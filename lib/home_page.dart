// home_page.dart
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

class HomePage extends StatefulWidget {
  HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final LocalAuthentication auth = LocalAuthentication();
  bool isAuthenticated = false;
  bool isAuthenticating = false;
  bool _locked = true;
  bool _isButtonPressed = false;
  double _scale = 1.0;
  int _selectedIndex = 1; // Default selection index for BT
  bool isConnected = false;
  bool bluetoothUnavailable = false;

  final DeviceConnection _deviceConnection =
      DeviceConnection(); // Singleton instance

  @override
  void initState() {
    super.initState();
    _authenticate();
    scanAndConnectToDevice();
    startSSEListening();
  }

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

      response.stream.transform(utf8.decoder).transform(LineSplitter()).listen(
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
    String _command = _locked ? "lock" : "unlock";
    if (_selectedIndex == 0 && _deviceConnection.connectedDevice != null) {
//    if (_selectedIndex == 0 || _deviceConnection.connectedDevice != null) {
      //bt
      print('Changing lock state over bt');
      await _ToggleLockBluetooth(_command);
      _selectedIndex = 0;
    } else {
      print('Device is not available over BT, using Wifi.');
      await _ToggleLockWiFi(_command);
      _selectedIndex = 1;
    }
  }

  Future<void> _ToggleLockWiFi(command) async {
    await sendLockStateRequest(command);
  }

  Future<void> _ToggleLockBluetooth(command) async {
    await _writeCharacteristic(command);
  }

  Future<void> scanAndConnectToDevice() async {
    if (Platform.isAndroid) {
      await FlutterBluePlus.turnOn(); // Request the user to turn on Bluetooth
    }

    bool isDeviceConnected = false;

    try {
      // Start scanning for devices with a 15-second timeout
      await FlutterBluePlus.startScan(
        timeout: Duration(seconds: 15),
        withNames: ["MyESP32"], // Filter by device name
      );

      var subscription = FlutterBluePlus.scanResults.listen((results) async {
        for (ScanResult result in results) {
          if (result.advertisementData.localName == "MyESP32") {
            BluetoothDevice device = result.device;
            await FlutterBluePlus.stopScan();

            try {
              // Connect to the device using DeviceConnection
              await DeviceConnection().connectToDevice(device);
              DeviceConnection().connectedDevice?.state.listen((state) async {
                if (state == BluetoothConnectionState.connected) {
                  print('Connected to the device!');
                  isDeviceConnected = true;
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
      await Future.delayed(Duration(seconds: 15));

      if (!isDeviceConnected) {
        await FlutterBluePlus.stopScan();
        subscription.cancel();
      }
    } catch (e) {
      print('Error during Bluetooth operations: $e');
    } finally {
      // Set the loading state or perform any cleanup tasks here if necessary
    }
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
    FlutterBluePlus.startScan(timeout: Duration(seconds: 4));

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
              leading: Icon(
                Icons.wifi_tethering,
                color: isConnected ? Colors.green : Colors.red,
              ),
              actions: [
                IconButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/settings');
                  },
                  icon: Icon(Icons.settings_outlined),
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
                        duration: Duration(milliseconds: 300),
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
                    SizedBox(height: 12),
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
                    SizedBox(height: 12),
                    _selectedIndex == 0 //bt is selected
                        ? TextButton.icon(
                            icon: Icon(Icons.add),
                            style: TextButton.styleFrom(
                              textStyle: TextStyles.normalText,
                              foregroundColor: Colors.white,
                              backgroundColor:
                                  Colors.deepPurple, // Sets the text color
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 12.0), // Adjust padding if needed
                            ),
                            onPressed: () async {
                              await _writeCharacteristic("a");
                            },
                            label: Text("Añadir Tarjeta RFID"),
                          )
                        : SizedBox.shrink(),
                    SizedBox(height: 12),
                    SegmentedButton<int>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment<int>(
                            value: 0,
                            label: Icon(Icons.bluetooth),
                            enabled: bluetoothUnavailable),
                        ButtonSegment<int>(
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
                            MaterialStateProperty.resolveWith<Color?>(
                          (Set<MaterialState> states) {
                            if (states.contains(MaterialState.selected)) {
                              return Colors
                                  .deepPurple; // Selected background color
                            }
                            return null; // Default background color
                          },
                        ),
                        foregroundColor:
                            MaterialStateProperty.resolveWith<Color?>((states) {
                          if (states.contains(MaterialState.selected)) {
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
                      child: Text('Clear Preferences'),
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
                        Text(
                          "Autenticación requerida",
                          style: TextStyle(color: Colors.white, fontSize: 24),
                        ),
                        SizedBox(height: 20),
                        IconButton(
                          icon:
                              Icon(Icons.replay, color: Colors.white, size: 50),
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
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ],
      ),
    );
  }
}
