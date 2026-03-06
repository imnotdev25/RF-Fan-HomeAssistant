#include <RCSwitch.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <map>
#include <vector>
#include <random>

// WiFi and MQTT Configuration
const char* ssid = ""; # WIFI SSID
const char* password = ""; # WIFI PASSWORD
const char* mqtt_server = ""; # MQTT SERVER HOST
const int mqtt_port = 1883;
// const char* mqtt_user = "your_username";
// const char* mqtt_password = "your_password";

// MQTT Topics
const char* livingRoomTopic = "living-room-fan";
const char* bedroomTopic = "bedroom-fan";

// RF Configuration
const int RF_TRANSMIT_PIN = 4; # Use Receiver to get codes from remote. [RF-SWITCH LIB]
const int RF_PROTOCOL = 1;
const int RF_BITS = 32;
const int RF_PULSE_LENGTH = 254;

// Living Room Fan RF Codes - Multiple codes per function
std::map<String, std::vector<unsigned long>> livingRoomCodes = {
  {"power", {2387948334, 2387948351, 2387948360, 2387948377, 2387948394, 2387948411, 2387948300}},
  {"speed1", {2387949847, 2387949860, 2387949877, 2387949890, 2387949907, 2387949920}},
  {"speed2", {2387951139, 2387951173, 2387951188, 2387951207, 2387951105, 2387951120}},
  {"speed3", {2387948810, 2387948827, 2387948840, 2387948878, 2387948895, 2387948925}},
  {"speed4", {2387949508, 2387949542, 2387949559, 2387949457, 2387949474}},
  {"speed5", {2387949065, 2387949099, 2387949114, 2387949148, 2387949167}},
  {"speed6", {2387949650, 2387949665, 2387949575}},
  {"speed7", {2387950417, 2387950434, 2387950451, 2387950357, 2387950391, 2387950400}},
  {"light", {2387950948, 2387950965, 2387950850, 2387950880, 2387950897, 2387950918}},
  {"timer-off", {2387948758, 2387948773, 2387948675, 2387948690, 2387948705, 2387948720}},
  {"timer-2h", {2387947867, 2387947880, 2387947897, 2387947790, 2387947807, 2387947820}},
  {"timer-4h", {2387950776, 2387950814, 2387950829, 2387950844, 2387950731, 2387950761}},
  {"timer-8h", {2387949771, 2387949786, 2387949801, 2387949711, 2387949726, 2387949741}},
  {"reverse", {2387948668, 2387948555, 2387948570, 2387948585, 2387948600, 2387948623}},
  {"smart", {2387950221, 2387950236, 2387950255, 2387950281, 2387950296, 2387950315}},
  {"natural", {2387948105, 2387948120, 2387948154, 2387948045, 2387948060, 2387948094}}
};

// Bedroom Fan RF Codes - Multiple codes per function
std::map<String, std::vector<unsigned long>> bedroomCodes = {
  {"power", {3365872442, 3365872461, 3365872495, 3365872393}},
  {"speed1", {3365874021, 3365874036, 3365873953, 3365873991}},
  {"speed2", {3365875298, 3365875315, 3365875204, 3365875221, 3365875255}},
  {"speed3", {3365872971, 3365873001, 3365872911, 3365872941}},
  {"speed4", {3365873650, 3365873541, 3365873635}},
  {"speed5", {3365873215, 3365873224, 3365873241}},
  {"speed6", {3365873713, 3365873751, 3365873764, 3365873781, 3365873666, 3365873683, 3365873666}},
  {"speed7", {3365874433, 3365874482, 3365874467, 3365874448, 3365874535, 3365874550}},
  {"light", {3365874966, 3365874981, 3365874996, 3365875011, 3365875026, 3365875041}},
  {"timer-off", {3365872791, 3365872804, 3365872834, 3365872864, 3365872774, 3365872791}},
  {"timer-2h", {3365871913, 3365871928, 3365871951, 3365871966}},
  {"timer-4h", {3365874877, 3365874890, 3365874907, 3365874920, 3365874937}},
  {"reverse", {3365872701, 3365872714, 3365872731, 3365872761, 3365872654, 3365872408}},
  {"smart", {3365874312, 3365874329, 3365874346}},
  {"natural", {3365872255, 3365872221, 3365872136}}
};

WiFiClient espClient;
PubSubClient client(espClient);
RCSwitch mySwitch = RCSwitch();

// Random number generator
std::random_device rd;
std::mt19937 gen(rd());

void setup() {
  // Disable onboard LEDs
  
  digitalWrite(2, LOW);  // Turn off built-in LED (if active low)
 

  Serial.begin(115200);
  Serial.println("🚀 Dual RF Fan Controller Starting...");

  setupRcSwitch(RF_TRANSMIT_PIN, RF_PROTOCOL, RF_PULSE_LENGTH);
  setupWifi(ssid, password);

  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(callback);

  // Disable WiFi LED after WiFi is initialized
  WiFi.setSleep(WIFI_PS_MAX_MODEM);
  
  Serial.println("✅ Setup complete! Use template method in Home Assistant.");
}

void sendRadioCommand(const String& topic, const String& message) {
  std::vector<unsigned long> codes;
  bool isLivingRoom = (topic == livingRoomTopic);
  auto& codeMap = isLivingRoom ? livingRoomCodes : bedroomCodes;
  
  auto it = codeMap.find(message);
  if (it != codeMap.end()) {
    codes = it->second;
    Serial.print(isLivingRoom ? "Living Room: " : "Bedroom: ");
    Serial.print(message);
    Serial.print(" - Available codes: ");
    
    for (size_t i = 0; i < codes.size(); i++) {
      if (i > 0) Serial.print(" ");
      Serial.print(codes[i]);
    }
    Serial.println();

    // Randomly select one code from the available options
    std::uniform_int_distribution<> dis(0, codes.size() - 1);
    unsigned long code = codes[dis(gen)];
    
    Serial.print("Selected code: ");
    Serial.print(code);
    Serial.print(" (random choice from ");
    Serial.print(codes.size());
    Serial.println(" options)");
    
    mySwitch.send(code, RF_BITS);
    Serial.println("RF sent successfully");
  } else {
    Serial.print("Unknown command: ");
    Serial.println(message);
  }
}

void setupRcSwitch(int pin, int protocol, int pulseLength) {
  mySwitch.enableTransmit(pin);
  mySwitch.setProtocol(protocol);
  mySwitch.setPulseLength(pulseLength);
  Serial.println("RF Transmitter initialized on GPIO" + String(pin) + " with pulse length " + String(pulseLength));
}

void setupWifi(const char* ssid, const char* password) {
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("");
  Serial.println("Connected to " + String(ssid));
  Serial.println("IP address: " + WiFi.localIP().toString());
  Serial.println("MQTT server: " + String(mqtt_server));
}

void reconnect() {
  while (!client.connected()) {
    Serial.print("Attempting MQTT connection...");
    String clientId = "dual-rf-fans-" + String(random(0xffff), HEX);
    
    if (client.connect(clientId.c_str())) {   //  Add User name and password here Ex. client.connect(clientId, user, password)
      Serial.println("connected");
      client.subscribe(livingRoomTopic);
      client.subscribe(bedroomTopic);
      Serial.println("Subscribed to command topics");
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

  sendRadioCommand(String(topic), message);
}

void loop() {
  if (!client.connected()) {
    reconnect();
  }
  client.loop();
  delay(2); // allow the CPU to switch to other tasks
} 