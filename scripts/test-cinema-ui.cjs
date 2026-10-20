"use strict";
const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const { resolve } = require("node:path");
const { runInNewContext } = require("node:vm");
const source = readFileSync(resolve(__dirname, "../C0DE/web/public/assets/js/cinema.js"), "utf8");
function element(title = "") {
    return {
        dataset: { title }, hidden: false, value: "", events: {}, textContent: "",
        addEventListener(name, fn) { this.events[name] = fn; },
        focus() { this.focused = true; }, pause() { this.paused = true; }
    };
}
const ids = Object.fromEntries(["cinema-search", "cinema-clear", "cinema-search-controls", "cinema-count", "cinema-no-results"].map((key) => [key, element()]));
ids["cinema-search-controls"].hidden = true;
const movies = [element("Película de prueba"), element("Señales y sistemas")];
const videos = [element(), element()];
const document = {
    getElementById: (id) => ids[id],
    querySelectorAll: (selector) => selector === "video" ? videos : movies,
    addEventListener(name, fn) { this.ready = fn; }
};
runInNewContext(source, { document });
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
assert.equal(ids["cinema-count"].textContent, "2 de 2 videos");
videos[0].events.play();
assert(videos[1].paused);
const emptyDocument = { getElementById() { return null; }, querySelectorAll() { return []; }, addEventListener(name, fn) { this.ready = fn; } };
runInNewContext(source, { document: emptyDocument });
emptyDocument.ready();
console.log("OK: busqueda de Cinema sin distincion de acentos, limpiar, sin resultados y reproduccion exclusiva.");
