# WinTune deployment and releases

## One-time server setup

The public routes are served beneath `https://angusu.de/wintune/`.

1. Copy the contents of `Server/nginx/angusu-wintune.location.conf` into the HTTPS `angusu.de` server block, then run `nginx -t` and reload Nginx.
2. Create a private `.env` from `Server/.env.example`, with a generated `APP_PEPPER` and a strong password hash. Never commit it.
3. Create the database and restricted database user, then import `Server/database/schema.sql`.
4. Generate the signing key outside the web root. Put the public `.cer` in `Client/Bootstrap/keys/` before distributing the first starter ZIP; keep the PEM only in the release secret store.
5. Optionally set `WINTUNE_SOURCE_URL` in the PHP-FPM environment if the source repository moves. The default points to `https://github.com/IamAngusU/WinTune`.

The page reads `Server/storage/releases/manifests/public-release.json`; the release builder writes it atomically alongside the signed update manifest. It therefore changes its version, download URL, hash and notes only after a complete release build.

## GitHub approval gate

Create a GitHub environment named `production` and add required reviewers. Add these environment secrets:

- `WINTUNE_UPDATE_SIGNING_KEY`: PEM private key, including its header and footer.
- `WINTUNE_DEPLOY_HOST`, `WINTUNE_DEPLOY_USER`, `WINTUNE_DEPLOY_SSH_KEY`: a deploy-only SSH identity.
- `WINTUNE_DEPLOY_KNOWN_HOSTS`: the server's pinned `known_hosts` entry (obtain it from a trusted console, not from an unverified network lookup).
- `WINTUNE_RELEASE_ROOT`: `/var/www/html/AlleProjekte/wintune/Server/storage/releases`.

Run **Publish signed WinTune release** from the Actions tab, choose a version/channel, and approve the waiting `production` deployment. The workflow builds the ZIP, signs the manifest, deploys the ZIP and manifests, and attaches the identical ZIP to the public GitHub Release. Do not enable the workflow until the public certificate distributed with the launcher matches the private key stored as the GitHub secret.
