<?php
declare(strict_types=1);
require __DIR__ . "/common.php";

$json = str_contains((string) ($_SERVER["HTTP_ACCEPT"] ?? ""), "application/json");

function cinemaRespond(int $status, string $message): never
{
    global $json;
    $ok = $status < 400;
    if (!$json || $ok) {
        $_SESSION["flash"] = ["ok" => $ok, "message" => $message];
    }
    session_write_close();
    if ($json) {
        http_response_code($status);
        header("Content-Type: application/json; charset=utf-8");
        echo json_encode(["ok" => $ok, "message" => $message],
            JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    } else {
        header("Location: /cinema/", true, 303);
    }
    exit;
}

if (($_SERVER["REQUEST_METHOD"] ?? "") !== "POST") {
    session_write_close();
    http_response_code(405);
    header("Allow: POST");
    header("Content-Type: text/plain; charset=utf-8");
    exit("Usa el formulario de la biblioteca para agregar o eliminar archivos.");
}
// PHP vacia POST y FILES si se supera post_max_size. Da un error util en ese caso.
if ((int) ($_SERVER["CONTENT_LENGTH"] ?? 0) > CINEMA_MAX_BYTES + 2097152) {
    cinemaRespond(413, "El archivo supera el límite de 2 GiB.");
}
$token = $_POST["csrf"] ?? null;
if (!is_string($token) || !hash_equals($cinemaCsrf, $token)) {
    cinemaRespond(403, "La sesión del formulario venció. Recarga la página e intenta de nuevo.");
}
if (!cinemaCanManage()) {
    cinemaRespond(503, "La carga y eliminación de archivos no están disponibles en este momento.");
}

final class CinemaRequestError extends RuntimeException {}
function cinemaReject(int $status, string $message): never
{
    throw new CinemaRequestError($message, $status);
}
function cinemaLock()
{
    $path = CINEMA_INCOMING . "/.lock";
    if (is_link($path)) {
        cinemaReject(503, "La biblioteca no está disponible en este momento.");
    }
    $lock = @fopen($path, "c");
    if ($lock === false || !flock($lock, LOCK_EX)) {
        if (is_resource($lock)) {
            fclose($lock);
        }
        cinemaReject(503, "La biblioteca está ocupada. Intenta de nuevo.");
    }
    return $lock;
}

$status = 200;
$message = "";
$staged = null;
$lock = null;
try {
    $action = $_POST["action"] ?? null;
    if ($action === "upload") {
        $file = $_FILES["media"] ?? null;
        if (!is_array($file) || !is_int($file["error"] ?? null)
            || !is_string($file["name"] ?? null) || !is_string($file["tmp_name"] ?? null)) {
            cinemaReject(400, "Selecciona un archivo MP4 o MP3.");
        }
        if (in_array($file["error"], [UPLOAD_ERR_INI_SIZE, UPLOAD_ERR_FORM_SIZE], true)) {
            cinemaReject(413, "El archivo supera el tamaño permitido. El límite de la biblioteca es 2 GiB.");
        }
        if ($file["error"] !== UPLOAD_ERR_OK) {
            $errors = [
                UPLOAD_ERR_PARTIAL => "La carga quedó incompleta. Selecciona el archivo e intenta de nuevo.",
                UPLOAD_ERR_NO_FILE => "Selecciona un archivo MP4 o MP3.",
                UPLOAD_ERR_NO_TMP_DIR => "El servidor no puede recibir archivos en este momento.",
                UPLOAD_ERR_CANT_WRITE => "El servidor no pudo guardar el archivo. Revisa el espacio disponible.",
                UPLOAD_ERR_EXTENSION => "El servidor detuvo la carga del archivo."
            ];
            cinemaReject(400, $errors[$file["error"]] ?? "No se pudo recibir el archivo.");
        }
        $name = $file["name"];
        $extension = strtolower(pathinfo($name, PATHINFO_EXTENSION));
        if (!cinemaValidName($name) || !in_array($extension, ["mp4", "mp3"], true)) {
            cinemaReject(415, "Usa un archivo MP4 o MP3 con un nombre válido.");
        }
        $temporary = $file["tmp_name"];
        if (!is_uploaded_file($temporary)) {
            cinemaReject(400, "No se recibió un archivo válido.");
        }
        $size = filesize($temporary);
        if ($size === false || $size < 16) {
            cinemaReject(415, "El archivo está vacío o no contiene audio o video válido.");
        }
        if ($size > CINEMA_MAX_BYTES) {
            cinemaReject(413, "El archivo supera el límite de 2 GiB.");
        }
        // Inspeccion acotada: no carga peliculas completas en memoria.
        $handle = fopen($temporary, "rb");
        if ($handle === false) {
            cinemaReject(500, "No se pudo leer el archivo recibido.");
        }
        try {
            $sample = fread($handle, 65536);
        } finally {
            fclose($handle);
        }
        $mime = $sample === false ? false : (new finfo(FILEINFO_MIME_TYPE))->buffer($sample);
        $expected = [
            "mp4" => ["video/mp4", "application/mp4", "audio/mp4"],
            "mp3" => ["audio/mpeg", "audio/mp3", "audio/x-mpeg"]
        ];
        if (!in_array($mime, $expected[$extension], true)) {
            cinemaReject(415, "El contenido del archivo no corresponde a su extensión MP4 o MP3.");
        }
        $free = disk_free_space(CINEMA_STORAGE);
        if ($free !== false && $free < $size + 33554432) {
            cinemaReject(507, "No hay espacio suficiente en el servidor para guardar este archivo.");
        }
        $staged = tempnam(CINEMA_INCOMING, "upload-");
        if ($staged === false || dirname($staged) !== CINEMA_INCOMING) {
            cinemaReject(500, "No se pudo preparar la carga del archivo.");
        }
        // link() no hereda las ACL del directorio de destino:
        // es obligatorio publicar el archivo con el grupo compartido.
        $unified = is_file("/etc/gutsnet/media-unificada");
        if (!move_uploaded_file($temporary, $staged)
            || ($unified && !chgrp($staged, "gutsnet-files"))
            || !chmod($staged, $unified ? 0660 : 0640)) {
            cinemaReject(500, "No se pudo guardar el archivo.");
        }
        $lock = cinemaLock();
        $destination = CINEMA_STORAGE . "/" . $name;
        clearstatcache(true, $destination);
        if (@lstat($destination) !== false) {
            cinemaReject(409, "Ya existe un archivo con ese nombre. Renómbralo antes de subirlo.");
        }
        // link() publica de forma atomica y nunca reemplaza un destino existente.
        if (!@link($staged, $destination)) {
            clearstatcache(true, $destination);
            cinemaReject(@lstat($destination) !== false ? 409 : 500,
                "No se pudo agregar el archivo. Comprueba que el nombre no esté ocupado.");
        }
        $status = 201;
        $message = "Archivo agregado: " . $name;
    } elseif ($action === "delete") {
        $name = $_POST["filename"] ?? null;
        $version = $_POST["version"] ?? null;
        if (!is_string($name) || !cinemaValidName($name)
            || !isset(CINEMA_TYPES[strtolower(pathinfo($name, PATHINFO_EXTENSION))])
            || !is_string($version) || !preg_match('/\A[a-f0-9]{64}\z/', $version)) {
            cinemaReject(400, "La solicitud de eliminación no es válida.");
        }
        $lock = cinemaLock();
        $path = CINEMA_STORAGE . "/" . $name;
        clearstatcache(true, $path);
        $stat = @lstat($path);
        if ($stat === false) {
            cinemaReject(404, "El archivo ya no está en la biblioteca.");
        }
        if (($stat["mode"] & 0170000) !== 0100000 || is_link($path)) {
            cinemaReject(400, "Solo puedes eliminar archivos de la biblioteca, no enlaces ni carpetas.");
        }
        if (!hash_equals(cinemaFileVersion($stat), $version)) {
            cinemaReject(409, "El archivo cambió desde que abriste la página. Recárgala antes de eliminarlo.");
        }
        if (!unlink($path)) {
            cinemaReject(500, "No se pudo eliminar el archivo. Intenta de nuevo.");
        }
        $message = "Archivo eliminado: " . $name;
    } else {
        cinemaReject(400, "Elige agregar o eliminar un archivo.");
    }
} catch (CinemaRequestError $error) {
    $status = $error->getCode();
    $message = $error->getMessage();
} catch (Throwable $error) {
    error_log("GutsCinema: " . $error->getMessage());
    $status = 500;
    $message = "No se pudo completar la operación. Intenta de nuevo.";
} finally {
    if (is_resource($lock)) {
        flock($lock, LOCK_UN);
        fclose($lock);
    }
    if (is_string($staged) && is_file($staged) && !is_link($staged)) {
        unlink($staged);
    }
}
cinemaRespond($status, $message);
