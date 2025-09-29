import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:geocoding/geocoding.dart';
import '../services/storage_service.dart';

class TripAnalyticsScreen extends StatefulWidget {
  const TripAnalyticsScreen({super.key});

  @override
  State<TripAnalyticsScreen> createState() => _TripAnalyticsScreenState();
}

class _TripAnalyticsScreenState extends State<TripAnalyticsScreen> {
  Map<String, int> odCounts = {};
  final Map<String, String> _geocodeCache = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _processTrips();
  }

  Future<String> _getPlaceLabel(double lat, double lng) async {
    final key = "${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}";
    if (_geocodeCache.containsKey(key)) return _geocodeCache[key]!;

    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final label =
            "${p.locality ?? p.subAdministrativeArea ?? p.administrativeArea ?? lat.toStringAsFixed(2)},${p.country ?? lng.toStringAsFixed(2)}";
        _geocodeCache[key] = label;
        return label;
      }
    } catch (e) {
      debugPrint("Geocoding failed for $lat,$lng → $e");
    }
    final fallback = "${lat.toStringAsFixed(2)},${lng.toStringAsFixed(2)}";
    _geocodeCache[key] = fallback;
    return fallback;
  }

  Future<void> _processTrips() async {
    final tripsRaw = StorageService.box.values.toList();
    if (tripsRaw.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    final counts = <String, int>{};

    // Process trips concurrently
    await Future.wait(tripsRaw.map((raw) async {
      Map<String, dynamic> t;
      if (raw is String) {
        try {
          t = Map<String, dynamic>.from(jsonDecode(raw));
        } catch (_) {
          return;
        }
      } else if (raw is Map) {
        t = Map<String, dynamic>.from(raw);
      } else {
        return;
      }

      final segs = (t['segments'] as List? ?? []);
      if (segs.isEmpty) return;

      final originGps = segs.first['gps'].first;
      final destGps = segs.last['gps'].last;

      final originLabel =
          await _getPlaceLabel(originGps['lat'], originGps['lng']);
      final destLabel =
          await _getPlaceLabel(destGps['lat'], destGps['lng']);

      final pair = "$originLabel → $destLabel";
      counts[pair] = (counts[pair] ?? 0) + 1;
    }));

    if (!mounted) return;
    setState(() {
      odCounts = counts;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = odCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalTrips = odCounts.values.fold<int>(0, (sum, v) => sum + v);

    return Scaffold(
      appBar: AppBar(title: const Text('Trip Analytics')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : items.isEmpty
                ? const Center(child: Text("No trips yet"))
                : Column(
                    children: [
                      Expanded(
                        child: ListView(
                          children: items
                              .map(
                                (e) => ListTile(
                                  title: Text(e.key),
                                  trailing: Text(
                                      "x${e.value} (${(e.value / totalTrips * 100).toStringAsFixed(1)}%)"),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const Divider(),
                      SizedBox(
                        height: 220,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: items.length * 60.0,
                            child: BarChart(
                              BarChartData(
                                barGroups: [
                                  for (int i = 0; i < items.length; i++)
                                    BarChartGroupData(
                                      x: i,
                                      barRods: [
                                        BarChartRodData(
                                          toY: items[i].value.toDouble(),
                                          color: Colors.indigo,
                                          width: 18,
                                        )
                                      ],
                                    )
                                ],
                                titlesData: FlTitlesData(
                                  show: true,
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        final idx = value.toInt();
                                        if (idx < 0 || idx >= items.length) return const SizedBox.shrink();
                                        final text = items[idx].key.split('→').last.trim();
                                        return SideTitleWidget(
                                          meta: meta,
                                          child: RotatedBox(
                                            quarterTurns: 1,
                                            child: Text(
                                              text,
                                              style: const TextStyle(fontSize: 10),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: true),
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
