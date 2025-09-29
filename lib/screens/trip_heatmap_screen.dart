import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/storage_service.dart';

class TripHeatmapScreen extends StatelessWidget {
  const TripHeatmapScreen({super.key});

  Map<String, dynamic> _decodeTrip(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String) {
      try {
        return Map<String, dynamic>.from(jsonDecode(raw));
      } catch (_) {
        debugPrint("⚠️ Ignored non-JSON string in Hive: $raw");
        return {};
      }
    }
    return {};
  }

  @override
  Widget build(BuildContext context) {
    final rawTrips = StorageService.box.values.toList();
    final List<LatLng> allPoints = [];

    // Collect GPS points safely
    for (var raw in rawTrips) {
      final trip = _decodeTrip(raw);
      final segments = (trip['segments'] as List? ?? []);
      for (var seg in segments) {
        final gpsList = (seg['gps'] as List? ?? []);
        for (var p in gpsList) {
          try {
            allPoints.add(LatLng(
              (p['lat'] as num).toDouble(),
              (p['lng'] as num).toDouble(),
            ));
          } catch (_) {}
        }
      }
    }

    if (allPoints.isEmpty) {
      return const Scaffold(
        body: Center(child: Text("No trips yet")),
      );
    }

    // --- Create heatmap grid ---
    final Map<String, int> heatGrid = {};
    const precision = 1000; // 0.001 degrees ~100m
    for (var p in allPoints) {
      final latKey = (p.latitude * precision).round();
      final lngKey = (p.longitude * precision).round();
      final key = '$latKey,$lngKey';
      heatGrid[key] = (heatGrid[key] ?? 0) + 1;
    }

    // Determine max frequency for normalization
    final maxFreq = heatGrid.values.isNotEmpty ? heatGrid.values.reduce(max) : 1;

    // Build circles with gradient opacity
    final circles = <Circle>{};
    int idx = 0;
    const maxCircles = 500; // cap for performance
    heatGrid.forEach((key, freq) {
      if (idx >= maxCircles) return;
      final parts = key.split(',');
      final lat = double.parse(parts[0]) / precision;
      final lng = double.parse(parts[1]) / precision;

      final opacity = (freq / maxFreq).clamp(0.1, 0.6); // stronger density = darker
      final radius = 30 + (freq.toDouble() * 3); // scale radius slightly

      circles.add(Circle(
        circleId: CircleId('c_$idx'),
        center: LatLng(lat, lng),
        radius: radius,
        fillColor: Colors.red.withOpacity(opacity),
        strokeWidth: 0,
      ));
      idx++;
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Frequent Routes Heatmap')),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: allPoints.first,
          zoom: 13,
        ),
        circles: circles,
        myLocationButtonEnabled: true,
        myLocationEnabled: true,
        zoomControlsEnabled: true,
      ),
    );
  }
}
