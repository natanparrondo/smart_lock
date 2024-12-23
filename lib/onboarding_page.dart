import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:local_auth/local_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_lock/theme/font_styles.dart';
import 'home_page.dart'; // Import your HomePage widget
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'functions/device_connection.dart';

BluetoothDevice? device;

class OnboardingPage extends StatefulWidget {
  OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => OnboardingPageState();
}

final TextEditingController _passwordController =
    TextEditingController(text: 'vXugB22L5mKzVbi54D5g');
final TextEditingController _ssidController =
    TextEditingController(text: 'MovistarFibra-6F1288');

class OnboardingPageState extends State<OnboardingPage> {
  Future<void> _setAppBeenSetup(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('appBeenSetup', value);
  }

  Future<void> _requestBluetoothPermission() async {
    if (Platform.isAndroid) {
      await FlutterBluePlus.turnOn();
      if (Platform.isAndroid) {
        PermissionStatus status = await Permission.bluetooth.request();
        if (status.isGranted) {
          await FlutterBluePlus.turnOn();
        }
      }
    }
  }

  Future<void> _requestLocationPermission() async {
    await Permission.locationWhenInUse.request();
  }

  Future<void> _requestPermissionsSequentially() async {
    await _requestBluetoothPermission(); // Wait until Bluetooth permission is handled
    await _requestLocationPermission(); // Then ask for location permission
  }

  @override
  void initState() {
    super.initState();
    _requestPermissionsSequentially();
  }

  StreamSubscription<List<int>>? characteristicSubscription;

  @override
  void dispose() {
    // Cancelar cualquier suscripción activa para evitar errores
    characteristicSubscription?.cancel();
    super.dispose();
  }

  final LocalAuthentication auth = LocalAuthentication();
  int _currentStep = 0;
  bool _showingLoading = false;

  void _nextStep() async {
    if (_currentStep == 0) {
      setState(() {
        _showingLoading = true;
      });
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        // Check if the widget is still mounted
        setState(() {
          _showingLoading = false;
          _currentStep++;
        });
      }
    } else {
      if (mounted) {
        // Check if the widget is still mounted
        setState(() {
          _currentStep++;
        });
      }
    }
  }

  void _subscribeToCharacteristic() async {
    try {
      // Asegúrate de que el dispositivo esté conectado
      BluetoothDevice? connectedDevice = DeviceConnection().connectedDevice;
      if (connectedDevice == null) {
        print('No device connected.');
        return;
      }

      // Descubre los servicios y las características
      List<BluetoothService> services =
          await connectedDevice.discoverServices();
      for (BluetoothService service in services) {
        if (service.uuid.toString() == DeviceConnection().serviceUUID) {
          for (BluetoothCharacteristic characteristic
              in service.characteristics) {
            if (characteristic.uuid.toString() ==
                DeviceConnection().characteristicUUID) {
              // Asegúrate de que la característica soporte notificaciones
              if (characteristic.properties.notify) {
                // Suscribirse a las notificaciones de la característica
                await characteristic.setNotifyValue(true);

                // Escuchar los cambios en la característica (notificaciones)
                characteristic.value.listen((value) {
                  // Los datos recibidos estarán en 'value', que es una lista de bytes
                  String receivedData = utf8.decode(value);
                  print('Received data: $receivedData');

                  // Aquí puedes manejar los datos recibidos
                  // Por ejemplo, puedes actualizar el estado de la UI o realizar otras acciones
                });

                print('Listening to characteristic notifications.');
                return; // Salir del bucle una vez que se ha encontrado la característica
              } else {
                print('Characteristic does not support notifications.');
              }
            }
          }
        }
      }
      print('Characteristic not found.');
    } catch (e) {
      print('Error subscribing to notifications: $e');
    }
  }

  Future<void> _saveDeviceModel(String deviceModel) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('deviceModel', deviceModel);
  }

  Future<void> scanAndConnectToDevice() async {
    setState(() {
      _showingLoading = true;
    });

    if (Platform.isAndroid) {
      await FlutterBluePlus.turnOn(); // Request the user to turn on Bluetooth
    }

    bool isDeviceConnected = false;

    try {
      // Start scanning for devices with a 15-second timeout
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 60),
        withNames: ["Lock32"], // Filter by device name
      );

      var subscription = FlutterBluePlus.scanResults.listen((results) async {
        for (ScanResult result in results) {
          if (result.advertisementData.localName == "Lock32") {
            BluetoothDevice device = result.device;
            await FlutterBluePlus.stopScan();

            try {
              // Connect to the device using DeviceConnection
              await DeviceConnection().connectToDevice(device);
              // Justo después de la conexión exitosa al dispositivo
              DeviceConnection().connectedDevice?.state.listen((state) async {
                if (state == BluetoothConnectionState.connected) {
                  print('Connected to the device!');
                  isDeviceConnected = true;

                  // Suscribirse a las notificaciones
                  _subscribeToCharacteristic();

                  // Guardar el modelo del dispositivo
                  await _saveDeviceModel(device.name);

                  _nextStep(); // Continuar al siguiente paso
                } else if (state == BluetoothConnectionState.disconnected) {
                  print('Disconnected from the device!');
                }
              });
            } catch (e) {
              print('Failed to connect: $e');
            }
            break; // Exit the loop after finding the device
          }
        }
      });

      // Wait 15 seconds to allow the device to connect
      await Future.delayed(const Duration(seconds: 15));

      if (!isDeviceConnected) {
        await FlutterBluePlus.stopScan();
        subscription.cancel();
        setState(() {
          _currentStep =
              -2; // Paso para mostrar que no se encontró el dispositivo
        });
        _nextStep();
      }
    } catch (e) {
      print('Error during Bluetooth operations: $e');
    } finally {
      // if (mounted) {
      //   setState(() {
      //     _showingLoading = false;
      //   });
      // }
    }
  }

  Future<void> _authenticate() async {
    bool authenticated = false;
    try {
      authenticated = await auth.authenticate(
        localizedReason: 'Autenticar para activar acceso biométrico.',
        options: const AuthenticationOptions(
          useErrorDialogs: true,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      print(e);
    }
    if (authenticated) {
      await _setAppBeenSetup(true);
      _nextStep();
    }
  }

  Future<void> _end() async {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) =>
            HomePage(fromOnboarding: true), // Pasar el parámetro aquí
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                child: _getCurrentStep(),
              ),
            ),
          ),
          if (_showingLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _getCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      case 2:
        return _buildStep3();
      case 3:
        return _buildStep4();
      case 4:
        return _buildStep5();
      case -1:
        return _buildStep2Fail();
      default:
        return _buildStep1();
    }
  }

  Widget _buildStep1() {
    return Column(
      key: const ValueKey(0),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          'lib/assets/onboarding_search.png',
          width: 250,
        ),
        const SizedBox(height: 12),
        Text(
          "Vincular dispositivo",
          style: TextStyles.heading1(context),
        ),
        const SizedBox(height: 12),
        Text(
          textAlign: TextAlign.center,
          "Se buscaran los dispositivos cercanos compatibles para conectar con la aplicación.",
          style: TextStyles.normalText(context),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: scanAndConnectToDevice,
          label: const Text("Continuar"),
          icon: const Icon(Icons.chevron_right),
          iconAlignment: IconAlignment.end,
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      key: const ValueKey(1),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          'lib/assets/onboarding_success.png',
          width: 250,
        ),
        const SizedBox(height: 12),
        Text(
          "Dispositivo encontrado",
          style: TextStyles.heading1(context),
        ),
        const SizedBox(height: 12),
        Text.rich(
          const TextSpan(
            text: 'Se establecerá "', // default text style
            children: <TextSpan>[
              TextSpan(
                text: 'Lock32',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurpleAccent,
                ),
              ),
              TextSpan(
                text: '" como dispositivo principal para usar en Smart Lock.',
              ),
            ],
          ),
          textAlign: TextAlign.center,
          style: TextStyles.normalText(context),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _nextStep,
          label: const Text("Conectar"),
          icon: const Icon(Icons.chevron_right),
          iconAlignment: IconAlignment.end,
        ),
      ],
    );
  }

  Widget _buildStep2Fail() {
    return Column(
      key: const ValueKey(-1),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          'lib/assets/onboarding_failed.png',
          width: 250,
        ),
        const SizedBox(height: 12),
        Text(
          "Dispositivo no encontrado",
          style: TextStyles.heading1(context),
        ),
        const SizedBox(height: 12),
        Text.rich(
          const TextSpan(
            text:
                'No se encontró ningun dispositivo con el nombre "', // default text style
            children: <TextSpan>[
              TextSpan(
                text: 'Lock32',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurpleAccent,
                ),
              ),
              TextSpan(
                text:
                    '". Asegurate de que el Bluetooth de tu celular esté encendido y el dispositivo este en modo de emparejamiento.',
              ),
            ],
          ),
          textAlign: TextAlign.center,
          style: TextStyles.normalText(context),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () {
            _currentStep = -1;
            _nextStep();
          },
          label: const Text("Reintentar"),
          icon: const Icon(Icons.refresh),
          iconAlignment: IconAlignment.end,
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      key: const ValueKey(2),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 12),
        Text(
          textAlign: TextAlign.center,
          "Ingresa las credenciales WI-FI",
          style: TextStyles.heading1(context),
        ),
        const SizedBox(height: 12),
        Text(
          textAlign: TextAlign.center,
          "Será usado para autenticar con la cerradura, solo lo pediremos la primera vez.",
          style: TextStyles.normalText(context),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _ssidController,
          style: const TextStyle(fontFamily: TextStyles.fontFamily),
          keyboardType: TextInputType.text,
          autofocus: true,
          decoration: const InputDecoration(
              label: Text(
                "SSID (Nombre)",
                style: TextStyle(fontFamily: TextStyles.fontFamily),
              ),
              border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            label: Text(
              "Password",
              style: TextStyle(fontFamily: TextStyles.fontFamily),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () {
            _sendWifiData();
          }, // Updated to use function reference
          style: TextButton.styleFrom(
            textStyle: TextStyles.normalText(context),
            foregroundColor: Colors.white,
            backgroundColor: Colors.deepPurple, // Sets the text color
            padding: const EdgeInsets.symmetric(
                horizontal: 16.0, vertical: 12.0), // Adjust padding if needed
          ),
          label: const Text("Conectar"),
          icon: const Icon(Icons.wifi_rounded),
          iconAlignment: IconAlignment.end,
        ),
        SizedBox(
          height: 8,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 12,
            ),
            TextButton.icon(
              onPressed: _nextStep, // Updated to use function reference
              style: TextButton.styleFrom(
                textStyle: TextStyles.normalText(context),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0), // Adjust padding if needed
              ),
              label: const Text("Continuar sin conectar"),
              icon: const Icon(Icons.chevron_right),
              iconAlignment: IconAlignment.end,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep4() {
    return Column(
      key: const ValueKey(3),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          'lib/assets/onboarding_biometric.png',
          width: 250,
        ),
        const SizedBox(height: 12),
        Text(
          textAlign: TextAlign.center,
          "Habilitar acceso con biometria",
          style: TextStyles.heading1(context),
        ),
        const SizedBox(height: 12),
        Text(
          textAlign: TextAlign.center,
          "Habilita el permiso necesario para acceder a la app de forma segura con Touch ID, Face ID o PIN.",
          style: TextStyles.normalText(context),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _authenticate,
          label: const Text("Habilitar acceso biometrico"),
          icon: const Icon(Icons.chevron_right),
          iconAlignment: IconAlignment.end,
        ),
      ],
    );
  }

  Widget _buildStep5() {
    return Column(
      key: const ValueKey(4),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          'lib/assets/onboarding_end.png',
          width: 250,
        ),
        const SizedBox(height: 12),
        Text(
          textAlign: TextAlign.center,
          "Todo listo!",
          style: TextStyles.heading1(context),
        ),
        const SizedBox(height: 12),
        Text(
          textAlign: TextAlign.center,
          "Termino el paso de configuración del dispositivo, ya puedes empezar a usarla. Puedes añadir tarjetas en la pantalla de configuración.",
          style: TextStyles.normalText(context),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _end,
          label: const Text("Finalizar"),
          icon: const Icon(Icons.check),
          iconAlignment: IconAlignment.end,
        ),
      ],
    );
  }

  void _sendWifiData() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _showingLoading = true; // Mostrar el indicador de carga antes de enviar
    });

    final String ssid = _ssidController.text;
    final String password = _passwordController.text;
    final String formattedData = 's;$ssid;$password';

    try {
      // Ensure the device is connected
      BluetoothDevice? connectedDevice = DeviceConnection().connectedDevice;
      if (connectedDevice == null) {
        print('No device connected.');
        return;
      }

      // Discover services and characteristics
      List<BluetoothService> services =
          await connectedDevice.discoverServices();
      for (BluetoothService service in services) {
        if (service.uuid.toString() == DeviceConnection().serviceUUID) {
          for (BluetoothCharacteristic characteristic
              in service.characteristics) {
            if (characteristic.uuid.toString() ==
                DeviceConnection().characteristicUUID) {
              // Write the formatted data to the BLE characteristic
              await characteristic.write(utf8.encode(formattedData),
                  withoutResponse: false);
              print('Data sent: $formattedData');
              // Proceed to the next step
              _nextStep();
              return;
            }
          }
        }
      }
      print('Characteristic not found.');
    } catch (e) {
      print('Error sending Wi-Fi data: $e');
    } finally {
      setState(() {
        _showingLoading =
            false; // Ocultar el indicador de carga después de enviar
      });
    }
  }
}
