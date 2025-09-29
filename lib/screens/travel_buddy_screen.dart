import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/bluetooth_service.dart';
import '../widgets/buddy_tile.dart';

class TravelBuddyScreen extends StatefulWidget {
  const TravelBuddyScreen({super.key});
  @override
  State<TravelBuddyScreen> createState() => _TravelBuddyScreenState();
}

class _TravelBuddyScreenState extends State<TravelBuddyScreen> {
  // This map now stores the latest data for each unique buddy
  Map<String, Map<String, dynamic>> _buddies = {};
  StreamSubscription? _scanSubscription;
  Timer? _cleanupTimer;

  @override
  void initState() {
    super.initState();
    final bt = Provider.of<BluetoothService>(context, listen: false);

    bt.startPeriodicScan();

    _scanSubscription = bt.stream.listen((results) {
      if (!mounted) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      bool listChanged = false;

      // A temporary set to track unique IDs seen in this scan batch
      final seenIds = <String>{};

      for (var r in results) {
        final decryptedData = bt.decryptScanResult(r);
        if (decryptedData != null && decryptedData.containsKey('name')) {
          final deviceId = decryptedData['uuid'];
          seenIds.add(deviceId);

          // Update or add the buddy's data
          _buddies[deviceId] = {
            'id': deviceId,
            'name': decryptedData['name'],
            'rssi': r.rssi,
            'ts': now,
          };
        }
      }

      // Cleanup old buddies that are no longer in range
      final initialBuddyCount = _buddies.length;
      _buddies.removeWhere((key, value) => (now - value['ts']) > 30000); // 30-second timeout

      if (seenIds.isNotEmpty || _buddies.length != initialBuddyCount) {
        // Only update the state if the list of buddies has actually changed
        setState(() {});
      }
    });

    // A separate timer to ensure the list is cleaned even if no new devices are found
    _cleanupTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!mounted) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      final originalCount = _buddies.length;
      _buddies.removeWhere((key, value) => (now - value['ts']) > 30000);

      if (_buddies.length != originalCount) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _cleanupTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buddyList = _buddies.values.toList();
    // Sort by strongest signal (closest)
    buddyList.sort((a, b) => b['rssi'].compareTo(a['rssi']));

    return Scaffold(
      appBar: AppBar(title: const Text('Nearby Travelers')),
      body: buddyList.isEmpty
          ? const Center(
              child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 60, color: Colors.grey),
                SizedBox(height: 16),
                Text("Searching for nearby travel buddies..."),
              ],
            ))
          : ListView.separated(
              itemCount: buddyList.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final b = buddyList[i];
                return BuddyTile(name: b['name'], id: b['id'], rssi: b['rssi']);
              }),
    );
  }
}