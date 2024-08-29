import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_lock/onboarding_page.dart';

Future<void> sendLockStateRequest(String command) async {
  final prefs = await SharedPreferences.getInstance();
  final apiKey = prefs.getString('sinric_api_key') ?? '';
  final deviceId = prefs.getString('sinric_device_id') ?? '';

  if (apiKey.isEmpty || deviceId.isEmpty) {
    print('API Key or Device ID is not set.');
    //snackbar con ese mensaje
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
