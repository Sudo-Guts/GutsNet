#!/usr/bin/env python3
"""Prueba altas/bajas por HTTPS con archivos propios y limpia solo esas pruebas."""
import argparse
import base64
import http.client
from html.parser import HTMLParser
import json
from pathlib import Path
import secrets
import socket
import ssl
import sys
from http.cookies import SimpleCookie
from urllib.parse import quote, urlencode

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--user", default="cine")
parser.add_argument("--ca", required=True)
args = parser.parse_args()
password = sys.stdin.readline().rstrip("\r\n")
if not password:
    raise SystemExit("ERROR: falta la contraseña por stdin.")
authorization = "Basic " + base64.b64encode(
    (args.user + ":" + password).encode("utf-8")
).decode("ascii")
del password
context = ssl.create_default_context(cafile=args.ca)


class LocalHTTPS(http.client.HTTPSConnection):
    def connect(self):
        transport = socket.create_connection(("127.0.0.1", 443), timeout=self.timeout)
        self.sock = context.wrap_socket(transport, server_hostname="gutsnet.test")


class Client:
    def __init__(self):
        self.cookies = SimpleCookie()

    def request(self, method, path, body=None, headers=None, authenticated=True):
        merged = {"Accept": "application/json"}
        if authenticated:
            merged["Authorization"] = authorization
        if self.cookies:
            merged["Cookie"] = "; ".join(m.key + "=" + m.coded_value for m in self.cookies.values())
        merged.update(headers or {})
        connection = LocalHTTPS("gutsnet.test", timeout=60, context=context)
        try:
            connection.request(method, path, body=body, headers=merged)
            response = connection.getresponse()
            status = response.status
            pairs = response.getheaders()
            for key, value in pairs:
                if key.lower() == "set-cookie":
                    self.cookies.load(value)
            return status, {k.lower(): v for k, v in pairs}, response.read()
        finally:
            connection.close()

    def post(self, fields, accept="application/json", authenticated=True):
        return self.request("POST", "/cinema/manage.php",
            urlencode(fields).encode("utf-8"),
            {"Content-Type": "application/x-www-form-urlencoded", "Accept": accept},
            authenticated=authenticated)


class Catalog(HTMLParser):
    def __init__(self, page):
        super().__init__(convert_charrefs=True)
        self.current = None
        self.forms = []
        self.audios = 0
        self.feed(page)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "form":
            self.current = {}
        elif tag == "input" and self.current is not None and attrs.get("name"):
            self.current[attrs["name"]] = attrs.get("value", "")
        elif tag == "audio":
            self.audios += 1

    def handle_endtag(self, tag):
        if tag == "form" and self.current is not None:
            self.forms.append(self.current)
            self.current = None

    def csrf(self):
        return next(f["csrf"] for f in self.forms if f.get("action") == "upload")

    def deletion(self, name):
        return next((f for f in self.forms
            if f.get("action") == "delete" and f.get("filename") == name), None)


def expect(response, expected, label):
    if response[0] != expected:
        raise AssertionError(f"{label}: HTTP {response[0]}, se esperaba {expected}.")
    return response


client = Client()
owned = set()
root = Path(__file__).resolve().parents[2]
video = (root / "C0DE/web/public/assets/video/demostracion.mp4").read_bytes()
audio = (root / "C0DE/web/public/assets/audio/ambiente2.mp3").read_bytes()
prefix = "GutsCinema_prueba_" + secrets.token_hex(10)


def catalog():
    response = expect(client.request("GET", "/cinema/"), 200, "Catálogo")
    page = response[2].decode("utf-8")
    return Catalog(page), page, response[1]


def upload(name, data, fields=None, accept="application/json"):
    boundary = "GutsCinema" + secrets.token_hex(16)
    fields = fields if fields is not None else {"action": "upload", "csrf": token}
    parts = []
    for key, value in fields.items():
        parts.append(("--" + boundary + '\r\nContent-Disposition: form-data; name="'
            + key + '"\r\n\r\n' + value + "\r\n").encode("utf-8"))
    filename = name.replace("\\", "\\\\").replace('"', '\\"')
    parts.append(("--" + boundary + '\r\nContent-Disposition: form-data; name="media"; filename="'
        + filename + '"\r\nContent-Type: application/octet-stream\r\n\r\n').encode("utf-8"))
    parts.extend([data, ("\r\n--" + boundary + "--\r\n").encode("ascii")])
    response = client.request("POST", "/cinema/manage.php", b"".join(parts),
        {"Content-Type": "multipart/form-data; boundary=" + boundary, "Accept": accept})
    if response[0] in (201, 303) and name.startswith(prefix):
        owned.add(name)
    return response


def media(name, authenticated=True):
    return client.request("GET", "/cinema/media/" + quote(name, safe=""),
        headers={"Range": "bytes=0-15"}, authenticated=authenticated)


try:
    current, page, headers = catalog()
    token = current.csrf()
    assert 'id="cinema-upload"' in page, "Falta el formulario de carga."
    assert len(token) == 64
    cookie = client.cookies["guts_cinema"]
    assert cookie["secure"] and cookie["httponly"] and cookie["samesite"] == "Strict"
    assert cookie["path"] == "/cinema/"

    expect(client.request("GET", "/cinema/manage.php"), 405, "Método de gestión")
    expect(client.post({"action": "delete"}, authenticated=False), 401, "Gestión sin cuenta")
    expect(client.post({"action": "delete"}), 403, "Gestión sin CSRF")
    expect(client.post({"action": "upload", "csrf[]": token}), 403, "CSRF mal formado")
    other = Client()
    expect(other.post({"action": "delete", "csrf": token}), 403, "CSRF de otra sesión")

    invalid = prefix + "_falso.mp4"
    expect(upload(invalid, b"<?php echo 'ESTO_NO_ES_UN_VIDEO'; ?>"), 415, "MP4 falso")
    expect(upload(prefix + "_script.php", video), 415, "Extensión no permitida")
    expect(upload("." + prefix + ".mp4", video), 415, "Archivo oculto")

    movie = prefix + '_<b>&"video".mp4'
    expect(upload(movie, video), 201, "Subir MP4")
    # La muestra supera 2 MiB: detecta la configuracion PHP anterior por defecto.
    assert len(video) > 2 * 1024 * 1024
    partial = expect(media(movie), 206, "Range del MP4")
    assert partial[2] == video[:16]
    assert partial[1]["content-range"].endswith("/" + str(len(video)))
    expect(media(movie, authenticated=False), 401, "MP4 privado")

    expect(upload(movie, video + b"NO_SOBRESCRIBIR"), 409, "Nombre duplicado")
    partial = expect(media(movie), 206, "MP4 conservado")
    assert partial[1]["content-range"].endswith("/" + str(len(video)))

    song = prefix + "_cancion.mp3"
    expect(upload(song, audio), 201, "Subir MP3")
    partial = expect(media(song), 206, "Range del MP3")
    assert partial[2] == audio[:16]
    assert partial[1]["content-type"].startswith("audio/mpeg")
    expect(media(song, authenticated=False), 401, "MP3 privado")

    current, page, _ = catalog()
    assert current.audios > 0, "Falta el reproductor de audio."
    assert "&lt;b&gt;&amp;&quot;video&quot;" in page and '<b>&"video"' not in page
    assert json.loads(expect(client.post({"action": "invalid", "csrf": token}),
        400, "Acción inválida")[2])["ok"] is False

    deletion = current.deletion(movie)
    assert deletion is not None, "Falta la confirmación para eliminar el MP4."
    expect(client.post({**deletion, "csrf": "0" * 64}), 403, "Baja sin CSRF")
    expect(client.post({**deletion, "filename": "../../etc/passwd"}), 400, "Traversal")
    expect(client.post({**deletion, "filename[]": movie, "filename": ""}), 400, "Nombre mal formado")
    expect(client.post({**deletion, "version": "0" * 64}), 409, "Archivo desactualizado")
    expect(media(movie), 206, "Archivo conservado tras bajas inválidas")
    expect(client.post(deletion), 200, "Eliminar MP4")
    owned.discard(movie)
    expect(media(movie), 404, "MP4 eliminado")
    expect(client.post(deletion), 404, "Baja repetida")

    # El flujo HTML tambien funciona sin JavaScript y usa POST/Redirect/GET.
    native = prefix + "_sin_javascript.mp3"
    response = expect(upload(native, audio, accept="text/html"), 303, "Carga HTML")
    assert response[1]["location"] == "/cinema/"
    current, page, _ = catalog()
    assert current.deletion(native) is not None and "Archivo agregado:" in page
    response = expect(client.post(current.deletion(native), accept="text/html"),
        303, "Baja HTML")
    assert response[1]["location"] == "/cinema/"
    owned.discard(native)
    expect(media(native), 404, "MP3 eliminado por formulario")

    print("OK: altas MP4/MP3, progreso compatible, Range, privacidad, CSRF, "
        "nombres duplicados, MIME, rutas, versiones y baja con/sin JavaScript.")
finally:
    # Nunca se elimina un archivo anterior a esta prueba.
    if owned:
        current, _, _ = catalog()
        for name in owned:
            form = current.deletion(name)
            if form is not None:
                expect(client.post(form), 200, "Limpiar archivo propio de prueba")
