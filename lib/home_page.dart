import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for HapticFeedback
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_lock/theme/font_styles.dart';
import 'package:smart_lock/settings_page.dart'; // Import your SettingsPage widget
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
    // SystemChannels.platform.invokeMethod<void>('SystemNavigator.pop');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: isAuthenticated
          ? AppBar(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              title: Text("Smart Lock", style: TextStyles.normalText),
              centerTitle: true,
              leading: Icon(
                Icons.circle,
                // Navigate to SettingsPage
              ),
              actions: [
                IconButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/settings');
                  },
                  icon: Icon(Icons.settings),
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
                onLongPress: () {
                  setState(() {
                    _locked = !_locked;
                  });
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedSwitcher(
                      duration: Duration(milliseconds: 150),
                      switchInCurve: Curves.easeIn,
                      switchOutCurve: Curves.easeInCirc,
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
