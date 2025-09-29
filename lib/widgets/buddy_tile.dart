import 'dart:math';

import 'package:flutter/material.dart';

class BuddyTile extends StatelessWidget {
  final String name;
  final String id;
  final int rssi;

  const BuddyTile(
      {super.key, required this.name, required this.id, required this.rssi});

  @override
  Widget build(BuildContext context) {
    final initials = name.isNotEmpty ? name.split(' ').map((e) => e[0]).take(2).join() : "?";
    final distanceEst = _estimateDistance(rssi);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _colorFromName(name),
        child: Text(
          initials,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(name),
      subtitle: Text("Approx. ${(distanceEst / 10 ).toStringAsFixed(1)}m away"),
      trailing: Icon(Icons.people, color: Colors.indigo.shade400),
    );
  }

  Color _colorFromName(String name) {
    final hash = name.hashCode;
    final index = hash % Colors.primaries.length;
    return Colors.primaries[index][400]!;
  }

  double _estimateDistance(int rssi) {
    // Simple path loss approximation
    int txPower = -59;
    if (rssi == 0) return -1.0;
    double ratio = rssi * 1.0 / txPower;
    if (ratio < 1.0) {
      return pow(ratio, 10).toDouble();
    } else {
      double distance = (0.89976) * pow(ratio, 7.7095) + 0.111;
      return distance;
    }
  }
}
