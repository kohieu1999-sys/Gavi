<?php
// GaviStore key verification API for the 3105 iOS client.
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');

function respond(int $status, array $payload): void {
    http_response_code($status);
    echo json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    header('Allow: POST');
    respond(405, ['valid' => false, 'message' => 'Method not allowed']);
}

$raw = file_get_contents('php://input', false, null, 0, 4097);
if ($raw === false || strlen($raw) > 4096) {
    respond(400, ['valid' => false, 'message' => 'Invalid request']);
}

$input = json_decode($raw, true);
$key = is_array($input) && isset($input['key']) && is_string($input['key'])
    ? trim($input['key']) : '';
$deviceId = is_array($input) && isset($input['device_id']) && is_string($input['device_id'])
    ? trim($input['device_id']) : '';

if ($key === '' || strlen($key) > 256 || $deviceId === '' || strlen($deviceId) > 128) {
    respond(400, ['valid' => false, 'message' => 'Thiếu key hoặc mã thiết bị']);
}

// Upload server/public/* into the website document root. Keep this private
// JSON file inside /private; the accompanying .htaccess blocks direct access.
$keysPath = dirname(__DIR__, 2) . '/private/keys.json';
if (!is_file($keysPath) || !is_readable($keysPath) || !is_writable($keysPath)) {
    respond(503, ['valid' => false, 'message' => 'Máy chủ chưa cấu hình kho key']);
}

$handle = fopen($keysPath, 'c+');
if ($handle === false || !flock($handle, LOCK_EX)) {
    if (is_resource($handle)) fclose($handle);
    respond(503, ['valid' => false, 'message' => 'Không thể đọc kho key']);
}

try {
    rewind($handle);
    $contents = stream_get_contents($handle);
    $database = json_decode($contents === false ? '' : $contents, true);
    if (!is_array($database) || !isset($database['keys']) || !is_array($database['keys'])) {
        respond(503, ['valid' => false, 'message' => 'Dữ liệu kho key không hợp lệ']);
    }

    $now = new DateTimeImmutable('now', new DateTimeZone('UTC'));
    $foundIndex = null;
    foreach ($database['keys'] as $index => $record) {
        if (!is_array($record) || !isset($record['key']) || !is_string($record['key'])) continue;
        if (hash_equals($record['key'], $key)) {
            $foundIndex = $index;
            break;
        }
    }

    if ($foundIndex === null) {
        respond(200, ['valid' => false, 'message' => 'Key không tồn tại hoặc đã bị khóa']);
    }

    $record = $database['keys'][$foundIndex];
    $expiresAt = isset($record['expires_at']) && is_string($record['expires_at'])
        ? $record['expires_at'] : null;
    if (($record['active'] ?? false) !== true) {
        respond(200, ['valid' => false, 'expires_at' => $expiresAt, 'message' => 'Key đã bị quản trị viên khóa']);
    }

    if ($expiresAt !== null) {
        try {
            $expiry = new DateTimeImmutable($expiresAt);
        } catch (Throwable $error) {
            respond(503, ['valid' => false, 'message' => 'Ngày hết hạn của key không hợp lệ']);
        }
        if ($expiry <= $now) {
            respond(200, ['valid' => false, 'expires_at' => $expiresAt, 'message' => 'Key đã hết hạn']);
        }
    }

    $devices = isset($record['devices']) && is_array($record['devices'])
        ? array_values(array_filter($record['devices'], 'is_string')) : [];
    $limit = isset($record['device_limit']) ? max(0, (int)$record['device_limit']) : 1;
    $alreadyRegistered = in_array($deviceId, $devices, true);
    if (!$alreadyRegistered && $limit > 0 && count($devices) >= $limit) {
        respond(200, ['valid' => false, 'expires_at' => $expiresAt, 'message' => 'Key đã đạt giới hạn thiết bị']);
    }

    if (!$alreadyRegistered) {
        $devices[] = $deviceId;
        $database['keys'][$foundIndex]['devices'] = array_values(array_unique($devices));
        $encoded = json_encode($database, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        if ($encoded === false) {
            respond(503, ['valid' => false, 'message' => 'Không thể lưu thiết bị']);
        }
        rewind($handle);
        if (!ftruncate($handle, 0) || fwrite($handle, $encoded . "\n") === false || !fflush($handle)) {
            respond(503, ['valid' => false, 'message' => 'Không thể cập nhật kho key']);
        }
    }

    respond(200, ['valid' => true, 'expires_at' => $expiresAt, 'message' => 'Key hợp lệ']);
} finally {
    flock($handle, LOCK_UN);
    fclose($handle);
}
