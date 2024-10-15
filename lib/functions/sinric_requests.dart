import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smart_lock/home_page.dart';

void showApiKeyDeviceIdDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('API Key y/o Device ID no configurados'),
        content: Text(
          'Obtenlos desde la página de SinRic y pégalos en la pantalla de configuración',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Cierra el diálogo
            },
            child: Text('Ignorar'),
          ),
          TextButton(
            onPressed: () async {
              final Uri url = Uri.parse('https://sinric.pro');
              if (!await launchUrl(url)) {
                throw Exception('Could not launch');
              }
            },
            child: Text('Abrir SinRic'),
          ),
        ],
      );
    },
  );
}

Future<void> sendLockStateRequest(String command, BuildContext contexto) async {
  final prefs = await SharedPreferences.getInstance();
  final apiKey = prefs.getString('sinric_api_key') ?? '';
  final deviceId = prefs.getString('sinric_device_id') ?? '';

  if (apiKey.isEmpty || deviceId.isEmpty) {
    print('API Key or Device ID is not set.');
    showApiKeyDeviceIdDialog(contexto);

    return;
  }

  final url = Uri.parse('https://apple.sinric.pro/v1/shortcuts/actions');
  final headers = {
    'Content-Type': 'application/json',
  };
  final body = jsonEncode({
    'api_key': apiKey,
    'device_id': deviceId,
    'action': 'setLockState',
    'value': {'state': command},
  });

  try {
    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      print('Solicitud exitosa: ${response.body}');
    } else {
      print('Error en la solicitud: ${response.statusCode} ${response.body}');
      print(apiKey);
      print(deviceId);
    }
  } catch (e) {
    print('Excepción: $e');
  }
}
