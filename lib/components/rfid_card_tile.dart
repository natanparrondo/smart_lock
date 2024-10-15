// lib/components/rfid_card_tile.dart
import 'package:flutter/material.dart';
import 'package:smart_lock/theme/font_styles.dart';

class RfidCardTile extends StatelessWidget {
  final String nickname;
  final String id;
  final VoidCallback onRemove; // Add a callback for the remove action

  const RfidCardTile({
    super.key,
    required this.nickname,
    required this.id,
    required this.onRemove, // Add the onRemove parameter
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
          vertical: 4), // 8 units of separation (4 top and 4 bottom)
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                nickname,
                style: TextStyles.normalTextBold,
              ),
              Text(
                ' • ID: $id',
                style: TextStyles.normalText,
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: onRemove, // Call the remove callback
          ),
        ],
      ),
    );
  }
}
