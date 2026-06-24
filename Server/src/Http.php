<?php
declare(strict_types=1);

namespace WinTune;

final class Http
{
    public static function request(): array
    {
        $body = file_get_contents('php://input');
        if ($body !== false && strlen($body) > 131072) {
            self::json(['error' => 'payload_too_large'], 413);
        }
        $json = null;
        if ($body !== false && $body !== '') {
            $contentType = strtolower((string) ($_SERVER['CONTENT_TYPE'] ?? ''));
            if (!str_starts_with($contentType, 'application/json')) {
                self::json(['error' => 'content_type_must_be_json'], 415);
            }
            $json = json_decode($body, true);
            if (!is_array($json)) {
                self::json(['error' => 'invalid_json'], 400);
            }
        }

        return [
            'method' => strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET'),
            'path' => parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/',
            'query' => $_GET,
            'headers' => self::headers(),
            'json' => $json ?? [],
            'ip' => $_SERVER['REMOTE_ADDR'] ?? '',
        ];
    }

    public static function headers(): array
    {
        $headers = [];
        foreach ($_SERVER as $key => $value) {
            if (str_starts_with($key, 'HTTP_')) {
                $headers[strtolower(str_replace('_', '-', substr($key, 5)))] = (string)$value;
            }
        }
        return $headers;
    }

    public static function json(array $payload, int $status = 200): never
    {
        http_response_code($status);
        header('Content-Type: application/json; charset=utf-8');
        header('Cache-Control: no-store');
        echo json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
        exit;
    }

    public static function text(string $body, int $status = 200): never
    {
        http_response_code($status);
        header('Content-Type: text/plain; charset=utf-8');
        echo $body;
        exit;
    }
}
