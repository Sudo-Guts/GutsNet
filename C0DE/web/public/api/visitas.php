<?php

declare(strict_types=1);

// ============================================================
// GutsNet - Visit Counter
// ============================================================

header("Content-Type: application/json; charset=utf-8");
header("Cache-Control: no-store");

// Permitir únicamente solicitudes POST.
if ($_SERVER["REQUEST_METHOD"] !== "POST") {
    header("Allow: POST");
    http_response_code(405);

    echo json_encode([
        "error" => "Metodo no permitido"
    ]);

    exit;
}

try {
    // Conexión con SQLite.
    $db = new PDO(
        "sqlite:/var/lib/gutsnet/visitas.sqlite",
        null,
        null,
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION
        ]
    );

    $db->exec("PRAGMA busy_timeout = 5000");

    // Crear la tabla si todavía no existe.
    $db->exec("
        CREATE TABLE IF NOT EXISTS visitas (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            total INTEGER NOT NULL DEFAULT 0
        )
    ");

    // Inicializar el contador.
    $db->exec("
        INSERT OR IGNORE INTO visitas (id, total)
        VALUES (1, 0)
    ");

    // Incrementar y obtener el nuevo valor.
    $stmt = $db->query("
        UPDATE visitas
        SET total = total + 1
        WHERE id = 1
        RETURNING total
    ");

    $total = (int) $stmt->fetchColumn();

    echo json_encode([
        "visitas" => $total
    ]);
} catch (Throwable $error) {
    error_log("GutsNet: " . $error->getMessage());

    http_response_code(500);

    echo json_encode([
        "error" => "Contador no disponible"
    ]);
}

