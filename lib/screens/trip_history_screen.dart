import 'dart:convert';
import 'dart:io'; // for SocketException
import 'dart:async'; // for TimeoutException
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'package:http/http.dart' as http;

import '../services/storage_service.dart';
import '../services/sync_service.dart';

class ApiConfig {
  static const String API_BASE_URL = 'http://http://34.55.89.158:5000/api';
}

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  List<Map<String, dynamic>> _allTrips = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAllTrips();
  }

  Future<void> _loadAllTrips() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // ✅ Load local trips immediately
      final pending = _loadPendingTrips();
      _mergeTrips(pending);

      // ✅ Fetch backend trips in background
      unawaited(_fetchPastTrips());
    } catch (e) {
      debugPrint("❗ Error in _loadAllTrips: $e");
      if (mounted) {
        setState(() => _error = "Error loading trips: $e");
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> _loadPendingTrips() {
    final box = StorageService.box;
    final keys = box.keys.where(
      (k) => k != 'anon_user_id' && k != 'transition_graph',
    );

    final pending =
        keys
            .map((key) {
              final raw = box.get(key);
              final t = _decodeTrip(raw);
              if (t.isNotEmpty) {
                t['_isUploaded'] = false;
              }
              return t.isNotEmpty ? t : null;
            })
            .whereType<Map<String, dynamic>>()
            .toList();

    return pending;
  }

  Future<void> _fetchPastTrips() async {
    // final anonUserId = await StorageService.getOrCreateAnonUserId();
    final userId = AuthService.currentUserId;
    if (userId == null) {
      debugPrint("⛔ User not logged in. Cannot fetch past trips.");
      if (mounted) {
        setState(() {
          // Clear any old server trips and show an error/message
          _allTrips.removeWhere((trip) => trip['_isUploaded'] == true);
          _error = "Please sign in to view your trip history.";
          _isLoading = false;
        });
      }
      return;
    }
    final url = Uri.parse('${ApiConfig.API_BASE_URL}/trips/$userId');
    debugPrint("🔗 Fetching trips from: $url");

    try {
      final response = await http
          .get(url, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 8));

           debugPrint("⬅️ [Trip History] Received response with status code: ${response.statusCode}");

      if (response.statusCode == 200) {
        debugPrint("✅ [Trip History] Successfully received trip data.");
        final List<dynamic> data = jsonDecode(response.body);
        debugPrint("📦 [Trip History] Found ${data.length} trips in the response from the server.");

        final past =
            data.map((t) {
              final m = Map<String, dynamic>.from(t);
              m['_isUploaded'] = true;
              return m;
            }).toList();

        if (mounted) {
          final pendingTrips =
              _allTrips.where((t) => t['_isUploaded'] == false).toList();
          _mergeTrips([...pendingTrips, ...past]);
        }
        debugPrint("✅ [Trip History] Merged ${past.length} server trips with local trips.");


        // _mergeTrips(past);
        debugPrint(
          "✅ Loaded ${past.length} trips from backend for user $userId.",
        );
      } else {
        debugPrint("❌ Backend error ${response.statusCode}: ${response.body}");
      }
    } on SocketException {
      debugPrint("🌐 No backend connection.");
    } on TimeoutException {
      debugPrint("⏱ Backend request timed out.");
    } catch (e) {
      debugPrint("❗ Unexpected error fetching trips: $e");
    }
  }

  void _mergeTrips(List<Map<String, dynamic>> newTrips) {
    if (!mounted) return;

    // final merged = [..._allTrips, ...newTrips];
    final tripMap = <String, Map<String, dynamic>>{};

    // Add existing trips first
    for (final trip in _allTrips) {
      tripMap[trip['id'] ?? trip['tripClientId']] = trip;
    }
    // Add new trips, overwriting duplicates
    for (final trip in newTrips) {
      tripMap[trip['id'] ?? trip['tripClientId']] = trip;
    }

    final merged = tripMap.values.toList();

    // Sort all trips by startTime (newest first)
    merged.sort((a, b) {
      final aStart =
          DateTime.tryParse(
            (a['startTime'] ?? a['segments']?[0]?['start'] ?? '').toString(),
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bStart =
          DateTime.tryParse(
            (b['startTime'] ?? b['segments']?[0]?['start'] ?? '').toString(),
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bStart.compareTo(aStart);
    });

    if (mounted) {
      setState(() {
        _allTrips = merged;
      });
    }

    // setState(() {
    //   _allTrips = merged;
    // });
  }

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
    if (_isLoading && _allTrips.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _allTrips.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }

    if (_allTrips.isEmpty) {
      return const Center(child: Text("No trips found."));
    }

    return RefreshIndicator(
      onRefresh: _loadAllTrips,
     child: ListView.builder(
      itemCount: _allTrips.length,
      itemBuilder: (context, index) {
        final trip = _allTrips[index];
        final isUploaded = trip['_isUploaded'] == true;

        return isUploaded
            ? _buildPastTripCard(trip)
            : _buildPendingTripCard(trip);
      },
     ),
    );
  }

  Widget _buildPendingTripCard(Map<String, dynamic> t) {
    final segs = (t['segments'] as List? ?? []);
    if (segs.isEmpty) return const SizedBox.shrink();

    final firstSeg = segs.first;
    final start =
        DateTime.tryParse(firstSeg['start'] ?? '')?.toLocal() ?? DateTime.now();
    final end = DateTime.tryParse(firstSeg['end'] ?? '')?.toLocal() ?? start;
    final mode = firstSeg['mode'] ?? 'unknown';

    final gpsPoints =
        segs.expand((seg) => seg['gps'] as List<dynamic>? ?? []).toList();
    if (gpsPoints.isEmpty) return const SizedBox.shrink();

    final latLngPoints =
        gpsPoints
            .map((p) => LatLng(p['lat'] as double, p['lng'] as double))
            .toList();

    final duration = end.difference(start);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    return _buildTripCard(
      startTime: start,
      endTime: end,
      mode: mode,
      points: latLngPoints,
      rawGpsPoints: gpsPoints,
      durationText: "${hours}h ${minutes}m",
      subtitle: "Segments: ${segs.length}, Points: ${gpsPoints.length}",
      isUploaded: false,
    );
  }

  Widget _buildPastTripCard(Map<String, dynamic> trip) {
    final start =
        DateTime.tryParse(trip['startTime'] ?? '')?.toLocal() ?? DateTime.now();
    final end = DateTime.tryParse(trip['endTime'] ?? '')?.toLocal() ?? start;
    final mode = trip['mode'] as String? ?? 'unknown';
    final durationSecs = trip['duration'] as int? ?? 0;
    final distanceMeters = (trip['distance'] as num?)?.toDouble() ?? 0.0;
    final path = (trip['path'] as List? ?? []);
    if (path.isEmpty) return const SizedBox.shrink();

    final latLngPoints =
        path
            .map((p) => LatLng(p['lat'] as double, p['lng'] as double))
            .toList();

    final hours = durationSecs ~/ 3600;
    final minutes = (durationSecs % 3600) ~/ 60;
    final distanceKm = (distanceMeters / 1000).toStringAsFixed(2);

    return _buildTripCard(
      startTime: start,
      endTime: end,
      mode: mode,
      points: latLngPoints,
      rawGpsPoints: path.cast<Map<String, dynamic>>(),
      durationText: "${hours}h ${minutes}m",
      subtitle: "Distance: $distanceKm km",
      isUploaded: true,
    );
  }

  Widget _buildTripCard({
    required DateTime startTime,
    required DateTime endTime,
    required String mode,
    required List<LatLng> points,
    required List<dynamic> rawGpsPoints,
    required String durationText,
    required String subtitle,
    required bool isUploaded,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ExpansionTile(
        title: Text(
          "${startTime.hour}:${startTime.minute.toString().padLeft(2, '0')} → ${endTime.hour}:${endTime.minute.toString().padLeft(2, '0')}",
        ),
        subtitle: Text("Mode: $mode\n$subtitle, Duration: $durationText"),
        trailing: Icon(
          isUploaded ? Icons.cloud_done : Icons.cloud_upload,
          color: isUploaded ? Colors.green : Colors.orange,
        ),
        children: [
          Column(
            children: [
              SizedBox(
                height: 200,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: points.first,
                    initialZoom: 13,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: points,
                          color: Colors.blue,
                          strokeWidth: 4,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: points.first,
                          width: 16,
                          height: 16,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.green,
                            size: 16,
                          ),
                        ),
                        Marker(
                          point: points.last,
                          width: 16,
                          height: 16,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ButtonBar(
                alignment: MainAxisAlignment.start,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _openGoogleMapsRoute(rawGpsPoints, mode),
                    icon: const Icon(Icons.map),
                    label: const Text('Open in Maps'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getGoogleTravelMode(String mode) {
    final m = mode.toLowerCase();
    if (['car', 'taxi', 'driving', 'auto'].contains(m)) return 'driving';
    if (['walk', 'foot', 'running'].contains(m)) return 'walking';
    if (['bike', 'bicycle', 'cycling'].contains(m)) return 'bicycling';
    return 'driving';
  }

  Future<void> _openGoogleMapsRoute(
    List<dynamic> gpsPoints,
    String mode,
  ) async {
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
    } else {
      waypoints = gpsPoints.sublist(1, gpsPoints.length - 1);
    }

    final originLat = start['lat'];
    final originLng = start['lng'];
    final destLat = end['lat'];
    final destLng = end['lng'];
    final waypointStr = waypoints
        .map((p) => '${p['lat']},${p['lng']}')
        .join('|');

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
}
