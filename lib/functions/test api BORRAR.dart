import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

Future<String> getAuthToken() async {
  final url = Uri.parse('https://api.sinric.pro/api/v1/auth');
  final response = await http.post(url, headers: {
    'x-sinric-api-key':
        'ef190a0b-1086-427b-890d-366ea38cce31', // Reemplaza con tu API Key
    'Content-Type': 'application/x-www-form-urlencoded',
  }, body: {
    'client_id': 'android-app',
  });

  if (response.statusCode == 200) {
    try {
      final body = jsonDecode(response.body);
      if (body != null && body.containsKey('accessToken')) {
        return body['accessToken']; // Retorna el nuevo token
      } else {
        print('No access_token found in the response: ${response.body}');
        return ''; // Handle the case where access_token is missing
      }
    } catch (e) {
      print('Error decoding the response: $e');
      return ''; // Return empty string in case of a decoding error
    }
  } else {
    print('Error al obtener el token: ${response.statusCode} ${response.body}');
    return ''; // Retorna una cadena vacía en caso de error
  }
}

Future<void> monitorLockState(String accessToken) async {
  final String deviceId = '66ace703674e208e6f045258';
  final url = Uri.parse(
      'https://portal.sinric.pro/sse/stream?accessToken=$accessToken');

  try {
    final request = await HttpClient().getUrl(url);
    final response = await request.close();
    print('Conectado al stream SSE...');

    await for (var event in response.transform(utf8.decoder)) {
      print('Evento recibido: $event'); // Debug para eventos recibidos
      if (event.contains('"deviceMessageArrived"')) {
        final json = jsonDecode(event);
        if (json['device']['id'] == deviceId) {
          final state = json['device']['powerState'];
          bool _locked = state == 'locked';
          print('Estado del candado: $_locked');
        }
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}

void main() async {
  String accessToken = await getAuthToken();
  if (accessToken.isNotEmpty) {
    await monitorLockState(accessToken);
  } else {
    print('No se obtuvo un token válido.');
  }
}
