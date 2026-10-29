# Currículum y fotografía

La portada incorpora la fotografía de Gustavo en «Sobre mí» y enlaza una
versión web del CV en `cv.html`, además del PDF descargable. El despliegue
habitual de GutsNet publica ambos archivos y la fotografía.

El contenido se concentra en `C0DE/web/cv.json`. Describe formación en curso
y proyectos académicos y personales; no atribuye empleos, certificaciones,
fechas de estudios o niveles de idiomas que no estén confirmados. El contacto
publicado es el perfil de GitHub. La fotografía original está en
`C0DE/web/public/assets/img/gustavo-ruiz-luis.jpg`.

## Actualizar el contenido

1. Editar `C0DE/web/cv.json` con información confirmada.
2. En un entorno con Python y ReportLab, ejecutar desde la raíz:

```bash
python3 scripts/build-cv.py
python3 scripts/version-web-assets.py
python3 scripts/version-web-assets.py --check
```

El generador utiliza DejaVu Sans cuando está instalada y Helvetica como
alternativa. Produce `C0DE/web/public/cv.html` y
`C0DE/web/public/assets/docs/Gustavo_Ruiz_Luis_CV.pdf`. El PDF contiene texto
seleccionable y enlaces a los repositorios; el generador rechaza contenido
que exceda la página. Después de cambiarlo, revisar visualmente el PDF y las
versiones de escritorio y móvil antes de publicar.

Los archivos generados se versionan: el servidor Apache no necesita ReportLab
ni regenerar el CV durante el despliegue. Para publicarlos en el servidor:

```bash
make preview
make deploy
```
