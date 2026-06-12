# Home Assistant Add-on: Headscale

[Headscale](https://headscale.net/) is an open source, self-hosted
implementation of the Tailscale control server: run your own tailnet
without depending on Tailscale Inc. servers.

## Features

- **Headscale** installed from the official upstream package, fully
  configured from the add-on options (OIDC included).
- **Bundled [Headplane](https://github.com/tale/headplane) dashboard**
  (optional): manage machines, users, ACLs, DNS settings and extra DNS
  records from a web UI, with API key or OpenID Connect login.
- **Worry-free DNS changes**: extra records are hot-reloaded; settings
  that require a headscale restart are applied automatically (service
  only, the add-on stays up) and survive restarts and updates.
- **Prebuilt multi-arch images** (aarch64/amd64) published on GitHub
  Container Registry: installing and updating is a plain download, no
  local builds.
- **AppArmor profile** included.

## Getting started

1. Install the add-on and set at least `server_url` in the configuration.
2. Start it and register your Tailscale clients against your `server_url`.
3. (Recommended) Enable `headplane_enabled` and open the dashboard at
   `http://<host>:3000/admin`.

All the details (options, OIDC, Headplane, DNS management, CLI) are in
the **Documentation** tab.
