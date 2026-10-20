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
            count.textContent = `${visible} de ${movies.length} videos`;
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
    const videos = Array.from(document.querySelectorAll("video"));
    videos.forEach((current) => {
        current.addEventListener("play", () => {
            videos.forEach((other) => {
                if (other !== current) other.pause();
            });
        });
    });
});
