#!/usr/bin/env python3
"""Prueba SSH anidado en un runner desechable con el modulo ya instalado."""
import argparse
import os
from pathlib import Path
import shutil
import socket
import subprocess
import uuid

import pexpect


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--known-hosts", required=True)
    args = parser.parse_args()
    if os.geteuid() != 0:
        raise SystemExit("ERROR: esta prueba requiere root en un runner desechable.")
    password = input()
    assert password, "Falta la clave de prueba por stdin"
    jail = Path("/home/gutsnet-jail")
    known_hosts = jail / "var/lib/gutsnet-ssh/known_hosts"
    private_config = jail / "var/lib/gutsnet-ssh/.ssh"
    shared_config = jail / "compartido/.ssh"
    for folder in (private_config, shared_config):
        assert not folder.exists(), "La prueba no sustituye configuraciones existentes"
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        port = listener.getsockname()[1]
    sshd = subprocess.Popen(["/usr/sbin/sshd", "-D", "-e", "-p", str(port)], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
    session = None
    name = "salto_ci_" + uuid.uuid4().hex
    try:
        # Si se lee cualquiera de estas configuraciones, la conexion debe fallar.
        for folder in (private_config, shared_config):
            folder.mkdir(mode=0o755)
            (folder / "config").write_text("OpcionGutsnetNoValida yes\n")
        options = ["-tt", "-e", "none", "-F", "/dev/null", "-o", "StrictHostKeyChecking=yes",
            "-o", f"UserKnownHostsFile={args.known_hosts}", "-o", "PreferredAuthentications=password",
            "-o", "PubkeyAuthentication=no", "-o", "ConnectTimeout=5", "gutsjail@127.0.0.1"]
        session = pexpect.spawn("/usr/bin/ssh", options, encoding="utf-8", timeout=20)
        session.expect("(?i)password:")
        session.sendline(password)
        base_prompt = "gutsnet-jail:/compartido> "
        parent_prompt = f"gutsnet-jail:/compartido/{name}> "
        session.expect_exact(base_prompt)
        session.sendline(f"mkdir {name}")
        session.expect_exact(base_prompt)
        session.sendline(f"cd {name}")
        session.expect_exact(parent_prompt)

        # Puerto 22, repeticion sin volver a aceptar clave y puerto alternativo/DNS.
        for command, first_visit in (("ssh gutsjail@127.0.0.1", True),
            ("ssh gutsjail@127.0.0.1", False), (f"ssh -p {port} gutsjail@localhost", True)):
            assert sshd.poll() is None, "No arranco el sshd del puerto alternativo"
            session.sendline(command)
            if first_visit:
                session.expect("Are you sure you want to continue connecting")
                session.sendline("yes")
            session.expect("(?i)password:")
            session.sendline(password)
            session.expect_exact(base_prompt)
            session.sendline(f"write {name}/nota.txt Conexion anidada correcta")
            session.expect_exact(base_prompt)
            session.sendline(f"cat {name}/nota.txt")
            session.expect_exact("Conexion anidada correcta")
            session.expect_exact(base_prompt)
            session.sendline(f"rm {name}/nota.txt")
            session.expect_exact(base_prompt)
            session.sendline("exit")
            session.expect_exact(parent_prompt)
        assert known_hosts.read_text().startswith("|1|"), "No se conservaron claves conocidas con hash"
        # Un destino inaccesible debe devolver la consola sin perder su carpeta.
        with socket.socket() as occupied:
            occupied.bind(("127.0.0.1", 0))
            closed_port = occupied.getsockname()[1]
            session.sendline(f"ssh -p {closed_port} gutsjail@127.0.0.1")
            session.expect_exact("Connection refused")
            session.expect_exact(parent_prompt)
        for command in ("ssh -oProxyCommand=id user@localhost", "ssh user@localhost id",
            "ssh -F /compartido/.ssh/config user@localhost", "bash", "cd /", "cat /etc/passwd"):
            session.sendline(command)
            session.expect_exact(parent_prompt)
            assert "FUERA_DEL_AREA_COMPARTIDA" not in session.before
            assert "Uso:" in session.before or "no permitido" in session.before or "Operation not permitted" in session.before
        session.sendline("cd ..")
        session.expect_exact(base_prompt)
        session.sendline(f"rmdir {name}")
        session.expect_exact(base_prompt)
        session.sendline("exit")
        session.expect(pexpect.EOF)
        session.close()
        assert session.exitstatus == 0, "La sesion exterior no termino correctamente"
        print("OK: SSH anidado, claves persistentes, DNS, puerto alternativo y regreso al jail.")
    finally:
        if session is not None and session.isalive():
            session.close(force=True)
        sshd.terminate()
        try:
            sshd.communicate(timeout=5)
        except subprocess.TimeoutExpired:
            sshd.kill()
            sshd.communicate()
        for folder in (private_config, shared_config, jail / "compartido" / name):
            shutil.rmtree(folder, ignore_errors=True)


if __name__ == "__main__":
    main()
