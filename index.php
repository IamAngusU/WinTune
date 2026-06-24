<?php
declare(strict_types=1);

/*
 * The landing page is deliberately fed only from the release metadata written
 * by Server/scripts/build_release.php.  It never trusts query parameters for
 * filenames or download URLs.
 */
$metadataPath = __DIR__ . '/Server/storage/releases/manifests/public-release.json';
$release = [];
if (is_file($metadataPath) && is_readable($metadataPath)) {
    $decoded = json_decode((string) file_get_contents($metadataPath), true);
    if (is_array($decoded)
        && is_string($decoded['version'] ?? null)
        && preg_match('/^\d+\.\d+\.\d+$/', $decoded['version'])
        && is_string($decoded['downloadUrl'] ?? null)
        && str_starts_with($decoded['downloadUrl'], '/wintune/releases/')
        && is_string($decoded['sha256'] ?? null)
        && preg_match('/^[a-f0-9]{64}$/i', $decoded['sha256'])) {
        $release = $decoded;
    }
}

$version = $release['version'] ?? '0.0.0';
$versionLabel = isset($release['version']) ? 'v' . $release['version'] : 'Beta folgt in Kürze';
$downloadUrl = $release['downloadUrl'] ?? '#download';
$downloadLabel = isset($release['version']) ? 'Download v' . $release['version'] : 'Noch kein Release verfügbar';
$sha256 = isset($release['sha256']) ? strtoupper($release['sha256']) : 'Wird mit dem ersten Release veröffentlicht';
$sourceUrl = getenv('WINTUNE_SOURCE_URL') ?: 'https://github.com/IamAngusU/WinTune';
$assetVersion = static function (string $path): string { $time = @filemtime(__DIR__ . '/' . $path); return $time ? (string) $time : '1'; };

$replace = [
    '{{VERSION}}' => htmlspecialchars($version, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8'),
    '{{VERSION_LABEL}}' => htmlspecialchars($versionLabel, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8'),
    '{{DOWNLOAD_URL}}' => htmlspecialchars($downloadUrl, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8'),
    '{{DOWNLOAD_LABEL}}' => htmlspecialchars($downloadLabel, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8'),
    '{{SHA256}}' => htmlspecialchars($sha256, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8'),
    '{{SOURCE_URL}}' => htmlspecialchars($sourceUrl, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8'),
    '{{RELEASE_NOTES}}' => isset($release['notes']) && is_array($release['notes'])
        ? implode('', array_map(static fn ($note): string => '<li>' . htmlspecialchars((string) $note, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8') . '</li>', array_slice($release['notes'], 0, 12)))
        : '<li>Der erste signierte Beta-Release wird vorbereitet.</li>',
    '{{CSS_VERSION}}' => $assetVersion('assets/css/site.css'),
    '{{JS_VERSION}}' => $assetVersion('assets/js/site.js'),
    '{{IMAGE_VERSION}}' => $assetVersion('assets/images/wintune-hero.png'),
    '{{LOGO_VERSION}}' => $assetVersion('assets/images/logo_wintune-transparent.png'),
    '{{FAVICON_VERSION}}' => $assetVersion('assets/images/favicon.png'),
    '{{LOGO_CSS_VERSION}}' => $assetVersion('assets/css/logo.css'),
];

header('Content-Type: text/html; charset=utf-8');
header('X-Content-Type-Options: nosniff');
header('Referrer-Policy: strict-origin-when-cross-origin');
echo strtr((string) file_get_contents(__DIR__ . '/downloadpage.html'), $replace);
