#!/usr/bin/env python3
"""Prueba HTTPS, SSH/SFTP y FTPS reales; recibe contrasenas web/linux como JSON por stdin."""
import argparse
import base64
from ftplib import FTP, FTP_TLS, error_perm
from html.parser import HTMLParser
from http.cookies import SimpleCookie
import http.client
import io
import json
import os
from pathlib import Path
import secrets
import shlex
import socket
import ssl
import subprocess
import sys
import tempfile
from urllib.parse import quote, urlencode


class Catalog(HTMLParser):
    def __init__(self, page):
        super().__init__(convert_charrefs=True)
        self.current = None
        self.forms = []
        self.feed(page)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "form":
            self.current = {}
        elif tag == "input" and self.current is not None and attrs.get("name"):
            self.current[attrs["name"]] = attrs.get("value", "")

    def handle_endtag(self, tag):
        if tag == "form" and self.current is not None:
            self.forms.append(self.current)
            self.current = None

    def form(self, action, name=None):
        return next(form for form in self.forms if form.get("action") == action and (name is None or form.get("filename") == name))


class LocalHTTPS(http.client.HTTPSConnection):
    def connect(self):
        transport = socket.create_connection(("127.0.0.1", 443), timeout=self.timeout)
        self.sock = self._context.wrap_socket(transport, server_hostname="gutsnet.test")


class ResumingFTP(FTP_TLS):
    """Valida gutsnet.test por loopback y reutiliza TLS en el canal de datos."""
    def connect(self, port=21):
        response = super().connect("127.0.0.1", port)
        # FTP_TLS usa self.host para validar ambos canales, no para resolver PASV.
        self.host = "gutsnet.test"
        return response

    def ntransfercmd(self, command, rest=None):
        connection, size = FTP.ntransfercmd(self, command, rest)
        if self._prot_p:
            connection = self.context.wrap_socket(connection, server_hostname=self.host, session=self.sock.session)
        return connection, size


class Web:
    def __init__(self, context, password):
        self.context = context
        self.password = password
        self.cookies = SimpleCookie()

    def request(self, method, path, body=None, headers=None, user="gutsjail"):
        merged = {"Accept": "application/json"}
        if user is not None:
            credential = base64.b64encode((user + ":" + self.password).encode()).decode("ascii")
            merged["Authorization"] = "Basic " + credential
        if self.cookies:
            merged["Cookie"] = "; ".join(item.key + "=" + item.coded_value for item in self.cookies.values())
        merged.update(headers or {})
        connection = LocalHTTPS("gutsnet.test", timeout=30, context=self.context)
        try:
            connection.request(method, path, body=body, headers=merged)
            response = connection.getresponse()
            for key, value in response.getheaders():
                if key.lower() == "set-cookie":
                    self.cookies.load(value)
            return response.status, response.read()
        finally:
            connection.close()

    def catalog(self):
        status, body = self.request("GET", "/cinema/")
        assert status == 200, f"Catalogo: HTTP {status}"
        return Catalog(body.decode("utf-8"))

    def upload(self, name, payload):
        boundary = "GutsNet" + secrets.token_hex(16)
        token = self.catalog().form("upload")["csrf"]
        parts = []
        for key, value in {"action": "upload", "csrf": token}.items():
            parts.append((f'--{boundary}\r\nContent-Disposition: form-data; name="{key}"\r\n\r\n{value}\r\n').encode())
        filename = name.replace("\\", "\\\\").replace('"', '\\"')
        parts.append((f'--{boundary}\r\nContent-Disposition: form-data; name="media"; filename="{filename}"\r\nContent-Type: application/octet-stream\r\n\r\n').encode())
        parts.extend([payload, (f"\r\n--{boundary}--\r\n").encode()])
        status, _ = self.request("POST", "/cinema/manage.php", b"".join(parts), {"Content-Type": "multipart/form-data; boundary=" + boundary})
        assert status == 201, f"Carga web: HTTP {status}"

    def delete(self, name):
        fields = self.catalog().form("delete", name)
        status, _ = self.request("POST", "/cinema/manage.php", urlencode(fields).encode(), {"Content-Type": "application/x-www-form-urlencoded"})
        assert status == 200, f"Eliminacion web: HTTP {status}"

    def media(self, name):
        return self.request("GET", "/cinema/media/" + quote(name, safe=""), headers={"Range": "bytes=0-15"})


def authenticated_process(command, password, input_text=None):
    """Entrega la credencial por descriptor, sin exponerla en argumentos."""
    read_fd, write_fd = os.pipe()
    try:
        os.write(write_fd, (password + "\n").encode())
    finally:
        os.close(write_fd)
    try:
        return subprocess.run(["sshpass", "-d", str(read_fd), *command], input=input_text, text=True, capture_output=True, pass_fds=(read_fd,), timeout=45)
    finally:
        os.close(read_fd)


def sftp_quote(value):
    return '"' + str(value).replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ca", default="/etc/ssl/certs/gutsnet-ca.crt")
    args = parser.parse_args()
    credentials = json.loads(sys.stdin.readline())
    web_password = credentials["web"]
    linux_password = credentials["linux"]
    assert web_password and linux_password
    context = ssl.create_default_context(cafile=args.ca)
    ftp_context = ssl.create_default_context(cafile=args.ca)
    ftp_context.maximum_version = ssl.TLSVersion.TLSv1_2
    web = Web(context, web_password)
    root = Path(__file__).resolve().parents[3]
    audio = (root / "C0DE/web/public/assets/audio/ambiente2.mp3").read_bytes()
    video = (root / "C0DE/web/public/assets/video/demostracion.mp4").read_bytes()
    prefix = "GutsNet_cruce_" + secrets.token_hex(12)
    owned = set()
    with tempfile.TemporaryDirectory(prefix="gutsnet-interfaces-") as temp:
        temp = Path(temp)
        keys = subprocess.run(["ssh-keyscan", "-T", "5", "127.0.0.1"], capture_output=True, text=True, check=True, timeout=10)
        known_hosts = temp / "known_hosts"
        known_hosts.write_text(keys.stdout)
        options = ["-o", "StrictHostKeyChecking=yes", "-o", "UserKnownHostsFile=" + str(known_hosts), "-o", "PreferredAuthentications=password", "-o", "PubkeyAuthentication=no", "-o", "BatchMode=no", "-o", "ConnectTimeout=5", "-o", "NumberOfPasswordPrompts=1"]

        def ssh(command, success=True):
            result = authenticated_process(["ssh", "-T", "-n", *options, "gutsjail@127.0.0.1", command], linux_password)
            assert (result.returncode == 0) == success, f"SSH: {command}: {result.stderr}"
            return result.stdout

        def sftp(commands, success=True):
            result = authenticated_process(["sftp", "-q", *options, "-b", "-", "gutsjail@127.0.0.1"], linux_password, commands + "\n")
            assert (result.returncode == 0) == success, f"SFTP: {result.stderr}"

        def download_sftp(name, payload):
            target = temp / "descarga.bin"
            sftp("get " + sftp_quote("/compartido/" + name) + " " + sftp_quote(target))
            assert target.read_bytes() == payload, "SFTP altero el contenido"

        ftp = ResumingFTP(context=ftp_context, encoding="utf-8", timeout=30)
        ftp.connect()
        ftp.login("gutsjail", linux_password)
        ftp.prot_p()
        ftp.cwd("/intercambio")
        try:
            assert web.request("GET", "/cinema/", user=None)[0] == 401
            assert web.request("GET", "/cinema/", user="cine")[0] in (401, 403)
            assert ssh("pwd").strip() == "/compartido"

            name = prefix + "_Mi canción.mp3"
            owned.add(name)
            web.upload(name, audio)
            downloaded = io.BytesIO()
            ftp.retrbinary("RETR " + name, downloaded.write)
            assert downloaded.getvalue() == audio, "FTPS no lee la carga web"
            download_sftp(name, audio)
            assert name in ssh("ls"), "SSH oculta el nombre subido por web"
            ssh("rm " + shlex.quote(name))
            assert web.media(name)[0] == 404
            assert name not in ftp.nlst()
            owned.remove(name)
            print("OK: carga HTTPS, descarga FTPS/SFTP y baja SSH con espacios y acentos.")

            name = prefix + "_Señal SFTP.mp4"
            source = temp / "carga.mp4"
            source.write_bytes(video)
            source.chmod(0o664)
            owned.add(name)
            sftp("put " + sftp_quote(source) + " " + sftp_quote("/compartido/" + name))
            status, body = web.media(name)
            assert status == 206 and body == video[:16], "Cinema no reproduce la carga SFTP"
            web.delete(name)
            assert name not in ftp.nlst()
            assert name not in ssh("ls")
            owned.remove(name)
            print("OK: carga SFTP, reproduccion HTTPS Range y baja web visible por FTPS/SSH.")

            name = prefix + "_Audio FTPS.mp3"
            owned.add(name)
            ftp.storbinary("STOR " + name, io.BytesIO(audio))
            status, body = web.media(name)
            assert status == 206 and body == audio[:16], "Cinema no reproduce la carga FTPS"
            download_sftp(name, audio)
            web.delete(name)
            assert name not in ftp.nlst()
            owned.remove(name)
            print("OK: carga FTPS, reproduccion web, descarga SFTP y baja web.")

            ssh("cat /etc/passwd", success=False)
            sftp("get /etc/passwd " + sftp_quote(temp / "prohibido"), success=False)
            try:
                ftp.retrbinary("RETR /../../etc/passwd", lambda block: None)
                raise AssertionError("FTPS accedio fuera del chroot")
            except error_perm:
                pass
            denied = ResumingFTP(context=ftp_context, timeout=10)
            try:
                denied.connect()
                try:
                    denied.login("gutsftp", linux_password)
                    raise AssertionError("La cuenta FTPS anterior sigue autorizada")
                except error_perm:
                    pass
            finally:
                denied.close()
            print("OK: aislamiento de SSH/SFTP/FTPS y rechazo de credenciales anteriores.")
        finally:
            for name in owned:
                try:
                    ftp.delete(name)
                except error_perm:
                    pass
            ftp.close()
    print("Pruebas cruzadas completadas; solo se retiraron archivos propios.")


if __name__ == "__main__":
    main()
