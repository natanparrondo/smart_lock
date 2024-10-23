#include <ESP32Servo.h>
#include <SPI.h>
#include <MFRC522.h>
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <WiFi.h> // Include the WiFi library for ESP32
#include <SinricPro.h> // Include the SinricPro library
#include <SinricProLock.h> // Include the SinricPro library
#include <EEPROM.h>

#define SS_PIN 21
#define RST_PIN 15
#define MOSI_PIN 18    
#define MISO_PIN 5  
#define SCK_PIN 19

#define GREEN_LED_PIN 25
#define RED_LED_PIN 33
#define YELLOW_LED_PIN 26
#define PIN_SG90 13
#define BUTTON_PIN 32
#define LOCK_ID "66ace703674e208e6f045258"  // Define your LOCK_ID here

MFRC522 mfrc522(SS_PIN, RST_PIN);
Servo myServo;

#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define APP_KEY           "e9e0335b-c8f0-4221-92d3-4f2489f9dfe8"
#define APP_SECRET        "67688a2d-8085-48b1-82d2-e626042298eb-38f4da05-2462-494f-83fe-6e85ba08b370"
#define CHARACTERISTIC_UUID_SEND "4694c381-4c73-473f-b9f6-fac2384527b7"  // Nuevo UUID para enviar estado

// Declarar el objeto de la característica de envío
BLECharacteristic *pSendCharacteristic;

bool lastLockState = true; // Declare and initialize lastLockState
bool currentLockState = true; // Declare currentLockState
bool wifiUnavailable = false;
bool redLEDprevioudState = false;


bool addCardOnButtonPress = false;
String allowedCards[10];
int allowedCardCount = 0;

bool isManualChange = false;
int advertise_interval = 0;

void blinkLED(int pin){
  digitalWrite(pin, LOW);
  delay(300);
  digitalWrite(pin, HIGH);
  delay(300);
  digitalWrite(pin, LOW);
}

void lock(){
  if (isManualChange){
    currentLockState = !currentLockState; 
    SinricProLock &myLock = SinricPro[LOCK_ID];
    myLock.sendLockStateEvent(currentLockState); //manda el update de estado al server si se desbloquea offline
    isManualChange = false; 
  }
  digitalWrite(GREEN_LED_PIN, HIGH);
  Serial.println("Lock command received. Operating servo...");
  for (int pos = 180; pos >= 0; pos--) {
    myServo.write(pos);  
    delay(10);
  }
  digitalWrite(GREEN_LED_PIN, LOW);
  digitalWrite(RED_LED_PIN, HIGH);  

  currentLockState = true;
  writeStringToEEPROM(110,"1");  // Guardar estado cerrado en EEPROM
  EEPROM.commit();
  if (pSendCharacteristic != nullptr) {
    pSendCharacteristic->setValue("On");
    pSendCharacteristic->notify();
  }
}

void unlock(){
  if (isManualChange){
    currentLockState = !currentLockState;
    SinricProLock &myLock = SinricPro[LOCK_ID];
    myLock.sendLockStateEvent(currentLockState);
    isManualChange = false;
    
  }
  digitalWrite(GREEN_LED_PIN, HIGH);
  Serial.println("Unlock command received. Operating servo...");
  for (int pos = 0; pos <= 180; pos++) {  
    myServo.write(pos);  
    delay(10);
  }
  digitalWrite(GREEN_LED_PIN, LOW);
  digitalWrite(RED_LED_PIN, LOW); 

  Serial.println("Puerta estaba cerrada, abierta ahora...");
  writeStringToEEPROM(110,"0"); 
  if (pSendCharacteristic != nullptr) {
    pSendCharacteristic->setValue("Off");
    pSendCharacteristic->notify();
  }
}

// EEPROM
void writeStringToEEPROM(int address, const String &data) {
  int len = data.length();
  for (int i = 0; i < len; i++) {
    EEPROM.write(address + i, data[i]);
  }
  EEPROM.write(address + len, '\0'); // Add a null terminator
  EEPROM.commit();
}

String readStringFromEEPROM(int address) {
  char data[100]; // Adjust size according to your needs
  int len = 0;
  unsigned char k;
  k = EEPROM.read(address);
  while (k != '\0' && len < sizeof(data) - 1) {
    data[len++] = k;
    k = EEPROM.read(address + len);
  }
  data[len] = '\0'; // Null terminator
  return String(data);
}

// SinricPro
void setupWiFi() {
  int pointCount = 0;
  Serial.print("\n[Wifi]: Connecting");
  WiFi.begin(wifi_ssid.c_str(), wifi_password.c_str());

  while (WiFi.status() != WL_CONNECTED) {
    Serial.print(".");
    digitalWrite(RED_LED_PIN, HIGH);
    delay(250);
    pointCount++;
    if (pointCount >= 30){
      break;
    }
  }
  Serial.print("\n[WiFi]: IP-Address is ");
  Serial.println(WiFi.localIP());
  if (WiFi.localIP() == "0.0.0.0" || WiFi.isConnected() != true){
    wifiUnavailable = true;
  } else {
    wifiUnavailable = false;
  }
}

void setupSinricPro() {
  SinricProLock &myLock = SinricPro[LOCK_ID];
  myLock.onLockState(onLockState);

  SinricPro.onConnected([]() {
    Serial.println("Connected to SinricPro");
  });
  
  SinricPro.onDisconnected([]() {
    Serial.println("Disconnected from SinricPro");
  });
  
  SinricPro.begin(APP_KEY, APP_SECRET);
}

bool onLockState(String deviceId, bool &lockState) {
  Serial.printf("Device %s is %s\r\n", deviceId.c_str(), lockState ? "locked" : "unlocked");
  if (lockState) {
    lock();
  } else {
    unlock();
  }
  digitalWrite(RED_LED_PIN, lockState);  
  return true;
}

void addCardToAllowedList(String uuid) {
  allowedCards[allowedCardCount] = uuid;
  allowedCardCount++;
  saveCardToEEPROM(allowedCardCount - 1, uuid); // Guardar la tarjeta en EEPROM
  updateAllowedCardCount(); // Actualizar el contador de tarjetas
  Serial.print("UUID added to allowed list: ");
  Serial.println(uuid);
  blinkLED(GREEN_LED_PIN);
  digitalWrite(RED_LED_PIN, redLEDprevioudState);
  digitalWrite(GREEN_LED_PIN, LOW);
  delay(2000);
}

void updateAllowedCardCount() {
  EEPROM.write(119, allowedCardCount); // Guardar el número de tarjetas en la dirección 119
  EEPROM.commit();
}

// Guardado y Carga de tarjetas en la EEPROM
void saveCardToEEPROM(int cardIndex, String uuid) {
  int startAddress = 120 + cardIndex * 100; // Cambié a 100 bytes por tarjeta para tener más espacio si se necesita
  writeStringToEEPROM(startAddress, uuid); // Usar la función para escribir el UUID
}

void loadCardsFromEEPROM() {
  allowedCardCount = EEPROM.read(119); // Leer la cantidad de tarjetas guardadas desde la dirección 119
  Serial.println("Loading cards from EEPROM...");
  
  for (int i = 0; i < allowedCardCount; i++) {
    int startAddress = 120 + i * 100; // Cambié a 100 bytes por tarjeta para tener más espacio
    String uuid = readStringFromEEPROM(startAddress); // Usar la función para leer el UUID
    allowedCards[i] = uuid; // Añadir la tarjeta a la lista
    Serial.print("Card ");
    Serial.print(i + 1);  // Imprime el número de la tarjeta (1, 2, 3...)
    Serial.print(": ");
    Serial.println(uuid); // Imprime el UUID de la tarjeta
  }

  Serial.println("Cards loaded successfully.");
}

class MyCallbacks : public BLECharacteristicCallbacks {
  void onDisconnect(BLEServer* pServer) {
        // Reiniciar advertising
        pServer->startAdvertising();
        Serial.println("Advertising re-enabled.");
    }

  void onWrite(BLECharacteristic *pCharacteristic) override {
    String receivedValue = pCharacteristic->getValue().c_str();

    if (receivedValue.length() > 0) {
      Serial.print("Received over BT: ");
      Serial.println(receivedValue);
      if (receivedValue.startsWith("s")) {
        int firstDelimiterIndex = receivedValue.indexOf(';');
        int secondDelimiterIndex = receivedValue.indexOf(';', firstDelimiterIndex + 1);

        if (firstDelimiterIndex != -1 && secondDelimiterIndex != -1) {
          wifi_ssid = receivedValue.substring(firstDelimiterIndex + 1, secondDelimiterIndex);
          wifi_password = receivedValue.substring(secondDelimiterIndex + 1);
          writeStringToEEPROM(0, wifi_ssid);
          writeStringToEEPROM(32, wifi_password);
          writeStringToEEPROM(100, "1"); // until 95 (next starts 96)
          setupWiFi();
          delay(300);
          setupSinricPro();
}
      } else if (receivedValue == "a") {
        redLEDprevioudState = digitalRead(RED_LED_PIN);
        digitalWrite(RED_LED_PIN, HIGH);  
        digitalWrite(GREEN_LED_PIN, HIGH);  
        addCardOnButtonPress = true;
      } else if (receivedValue == "lock") {
        isManualChange = true;
        // if (pSendCharacteristic != nullptr) {
        //   pSendCharacteristic->setValue("process");
        //   pSendCharacteristic->notify();
        // }
        lock();
      } else if (receivedValue == "unlock") {
        // if (pSendCharacteristic != nullptr) {
        //   pSendCharacteristic->setValue("process");
        //   pSendCharacteristic->notify();
        // }
        isManualChange = true;
        unlock();
      } else if (receivedValue == "reset"){
        for (int i = 0; i < EEPROM.length(); i++) {
          EEPROM.write(i, 0);
        }
        EEPROM.commit();
        ESP.restart();
      }
    }
  }
};

void setup() {
  pinMode(GREEN_LED_PIN, OUTPUT);
  pinMode(RED_LED_PIN, OUTPUT);
  pinMode(BUTTON_PIN, INPUT_PULLUP);

  Serial.begin(115200);
  SPI.begin(SCK_PIN, MISO_PIN, MOSI_PIN, SS_PIN);      // Init SPI bus
  mfrc522.PCD_Init();             // Init MFRC522
  myServo.attach(PIN_SG90);

  EEPROM.begin(512);
  delay(100);


  bool currentLockState = readStringFromEEPROM(110) == "1" ? true : false;

  if (currentLockState) {
    Serial.println("Puerta cerrada al inicio.");
  } else {
    Serial.println("Puerta abierta al inicio. Cerrando...");
    lock(); // Cerrar la puerta
    currentLockState = true;
    writeStringToEEPROM(110,"1");  // Guardar estado cerrado en la EEPROM
    EEPROM.commit();
  }

  loadCardsFromEEPROM();

  String beenSetup = readStringFromEEPROM(100);
  if (beenSetup != "1") {
    //digitalWrite(GREEN_LED_PIN, HIGH);    
    Serial.println("Waiting setup");
  } else {
    setupWiFi();
    setupSinricPro();
    Serial.println(readStringFromEEPROM(0));
    Serial.println(readStringFromEEPROM(32));
  }

  

  
  BLEDevice::init("Lock32");
  BLEServer *pServer = BLEDevice::createServer();
  BLEService *pService = pServer->createService(SERVICE_UUID);
  
  BLECharacteristic *pCharacteristic = pService->createCharacteristic(
                                         CHARACTERISTIC_UUID,
                                         BLECharacteristic::PROPERTY_READ |
                                         BLECharacteristic::PROPERTY_WRITE
                                       );
  pCharacteristic->setCallbacks(new MyCallbacks());

  // Crear la característica BLE para enviar el estado de bloqueo
  pSendCharacteristic = pService->createCharacteristic(
                           CHARACTERISTIC_UUID_SEND,
                           BLECharacteristic::PROPERTY_NOTIFY
                         );
  pService->start();
  pCharacteristic->setValue("none");
  pSendCharacteristic->setValue("On");
  BLEAdvertising *pAdvertising = pServer->getAdvertising();
  pAdvertising->start();
  Serial.println("Waiting a client connection to notify...");
}

unsigned long lastCardRead = 0;
const unsigned long debounceDelay = 2000; // 2 seconds debounce delay

void loop() {
  // Check for any incoming SinricPro messages
  SinricPro.handle();

  // Handle button press
  static unsigned long buttonPressStartTime = 0;
  static bool buttonWasPressed = false;
  
  bool buttonState = digitalRead(BUTTON_PIN) == LOW; // Button is pressed when LOW
  
  if (buttonState && !buttonWasPressed) { // Button just pressed
    buttonPressStartTime = millis();
    buttonWasPressed = true;
    digitalWrite(RED_LED_PIN, HIGH); // Indicate button press
  }
  
  if (!buttonState && buttonWasPressed) { // Button just released
    unsigned long buttonPressDuration = millis() - buttonPressStartTime;
    
    if (buttonPressDuration >= 5000 && buttonPressDuration <= 13999) { // Long press for 5 seconds
      Serial.println("Long press detected. Adding card.");
      redLEDprevioudState = digitalRead(RED_LED_PIN);
      digitalWrite(GREEN_LED_PIN, HIGH);
      digitalWrite(RED_LED_PIN, HIGH);
      addCardOnButtonPress = true;
      
    } else if (buttonPressDuration >= 14000) { // Long press for 15 seconds
      for (int i = 0; i < EEPROM.length(); i++) {
        EEPROM.write(i, 0);
      }
      EEPROM.commit();
      ESP.restart();
    } else { // Short press
      Serial.println("Button press detected. Toggling lock state.");
      Serial.println(readStringFromEEPROM(0));
      Serial.println(readStringFromEEPROM(32));
      Serial.println(readStringFromEEPROM(100));
      if (addCardOnButtonPress){
        addCardOnButtonPress = false; // Reset the flag
      } else {
        if (pSendCharacteristic != nullptr) {
          pSendCharacteristic->setValue("process");
          pSendCharacteristic->notify();
        }
        isManualChange = true;
      // Toggle lock state
        if (currentLockState) {
          unlock();
          
        } else {
          lock();
        }
      }
    }
    buttonWasPressed = false;
    // digitalWrite(RED_LED_PIN, LOW); // Indicate button release
  }

  // Check the state of the card reader
  if (millis() - lastCardRead > debounceDelay) {
    if (mfrc522.PICC_IsNewCardPresent() && mfrc522.PICC_ReadCardSerial()) {
      String uuid = "";
      for (byte i = 0; i < mfrc522.uid.size; i++) {
        uuid += String(mfrc522.uid.uidByte[i], HEX);
      }
      uuid.toUpperCase(); // Convert UUID to uppercase
      Serial.print("Card UUID: ");
      Serial.println(uuid);

      bool isAllowed = false;
      for (int i = 0; i < allowedCardCount; i++) {
        if (allowedCards[i] == uuid) {
          isAllowed = true;
          break;
        }
      }

      if (isAllowed) {
        Serial.println("Card is allowed.");
        if (pSendCharacteristic != nullptr) {
          pSendCharacteristic->setValue("process");
          pSendCharacteristic->notify();
        }
        isManualChange = true;
        if (currentLockState == true) { // If the current state is locked
          unlock(); // Unlock if currently locked
          writeStringToEEPROM(110,"0");  // Guardar estado desbloqueado en EEPROM
          EEPROM.commit();
          digitalWrite(GREEN_LED_PIN, LOW);
        } else {
          lock();
          writeStringToEEPROM(110,"1");  // Guardar estado desbloqueado en EEPROM
          EEPROM.commit();
          digitalWrite(GREEN_LED_PIN, HIGH);
        }
        
        blinkLED(GREEN_LED_PIN);
      } else {
        Serial.println("Card is not allowed.");
        //if (currentLockState == false) { // If the current state is unlocked
        if (pSendCharacteristic != nullptr) {
          pSendCharacteristic->setValue("process");
          pSendCharacteristic->notify();
        }
          isManualChange = true;
          blinkLED(RED_LED_PIN);
          blinkLED(RED_LED_PIN);
          digitalWrite(RED_LED_PIN, HIGH);
          if (currentLockState == false) 
          {
            lock();

          }
      }

      // Update the last card read time
      lastCardRead = millis();
      // Stop reading the card
      mfrc522.PICC_HaltA();
      mfrc522.PCD_StopCrypto1();
    }
  }

  delay(100); // Small delay to avoid excessive loop iterations

  // Handle adding a card to the allowed list if button was pressed long
  if (addCardOnButtonPress) {
    // Read card and add to allowed list
    if (mfrc522.PICC_IsNewCardPresent() && mfrc522.PICC_ReadCardSerial()) {
      String uuid = "";
      for (byte i = 0; i < mfrc522.uid.size; i++) {
        uuid += String(mfrc522.uid.uidByte[i], HEX);
      }
      uuid.toUpperCase(); // Convert UUID to uppercase
      Serial.print("Card UUID for registration: ");
      Serial.println(uuid);
      redLEDprevioudState = digitalRead(RED_LED_PIN);
      addCardToAllowedList(uuid);
      addCardOnButtonPress = false; // Reset the flag
    }
  }

  advertise_interval++;

  if (advertise_interval == 50){
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->start();  // Reinicia el advertising en cada ciclo de loop
  Serial.println("Re-enabling advertising.");
  advertise_interval = 0;
  }
}


