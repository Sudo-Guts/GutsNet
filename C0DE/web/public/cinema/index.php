<?php
declare(strict_types=1);

// Apache autentica tanto este catalogo como cada URL de /cinema/media/.
if (($_SERVER["HTTPS"] ?? "") !== "on") {
    http_response_code(403);
    header("Content-Type: text/plain; charset=utf-8");
    exit("GutsCinema requiere HTTPS.");
}
if (trim((string) ($_SERVER["REMOTE_USER"] ?? "")) === "") {
    http_response_code(401);
    header("Content-Type: text/plain; charset=utf-8");
    exit("GutsCinema requiere una cuenta autenticada por Apache.");
}
header("Content-Type: text/html; charset=utf-8");
header("Cache-Control: private, no-store");
header("X-Content-Type-Options: nosniff");

$storage = "/home/gutsnet-shared/peliculas";
$allowedMimeTypes = ["mp4" => "video/mp4", "webm" => "video/webm", "ogv" => "video/ogg"];
$movies = [];
$storageAvailable = is_dir($storage) && is_readable($storage);
if ($storageAvailable) {
    try {
        foreach (new DirectoryIterator($storage) as $entry) {
            if (!$entry->isFile() || $entry->isLink() || !$entry->isReadable() || $entry->getSize() < 16) {
                continue;
            }
            $filename = $entry->getFilename();
            $extension = strtolower(pathinfo($filename, PATHINFO_EXTENSION));
            if ($filename === "" || $filename[0] === "." || !isset($allowedMimeTypes[$extension])) {
                continue;
            }
            $movies[] = [
                "title" => str_replace(["_", "-"], " ", pathinfo($filename, PATHINFO_FILENAME)),
                "filename" => $filename,
                "mime" => $allowedMimeTypes[$extension]
            ];
        }
    } catch (Throwable $error) {
        error_log("GutsCinema: " . $error->getMessage());
        $storageAvailable = false;
        $movies = [];
    }
}
usort($movies, static function (array $a, array $b): int {
    return strnatcasecmp($a["title"], $b["title"]);
});
if (!$storageAvailable) {
    http_response_code(503);
}
function escapeHtml(string $value): string
{
    return htmlspecialchars($value, ENT_QUOTES | ENT_SUBSTITUTE, "UTF-8");
}
?>
<!DOCTYPE html>
<html lang="es-MX">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="robots" content="noindex, nofollow">
    <meta name="theme-color" content="#ffffff">
    <title>GutsCinema | Mi sala de cine</title>
    <link rel="icon" href="../assets/img/favicon.svg?v=2ca871dd7910" type="image/svg+xml">
    <link rel="stylesheet" href="../assets/css/style.css?v=8bddbe37b28e">
    <link rel="stylesheet" href="../assets/css/cinema.css?v=f64137052a19">
    <script src="../assets/js/cinema.js?v=5f30def5d6a7" defer></script>
</head>
<body>
    <a class="skip-link" href="#contenido">Ir al contenido</a>
    <header class="site-header"><div class="container header-content">
        <a class="logo" href="./" aria-label="GutsCinema, inicio"><span class="logo-symbol" aria-hidden="true">g<span>.</span></span>GutsCinema</a>
        <nav aria-label="Navegación de Cinema"><a href="../#multimedia">← Volver a GutsNet</a></nav>
    </div></header>
    <main id="contenido" class="section cinema-main" data-cinema-catalog>
        <div class="container">
            <div class="cinema-intro"><div><p class="eyebrow">EL RINCÓN MULTIMEDIA DE GUTSNET</p><h1 class="section-title">Mi sala de <em>cine.</em></h1><p class="section-description">Elige un video, acomódate y dale play.</p></div><span class="cinema-account">Acceso privado · <?= escapeHtml((string) $_SERVER["REMOTE_USER"]) ?></span></div>
            <?php if (!$storageAvailable): ?>
                <div class="card cinema-empty"><h2>La sala no está disponible</h2><p>No se pudo abrir la biblioteca. Intenta de nuevo más tarde.</p></div>
            <?php elseif ($movies === []): ?>
                <div class="card cinema-empty"><h2>La sala está lista</h2><p>Todavía no hay videos en la biblioteca. Aparecerán aquí cuando los agregues al servidor.</p></div>
            <?php else: ?>
                <div class="cinema-toolbar"><div class="cinema-search" id="cinema-search-controls" hidden><label for="cinema-search">Buscar en mi biblioteca</label><div><input id="cinema-search" type="search" placeholder="Escribe el título de un video" autocomplete="off"><button id="cinema-clear" type="button">Limpiar</button></div></div><p id="cinema-count" role="status"><?= count($movies) ?> videos disponibles</p></div>
                <div class="cinema-grid">
                    <?php foreach ($movies as $movie): ?>
                        <article class="cinema-movie" data-title="<?= escapeHtml($movie["title"]) ?>">
                            <video class="project-video" controls preload="none" playsinline poster="../assets/img/cinema-poster.svg?v=2e0199750683" aria-label="<?= escapeHtml($movie["title"]) ?>">
                                <source src="/cinema/media/<?= rawurlencode($movie["filename"]) ?>" type="<?= escapeHtml($movie["mime"]) ?>">
                                Tu navegador no admite este formato de video.
                            </video>
                            <div class="cinema-movie-info"><h2><?= escapeHtml($movie["title"]) ?></h2><span><?= escapeHtml(strtoupper(pathinfo($movie["filename"], PATHINFO_EXTENSION))) ?></span></div>
                        </article>
                    <?php endforeach; ?>
                </div>
                <p class="cinema-no-results" id="cinema-no-results" hidden>No encontré videos con ese título. Prueba con otra palabra.</p>
            <?php endif; ?>
        </div>
    </main>
    <footer class="site-footer"><div class="container footer-content"><p>© 2026 GUTSCINEMA / GUTSNET</p><a class="text-link" href="../">Volver al taller ↗</a></div></footer>
</body>
</html>
