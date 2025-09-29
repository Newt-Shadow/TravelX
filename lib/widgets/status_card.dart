import 'package:flutter/material.dart';

class StatusCard extends StatelessWidget {
  final bool collecting;
  final String mode;

  const StatusCard({super.key, required this.collecting, required this.mode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIdle = !collecting;

    return Card(
      elevation: isIdle ? 2 : 0,
      color: isIdle ? Colors.teal : theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isIdle
            ? BorderSide.none
            : BorderSide(color: Colors.green.shade400, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Icon(
              isIdle ? Icons.play_circle_fill_rounded : Icons.pause_circle_filled_rounded,
              color: isIdle ? Colors.white : Colors.green.shade400,
              size: 40,
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STATUS',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isIdle ? Colors.white70 : theme.textTheme.bodySmall?.color,
                  ),
                ),
                if (collecting)
                  Text(
                    'Recording: $mode',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  )
                else
                  const Text(
                    'Tap to Start Recording',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  )
              ],
            )
          ],
        ),
      ),
    );
  }
}