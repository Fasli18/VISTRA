<?php
declare(strict_types=1);

// Loaded before private configuration, including failures while loading it.
ini_set('display_errors', '0');
ini_set('display_startup_errors', '0');
ini_set('log_errors', '1');
error_reporting(E_ALL);
$vistraErrorBufferLevel = ob_get_level();
ob_start();

function vistraDebugEnabled(): bool {
    return defined('APP_ENV') && in_array(strtolower((string)APP_ENV), ['local', 'development', 'test'], true)
        && defined('APP_DEBUG') && APP_DEBUG === true;
}

function vistraServerError(Throwable $error, int $status = 500, string $message = 'Layanan sementara tidak tersedia.'): never {
    global $vistraErrorBufferLevel;
    while (ob_get_level() > $vistraErrorBufferLevel) ob_end_clean();
    // Do not copy SQL, connection strings, passwords, tokens or payloads to logs.
    $reference = substr(hash('sha256', uniqid('', true)), 0, 12);
    error_log('[VISTRA] error_ref=' . $reference . ' type=' . get_class($error));
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: no-store');
    $publicMessage = vistraDebugEnabled() ? $error->getMessage() : $message;
    echo json_encode(['success'=>false, 'data'=>null, 'message'=>$publicMessage, 'error_ref'=>$reference], JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    exit;
}

set_exception_handler(static function (Throwable $error): void { vistraServerError($error); });
set_error_handler(static function (int $severity, string $message, string $file, int $line): bool {
    if (!(error_reporting() & $severity)) return false;
    throw new ErrorException($message, 0, $severity, $file, $line);
});
register_shutdown_function(static function (): void {
    $error = error_get_last();
    if ($error && in_array($error['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR], true)) {
        vistraServerError(new ErrorException('Fatal server error.', 0, $error['type']));
    }
});

function vistraNormalizeOrigin(string $origin): ?string {
    $parts = parse_url($origin);
    if (!$parts || !isset($parts['scheme'], $parts['host']) || !in_array(strtolower($parts['scheme']), ['http','https'], true)
        || isset($parts['user']) || isset($parts['pass']) || isset($parts['query']) || isset($parts['fragment'])
        || (isset($parts['path']) && $parts['path'] !== '')) return null;
    if (preg_match('/[\s\x00-\x1f\x7f]/', $origin)) return null;
    $scheme = strtolower($parts['scheme']);
    $port = $parts['port'] ?? ($scheme === 'https' ? 443 : 80);
    return $scheme . '://' . strtolower($parts['host']) . (($scheme === 'https' && $port === 443) || ($scheme === 'http' && $port === 80) ? '' : ':' . $port);
}

function vistraApplyCors(): void {
    header('Vary: Origin');
    header('Cache-Control: no-store');
    $origin = (string)($_SERVER['HTTP_ORIGIN'] ?? '');
    if ($origin !== '') {
        $normalized = vistraNormalizeOrigin($origin);
        $https = !empty($_SERVER['HTTPS']) && strtolower((string)$_SERVER['HTTPS']) !== 'off';
        $sameOrigin = vistraNormalizeOrigin(($https ? 'https://' : 'http://') . (string)($_SERVER['HTTP_HOST'] ?? ''));
        $configured = defined('CORS_ORIGIN') ? vistraNormalizeOrigin((string)CORS_ORIGIN) : null;
        // Wildcards, null origins, substring matches and reflected arbitrary origins are never allowed.
        if ($normalized === null || ($normalized !== $sameOrigin && ($configured === null || $normalized !== $configured))) {
            http_response_code(403);
            echo json_encode(['success'=>false, 'data'=>null, 'message'=>'Origin tidak diizinkan.']);
            exit;
        }
        header('Access-Control-Allow-Origin: ' . $origin);
    }
    header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type, Authorization');
    if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'OPTIONS') { http_response_code(204); exit; }
}
