import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for SystemChannels
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smart_lock/theme/font_styles.dart';

class SettingsPage extends StatefulWidget {
  SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.secondary,
        title: Text("Settings", style: TextStyles.normalText),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.chevron_left),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Registrar tarjeta',
              style: TextStyles.heading1,
              //textAlign: TextAlign.start,
            ),
            Text(
              'Escribe el nombre que será asignado a la tarjeta, luego presiona el boton de confirmar',
              style: TextStyles.normalText,
            ),
            SizedBox(
              height: 12,
            ),
            TextField(
              keyboardType: TextInputType.name,
              //autofocus: true,
              decoration: InputDecoration(
                  label: Text('Nombre de la tarjeta',
                      style: TextStyles.normalText),
                  border: OutlineInputBorder()),
            ),
            SizedBox(height: 12),
            Container(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {},
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.deepPurple, // Sets the text color
                  padding: EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0), // Adjust padding if needed
                ),
                label: Text("Añadir tarjeta", style: TextStyles.normalText),
                icon: Icon(Icons.contactless_rounded),
                iconAlignment: IconAlignment.end,
              ),
            ),
            SizedBox(
              height: 24,
            ),
            Text(
              'Tarjetas registradas',
              style: TextStyles.heading1,
            )
          ],
        ),
      ),
    );
  }
}
