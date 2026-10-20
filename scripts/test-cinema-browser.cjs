"use strict";
// Navegador real contra Apache de pruebas; limpia solo sus propios archivos.
const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const { resolve } = require("node:path");
const { randomBytes } = require("node:crypto");
const { chromium } = require("playwright");

async function main() {
    const password = readFileSync(0, "utf8").replace(/[\r\n]+$/, "");
    assert(password, "Falta la contraseña de Cinema por stdin.");
    const catalog = new URL(process.env.CINEMA_BROWSER_URL || "https://127.0.0.1/cinema/");
    assert.equal(catalog.protocol, "https:");
    assert.equal(catalog.pathname, "/cinema/");
    const browser = await chromium.launch({ headless: true });
    // Solo este navegador de CI acepta la CA efimera. test.sh valida TLS con --cacert.
    const context = await browser.newContext({
        ignoreHTTPSErrors: true,
        httpCredentials: { username: process.env.CINEMA_BROWSER_USER || "cine", password }
    });
    const page = await context.newPage();
    page.setDefaultTimeout(15000);
    const errors = [];
    page.on("pageerror", (error) => errors.push(error.message));
    const prefix = "GutsCinema_navegador_" + randomBytes(12).toString("hex");
    const fixtures = [
        { name: prefix + ".mp4", file: "assets/video/demostracion.mp4", mime: "video/mp4" },
        { name: prefix + ".mp3", file: "assets/audio/ambiente2.mp3", mime: "audio/mpeg" }
    ];
    const cardFor = (name) => page.locator(".cinema-movie").filter({
        has: page.locator(`input[name="filename"][value="${name}"]`)
    });
    const nextPost = () => page.waitForResponse((response) => response.request().method() === "POST");
    async function remove(name) {
        await page.goto(catalog.href);
        const card = cardFor(name);
        if (await card.count() === 0) return;
        await card.locator("summary").click();
        const pending = nextPost();
        await card.locator("button[type=submit]").click();
        const response = await pending;
        assert.equal(new URL(response.url()).pathname, "/cinema/manage.php");
        assert.equal(response.status(), 303, "La baja por formulario debe redirigir al catálogo.");
        await page.waitForFunction((filename) => !Array.from(
            document.querySelectorAll('input[name="filename"]')
        ).some((input) => input.value === filename), name);
        const missing = await context.request.get(new URL("/cinema/media/" + name, catalog).href);
        assert.equal(missing.status(), 404, "El archivo propio de prueba debe quedar eliminado.");
    }
    try {
        const initial = await page.goto(catalog.href);
        assert.equal(initial.status(), 200);
        assert.equal(await page.locator("#cinema-upload").evaluate((form) =>
            form.action instanceof HTMLInputElement), true,
        "La prueba debe cubrir el control action que oculta la propiedad del formulario.");
        for (const fixture of fixtures) {
            const buffer = readFileSync(resolve(__dirname, "../C0DE/web/public", fixture.file));
            await page.locator("#cinema-file").setInputFiles({
                name: fixture.name, mimeType: fixture.mime, buffer
            });
            const pending = nextPost();
            await page.locator("#cinema-upload-button").click();
            const response = await pending;
            assert.equal(new URL(response.url()).pathname, "/cinema/manage.php",
                "La carga debe llegar a manage.php y no a [object HTMLInputElement].");
            assert.equal(response.status(), 201, "La carga desde el navegador debe crear el archivo.");
            // La tarjeta confirma que el cliente proceso el JSON y recargo el catalogo.
            // Chromium puede descartar el cuerpo XHR cuando comienza esa navegacion.
            await cardFor(fixture.name).waitFor({ state: "attached" });
            const partial = await context.request.get(
                new URL("/cinema/media/" + fixture.name, catalog).href,
                { headers: { Range: "bytes=0-15" } }
            );
            assert.equal(partial.status(), 206);
            assert.deepEqual(await partial.body(), buffer.subarray(0, 16));
            await remove(fixture.name);
        }
        assert.deepEqual(errors, [], "No debe haber errores de JavaScript.");
        console.log("OK: Chromium carga MP4/MP3 por XHR a manage.php, verifica Range y elimina por formulario.");
    } finally {
        for (const fixture of fixtures) {
            try { await remove(fixture.name); }
            catch (error) { console.error("ERROR al limpiar archivo propio:", error.message); process.exitCode = 1; }
        }
        await browser.close();
    }
}
main().catch((error) => { console.error(error); process.exitCode = 1; });
