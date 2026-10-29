#!/usr/bin/env python3
"""Genera el CV web y PDF desde C0DE/web/cv.json; requiere ReportLab para el PDF."""
from html import escape
import json
from pathlib import Path

from reportlab.lib.colors import HexColor
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas
from reportlab.platypus import Paragraph

ROOT = Path(__file__).resolve().parents[1]
PUBLIC = ROOT / "C0DE/web/public"
DATA = ROOT / "C0DE/web/cv.json"
PDF_PATH = PUBLIC / "assets/docs/Gustavo_Ruiz_Luis_CV.pdf"
PHOTO = PUBLIC / "assets/img/gustavo-ruiz-luis.jpg"
ACCENT = HexColor("#7254b3")
TEXT = HexColor("#25283c")
MUTED = HexColor("#586174")


def build_html(data):
    """Genera HTML semántico; los datos se escapan antes de insertarlos."""
    e = escape
    projects = []
    for project in data["projects"]:
        points = "".join(f"<li>{e(point)}</li>" for point in project["points"])
        projects.append(f'''                    <article class="resume-project">
                        <h3>{e(project["name"])}</h3>
                        <p class="resume-project-meta mono">{e(project["area"])}</p>
                        <ul>{points}</ul>
                        <a class="text-link" href="{e(project["url"])}" target="_blank" rel="noopener noreferrer">Ver {e(project["repository"])} en GitHub <span aria-hidden="true">↗</span></a>
                    </article>''')
    education = data["education"]
    courses = "".join(f"<li>{e(course)}</li>" for course in education["courses"])
    skills = "".join(f'<div class="resume-skill"><h3>{e(skill["name"])}</h3><p>{e(skill["text"])}</p></div>' for skill in data["skills"])
    additional = data["additional"]
    html = f'''<!DOCTYPE html>
<html lang="es-MX">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="description" content="CV de {e(data["name"])}: estudiante de Ingeniería en Electrónica, con proyectos de sistemas embebidos, RISC-V, procesamiento de señales y Linux.">
    <meta name="theme-color" content="#ffffff">
    <title>{e(data["name"])} | CV · GutsNet</title>
    <link rel="icon" href="assets/img/favicon.svg" type="image/svg+xml">
    <link rel="stylesheet" href="assets/css/style.css">
    <link rel="stylesheet" href="assets/css/cv.css">
</head>
<body class="resume-page">
    <a class="skip-link" href="#cv-content">Ir al currículum</a>
    <header class="site-header">
        <div class="container header-content">
            <a class="logo" href="index.html" aria-label="GutsNet, inicio"><span class="logo-symbol" aria-hidden="true">g<span>.</span></span>GutsNet</a>
            <nav aria-label="Navegación principal"><a href="index.html">Portafolio</a><a href="index.html#proyectos">Proyectos</a><a href="materias.html">Materias</a><a href="cv.html" aria-current="page">CV</a></nav>
        </div>
    </header>
    <main id="cv-content" class="resume-shell">
        <header class="resume-header">
            <div>
                <p class="eyebrow">DEL CIRCUITO AL CÓDIGO / CURRICULUM VITAE</p>
                <h1>{e(data["name"])}</h1>
                <p class="resume-role">{e(data["role"])}</p>
                <p class="resume-focus mono">{e(data["focus"])}</p>
                <p class="resume-summary">{e(data["profile"])}</p>
                <div class="resume-actions"><a class="button primary" href="assets/docs/Gustavo_Ruiz_Luis_CV.pdf" download>Descargar CV en PDF <span aria-hidden="true">↓</span></a><a class="text-link" href="{e(data["github"])}" target="_blank" rel="noopener noreferrer">Mi GitHub <span aria-hidden="true">↗</span></a></div>
            </div>
            <img class="resume-photo" src="assets/img/gustavo-ruiz-luis.jpg" alt="Retrato de {e(data["name"])}" width="1152" height="1536">
        </header>
        <div class="resume-body">
            <section aria-labelledby="resume-projects-title">
                <h2 id="resume-projects-title" class="resume-section-title">Proyectos académicos y personales</h2>
{chr(10).join(projects)}
            </section>
            <aside class="resume-aside" aria-label="Formación, herramientas y contacto">
                <section aria-labelledby="resume-education-title"><h2 id="resume-education-title" class="resume-section-title">Formación</h2><span class="resume-study-status">{e(education["status"])}</span><h3>{e(education["degree"])}</h3><p>{e(education["institution"])}</p><p>Materias actuales</p><ul>{courses}</ul></section>
                <section aria-labelledby="resume-skills-title"><h2 id="resume-skills-title" class="resume-section-title">Áreas y herramientas</h2>{skills}</section>
                <section aria-labelledby="resume-additional-title"><h2 id="resume-additional-title" class="resume-section-title">Electrónica aplicada</h2><h3>{e(additional["name"])}</h3><p>{e(additional["text"])}</p><a class="text-link" href="{e(additional["url"])}" target="_blank" rel="noopener noreferrer">Ver SPWM <span aria-hidden="true">↗</span></a></section>
                <section aria-labelledby="resume-method-title"><h2 id="resume-method-title" class="resume-section-title">Cómo trabajo</h2><p>{e(data["method"])}</p></section>
                <section aria-labelledby="resume-contact-title"><h2 id="resume-contact-title" class="resume-section-title">Contacto y código</h2><a class="text-link resume-contact" href="{e(data["github"])}" target="_blank" rel="noopener noreferrer">{e(data["github_label"])}</a></section>
            </aside>
        </div>
        <footer class="resume-footer mono"><span>PROYECTOS ACADÉMICOS Y PERSONALES</span><span>{e(data["revision"])}</span><a href="index.html">Volver a GutsNet ↗</a></footer>
    </main>
</body>
</html>
'''
    (PUBLIC / "cv.html").write_text(html, encoding="utf-8")


def build_pdf(data):
    """Compone una página A4 con texto seleccionable y enlaces a los proyectos."""
    font = "Helvetica"
    bold = "Helvetica-Bold"
    font_dir = Path("/usr/share/fonts/truetype/dejavu")
    if (font_dir / "DejaVuSans.ttf").is_file() and (font_dir / "DejaVuSans-Bold.ttf").is_file():
        pdfmetrics.registerFont(TTFont("CVSans", str(font_dir / "DejaVuSans.ttf")))
        pdfmetrics.registerFont(TTFont("CVSansBold", str(font_dir / "DejaVuSans-Bold.ttf")))
        font, bold = "CVSans", "CVSansBold"
    PDF_PATH.parent.mkdir(parents=True, exist_ok=True)
    pdf = canvas.Canvas(str(PDF_PATH), pagesize=A4, pageCompression=1)
    pdf.setTitle(f"{data['name']} | Curriculum vitae")
    pdf.setAuthor(data["name"])
    pdf.setSubject(data["focus"])
    width, height = A4
    styles = {
        "body": ParagraphStyle("body", fontName=font, fontSize=9.1, leading=12.6, textColor=MUTED, alignment=TA_LEFT),
        "side": ParagraphStyle("side", fontName=font, fontSize=8.3, leading=11.8, textColor=MUTED),
        "title": ParagraphStyle("title", fontName=bold, fontSize=11.1, leading=14.7, textColor=TEXT),
        "small-title": ParagraphStyle("small-title", fontName=bold, fontSize=8.8, leading=12, textColor=TEXT),
        "profile": ParagraphStyle("profile", fontName=font, fontSize=9.3, leading=13.4, textColor=MUTED)
    }

    def paragraph(text, x, top, size, style="body"):
        item = Paragraph(escape(text), styles[style])
        _, block_height = item.wrap(size, height)
        item.drawOn(pdf, x, top - block_height)
        return top - block_height

    def label(text, x, top):
        pdf.setFont(bold, 7.5)
        pdf.setFillColor(ACCENT)
        pdf.drawString(x, top, text.upper())
        return top - 18

    def link(text, url, x, top, size=7.7):
        pdf.setFont(font, size)
        pdf.setFillColor(ACCENT)
        pdf.drawString(x, top - size, text)
        pdf.linkURL(url, (x, top - size - 2, x + pdfmetrics.stringWidth(text, font, size), top + 2), relative=0)
        return top - size - 8

    pdf.setFillColor(ACCENT)
    pdf.rect(36, height - 24, width - 72, 3, fill=1, stroke=0)
    label("Del circuito al código / Curriculum vitae", 36, height - 43)
    pdf.setFillColor(TEXT)
    pdf.setFont(bold, 28)
    pdf.drawString(34, height - 80, data["name"])
    pdf.setFont(font, 10)
    pdf.drawString(36, height - 101, data["role"])
    pdf.setFillColor(ACCENT)
    pdf.setFont(font, 8.5)
    pdf.drawString(36, height - 118, data["focus"])
    header_bottom = paragraph(data["profile"], 36, height - 135, 388, "profile")
    photo_x, photo_y, photo_w, photo_h = width - 140, height - 174, 104, 130
    pdf.saveState()
    clip = pdf.beginPath()
    clip.roundRect(photo_x, photo_y, photo_w, photo_h, 7)
    pdf.clipPath(clip, stroke=0)
    pdf.drawImage(str(PHOTO), photo_x, photo_y - 4.3, width=photo_w, height=photo_w * 4 / 3, mask="auto")
    pdf.restoreState()
    rule_y = min(header_bottom - 19, photo_y - 18)
    pdf.setStrokeColor(HexColor("#ddd7e8"))
    pdf.setLineWidth(.7)
    pdf.line(36, rule_y, width - 36, rule_y)
    main_top = rule_y - 25
    y = label("Proyectos académicos y personales", 36, main_top)
    for project in data["projects"]:
        y = paragraph(project["name"], 36, y, 326, "title") - 5
        pdf.setFillColor(ACCENT)
        pdf.setFont(font, 6.8)
        pdf.drawString(36, y - 6.8, project["area"])
        y -= 20
        for point in project["points"]:
            pdf.setFillColor(ACCENT)
            pdf.circle(39, y - 5.6, 1.5, fill=1, stroke=0)
            y = paragraph(point, 48, y, 314) - 5
        y = link("github.com/Sudo-Guts/" + project["repository"], project["url"], 48, y) - 13

    side_x, side_w = 391, width - 427
    side = label("Formación", side_x, main_top)
    education = data["education"]
    side = paragraph(education["degree"], side_x, side, side_w, "small-title") - 4
    side = paragraph(education["institution"] + " · " + education["status"], side_x, side, side_w, "side") - 23
    side = label("Áreas y herramientas", side_x, side)
    for skill in data["skills"]:
        side = paragraph(skill["name"], side_x, side, side_w, "small-title") - 4
        side = paragraph(skill["text"], side_x, side, side_w, "side") - 12
    side -= 8
    side = label("Electrónica aplicada", side_x, side)
    side = paragraph(data["additional"]["name"], side_x, side, side_w, "small-title") - 4
    side = paragraph(data["additional"]["text"], side_x, side, side_w, "side") - 5
    side = link("Ver proyecto SPWM", data["additional"]["url"], side_x, side) - 18
    side = label("Cómo trabajo", side_x, side)
    side = paragraph(data["method"], side_x, side, side_w, "side") - 23
    side = label("Contacto y código", side_x, side)
    side = link(data["github_label"], data["github"], side_x, side)
    if min(y, side) < 55:
        raise ValueError(f"El contenido excede la página; revisar el diseño (proyectos: {y:.1f}, lateral: {side:.1f}).")
    pdf.setStrokeColor(HexColor("#ddd7e8"))
    pdf.line(36, 44, width - 36, 44)
    pdf.setFont(font, 7)
    pdf.setFillColor(MUTED)
    pdf.drawString(36, 29, "Gustavo Ruiz Luis / Proyectos académicos y personales")
    pdf.drawRightString(width - 36, 29, data["revision"])
    pdf.save()


def main():
    data = json.loads(DATA.read_text(encoding="utf-8"))
    if not PHOTO.is_file():
        raise FileNotFoundError(PHOTO)
    build_pdf(data)
    build_html(data)
    print("OK: CV de una página en PDF y versión web generados desde cv.json.")


if __name__ == "__main__":
    main()
