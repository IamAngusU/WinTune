<?php
declare(strict_types=1);

namespace WinTune;

final class Database
{
    public static function connect(array $config): \PDO
    {
        $pdo = new \PDO(
            $config['DB_DSN'],
            $config['DB_USER'],
            $config['DB_PASSWORD'],
            [
                \PDO::ATTR_ERRMODE => \PDO::ERRMODE_EXCEPTION,
                \PDO::ATTR_DEFAULT_FETCH_MODE => \PDO::FETCH_ASSOC,
                \PDO::ATTR_EMULATE_PREPARES => false,
            ]
        );
        return $pdo;
    }
}
