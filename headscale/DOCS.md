# Home Assistant Add-on: Headscale

[Headscale](https://headscale.net/) is an open source, self-hosted
implementation of the Tailscale control server.

## Configuration

On startup the add-on automatically generates `/etc/headscale/config.yaml`
from the options below. Manual edits to the file are overwritten on every
restart — with one exception: the DNS settings and OIDC access
restrictions, which are owned by Headplane or by the user and are
preserved (see "DNS and OIDC restrictions" below).

### Main options

| Option | Default | Description |
|---|---|---|
| `server_url` | `http://homeassistant.local:8080` | Public URL clients use to reach Headscale. To use it outside the LAN you need a reachable domain (typically behind a TLS reverse proxy). |
| `log_level` | `info` | Log verbosity (`trace`…`error`). |
| `ipv4_prefix` / `ipv6_prefix` | `100.64.0.0/10` / `fd7a:115c:a1e0::/48` | Ranges tailnet addresses are allocated from. |
| `address_allocation` | `sequential` | How IPs are assigned to new nodes (`sequential` or `random`). |
| `ephemeral_node_inactivity_timeout` | `30m` | Time before an inactive ephemeral node is removed. |
| `policy_mode` | `file` | Where ACLs are stored: `file` (HuJSON file, see `policy_path`) or `database` (managed via the Headscale API/CLI). |
| `policy_path` | — | (Optional, `policy_mode: file` only) path to a HuJSON ACL file, e.g. `/etc/headscale/acl.hujson`. Place the file in the add-on configuration folder. |

### OpenID Connect (optional)

With `oidc_enabled: true` user authentication is delegated to an OIDC
identity provider. In that case `oidc_issuer`, `oidc_client_id` and
`oidc_client_secret` are required (the add-on refuses to start without
them).

Additional options: `oidc_expiry` (session duration, e.g. `180d`),
`oidc_scope`, `oidc_pkce_enabled`. Access restrictions
(`allowed_domains`, `allowed_users`, `allowed_groups`) are managed from
Headplane or by editing the file (see below).

### Headplane (bundled dashboard)

With `headplane_enabled: true` the add-on also runs
[Headplane](https://github.com/tale/headplane), a full web UI for
Headscale, reachable on port 3000 at the `/admin` path
(e.g. `http://homeassistant.local:3000/admin`). From there you manage
machines, users, ACLs and DNS settings.

- Login: with a Headscale API key, created from the add-on container
  terminal with `headscale apikeys create --expiration 90d`, or via
  OpenID Connect (see below).
- `headplane_base_url` must match the URL you use to reach the dashboard
  (needed for cookies and redirects); with an `https://` URL the cookies
  are automatically marked secure.
- Headscale runs in the same container: Headplane applies configuration
  changes by reloading it via SIGHUP (`proc` integration), with no
  special permissions.

How changes made from Headplane are applied:

| Change | Application |
|---|---|
| Extra DNS records | Hot, immediate (`dns_records.json` reloaded by headscale) |
| ACLs | Immediate (headscale API / SIGHUP) |
| DNS settings (nameservers, split DNS, override, base domain, MagicDNS) and OIDC restrictions | Automatic restart of the headscale service only within ~10 seconds; right after, the dashboard restarts too (to re-attach to the new process). The add-on stays up and clients reconnect on their own |

#### OIDC login for Headplane

With `headplane_oidc_enabled: true` the dashboard login happens through
OpenID Connect. If the `headplane_oidc_issuer` / `_client_id` /
`_client_secret` options are not set, headscale's OIDC settings are
reused (the recommended setup: same client on the identity provider).
It requires:

- `headplane_enabled: true` (and, when reusing the credentials,
  `oidc_enabled: true`);
- on the identity provider, allow the redirect URI
  `<headplane_base_url>/admin/oidc/callback`.

On first start the add-on automatically issues a Headscale API key
dedicated to Headplane (10-year expiration, stored in the data
directory): it is what Headplane uses to talk to the API when users log
in via OIDC. API key login remains available as a fallback.

### DNS and OIDC restrictions (Headplane or manual edits)

The DNS settings (`dns.magic_dns`, `dns.base_domain`,
`dns.override_local_dns`, `dns.nameservers`, `dns.search_domains`) and
the OIDC access restrictions (`oidc.allowed_*`) are **not add-on
options**: the generated config starts from defaults (MagicDNS on, base
domain `tailnet.internal`, Cloudflare nameservers) and they are changed
from a [Headplane](https://github.com/tale/headplane) dashboard or by
editing `config.yaml` in the configuration folder directly. This keeps a
single source of change and avoids conflicts with the UI options.

Changes to these keys survive regeneration: on every start they are
compared with the config generated at the previous start, stored as
overrides in the persistent data directory (`/var/lib/headscale`,
included in backups) and re-applied. Setting a key back to its default
removes the override. Extra DNS records live in `dns_records.json`
(referenced via `dns.extra_records_path`): Headplane writes to it and
Headscale hot-reloads it, no restart needed.

## CLI usage

Administrative commands (creating users, preauth keys, etc.) run from
the add-on container terminal, for example:

```bash
headscale users create alessio
headscale preauthkeys create --user 1
```

Alternatively the CLI can connect remotely over gRPC (port 50443,
disabled by default — enable it in the add-on network configuration): it
requires valid TLS certificates on the `server_url` and an API key
(`headscale apikeys create`).

## Data

- State and SQLite database: `/var/lib/headscale` (included in Home
  Assistant backups).
- Configuration: the `addon_config` folder, visible from the Home
  Assistant file editor.
