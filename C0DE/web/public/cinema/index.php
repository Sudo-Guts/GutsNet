<?php
declare(strict_types=1);
require __DIR__ . "/common.php";
header("Content-Type: text/html; charset=utf-8");

$flash = $_SESSION["flash"] ?? null;
unset($_SESSION["flash"]);
session_write_close();
$storageAvailable = cinemaStorageAvailable();
$canManage = cinemaCanManage();
$movies = [];
if ($storageAvailable) {
    try {
        $movies = cinemaCatalog();
    } catch (Throwable $error) {
        error_log("GutsCinema: " . $error->getMessage());
        $storageAvailable = false;
        $canManage = false;
    }
}
if (!$storageAvailable) {
    http_response_code(503);
}
?>
<!DOCTYPE html>
<html lang="es-MX">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="robots" content="noindex, nofollow">
    <meta name="theme-color" content="#ffffff">
    <title>GutsCinema | Videos y música</title>
    <link rel="icon" href="../assets/img/favicon.svg?v=2ca871dd7910" type="image/svg+xml">
    <link rel="stylesheet" href="../assets/css/style.css?v=8bddbe37b28e">
    <link rel="stylesheet" href="../assets/css/cinema.css?v=0af8a53b21ae">
    <script src="../assets/js/cinema.js?v=8c39a7ff2914" defer></script>
</head>
<body>
    <a class="skip-link" href="#contenido">Ir al contenido</a>
    <header class="site-header"><div class="container header-content">
        <a class="logo" href="./" aria-label="GutsCinema, inicio"><span class="logo-symbol" aria-hidden="true">g<span>.</span></span>GutsCinema</a>
        <nav aria-label="Navegación de Cinema"><a href="../#multimedia">← Volver a GutsNet</a></nav>
    </div></header>
    <main id="contenido" class="section cinema-main" data-cinema-catalog>
        <div class="container">
            <div class="cinema-intro"><div><p class="eyebrow">EL RINCÓN MULTIMEDIA DE GUTSNET</p><h1 class="section-title">Mi sala de <em>cine.</em></h1><p class="section-description">Videos para acomodarse. Música para acompañar.</p></div><span class="cinema-account">Acceso privado · <?= escapeHtml($cinemaUser) ?></span></div>

            <?php if (is_array($flash) && is_string($flash["message"] ?? null)): ?>
                <p class="cinema-notice <?= ($flash["ok"] ?? false) ? "cinema-notice-success" : "cinema-notice-error" ?>" role="status"><?= escapeHtml($flash["message"]) ?></p>
            <?php endif; ?>

            <?php if (!$storageAvailable): ?>
                <div class="card cinema-empty"><h2>La sala no está disponible</h2><p>No se pudo abrir la biblioteca. Intenta de nuevo más tarde.</p></div>
            <?php else: ?>
                <section class="cinema-upload-panel" aria-labelledby="cinema-upload-title">
                    <div><p class="eyebrow">UN ARCHIVO MÁS PARA LA COLECCIÓN</p><h2 id="cinema-upload-title">Agrega un video o una canción</h2><p id="cinema-upload-hint">MP4 o MP3 · hasta 2 GiB por archivo. Si el nombre ya existe, elige otro antes de subirlo.</p></div>
                    <?php if ($canManage): ?>
                        <form id="cinema-upload" action="/cinema/manage.php" method="post" enctype="multipart/form-data">
                            <input type="hidden" name="action" value="upload">
                            <input type="hidden" name="csrf" value="<?= escapeHtml($cinemaCsrf) ?>">
                            <input type="hidden" name="MAX_FILE_SIZE" value="<?= CINEMA_MAX_BYTES ?>">
                            <div class="cinema-upload-fields">
                                <div class="cinema-file-field"><label for="cinema-file">Archivo de tu dispositivo</label><input id="cinema-file" type="file" name="media" accept=".mp4,.mp3,video/mp4,audio/mpeg" required aria-describedby="cinema-upload-hint" data-max-bytes="<?= CINEMA_MAX_BYTES ?>"></div>
                                <button class="cinema-upload-button" id="cinema-upload-button" type="submit">Subir archivo <span aria-hidden="true">↑</span></button>
                            </div>
                            <div id="cinema-upload-progress" class="cinema-upload-progress" hidden><label for="cinema-progress">Progreso de la carga</label><progress id="cinema-progress" max="100" value="0"></progress></div>
                            <p id="cinema-upload-status" class="cinema-upload-status" role="status" aria-live="polite"></p>
                            <noscript><p class="cinema-upload-hint">La página se actualizará cuando termine la carga. Mantén esta pestaña abierta.</p></noscript>
                        </form>
                    <?php else: ?>
                        <p class="cinema-notice">Puedes reproducir la biblioteca. La carga y eliminación no están disponibles en este momento.</p>
                    <?php endif; ?>
                </section>

                <?php if ($movies === []): ?>
                    <div class="card cinema-empty"><h2>La sala está lista</h2><p>Todavía no hay archivos. Agrega tu primer video o canción para empezar.</p></div>
                <?php else: ?>
                    <div class="cinema-toolbar"><div class="cinema-search" id="cinema-search-controls" hidden><label for="cinema-search">Buscar en mi biblioteca</label><div><input id="cinema-search" type="search" placeholder="Escribe el título de un video o canción" autocomplete="off"><button id="cinema-clear" type="button">Limpiar</button></div></div><p id="cinema-count" role="status"><?= count($movies) ?> archivos disponibles</p></div>
                    <div class="cinema-grid">
                        <?php foreach ($movies as $movie): ?>
                            <article class="cinema-movie" data-title="<?= escapeHtml($movie["title"]) ?>">
                                <?php if ($movie["audio"]): ?>
                                    <div class="cinema-audio"><span class="cinema-audio-symbol" aria-hidden="true">♫</span><span class="cinema-audio-label">PARA ESCUCHAR</span><audio controls preload="none" aria-label="<?= escapeHtml($movie["title"]) ?>"><source src="/cinema/media/<?= rawurlencode($movie["filename"]) ?>" type="audio/mpeg">Tu navegador no admite este formato de audio.</audio></div>
                                <?php else: ?>
                                    <video class="project-video" controls preload="none" playsinline poster="../assets/img/cinema-poster.svg?v=2e0199750683" aria-label="<?= escapeHtml($movie["title"]) ?>">
                                        <source src="/cinema/media/<?= rawurlencode($movie["filename"]) ?>" type="<?= escapeHtml($movie["mime"]) ?>">
                                        Tu navegador no admite este formato de video.
                                    </video>
                                <?php endif; ?>
                                <div class="cinema-movie-info"><h2><?= escapeHtml($movie["title"]) ?></h2><span><?= escapeHtml($movie["extension"]) ?></span></div>
                                <div class="cinema-file-meta"><span><?= escapeHtml(cinemaSize($movie["size"])) ?></span><span><?= $movie["audio"] ? "Audio" : "Video" ?></span></div>
                                <?php if ($canManage): ?>
                                    <details class="cinema-delete">
                                        <summary>Eliminar archivo</summary>
                                        <div class="cinema-delete-confirm"><p>¿Eliminar <strong><?= escapeHtml($movie["filename"]) ?></strong> de la biblioteca? Se borrará del servidor.</p>
                                            <form action="/cinema/manage.php" method="post">
                                                <input type="hidden" name="action" value="delete">
                                                <input type="hidden" name="csrf" value="<?= escapeHtml($cinemaCsrf) ?>">
                                                <input type="hidden" name="filename" value="<?= escapeHtml($movie["filename"]) ?>">
                                                <input type="hidden" name="version" value="<?= escapeHtml($movie["version"]) ?>">
                                                <button class="cinema-delete-button" type="submit">Sí, eliminar archivo</button>
                                            </form>
                                            <p class="cinema-delete-cancel">Para cancelar, cierra «Eliminar archivo».</p>
                                        </div>
                                    </details>
                                <?php endif; ?>
                            </article>
                        <?php endforeach; ?>
                    </div>
                    <p class="cinema-no-results" id="cinema-no-results" hidden>No encontré archivos con ese título. Prueba con otra palabra.</p>
                <?php endif; ?>
            <?php endif; ?>
        </div>
    </main>
    <footer class="site-footer"><div class="container footer-content"><p>© 2026 GUTSCINEMA / GUTSNET</p><a class="text-link" href="../">Volver al taller ↗</a></div></footer>
</body>
</html>
