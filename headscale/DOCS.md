# Home Assistant Add-on: Headscale

[Headscale](https://headscale.net/) è un'implementazione open source e
self-hosted del control server di Tailscale.

## Configurazione

All'avvio l'add-on genera automaticamente `/etc/headscale/config.yaml` a
partire dalle opzioni qui sotto. Le modifiche manuali al file vengono
sovrascritte a ogni riavvio.

### Opzioni principali

| Opzione | Default | Descrizione |
|---|---|---|
| `server_url` | `http://homeassistant.local:8080` | URL pubblico con cui i client raggiungono Headscale. Per usarlo fuori dalla LAN serve un dominio raggiungibile (tipicamente dietro reverse proxy con TLS). |
| `log_level` | `info` | Livello di log (`trace`…`error`). |
| `ipv4_prefix` / `ipv6_prefix` | `100.64.0.0/10` / `fd7a:115c:a1e0::/48` | Range da cui vengono assegnati gli indirizzi della tailnet. |
| `address_allocation` | `sequential` | Strategia di assegnazione degli IP ai nuovi nodi (`sequential` o `random`). |
| `ephemeral_node_inactivity_timeout` | `30m` | Tempo dopo il quale un nodo effimero inattivo viene rimosso. |
| `policy_mode` | `file` | Dove sono salvate le ACL: `file` (file HuJSON, vedi `policy_path`) o `database` (gestite via API/CLI di Headscale). |
| `policy_path` | — | (Opzionale, solo con `policy_mode: file`) percorso di un file ACL HuJSON, ad es. `/etc/headscale/acl.hujson`. Mettere il file nella cartella di configurazione dell'add-on. |

### OpenID Connect (opzionale)

Con `oidc_enabled: true` l'autenticazione degli utenti è delegata a un
identity provider OIDC. In tal caso `oidc_issuer`, `oidc_client_id` e
`oidc_client_secret` sono obbligatori (l'add-on si rifiuta di partire se
mancano).

Opzioni aggiuntive: `oidc_expiry` (durata della sessione, es. `180d`),
`oidc_scope`, `oidc_pkce_enabled`. Le restrizioni di accesso
(`allowed_domains`, `allowed_users`, `allowed_groups`) si gestiscono da
Headplane o modificando il file (vedi sotto).

### Headplane (dashboard integrata)

Con `headplane_enabled: true` l'add-on avvia anche
[Headplane](https://github.com/tale/headplane), una web UI completa per
Headscale, raggiungibile sulla porta 3000 al percorso `/admin`
(es. `http://homeassistant.local:3000/admin`). Da lì si gestiscono
macchine, utenti, ACL e impostazioni DNS.

- Login: con una API key di Headscale, da creare dal terminale dell'add-on
  con `headscale apikeys create --expiration 90d`.
- `headplane_base_url` deve corrispondere all'URL con cui si raggiunge la
  dashboard (serve per cookie e redirect); con un URL `https://` i cookie
  vengono marcati secure automaticamente.
- Headscale gira nello stesso container: Headplane applica le modifiche
  alla configurazione ricaricandolo via SIGHUP (integrazione `proc`),
  senza permessi speciali.

### DNS e restrizioni OIDC (Headplane o modifica manuale)

Le impostazioni DNS (`dns.magic_dns`, `dns.base_domain`,
`dns.override_local_dns`, `dns.nameservers`, `dns.search_domains`) e le
restrizioni di accesso OIDC (`oidc.allowed_*`) **non sono opzioni
dell'add-on**: nel config generato partono dai default (MagicDNS attivo,
base domain `tailnet.internal`, nameserver Cloudflare) e si modificano da
una dashboard [Headplane](https://github.com/tale/headplane) oppure
modificando direttamente `config.yaml` nella cartella di configurazione.
Così c'è un'unica fonte di modifica e nessun rischio di conflitto con la UI.

Le modifiche a queste chiavi sopravvivono alla rigenerazione: a ogni avvio
vengono confrontate col config generato all'avvio precedente, salvate come
override nella directory dati persistente (`/var/lib/headscale`, inclusa
nei backup) e riapplicate. Riportare una chiave al suo valore di default
rimuove l'override. I record DNS extra vivono in
`dns_records.json` (referenziato via `dns.extra_records_path`): Headplane ci
scrive e Headscale li ricarica a caldo, senza riavvio.

## Uso della CLI

I comandi amministrativi (creazione utenti, preauth key, ecc.) si eseguono
dal terminale del container dell'add-on, ad esempio:

```bash
headscale users create alessio
headscale preauthkeys create --user 1
```

In alternativa la CLI può collegarsi da remoto via gRPC (porta 50443,
disabilitata di default — abilitarla nella configurazione di rete
dell'add-on): richiede certificati TLS validi sul `server_url` e una API key
(`headscale apikeys create`).

## Dati

- Stato e database SQLite: `/var/lib/headscale` (incluso nei backup di
  Home Assistant).
- Configurazione: cartella `addon_config`, visibile dall'editor file di
  Home Assistant.
