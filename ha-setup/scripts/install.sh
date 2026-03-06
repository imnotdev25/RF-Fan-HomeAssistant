#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
#  setup.sh — Home Assistant Docker Stack — Master Setup Script
#
#  Creates ~/homeassistant-docker/ with the full repo layout.
#  Add-ons are optional — you will be asked which ones to install.
#
#  Usage:
#    chmod +x setup.sh && ./setup.sh
# ═══════════════════════════════════════════════════════════════════════════
set -euo pipefail

# ── Colours ───────────────────────────────────────────────────────────────
RED='\033[0;31m';  GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m';     DIM='\033[2m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; exit 1; }
header()  { echo -e "\n${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n  $*\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"; }
ask()     { echo -e "${YELLOW}$*${RESET}"; }

# ── Helper: write file only if it does not already exist ──────────────────
write_file() {
    local dest="$1"; local content="$2"
    if [[ -f "$dest" ]]; then warn "Skipping (exists): $dest"; return; fi
    printf '%s' "$content" > "$dest"
    success "Written  $dest"
}

# ── Base dir ──────────────────────────────────────────────────────────────
BASE_DIR="$HOME/homeassistant-docker"

# ═══════════════════════════════════════════════════════════════════════════
#  WELCOME BANNER
# ═══════════════════════════════════════════════════════════════════════════
clear
echo -e "${BOLD}${CYAN}"
echo "  ██╗  ██╗ █████╗     ██████╗  ██████╗  ██████╗██╗  ██╗███████╗██████╗ "
echo "  ██║  ██║██╔══██╗    ██╔══██╗██╔═══██╗██╔════╝██║ ██╔╝██╔════╝██╔══██╗"
echo "  ███████║███████║    ██║  ██║██║   ██║██║     █████╔╝ █████╗  ██████╔╝"
echo "  ██╔══██║██╔══██║    ██║  ██║██║   ██║██║     ██╔═██╗ ██╔══╝  ██╔══██╗"
echo "  ██║  ██║██║  ██║    ██████╔╝╚██████╔╝╚██████╗██║  ██╗███████╗██║  ██║"
echo "  ╚═╝  ╚═╝╚═╝  ╚═╝    ╚═════╝  ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝"
echo -e "${RESET}"
echo -e "  ${BOLD}Home Assistant Docker Stack — Interactive Setup${RESET}"
echo -e "  ${DIM}Target: $BASE_DIR${RESET}"
echo ""

# ── Existing dir check ────────────────────────────────────────────────────
if [[ -d "$BASE_DIR" ]]; then
    warn "Directory $BASE_DIR already exists."
    ask "Continue and overwrite config files? Existing files are skipped. [y/N]: "
    read -r CONFIRM
    [[ "${CONFIRM,,}" == "y" ]] || { info "Aborted."; exit 0; }
fi

# ═══════════════════════════════════════════════════════════════════════════
#  STEP 1 — ADD-ONS SELECTION
# ═══════════════════════════════════════════════════════════════════════════
header "Step 1 of 5 · Choose your Add-ons"

echo -e "  The core stack (Home Assistant, Mosquitto, PostgreSQL, Watchtower)"
echo -e "  will always be installed.\n"
echo -e "  Select which ${BOLD}optional add-ons${RESET} you want. Press Enter to skip any.\n"

# Associative map: key → "Name|Port|Description"
declare -A ADDON_META=(
    [nodered]="Node-RED|1880|Visual drag-and-drop automation flows"
    [zigbee2mqtt]="Zigbee2MQTT|8080|Zigbee USB dongle to MQTT bridge"
    [zwavejs]="Z-Wave JS UI|8091|Z-Wave USB stick bridge + web UI"
    [esphome]="ESPHome|6052|ESP8266/ESP32 firmware builder & OTA dashboard"
    [grafana]="Grafana|3000|Long-term history dashboards (reads HA PostgreSQL)"
    [codeserver]="code-server|8443|VS Code in the browser for editing HA config"
)

# Ordered list for display
ADDON_ORDER=(nodered zigbee2mqtt zwavejs esphome grafana codeserver)

# Will hold selected add-ons
declare -A SELECTED_ADDONS=()

for key in "${ADDON_ORDER[@]}"; do
    IFS='|' read -r name port desc <<< "${ADDON_META[$key]}"
    echo -e "  ${BOLD}${name}${RESET} ${DIM}(port ${port})${RESET}"
    echo -e "  ${DIM}${desc}${RESET}"
    ask "  Install ${name}? [y/N]: "
    read -r choice
    if [[ "${choice,,}" == "y" ]]; then
        SELECTED_ADDONS[$key]=1
        success "  ✓ ${name} selected"
    else
        echo -e "  ${DIM}  Skipped${RESET}"
    fi
    echo ""
done

# Summary
echo -e "${BOLD}Selected add-ons:${RESET}"
if [[ ${#SELECTED_ADDONS[@]} -eq 0 ]]; then
    echo -e "  ${DIM}None — core stack only${RESET}"
else
    for key in "${ADDON_ORDER[@]}"; do
        if [[ -v SELECTED_ADDONS[$key] ]]; then
            IFS='|' read -r name port desc <<< "${ADDON_META[$key]}"
            echo -e "  ${GREEN}✓${RESET} $name"
        fi
    done
fi
echo ""
ask "Proceed with this selection? [Y/n]: "
read -r PROCEED
[[ "${PROCEED,,}" == "n" ]] && { info "Aborted. Re-run setup.sh to try again."; exit 0; }

# ═══════════════════════════════════════════════════════════════════════════
#  STEP 2 — CREATE DIRECTORY STRUCTURE
# ═══════════════════════════════════════════════════════════════════════════
header "Step 2 of 5 · Creating directories"

# Core dirs (always created)
CORE_DIRS=(
    "$BASE_DIR/docs"
    "$BASE_DIR/homeassistant"
    "$BASE_DIR/mosquitto"
    "$BASE_DIR/postgres"
    "$BASE_DIR/scripts"
    "$BASE_DIR/docker"
)

for dir in "${CORE_DIRS[@]}"; do
    mkdir -p "$dir"; success "Created $dir"
done

# Add-on dirs (only if selected)
[[ -v SELECTED_ADDONS[nodered]     ]] && { mkdir -p "$BASE_DIR/nodered";              success "Created $BASE_DIR/nodered"; }
[[ -v SELECTED_ADDONS[zigbee2mqtt] ]] && { mkdir -p "$BASE_DIR/zigbee2mqtt";           success "Created $BASE_DIR/zigbee2mqtt"; }
[[ -v SELECTED_ADDONS[zwavejs]     ]] && { mkdir -p "$BASE_DIR/zwave-js-ui";           success "Created $BASE_DIR/zwave-js-ui"; }
[[ -v SELECTED_ADDONS[esphome]     ]] && { mkdir -p "$BASE_DIR/esphome";               success "Created $BASE_DIR/esphome"; }
[[ -v SELECTED_ADDONS[grafana]     ]] && { mkdir -p "$BASE_DIR/grafana/provisioning";  success "Created $BASE_DIR/grafana"; }
[[ -v SELECTED_ADDONS[codeserver]  ]] && { mkdir -p "$BASE_DIR/code-server";           success "Created $BASE_DIR/code-server"; }

# ═══════════════════════════════════════════════════════════════════════════
#  STEP 3 — WRITE CORE FILES
# ═══════════════════════════════════════════════════════════════════════════
header "Step 3 of 5 · Writing core config files"

# ── .gitignore ────────────────────────────────────────────────────────────
GITIGNORE_ADDONS=""
[[ -v SELECTED_ADDONS[nodered]    ]] && GITIGNORE_ADDONS+=$'\nnodered/.config.runtime.json\nnodered/flows_cred.json'
[[ -v SELECTED_ADDONS[zigbee2mqtt] ]] && GITIGNORE_ADDONS+=$'\n# zigbee2mqtt: secrets are inside its configuration.yaml'
[[ -v SELECTED_ADDONS[zwavejs]    ]] && GITIGNORE_ADDONS+=$'\nzwave-js-ui/.config-db/'
[[ -v SELECTED_ADDONS[esphome]    ]] && GITIGNORE_ADDONS+=$'\nesphome/*.yaml'
[[ -v SELECTED_ADDONS[grafana]    ]] && GITIGNORE_ADDONS+=$'\ngrafana/'
[[ -v SELECTED_ADDONS[codeserver] ]] && GITIGNORE_ADDONS+=$'\ncode-server/'

write_file "$BASE_DIR/.gitignore" \
".env
homeassistant/secrets.yaml
homeassistant/.storage/
mosquitto/passwd
postgres/
*.log${GITIGNORE_ADDONS}
"

# ── .env ──────────────────────────────────────────────────────────────────
# Build the add-on ports section dynamically
ADDON_ENV_BLOCK=""
[[ -v SELECTED_ADDONS[nodered]     ]] && ADDON_ENV_BLOCK+=$'\nNODE_RED_PORT=1880\nNODE_RED_CREDENTIAL_SECRET=change_me_nodered_secret'
[[ -v SELECTED_ADDONS[zigbee2mqtt] ]] && ADDON_ENV_BLOCK+=$'\nZIGBEE2MQTT_PORT=8080'
[[ -v SELECTED_ADDONS[zwavejs]     ]] && ADDON_ENV_BLOCK+=$'\nZWAVEJS_PORT=8091\nZWAVEJS_SESSION_SECRET=change_me_zwave_secret'
[[ -v SELECTED_ADDONS[esphome]     ]] && ADDON_ENV_BLOCK+=$'\nESPHOME_PORT=6052'
[[ -v SELECTED_ADDONS[codeserver]  ]] && ADDON_ENV_BLOCK+=$'\nCODE_SERVER_PORT=8443\nCODE_SERVER_PASSWORD=change_me_code_server_password'
[[ -v SELECTED_ADDONS[grafana]     ]] && ADDON_ENV_BLOCK+=$'\nGRAFANA_PORT=3000\nGRAFANA_DOMAIN=grafana.yourdomain.com\nGRAFANA_ADMIN_USER=admin\nGRAFANA_ADMIN_PASSWORD=change_me_grafana\nGRAFANA_LOGTO_CLIENT_ID=your_grafana_client_id\nGRAFANA_LOGTO_CLIENT_SECRET=your_grafana_client_secret'

if [[ ! -f "$BASE_DIR/.env" ]]; then
    cat > "$BASE_DIR/.env" << ENVEOF
# ─────────────────────────────────────────────────────────────────────────
#  HOME ASSISTANT DOCKER STACK — ENVIRONMENT
#  Edit this file before running docker compose.
# ─────────────────────────────────────────────────────────────────────────

# ── General ───────────────────────────────────────────────────────────────
TZ=Europe/London
HOST_IP=192.168.1.100

# ── Custom Domain ─────────────────────────────────────────────────────────
HA_DOMAIN=ha.yourdomain.com

# ── PostgreSQL (Home Assistant recorder) ──────────────────────────────────
POSTGRES_DB=homeassistant
POSTGRES_USER=homeassistant
POSTGRES_PASSWORD=change_me_ha_db_password

# ── Logto OAuth — your existing deployment ────────────────────────────────
LOGTO_DOMAIN=auth.yourdomain.com
LOGTO_CLIENT_ID=your_ha_client_id
LOGTO_CLIENT_SECRET=your_ha_client_secret

# ── Mosquitto MQTT — leave empty for anonymous access ─────────────────────
MQTT_USER=
MQTT_PASSWORD=

# ── Watchtower ────────────────────────────────────────────────────────────
WATCHTOWER_SCHEDULE=0 0 4 * * *
$(if [[ -n "$ADDON_ENV_BLOCK" ]]; then echo -e "\n# ── Add-on settings ──────────────────────────────────────────────────────${ADDON_ENV_BLOCK}"; fi)
ENVEOF
    success "Written  $BASE_DIR/.env"
else
    warn "Skipping (exists): $BASE_DIR/.env"
fi

# ── docs/README.md ────────────────────────────────────────────────────────
ADDONS_COMPOSE_CMD=""
if [[ ${#SELECTED_ADDONS[@]} -gt 0 ]]; then
    ADDONS_COMPOSE_CMD=$'\n\n# Core + selected add-ons\ndocker compose -f docker/docker-compose.yml \\\n               -f docker/docker-compose.addons.yml up -d'
fi

write_file "$BASE_DIR/docs/README.md" \
"# Home Assistant Docker Stack

Production-ready Docker Compose setup for Home Assistant with Mosquitto,
PostgreSQL (long-term history), Logto OAuth, HomeKit Bridge, Bluetooth/D-Bus,
and Watchtower.

## Quick Start

\`\`\`bash
cd ~/homeassistant-docker
nano .env                  # fill in passwords, domains, HOST_IP
nano homeassistant/secrets.yaml   # recorder_db_url, homekit_advertise_ip

# Core stack
docker compose -f docker/docker-compose.yml up -d${ADDONS_COMPOSE_CMD}
\`\`\`

See \`docs/ADDONS.md\` for add-on setup details.
"

# ── docs/ADDONS.md ────────────────────────────────────────────────────────
write_file "$BASE_DIR/docs/ADDONS.md" \
'# Community Add-ons

| Add-on | Port | Purpose |
|---|---|---|
| Node-RED | 1880 | Visual automation flows |
| Zigbee2MQTT | 8080 | Zigbee dongle → MQTT bridge |
| Z-Wave JS UI | 8091 | Z-Wave dongle bridge + web UI |
| ESPHome | 6052 | ESP8266/ESP32 firmware builder |
| Grafana | 3000 | Long-term sensor dashboards |
| code-server | 8443 | VS Code in the browser |

See inline comments in `docker/docker-compose.addons.yml` for dongle device paths.
'

# ── homeassistant/configuration.yaml ─────────────────────────────────────
write_file "$BASE_DIR/homeassistant/configuration.yaml" \
'# ═══════════════════════════════════════════════════════════════════
#  Home Assistant — configuration.yaml
# ═══════════════════════════════════════════════════════════════════

default_config:

# ── HTTP — reverse-proxy / custom domain ──────────────────────────
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 127.0.0.1
    - ::1
    - 10.0.0.0/8
    - 172.16.0.0/12
    - 192.168.0.0/16

# ── Authentication ────────────────────────────────────────────────
#homeassistant:
#  auth_providers:
#    - type: custom_auth_provider   # this is the type hass-oidc-auth registers
#      module_name: custom_components.oidc
#      config:
#        client_id: !secret logto_client_id
#        client_secret: !secret logto_client_secret
#        discovery_url: !secret logto_discovery_url
#        # The redirect URI registered in Logto
#        redirect_uri: !secret logto_redirect_uri
#        # User claim to use as the HA username
#        name_claim: "name"
#        username_claim: "email"


# ── Recorder — PostgreSQL long-term history ──────────────────────
recorder:
  db_url: !secret recorder_db_url
  purge_keep_days: 90
  commit_interval: 5
  exclude:
    domains:
      - automation
      - updater
    entity_globs:
      - sensor.weather_*

# ── HomeKit Bridge ────────────────────────────────────────────────
homekit:
  - name: "Home Assistant Bridge"
    port: 21063
    advertise_ip: !secret homekit_advertise_ip
    filter:
      include_domains:
        - light
        - switch
        - cover
        - climate
        - alarm_control_panel
        - lock
        - sensor
        - binary_sensor
        - fan
        - media_player

# ── Logger ────────────────────────────────────────────────────────
logger:
  default: warning
  logs:
    homeassistant.components.recorder: info
    homeassistant.components.homekit: info

lovelace:
  mode: storage

fans: !include rf_fans.yaml

# automation: !include automations.yaml
# script:     !include scripts.yaml
# scene:      !include scenes.yaml
'

# ── homeassistant/secrets.yaml ────────────────────────────────────────────
write_file "$BASE_DIR/homeassistant/secrets.yaml" \
'# ─────────────────────────────────────────────
#  Home Assistant — secrets.yaml
#  Never commit this file!
# ─────────────────────────────────────────────
recorder_db_url: "postgresql://homeassistant:CHANGE_ME@localhost:5432/homeassistant"
homekit_advertise_ip: "192.168.1.100"
logto_client_id: "your_ha_client_id"
logto_client_secret: "your_ha_client_secret"
logto_discovery_url: "https://auth.yourdomain.com/oidc/.well-known/openid-configuration"
logto_redirect_uri: "https://ha.yourdomain.com/auth/oidc/callback"
# mqtt_username: ""
# mqtt_password: ""
'

# ── mosquitto/mosquitto.conf ──────────────────────────────────────────────
write_file "$BASE_DIR/mosquitto/mosquitto.conf" \
'# ─────────────────────────────────────────────
#  Mosquitto MQTT Broker Configuration
# ─────────────────────────────────────────────
listener 1883
protocol mqtt

listener 9001
protocol websockets

# Anonymous access ON by default.
# Run scripts/create-mqtt-user.sh to add a user,
# then flip allow_anonymous → false and uncomment password_file.
allow_anonymous true
# allow_anonymous false
# password_file /mosquitto/config/passwd

persistence true
persistence_location /mosquitto/data/

log_dest file /mosquitto/log/mosquitto.log
log_dest stdout
log_type error
log_type warning
log_type notice
log_type information

max_connections -1
max_queued_messages 1000
'

# ── scripts/create-mqtt-user.sh ───────────────────────────────────────────
write_file "$BASE_DIR/scripts/create-mqtt-user.sh" \
'#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────
#  create-mqtt-user.sh — Add/update a Mosquitto username and password
#
#  Usage:
#    ./scripts/create-mqtt-user.sh [username] [password]
#    ./scripts/create-mqtt-user.sh          # interactive prompts
#
#  After running:
#    1. Edit mosquitto/mosquitto.conf
#    2. Set:   allow_anonymous false
#    3. Set:   password_file /mosquitto/config/passwd
#    4. Run:   docker compose -f docker/docker-compose.yml restart mosquitto
# ─────────────────────────────────────────────────────────────────────────
set -euo pipefail

PASSWD_FILE="$(cd "$(dirname "$0")/.." && pwd)/mosquitto/passwd"
MOSQUITTO_CONTAINER="mosquitto"

if [[ -n "${1:-}" ]]; then MQTT_USER="$1"
else read -rp "Enter MQTT username: " MQTT_USER; fi
[[ -z "$MQTT_USER" ]] && { echo "Error: username empty." >&2; exit 1; }

if [[ -n "${2:-}" ]]; then MQTT_PASS="$2"
else
    read -rsp "Enter MQTT password: " MQTT_PASS; echo
    read -rsp "Confirm password: "    MQTT_CONF; echo
    [[ "$MQTT_PASS" != "$MQTT_CONF" ]] && { echo "Passwords do not match." >&2; exit 1; }
fi
[[ -z "$MQTT_PASS" ]] && { echo "Error: password empty." >&2; exit 1; }

if docker ps --format '"'"'{{.Names}}'"'"' | grep -q "^${MOSQUITTO_CONTAINER}$"; then
    docker exec -i "$MOSQUITTO_CONTAINER" \
        sh -c "mosquitto_passwd -b /mosquitto/config/passwd '"'"'$MQTT_USER'"'"' '"'"'$MQTT_PASS'"'"'"
    echo "✓ User saved in container."
else
    command -v mosquitto_passwd &>/dev/null || {
        echo "Start mosquitto first: docker compose -f docker/docker-compose.yml up -d mosquitto"
        exit 1
    }
    mosquitto_passwd -b "$PASSWD_FILE" "$MQTT_USER" "$MQTT_PASS"
    echo "✓ Written to $PASSWD_FILE"
fi

echo ""
echo "Next: mosquitto/mosquitto.conf → allow_anonymous false"
echo "      docker compose -f docker/docker-compose.yml restart mosquitto"
'

# ── docker/docker-compose.yml (core) ─────────────────────────────────────
write_file "$BASE_DIR/docker/docker-compose.yml" \
'# ═══════════════════════════════════════════════════════════════════════════
#  HOME ASSISTANT CORE STACK
#  Home Assistant · Mosquitto · PostgreSQL · Watchtower
#
#  Run from repo root:
#    docker compose -f docker/docker-compose.yml up -d
# ═══════════════════════════════════════════════════════════════════════════

services:

  homeassistant:
    container_name: homeassistant
    image: ghcr.io/home-assistant/home-assistant:stable
    restart: always
    network_mode: host
    privileged: false
    cap_add:
      - NET_ADMIN
      - NET_RAW
      - SYS_ADMIN
    volumes:
      - ../homeassistant:/config
      - /run/dbus:/run/dbus # :ro for read only
      - /etc/localtime:/etc/localtime:ro
    environment:
      TZ: ${TZ}
    depends_on:
      postgres:
        condition: service_healthy
      mosquitto:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-fsSL", "http://localhost:8123/api/"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 90s

  mosquitto:
    container_name: mosquitto
    image: eclipse-mosquitto:2
    restart: always
    ports:
      - "1883:1883"
      - "9001:9001"
    volumes:
      - ../mosquitto:/mosquitto/config:ro
      - mosquitto_data:/mosquitto/data
      - mosquitto_log:/mosquitto/log
    healthcheck:
      test: ["CMD-SHELL", "mosquitto_pub -h localhost -t '\''$$SYS/healthcheck'\'' -m '\'''\'' -q 0 2>/dev/null || exit 0"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s

  postgres:
    container_name: postgres_ha
    image: postgres:16-alpine
    restart: always
    ports:
      - "127.0.0.1:5432:5432"
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      PGDATA: /var/lib/postgresql/data/pgdata
    volumes:
      - ../postgres:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 20s

  watchtower:
    container_name: watchtower
    image: containrrr/watchtower:latest
    restart: always
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      TZ: ${TZ}
      WATCHTOWER_SCHEDULE: ${WATCHTOWER_SCHEDULE:-0 0 4 * * *}
      WATCHTOWER_CLEANUP: "true"
      WATCHTOWER_ROLLING_RESTART: "true"
      # WATCHTOWER_NOTIFICATIONS: "off"
      WATCHTOWER_DISABLE_CONTAINERS: "postgres_ha"

volumes:
  mosquitto_data:
  mosquitto_log:
'

# ═══════════════════════════════════════════════════════════════════════════
#  STEP 4 — WRITE SELECTED ADD-ON FILES
# ═══════════════════════════════════════════════════════════════════════════
header "Step 4 of 5 · Writing add-on files"

if [[ ${#SELECTED_ADDONS[@]} -eq 0 ]]; then
    info "No add-ons selected — skipping add-on files."
else
    # ── zigbee2mqtt stub config ────────────────────────────────────────────
    if [[ -v SELECTED_ADDONS[zigbee2mqtt] ]]; then
        write_file "$BASE_DIR/zigbee2mqtt/configuration.yaml" \
'# Zigbee2MQTT — see docs/ADDONS.md for full setup instructions.
# homeassistant: true
# permit_join: true
# mqtt:
#   base_topic: zigbee2mqtt
#   server: mqtt://localhost:1883
# serial:
#   port: /dev/ttyUSB0
# frontend:
#   port: 8080
'
    fi

    # ── Build docker-compose.addons.yml from selected services ────────────
    ADDONS_COMPOSE_CONTENT='# ═══════════════════════════════════════════════════════════════════════════
#  HOME ASSISTANT ADD-ONS STACK (generated by setup.sh)
#
#  Run combined with core:
#    docker compose -f docker/docker-compose.yml \
#                   -f docker/docker-compose.addons.yml up -d
# ═══════════════════════════════════════════════════════════════════════════

services:
'

    if [[ -v SELECTED_ADDONS[nodered] ]]; then
        ADDONS_COMPOSE_CONTENT+='
  # ── Node-RED ───────────────────────────────────────────────────────────
  nodered:
    container_name: nodered
    build:
      context: ..
      dockerfile: docker/Dockerfile.addons
      target: nodered
    image: ha-nodered:local
    restart: always
    network_mode: host
    user: "1000:1000"
    cap_add:
      - NET_ADMIN
      - NET_RAW
    volumes:
      - ../nodered:/data
      - /run/dbus:/run/dbus:ro
    environment:
      TZ: ${TZ}
      NODE_RED_CREDENTIAL_SECRET: ${NODE_RED_CREDENTIAL_SECRET:-change_me_nodered_secret}
'
    fi

    if [[ -v SELECTED_ADDONS[zigbee2mqtt] ]]; then
        ADDONS_COMPOSE_CONTENT+='
  # ── Zigbee2MQTT ────────────────────────────────────────────────────────
  zigbee2mqtt:
    container_name: zigbee2mqtt
    image: ghcr.io/koenkk/zigbee2mqtt:latest
    restart: always
    ports:
      - "${ZIGBEE2MQTT_PORT:-8080}:8080"
    volumes:
      - ../zigbee2mqtt:/app/data
      - /run/udev:/run/udev:ro
    environment:
      TZ: ${TZ}
    # Uncomment and set your Zigbee dongle path:
    # devices:
    #   - /dev/serial/by-id/YOUR_ZIGBEE_DONGLE:/dev/ttyUSB0
'
    fi

    if [[ -v SELECTED_ADDONS[zwavejs] ]]; then
        ADDONS_COMPOSE_CONTENT+='
  # ── Z-Wave JS UI ───────────────────────────────────────────────────────
  zwave_js_ui:
    container_name: zwave_js_ui
    image: zwavejs/zwave-js-ui:latest
    restart: always
    tty: true
    stop_signal: SIGINT
    ports:
      - "${ZWAVEJS_PORT:-8091}:8091"
      - "3000:3000"
    volumes:
      - ../zwave-js-ui:/usr/src/app/store
    environment:
      TZ: ${TZ}
      SESSION_SECRET: ${ZWAVEJS_SESSION_SECRET:-change_me_zwave_secret}
      ZWAVEJS_EXTERNAL_CONFIG: /usr/src/app/store/.config-db
    cap_add:
      - NET_ADMIN
    # Uncomment and set your Z-Wave stick path:
    # devices:
    #   - /dev/serial/by-id/YOUR_ZWAVE_STICK:/dev/ttyUSB1
'
    fi

    if [[ -v SELECTED_ADDONS[esphome] ]]; then
        ADDONS_COMPOSE_CONTENT+='
  # ── ESPHome ────────────────────────────────────────────────────────────
  esphome:
    container_name: esphome
    image: ghcr.io/esphome/esphome:latest
    restart: always
    ports:
      - "${ESPHOME_PORT:-6052}:6052"
    volumes:
      - ../esphome:/config
      - /etc/localtime:/etc/localtime:ro
    environment:
      TZ: ${TZ}
      ESPHOME_DASHBOARD_USE_PING: "true"
'
    fi

    if [[ -v SELECTED_ADDONS[grafana] ]]; then
        ADDONS_COMPOSE_CONTENT+='
  # ── Grafana ────────────────────────────────────────────────────────────
  grafana:
    container_name: grafana
    image: grafana/grafana-oss:latest
    restart: always
    ports:
      - "${GRAFANA_PORT:-3000}:3000"
    volumes:
      - grafana_data:/var/lib/grafana
      - ../grafana/provisioning:/etc/grafana/provisioning
    environment:
      TZ: ${TZ}
      GF_SERVER_ROOT_URL: https://${GRAFANA_DOMAIN:-grafana.yourdomain.com}
      GF_SECURITY_ADMIN_USER: ${GRAFANA_ADMIN_USER:-admin}
      GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_ADMIN_PASSWORD:-change_me_grafana}
      GF_INSTALL_PLUGINS: grafana-clock-panel,grafana-worldmap-panel
      GF_AUTH_GENERIC_OAUTH_ENABLED: "true"
      GF_AUTH_GENERIC_OAUTH_NAME: "Logto"
      GF_AUTH_GENERIC_OAUTH_CLIENT_ID: ${GRAFANA_LOGTO_CLIENT_ID:-your_grafana_client_id}
      GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET: ${GRAFANA_LOGTO_CLIENT_SECRET:-your_grafana_client_secret}
      GF_AUTH_GENERIC_OAUTH_SCOPES: "openid profile email"
      GF_AUTH_GENERIC_OAUTH_AUTH_URL: https://${LOGTO_DOMAIN}/oidc/auth
      GF_AUTH_GENERIC_OAUTH_TOKEN_URL: https://${LOGTO_DOMAIN}/oidc/token
      GF_AUTH_GENERIC_OAUTH_API_URL: https://${LOGTO_DOMAIN}/oidc/me
      GF_USERS_ALLOW_SIGN_UP: "false"
'
    fi

    if [[ -v SELECTED_ADDONS[codeserver] ]]; then
        ADDONS_COMPOSE_CONTENT+='
  # ── code-server ────────────────────────────────────────────────────────
  code_server:
    container_name: code_server
    image: lscr.io/linuxserver/code-server:latest
    restart: always
    ports:
      - "${CODE_SERVER_PORT:-8443}:8443"
    volumes:
      - ../homeassistant:/config/homeassistant
      - ../code-server:/config
    environment:
      TZ: ${TZ}
      PUID: 1000
      PGID: 1000
      PASSWORD: ${CODE_SERVER_PASSWORD:-change_me_code_server_password}
      DEFAULT_WORKSPACE: /config/homeassistant
'
    fi

    # Add volumes block only if grafana was selected
    if [[ -v SELECTED_ADDONS[grafana] ]]; then
        ADDONS_COMPOSE_CONTENT+='
volumes:
  grafana_data:
'
    fi

    write_file "$BASE_DIR/docker/docker-compose.addons.yml" "$ADDONS_COMPOSE_CONTENT"

    # ── Dockerfile.addons — only needed if nodered selected ───────────────
    if [[ -v SELECTED_ADDONS[nodered] ]]; then
        write_file "$BASE_DIR/docker/Dockerfile.addons" \
'# ═══════════════════════════════════════════════════════════════════════════
#  Dockerfile.addons — Multi-stage build for HA community add-ons
# ═══════════════════════════════════════════════════════════════════════════

FROM nodered/node-red:latest AS nodered

USER root

RUN npm install --unsafe-perm --no-update-notifier --no-fund --save \
    node-red-contrib-home-assistant-websocket \
    @flowfuse/node-red-dashboard \
    node-red-contrib-influxdb \
    node-red-node-mqtt \
    node-red-contrib-schedex \
    node-red-contrib-cron-plus \
    node-red-contrib-telegrambot \
    node-red-node-email \
    node-red-contrib-time-range-switch \
    node-red-contrib-counter \
    node-red-contrib-edge-trigger \
    node-red-contrib-jsonpath \
    node-red-contrib-zigbee2mqtt \
    node-red-node-ping

USER node-red

EXPOSE 1880

HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD wget -qO- http://localhost:1880 || exit 1
'
    fi

fi  # end add-ons block

# ── Make scripts executable ───────────────────────────────────────────────
chmod +x "$BASE_DIR/scripts/create-mqtt-user.sh"
chmod +x "$BASE_DIR/scripts/setup.sh" 2>/dev/null || true
success "Scripts marked executable"

# ═══════════════════════════════════════════════════════════════════════════
#  STEP 5 — SUMMARY
# ═══════════════════════════════════════════════════════════════════════════
header "Step 5 of 5 · Done!"

# Print directory tree
echo -e "${BOLD}Directory layout:${RESET}"
if command -v tree &>/dev/null; then
    tree -a --noreport -I ".storage|__pycache__|*.pyc|.git" "$BASE_DIR"
else
    find "$BASE_DIR" ! -path '*/.*' | sort | \
        while IFS= read -r fpath; do
            rel="${fpath#"$BASE_DIR"/}"
            [[ "$rel" == "$fpath" ]] && continue
            depth=$(echo "$rel" | awk -F/ '{print NF-1}')
            indent=$(printf '%*s' $(( depth * 2 )) '')
            name="${fpath##*/}"
            echo "  ${indent}└─ ${name}"
        done
fi

echo ""
echo -e "${BOLD}Next steps:${RESET}"
echo -e "  ${BOLD}1.${RESET} ${CYAN}nano $BASE_DIR/.env${RESET}"
echo -e "     → Set TZ, HOST_IP, HA_DOMAIN, POSTGRES_PASSWORD, LOGTO_* values"
echo ""
echo -e "  ${BOLD}2.${RESET} ${CYAN}nano $BASE_DIR/homeassistant/secrets.yaml${RESET}"
echo -e "     → Set recorder_db_url and homekit_advertise_ip"
echo ""
echo -e "  ${BOLD}3.${RESET} Start the ${BOLD}core stack${RESET}:"
echo -e "     ${YELLOW}cd $BASE_DIR && docker compose -f docker/docker-compose.yml up -d${RESET}"
echo ""

if [[ ${#SELECTED_ADDONS[@]} -gt 0 ]]; then
    echo -e "  ${BOLD}4.${RESET} Start ${BOLD}add-ons${RESET}:"
    if [[ -v SELECTED_ADDONS[nodered] ]]; then
        echo -e "     ${YELLOW}docker compose -f docker/docker-compose.yml -f docker/docker-compose.addons.yml build nodered${RESET}"
    fi
    echo -e "     ${YELLOW}docker compose -f docker/docker-compose.yml -f docker/docker-compose.addons.yml up -d${RESET}"
    echo ""
fi

echo -e "  ${BOLD}Logto OAuth:${RESET}"
echo -e "     • Create a ${BOLD}Traditional Web${RESET} app in your Logto Admin Console"
echo -e "     • Redirect URI: ${CYAN}https://\$HA_DOMAIN/auth/oidc/callback${RESET}"
echo -e "     • Paste Client ID + Secret into .env and secrets.yaml"
echo ""
echo -e "  ${BOLD}MQTT auth (optional):${RESET}"
echo -e "     ${YELLOW}$BASE_DIR/scripts/create-mqtt-user.sh${RESET}"
echo ""
echo -e "${GREEN}${BOLD}  Setup complete! Happy automating 🏠${RESET}"
echo ""