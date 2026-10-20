"use strict";

// GutsNet · Interacciones sin dependencias.
// El contenido y los enlaces siguen disponibles si JavaScript está desactivado.
document.addEventListener("DOMContentLoaded", () => {
    initMenu();
    initSectionNavigation();
    initProjectFilters();
    initSignal();
    initVisitCounter();
    initMusicPlayer();
});

function initMenu() {
    const toggle = document.getElementById("menu-toggle");
    const nav = document.getElementById("main-nav");
    if (!toggle || !nav) {
        return;
    }

    const mobile = window.matchMedia("(max-width: 850px)");

    function setOpen(open) {
        nav.hidden = mobile.matches && !open;
        toggle.setAttribute("aria-expanded", String(open));
        toggle.querySelector("span").textContent = open ? "−" : "+";
    }

    function syncMenu() {
        toggle.hidden = !mobile.matches;
        setOpen(false);
    }

    toggle.addEventListener("click", () => {
        setOpen(toggle.getAttribute("aria-expanded") !== "true");
    });
    nav.addEventListener("click", (event) => {
        if (mobile.matches && event.target.closest("a")) {
            setOpen(false);
        }
    });
    document.addEventListener("keydown", (event) => {
        if (event.key === "Escape" && mobile.matches && !nav.hidden) {
            setOpen(false);
            toggle.focus();
        }
    });
    mobile.addEventListener("change", syncMenu);
    syncMenu();
}

function initSectionNavigation() {
    const links = Array.from(document.querySelectorAll('#main-nav a[href^="#"]'));
    if (!links.length || !("IntersectionObserver" in window)) {
        return;
    }

    const observer = new IntersectionObserver((entries) => {
        entries.forEach((entry) => {
            if (!entry.isIntersecting) {
                return;
            }
            const current = entry.target.id || "inicio";
            links.forEach((link) => {
                if (link.hash === `#${current}`) {
                    link.setAttribute("aria-current", "location");
                } else {
                    link.removeAttribute("aria-current");
                }
            });
        });
    }, { rootMargin: "-15% 0px -65% 0px", threshold: 0 });

    links.forEach((link) => {
        const section = link.hash === "#inicio"
            ? document.querySelector(".hero")
            : document.getElementById(link.hash.slice(1));
        if (section) {
            observer.observe(section);
        }
    });
}

function initProjectFilters() {
    const group = document.querySelector(".project-filters");
    const projects = Array.from(document.querySelectorAll(".project-card[data-category]"));
    const status = document.getElementById("filter-status");
    if (!group || !projects.length) {
        return;
    }

    const buttons = Array.from(group.querySelectorAll("button[data-filter]"));
    group.hidden = false;
    buttons.forEach((button) => {
        button.addEventListener("click", () => {
            const filter = button.dataset.filter;
            let visible = 0;
            projects.forEach((project) => {
                const categories = project.dataset.category.split(" ");
                project.hidden = filter !== "all" && !categories.includes(filter);
                if (!project.hidden) {
                    visible += 1;
                }
            });
            buttons.forEach((item) => {
                item.setAttribute("aria-pressed", String(item === button));
            });
            if (status) {
                status.textContent = `${visible} proyectos: ${button.textContent.trim()}.`;
            }
        });
    });
}

// Una ventana de un segundo y amplitud normalizada. No son datos adquiridos.
function buildSignalPath(frequency, amplitude) {
    const points = [];
    for (let index = 0; index <= 440; index += 1) {
        const time = index / 440;
        const x = 20 + index;
        const y = 115 - 80 * amplitude * Math.sin(2 * Math.PI * frequency * time);
        points.push(`${index === 0 ? "M" : "L"}${x},${y.toFixed(2)}`);
    }
    return points.join(" ");
}

function initSignal() {
    const frequency = document.getElementById("signal-frequency");
    const amplitude = document.getElementById("signal-amplitude");
    const path = document.getElementById("signal-path");
    const frequencyValue = document.getElementById("frequency-value");
    const amplitudeValue = document.getElementById("amplitude-value");
    const description = document.getElementById("signal-description");
    if (!frequency || !amplitude || !path || !frequencyValue || !amplitudeValue) {
        return;
    }

    function draw() {
        const f = Number(frequency.value);
        const a = Number(amplitude.value);
        path.setAttribute("d", buildSignalPath(f, a));
        frequencyValue.textContent = `${f} Hz`;
        amplitudeValue.textContent = a.toFixed(1);
        if (description) {
            description.textContent = `Señal senoidal sintética de ${f} Hz y amplitud normalizada ${a.toFixed(1)}, durante un segundo.`;
        }
    }

    frequency.disabled = false;
    amplitude.disabled = false;
    frequency.addEventListener("input", draw);
    amplitude.addEventListener("input", draw);
    draw();
}

async function initVisitCounter() {
    const counter = document.getElementById("contador-visitas");
    if (!counter) {
        return;
    }

    try {
        const response = await fetch(new URL("api/visitas.php", document.baseURI), {
            method: "POST",
            cache: "no-store"
        });
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}`);
        }
        const data = await response.json();
        if (!Number.isSafeInteger(data.visitas) || data.visitas < 0) {
            throw new Error("Respuesta inválida del contador");
        }
        counter.textContent = new Intl.NumberFormat("es-MX").format(data.visitas);
    } catch (error) {
        counter.textContent = "No disponible";
        console.error("GutsNet - Error del contador:", error);
    }
}

function initMusicPlayer() {
    const audio = document.getElementById("musica-ambiental");
    const toggle = document.getElementById("music-toggle");
    const next = document.getElementById("music-next");
    const volume = document.getElementById("music-volume");
    const title = document.getElementById("music-title");
    if (!audio || !toggle || !next || !volume || !title) {
        return;
    }

    const playlist = [
        { name: "Música ambiental 1", file: "assets/audio/ambiente1.mp3" },
        { name: "Música ambiental 2", file: "assets/audio/ambiente2.mp3" }
    ];
    let currentTrack = 0;
    audio.volume = Number(volume.value) / 100;

    function loadTrack(index) {
        currentTrack = (index + playlist.length) % playlist.length;
        const track = playlist[currentTrack];
        audio.src = new URL(track.file, document.baseURI).href;
        title.textContent = track.name;
        audio.load();
    }

    async function playMusic() {
        try {
            await audio.play();
        } catch (error) {
            if (error.name !== "AbortError") {
                title.textContent = "No se pudo reproducir esta pista";
                console.error("GutsNet - Error de audio:", error);
            }
        }
    }

    function syncPlayback() {
        toggle.textContent = audio.paused ? "Reproducir" : "Pausar";
        toggle.setAttribute("aria-pressed", String(!audio.paused));
    }

    toggle.addEventListener("click", () => {
        if (audio.paused) {
            playMusic();
        } else {
            audio.pause();
        }
    });
    next.addEventListener("click", () => {
        const wasPlaying = !audio.paused;
        audio.pause();
        loadTrack(currentTrack + 1);
        syncPlayback();
        if (wasPlaying) {
            playMusic();
        }
    });
    audio.addEventListener("ended", () => {
        loadTrack(currentTrack + 1);
        playMusic();
    });
    audio.addEventListener("play", syncPlayback);
    audio.addEventListener("pause", syncPlayback);
    audio.addEventListener("error", () => {
        title.textContent = "Pista no disponible. Prueba la siguiente.";
        syncPlayback();
    });
    volume.addEventListener("input", () => {
        audio.volume = Math.max(0, Math.min(1, Number(volume.value) / 100));
    });
    document.querySelectorAll("video").forEach((video) => {
        video.addEventListener("play", () => audio.pause());
    });
    loadTrack(0);
}
