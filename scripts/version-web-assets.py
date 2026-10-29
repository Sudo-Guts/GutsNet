#!/usr/bin/env python3
"""Añade versiones por contenido a CSS, JS y SVG para evitar caché obsoleta."""
import argparse
import hashlib
from pathlib import Path
import re

PUBLIC = Path(__file__).resolve().parents[1] / "C0DE/web/public"
PAGES = [PUBLIC / "index.html", PUBLIC / "materias.html", PUBLIC / "cv.html", PUBLIC / "cinema/index.php"]
REFERENCE = re.compile(
    r'(?P<start>(?:href|src|poster)=")'
    r'(?P<path>(?:\.\./)?assets/(?:css/[\w-]+\.css|js/[\w-]+\.js|img/[\w-]+\.svg))'
    r'(?:\?v=[a-f0-9]+)?(?P<end>")'
)


def versioned_text(page):
    def replace(match):
        resource = (page.parent / match["path"]).resolve()
        if not resource.is_relative_to(PUBLIC) or not resource.is_file():
            raise ValueError(f"Recurso no disponible: {match['path']} en {page.name}")
        version = hashlib.sha256(resource.read_bytes()).hexdigest()[:12]
        return f'{match["start"]}{match["path"]}?v={version}{match["end"]}'
    return REFERENCE.sub(replace, page.read_text(encoding="utf-8"))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Comprobar sin modificar archivos")
    args = parser.parse_args()
    pending = []
    for page in PAGES:
        updated = versioned_text(page)
        if updated != page.read_text(encoding="utf-8"):
            pending.append(page.relative_to(PUBLIC))
            if not args.check:
                page.write_text(updated, encoding="utf-8")
    if args.check and pending:
        parser.exit(1, "ERROR: versiones de recursos pendientes en " + ", ".join(map(str, pending))
                    + ". Ejecuta: python3 scripts/version-web-assets.py\n")
    print("OK: versiones de CSS, JavaScript y SVG " + ("comprobadas." if args.check else "actualizadas."))


if __name__ == "__main__":
    main()
