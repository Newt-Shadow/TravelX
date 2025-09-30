import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';

class ApiConfig {
  static const String API_BASE_URL = 'http://http://34.55.89.158:5000/api';
}

class LatestTripCard extends StatefulWidget {
  const LatestTripCard({super.key});

  @override
  State<LatestTripCard> createState() => _LatestTripCardState();
}

class _LatestTripCardState extends State<LatestTripCard> {
  // ✅ REMOVED 'late' and made the Future nullable by adding a '?'.
  Future<Map<String, dynamic>?>? _latestTripFuture;

  @override
  void initState() {
    super.initState();
    // The network call is still initiated only once.
    _latestTripFuture = _fetchLatestTrip();
  }

  Future<Map<String, dynamic>?> _fetchLatestTrip() async {
    final userId = AuthService.currentUserId;
    if (userId == null) {
      throw Exception("Please sign in to view your latest trip.");
    }

    final url = Uri.parse('${ApiConfig.API_BASE_URL}/trips/$userId?limit=1&sort=desc');
    try {
      final response = await http
          .get(url, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          return data.first;
        } else {
          return null;
        }
      } else {
        throw Exception("Error fetching trip: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Error: Could not connect to the server.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _latestTripFuture,
      builder: (context, snapshot) {
        // --- Loading State ---
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        // --- Error State ---
        if (snapshot.hasError) {
          return Card(
            color: Colors.red.shade100,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(child: Text(snapshot.error.toString().replaceAll("Exception: ", ""))),
            ),
          );
        }

        // --- No Data State ---
        final trip = snapshot.data;
        if (trip == null) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: Text("No trips available.")),
            ),
          );
        }

        // --- Success State ---
        return _buildTripCardContent(trip);
      },
    );
  }

  // This function remains unchanged.
  Widget _buildTripCardContent(Map<String, dynamic> trip) {
    final startTime =
        DateTime.tryParse(trip['startTime'] ?? '')?.toLocal() ?? DateTime.now();
    final endTime =
        DateTime.tryParse(trip['endTime'] ?? '')?.toLocal() ?? startTime;
    final distanceMeters = (trip['distance'] as num?)?.toDouble() ?? 0.0;
    final distanceKm = (distanceMeters / 1000).toStringAsFixed(2);
    final companions = trip['meta']?['companions'] as List?;
    final path = (trip['path'] as List? ?? []);

    final latLngPoints = path
        .map<latlong.LatLng>((p) =>
            latlong.LatLng(p['lat'] as double, p['lng'] as double))
        .toList();

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (latLngPoints.isNotEmpty)
            Expanded(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: latLngPoints[latLngPoints.length ~/ 2],
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
                        points: latLngPoints,
                        color: Colors.blue,
                        strokeWidth: 4,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: latLngPoints.first,
                        width: 24,
                        height: 24,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.green,
                          size: 24,
                        ),
                      ),
                      Marker(
                        point: latLngPoints.last,
                        width: 24,
                        height: 24,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Trip on ${DateFormat.yMMMd().format(startTime)}",
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoColumn(Icons.timer_sharp, "Start Time",
                        DateFormat.jm().format(startTime)),
                    _buildInfoColumn(Icons.timer_off, "End Time",
                        DateFormat.jm().format(endTime)),
                    _buildInfoColumn(
                        Icons.space_dashboard, "Distance", "$distanceKm km"),
                  ],
                ),
                if (companions != null && companions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text("With Companions:",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: companions
                        .map((c) => Chip(label: Text(c.toString())))
                        .toList(),
                  ),
                ]
              ],
            ),
          )
        ],
      ),
    );
  }

  // This function also remains unchanged.
  Widget _buildInfoColumn(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.indigo, size: 28),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(color: Colors.black54, fontSize: 12)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}