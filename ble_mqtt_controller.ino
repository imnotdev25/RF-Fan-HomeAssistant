#include <BLEDevice.h>
#include <BLEScan.h>
#include <BLEAdvertisedDevice.h>
#include <BLEUtils.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>

// WiFi credentials
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";

// MQTT Broker settings
const char* mqtt_server = "broker.hivemq.com"; // Change to your MQTT broker
const int mqtt_port = 1883;
const char* mqtt_topic_command = "ble_controller/command";
const char* mqtt_topic_status = "ble_controller/status";
const char* mqtt_topic_data = "ble_controller/data";

// BLE settings
String TARGET_MAC = "XX:XX:XX:XX:XX:XX"; // Replace with your BLE device MAC
BLEScan* pBLEScan;
BLEClient* pClient;
BLERemoteCharacteristic* pRemoteCharacteristic;
bool deviceFound = false;
bool deviceConnected = false;

// Service and Characteristic UUIDs for Aer Matic Spray
static BLEUUID serviceUUID("6E400000-B5A3-F393-E0A9-E50E24DCCA9E");
static BLEUUID charUUID("6E400003-B5A3-F393-E0A9-E50E24DCCA9E");

// Spray command
const uint8_t SPRAY_COMMAND[16] = {0xbf, 0x62, 0x6D, 0x54, 0x18, 0x68, 0x62, 0x6D, 0x4E, 0x18, 0x9A, 0x62, 0x72, 0x49, 0x00, 0xFF};

// MQTT client
WiFiClient espClient;
PubSubClient client(espClient);

// Function prototypes
void connectToWiFi();
void connectToMQTT();
void callback(char* topic, byte* payload, unsigned int length);
void connectToBLEDevice(String macAddress);
void sendBLECommand(uint8_t* data, size_t length);
void publishStatus(const char* status);

class MyAdvertisedDeviceCallbacks: public BLEAdvertisedDeviceCallbacks {
    void onResult(BLEAdvertisedDevice advertisedDevice) {
      if (advertisedDevice.getAddress().toString() == TARGET_MAC) {
        deviceFound = true;
        Serial.print("Found target device: ");
        Serial.println(advertisedDevice.toString().c_str());
        pBLEScan->stop();
      }
    }
};

class MyClientCallback : public BLEClientCallbacks {
  void onConnect(BLEClient* pclient) {
    deviceConnected = true;
    Serial.println("Connected to BLE device");
    publishStatus("connected");
  }

  void onDisconnect(BLEClient* pclient) {
    deviceConnected = false;
    deviceFound = false;
    Serial.println("Disconnected from BLE device");
    publishStatus("disconnected");
  }
};

void setup() {
  Serial.begin(115200);
  
  // Initialize WiFi
  connectToWiFi();
  
  // Initialize MQTT
  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(callback);
  
  // Initialize BLE
  BLEDevice::init("");
  pBLEScan = BLEDevice::getScan();
  pBLEScan->setAdvertisedDeviceCallbacks(new MyAdvertisedDeviceCallbacks());
  pBLEScan->setActiveScan(true);
  pBLEScan->setInterval(100);
  pBLEScan->setWindow(99);
  
  Serial.println("BLE MQTT Controller started");
}

void loop() {
  if (!client.connected()) {
    connectToMQTT();
  }
  client.loop();
  
  if (!deviceConnected && !deviceFound) {
    Serial.println("Scanning for BLE devices...");
    BLEScanResults foundDevices = pBLEScan->start(5, false);
    pBLEScan->clearResults();
  } 
  else if (deviceFound && !deviceConnected) {
    connectToBLEDevice(TARGET_MAC);
  }
  
  delay(1000);
}

void connectToWiFi() {
  Serial.println("Connecting to WiFi...");
  WiFi.begin(ssid, password);
  
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  
  Serial.println("");
  Serial.println("WiFi connected");
  Serial.println("IP address: ");
  Serial.println(WiFi.localIP());
}

void connectToMQTT() {
  while (!client.connected()) {
    Serial.print("Attempting MQTT connection...");
    String clientId = "ESP32Client-" + String(random(0xffff), HEX);
    
    if (client.connect(clientId.c_str())) {
      Serial.println("connected");
      client.subscribe(mqtt_topic_command);
      publishStatus("online");
    } else {
      Serial.print("failed, rc=");
      Serial.print(client.state());
      Serial.println(" try again in 5 seconds");
      delay(5000);
    }
  }
}

void callback(char* topic, byte* payload, unsigned int length) {
  Serial.print("Message arrived [");
  Serial.print(topic);
  Serial.print("] ");
  
  String message = "";
  for (int i = 0; i < length; i++) {
    message += (char)payload[i];
  }
  Serial.println(message);

  // Process MQTT command
  if (strcmp(topic, mqtt_topic_command) == 0) {
    if (message == "spray") {
      if (deviceConnected) {
        Serial.println("Triggering spray action");
        sendBLECommand(SPRAY_COMMAND, sizeof(SPRAY_COMMAND));
        client.publish(mqtt_topic_data, "Spray triggered");
      } else {
        Serial.println("Cannot trigger spray - BLE device not connected");
        client.publish(mqtt_topic_status, "error:not_connected");
      }
    } else if (message == "status") {
      // Send current status
      publishStatus(deviceConnected ? "connected" : "disconnected");
    }
  }
}

void connectToBLEDevice(String macAddress) {
  Serial.print("Connecting to BLE device ");
  Serial.println(macAddress);
  
  pClient = BLEDevice::createClient();
  pClient->setClientCallbacks(new MyClientCallback());
  
  // Connect to the remote BLE Server
  BLEAddress address(macAddress.c_str());
  
  if (pClient->connect(address)) {
    Serial.println(" - Connected to server");
    
    // Obtain a reference to the service we are after in the remote BLE server
    BLERemoteService* pRemoteService = pClient->getService(serviceUUID);
    if (pRemoteService == nullptr) {
      Serial.print("Failed to find our service UUID: ");
      Serial.println(serviceUUID.toString().c_str());
      pClient->disconnect();
      return;
    }
    
    // Obtain a reference to the characteristic in the service of the remote BLE server
    pRemoteCharacteristic = pRemoteService->getCharacteristic(charUUID);
    if (pRemoteCharacteristic == nullptr) {
      Serial.print("Failed to find our characteristic UUID: ");
      Serial.println(charUUID.toString().c_str());
      pClient->disconnect();
      return;
    }
    
    // Read the value of the characteristic
    if(pRemoteCharacteristic->canRead()) {
      std::string value = pRemoteCharacteristic->readValue();
      Serial.print("The characteristic value was: ");
      Serial.println(value.c_str());
    }
    
    deviceConnected = true;
    publishStatus("connected");
  } else {
    Serial.println("Failed to connect to the BLE device");
  }
}

void sendBLECommand(uint8_t* data, size_t length) {
  if (deviceConnected && pRemoteCharacteristic != nullptr) {
    pRemoteCharacteristic->writeValue(data, length, false);
    
    // Publish confirmation
    char hexStr[length * 2 + 1];
    for (size_t i = 0; i < length; i++) {
      sprintf(hexStr + (i * 2), "%02x", data[i]);
    }
    hexStr[length * 2] = '\0';
    
    client.publish(mqtt_topic_data, hexStr);
    Serial.print("Sent BLE command: ");
    Serial.println(hexStr);
  }
}

void publishStatus(const char* status) {
  if (client.connected()) {
    client.publish(mqtt_topic_status, status);
  }
}
