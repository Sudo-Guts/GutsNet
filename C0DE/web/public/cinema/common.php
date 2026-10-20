<?php
declare(strict_types=1);

// Apache protege todo /cinema/; esta comprobacion tambien cubre accesos directos.
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
header("Cache-Control: private, no-store");
header("X-Content-Type-Options: nosniff");

const CINEMA_STORAGE = "/home/gutsnet-shared/peliculas";
const CINEMA_INCOMING = CINEMA_STORAGE . "/.incoming";
const CINEMA_MAX_BYTES = 2147483648; // 2 GiB; el cuerpo multipart tiene margen aparte.
const CINEMA_TYPES = [
    "mp4" => "video/mp4",
    "mp3" => "audio/mpeg",
    "webm" => "video/webm",
    "ogv" => "video/ogg"
];

session_name("guts_cinema");
if (!session_start([
    "use_strict_mode" => 1,
    "use_only_cookies" => 1,
    "cookie_secure" => true,
    "cookie_httponly" => true,
    "cookie_samesite" => "Strict",
    "cookie_path" => "/cinema/"
])) {
    http_response_code(503);
    exit("No se pudo abrir la sesión. Intenta de nuevo.");
}
$cinemaUser = (string) $_SERVER["REMOTE_USER"];
if (($_SESSION["user"] ?? null) !== $cinemaUser) {
    session_regenerate_id(true);
    $_SESSION = ["user" => $cinemaUser];
}
if (!isset($_SESSION["csrf"]) || !is_string($_SESSION["csrf"])) {
    $_SESSION["csrf"] = bin2hex(random_bytes(32));
}
$cinemaCsrf = $_SESSION["csrf"];

function escapeHtml(string $value): string
{
    return htmlspecialchars($value, ENT_QUOTES | ENT_SUBSTITUTE, "UTF-8");
}

function cinemaValidName(string $name): bool
{
    return $name !== "" && $name === trim($name) && $name[0] !== "."
        && strlen($name) <= 240 && preg_match('//u', $name) === 1
        && !preg_match('~[/\\\\\x00-\x1f\x7f]~', $name);
}

function cinemaStorageAvailable(): bool
{
    return !is_link(dirname(CINEMA_STORAGE)) && !is_link(CINEMA_STORAGE)
        && realpath(CINEMA_STORAGE) === CINEMA_STORAGE
        && is_dir(CINEMA_STORAGE) && is_readable(CINEMA_STORAGE);
}

function cinemaCanManage(): bool
{
    return cinemaStorageAvailable() && is_writable(CINEMA_STORAGE)
        && !is_link(CINEMA_INCOMING) && realpath(CINEMA_INCOMING) === CINEMA_INCOMING
        && is_dir(CINEMA_INCOMING) && is_writable(CINEMA_INCOMING);
}

function cinemaFileVersion(array $stat): string
{
    return hash("sha256", implode(":", [
        $stat["dev"], $stat["ino"], $stat["size"], $stat["mtime"], $stat["ctime"]
    ]));
}

function cinemaSize(int $bytes): string
{
    if ($bytes >= 1073741824) {
        return number_format($bytes / 1073741824, 1, ".", ",") . " GiB";
    }
    return number_format($bytes / 1048576, 1, ".", ",") . " MiB";
}

/** @return array<int, array<string, mixed>> */
function cinemaCatalog(): array
{
    $media = [];
    foreach (new DirectoryIterator(CINEMA_STORAGE) as $entry) {
        $name = $entry->getFilename();
        $extension = strtolower(pathinfo($name, PATHINFO_EXTENSION));
        if (!cinemaValidName($name) || !isset(CINEMA_TYPES[$extension])
            || $entry->isLink() || !$entry->isFile() || !$entry->isReadable()) {
            continue;
        }
        $stat = @lstat($entry->getPathname());
        if ($stat === false || ($stat["mode"] & 0170000) !== 0100000 || $stat["size"] < 16) {
            continue;
        }
        $media[] = [
            "title" => str_replace(["_", "-"], " ", pathinfo($name, PATHINFO_FILENAME)),
            "filename" => $name,
            "mime" => CINEMA_TYPES[$extension],
            "extension" => strtoupper($extension),
            "audio" => $extension === "mp3",
            "size" => (int) $stat["size"],
            "version" => cinemaFileVersion($stat)
        ];
    }
    usort($media, static function (array $a, array $b): int {
        return strnatcasecmp($a["title"], $b["title"]);
    });
    return $media;
}
