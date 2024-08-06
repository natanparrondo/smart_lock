import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_lock/theme/font_styles.dart';
import 'home_page.dart'; // Import your HomePage widget

class OnboardingPage extends StatefulWidget {
  OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => OnboardingPageState();
}

class OnboardingPageState extends State<OnboardingPage> {
  Future<void> _setAppBeenSetup(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('appBeenSetup', value);
  }

  final LocalAuthentication auth = LocalAuthentication();
  int _currentStep = 0;
  bool _showingLoading = false;

  void _nextStep() async {
    if (_currentStep == 0) {
      setState(() {
        _showingLoading = true;
      });
      await Future.delayed(Duration(seconds: 1));
      setState(() {
        _showingLoading = false;
        _currentStep++;
      });
    } else {
      setState(() {
        _currentStep++;
      });
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
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => HomePage()),
      );
    }
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
              child: Center(
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
      default:
        return _buildStep1();
    }
  }

  Widget _buildStep1() {
    return Column(
      key: ValueKey(0),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          'lib/assets/onboarding_search.png',
          width: 250,
        ),
        SizedBox(height: 12),
        Text(
          "Vincular dispositivo",
          style: TextStyles.heading1,
        ),
        SizedBox(height: 12),
        Text(
          textAlign: TextAlign.center,
          "Se buscaran los dispositivos cercanos compatibles para conectar con la aplicación.",
          style: TextStyles.normalText,
        ),
        SizedBox(height: 12),
        TextButton.icon(
          onPressed: _nextStep,
          label: Text("Continuar"),
          icon: Icon(Icons.chevron_right),
          iconAlignment: IconAlignment.end,
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      key: ValueKey(1),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          'lib/assets/onboarding_success.png',
          width: 250,
        ),
        SizedBox(height: 12),
        Text(
          "Dispositivo encontrado",
          style: TextStyles.heading1,
        ),
        SizedBox(height: 12),
        Text.rich(
          TextSpan(
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
          style: TextStyles.normalText,
        ),
        SizedBox(height: 12),
        TextButton.icon(
          onPressed: _nextStep,
          label: Text("Conectar"),
          icon: Icon(Icons.chevron_right),
          iconAlignment: IconAlignment.end,
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      key: ValueKey(2),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Image.asset(
        //   'lib/assets/onboarding_biometric.png',
        //   width: 250,
        // ),
        SizedBox(height: 12),
        Text(
          textAlign: TextAlign.center,
          "Ingresa las credenciales WI-FI",
          style: TextStyles.heading1,
        ),
        SizedBox(height: 12),
        Text(
          textAlign: TextAlign.center,
          "Será usado para autenticar con la cerradura, solo lo pediremos la primera vez.",
          style: TextStyles.normalText,
        ),
        SizedBox(height: 12),
        TextField(
          // style: TextStyles.normalText,
          keyboardType: TextInputType.name,
          autofocus: true,
          decoration: InputDecoration(
              label: Text(
                "SSID (Nombre)",
                style: TextStyles.normalText,
              ),
              border: OutlineInputBorder()),
        ),
        SizedBox(height: 12),

        TextField(
          //style: TextStyles.normalText,
          obscureText: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            label: Text("Password"),
          ),
        ),

        SizedBox(height: 12),

        TextButton.icon(
          onPressed: _nextStep,
          style: TextButton.styleFrom(
            textStyle: TextStyles.normalText,
            foregroundColor: Colors.white,
            backgroundColor: Colors.deepPurple, // Sets the text color
            padding: EdgeInsets.symmetric(
                horizontal: 16.0, vertical: 12.0), // Adjust padding if needed
          ),
          label: Text("Conectar"),
          icon: Icon(Icons.wifi_rounded),
          iconAlignment: IconAlignment.end,
        ),
      ],
    );
  }

  Widget _buildStep4() {
    return Column(
      key: ValueKey(3),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          'lib/assets/onboarding_biometric.png',
          width: 250,
        ),
        SizedBox(height: 12),
        Text(
          textAlign: TextAlign.center,
          "Habilitar acceso con biometria",
          style: TextStyles.heading1,
        ),
        SizedBox(height: 12),
        Text(
          textAlign: TextAlign.center,
          "Habilita el permiso necesario para acceder a la app de forma segura con Touch ID, Face ID o PIN.",
          style: TextStyles.normalText,
        ),
        SizedBox(height: 12),
        TextButton.icon(
          onPressed: _authenticate,
          label: Text("Habilitar acceso biometrico"),
          icon: Icon(Icons.chevron_right),
          iconAlignment: IconAlignment.end,
        ),
      ],
    );
  }
}
