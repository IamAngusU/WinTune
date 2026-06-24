<?php
declare(strict_types=1);

namespace WinTune;

final class TelemetryValidator
{
    private const SEVERITIES = ['critical', 'warning', 'info', 'optional'];
    private const STATUSES = ['Success', 'Degraded', 'Skipped', 'FailedNonFatal', 'Cancelled', 'Partial'];

    public static function payload(array $raw): array
    {
        self::mustString($raw, 'schemaVersion', 16);
        self::mustString($raw, 'clientVersion', 32);
        self::mustString($raw, 'channel', 16);
        self::mustUuid($raw, 'installationId');
        self::mustUuid($raw, 'sessionId');

        $env = is_array($raw['environment'] ?? null) ? $raw['environment'] : [];
        $hardware = is_array($raw['hardware'] ?? null) ? $raw['hardware'] : [];
        $scan = is_array($raw['scan'] ?? null) ? $raw['scan'] : [];

        $findings = [];
        foreach (array_slice((array)($raw['findings'] ?? []), 0, 100) as $item) {
            if (!is_array($item)) continue;
            $ruleId = self::stringValue($item['ruleId'] ?? '', 96);
            $severity = strtolower(self::stringValue($item['severity'] ?? '', 16));
            if ($ruleId === '' || !preg_match('/^[A-Z0-9_]+$/', $ruleId) || !in_array($severity, self::SEVERITIES, true)) continue;
            $findings[] = ['ruleId' => $ruleId, 'severity' => $severity];
        }

        $operations = [];
        foreach (array_slice((array)($raw['operations'] ?? []), 0, 100) as $item) {
            if (!is_array($item)) continue;
            $id = self::stringValue($item['id'] ?? '', 96);
            $status = self::stringValue($item['status'] ?? '', 32);
            if ($id === '' || !preg_match('/^[A-Za-z0-9._-]+$/', $id) || !in_array($status, self::STATUSES, true)) continue;
            $operations[] = [
                'id' => $id,
                'status' => $status,
                'errorCode' => self::stringValue($item['errorCode'] ?? '', 64),
                'fallbackUsed' => (bool)($item['fallbackUsed'] ?? false),
            ];
        }

        $actions = [];
        foreach (array_slice((array)($raw['actions'] ?? []), 0, 100) as $item) {
            if (!is_array($item)) continue;
            $id = self::stringValue($item['actionId'] ?? '', 96);
            $status = self::stringValue($item['status'] ?? '', 32);
            if ($id === '' || !preg_match('/^[A-Za-z0-9._-]+$/', $id) || $status === '') continue;
            $actions[] = ['actionId' => $id, 'status' => $status];
        }

        return [
            'schemaVersion' => self::stringValue($raw['schemaVersion'], 16),
            'clientVersion' => self::stringValue($raw['clientVersion'], 32),
            'channel' => self::stringValue($raw['channel'], 16),
            'installationId' => self::stringValue($raw['installationId'], 36),
            'sessionId' => self::stringValue($raw['sessionId'], 36),
            'windowsMajor' => (int)($env['windowsMajor'] ?? 0),
            'windowsBuild' => self::stringValue($env['windowsBuild'] ?? '', 32),
            'powershellMajor' => (int)($env['powershellMajor'] ?? 0),
            'isAdmin' => (bool)($env['isAdmin'] ?? false),
            'deviceType' => self::stringValue($env['deviceType'] ?? '', 32),
            'locale' => self::stringValue($env['locale'] ?? '', 24),
            'ramGbBucket' => self::stringValue($hardware['ramGbBucket'] ?? '', 32),
            'storageTypes' => array_values(array_filter(array_map(fn($v) => self::stringValue($v, 32), array_slice((array)($hardware['storageTypes'] ?? []), 0, 8)))),
            'diskCount' => max(0, min(32, (int)($hardware['diskCount'] ?? 0))),
            'batteryPresent' => (bool)($hardware['batteryPresent'] ?? false),
            'workStatus' => self::stringValue($scan['workStatus'] ?? '', 32),
            'findingCount' => max(0, min(100, (int)($scan['findingCount'] ?? 0))),
            'findings' => $findings,
            'operations' => $operations,
            'actions' => $actions,
        ];
    }

    private static function mustString(array $data, string $key, int $max): void
    {
        if (self::stringValue($data[$key] ?? '', $max) === '') {
            throw new \InvalidArgumentException("missing_or_invalid_{$key}");
        }
    }

    private static function mustUuid(array $data, string $key): void
    {
        $value = self::stringValue($data[$key] ?? '', 36);
        if (!preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i', $value)) {
            throw new \InvalidArgumentException("missing_or_invalid_{$key}");
        }
    }

    private static function stringValue(mixed $value, int $max): string
    {
        $value = is_scalar($value) ? trim((string)$value) : '';
        return substr($value, 0, $max);
    }
}
