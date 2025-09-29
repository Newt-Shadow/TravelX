// widgets/live_samples_card.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/accel_service.dart';
import '../services/gps_service.dart';

class LiveSamplesCard extends StatefulWidget {
  const LiveSamplesCard({super.key});
  @override
  State<LiveSamplesCard> createState() => _LiveSamplesCardState();
}

class _LiveSamplesCardState extends State<LiveSamplesCard> {
  double _lastAccel = 0.0;
  String _lastGps = 'No GPS yet';
  StreamSubscription? _accSub;
  StreamSubscription? _gpsSub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _accSub?.cancel();
    _gpsSub?.cancel();
    final accel = Provider.of<AccelService>(context);
    final gps = Provider.of<GpsService>(context);
    _accSub = accel.linearMagnitude.listen((v) {
      if (mounted) setState(() => _lastAccel = v);
    }, onError: (_) {});
    _gpsSub = gps.stream.listen((p) {
      if (mounted) {
        setState(() => _lastGps =
            '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}');
      }
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _accSub?.cancel();
    _gpsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Live Samples',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(children: [
              _miniGauge('Accel', _lastAccel),
              const SizedBox(width: 8),
              _miniGaugeText('GPS', _lastGps),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _miniGauge(String label, double value) {
    final display = value.toStringAsFixed(2);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10)),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // Allow column to shrink
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                      child: LinearProgressIndicator(
                          value: (value.clamp(0, 20) / 20), minHeight: 8)),
                  const SizedBox(width: 8),
                  Text(display,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ]),
      ),
    );
  }

  Widget _miniGaugeText(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10)),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // Allow column to shrink
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 6),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
      ),
    );
  }
}
