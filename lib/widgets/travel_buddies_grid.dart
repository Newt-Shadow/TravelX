import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/bluetooth_service.dart';
import '../theme/app_theme.dart';

class TravelBuddiesGrid extends StatefulWidget {
  const TravelBuddiesGrid({super.key});

  @override
  State<TravelBuddiesGrid> createState() => _TravelBuddiesGridState();
}

class _TravelBuddiesGridState extends State<TravelBuddiesGrid> {
  int _buddyCount = 0;
  StreamSubscription? _scanSubscription;
  Timer? _cleanupTimer;
  final Map<String, int> _recentBuddies = {};

  @override
  void initState() {
    super.initState();
    final bt = Provider.of<BluetoothService>(context, listen: false);

    _scanSubscription = bt.stream.listen((results) {
      if (!mounted) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      for (var r in results) {
        final decryptedData = bt.decryptScanResult(r);
        if (decryptedData != null) {
          // Use the remoteId as the unique key to prevent duplicates
          _recentBuddies[decryptedData['uuid']] = now;
        }
      }
      _updateCount();
    });

    _cleanupTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _updateCount();
    });
  }

  void _updateCount() {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Remove buddies that haven't been seen in 30 seconds
    _recentBuddies.removeWhere((key, value) => (now - value) > 30000);
    // Only update the state if the count has actually changed
    if (_recentBuddies.length != _buddyCount) {
      setState(() {
        _buddyCount = _recentBuddies.length;
      });
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _cleanupTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.people_alt_outlined,
                    color: AppTheme.accentColor),
                const SizedBox(width: 12),
                Text(
                  "Nearby Companions",
                  style: AppTheme.textTheme.titleMedium?.copyWith(color: Colors.black),
                ),
              ],
            ),
            Text(
              _buddyCount.toString(),
              style: AppTheme.textTheme.headlineSmall
                  ?.copyWith(color: AppTheme.accentColor),
            ),
          ],
        ),
      ),
    );
  }
}