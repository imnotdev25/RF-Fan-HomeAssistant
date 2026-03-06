# ═══════════════════════════════════════════════════════════════════════════
#  Dockerfile.addons
#  Multi-stage build for Home Assistant community add-ons.
#
#  Stages:
#    nodered  — Node-RED with popular community nodes pre-installed
#
#  Build:
#    docker build --target nodered -t ha-nodered:local .
#
#  Or let docker compose build it:
#    docker compose -f docker-compose.addons.yml build
# ═══════════════════════════════════════════════════════════════════════════

# ── Node-RED with community nodes ─────────────────────────────────────────
FROM nodered/node-red:latest AS nodered

# Switch to root to install packages
USER root

# Install community nodes recommended for Home Assistant
RUN npm install --unsafe-perm --no-update-notifier --no-fund --save \
    # Home Assistant WebSocket integration
    node-red-contrib-home-assistant-websocket \
    # Dashboard UI
    @flowfuse/node-red-dashboard \
    # InfluxDB nodes (for sending data to InfluxDB / PostgreSQL via InfluxDB bridge)
    node-red-contrib-influxdb \
    # MQTT nodes (built-in but ensure latest)
    node-red-node-mqtt \
    # Scheduling
    node-red-contrib-schedex \
    node-red-contrib-cron-plus \
    # Telegram bot notifications
    node-red-contrib-telegrambot \
    # HTTP request utilities
    node-red-node-email \
    # Time-range switch
    node-red-contrib-time-range-switch \
    # Counter & edge-trigger helpers
    node-red-contrib-counter \
    node-red-contrib-edge-trigger \
    # JSON path queries
    node-red-contrib-jsonpath \
    # Zigbee2MQTT integration
    node-red-contrib-zigbee2mqtt \
    # Ping / online check
    node-red-node-ping

# Drop back to non-root node-red user
USER node-red

# Expose Node-RED port
EXPOSE 1880

# Health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD wget -qO- http://localhost:1880 || exit 1

# ── ESPHome (optional custom stage) ───────────────────────────────────────
# Uncomment this stage if you need to extend ESPHome with custom components.
# FROM ghcr.io/esphome/esphome:latest AS esphome
#
# USER root
# RUN pip install --no-cache-dir \
#     esphome-xiaomi-ble \
#     some-custom-component
# USER esphome