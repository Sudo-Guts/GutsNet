<?php
declare(strict_types=1);

/*
 * GutsNet Cinema
 *
 * Esta pagina debe publicarse SOLAMENTE detras del VirtualHost HTTPS
 * y de la autenticacion Basic definida en SERVER/apache/gutsnet-ssl.conf.
 *
 * Los videos se almacenan fuera del DocumentRoot y Apache los sirve
 * mediante Alias, preservando las solicitudes Range del navegador.
 */

if (($_SERVER["HTTPS"] ?? "") !== "on") {
    http_response_code(403);
    header("Content-Type: text/plain; charset=utf-8");
    echo "GutsNet Cinema requiere HTTPS.";
    exit;
}

header("Content-Type: text/html; charset=utf-8");
header("Cache-Control: private, no-store");

$storage = "/home/gutsnet-shared/peliculas";
$allowedMimeTypes = [
    "mp4"  => "video/mp4",
    "webm" => "video/webm",
    "ogv"  => "video/ogg"
];

$movies = [];
$storageAvailable = is_dir($storage) && is_readable($storage);

if ($storageAvailable) {
    try {
        foreach (new DirectoryIterator($storage) as $entry) {
            if (!$entry->isFile() || $entry->isLink()) {
                continue;
            }

            $filename = $entry->getFilename();

            if ($filename === "" || $filename[0] === ".") {
                continue;
            }

            $extension = strtolower(pathinfo($filename, PATHINFO_EXTENSION));

            if (!array_key_exists($extension, $allowedMimeTypes)) {
                continue;
            }

            $title = pathinfo($filename, PATHINFO_FILENAME);
            $title = str_replace(["_", "-"], " ", $title);

            $movies[] = [
                "title" => $title,
                "filename" => $filename,
                "mime" => $allowedMimeTypes[$extension]
            ];
        }
    } catch (Throwable $error) {
        error_log("GutsNet Cinema: " . $error->getMessage());
        $storageAvailable = false;
        $movies = [];
    }
}

usort($movies, static function (array $a, array $b): int {
    return strnatcasecmp($a["title"], $b["title"]);
});

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
    <title>GutsNet Cinema | Biblioteca privada</title>
    <link rel="icon" href="../assets/img/favicon.svg?v=2ca871dd7910" type="image/svg+xml">
    <link rel="stylesheet" href="../assets/css/style.css?v=8bddbe37b28e">
</head>
<body>
    <a class="skip-link" href="#contenido">Ir al contenido</a>
    <header class="site-header">
        <div class="container header-content">
            <a class="logo" href="../" aria-label="GutsNet, inicio">
                <span class="logo-symbol" aria-hidden="true">g<span>.</span></span>
                GutsNet<span class="logo-caption">hardware<br>y software</span>
            </a>

            <nav aria-label="Navegación de Cinema">
                <a href="../#multimedia">← Volver al taller</a>
            </nav>
        </div>
    </header>

    <main id="contenido" class="section">
        <div class="container">
            <p class="eyebrow">ACCESO PRIVADO</p>
            <h1 class="section-title">GutsNet Cinema</h1>
            <p class="section-description">
                Biblioteca multimedia de acceso restringido.
                El rincón de películas del servidor de GutsNet.
            </p>

            <?php if (!$storageAvailable): ?>
                <div class="card">
                    <h2>Biblioteca no disponible</h2>
                    <p>
                        El directorio de películas todavía no está configurado
                        o el servidor no tiene permisos de lectura.
                    </p>
                </div>
            <?php elseif ($movies === []): ?>
                <div class="card">
                    <h2>Sin películas por el momento</h2>
                    <p>
                        La biblioteca privada ya está preparada.
                        Las películas aparecerán aquí cuando se agreguen al servidor.
                    </p>
                </div>
            <?php else: ?>
                <div class="about-grid">
                    <?php foreach ($movies as $movie): ?>
                        <article class="card multimedia-card">
                            <h2><?= escapeHtml($movie["title"]) ?></h2>

                            <video
                                class="project-video"
                                controls
                                preload="metadata"
                                playsinline
                            >
                                <source
                                    src="/cinema/media/<?= rawurlencode($movie["filename"]) ?>"
                                    type="<?= escapeHtml($movie["mime"]) ?>"
                                >
                                Tu navegador no admite este formato de video.
                            </video>
                        </article>
                    <?php endforeach; ?>
                </div>
            <?php endif; ?>
        </div>
    </main>

    <footer class="site-footer">
        <div class="container footer-content">
            <p>© 2026 GutsNet</p>
            <p>GUTSNET / BIBLIOTECA PRIVADA</p>
        </div>
    </footer>
</body>
</html>
