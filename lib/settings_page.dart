import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_lock/functions/api_dialog.dart';
import 'package:smart_lock/home_page.dart';
import 'package:smart_lock/onboarding_page.dart';
import 'package:smart_lock/theme/font_styles.dart';

class SettingsPage extends StatefulWidget {
  final BluetoothCharacteristic?
      statusCharacteristic; // Aquí se pasa la característica Bluetooth

  SettingsPage({Key? key, required this.statusCharacteristic})
      : super(key: key);

  @override
  State<SettingsPage> createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
  }

  Key key = UniqueKey(); // Usamos UniqueKey para forzar la reconstrucción

  Future<void> sendResetCommand() async {
    try {
      // El comando "reset" que enviarás
      List<int> resetCommand = utf8.encode("reset");

      // Escribe el comando a la característica

      await widget.statusCharacteristic!
          .write(resetCommand, withoutResponse: false);

      // Confirmación visual de que se envió el comando
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Comando "reset" enviado.'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Se reseteó el dispoitivo de fábrica.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showApiDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ApiDialog();
      },
    );
  }

  Future<void> clearAllPreferences() async {
    SharedPreferences.getInstance().then((prefs) {
      prefs.clear();
    });
    // Confirmación visual
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Preferencias borradas. Reiniciando...'),
        duration: const Duration(seconds: 1),
      ),
    );

    // Espera un poco antes de reiniciar para que el SnackBar se muestre
    await Future.delayed(const Duration(seconds: 2));
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.secondary,
        title: Text("Settings", style: TextStyles.heading1(context)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sincronización IoT',
              style: TextStyles.heading1(context),
            ),
            Text(
                'Configura una cuenta en SinRic y añade las credenciales para configurar el dispositivo para usar con apps de control de hogar inteligente.',
                style: TextStyles.normalText(context)),
            const SizedBox(height: 12),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  _showApiDialog(context);
                },
                style: TextButton.styleFrom(
                  foregroundColor:
                      Colors.white, // Este es el color del texto del botón
                  backgroundColor:
                      Colors.deepPurple, // Color de fondo del botón
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0), // Ajusta el padding si es necesario
                ),
                label: Text(
                  "Cambiar credenciales Sinric",
                  style: TextStyle(
                    fontFamily: TextStyles.fontFamily,
                    color:
                        Colors.white, // Establecer el color del texto en blanco
                  ),
                ),
                icon: const Icon(Icons.account_box_rounded),
                iconAlignment: IconAlignment.end,
              ),
            ),
            const SizedBox(height: 24),
            Image.asset("lib/assets/iot_integrations.png"),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () async {
                  await sendResetCommand();
                  await clearAllPreferences();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            OnboardingPage()), // Reemplaza con tu página de inicio
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor:
                      Colors.white, // Este es el color del texto del botón
                  backgroundColor: Colors.red, // Color de fondo del botón
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0), // Ajusta el padding si es necesario
                ),
                label: Text(
                  "Olvidar y resetear dispositivo",
                  style: TextStyle(
                    fontFamily: TextStyles.fontFamily,
                    color:
                        Colors.white, // Establecer el color del texto en blanco
                  ),
                ),
                icon: const Icon(Icons.close),
                iconAlignment: IconAlignment.end,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
