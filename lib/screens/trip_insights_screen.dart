import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/storage_service.dart';
import 'dart:convert';

class TripInsightsScreen extends StatefulWidget {
  const TripInsightsScreen({super.key});

  @override
  State<TripInsightsScreen> createState() => _TripInsightsScreenState();
}

class _TripInsightsScreenState extends State<TripInsightsScreen> {
  String? _selectedMode;

  @override
  Widget build(BuildContext context) {
    final trips = StorageService.box.values.toList();
    final Map<String, int> modeCounts = {};

    for (var raw in trips) {
      Map<String, dynamic> t = {};
      if (raw is String) {
        try {
          t = Map<String, dynamic>.from(jsonDecode(raw));
        } catch (_) {}
      } else if (raw is Map) {
        t = Map<String, dynamic>.from(raw);
      }

      final segs = (t['segments'] as List? ?? []);
      for (var seg in segs) {
        final m = (seg['mode'] ?? 'unknown') as String;
        modeCounts[m] = (modeCounts[m] ?? 0) + 1;
      }
    }

    final total = modeCounts.values.fold<int>(0, (sum, v) => sum + v);
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.yellow.shade700,
      Colors.cyan,
      Colors.pink,
      Colors.brown,
    ];
    final items = modeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(title: const Text('Trip Insights')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: items.isEmpty
            ? const Center(child: Text('No trip data available.'))
            : Column(
                children: [
                  SizedBox(
                    height: 300,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 50,
                        borderData: FlBorderData(show: false),
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) {
                            if (response != null && response.touchedSection != null) {
                              final idx = response.touchedSection!.touchedSectionIndex;
                              setState(() {
                                _selectedMode = items[idx].key;
                              });
                            } else {
                              setState(() {
                                _selectedMode = null;
                              });
                            }
                          },
                        ),
                        sections: [
                          for (int i = 0; i < items.length; i++)
                            PieChartSectionData(
                              value: items[i].value.toDouble(),
                              title:
                                  '${items[i].key} ${(items[i].value / total * 100).toStringAsFixed(1)}%',
                              color: colors[i % colors.length],
                              radius: (_selectedMode == null || _selectedMode == items[i].key) ? 70 : 50,
                              titleStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _selectedMode != null
                      ? Card(
                          color: Colors.grey.shade200,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Text(
                              '$_selectedMode: ${modeCounts[_selectedMode]!} segments (${(modeCounts[_selectedMode]! / total * 100).toStringAsFixed(1)}%)',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (_, index) {
                        final item = items[index];
                        final percent = (item.value / total * 100).toStringAsFixed(1);
                        final isSelected = _selectedMode == null || _selectedMode == item.key;
                        return Opacity(
                          opacity: isSelected ? 1.0 : 0.4,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: colors[index % colors.length],
                            ),
                            title: Text('${item.key}'),
                            trailing: Text('$percent%'),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
