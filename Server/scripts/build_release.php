<?php
declare(strict_types=1);

/*
Usage:
php build_release.php \
  --app-dir=/path/to/Client/App \
  --release-root=/var/www/wintune/storage/releases \
  --base-url=https://updates.example.com \
  --channel=beta \
  --version=0.2.1 \
  --private-key=/secure/keys/update-signing-private.pem
*/

$options = getopt('', ['app-dir:', 'release-root:', 'base-url:', 'channel:', 'version:', 'private-key:', 'notes::']);
foreach (['app-dir', 'release-root', 'base-url', 'channel', 'version', 'private-key'] as $key) {
    if (empty($options[$key])) {
        fwrite(STDERR, "Missing --{$key}\n");
        exit(2);
    }
}

$appDir = rtrim(realpath($options['app-dir']) ?: '', DIRECTORY_SEPARATOR);
$releaseRoot = rtrim($options['release-root'], '/\\');
$baseUrl = rtrim($options['base-url'], '/');
$channel = $options['channel'];
$version = $options['version'];
$keyPath = $options['private-key'];

if ($appDir === '' || !is_dir($appDir)) throw new RuntimeException('Invalid --app-dir');
if (!preg_match('/^(beta|stable)$/', $channel)) throw new RuntimeException('Invalid channel');
if (!preg_match('/^\d+\.\d+\.\d+$/', $version)) throw new RuntimeException('Version must be numeric x.y.z');
if (!filter_var($baseUrl, FILTER_VALIDATE_URL) || parse_url($baseUrl, PHP_URL_SCHEME) !== 'https' || parse_url($baseUrl, PHP_URL_USER) !== null) throw new RuntimeException('base-url must be an HTTPS URL without credentials');
if (!is_file($keyPath)) throw new RuntimeException('Private key not found');

if (!is_dir($releaseRoot) && !mkdir($releaseRoot, 0750, true) && !is_dir($releaseRoot)) throw new RuntimeException('Cannot create release root');
$lock = fopen($releaseRoot . '/.build.lock', 'c');
if ($lock === false || !flock($lock, LOCK_EX | LOCK_NB)) throw new RuntimeException('Another release build is already running');

$staging = sys_get_temp_dir() . '/wintune-release-' . bin2hex(random_bytes(6));
mkdir($staging, 0700, true);

$copy = function (string $source, string $target) use (&$copy): void {
    if (is_link($source)) throw new RuntimeException('Symlinks are not allowed in a release package');
    if (is_dir($source)) {
        if (!is_dir($target) && !mkdir($target, 0700, true) && !is_dir($target)) {
            throw new RuntimeException("Cannot create staging directory: {$target}");
        }
        foreach (scandir($source) as $name) {
            if ($name === '.' || $name === '..') continue;
            $copy($source . DIRECTORY_SEPARATOR . $name, $target . DIRECTORY_SEPARATOR . $name);
        }
        return;
    }
    copy($source, $target);
};
$copy($appDir, $staging);

$files = [];
$iterator = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($staging, FilesystemIterator::SKIP_DOTS));
foreach ($iterator as $file) {
    if (!$file->isFile()) continue;
    $relative = str_replace(DIRECTORY_SEPARATOR, '/', substr($file->getPathname(), strlen($staging) + 1));
    if ($relative === 'release.json') continue;
    $files[] = ['path' => $relative, 'sha256' => hash_file('sha256', $file->getPathname())];
}
usort($files, fn(array $a, array $b) => strcmp($a['path'], $b['path']));
file_put_contents($staging . '/release.json', json_encode(['version' => $version, 'files' => $files], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));

$packageDir = "{$releaseRoot}/packages/{$channel}";
$manifestDir = "{$releaseRoot}/manifests";
@mkdir($packageDir, 0750, true);
@mkdir($manifestDir, 0750, true);

$packageName = "WinTuneAdvisor-{$version}.zip";
$packagePath = "{$packageDir}/{$packageName}";
$temporaryPackagePath = $packagePath . '.tmp-' . bin2hex(random_bytes(6));
$zip = new ZipArchive();
if ($zip->open($temporaryPackagePath, ZipArchive::CREATE | ZipArchive::OVERWRITE) !== true) throw new RuntimeException('Cannot create ZIP');

$iterator = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($staging, FilesystemIterator::SKIP_DOTS));
foreach ($iterator as $file) {
    if ($file->isFile()) {
        $relative = str_replace(DIRECTORY_SEPARATOR, '/', substr($file->getPathname(), strlen($staging) + 1));
        $zip->addFile($file->getPathname(), $relative);
    }
}
$zip->close();

if (!rename($temporaryPackagePath, $packagePath)) throw new RuntimeException('Cannot publish ZIP');

$payload = [
    'schemaVersion' => 1,
    'channel' => $channel,
    'version' => $version,
    'minimumLauncherVersion' => '0.2.0',
    'packageUrl' => "{$baseUrl}/releases/{$channel}/{$packageName}",
    'packageSha256' => hash_file('sha256', $packagePath),
    'releaseNotes' => isset($options['notes']) && $options['notes'] !== '' ? array_values(array_filter(array_map('trim', explode('|', (string) $options['notes'])))) : ['Signed CLI beta release'],
    'publishedAt' => gmdate('c'),
];
$payloadBytes = json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
$privateKey = openssl_pkey_get_private('file://' . $keyPath);
if ($privateKey === false) throw new RuntimeException('Could not load private key');
if (!openssl_sign($payloadBytes, $signature, $privateKey, OPENSSL_ALGO_SHA256)) throw new RuntimeException('Manifest signing failed');

$envelope = [
    'algorithm' => 'RSA-SHA256',
    'payloadBase64' => base64_encode($payloadBytes),
    'signatureBase64' => base64_encode($signature),
];
function atomicJsonWrite(string $path, array $value): void {
    $temporary = $path . '.tmp-' . bin2hex(random_bytes(6));
    if (file_put_contents($temporary, json_encode($value, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . "\n", LOCK_EX) === false || !rename($temporary, $path)) {
        @unlink($temporary);
        throw new RuntimeException("Cannot publish {$path}");
    }
}

atomicJsonWrite("{$manifestDir}/{$channel}.json", $envelope);
atomicJsonWrite("{$manifestDir}/public-release.json", [
    'version' => $version,
    'channel' => $channel,
    'downloadUrl' => "/wintune/releases/{$channel}/{$packageName}",
    'sha256' => $payload['packageSha256'],
    'notes' => $payload['releaseNotes'],
    'publishedAt' => $payload['publishedAt'],
]);

echo "Created package: {$packagePath}\n";
echo "Updated manifest: {$manifestDir}/{$channel}.json\n";
