import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; // Import the BLE library
import 'package:smart_lock/functions/device_connection.dart'; // Import the DeviceConnection class
import 'package:smart_lock/functions/sinric_requests.dart';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;

import 'package:smart_lock/theme/font_styles.dart'; // Import for BackdropFilter

BluetoothDevice? _connectedDevice;

BluetoothCharacteristic? _commandCharacteristic;
BluetoothCharacteristic? _statusCharacteristic;

class HomePage extends StatefulWidget {
  final bool fromOnboarding; // Nuevo parámetro

  HomePage({super.key, this.fromOnboarding = false});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final LocalAuthentication auth = LocalAuthentication();
  bool isAuthenticated = false;
  bool isAuthenticating = false;
  bool _isConnecting = false;
  bool _locked = true;
  bool _isButtonPressed = false;
  double _scale = 1.0;
  int _selectedIndex = 0; // Default selection index for BT
  bool isConnected = false;
  bool bluetoothUnavailable = true;
  bool fromOnboarding = false; // Nueva variable
  bool isDeviceConnected = false;

  // Define los UUIDs como constantes para facilitar su uso y mantenimiento
  String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  String COMMAND_CHARACTERISTIC_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
  String STATUS_CHARACTERISTIC_UUID = "4694c381-4c73-473f-b9f6-fac2384527b7";

  final DeviceConnection _deviceConnection =
      DeviceConnection(); // Singleton instance

  @override
  void initState() {
    super.initState();
    _authenticate();
    startSSEListening();
    fromOnboarding = widget.fromOnboarding; // Asignar el valor pasado
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isConnecting && !fromOnboarding) {
      // Solo intentar conectar si NO viene de Onboarding
      _attemptConnection();
    }
    fromOnboarding = false; // Reiniciar para futuras navegaciones
  }

  Future<void> _discoverAndAssignCharacteristics() async {
    if (_deviceConnection.connectedDevice != null) {
      List<BluetoothService> services =
          await _deviceConnection.connectedDevice!.discoverServices();
      for (var service in services) {
        if (service.uuid.toString() == SERVICE_UUID) {
          // Usa la constante definida
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString() == COMMAND_CHARACTERISTIC_UUID) {
              _commandCharacteristic = characteristic;
              print("Command Characteristic found");
            } else if (characteristic.uuid.toString() ==
                STATUS_CHARACTERISTIC_UUID) {
              _statusCharacteristic = characteristic;
              await _statusCharacteristic!.setNotifyValue(true);
              _statusCharacteristic!.value.listen((value) {
                String lockState = String.fromCharCodes(value).trim();
                print('Estado recibido: $lockState');
                setState(() {
                  _locked = (lockState == 'On');
                });
              });
              print("Status Characteristic found and notification set");
            }
          }
        }
      }
    }
  }

  Future<void> listenAndSendCommand() async {
    try {
      if (_deviceConnection.connectedDevice != null) {
        var services =
            await _deviceConnection.connectedDevice!.discoverServices();

        for (var service in services) {
          var mainCharacteristic = service.characteristics.firstWhere(
            (characteristic) =>
                characteristic.uuid.toString() ==
                '12ab34cd-56ef-78gh-90ij-klmnopqrstuv',
          );

          await mainCharacteristic.setNotifyValue(true);

          mainCharacteristic.value.listen((value) async {
            String lockState = String.fromCharCodes(value);
            print('Estado recibido: $lockState');

            // Actualiza la variable _locked en función del estado recibido
            if (lockState == 'On') {
              _locked = true; // Estado bloqueado
              await mainCharacteristic.write('On'.codeUnits);
              print('Enviado comando "On" a la otra característica');
            } else if (lockState == 'Off') {
              _locked = false; // Estado desbloqueado
              await mainCharacteristic.write('Off'.codeUnits);
              print('Enviado comando "Off" a la otra característica');
            }

            // Mostrar el estado actual del bloqueo en la consola
            print(
                'Estado actual del bloqueo: ${_locked ? 'Bloqueado' : 'Desbloqueado'}');
          }, onError: (error) {
            print('Error al escuchar la característica: $error');
          });
        }
      }
    } catch (e) {
      print('Error en listenAndSendCommand: $e');
    }
  }

  // Function to attempt connection to the device
  Future<void> _attemptConnection() async {
    // Mostrar diálogo de conexión
    Future.delayed(Duration.zero, () {
      showDialog(
        context: context,
        barrierDismissible: false, // Prevenir cierre al tocar fuera
        builder: (BuildContext context) {
          return AlertDialog(
              title: const Text('Conectando...'),
              content: Row(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(width: 20),
                  const Text('Por favor, espere.'),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed: () {
                    Navigator.of(context).pop(); // Cerrar el diálogo
                  },
                )
              ]);
        },
      );
    });

    // Intentar conectar al dispositivo
    bool connected = await scanAndConnectToDevice();

    // Cerrar el diálogo después del intento de conexión
    Navigator.of(context).pop();

    if (connected) {
      await _discoverAndAssignCharacteristics();
      _showConnectionDialog('Éxito', 'Conectado al dispositivo.');
      setState(() {
        isDeviceConnected = true;
        bluetoothUnavailable = false;
      });
    } else {
      _showConnectionDialog('Error', 'No se pudo conectar al dispositivo.');
      setState(() {
        bluetoothUnavailable = true;
      });
    }
  }

  void _showConnectionDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
          ],
        );
      },
    );
  }

  Future<bool> scanAndConnectToDevice() async {
    if (Platform.isAndroid) {
      await FlutterBluePlus.turnOn(); // Request the user to turn on Bluetooth
    }

    try {
      // Start scanning for devices with a 1-second timeout
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 1),
        withNames: ["Lock32"], // Filter by device name
      );

      var subscription = FlutterBluePlus.scanResults.listen((results) async {
        for (ScanResult result in results) {
          if (result.advertisementData.localName == "Lock32") {
            BluetoothDevice device = result.device;
            await FlutterBluePlus.stopScan();

            try {
              // Connect to the device using DeviceConnection
              await _deviceConnection.connectToDevice(device);
              _deviceConnection.connectedDevice?.state.listen((state) async {
                if (state == BluetoothConnectionState.connected) {
                  print('Connected to the device!');
                  isDeviceConnected = true;

                  // Escuchar el estado del bloqueo
                  _deviceConnection.connectedDevice!
                      .discoverServices()
                      .then((services) {
                    for (var service in services) {
                      if (service.uuid.toString() ==
                          "4fafc201-1fb5-459e-8fcc-c5c9c331914b") {
                        for (var characteristic in service.characteristics) {
                          if (characteristic.uuid.toString() ==
                              "04b598db-da1a-4ee0-a6a8-487f553eebeb") {
                            // Este UUID parece ser anterior o incorrecto
                            characteristic
                                .setNotifyValue(true); // Activar notificaciones
                            characteristic.value.listen((value) {
                              String lockState =
                                  String.fromCharCodes(value).trim();
                              setState(() {
                                _locked =
                                    (lockState == 'On'); // Actualiza el estado
                              });
                            });
                          }
                        }
                      }
                    }
                  });
                } else if (state == BluetoothConnectionState.disconnected) {
                  print('Disconnected from the device!');
                  setState(() {
                    isDeviceConnected =
                        false; // Update the state if disconnected
                  });
                }
              });
            } catch (e) {
              print('Failed to connect: $e');
              // Set isDeviceConnected to false if an error occurs
              isDeviceConnected = false;
            }
            break; // Exit the loop after finding the device
          }
        }
      });

      // Wait 15 seconds to allow the device to connect
      await Future.delayed(const Duration(seconds: 2));

      if (!isDeviceConnected) {
        await FlutterBluePlus.stopScan();
        subscription.cancel();
      }
    } catch (e) {
      print('Error during Bluetooth operations: $e');
    }
    return isDeviceConnected; // Return the connection status
  }

  // Function to start listening to the SSE stream

  // Function to start listening to the SSE stream
  void startSSEListening() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('sinric_api_key');
    print(accessToken);
    final url = Uri.parse(
        'https://portal.sinric.pro/sse/stream?accessToken=$accessToken');

    try {
      final client = http.Client();
      final request = http.Request('GET', url);
      final response = await client.send(request);

      response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (data) {
          if (data.isNotEmpty) {
            try {
              final event = jsonDecode(data);
              print('Received SSE event: $event');
              if (event['event'] == 'deviceMessageArrived') {
                final deviceState = event['Cerradura']['lockState'];
                setState(() {
                  _locked = (deviceState == 'On');
                });
              }
            } catch (e) {
              print('Error decoding event: $e');
            }
          }
        },
        onError: (e) {
          print('Stream error: $e');
        },
      );
    } catch (e) {
      print('Error starting SSE listening: $e');
    }
  }

  Future<void> _handleLockToggle() async {
    String command = _locked ? "lock" : "unlock";
    if (_selectedIndex == 0 && _deviceConnection.connectedDevice != null) {
//    if (_selectedIndex == 0 || _deviceConnection.connectedDevice != fnull) {
      //bt
      print('Changing lock state over bt');
      await _ToggleLockBluetooth(command);
      _selectedIndex = 0;
    } else {
      print('Device is not available over BT, using Wifi.');
      await _ToggleLockWiFi(command);
      _selectedIndex = 1;
    }
  }

  Future<void> _ToggleLockWiFi(command) async {
    await sendLockStateRequest(command, context);
  }

  Future<void> _ToggleLockBluetooth(command) async {
    await _writeCharacteristic(command);
  }

  Future<String?> _getSavedDeviceModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('deviceModel');
  }

  void _loadDeviceModel() async {
    String? deviceModel = await _getSavedDeviceModel();
    if (deviceModel != null) {
      // Try to reconnect using the device model name
      _reconnectToDevice(deviceModel);
    }
  }

  void _reconnectToDevice(String deviceModel) async {
    // Start scanning for devices
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));

    // Listen to scan results
    FlutterBluePlus.scanResults.listen((List<ScanResult> results) {
      for (ScanResult r in results) {
        if (r.device.name == deviceModel) {
          // Stop scanning
          FlutterBluePlus.stopScan();

          // Connect to the device
          _connectedDevice = r.device;
          _connectedDevice!.connect().then((_) {
            print("Connected to $deviceModel");
            // Handle successful connection here
          }).catchError((error) {
            print("Failed to connect: $error");
            // Handle connection failure here
          });
          break;
        }
      }
    });
  }

  Future<void> _authenticate() async {
    setState(() {
      isAuthenticating = true;
    });
    bool authenticated = false;
    try {
      authenticated = await auth.authenticate(
        localizedReason: 'Autenticar para activar acceso biométrico.',
        options: const AuthenticationOptions(
          useErrorDialogs: true,
          stickyAuth: true,
        ),
      );
      setState(() {
        isAuthenticated = authenticated;
        isAuthenticating = false;
      });
    } catch (e) {
      setState(() {
        isAuthenticating = false;
      });
      print(e);
    }
  }

  Future<void> clearAllPreferences() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<void> _writeCharacteristic(String value) async {
    try {
      await _deviceConnection.writeCharacteristic(value);
      print('Data written successfully.');
    } catch (e) {
      print('Error writing characteristic: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: isAuthenticated
          ? AppBar(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              title: Text(
                "Smart Lock",
                style: TextStyles.heading1,
              ),
              centerTitle: true,
              leading: IconButton(
                onPressed: _attemptConnection,
                icon: Icon(Icons.wifi_tethering),
                color: bluetoothUnavailable ? Colors.red : Colors.green,
              ),
              actions: [
                IconButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/settings');
                  },
                  icon: const Icon(Icons.settings_outlined),
                )
              ],
            )
          : null,
      body: Stack(
        children: [
          // Main content
          Visibility(
            visible: isAuthenticated,
            child: Center(
              child: GestureDetector(
                onTapDown: (_) {
                  setState(() {
                    _isButtonPressed = true;
                    _scale = 0.9;
                  });
                },
                onTapUp: (_) {
                  setState(() {
                    _isButtonPressed = false;
                    _scale = 1.0;
                    _locked = !_locked;
                    _handleLockToggle(); // Handle the lock toggle action
                  });
                },
                onTapCancel: () {
                  setState(() {
                    _isButtonPressed = false;
                    _scale = 1.0;
                  });
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Transform.scale(
                      scale: _scale,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        switchInCurve: Curves.easeIn,
                        switchOutCurve: Curves.bounceIn,
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
                          HapticFeedback.heavyImpact();
                          return ScaleTransition(
                            scale: animation,
                            child: child,
                          );
                        },
                        child: Image.asset(
                          _locked
                              ? 'lib/assets/locked.png'
                              : 'lib/assets/unlocked.png',
                          key: ValueKey<bool>(_locked),
                          width: 150,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _locked ? "Bloqueado" : "Desbloqueado",
                      style: TextStyles.heading1,
                    ),
                    Text(
                      _locked
                          ? "Mantener pulsado para desbloquear"
                          : "Mantener pulsado para bloquear",
                      style: TextStyles.normalText,
                    ),
                    const SizedBox(height: 12),
                    _selectedIndex == 0 //bt is selected
                        ? TextButton.icon(
                            icon: const Icon(Icons.add_card_rounded),
                            style: TextButton.styleFrom(
                              textStyle: TextStyles.normalText,
                              foregroundColor: Colors.white,
                              backgroundColor:
                                  Colors.deepPurple, // Sets the text color
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 12.0), // Adjust padding if needed
                            ),
                            onPressed: () async {
                              await _writeCharacteristic("a");
                            },
                            label: const Text("Añadir Tarjeta RFID"),
                          )
                        : const SizedBox.shrink(),
                    const SizedBox(height: 12),
                    SegmentedButton<int>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment<int>(
                            value: 0,
                            label: const Icon(Icons.bluetooth),
                            enabled: bluetoothUnavailable || isDeviceConnected),
                        const ButtonSegment<int>(
                          value: 1,
                          label: Icon(Icons.wifi),
                        ),
                      ],
                      selected: {_selectedIndex},
                      onSelectionChanged: (Set<int> newSelection) {
                        setState(() {
                          _selectedIndex = newSelection.first;
                        });
                      },
                      style: ButtonStyle(
                        backgroundColor:
                            WidgetStateProperty.resolveWith<Color?>(
                          (Set<WidgetState> states) {
                            if (states.contains(WidgetState.selected)) {
                              return Colors
                                  .deepPurple; // Selected background color
                            }
                            return null; // Default background color
                          },
                        ),
                        foregroundColor:
                            WidgetStateProperty.resolveWith<Color?>((states) {
                          if (states.contains(WidgetState.selected)) {
                            return Colors
                                .white; // Set icon color to white when selected
                          }
                          return null; // Default icon color
                        }),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        await clearAllPreferences();
                      },
                      child: const Text('Clear Preferences'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Blurred overlay with retry button
          Visibility(
            visible: !isAuthenticated && !isAuthenticating,
            child: Center(
              child: Stack(
                children: [
                  BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                    child: Container(
                      color: Colors.black.withOpacity(0.5),
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Autenticación requerida",
                          style: TextStyle(color: Colors.white, fontSize: 24),
                        ),
                        const SizedBox(height: 20),
                        IconButton(
                          icon: const Icon(Icons.replay,
                              color: Colors.white, size: 50),
                          onPressed: _authenticate,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Loading spinner while authenticating
          Visibility(
            visible: isAuthenticating,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ],
      ),
    );
  }
}
