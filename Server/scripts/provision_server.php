#!/usr/bin/env php
<?php
declare(strict_types=1);

/* One-time local provisioning. Run as the server administrator, never in CI. */
$options = getopt('', ['env-file::', 'release-root::', 'db-name::', 'db-user::']);
$envFile = $options['env-file'] ?? dirname(__DIR__) . '/.env';
$releaseRoot = $options['release-root'] ?? dirname(__DIR__) . '/storage/releases';
$database = $options['db-name'] ?? 'wintune';
$databaseUser = $options['db-user'] ?? 'wintune_api';

if (is_file($envFile)) {
    fwrite(STDERR, "Refusing to replace existing {$envFile}\n");
    exit(1);
}
if (!preg_match('/^[A-Za-z0-9_]{1,64}$/', $database) || !preg_match('/^[A-Za-z0-9_]{1,32}$/', $databaseUser)) {
    fwrite(STDERR, "Database and user names may contain only letters, digits, and underscores.\n");
    exit(2);
}

function randomSecret(int $bytes = 32): string
{
    return rtrim(strtr(base64_encode(random_bytes($bytes)), '+/', '-_'), '=');
}

$dbPassword = randomSecret();
$pepper = bin2hex(random_bytes(32));
$adminPassword = randomSecret(24);
$adminHash = password_hash($adminPassword, PASSWORD_DEFAULT);
if ($adminHash === false) throw new RuntimeException('Could not create admin password hash');

try {
    $pdo = new PDO('mysql:unix_socket=/run/mysqld/mysqld.sock;charset=utf8mb4', 'root', '', [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_EMULATE_PREPARES => false,
    ]);
    $quotedDatabase = '`' . str_replace('`', '``', $database) . '`';
    $pdo->exec("CREATE DATABASE IF NOT EXISTS {$quotedDatabase} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");
    $pdo->exec("CREATE USER IF NOT EXISTS " . $pdo->quote($databaseUser) . "@'127.0.0.1' IDENTIFIED BY " . $pdo->quote($dbPassword));
    $pdo->exec("ALTER USER " . $pdo->quote($databaseUser) . "@'127.0.0.1' IDENTIFIED BY " . $pdo->quote($dbPassword));
    $pdo->exec("GRANT SELECT, INSERT, UPDATE, DELETE ON {$quotedDatabase}.* TO " . $pdo->quote($databaseUser) . "@'127.0.0.1'");
    $pdo->exec('FLUSH PRIVILEGES');

    $schema = (string) file_get_contents(dirname(__DIR__) . '/database/schema.sql');
    foreach (preg_split('/;\s*(?:\R|$)/', $schema) ?: [] as $statement) {
        if (trim($statement) !== '') $pdo->exec('USE ' . $quotedDatabase . ';' . $statement);
    }
} catch (Throwable $e) {
    fwrite(STDERR, "Database provisioning failed: {$e->getMessage()}\n");
    exit(1);
}

foreach ([$releaseRoot, $releaseRoot . '/manifests', $releaseRoot . '/packages'] as $directory) {
    if (!is_dir($directory) && !mkdir($directory, 0755, true) && !is_dir($directory)) {
        throw new RuntimeException("Cannot create {$directory}");
    }
}

$env = implode("\n", [
    "DB_DSN=\"mysql:host=127.0.0.1;dbname={$database};charset=utf8mb4\"",
    "DB_USER=\"{$databaseUser}\"",
    "DB_PASSWORD=\"{$dbPassword}\"",
    "APP_PEPPER=\"{$pepper}\"",
    'ADMIN_USERNAME="admin"',
    "ADMIN_PASSWORD_HASH=\"{$adminHash}\"",
    "RELEASE_ROOT=\"{$releaseRoot}\"",
    'API_BASE_PATH="/wintune/api"',
    '',
]);
$temporary = $envFile . '.tmp-' . bin2hex(random_bytes(4));
if (file_put_contents($temporary, $env, LOCK_EX) === false || !rename($temporary, $envFile)) {
    @unlink($temporary);
    throw new RuntimeException('Cannot write .env');
}
chmod($envFile, 0640);
@chgrp($envFile, 'www-data');

fwrite(STDOUT, "WinTune server provisioned. Store this one-time dashboard password now:\n{$adminPassword}\n");
