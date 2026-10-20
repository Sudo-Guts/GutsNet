
"use strict";

// ============================================================
// GutsNet - Main JavaScript
// ============================================================

document.addEventListener("DOMContentLoaded", () => {
    initVisitCounter();
    initMusicPlayer();
});

// ============================================================
// Visit Counter
// ============================================================

async function initVisitCounter() {
    const counter = document.getElementById("contador-visitas");

    if (!counter) {
        return;
    }

    try {
        const response = await fetch("/api/visitas.php", {
            method: "POST",
            cache: "no-store"
        });

        if (!response.ok) {
            throw new Error(`HTTP ${response.status}`);
        }

        const data = await response.json();

        if (!Number.isSafeInteger(data.visitas) ||
            data.visitas < 0) {
            throw new Error("Respuesta invalida");
        }

        counter.textContent = new Intl.NumberFormat(
            "es-MX"
        ).format(data.visitas);

    } catch (error) {
        counter.textContent = "No disponible";

        console.error(
            "GutsNet - Error del contador:",
            error
        );
    }
}

// ============================================================
// Ambient Music
// ============================================================

function initMusicPlayer() {
    // --------------------------------------------------------
    // Elements
    // --------------------------------------------------------

    const audio = document.getElementById("musica-ambiental");
    const toggle = document.getElementById("music-toggle");
    const next = document.getElementById("music-next");
    const volume = document.getElementById("music-volume");
    const title = document.getElementById("music-title");

    if (!audio || !toggle || !next || !volume || !title) {
        return;
    }

    // --------------------------------------------------------
    // Playlist
    // --------------------------------------------------------

    const playlist = [
        {
            name: "Música ambiental 1",
            file: "/assets/audio/ambiente1.mp3"
        },
        {
            name: "Música ambiental 2",
            file: "/assets/audio/ambiente2.mp3"
        }
    ];

    let currentTrack = 0;

    // --------------------------------------------------------
    // Configuration
    // --------------------------------------------------------

    audio.volume = Number(volume.value) / 100;

    // --------------------------------------------------------
    // Load Track
    // --------------------------------------------------------

    function loadTrack(index) {
        currentTrack = (
            index + playlist.length
        ) % playlist.length;

        const track = playlist[currentTrack];

        audio.src = track.file;
        title.textContent = track.name;

        audio.load();
    }

    // --------------------------------------------------------
    // Play Music
    // --------------------------------------------------------

    async function playMusic() {
        try {
            await audio.play();

        } catch (error) {
            if (error.name === "AbortError") {
                return;
            }

            console.error(
                "GutsNet - Error de audio:",
                error
            );

            title.textContent = "Audio no disponible";
        }
    }

    // --------------------------------------------------------
    // Toggle Play / Pause
    // --------------------------------------------------------

    toggle.addEventListener("click", () => {
        if (audio.paused) {
            playMusic();
        } else {
            audio.pause();
        }
    });

    // --------------------------------------------------------
    // Next Track
    // --------------------------------------------------------

    next.addEventListener("click", () => {
        const wasPlaying = !audio.paused;

        audio.pause();

        loadTrack(currentTrack + 1);

        if (wasPlaying) {
            playMusic();
        }
    });

    // --------------------------------------------------------
    // Automatic Next Track
    // --------------------------------------------------------

    audio.addEventListener("ended", () => {
        loadTrack(currentTrack + 1);
        playMusic();
    });

    // --------------------------------------------------------
    // Player State
    // --------------------------------------------------------

    audio.addEventListener("play", () => {
        toggle.textContent = "Pausar";
        toggle.setAttribute("aria-pressed", "true");
    });

    audio.addEventListener("pause", () => {
        toggle.textContent = "Reproducir";
        toggle.setAttribute("aria-pressed", "false");
    });

    // --------------------------------------------------------
    // Volume
    // --------------------------------------------------------

    volume.addEventListener("input", () => {
        const value = Number(volume.value);

        audio.volume = Math.max(
            0,
            Math.min(1, value / 100)
        );
    });

    // --------------------------------------------------------
    // Initialization
    // --------------------------------------------------------

    loadTrack(0);
}

