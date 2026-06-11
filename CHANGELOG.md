# CHANGELOG

## 0.28.0.3 (2026-06-11)

- Fix startup failure: store add-on state (render baseline, Headplane overrides, cookie secret) in `/var/lib/headscale` — `/data` is not mounted when the data map uses a custom path

## 0.28.0.2 (2026-06-11)

- Fix startup failure on recent Supervisors: read the add-on options through the Supervisor API instead of `/data/options.json`, which is no longer provided

## 0.28.0.1 (2026-06-11)

- Generate the Headscale configuration automatically from the add-on options (server URL, IP prefixes and allocation strategy, log level, ACL policy mode/path, optional OpenID Connect section)
- DNS settings and OIDC access restrictions are not add-on options: they are managed from a Headplane dashboard or by editing the config file, and such changes are preserved across config regenerations (stored as overrides in `/data`); extra DNS records live in a hot-reloaded `dns_records.json`
- Bundle the [Headplane](https://github.com/tale/headplane) 0.6.3 dashboard as an optional second service (`headplane_enabled` option, port 3000, path `/admin`), wired to headscale via the proc/SIGHUP integration
- Publish prebuilt multi-arch images to `ghcr.io/alessiobazzanella/addon-headscale` via GitHub Actions: Home Assistant now pulls the image instead of building it locally
- Fix image cleanup in Dockerfile (apt lists and downloaded .deb were not removed)

## 0.28.0 (2026-03-16)

- Update to version 0.28.0 from juanfont/headscale (changelog : https://github.com/juanfont/headscale/releases/tag/v0.28.0)

## 0.27.1 (2026-03-16)

- Update to version 0.27.1 from juanfont/headscale (changelog : https://github.com/juanfont/headscale/releases/tag/v0.27.1)

## 0.27.0 (2026-03-16)

- Update to version 0.27.0 from juanfont/headscale (changelog : https://github.com/juanfont/headscale/releases/tag/v0.27.0)

## 0.2.0 (2026-03-16)

- Migrate from alpine to debian based image

## 0.1.0 (2025-08-18)

- 🎉 Initial add-on release with headscale 0.26.1 🎉
