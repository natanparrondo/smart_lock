import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiDialog extends StatefulWidget {
  const ApiDialog({super.key});

  @override
  _ApiDialogState createState() => _ApiDialogState();
}

class _ApiDialogState extends State<ApiDialog> {
  final TextEditingController _apiKeyController =
      TextEditingController(text: '5647741b-579b-4a52-ab2c-5d6252d3c4c3');
  final TextEditingController _deviceIdController =
      TextEditingController(text: '66ace703674e208e6f045258');

  @override
  void dispose() {
    _apiKeyController.dispose();
    _deviceIdController.dispose();
    super.dispose();
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sinric_api_key', _apiKeyController.text);
    await prefs.setString('sinric_device_id', _deviceIdController.text);
    Navigator.of(context).pop(); // Close the dialog
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter API Key and Device ID'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _apiKeyController,
            decoration: const InputDecoration(labelText: 'Sinric API Key'),
          ),
          TextField(
            controller: _deviceIdController,
            decoration: const InputDecoration(labelText: 'Sinric Device ID'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(); // Close the dialog without saving
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _savePreferences,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
