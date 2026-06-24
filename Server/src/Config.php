<?php
declare(strict_types=1);

namespace WinTune;

final class Config
{
    public static function load(string $envFile): array
    {
        if (!is_file($envFile)) {
            throw new \RuntimeException("Missing .env file. Copy .env.example to .env first.");
        }

        $values = [];
        foreach (file($envFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
            $line = trim($line);
            if ($line === '' || str_starts_with($line, '#')) {
                continue;
            }
            [$key, $value] = array_pad(explode('=', $line, 2), 2, '');
            $values[trim($key)] = trim($value, " \t\n\r\0\x0B\"");
        }

        foreach (['DB_DSN', 'DB_USER', 'DB_PASSWORD', 'APP_PEPPER', 'ADMIN_USERNAME', 'ADMIN_PASSWORD_HASH', 'RELEASE_ROOT'] as $required) {
            if (!array_key_exists($required, $values) || $values[$required] === '') {
                throw new \RuntimeException("Missing required environment variable: {$required}");
            }
        }

        return $values;
    }
}
