# WinTune server

## Requirements

- PHP 8.2+ with PDO MySQL, OpenSSL and ZipArchive.
- MySQL 8+ or MariaDB with JSON support.
- Nginx or an equivalent HTTPS reverse proxy.
- A DNS hostname pointing to the VPS; do not distribute raw-IP update URLs.
- A valid TLS certificate.

## Setup

```bash
cp .env.example .env
# Edit .env
mysql -u wintune_api -p wintune < database/schema.sql
```

Generate a strong pepper:

```bash
openssl rand -hex 32
```

Generate an admin password hash:

```bash
php -r "echo password_hash('choose-a-strong-password', PASSWORD_DEFAULT), PHP_EOL;"
```

Generate release signing keys **outside** the web root:

```bash
./scripts/generate_update_key.sh /secure/wintune-keys
```

The private PEM is release-server-only. Copy only the generated `.cer` file into `Client/Bootstrap/keys/` before packaging the client starter ZIP.

## Create beta codes

Hash the code with the same `APP_PEPPER` set in `.env`:

```bash
php -r "echo hash_hmac('sha256', 'YOUR-BETA-CODE', 'YOUR_APP_PEPPER'), PHP_EOL;"
```

Then insert the returned hash:

```sql
INSERT INTO beta_codes (code_hash, label) VALUES ('HASH_HERE', 'friend-01');
```

Give friends the plaintext beta code only through a private channel. The server stores only its HMAC hash.

## Release flow

1. Update Client/App code and its `appsettings.json`.
2. Run `scripts/build_release.php` with the private PEM.
3. Ensure `/releases/` is served as static HTTPS content by Nginx.
4. Copy the public `.cer` into the distributed `Client/Bootstrap/keys/`.
5. Enable update checks and point the launcher to `/v1/updates/manifest?channel=beta`.

The builder produces a signed manifest envelope. The client validates the manifest signature, package SHA-256 and file hash list before switching `current.json`.

## API endpoints

- `GET /v1/updates/manifest?channel=beta`
- `POST /v1/enroll`
- `POST /v1/telemetry/events`
- `POST /v1/feedback`
- `GET /admin`

The telemetry validator whitelists fields and discards unknown data. Keep web-server access logs, PHP logs, database backups, and retention policies under your operational control.
