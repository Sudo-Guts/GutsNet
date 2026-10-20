#!/usr/bin/env python3
"""Prueba clientes y destinos configurables con peers temporales, sin Internet."""
from contextlib import contextmanager
import errno
from pathlib import Path
import socket
import subprocess
import sys
import threading
import unittest

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "out"


@contextmanager
def tcp_service(handler, family=socket.AF_INET, port=0):
    listener = socket.socket(family, socket.SOCK_STREAM)
    try:
        if family == socket.AF_INET6:
            listener.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 1)
        listener.bind(("::1" if family == socket.AF_INET6 else "127.0.0.1", port))
        listener.listen(1)
    except Exception:
        listener.close()
        raise
    listener.settimeout(3)
    stop = threading.Event()
    errors = []

    def serve():
        try:
            connection, _ = listener.accept()
            with connection:
                connection.settimeout(3)
                handler(connection, stop)
        except Exception as error:
            errors.append(error)

    worker = threading.Thread(target=serve, daemon=True)
    worker.start()
    try:
        yield listener.getsockname()[1]
    finally:
        has_error = sys.exc_info()[0] is not None
        stop.set()
        listener.close()
        worker.join(4)
        if not has_error:
            if worker.is_alive():
                raise AssertionError("El servidor temporal no termino.")
            if errors:
                raise errors[0]


@contextmanager
def udp_service(reply):
    server = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    server.bind(("127.0.0.1", 0))
    server.settimeout(3)
    errors = []

    def serve():
        try:
            data, peer = server.recvfrom(65535)
            server.sendto(reply(data), peer)
        except Exception as error:
            errors.append(error)

    worker = threading.Thread(target=serve, daemon=True)
    worker.start()
    try:
        yield server.getsockname()[1]
    finally:
        has_error = sys.exc_info()[0] is not None
        worker.join(4)
        server.close()
        if not has_error and errors:
            raise errors[0]


def read_request(connection):
    data = bytearray()
    while True:
        part = connection.recv(4096)
        if not part:
            return bytes(data)
        data.extend(part)


def run_client(name, port, *arguments):
    return subprocess.run([str(OUT / name), "localhost", str(port), *arguments],
        capture_output=True, timeout=3, check=False)


def run_target(name, *settings):
    return subprocess.run(["make", "--no-print-directory", "-s", name, *settings],
        cwd=ROOT, capture_output=True, timeout=3, check=False)


class Clients(unittest.TestCase):
    def test_echo_tcp_fragmentado_y_servidor_que_permanece_abierto(self):
        message = ("Hola desde GutsNet: señales y circuitos. " * 280).encode()

        def echo(connection, stop):
            data = read_request(connection)
            for offset in range(0, len(data), 137):
                connection.sendall(data[offset:offset + 137])
            stop.wait(3)  # El cliente debe terminar sin esperar el EOF del peer.

        with tcp_service(echo) as port:
            result = run_client("echo_tcp_client", port, message.decode())
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, message)

    def test_echo_tcp_incorrecto(self):
        def wrong(connection, _):
            data = read_request(connection)
            connection.sendall(b"X" * len(data))

        with tcp_service(wrong) as port:
            result = run_client("echo_tcp_client", port, "mensaje")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(b"no coincide", result.stderr)

    def test_echo_tcp_incompleto(self):
        def incomplete(connection, _):
            data = read_request(connection)
            connection.sendall(data[:-1])

        with tcp_service(incomplete) as port:
            result = run_client("echo_tcp_client", port, "mensaje")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(b"incompleto", result.stderr)

    def test_daytime_tcp_con_formato_del_otro_servidor(self):
        response = b"2026-10-20 20:00:00 UTC\r\n"  # Dato de prueba.
        with tcp_service(lambda connection, _: connection.sendall(response)) as port:
            result = run_client("daytime_tcp_client", port)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, response)

    def test_daytime_tcp_vacio_se_rechaza(self):
        with tcp_service(lambda connection, _: None) as port:
            result = run_client("daytime_tcp_client", port)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(b"vacia", result.stderr)

    def test_daytime_prueba_la_siguiente_direccion_si_la_primera_no_envia_datos(self):
        families = []
        for family, _, _, _, _ in socket.getaddrinfo(
                "localhost", 0, socket.AF_UNSPEC, socket.SOCK_STREAM):
            if family not in families:
                families.append(family)
        if set(families) != {socket.AF_INET, socket.AF_INET6}:
            self.skipTest("localhost no tiene las dos familias de direcciones.")
        response = b"2026-10-20 20:00:00 UTC\r\n"
        visits = []

        def empty(connection, _):
            visits.append("vacia")

        def available(connection, _):
            visits.append("hora")
            connection.sendall(response)

        try:
            with tcp_service(empty, family=families[0]) as port:
                with tcp_service(available, family=families[1], port=port):
                    result = run_client("daytime_tcp_client", port)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(result.stdout, response)
                    self.assertEqual(visits, ["vacia", "hora"])
                    self.assertIn(b"Respuesta Daytime vacia", result.stderr)
        except OSError as error:
            if error.errno in {errno.EAFNOSUPPORT, errno.EADDRNOTAVAIL,
                              errno.EPROTONOSUPPORT}:
                self.skipTest("El entorno no tiene loopback IPv6 disponible.")
            raise

    def test_clientes_udp_con_host_y_puerto_configurables(self):
        with udp_service(lambda data: data) as port:
            result = run_client("echo_udp_client", port, "Hola UDP")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, b"Hola UDP")
        response = b"2026-10-20 20:00:00 UTC\r\n"
        with udp_service(lambda data: response) as port:
            result = run_client("daytime_udp_client", port)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, response)

    def test_make_echo_destino_y_mensaje_con_comillas(self):
        message = 'Hola "GutsNet"; un mensaje, sin ejecutar comandos.'

        def echo(connection, _):
            connection.sendall(read_request(connection))

        with tcp_service(echo) as port:
            result = run_target("echo-remoto", "ECHO_HOST=localhost",
                "ECHO_PORT=" + str(port), "MESSAGE=" + message)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn(("localhost:" + str(port)).encode(), result.stdout)
            self.assertTrue(result.stdout.endswith(message.encode() + b"\n"))

    def test_make_hora_destino_configurable(self):
        response = b"2026-10-20 20:00:00 UTC\r\n"
        with tcp_service(lambda connection, _: connection.sendall(response)) as port:
            result = run_target("hora-remota", "DAYTIME_HOST=localhost",
                "DAYTIME_PORT=" + str(port))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue(result.stdout.endswith(response))

    def test_make_limita_la_espera_si_el_servidor_no_responde(self):
        with tcp_service(lambda connection, stop: stop.wait(3)) as port:
            result = run_target("hora-remota", "DAYTIME_HOST=localhost",
                "DAYTIME_PORT=" + str(port), "SOCKET_TIMEOUT=0.2s")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(b"Sin respuesta de Daytime", result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
