# 🔒 Smart Lock - Cerradura Inteligente

**Cerradura electrónica inteligente** basada en **ESP32** y controlada mediante una **aplicación complementaria desarrollada con Flutter**. Permite gestionar el acceso a través de múltiples métodos, incluyendo **Wi-Fi, BLE, RFID y NFC**.  

📌 **Características principales:**  
✅ Control remoto mediante **Wi-Fi** (integración con Sinric Pro, compatible con Google Home, Alexa, SmartThings, IFTTT y más).  
✅ Conexión **Bluetooth Low Energy (BLE)** para desbloqueo local sin Internet.  
✅ Autenticación con **tarjetas RFID**.  
✅ Uso de **NFC** para acceso rápido desde el celular desde Wallet.  
✅ Control manual mediante **botón físico** en la cerradura.  
✅ Almacenamiento de estado en **EEPROM** para recordar la configuración tras reinicios.  

---

## 📱 Aplicación Móvil (Flutter)
La aplicación permite:  
- **Configurar la cerradura por primera vez y conectarlo con aplicaciones IoT de terceros.**  
- **Configurar credenciales de Wi-Fi y Sinric Pro.**  
- **Registrar nuevas tarjetas RFID.**  
- **Monitorear el estado de la cerradura en tiempo real.**  
- **Desbloquear o bloquear la cerradura de forma remota.**  

📂 **Estructura del código:**  
```
/lib            -> Código principal de la app en Flutter (Dart).
/esp32          -> Código del microcontrolador ESP32.
```

---

## 📷 Interfaz de Usuario  
### Onboarding (Setup de la cerradura y vinculación con la aplicación)
![onboarding (1)](https://github.com/user-attachments/assets/455385fb-bd65-4b2e-91b6-49eadf2da012)
### Pantalla de inicio y configuración
![homescreen (1)](https://github.com/user-attachments/assets/aaa93421-7c4d-4b82-9220-478639797053)


---

## 🛠️ Hardware Utilizado  
- **ESP32 DevKit**  
- **Servomotor SG-90** (para accionar el pestillo)  
- **Lector RC-522** (integrado con Wallet)  
- **Conectores Molex, PCB impreso y gabinete 3D**  

---

## ⚙️ Instalación y Configuración  

### 1️⃣ Configurar el ESP32  
1. Cargar el código de la carpeta `/esp32` en el microcontrolador usando **Arduino IDE** o **PlatformIO**.  
2. Configurar las credenciales de **Wi-Fi** y **Sinric Pro** a través de la app o BLE.  

### 2️⃣ Ejecutar la Aplicación  
1. Clonar este repositorio:  
   ```bash
   git clone https://github.com/natanparrondo/smart_lock.git
   cd smart_lock
   ```
2. Instalar dependencias de Flutter:  
   ```bash
   flutter pub get
   ```
3. Ejecutar en un emulador o dispositivo físico:  
   ```bash
   flutter run
   ```

---

## 🔗 Recursos y Documentación  
- 📖 [**Informe completo del proyecto**](https://github.com/user-attachments/files/19295468/Informe.Smart.Lock.pdf)
- 📖 [Documentación de Flutter](https://docs.flutter.dev/)  
- 📖 [Guía API de Sinric Pro](https://help.sinric.pro/pages/tutorials/api-guide)  
- 📖 [ESP32 con RFID RC522](https://www.electronicwings.com/esp32/rfid-rc522-interfacing-with-esp32)  

---

📆 **Montaje de Proyectos Electrónicos III** - 2024
