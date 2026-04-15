#include <Servo.h>
#include <WiFiS3.h>
#include <ArduinoBLE.h>

#if defined(__has_include) && __has_include("arduino_secrets.h")
  #include "arduino_secrets.h"
#else
  #define SECRET_SSID "Khaled"
  #define SECRET_PASS "10041972"
#endif

const uint16_t SERVER_PORT = 8888;
WiFiServer server(SERVER_PORT);

BLEService gloveService("180C");
BLEStringCharacteristic gloveCharacteristic("2A56", BLEWrite | BLEWriteWithoutResponse, 120);

const int SERVO_PINS[] = { 3, 5, 6, 9, 10 };
const int NUM_SERVOS = 5;
Servo servos[NUM_SERVOS];

const int GESTURE_TABLE[27][5] = {
  {  0, 90, 90, 90, 90 }, // A
  {  0,  0,  0,  0, 90 }, // B
  { 90, 45, 45, 45, 90 }, // C
  {  0,  0, 90, 90, 90 }, // D
  { 90, 90, 90, 90, 90 }, // E
  {  0,  0,  0, 90, 90 }, // F
  {  0,  0,  0,  0,  0 }, // G
  {  0,  0, 90, 90,  0 }, // H
  { 90, 90, 90, 90,  0 }, // I
  { 90, 90, 90, 45,  0 }, // J
  {  0,  0, 90,  0, 90 }, // K
  { 45, 90, 90, 90, 90 }, // L
  {  0, 45, 45, 90, 90 }, // M
  {  0, 45, 90, 90, 90 }, // N
  { 90, 45, 45, 45, 45 }, // O
  { 45,  0, 90, 90, 90 }, // P
  {  0,  0,  0, 45, 90 }, // Q
  { 45,  0, 90,  0, 90 }, // R
  { 90, 90, 45, 90, 90 }, // S
  { 90, 90, 90, 90, 45 }, // T
  {  0,  0, 90, 45, 90 }, // U
  {  0,  0, 45, 90, 45 }, // V
  { 45, 45,  0, 45, 90 }, // W
  { 90, 45, 45, 90, 45 }, // X
  {  0, 90, 45, 90,  0 }, // Y
  { 45, 45, 90,  0, 90 }  // Z
};

WiFiClient wifiClient;
String lineBuffer;
bool stopRequested = false;

void processLine(const String& line);
void moveToPose(const int angles[5], int stepDelayMs);
void sendWiFiResponse(const char* msg);

void setup() {
  Serial.begin(115200);

  // ✅ FIX: Use attach() with NO microsecond params — use defaults (544–2400µs)
  for (int i = 0; i < NUM_SERVOS; i++) {
    servos[i].attach(SERVO_PINS[i]);
    delay(100);          // small delay so each servo powers up cleanly
    servos[i].write(0);
  }
  delay(1000);           // let all servos reach position before anything else

  // Connect to WiFi
  Serial.print("Attempting to connect to SSID: ");
  WiFi.setHostname("adeva-glove");
  Serial.println(SECRET_SSID);
  
  while (WiFi.begin(SECRET_SSID, SECRET_PASS) != WL_CONNECTED) {
    Serial.print(".");
    delay(1000);
  }
  // Debugging: Wait for a valid IP (The fix for 0.0.0.0)
  while (WiFi.localIP() == IPAddress(0,0,0,0)) {
    Serial.print("?");
    delay(500);
  }

  server.begin();
  
  Serial.println("\nWiFi Connected!");
  Serial.print("IP Address: ");
  Serial.println(WiFi.localIP());
  Serial.print("Connecting to WiFiBLE");

  if (!BLE.begin()) {
    Serial.println("BLE init failed! Continuing without BLE.");
  } else {
    BLE.setLocalName("AdevaGlove");
    BLE.setAdvertisedService(gloveService);
    gloveService.addCharacteristic(gloveCharacteristic);
    BLE.addService(gloveService);
    BLE.advertise();
    Serial.println(" advertising as 'AdevaGlove'");
  }

  lineBuffer.reserve(128);
}

void loop() {
  BLE.poll();
  if (gloveCharacteristic.written()) {
    String bleMsg = gloveCharacteristic.value();
    Serial.print("[BLE] Received: ");
    Serial.println(bleMsg);
    processLine(bleMsg);
  }

  if (!wifiClient || !wifiClient.connected()) {
    wifiClient = server.available();
    if (wifiClient) {
      lineBuffer = "";
      Serial.println("[WiFi] Client connected");
      sendWiFiResponse("ACK connected\n");
    }
  }

  if (wifiClient && wifiClient.connected()) {
    while (wifiClient.available()) {
      char c = wifiClient.read();
      if (c == '\n' || c == '\r') {
        if (lineBuffer.length() > 0) {
          processLine(lineBuffer);
          lineBuffer = "";
        }
      } else {
        if (lineBuffer.length() < 120) lineBuffer += c;
      }
    }
  }

  if (stopRequested) {
    stopRequested = false;
    moveToPose(GESTURE_TABLE[26], 20);
  }
}

void processLine(const String& line) {
  String id;
  float speed = 0.6f;

  int idx = line.indexOf("\"id\"");
  if (idx >= 0) {
    int colon = line.indexOf(':', idx);
    int start = line.indexOf('"', colon + 1);
    int end   = line.indexOf('"', start + 1);
    if (start >= 0 && end > start) id = line.substring(start + 1, end);
  }

  idx = line.indexOf("\"speed\"");
  if (idx >= 0) {
    int colon = line.indexOf(':', idx);
    int end = colon + 1;
    while (end < (int)line.length() &&
           (isDigit(line[end]) || line[end] == '.' || line[end] == '-')) end++;
    speed = line.substring(colon + 1, end).toFloat();
  }

  if (id.length() == 0) {
    sendWiFiResponse("NACK no id\n");
    Serial.println("[CMD] NACK: no id");
    return;
  }

  id.toUpperCase();

  if (id == "STOP") {
    stopRequested = true;
    sendWiFiResponse("ACK STOP\n");
    Serial.println("[CMD] STOP queued");
    return;
  }

  if (id.length() != 1 || id[0] < 'A' || id[0] > 'Z') {
    sendWiFiResponse("NACK unknown id\n");
    Serial.print("[CMD] NACK unknown id: ");
    Serial.println(id);
    return;
  }

  int gestureIndex = id[0] - 'A';
  int angles[5];
  for (int i = 0; i < 5; i++) {
    angles[i] = constrain(GESTURE_TABLE[gestureIndex][i], 0, 180);
  }

  int stepDelay = 20 + (int)((1.0f - speed) * 30);
  moveToPose(angles, stepDelay);

  sendWiFiResponse("ACK\n");
  Serial.print("[CMD] Gesture: ");
  Serial.println(id);
}

void moveToPose(const int angles[5], int stepDelayMs) {
  for (int i = 0; i < NUM_SERVOS; i++) {
    servos[i].write(angles[i]);
  }
  // ✅ Increased delay to give servos enough time to physically reach position
  delay(800);
}

void sendWiFiResponse(const char* msg) {
  if (wifiClient && wifiClient.connected()) {
    wifiClient.print(msg);
  }
  Serial.print("> ");
  Serial.print(msg);
}