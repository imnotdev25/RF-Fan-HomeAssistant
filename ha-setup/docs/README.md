# Home Assistant Docker Stack

Production-ready Docker Compose setup for Home Assistant with MQTT, PostgreSQL long-term history, Logto OAuth, HomeKit Bridge, Bluetooth/D-Bus, and Watchtower.

---

## Prerequisites

- Docker 24+ and Docker Compose v2
- A Linux host with D-Bus available at `/run/dbus` (for Bluetooth)
- A reverse proxy already handling TLS for your custom domains (Nginx, Caddy, Traefik — not included here)
- Your custom domains pointing at the host: `ha.yourdomain.com`, `auth.yourdomain.com`, `auth-admin.yourdomain.com`

---

## Setup

### 1 · Configure environment & secrets

Copy the example environment file and fill in your values:

```bash
cd homeassistant-docker
cp .env.example .env
nano .env
```

Key values to set in `.env`:

| Variable | Description |
|---|---|
| `TZ` | Your timezone, e.g. `Europe/London` |
| `HOST_IP` | LAN IP of your Docker host |
| `HA_DOMAIN` | Public domain for HA, e.g. `ha.yourdomain.com` |
| `LOGTO_DOMAIN` | Public OIDC endpoint domain |
| `POSTGRES_PASSWORD` | Strong password for the HA database |
| `LOGTO_POSTGRES_PASSWORD` | Strong password for the Logto database |
| `MQTT_USER` / `MQTT_PASSWORD` | Optional — leave empty to skip MQTT auth |

Then edit `config/homeassistant/secrets.yaml` and set the `recorder_db_url` and `homekit_advertise_ip`:

```yaml
recorder_db_url: "postgresql://homeassistant:YOUR_PASSWORD@localhost:5432/homeassistant"
homekit_advertise_ip: "192.168.1.100"   # LAN IP of your Docker host
```

---

### 2 · Start the stack and configure Logto OAuth

**Connect your existing Logto to Home Assistant:**

In your Logto Admin Console, create a new application:

1. Go to **Applications → Create application**, choose **Traditional Web** type.
2. Name it `Home Assistant`.
3. Set the redirect URI to: `https://ha.yourdomain.com/auth/oidc/callback`
4. Copy the **Client ID** and **Client Secret** into your `.env`:
   ```
   LOGTO_CLIENT_ID=xxxxx
   LOGTO_CLIENT_SECRET=xxxxx
   ```
5. Also paste them into `config/homeassistant/secrets.yaml`:
   ```yaml
   logto_client_id: "xxxxx"
   logto_client_secret: "xxxxx"
   ```

**Start the stack:**

```bash
docker compose up -d
docker compose logs -f homeassistant   # watch first-boot
```

**Enable OIDC authentication in Home Assistant:**

Install the [`hass-oidc-auth`](https://github.com/christiaangoossens/hass-oidc-auth) custom component via HACS (HACS → Integrations → search "OIDC"). After installing, uncomment the `oidc` auth provider block in `config/homeassistant/configuration.yaml`:

```yaml
homeassistant:
  auth_providers:
    - type: homeassistant
    - type: oidc
      id: logto
      name: "Sign in with Logto"
      issuer: "https://auth.yourdomain.com/oidc"
      client_id: !secret logto_client_id
      client_secret: !secret logto_client_secret
      scope: "openid profile email"
```

Restart Home Assistant to apply: `docker compose restart homeassistant`

The HA login page will now show a **Sign in with Logto** button. Existing local HA accounts remain fully functional as a fallback.

---

---

## HACS — Home Assistant Community Store

HACS is the community package manager for Home Assistant. It lets you install custom integrations, Lovelace cards, and themes that are not part of the official HA core — including `hass-oidc-auth` for Logto OAuth.

### Prerequisites

- Home Assistant must be running and accessible at `http://localhost:8123`
- Your HA user must have **Administrator** role
- A **GitHub account** (HACS uses the GitHub API to browse repositories)
- Port `443` outbound must be open from the container (for GitHub API calls)

### 1 · Install HACS into the container

Run the official HACS installer script directly inside the running HA container:

```bash
docker exec -it homeassistant bash -c "wget -O - https://get.hacs.xyz | bash -"
```

The script will:
- Download HACS into `/config/custom_components/hacs/`
- Print a confirmation message when done

### 2 · Restart Home Assistant

```bash
docker compose -f docker/docker-compose.yml restart homeassistant
```

Wait ~60 seconds for HA to fully restart.

### 3 · Add the HACS integration

1. Open Home Assistant → **Settings → Devices & Services**
2. Click **+ Add Integration** (bottom-right)
3. Search for **HACS** and select it
4. A GitHub authorisation flow opens — click the link, enter the one-time code shown, and authorise **hacs-bot** on your GitHub account
5. Choose which HACS sections to enable (Integrations, Frontend, etc.) and click **Submit**

HACS will now appear in your sidebar.

### 4 · Install custom components via HACS

For example, to install `hass-oidc-auth` for Logto OAuth:

1. In the HA sidebar click **HACS**
2. Go to **Integrations** → click **Explore & download repositories**
3. Search for `OIDC` → select **OIDC Auth Provider**
4. Click **Download** → confirm the version → click **Download** again
5. Restart Home Assistant:
   ```bash
   docker compose -f docker/docker-compose.yml restart homeassistant
   ```

### 5 · Verify HACS is working

```bash
# Check HACS custom_components folder was created
docker exec homeassistant ls /config/custom_components/

# Watch for HACS-related log lines on startup
docker compose -f docker/docker-compose.yml logs homeassistant | grep -i hacs
```

### Troubleshooting

Enable HACS debug logging by adding this to `homeassistant/configuration.yaml`, restarting, reproducing the issue, then removing it:

```yaml
logger:
  default: warning
  logs:
    custom_components.hacs: debug
    aiogithubapi: debug
```

> **Note:** HACS requires outbound HTTPS to `github.com`, `api.github.com`, and `raw.githubusercontent.com`. If your Docker host sits behind a firewall, ensure those domains are whitelisted on port 443.

---

## HomeKit Bridge

HomeKit discovery works out of the box because HA uses `network_mode: host`. The bridge advertises on port `21063`.

On first use, navigate to **Settings → Devices & Services** in HA and look for the HomeKit card. Scan the QR code with your iPhone or iPad. If no QR code appears, check that `homekit_advertise_ip` in `secrets.yaml` matches your server's LAN IP.

---

## Bluetooth

The `NET_ADMIN` and `NET_RAW` capabilities plus the `/run/dbus:/run/dbus:ro` volume mount give HA full Bluetooth access. After the first boot, go to **Settings → Devices & Services → Add Integration** and search for **Bluetooth** to let HA discover nearby BLE devices.

---

## MQTT — Optional Authentication

By default, Mosquitto accepts anonymous connections. To add credentials:

```bash
./scripts/create-mqtt-user.sh myuser mypassword
```

Then edit `config/mosquitto/mosquitto.conf`, switch `allow_anonymous` to `false` and uncomment `password_file`, then restart:

```bash
docker compose restart mosquitto
```

Update `config/homeassistant/secrets.yaml` with the new credentials and reload the MQTT integration in HA.

---

## PostgreSQL — Long-Term History

The `recorder` in `configuration.yaml` writes all HA state history to PostgreSQL instead of the default SQLite file. This gives you years of history without performance degradation. The database runs on `localhost:5432` (accessible to HA via the host network).

To connect Grafana (from the add-ons stack) to the HA database, add a **PostgreSQL** data source in Grafana pointing at `localhost:5432`, database `homeassistant`.

---

## Watchtower

Watchtower checks for new images daily at 04:00 and performs rolling restarts. PostgreSQL and Logto are excluded from auto-update to prevent unexpected migrations. To trigger a manual update:

```bash
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock containrrr/watchtower --run-once
```

---

## Reverse Proxy

Your TLS-terminating reverse proxy should forward to:

| Service | Upstream |
|---|---|
| `ha.yourdomain.com` | `http://localhost:8123` |
| `auth.yourdomain.com` | `http://localhost:3001` |
| `auth-admin.yourdomain.com` | `http://localhost:3002` |

**Required HA header** (add to your proxy config for the HA vhost):

```
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto https;
```

---

## Useful Commands

```bash
# Start everything
docker compose up -d

# View logs
docker compose logs -f homeassistant
docker compose logs -f logto

# Restart a single service
docker compose restart homeassistant

# Validate HA config before restarting
docker exec homeassistant python -m homeassistant --script check_config --config /config

# Stop and remove containers (data volumes are preserved)
docker compose down
```