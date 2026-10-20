#!/usr/bin/env python3
"""Comprueba que Cinema conserva la IP al pasar de HTTP a HTTPS."""
import http.client


def request(host, path):
    connection = http.client.HTTPConnection("127.0.0.1", timeout=15)
    try:
        connection.request("GET", path, headers={"Host": host})
        response = connection.getresponse()
        headers = {key.lower(): value for key, value in response.getheaders()}
        response.read()
        return response.status, headers
    finally:
        connection.close()


hosts = (
    ("gutsnet.test", "gutsnet.test"),
    ("gutsnet.test:80", "gutsnet.test"),
    ("localhost", "localhost"),
    ("127.0.0.1", "127.0.0.1"),
    ("192.168.244.135", "192.168.244.135"),
    ("192.168.244.135:80", "192.168.244.135"),
    ("[::1]", "[::1]"),
    ("[::1]:80", "[::1]"),
    ("gutsnet.test.example.org", "gutsnet.test"),
    ("192.168.244.135.example.org", "gutsnet.test"),
)
paths = (
    ("/cinema", "/cinema/"),
    ("/cinema/", "/cinema/"),
    ("/cinema/manage.php", "/cinema/manage.php"),
    ("/cinema/media/Mi%20pelicula%23.mp4?download=1", "/cinema/media/Mi%20pelicula%23.mp4?download=1"),
)
for host, target in hosts:
    for path, destination in paths:
        status, headers = request(host, path)
        expected = "https://" + target + destination
        if status != 302 or headers.get("location") != expected:
            raise SystemExit(f"ERROR: HTTP {host}{path}: {status}, "
                f"Location={headers.get('location')!r}; se esperaba 302 a {expected}")
        if "www-authenticate" in headers:
            raise SystemExit("ERROR: Cinema solicita credenciales por HTTP.")
print("OK: Cinema redirige nombre e IP a HTTPS sin cambiar de servidor (40 casos)")
