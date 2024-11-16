#include <DHT.h>
#include <ESP8266WiFi.h>
#include <ThingSpeak.h>

// WiFi Details
const char* ssid = "Project";
const char* password = "123456789";

// ThingSpeak Details
unsigned long channelID = 2737482;
const char* apiKey = "8LE7OV8JRTAYB6WM";

// Pin Definitions
#define RAIN_SENSOR_PIN A0    // MH-RD rain sensor analog pin
#define SOIL_MOISTURE_PIN D1  // Soil moisture sensor analog pin
#define DHT_PIN D2           // DHT11 data pin
#define RELAY_PIN D3         // Relay control pin
#define DHT_TYPE DHT11

// Thresholds (you might need to adjust these based on your sensor readings)
const int RAIN_THRESHOLD = 800;    // Above this means dry, below means rain
const int SOIL_MOISTURE_THRESHOLD = 800;  // ABOVE this means dry soil

// Initialize instances
DHT dht(DHT_PIN, DHT_TYPE);
WiFiClient client;

// Variables for last upload time
unsigned long lastUploadTime = 0;
const unsigned long uploadInterval = 15000; // Upload every 15 seconds

void setup() {
  Serial.begin(115200);
  
  // Initialize pins
  pinMode(RAIN_SENSOR_PIN, INPUT);
  pinMode(SOIL_MOISTURE_PIN, INPUT);
  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, LOW);  // Start with pump off
  
  dht.begin();
  
  // Connect to WiFi
  WiFi.begin(ssid, password);
  Serial.print("\nConnecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi Connected!");
  Serial.println("IP: " + WiFi.localIP().toString());
  
  // Initialize ThingSpeak
  ThingSpeak.begin(client);
  Serial.println("System Ready!");
}

void loop() {
  // Read all sensors
  int rainValue = analogRead(RAIN_SENSOR_PIN);
  int soilMoisture = analogRead(SOIL_MOISTURE_PIN);
  float humidity = dht.readHumidity();
  float temperature = dht.readTemperature();
  
  // Check conditions
  bool isRaining = (rainValue < RAIN_THRESHOLD);
  bool soilDry = (soilMoisture > SOIL_MOISTURE_THRESHOLD);
  
  // Control pump
  bool pumpStatus = false;
  if (soilDry && !isRaining) {
    digitalWrite(RELAY_PIN, HIGH);
    pumpStatus = true;
    Serial.println("PUMP ON - Dry soil & no rain");
  } else {
    digitalWrite(RELAY_PIN, LOW);
    pumpStatus = false;
    Serial.println("PUMP OFF");
  }
  
  // Print all readings to Serial
  Serial.println("\n=== Current Readings ===");
  Serial.println("Rain Sensor: " + String(rainValue) + (isRaining ? " (RAINING)" : " (DRY)"));
  Serial.println("Soil Moisture: " + String(soilMoisture) + (soilDry ? " (DRY)" : " (WET)"));
  Serial.println("Temperature: " + String(temperature) + "°C");
  Serial.println("Humidity: " + String(humidity) + "%");
  Serial.println("Pump: " + String(pumpStatus ? "ON" : "OFF"));
  
  // Upload to ThingSpeak every 15 seconds
  if (millis() - lastUploadTime > uploadInterval) {
    // Set all field values
    ThingSpeak.setField(1, temperature);
    ThingSpeak.setField(2, humidity);
    ThingSpeak.setField(3, rainValue);
    ThingSpeak.setField(4, soilMoisture);
    ThingSpeak.setField(5, pumpStatus ? 1 : 0);
    
    // Try to upload
    int response = ThingSpeak.writeFields(channelID, apiKey);
    
    if (response == 200) {
      Serial.println("✓ ThingSpeak Update OK");
    } else {
      Serial.println("✗ ThingSpeak Error: " + String(response));
    }
    
    lastUploadTime = millis();
  }
  
  delay(2000); // Wait 2 seconds before next reading
}