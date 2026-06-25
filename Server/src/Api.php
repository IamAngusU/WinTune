<?php
declare(strict_types=1);

namespace WinTune;

final class Api
{
    public function __construct(
        private readonly array $config,
        private readonly \PDO $db
    ) {}

    public function handle(array $request): never
    {
        try {
            $path = rtrim($request['path'], '/') ?: '/';
            $basePath = rtrim((string) ($this->config['API_BASE_PATH'] ?? ''), '/');
            if ($basePath !== '' && ($path === $basePath || str_starts_with($path, $basePath . '/'))) {
                $path = substr($path, strlen($basePath)) ?: '/';
            }
            if ($path === '/v1/updates/manifest' && $request['method'] === 'GET') {
                $this->manifest($request);
            }
            if ($path === '/v1/download' && $request['method'] === 'GET') {
                $this->download($request);
            }
            if ($path === '/v1/funnel' && $request['method'] === 'POST') {
                $this->funnel($request);
            }
            if ($path === '/v1/enroll' && $request['method'] === 'POST') {
                $this->enroll($request);
            }
            if ($path === '/v1/telemetry/events' && $request['method'] === 'POST') {
                $this->telemetry($request);
            }
            if ($path === '/v1/feedback' && $request['method'] === 'POST') {
                $this->feedback($request);
            }
            if ($path === '/admin' && $request['method'] === 'GET') {
                $this->dashboard($request);
            }
            Http::json(['error' => 'not_found'], 404);
        } catch (\InvalidArgumentException $e) {
            Http::json(['error' => $e->getMessage()], 422);
        } catch (\Throwable $e) {
            error_log('[WinTune] ' . $e->getMessage());
            Http::json(['error' => 'server_error'], 500);
        }
    }

    private function manifest(array $request): never
    {
        $channel = (string)($request['query']['channel'] ?? 'beta');
        if (!in_array($channel, ['beta', 'stable'], true)) {
            Http::json(['error' => 'invalid_channel'], 400);
        }

        $path = rtrim($this->config['RELEASE_ROOT'], '/\\') . '/manifests/' . $channel . '.json';
        if (!is_file($path)) {
            Http::json(['error' => 'release_not_found'], 404);
        }

        header('Content-Type: application/json; charset=utf-8');
        header('Cache-Control: no-store');
        readfile($path);
        exit;
    }

    private function download(array $request): never
    {
        $target = (string)($request['query']['target'] ?? '');
        if (!str_starts_with($target, '/wintune/releases/') || str_contains($target, '..') || !preg_match('/^\/wintune\/releases\/(beta|stable)\/[A-Za-z0-9._-]+\.zip$/', $target, $matches)) {
            Http::json(['error' => 'invalid_download'], 422);
        }

        try {
            $this->ensureAnalyticsTables();
            $packageName = basename($target);
            $version = null;
            if (preg_match('/(\d+\.\d+\.\d+)/', $packageName, $versionMatch)) {
                $version = $versionMatch[1];
            }

            $ua = (string)($request['headers']['user-agent'] ?? '');
            $referrer = (string)($request['headers']['referer'] ?? '');
            $referrerHost = $referrer !== '' ? (string)(parse_url($referrer, PHP_URL_HOST) ?: '') : null;
            $visitorKey = gmdate('Y-m-d') . '|' . (string)$request['ip'] . '|' . substr($ua, 0, 240);

            $insert = $this->db->prepare(
                'INSERT INTO download_events (release_version, channel, package_name, visitor_hash, user_agent_hash, referrer_host, created_at)
                 VALUES (:version, :channel, :package, :visitor, :ua, :referrer, UTC_TIMESTAMP())'
            );
            $insert->execute([
                'version' => $version,
                'channel' => $matches[1],
                'package' => $packageName,
                'visitor' => hash_hmac('sha256', $visitorKey, $this->config['APP_PEPPER']),
                'ua' => $ua !== '' ? hash_hmac('sha256', $ua, $this->config['APP_PEPPER']) : null,
                'referrer' => $referrerHost !== '' ? substr((string)$referrerHost, 0, 160) : null,
            ]);

            $this->recordFunnelEvent('download', null, null, $version, null, $matches[1], $packageName);
        } catch (\Throwable $e) {
            error_log('[WinTune] download analytics skipped: ' . $e->getMessage());
        }
        header('Location: ' . $target, true, 302);
        header('Cache-Control: no-store');
        exit;
    }

    private function funnel(array $request): never
    {
        $allowed = [
            'launcher_started', 'update_manifest_checked', 'update_manifest_failed',
            'update_available', 'update_installed', 'update_skipped', 'app_started',
            'scan_completed', 'telemetry_prompt_shown', 'telemetry_declined',
            'telemetry_uploaded', 'telemetry_queued'
        ];
        $eventName = trim((string)($request['json']['eventName'] ?? ''));
        if (!in_array($eventName, $allowed, true)) {
            Http::json(['error' => 'invalid_funnel_event'], 422);
        }

        $installationId = trim((string)($request['json']['installationId'] ?? ''));
        if ($installationId !== '' && !preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i', $installationId)) {
            Http::json(['error' => 'invalid_installation'], 422);
        }
        $sessionId = trim((string)($request['json']['sessionId'] ?? ''));
        if ($sessionId !== '' && !preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i', $sessionId)) {
            Http::json(['error' => 'invalid_session'], 422);
        }

        $this->recordFunnelEvent(
            $eventName,
            $installationId !== '' ? hash_hmac('sha256', strtolower($installationId), $this->config['APP_PEPPER']) : null,
            $sessionId !== '' ? strtolower($sessionId) : null,
            $this->shortText($request['json']['releaseVersion'] ?? null, 32),
            $this->shortText($request['json']['clientVersion'] ?? null, 32),
            $this->shortText($request['json']['channel'] ?? null, 16),
            $this->shortText($request['json']['detail'] ?? null, 120)
        );
        Http::json(['accepted' => true], 201);
    }

    private function enroll(array $request): never
    {
        $betaCode = trim((string)($request['json']['betaCode'] ?? ''));
        $installationId = trim((string)($request['json']['installationId'] ?? ''));
        if (strlen($betaCode) > 128 || !preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i', $installationId)) {
            Http::json(['error' => 'invalid_enrollment'], 422);
        }

        $this->ensureAnalyticsTables();
        $codeId = null;
        if ($betaCode !== '') {
            $codeHash = hash_hmac('sha256', $betaCode, $this->config['APP_PEPPER']);
            $stmt = $this->db->prepare('SELECT id FROM beta_codes WHERE code_hash = :hash AND revoked_at IS NULL AND (expires_at IS NULL OR expires_at > UTC_TIMESTAMP()) LIMIT 1');
            $stmt->execute(['hash' => $codeHash]);
            $code = $stmt->fetch();
            if (!$code) {
                Http::json(['error' => 'invalid_beta_code'], 403);
            }
            $codeId = (int)$code['id'];
        }

        $installationHash = hash_hmac('sha256', strtolower($installationId), $this->config['APP_PEPPER']);
        $token = bin2hex(random_bytes(32));
        $tokenHash = hash_hmac('sha256', $token, $this->config['APP_PEPPER']);

        $insert = $this->db->prepare(
            'INSERT INTO installations (beta_code_id, installation_id_hash, token_hash, created_at, last_seen_at)
             VALUES (:beta, :installation, :token, UTC_TIMESTAMP(), UTC_TIMESTAMP())
             ON DUPLICATE KEY UPDATE token_hash = VALUES(token_hash), last_seen_at = UTC_TIMESTAMP(), revoked_at = NULL'
        );
        $insert->execute([
            'beta' => $codeId,
            'installation' => $installationHash,
            'token' => $tokenHash,
        ]);

        Http::json(['accessToken' => $token]);
    }

    private function telemetry(array $request): never
    {
        $installation = $this->authenticate($request);
        $payload = TelemetryValidator::payload($request['json']);
        $this->ensureAnalyticsTables();

        $installationHash = hash_hmac('sha256', strtolower($payload['installationId']), $this->config['APP_PEPPER']);
        if (!hash_equals($installation['installation_id_hash'], $installationHash)) {
            Http::json(['error' => 'installation_mismatch'], 403);
        }

        // Basic per-installation pacing. It keeps accidental client loops from filling the database.
        $last = $this->db->prepare('SELECT created_at FROM scan_sessions WHERE installation_id = :installation ORDER BY id DESC LIMIT 1');
        $last->execute(['installation' => $installation['id']]);
        $previous = $last->fetchColumn();
        if ($previous && strtotime((string)$previous) > time() - 3) {
            Http::json(['error' => 'rate_limited'], 429);
        }

        $this->db->beginTransaction();
        try {
            $insert = $this->db->prepare(
                'INSERT INTO scan_sessions
                (installation_id, client_version, channel, session_uuid, windows_major, windows_build, powershell_major, is_admin, device_type, locale, ram_bucket, storage_types_json, disk_count, battery_present, work_status, finding_count, created_at)
                VALUES
                (:installation, :version, :channel, :session, :windows, :build, :powershell, :admin, :device, :locale, :ram, :storage, :disks, :battery, :work, :findings, UTC_TIMESTAMP())'
            );
            $insert->execute([
                'installation' => $installation['id'],
                'version' => $payload['clientVersion'],
                'channel' => $payload['channel'],
                'session' => $payload['sessionId'],
                'windows' => $payload['windowsMajor'],
                'build' => $payload['windowsBuild'],
                'powershell' => $payload['powershellMajor'],
                'admin' => $payload['isAdmin'] ? 1 : 0,
                'device' => $payload['deviceType'],
                'locale' => $payload['locale'],
                'ram' => $payload['ramGbBucket'],
                'storage' => json_encode($payload['storageTypes'], JSON_UNESCAPED_SLASHES),
                'disks' => $payload['diskCount'],
                'battery' => $payload['batteryPresent'] ? 1 : 0,
                'work' => $payload['workStatus'],
                'findings' => $payload['findingCount'],
            ]);
            $sessionId = (int)$this->db->lastInsertId();

            $findingStmt = $this->db->prepare('INSERT INTO finding_events (scan_session_id, rule_id, severity) VALUES (:session, :rule, :severity)');
            foreach ($payload['findings'] as $finding) {
                $findingStmt->execute(['session' => $sessionId, 'rule' => $finding['ruleId'], 'severity' => $finding['severity']]);
            }

            $operationStmt = $this->db->prepare('INSERT INTO operation_events (scan_session_id, operation_id, status, error_code, fallback_used) VALUES (:session, :operation, :status, :error, :fallback)');
            foreach ($payload['operations'] as $operation) {
                $operationStmt->execute([
                    'session' => $sessionId,
                    'operation' => $operation['id'],
                    'status' => $operation['status'],
                    'error' => $operation['errorCode'] ?: null,
                    'fallback' => $operation['fallbackUsed'] ? 1 : 0,
                ]);
            }

            $actionStmt = $this->db->prepare('INSERT INTO action_events (scan_session_id, action_id, status) VALUES (:session, :action, :status)');
            foreach ($payload['actions'] as $action) {
                $actionStmt->execute(['session' => $sessionId, 'action' => $action['actionId'], 'status' => $action['status']]);
            }

            $touch = $this->db->prepare('UPDATE installations SET last_seen_at = UTC_TIMESTAMP() WHERE id = :id');
            $touch->execute(['id' => $installation['id']]);
            $this->recordFunnelEvent('telemetry_uploaded', $installation['installation_id_hash'], $payload['sessionId'], null, $payload['clientVersion'], $payload['channel'], null);

            $this->db->commit();
            Http::json(['sessionId' => $payload['sessionId'], 'accepted' => true], 201);
        } catch (\Throwable $e) {
            $this->db->rollBack();
            throw $e;
        }
    }

    private function feedback(array $request): never
    {
        $installation = $this->authenticate($request);
        $sessionUuid = trim((string)($request['json']['sessionId'] ?? ''));
        $score = (int)($request['json']['score'] ?? 0);
        $helped = isset($request['json']['helped']) ? (bool)$request['json']['helped'] : null;

        if (!preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i', $sessionUuid) || $score < 1 || $score > 5) {
            Http::json(['error' => 'invalid_feedback'], 422);
        }

        $lookup = $this->db->prepare('SELECT id FROM scan_sessions WHERE installation_id = :installation AND session_uuid = :session LIMIT 1');
        $lookup->execute(['installation' => $installation['id'], 'session' => $sessionUuid]);
        $sessionId = $lookup->fetchColumn();
        if (!$sessionId) Http::json(['error' => 'session_not_found'], 404);

        $insert = $this->db->prepare('INSERT INTO feedback_events (scan_session_id, score, helped, created_at) VALUES (:session, :score, :helped, UTC_TIMESTAMP()) ON DUPLICATE KEY UPDATE score = VALUES(score), helped = VALUES(helped), created_at = VALUES(created_at)');
        $insert->execute(['session' => $sessionId, 'score' => $score, 'helped' => $helped === null ? null : ($helped ? 1 : 0)]);
        Http::json(['accepted' => true], 201);
    }

    private function authenticate(array $request): array
    {
        $header = (string)($request['headers']['authorization'] ?? '');
        if (!preg_match('/^Bearer\s+([a-f0-9]{64})$/i', $header, $matches)) {
            Http::json(['error' => 'missing_or_invalid_token'], 401);
        }

        $hash = hash_hmac('sha256', $matches[1], $this->config['APP_PEPPER']);
        $stmt = $this->db->prepare('SELECT * FROM installations WHERE token_hash = :hash AND revoked_at IS NULL LIMIT 1');
        $stmt->execute(['hash' => $hash]);
        $installation = $stmt->fetch();
        if (!$installation) Http::json(['error' => 'invalid_token'], 401);
        return $installation;
    }

    private function dashboard(array $request): never
    {
        $this->requireAdmin($request);

        $total = (int)$this->db->query('SELECT COUNT(*) FROM scan_sessions')->fetchColumn();
        $completed = (int)$this->db->query('SELECT COUNT(*) FROM scan_sessions WHERE finding_count >= 0')->fetchColumn();
        $installations = (int)$this->db->query('SELECT COUNT(*) FROM installations WHERE revoked_at IS NULL')->fetchColumn();
        $recent = (int)$this->db->query('SELECT COUNT(*) FROM scan_sessions WHERE created_at >= UTC_TIMESTAMP() - INTERVAL 24 HOUR')->fetchColumn();
        $this->ensureAnalyticsTables();
        $downloads = (int)$this->db->query('SELECT COUNT(*) FROM download_events')->fetchColumn();
        $funnelCounts = $this->db->query('SELECT event_name, COUNT(DISTINCT COALESCE(installation_id_hash, CONCAT("event-", id))) AS hits FROM funnel_events GROUP BY event_name')->fetchAll();
        $funnelMap = [];
        foreach ($funnelCounts as $row) $funnelMap[(string)$row['event_name']] = (int)$row['hits'];
        $funnelMap['download'] = max($downloads, $funnelMap['download'] ?? 0);
        $funnelMap['scan_completed'] = max($total, $funnelMap['scan_completed'] ?? 0);
        $funnelMap['telemetry_uploaded'] = max($total, $funnelMap['telemetry_uploaded'] ?? 0);
        $rules = $this->db->query('SELECT rule_id, COUNT(*) AS hits FROM finding_events GROUP BY rule_id ORDER BY hits DESC LIMIT 20')->fetchAll();
        $actions = $this->db->query('SELECT action_id, status, COUNT(*) AS hits FROM action_events GROUP BY action_id, status ORDER BY action_id, hits DESC')->fetchAll();
        $collectors = $this->db->query('SELECT operation_id, status, COUNT(*) AS hits FROM operation_events GROUP BY operation_id, status ORDER BY operation_id, hits DESC')->fetchAll();

        header('Content-Type: text/html; charset=utf-8');
        echo '<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>WinTune Beta Dashboard</title>';
        echo '<style>:root{font-family:Inter,Segoe UI,Arial,sans-serif;color:#151625;background:#f5f5fa}*{box-sizing:border-box}body{margin:0;background:radial-gradient(circle at 82% 0,#e8e4ff,transparent 28rem),#f5f5fa}main{max-width:1160px;margin:0 auto;padding:52px 24px 80px}.eyebrow{color:#624cf0;font:800 11px ui-monospace,monospace;text-transform:uppercase;letter-spacing:.1em}h1{font-size:42px;letter-spacing:-.06em;margin:8px 0}header p{color:#6d7080}.kpis{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin:30px 0}.kpi,section{background:#fff;border:1px solid #dfdeeb;border-radius:16px;box-shadow:0 12px 28px #18133308}.kpi{padding:18px}.kpi small{display:block;color:#74778a;text-transform:uppercase;font-size:10px;letter-spacing:.06em}.kpi b{display:block;margin-top:8px;font-size:27px;letter-spacing:-.05em}section{padding:22px;margin:16px 0}h2{font-size:17px;margin:0 0 14px}.tree{display:grid;gap:10px}.step{display:grid;grid-template-columns:minmax(150px,1fr) 90px 90px;gap:12px;align-items:center}.bar{height:9px;background:#eceaf7;border-radius:999px;overflow:hidden;grid-column:1/-1}.bar span{display:block;height:100%;background:#624cf0}table{width:100%;border-collapse:collapse}td,th{text-align:left;padding:11px;border-bottom:1px solid #efedf4}th{font-size:10px;color:#74778a;text-transform:uppercase;letter-spacing:.06em}@media(max-width:700px){.kpis{grid-template-columns:1fr 1fr}.step{grid-template-columns:1fr 70px 70px}}</style></head><body><main>';
        echo '<header><div class="eyebrow">Private beta analytics</div><h1>WinTune dashboard</h1><p>Aggregated, opt-in beta diagnostics. No raw personal content is stored in this view.</p></header>';
        echo '<div class="kpis"><div class="kpi"><small>Downloads</small><b>' . $downloads . '</b></div><div class="kpi"><small>Scans received</small><b>' . $total . '</b></div><div class="kpi"><small>Active installations</small><b>' . $installations . '</b></div><div class="kpi"><small>Last 24 hours</small><b>' . $recent . '</b></div></div>';
        echo '<section><h2>Funnel tree</h2><div class="tree">';
        foreach ($this->funnelSteps() as $event => $label) {
            $count = (int)($funnelMap[$event] ?? 0);
            $pct = $downloads > 0 ? round(($count / $downloads) * 100, 1) : 0;
            echo '<div class="step"><strong>' . htmlspecialchars($label) . '</strong><span>' . $count . '</span><span>' . $pct . '%</span><div class="bar"><span style="width:' . min(100, $pct) . '%"></span></div></div>';
        }
        echo '</div></section>';
        echo '<section><h2>Most common findings</h2><table><tr><th>Rule</th><th>Hits</th></tr>';
        foreach ($rules as $row) echo '<tr><td>' . htmlspecialchars($row['rule_id']) . '</td><td>' . (int)$row['hits'] . '</td></tr>';
        echo '</table></section><section><h2>Action outcomes</h2><table><tr><th>Action</th><th>Status</th><th>Hits</th></tr>';
        foreach ($actions as $row) echo '<tr><td>' . htmlspecialchars($row['action_id']) . '</td><td>' . htmlspecialchars($row['status']) . '</td><td>' . (int)$row['hits'] . '</td></tr>';
        echo '</table></section><section><h2>Collector compatibility</h2><table><tr><th>Collector</th><th>Status</th><th>Hits</th></tr>';
        foreach ($collectors as $row) echo '<tr><td>' . htmlspecialchars($row['operation_id']) . '</td><td>' . htmlspecialchars($row['status']) . '</td><td>' . (int)$row['hits'] . '</td></tr>';
        echo '</table></section></main></body></html>';
        exit;
    }

    private function requireAdmin(array $request): void
    {
        $header = (string)($request['headers']['authorization'] ?? '');
        if (!preg_match('/^Basic\s+(.+)$/', $header, $matches)) {
            header('WWW-Authenticate: Basic realm="WinTune Admin"');
            Http::text('Authentication required', 401);
        }
        $decoded = base64_decode($matches[1], true);
        if ($decoded === false || !str_contains($decoded, ':')) Http::text('Forbidden', 403);
        [$username, $password] = explode(':', $decoded, 2);
        if (!hash_equals($this->config['ADMIN_USERNAME'], $username) || !password_verify($password, $this->config['ADMIN_PASSWORD_HASH'])) {
            Http::text('Forbidden', 403);
        }
    }

    private function recordFunnelEvent(string $eventName, ?string $installationHash, ?string $sessionUuid, ?string $releaseVersion, ?string $clientVersion, ?string $channel, ?string $detail): void
    {
        try {
            $this->ensureAnalyticsTables();
            $insert = $this->db->prepare(
                'INSERT INTO funnel_events (installation_id_hash, session_uuid, event_name, release_version, client_version, channel, detail, created_at)
                 VALUES (:installation, :session, :event, :release, :client, :channel, :detail, UTC_TIMESTAMP())'
            );
            $insert->execute([
                'installation' => $installationHash,
                'session' => $sessionUuid,
                'event' => $eventName,
                'release' => $releaseVersion,
                'client' => $clientVersion,
                'channel' => $channel,
                'detail' => $detail,
            ]);
        } catch (\Throwable $e) {
            error_log('[WinTune] funnel analytics skipped: ' . $e->getMessage());
        }
    }

    private function ensureAnalyticsTables(): void
    {
        static $done = false;
        if ($done) return;
        try {
            $stmt = $this->db->prepare('SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name IN ("download_events", "funnel_events")');
            $stmt->execute();
            if ((int)$stmt->fetchColumn() === 2) {
                $done = true;
                return;
            }
        } catch (\Throwable) {}
        $this->db->exec('CREATE TABLE IF NOT EXISTS download_events (
          id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
          release_version VARCHAR(32) NULL,
          channel VARCHAR(16) NULL,
          package_name VARCHAR(180) NULL,
          visitor_hash CHAR(64) NOT NULL,
          user_agent_hash CHAR(64) NULL,
          referrer_host VARCHAR(160) NULL,
          created_at DATETIME NOT NULL,
          KEY ix_downloads_created (created_at),
          KEY ix_downloads_release (release_version, channel)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci');
        $this->db->exec('CREATE TABLE IF NOT EXISTS funnel_events (
          id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
          installation_id_hash CHAR(64) NULL,
          session_uuid CHAR(36) NULL,
          event_name VARCHAR(64) NOT NULL,
          release_version VARCHAR(32) NULL,
          client_version VARCHAR(32) NULL,
          channel VARCHAR(16) NULL,
          detail VARCHAR(120) NULL,
          created_at DATETIME NOT NULL,
          KEY ix_funnel_event (event_name),
          KEY ix_funnel_created (created_at),
          KEY ix_funnel_installation (installation_id_hash),
          KEY ix_funnel_session (session_uuid)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci');
        try { $this->db->exec('ALTER TABLE installations MODIFY beta_code_id BIGINT UNSIGNED NULL'); } catch (\Throwable) {}
        $done = true;
    }

    private function shortText(mixed $value, int $length): ?string
    {
        $text = trim((string)$value);
        return $text === '' ? null : substr($text, 0, $length);
    }

    private function funnelSteps(): array
    {
        return [
            'download' => 'Downloaded',
            'launcher_started' => 'Started launcher',
            'update_manifest_checked' => 'Checked updates',
            'update_available' => 'Saw update',
            'update_installed' => 'Installed update',
            'app_started' => 'Started advisor',
            'scan_completed' => 'Completed scan',
            'telemetry_prompt_shown' => 'Saw analysis prompt',
            'telemetry_uploaded' => 'Sent analysis data',
            'telemetry_declined' => 'Declined analysis data',
        ];
    }
}
