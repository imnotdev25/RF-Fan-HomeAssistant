# Home Assistant Docker Stack

Production-ready Docker Compose setup for Home Assistant with MQTT, PostgreSQL long-term history, Logto OAuth, HomeKit Bridge, Bluetooth/D-Bus, and Watchtower.

---

## Prerequisites

- Docker 24+ and Docker Compose v2
- A Linux host with D-Bus available at `/run/dbus` (for Bluetooth)

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