import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class TripTimelineScreen extends StatelessWidget {
  final String tripKey;
  const TripTimelineScreen({super.key, required this.tripKey});

  IconData _modeIcon(String mode) {
    switch (mode) {
      case 'walk':
        return Icons.directions_walk;
      case 'bike':
        return Icons.directions_bike;
      case 'car':
        return Icons.directions_car;
      case 'bus':
        return Icons.directions_bus;
      case 'train':
        return Icons.train;
      default:
        return Icons.question_mark;
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = StorageService.getTrip(tripKey);
    if (trip == null) {
      return const Scaffold(
        body: Center(child: Text("Trip data not found")),
      );
    }

    final segs = (trip['segments'] as List? ?? []);

    return Scaffold(
      appBar: AppBar(title: const Text("Trip Timeline")),
      body: ListView.separated(
        itemCount: segs.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (ctx, i) {
          final seg = segs[i];
          final start = DateTime.tryParse(seg['startTime'] ?? '')?.toLocal() ??
              DateTime.now();
          final end =
              DateTime.tryParse(seg['endTime'] ?? '')?.toLocal() ?? start;
          final mode = seg['mode'] ?? 'unknown';
          final duration = end.difference(start);

          return ListTile(
            leading: Icon(_modeIcon(mode), color: Colors.indigo),
            title: Text("Mode: $mode"),
            subtitle: Text(
              "${start.hour}:${start.minute.toString().padLeft(2, '0')} → "
              "${end.hour}:${end.minute.toString().padLeft(2, '0')} "
              "(${duration.inMinutes} min)",
            ),
          );
        },
      ),
    );
  }
}
