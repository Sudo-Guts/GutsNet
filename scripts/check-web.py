#!/usr/bin/env python3
"""Verifica enlaces, fragmentos y recursos de la web sin iniciar Apache."""
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit
import re

PUBLIC = Path(__file__).resolve().parents[1] / "C0DE/web/public"


class Page(HTMLParser):
    def __init__(self, path):
        super().__init__(convert_charrefs=True)
        self.path = path
        self.ids = set()
        self.references = []
        self.h1_count = 0
        self.id_references = []
        self.feed(path.read_text(encoding="utf-8"))

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        identifier = attrs.get("id")
        if identifier:
            assert not re.search(r"\s", identifier), f"ID con espacios en {self.path.name}"
            assert identifier not in self.ids, f"ID duplicado: {identifier} en {self.path.name}"
            self.ids.add(identifier)
        self.h1_count += tag == "h1"
        for key in ("aria-labelledby", "aria-describedby", "aria-controls", "for"):
            self.id_references.extend(attrs.get(key, "").split())
        for key in ("href", "src", "poster"):
            if attrs.get(key):
                self.references.append(attrs[key])
        if tag == "img":
            assert "alt" in attrs, f"Imagen sin alt en {self.path.name}"
        if tag == "button":
            assert attrs.get("type") == "button", f"Botón sin tipo explícito en {self.path.name}"
        if tag == "a" and attrs.get("target") == "_blank":
            assert "noopener" in attrs.get("rel", "").split(), f"Enlace externo sin noopener: {attrs.get('href')}"


pages = {path.resolve(): Page(path) for path in PUBLIC.rglob("*.html")}
reference_count = 0
for path, page in pages.items():
    assert page.h1_count == 1, f"Se esperaba un h1 en {path.name}"
    for identifier in page.id_references:
        assert identifier in page.ids, f"Referencia a ID inexistente: {identifier} en {path.name}"
    for reference in page.references:
        parts = urlsplit(reference)
        if parts.scheme or parts.netloc:
            continue
        target = (PUBLIC / unquote(parts.path.lstrip("/")) if parts.path.startswith("/")
                  else path.parent / unquote(parts.path)).resolve() if parts.path else path
        assert target.is_relative_to(PUBLIC), f"Recurso fuera de public: {reference}"
        if target.is_dir():
            target = next((target / name for name in ("index.html", "index.php")
                           if (target / name).is_file()), target)
        assert target.is_file(), f"Falta {reference} en {path.name}"
        if parts.fragment and target in pages:
            assert unquote(parts.fragment) in pages[target].ids, f"Fragmento inexistente: {reference} en {path.name}"
        reference_count += 1

js = (PUBLIC / "assets/js/main.js").read_text(encoding="utf-8")
all_ids = set().union(*(page.ids for page in pages.values()))
for identifier in re.findall(r'getElementById\("([^"\n]+)"\)', js):
    assert identifier in all_ids, f"JavaScript referencia un ID inexistente: {identifier}"

audio_files = re.findall(r'file:\s*["\'](/?assets/audio/[^"\']+)["\']', js)
assert audio_files, "No se encontraron pistas de audio"
for file in audio_files:
    assert (PUBLIC / file.lstrip("/")).is_file(), f"Falta pista: {file}"

mp4 = PUBLIC / "assets/video/demostracion.mp4"
with mp4.open("rb") as stream:
    header = stream.read(12)
assert header[4:8] == b"ftyp", "El video no tiene una cabecera MP4 válida"
print(f"OK: {len(pages)} páginas; {reference_count} enlaces, fragmentos y recursos; {len(audio_files)} pistas; cabecera MP4.")
