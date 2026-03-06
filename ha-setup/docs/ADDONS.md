# Community Add-ons

These services run alongside the core stack and replicate the most popular Home Assistant OS add-ons for a Docker environment. All are in `docker-compose.addons.yml`.

---

## Add-ons Overview

| Add-on | Port | Purpose |
|---|---|---|
| **Node-RED** | `1880` | Visual drag-and-drop automation flows |
| **Zigbee2MQTT** | `8080` | Zigbee dongle → MQTT bridge |
| **Z-Wave JS UI** | `8091` | Z-Wave dongle → HA WebSocket bridge |
| **ESPHome** | `6052` | ESP8266/ESP32 firmware builder & OTA dashboard |
| **Grafana** | `3000` | Long-term sensor dashboards on top of PostgreSQL |
| **code-server** | `8443` | VS Code in the browser for editing HA config |

---

## Start Add-ons

Run both stacks together (recommended):

```bash
docker compose -f docker-compose.yml -f docker-compose.addons.yml up -d
```

Or add-ons only (core must already be running):

```bash
docker compose -f docker-compose.addons.yml up -d
```

Build the custom Node-RED image first if you haven't yet:

```bash
docker compose -f docker-compose.addons.yml build nodered
```

---

## Node-RED

Node-RED connects to Home Assistant via the `node-red-contrib-home-assistant-websocket` node, which is pre-installed in the custom `Dockerfile.addons` image.

**First-time setup:**

1. Open `http://your-host:1880`.
2. Install the HA palette (already in image): go to **Manage palette → Installed** and verify `node-red-contrib-home-assistant-websocket` appears.
3. Drag a **server config** node onto the canvas. Set the HA URL to `http://localhost:8123` (host network) and create a **Long-Lived Access Token** in HA under your profile.

The `NODE_RED_CREDENTIAL_SECRET` in `.env` encrypts stored credentials — change it before first boot and never change it after.

---

## Zigbee2MQTT

Bridges your Zigbee USB dongle to the Mosquitto MQTT broker, which then feeds devices into HA.

**Before starting:**

1. Find your dongle's stable device path:
   ```bash
   ls /dev/serial/by-id/
   ```
2. Uncomment and update the `devices:` block in `docker-compose.addons.yml`:
   ```yaml
   devices:
     - /dev/serial/by-id/usb-ITead_Sonoff_Zigbee_3.0_USB_Dongle_Plus_XXXX-if00-port0:/dev/ttyUSB0
   ```
3. Create the config directory and a minimal `configuration.yaml`:
   ```bash
   mkdir -p config/zigbee2mqtt
   cat > config/zigbee2mqtt/configuration.yaml <<'EOF'
   homeassistant: true
   permit_join: true
   mqtt:
     base_topic: zigbee2mqtt
     server: mqtt://localhost:1883
     # username: !secret mqtt_user       # uncomment if auth is enabled
     # password: !secret mqtt_password
   serial:
     port: /dev/ttyUSB0
   frontend:
     port: 8080
   advanced:
     log_level: info
   EOF
   ```
4. Start the container and open `http://your-host:8080` to add devices.

In HA, the Zigbee devices appear automatically via MQTT Discovery. No manual integration setup is required.

---

## Z-Wave JS UI

Provides a WebSocket server for the HA **Z-Wave JS** integration and a management web UI.

**Before starting:**

1. Find your Z-Wave stick path:
   ```bash
   ls /dev/serial/by-id/
   ```
2. Uncomment the `devices:` block in `docker-compose.addons.yml`:
   ```yaml
   devices:
     - /dev/serial/by-id/usb-Zooz_800_Series_ZST39_XXXX-if00-port0:/dev/ttyUSB1
   ```
3. Start the container: `docker compose -f docker-compose.addons.yml up -d zwave_js_ui`
4. Open `http://your-host:8091` → **Settings → Z-Wave** and set the serial port to `/dev/ttyUSB1`.
5. In HA: **Settings → Devices & Services → Add Integration → Z-Wave JS**, point it at `ws://localhost:3000`.

---

## ESPHome

ESPHome compiles firmware for ESP8266 and ESP32 devices and pushes it over-the-air.

**Usage:**

1. Open `http://your-host:6052`.
2. Click **+ New device**, give it a name, choose your chip type.
3. ESPHome generates a YAML config. Edit it, then click **Install**.

ESPHome devices appear in HA automatically via the ESPHome integration (already included in `default_config`). If HA doesn't auto-discover a device, go to **Settings → Devices & Services → Add Integration → ESPHome** and enter the device IP.

**Tip:** Store your ESPHome YAML configs in `config/esphome/` — they are mounted into the container and survive rebuilds.

---

## Grafana

Grafana visualises the long-term sensor data stored in the HA PostgreSQL database.

**First-time setup:**

1. Open `http://your-host:3000`, log in with the admin credentials from `.env`.
2. Go to **Connections → Data Sources → Add data source → PostgreSQL**.
3. Fill in:
   - **Host:** `localhost:5432`
   - **Database:** `homeassistant`
   - **User / Password:** values from `.env` (`POSTGRES_USER` / `POSTGRES_PASSWORD`)
   - **TLS/SSL Mode:** disable (internal loopback)
4. Click **Save & test**.

Grafana also supports Logto OAuth for single sign-on — set `GF_AUTH_GENERIC_OAUTH_*` values in `.env` after creating a **Grafana** application in the Logto Admin Console (same steps as the HA application, with the Grafana callback URL `https://grafana.yourdomain.com/login/generic_oauth`).

---

## code-server (VS Code)

Provides a browser-based VS Code instance with the HA config directory pre-mounted.

**Access:** `https://your-host:8443` — password set via `CODE_SERVER_PASSWORD` in `.env`.

**Recommended VS Code extensions to install inside code-server:**

- `keesschollaart.vscode-home-assistant` — HA YAML autocompletion & validation
- `redhat.vscode-yaml` — YAML language support
- `esbenp.prettier-vscode` — code formatting

The HA config folder is pre-loaded as the default workspace. Save changes and restart HA with:

```bash
docker compose restart homeassistant
```

---

## Dockerfile.addons — Custom Builds

`Dockerfile.addons` uses multi-stage builds. The `nodered` stage extends the official Node-RED image with community nodes. To add more nodes, edit the `npm install` list and rebuild:

```bash
docker compose -f docker-compose.addons.yml build --no-cache nodered
docker compose -f docker-compose.addons.yml up -d nodered
```

To add a custom ESPHome stage or any other add-on requiring extra packages, add a new `FROM` stage to `Dockerfile.addons`, reference it as a build target in `docker-compose.addons.yml`, and follow the same pattern.