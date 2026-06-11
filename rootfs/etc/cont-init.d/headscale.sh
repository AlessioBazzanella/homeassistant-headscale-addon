#!/command/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Home Assistant Community Add-on: Headscale
# Generates the Headscale configuration from the add-on options.
#
# The config is re-rendered from the options on every start. The DNS and
# OIDC-restriction keys are not exposed as options: they are owned by
# Headplane (or by manual edits to the config file). On each start the live
# config is diffed against the baseline rendered at the previous start; the
# differences are stored in /data/headplane_overrides.yaml and re-applied on
# top of the fresh render. A key set back to its rendered value drops its
# override, so reverting to defaults works too.
# ==============================================================================
readonly CONFIG='/etc/headscale/config.yaml'
readonly RENDER='/tmp/headscale-config.rendered.yaml'
readonly BASELINE='/data/last_rendered_config.yaml'
readonly OVERRIDES='/data/headplane_overrides.yaml'
readonly OPTIONS='/tmp/options.json'

# Recent Supervisors no longer write /data/options.json: fetch the add-on
# options through the Supervisor API, the same way bashio itself does.
bashio::addon.config > "${OPTIONS}"

# Headscale's CLI talks to the server over this unix socket; /run is a
# tmpfs, so the directory must be recreated on every container start.
mkdir -p /var/run/headscale

# Extra DNS records live outside the config (dns.extra_records_path) so that
# Headplane can edit them and headscale hot-reloads them without a restart.
if ! bashio::fs.file_exists '/etc/headscale/dns_records.json'; then
    echo '[]' > /etc/headscale/dns_records.json
fi

if bashio::config.true 'oidc_enabled'; then
    bashio::config.require 'oidc_issuer' "'oidc_enabled' is set to true"
    bashio::config.require 'oidc_client_id' "'oidc_enabled' is set to true"
    bashio::config.require 'oidc_client_secret' "'oidc_enabled' is set to true"
fi

bashio::log.info "Generating Headscale configuration: ${CONFIG}"
tempio \
    -conf "${OPTIONS}" \
    -template /usr/share/tempio/headscale.config.gtpl \
    -out "${RENDER}"

# Keys owned by Headplane / manual config edits.
managed_paths=(
    '.dns.magic_dns'
    '.dns.base_domain'
    '.dns.override_local_dns'
    '.dns.nameservers.global'
    '.dns.nameservers.split'
    '.dns.search_domains'
)
if bashio::config.true 'oidc_enabled'; then
    managed_paths+=(
        '.oidc.allowed_domains'
        '.oidc.allowed_users'
        '.oidc.allowed_groups'
    )
fi

if ! bashio::fs.file_exists "${OVERRIDES}"; then
    echo '{}' > "${OVERRIDES}"
fi

if bashio::fs.file_exists "${BASELINE}" && bashio::fs.file_exists "${CONFIG}"; then
    for path in "${managed_paths[@]}"; do
        live=$(yq -o=json "${path}" "${CONFIG}")
        old=$(yq -o=json "${path}" "${BASELINE}")
        if [[ "${live}" == "${old}" || "${live}" == "null" ]]; then
            # In sync with the render (or key removed): no override needed.
            # This also makes reverting a key to its default work.
            yq -i "del(${path})" "${OVERRIDES}"
        else
            bashio::log.info "Preserving external change: ${path}"
            yq -i "${path} = ${live}" "${OVERRIDES}"
        fi
    done
fi

# Fresh render + stored Headplane overrides (deep merge, arrays replaced)
yq eval-all '. as $item ireduce ({}; . * $item)' \
    "${RENDER}" "${OVERRIDES}" > "${CONFIG}"
cp "${RENDER}" "${BASELINE}"

# ------------------------------------------------------------------------------
# Headplane dashboard
# ------------------------------------------------------------------------------
if bashio::config.true 'headplane_enabled'; then
    bashio::log.info 'Generating Headplane configuration: /etc/headplane/config.yaml'
    mkdir -p /etc/headplane /data/headplane

    # Headplane wants a stable 32-char secret to sign its session cookies
    if ! bashio::fs.file_exists /data/headplane_cookie_secret; then
        head -c 100 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' \
            | head -c 32 > /data/headplane_cookie_secret
    fi

    tempio \
        -conf "${OPTIONS}" \
        -template /usr/share/tempio/headplane.config.gtpl \
        -out /etc/headplane/config.yaml

    cookie_secret=$(< /data/headplane_cookie_secret)
    cookie_secure=false
    if [[ "$(bashio::config 'headplane_base_url')" == https://* ]]; then
        cookie_secure=true
    fi
    yq -i ".server.cookie_secret = \"${cookie_secret}\"
         | .server.cookie_secure = ${cookie_secure}" /etc/headplane/config.yaml
fi
