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

    private function enroll(array $request): never
    {
        $betaCode = trim((string)($request['json']['betaCode'] ?? ''));
        $installationId = trim((string)($request['json']['installationId'] ?? ''));
        if ($betaCode === '' || strlen($betaCode) > 128 || !preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i', $installationId)) {
            Http::json(['error' => 'invalid_enrollment'], 422);
        }

        $codeHash = hash_hmac('sha256', $betaCode, $this->config['APP_PEPPER']);
        $stmt = $this->db->prepare('SELECT id FROM beta_codes WHERE code_hash = :hash AND revoked_at IS NULL AND (expires_at IS NULL OR expires_at > UTC_TIMESTAMP()) LIMIT 1');
        $stmt->execute(['hash' => $codeHash]);
        $code = $stmt->fetch();
        if (!$code) {
            Http::json(['error' => 'invalid_beta_code'], 403);
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
            'beta' => $code['id'],
            'installation' => $installationHash,
            'token' => $tokenHash,
        ]);

        Http::json(['accessToken' => $token]);
    }

    private function telemetry(array $request): never
    {
        $installation = $this->authenticate($request);
        $payload = TelemetryValidator::payload($request['json']);

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
        $rules = $this->db->query('SELECT rule_id, COUNT(*) AS hits FROM finding_events GROUP BY rule_id ORDER BY hits DESC LIMIT 20')->fetchAll();
        $actions = $this->db->query('SELECT action_id, status, COUNT(*) AS hits FROM action_events GROUP BY action_id, status ORDER BY action_id, hits DESC')->fetchAll();
        $collectors = $this->db->query('SELECT operation_id, status, COUNT(*) AS hits FROM operation_events GROUP BY operation_id, status ORDER BY operation_id, hits DESC')->fetchAll();

        header('Content-Type: text/html; charset=utf-8');
        echo '<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>WinTune Beta Dashboard</title>';
        echo '<style>:root{font-family:Inter,Segoe UI,Arial,sans-serif;color:#151625;background:#f5f5fa}*{box-sizing:border-box}body{margin:0;background:radial-gradient(circle at 82% 0,#e8e4ff,transparent 28rem),#f5f5fa}main{max-width:1160px;margin:0 auto;padding:52px 24px 80px}.eyebrow{color:#624cf0;font:800 11px ui-monospace,monospace;text-transform:uppercase;letter-spacing:.1em}h1{font-size:42px;letter-spacing:-.06em;margin:8px 0}header p{color:#6d7080}.kpis{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin:30px 0}.kpi,section{background:#fff;border:1px solid #dfdeeb;border-radius:16px;box-shadow:0 12px 28px #18133308}.kpi{padding:18px}.kpi small{display:block;color:#74778a;text-transform:uppercase;font-size:10px;letter-spacing:.06em}.kpi b{display:block;margin-top:8px;font-size:27px;letter-spacing:-.05em}section{padding:22px;margin:16px 0}h2{font-size:17px;margin:0 0 14px}table{width:100%;border-collapse:collapse}td,th{text-align:left;padding:11px;border-bottom:1px solid #efedf4}th{font-size:10px;color:#74778a;text-transform:uppercase;letter-spacing:.06em}@media(max-width:700px){.kpis{grid-template-columns:1fr 1fr}}</style></head><body><main>';
        echo '<header><div class="eyebrow">Private beta analytics</div><h1>WinTune dashboard</h1><p>Aggregated, opt-in beta diagnostics. No raw personal content is stored in this view.</p></header>';
        echo '<div class="kpis"><div class="kpi"><small>Scans received</small><b>' . $total . '</b></div><div class="kpi"><small>Active installations</small><b>' . $installations . '</b></div><div class="kpi"><small>Last 24 hours</small><b>' . $recent . '</b></div><div class="kpi"><small>Parsed sessions</small><b>' . $completed . '</b></div></div>';
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
}
