import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/trip.dart'; // Import the Trip model
import '../screens/trip_detail_screen.dart'; // Import the new detail screen
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import 'package:url_launcher/url_launcher.dart';

class PastTripsList extends StatefulWidget {
  const PastTripsList({super.key});
  @override
  State<PastTripsList> createState() => _PastTripsListState();
}

class _PastTripsListState extends State<PastTripsList> {
  List<Map<String, dynamic>> _processedTrips = [];

  @override
  void initState() {
    super.initState();
    _loadAndProcessTrips();
  }

  /// Loads all trip data from storage and prepares it for display.
  void _loadAndProcessTrips() {
    final box = StorageService.box;
    final keys = box.keys
        .cast<String>()
        .where((k) => k != 'anon_user_id' && k != 'transition_graph')
        .toList()
        .reversed
        .toList();

    // ✅ FIXED: Added a try-catch block inside the map to handle corrupted data for a single trip gracefully.
    _processedTrips = keys.map((key) {
      try {
        final raw = box.get(key);
        final trip = _decodeTrip(raw);
        trip['hive_key'] = key;
        return trip;
      } catch (e) {
        debugPrint("❌ Failed to process trip with key $key. Error: $e");
        return {'hive_key': key, 'error': true}; // Return an error object
      }
    }).toList();
  }

  /// Decodes trip data from Hive, handling both Map and JSON String formats.
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

  void _refreshList() {
    setState(() {
      _loadAndProcessTrips();
    });
  }
  
  String _getGoogleTravelMode(String mode) {
    final m = mode.toLowerCase();
    if (['car', 'taxi', 'driving', 'auto'].contains(m)) return 'driving';
    if (['walk', 'foot', 'running'].contains(m)) return 'walking';
    if (['bike', 'bicycle', 'cycling'].contains(m)) return 'bicycling';
    return 'driving';
  }

  /// ✅ FIXED: Generates a safe and correctly formatted Google Maps URL.
  Future<void> _openGoogleMapsRoute(List<dynamic> gpsPoints, String mode) async {
    if (gpsPoints.isEmpty) return;

    final travelMode = _getGoogleTravelMode(mode);
    final start = gpsPoints.first;
    final end = gpsPoints.last;

    List<dynamic> waypoints = [];
    if (gpsPoints.length > 25) {
      final step = (gpsPoints.length / 23).ceil();
      for (var i = step; i < gpsPoints.length - 1; i += step) {
        waypoints.add(gpsPoints[i]);
      }
    } else if (gpsPoints.length > 2){
      waypoints = gpsPoints.sublist(1, gpsPoints.length - 1);
    }

    final originLat = (start['lat'] as num?)?.toDouble() ?? 0.0;
    final originLng = (start['lng'] as num?)?.toDouble() ?? 0.0;
    final destLat = (end['lat'] as num?)?.toDouble() ?? 0.0;
    final destLng = (end['lng'] as num?)?.toDouble() ?? 0.0;
    
    final waypointStr = waypoints
        .map((p) => '${(p['lat'] as num?)?.toDouble() ?? 0.0},${(p['lng'] as num?)?.toDouble() ?? 0.0}')
        .join('|');

    // Use the safe Uri.https constructor which handles URL encoding.
    final url = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'origin': '$originLat,$originLng',
      'destination': '$destLat,$destLng',
      if (waypointStr.isNotEmpty) 'waypoints': waypointStr,
      'travelmode': travelMode,
    });

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      debugPrint("❌ Exception launching Google Maps: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_processedTrips.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: const [
              Icon(Icons.history, size: 42, color: Colors.grey),
              SizedBox(height: 8),
              Text('No past trips stored.', style: TextStyle(color: Colors.black54)),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _processedTrips.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, idx) {
        final t = _processedTrips[idx];
        
        // ✅ FIXED: Handle the case where a trip failed to load and show an error card.
        if (t['error'] == true) {
          return Card(
            color: Colors.red[100],
            child: ListTile(
              leading: Icon(Icons.error_outline, color: Colors.red),
              title: Text('Error Loading Trip'),
              subtitle: Text('This trip data could not be read.'),
            ),
          );
        }

        final key = t['hive_key'] as String;
        final segs = (t['segments'] as List? ?? []);
        if (segs.isEmpty) return const SizedBox.shrink();

        final firstSeg = segs.first;
        final start = DateTime.tryParse(firstSeg['start'] ?? '')?.toLocal() ?? DateTime.now();
        final end = DateTime.tryParse(segs.last['end'] ?? '')?.toLocal() ?? start;
        final mode = firstSeg['mode'] ?? 'unknown';
        final uploaded = t['uploaded'] == true;

        final duration = end.difference(start);
        final hours = duration.inHours;
        final minutes = duration.inMinutes % 60;

        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              // This is now safe because Trip.fromJson is robust.
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TripDetailScreen(trip: Trip.fromJson(t)),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${start.hour}:${start.minute.toString().padLeft(2, '0')} → ${end.hour}:${end.minute.toString().padLeft(2, '0')}",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text("Mode: $mode, Duration: ${hours}h ${minutes}m"),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(uploaded ? Icons.cloud_done : Icons.cloud_upload,
                                color: uploaded ? Colors.green : Colors.orange, size: 16),
                            const SizedBox(width: 4),
                            Text(uploaded ? 'Synced' : 'Pending Sync',
                                style: TextStyle(color: uploaded ? Colors.green : Colors.orange, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'sync') {
                        await SyncService.instance.enqueueAndSync(key);
                        _refreshList();
                      } else if (value == 'delete') {
                         await StorageService.deleteTrip(key);
                         _refreshList();
                      } else if (value == 'maps') {
                        final gpsPoints = segs.expand((seg) => seg['gps'] as List<dynamic>? ?? []).toList();
                        _openGoogleMapsRoute(gpsPoints, mode);
                      }
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(value: 'sync', child: Text('Sync Now')),
                      const PopupMenuItem<String>(value: 'maps', child: Text('Open in Maps')),
                      const PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

