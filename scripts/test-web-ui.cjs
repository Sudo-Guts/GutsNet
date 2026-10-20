"use strict";

// Pruebas de comportamiento con APIs DOM mínimas. No sustituyen el renderizado
// ni la reproducción real del navegador. Se ejecutan con Node, sin paquetes.
const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const { resolve } = require("node:path");
const { runInNewContext } = require("node:vm");
const source = readFileSync(resolve(__dirname, "../C0DE/web/public/assets/js/main.js"), "utf8");

class Element {
    constructor(textContent = "", dataset = {}) {
        this.textContent = textContent;
        this.dataset = dataset;
        this.attributes = {};
        this.events = {};
        this.hidden = false;
    }
    setAttribute(name, value) { this.attributes[name] = value; }
    getAttribute(name) { return this.attributes[name]; }
    addEventListener(name, callback) { this.events[name] = callback; }
    async fire(name, event = {}) { return this.events[name]?.(event); }
    focus() { this.focused = true; }
}

function environment({ ids = {}, selectors = {}, lists = {}, window = {}, fetch } = {}) {
    const events = {};
    const document = {
        baseURI: "https://example.test/GutsNet/index.html",
        getElementById: (id) => ids[id] || null,
        querySelector: (selector) => selectors[selector] || null,
        querySelectorAll: (selector) => lists[selector] || [],
        addEventListener: (event, callback) => { events[event] = callback; }
    };
    const context = { document, window, fetch, URL, Intl, console: { error() {} } };
    runInNewContext(source, context);
    return { context, events };
}

async function test() {
    // Las páginas secundarias no contienen controles de la portada.
    const empty = environment();
    empty.events.DOMContentLoaded();

    const scope = environment().context;
    const points = scope.buildSignalPath(2, 0.6).split(" ").map((point) => point.slice(1).split(",").map(Number));
    assert.equal(points.length, 441);
    assert.deepEqual(points[0], [20, 115]);
    assert.deepEqual(points[55], [75, 67]);
    assert.deepEqual(points[165], [185, 163]);
    assert.deepEqual(points[440], [460, 115]);
    for (const frequency of [1, 2.5, 5]) {
        for (const amplitude of [0.1, 0.6, 1]) {
            const path = scope.buildSignalPath(frequency, amplitude);
            const heights = path.split(" ").map((point) => Number(point.split(",")[1]));
            assert(heights.every((height) => height >= 35 && height <= 195));
        }
    }

    const frequency = new Element();
    frequency.value = "2";
    frequency.disabled = true;
    const amplitude = new Element();
    amplitude.value = "0.6";
    amplitude.disabled = true;
    const signalPath = new Element();
    const frequencyValue = new Element();
    const amplitudeValue = new Element();
    const description = new Element();
    const signal = environment({ ids: {
        "signal-frequency": frequency, "signal-amplitude": amplitude,
        "signal-path": signalPath, "frequency-value": frequencyValue,
        "amplitude-value": amplitudeValue, "signal-description": description
    } });
    signal.context.initSignal();
    assert.equal(frequency.disabled, false);
    assert.equal(amplitude.disabled, false);
    const initialPath = signalPath.getAttribute("d");
    frequency.value = "5";
    amplitude.value = "1";
    await frequency.fire("input");
    assert.notEqual(signalPath.getAttribute("d"), initialPath);
    assert.equal(frequencyValue.textContent, "5 Hz");
    assert.equal(amplitudeValue.textContent, "1.0");
    assert(description.textContent.includes("5 Hz"));

    const buttons = ["all", "hardware", "senales", "linux"].map((filter) => new Element(filter, { filter }));
    const categories = ["hardware senales", "hardware", "hardware senales", "linux", "linux", "hardware"];
    const projects = categories.map((category) => new Element("", { category }));
    const group = new Element();
    group.hidden = true;
    group.querySelectorAll = () => buttons;
    const status = new Element();
    const filters = environment({
        ids: { "filter-status": status },
        selectors: { ".project-filters": group },
        lists: { ".project-card[data-category]": projects }
    });
    filters.context.initProjectFilters();
    assert.equal(group.hidden, false);
    for (const [index, expected] of [[1, 4], [2, 2], [3, 2], [0, 6]]) {
        await buttons[index].fire("click");
        assert.equal(projects.filter((project) => !project.hidden).length, expected);
        assert.equal(buttons.filter((button) => button.getAttribute("aria-pressed") === "true").length, 1);
        assert(status.textContent.startsWith(`${expected} proyectos`));
    }

    const nav = new Element();
    const toggle = new Element();
    const plus = new Element("+");
    toggle.querySelector = () => plus;
    const media = { matches: true, addEventListener(name, callback) { this.change = callback; } };
    const menu = environment({ ids: { "menu-toggle": toggle, "main-nav": nav }, window: { matchMedia: () => media } });
    menu.context.initMenu();
    assert(nav.hidden);
    assert.equal(toggle.hidden, false);
    await toggle.fire("click");
    assert.equal(nav.hidden, false);
    assert.equal(toggle.getAttribute("aria-expanded"), "true");
    menu.events.keydown({ key: "Escape" });
    assert(nav.hidden && toggle.focused);
    await toggle.fire("click");
    await nav.fire("click", { target: { closest: () => ({}) } });
    assert(nav.hidden);
    media.matches = false;
    media.change();
    assert.equal(nav.hidden, false);
    assert(toggle.hidden);

    const counter = new Element();
    let requested;
    const visits = environment({ ids: { "contador-visitas": counter }, fetch: async (url, options) => {
        requested = { url: url.href, options };
        return { ok: true, json: async () => ({ visitas: 1234 }) };
    } });
    await visits.context.initVisitCounter();
    assert.equal(requested.url, "https://example.test/GutsNet/api/visitas.php");
    assert.equal(requested.options.method, "POST");
    assert.equal(counter.textContent, new Intl.NumberFormat("es-MX").format(1234));
    for (const value of [-1, "14", 1.2, Number.MAX_SAFE_INTEGER + 1]) {
        const invalid = environment({ ids: { "contador-visitas": counter }, fetch: async () => ({ ok: true, json: async () => ({ visitas: value }) }) });
        await invalid.context.initVisitCounter();
        assert.equal(counter.textContent, "No disponible");
    }
    const offline = environment({ ids: { "contador-visitas": counter }, fetch: async () => { throw new Error("offline"); } });
    await offline.context.initVisitCounter();
    assert.equal(counter.textContent, "No disponible");

    const audio = new Element();
    audio.paused = true;
    audio.load = () => {};
    audio.play = async () => { audio.paused = false; await audio.fire("play"); };
    audio.pause = () => { audio.paused = true; audio.fire("pause"); };
    const play = new Element();
    const next = new Element();
    const volume = new Element();
    volume.value = "20";
    const title = new Element();
    const video = new Element();
    const music = environment({ ids: {
        "musica-ambiental": audio, "music-toggle": play, "music-next": next,
        "music-volume": volume, "music-title": title
    }, lists: { video: [video] } });
    music.context.initMusicPlayer();
    assert.equal(audio.paused, true, "La música no debe empezar sola");
    assert.equal(audio.volume, 0.2);
    assert.equal(audio.src, "https://example.test/GutsNet/assets/audio/ambiente1.mp3");
    await next.fire("click");
    assert(audio.paused);
    assert.equal(title.textContent, "Música ambiental 2");
    await play.fire("click");
    assert.equal(play.getAttribute("aria-pressed"), "true");
    await next.fire("click");
    assert.equal(audio.paused, false);
    assert.equal(title.textContent, "Música ambiental 1");
    await video.fire("play");
    assert(audio.paused);
    assert.equal(play.getAttribute("aria-pressed"), "false");
    await audio.fire("error");
    assert(title.textContent.includes("no disponible"));
    volume.value = "140";
    await volume.fire("input");
    assert.equal(audio.volume, 1);
    console.log("OK: señal, filtros, menú móvil, contador y audio; páginas sin controles.");
}

test().catch((error) => { console.error(error); process.exitCode = 1; });
