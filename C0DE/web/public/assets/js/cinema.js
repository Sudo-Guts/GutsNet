"use strict";

document.addEventListener("DOMContentLoaded", () => {
    const input = document.getElementById("cinema-search");
    const clear = document.getElementById("cinema-clear");
    const controls = document.getElementById("cinema-search-controls");
    const count = document.getElementById("cinema-count");
    const empty = document.getElementById("cinema-no-results");
    const movies = Array.from(document.querySelectorAll(".cinema-movie[data-title]"));
    if (input && clear && controls && count && empty && movies.length) {
        const normalize = (text) => text.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLocaleLowerCase("es-MX");
        function filter() {
            const query = normalize(input.value.trim());
            let visible = 0;
            movies.forEach((movie) => {
                movie.hidden = !normalize(movie.dataset.title).includes(query);
                if (!movie.hidden) visible += 1;
            });
            count.textContent = `${visible} de ${movies.length} archivos`;
            empty.hidden = visible !== 0;
        }
        function reset() {
            input.value = "";
            filter();
            input.focus();
        }
        controls.hidden = false;
        input.addEventListener("input", filter);
        clear.addEventListener("click", reset);
        input.addEventListener("keydown", (event) => {
            if (event.key === "Escape") reset();
        });
        filter();
    }
    const videos = Array.from(document.querySelectorAll("video, audio"));
    videos.forEach((current) => {
        current.addEventListener("play", () => {
            videos.forEach((other) => {
                if (other !== current) other.pause();
            });
        });
    });

    // El formulario sigue funcionando sin JavaScript; XHR agrega progreso y errores.
    const upload = document.getElementById("cinema-upload");
    const file = document.getElementById("cinema-file");
    const button = document.getElementById("cinema-upload-button");
    const progressBox = document.getElementById("cinema-upload-progress");
    const progress = document.getElementById("cinema-progress");
    const status = document.getElementById("cinema-upload-status");
    if (upload && file && button && progressBox && progress && status
        && typeof XMLHttpRequest !== "undefined" && typeof FormData !== "undefined") {
        let busy = false;
        function finishError(message) {
            busy = false;
            upload.setAttribute("aria-busy", "false");
            button.disabled = false;
            file.disabled = false;
            progressBox.hidden = true;
            status.classList.add("is-error");
            status.textContent = message;
        }
        upload.addEventListener("submit", (event) => {
            event.preventDefault();
            if (busy) return;
            const selected = file.files[0];
            if (!selected || !/\.(mp4|mp3)$/i.test(selected.name)) {
                finishError("Selecciona un archivo MP4 o MP3.");
                return;
            }
            if (selected.size > Number(file.dataset.maxBytes)) {
                finishError("El archivo supera el límite de 2 GiB.");
                return;
            }
            if (selected.size < 16) {
                finishError("El archivo está vacío o incompleto.");
                return;
            }
            const data = new FormData(upload);
            busy = true;
            upload.setAttribute("aria-busy", "true");
            button.disabled = true;
            file.disabled = true;
            status.classList.remove("is-error");
            status.textContent = "Subiendo archivo… Mantén esta pestaña abierta.";
            progress.value = 0;
            progressBox.hidden = false;
            const request = new XMLHttpRequest();
            request.open("POST", upload.action);
            request.setRequestHeader("Accept", "application/json");
            request.upload.addEventListener("progress", (update) => {
                if (update.lengthComputable) {
                    progress.value = Math.round(update.loaded / update.total * 100);
                    status.textContent = progress.value < 100
                        ? "Subiendo archivo… " + progress.value + "%"
                        : "Carga recibida. Guardando en la biblioteca…";
                } else {
                    progress.removeAttribute("value");
                }
            });
            request.addEventListener("load", () => {
                let response;
                try {
                    response = JSON.parse(request.responseText);
                } catch {
                    finishError(request.status === 413
                        ? "El archivo supera el tamaño permitido por el servidor."
                        : "No se pudo completar la carga. Recarga la página e intenta de nuevo.");
                    return;
                }
                if (request.status >= 200 && request.status < 300 && response.ok === true) {
                    status.textContent = response.message;
                    window.location.assign("/cinema/");
                } else {
                    finishError(typeof response.message === "string" ? response.message
                        : "No se pudo completar la carga. Intenta de nuevo.");
                }
            });
            request.addEventListener("error", () =>
                finishError("Se perdió la conexión. Revisa la biblioteca antes de intentar subir el archivo otra vez."));
            request.addEventListener("abort", () =>
                finishError("Se canceló la carga del archivo."));
            request.send(data);
        });
    }
});
