import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_lock/theme/font_styles.dart';
import 'dart:ui' as ui; // Import for BackdropFilter

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

  @override
  void initState() {
    super.initState();
    _authenticate();
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
              leading: Icon(Icons.wifi_tethering),
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
                    SizedBox(
                      height: 12,
                    ),
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
                    SizedBox(
                      height: 12,
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
