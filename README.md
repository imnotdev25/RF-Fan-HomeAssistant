# RF-Fan-HomeAssistant

Home automation project for controlling RF ceiling fans and Godrej Aer Smart Matic air fresheners via Home Assistant using MQTT and RF/BLE bridges.

---

## 📦 Project Structure

```
RF-Fan-HomeAssistant/
├── ha-setup/                    # Home Assistant Docker stack
├── rf-fans/                     # RF fan controller (ESP32/Arduino)
└── airfreshner/                 # BLE air freshener controller (ESPHome)
```

---

## 🏠 Components

### 1. Home Assistant Setup (`ha-setup/`)

Production-ready Docker Compose setup with:

- **Home Assistant Core** with HomeKit Bridge & Bluetooth support
- **Mosquitto MQTT Broker** for device communication
- **PostgreSQL** for long-term history storage
- **Watchtower** for automatic updates
- **Add-ons**: Node-RED, Zigbee2MQTT, Z-Wave JS UI, ESPHome, Grafana, code-server

📖 [Full setup documentation](ha-setup/docs/README.md)
📖 [Add-ons guide](ha-setup/docs/ADDONS.md)

**Quick start:**
```bash
cd ha-setup
cp .env.example .env
nano .env  # Configure your settings
docker compose up -d
```

### 2. RF Fan Controllers (`rf-fans/`)

ESP32-based RF transmitter for controlling ceiling fans via MQTT.

**Features:**
- Controls 2 fans (Living Room & Bedroom) independently
- 7-speed control + power, light, reverse, timer modes
- Smart & Natural wind modes
- Multiple RF codes per function for reliability

**Files:**
- `RF_multicodecs.ino` - Main RF transmitter firmware (ESP32 + 433MHz transmitter)
- `ble_mqtt_controller.ino` - Alternative BLE-MQTT bridge firmware
- `rf-fans.yaml` - Home Assistant template buttons configuration

**Hardware:**
- ESP32 development board
- 433MHz RF transmitter module (connected to GPIO 4)

**Setup:**
1. Flash `RF_multicodecs.ino` to ESP32 using Arduino IDE
2. Update WiFi & MQTT credentials in the sketch
3. Add `rf-fans.yaml` templates to Home Assistant configuration
4. Restart Home Assistant

### 3. Air Freshener Controller (`airfreshner/`)

ESPHome configuration for Godrej Aer Smart Matic BLE air freshener control.

**Features:**
- Trigger spray via Home Assistant
- BLE connection to air freshener
- Fully integrated with ESPHome

**Files:**
- `airfresher.yaml` - ESPHome configuration

**Setup:**
1. Replace `<SSID>`, `<PASSWORD>`, and `<MAC-ADDRESS>` in `airfresher.yaml`
2. Flash to ESP32-C6 via ESPHome dashboard
3. Device auto-discovered in Home Assistant

---

## 🔧 Requirements

### Hardware
- ESP32 development board (for RF fans)
- ESP32-C6 with BLE (for air freshener)
- 433MHz RF transmitter module
- Docker host (for Home Assistant)
- Linux host with D-Bus (for Bluetooth support)

### Software
- Docker 24+ and Docker Compose v2
- Arduino IDE or PlatformIO (for RF controller)
- ESPHome (included in add-ons stack)

---

## 🚀 Getting Started

1. **Deploy Home Assistant:**
   ```bash
   cd ha-setup
   cp .env.example .env
   # Edit .env with your settings
   docker compose up -d
   ```

2. **Flash RF Controller:**
   - Open `rf-fans/RF_multicodecs.ino` in Arduino IDE
   - Update WiFi & MQTT credentials
   - Flash to ESP32

3. **Configure Air Freshener (optional):**
   - Update `airfreshner/airfresher.yaml` with device MAC
   - Flash via ESPHome dashboard

4. **Add to Home Assistant:**
   - Copy YAML templates from `rf-fans/rf-fans.yaml` and `airfreshner/airfresher.yaml` to your HA config
   - Restart Home Assistant

---

## 📝 MQTT Topics

### RF Fans
- `living-room-fan` - Living room fan commands
- `bedroom-fan` - Bedroom fan commands

**Payloads:** `power`, `light`, `speed1`-`speed7`, `reverse`, `smart`, `natural`, `timer-off`, `timer-2h`, `timer-4h`, `timer-8h`

---

## 🛠️ Customization

### Adding New RF Codes
1. Use an RF receiver to capture codes from your remote
2. Add codes to the appropriate map in `RF_multicodecs.ino`
3. Reflash the ESP32

### Adding New Fans
1. Duplicate fan sections in `RF_multicodecs.ino`
2. Add new MQTT topic
3. Create corresponding buttons in Home Assistant YAML

---

## 📚 Documentation

- [Home Assistant Setup Guide](ha-setup/docs/README.md)
- [Add-ons Installation](ha-setup/docs/ADDONS.md)

---

## 🙏 Acknowledgments

- Home Assistant community
- ESPHome project
- RC-Switch library for RF communication

---

## 📄 License

This project is provided as-is for personal use and experimentation.
