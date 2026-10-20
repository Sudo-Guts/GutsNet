"use strict";
const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const { resolve } = require("node:path");
const { runInNewContext } = require("node:vm");
const source = readFileSync(resolve(__dirname, "../C0DE/web/public/assets/js/cinema.js"), "utf8");

function element(title = "") {
    const classes = new Set();
    return {
        dataset: { title }, hidden: false, value: "", events: {}, textContent: "",
        disabled: false, files: [], attributes: {},
        classList: { add: (name) => classes.add(name), remove: (name) => classes.delete(name),
            contains: (name) => classes.has(name) },
        addEventListener(name, fn) { this.events[name] = fn; },
        setAttribute(name, value) { this.attributes[name] = value; },
        removeAttribute(name) { delete this.attributes[name]; },
        focus() { this.focused = true; }, pause() { this.paused = true; }
    };
}
const ids = Object.fromEntries(["cinema-search", "cinema-clear", "cinema-search-controls",
    "cinema-count", "cinema-no-results", "cinema-upload", "cinema-file", "cinema-upload-button",
    "cinema-upload-progress", "cinema-progress", "cinema-upload-status"]
    .map((key) => [key, element()]));
ids["cinema-search-controls"].hidden = true;
ids["cinema-file"].dataset.maxBytes = "2147483648";
ids["cinema-upload"].action = "/cinema/manage.php";
const movies = [element("Película de prueba"), element("Señales y sistemas")];
const players = [element(), element()]; // video y audio
const document = {
    getElementById: (id) => ids[id] || null,
    querySelectorAll: (selector) => selector === "video, audio" ? players : movies,
    addEventListener(name, fn) { this.ready = fn; }
};
const requests = [];
const redirects = [];
class Request {
    constructor() {
        this.events = {};
        this.upload = element();
        requests.push(this);
    }
    open(method, url) { this.method = method; this.url = url; }
    setRequestHeader(name, value) { this.accept = value; }
    addEventListener(name, fn) { this.events[name] = fn; }
    send(data) { this.data = data; }
    answer(status, payload) {
        this.status = status;
        this.responseText = payload;
        this.events.load();
    }
}
class Data {
    constructor(form) {
        assert.equal(form, ids["cinema-upload"]);
        assert.equal(ids["cinema-file"].disabled, false,
            "FormData debe capturar el archivo antes de deshabilitar su input");
    }
}
runInNewContext(source, { document, XMLHttpRequest: Request, FormData: Data,
    window: { location: { assign: (path) => redirects.push(path) } } });
document.ready();
assert.equal(ids["cinema-search-controls"].hidden, false);
for (const [query, visible] of [["pelicula", 1], ["SENALES", 1], ["inexistente", 0]]) {
    ids["cinema-search"].value = query;
    ids["cinema-search"].events.input();
    assert.equal(movies.filter((movie) => !movie.hidden).length, visible);
    assert.equal(ids["cinema-no-results"].hidden, visible > 0);
}
ids["cinema-clear"].events.click();
assert(movies.every((movie) => !movie.hidden));
assert(ids["cinema-search"].focused);
assert.equal(ids["cinema-count"].textContent, "2 de 2 archivos");
players[0].events.play();
assert(players[1].paused, "El video pausa el audio");
players[0].paused = false;
players[1].events.play();
assert(players[0].paused, "El audio pausa el video");

function submit(name, size) {
    ids["cinema-file"].files = [{ name, size }];
    let prevented = false;
    ids["cinema-upload"].events.submit({ preventDefault() { prevented = true; } });
    assert(prevented);
}
submit("archivo.php", 100);
submit("pelicula.mp4", 2147483649);
submit("vacio.mp3", 0);
assert.equal(requests.length, 0);
submit("Pelicula.MP4", 100);
assert.equal(requests.length, 1);
assert.equal(ids["cinema-upload-button"].disabled, true);
assert.equal(ids["cinema-upload-progress"].hidden, false);
assert.equal(requests[0].method, "POST");
assert.equal(requests[0].accept, "application/json");
submit("Pelicula.MP4", 100);
assert.equal(requests.length, 1, "No repite una carga mientras esta en curso");
requests[0].upload.events.progress({ lengthComputable: true, loaded: 50, total: 100 });
assert.equal(ids["cinema-progress"].value, 50);
assert(ids["cinema-upload-status"].textContent.includes("50%"));
requests[0].upload.events.progress({ lengthComputable: true, loaded: 100, total: 100 });
assert(ids["cinema-upload-status"].textContent.includes("Guardando"));
requests[0].answer(409, JSON.stringify({ ok: false, message: "Ya existe ese nombre." }));
assert.equal(ids["cinema-upload-button"].disabled, false);
assert.equal(ids["cinema-file"].disabled, false);
assert.equal(ids["cinema-upload-status"].textContent, "Ya existe ese nombre.");
assert(ids["cinema-upload-status"].classList.contains("is-error"));

submit("Cancion.mp3", 100);
requests[1].answer(413, "<html>Request too large</html>");
assert(ids["cinema-upload-status"].textContent.includes("tamaño permitido"));
submit("Cancion.mp3", 100);
requests[2].events.error();
assert(ids["cinema-upload-status"].textContent.includes("conexión"));
submit("Cancion.mp3", 100);
requests[3].answer(201, JSON.stringify({ ok: true, message: "Archivo agregado" }));
assert.deepEqual(redirects, ["/cinema/"]);

const emptyDocument = {
    getElementById() { return null; }, querySelectorAll() { return []; },
    addEventListener(name, fn) { this.ready = fn; }
};
runInNewContext(source, { document: emptyDocument });
emptyDocument.ready();
console.log("OK: busqueda, reproduccion exclusiva entre audio/video, carga y progreso, "
    + "validacion, duplicados, errores de red/413 y retorno al catalogo.");
