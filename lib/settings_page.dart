import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_lock/functions/api_dialog.dart';
import 'package:smart_lock/theme/font_styles.dart';
import 'package:smart_lock/components/rfid_card_tile.dart'; // Import the RfidCardTile component

class SettingsPage extends StatefulWidget {
  SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  List<Map<String, String>> cardList = [];
  final TextEditingController _cardNameController = TextEditingController();
  final FocusNode _textFieldFocusNode = FocusNode();
  String receivedCardId = '';

  @override
  void initState() {
    super.initState();
    _loadCardList();
  }

  void _showApiDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ApiDialog();
      },
    );
  }

  Future<void> _loadCardList() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? storedCardList = prefs.getStringList('cardList');

    if (storedCardList != null) {
      setState(() {
        cardList = storedCardList.map((card) {
          List<String> parts = card.split(':');
          return {'nickname': parts[0], 'id': parts[1]};
        }).toList();
      });
    }
  }

  Future<void> _addCard(String nickname, String id) async {
    setState(() {
      cardList.add({'nickname': nickname, 'id': id});
    });
    await _saveCardList();
  }

  Future<void> _removeCard(int index) async {
    setState(() {
      cardList.removeAt(index);
    });
    await _saveCardList();
  }

  Future<void> _saveCardList() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> storedCardList =
        cardList.map((card) => '${card['nickname']}:${card['id']}').toList();
    await prefs.setStringList('cardList', storedCardList);
  }

  Future<void> _showAddCardDialog() async {
    showDialog(
      context: context,
      barrierDismissible:
          false, // Prevents dismissing the dialog by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Nueva tarjeta', style: TextStyles.heading1),
          content: Text(
            'Acerca la tarjeta al lector de la cerradura',
            style: TextStyles.normalText,
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancelar', style: TextStyles.normalText),
              onPressed: () {
                setState(() {
                  receivedCardId = ''; // Reset received card ID
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );

    // Simulate waiting for the card to be scanned and the ID to be received
    await Future.delayed(Duration(seconds: 5)); // Simulated delay

    // Simulated received card ID
    setState(() {
      receivedCardId = 'test'; // Simulated received card ID
    });

    if (receivedCardId.isNotEmpty) {
      String cardName = _cardNameController.text.trim();
      if (cardName.isNotEmpty) {
        await _addCard(cardName, receivedCardId);
        _cardNameController.clear();
        Navigator.of(context).pop(); // Close the dialog
      }
    }
  }

  @override
  void dispose() {
    _cardNameController.dispose(); // Dispose the TextEditingController
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.secondary,
        title: Text("Settings", style: TextStyles.heading1),
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
            ),
            Text(
              'Escribe el nombre que será asignado a la tarjeta, luego presiona el boton de confirmar',
              style: TextStyles.normalText,
            ),
            SizedBox(height: 12),
            TextField(
              controller: _cardNameController,
              focusNode: _textFieldFocusNode,
              keyboardType: TextInputType.name,
              decoration: InputDecoration(
                label:
                    Text('Nombre de la tarjeta', style: TextStyles.normalText),
                border: OutlineInputBorder(),
              ),
              onChanged: (text) {
                print("TextField changed: $text"); // Debug print
              },
            ),
            SizedBox(height: 12),
            Container(
              width: double.infinity,
              child: TextButton.icon(
                onPressed:
                    _showAddCardDialog, // Show the dialog on button press
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.deepPurple, // Sets the text color
                  padding: EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0), // Adjust padding if needed
                ),
                label: Text("Añadir tarjeta", style: TextStyles.normalText),
                icon: Icon(Icons.contactless_outlined),
                iconAlignment: IconAlignment.end,
              ),
            ),
            SizedBox(height: 12),
            Container(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  _showApiDialog(context);
                }, // Show the dialog on button press
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.deepPurple, // Sets the text color
                  padding: EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0), // Adjust padding if needed
                ),
                label: Text("Cambiar credenciales Sinric",
                    style: TextStyles.normalText),
                icon: Icon(Icons.account_box_rounded),
                iconAlignment: IconAlignment.end,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Tarjetas registradas',
              style: TextStyles.heading1,
            ),
            Expanded(
              child: ListView.builder(
                itemCount: cardList.length,
                itemBuilder: (context, index) {
                  return RfidCardTile(
                    nickname: cardList[index]['nickname']!,
                    id: cardList[index]['id']!,
                    onRemove: () =>
                        _removeCard(index), // Pass the remove callback
                  );
                },
              ),
            ),
            Container(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {}, // Define the reset action
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.red, // Sets the text color
                  padding: EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0), // Adjust padding if needed
                ),
                label: Text("RESET", style: TextStyles.normalText),
                icon: Icon(Icons.close),
                iconAlignment: IconAlignment.end,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
