import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_lock/home_page.dart';
import 'package:smart_lock/onboarding_page.dart';
import 'package:smart_lock/settings_page.dart';
import 'package:smart_lock/theme/theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<bool> _getAppBeenSetup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('appBeenSetup') ?? false;
    } catch (e) {
      print("Error getting appBeenSetup: $e");
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: lightMode,
      darkTheme: darkMode,
      home: FutureBuilder<bool>(
        future: _getAppBeenSetup(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          } else if (snapshot.hasError) {
            return const Scaffold(
              body: Center(child: Text('Error al cargar estado')),
            );
          } else if (snapshot.hasData) {
            return snapshot.data! ? HomePage() : OnboardingPage();
          } else {
            return OnboardingPage();
          }
        },
      ),
      routes: {
        '/settings': (context) => SettingsPage(),
      },
    );
  }
}
