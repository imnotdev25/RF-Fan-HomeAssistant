#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────
#  create-mqtt-user.sh
#  Creates an optional Mosquitto username/password pair.
#
#  Usage:
#    ./scripts/create-mqtt-user.sh [username] [password]
#    ./scripts/create-mqtt-user.sh                   # prompts interactively
#
#  After running this script:
#    1. Edit config/mosquitto/mosquitto.conf
#    2. Comment out:  allow_anonymous true
#    3. Uncomment:    allow_anonymous false
#    4. Uncomment:    password_file /mosquitto/config/passwd
#    5. Restart:      docker compose restart mosquitto
# ─────────────────────────────────────────────────────────────────────────
set -euo pipefail

PASSWD_FILE="$(dirname "$0")/../config/mosquitto/passwd"
MOSQUITTO_CONTAINER="mosquitto"

# ── Get username ──────────────────────────────────────────────────────────
if [[ -n "${1:-}" ]]; then
    MQTT_USER="$1"
else
    read -rp "Enter MQTT username: " MQTT_USER
fi

if [[ -z "$MQTT_USER" ]]; then
    echo "Error: username cannot be empty." >&2
    exit 1
fi

# ── Get password ──────────────────────────────────────────────────────────
if [[ -n "${2:-}" ]]; then
    MQTT_PASS="$2"
else
    read -rsp "Enter MQTT password: " MQTT_PASS
    echo
    read -rsp "Confirm MQTT password: " MQTT_PASS_CONFIRM
    echo
    if [[ "$MQTT_PASS" != "$MQTT_PASS_CONFIRM" ]]; then
        echo "Error: passwords do not match." >&2
        exit 1
    fi
fi

if [[ -z "$MQTT_PASS" ]]; then
    echo "Error: password cannot be empty." >&2
    exit 1
fi

# ── Create or update passwd file ──────────────────────────────────────────
# Use mosquitto_passwd inside the running container (ensures correct binary)
if docker ps --format '{{.Names}}' | grep -q "^${MOSQUITTO_CONTAINER}$"; then
    echo "→ Using running container to hash password..."
    docker exec -i "$MOSQUITTO_CONTAINER" \
        sh -c "mosquitto_passwd -b /mosquitto/config/passwd '$MQTT_USER' '$MQTT_PASS'"
    echo "✓ User '$MQTT_USER' added/updated in container's passwd file."
else
    echo "→ Container not running; creating passwd file locally..."
    # Use mosquitto_passwd locally if available, otherwise warn
    if command -v mosquitto_passwd &>/dev/null; then
        mosquitto_passwd -b "$PASSWD_FILE" "$MQTT_USER" "$MQTT_PASS"
        echo "✓ User '$MQTT_USER' written to $PASSWD_FILE"
    else
        echo ""
        echo "⚠  mosquitto_passwd not found locally."
        echo "   Start the stack first with:  docker compose up -d mosquitto"
        echo "   Then re-run this script."
        exit 1
    fi
fi

echo ""
echo "Next steps:"
echo "  1. Edit config/mosquitto/mosquitto.conf"
echo "  2. Set:  allow_anonymous false"
echo "  3. Set:  password_file /mosquitto/config/passwd"
echo "  4. Run:  docker compose restart mosquitto"