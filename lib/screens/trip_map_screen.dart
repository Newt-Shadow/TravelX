import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/storage_service.dart';

class TripMapScreen extends StatefulWidget {
  final String tripKey;
  const TripMapScreen({super.key, required this.tripKey});

  @override
  State<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends State<TripMapScreen> {
  late Map<String, dynamic> trip;

  @override
  void initState() {
    super.initState();
    trip = StorageService.getTrip(widget.tripKey) ?? {};
  }

  @override
  Widget build(BuildContext context) {
    final segs = (trip['segments'] as List? ?? []);
    final polylines = <Polyline>{};
    final markers = <Marker>{};

    int polyId = 1;
    for (final seg in segs) {
      final gpsList = (seg['gps'] as List? ?? [])
          .where((p) => p['lat'] != null && p['lng'] != null)
          .toList();
      if (gpsList.length < 2) continue;

      final points = gpsList
          .map((p) => LatLng(p['lat'] as double, p['lng'] as double))
          .toList();

      Color color;
      switch (seg['mode'] ?? '') {
        case 'walk':
          color = Colors.green;
          break;
        case 'bike':
          color = Colors.blue;
          break;
        case 'bus':
          color = Colors.orange;
          break;
        case 'train':
          color = Colors.purple;
          break;
        default:
          color = Colors.grey;
      }

      polylines.add(Polyline(
        polylineId: PolylineId('seg_$polyId'),
        points: points,
        color: color,
        width: 5,
      ));
      polyId++;
    }

    // Safe origin/destination
    LatLng defaultPos = const LatLng(0, 0);
    LatLng origin = defaultPos, dest = defaultPos;

    if (segs.isNotEmpty && (segs.first['gps'] as List? ?? []).isNotEmpty) {
      final first = segs.first['gps'].first;
      origin = LatLng(first['lat'] as double, first['lng'] as double);
    }
    if (segs.isNotEmpty && (segs.last['gps'] as List? ?? []).isNotEmpty) {
      final last = segs.last['gps'].last;
      dest = LatLng(last['lat'] as double, last['lng'] as double);
    }

    markers.add(Marker(
        markerId: const MarkerId('origin'),
        position: origin,
        infoWindow: const InfoWindow(title: 'Origin')));
    markers.add(Marker(
        markerId: const MarkerId('dest'),
        position: dest,
        infoWindow: const InfoWindow(title: 'Destination')));

    return Scaffold(
      appBar: AppBar(title: const Text('Trip Map')),
      body: GoogleMap(
        polylines: polylines,
        markers: markers,
        initialCameraPosition: CameraPosition(target: origin, zoom: 14),
      ),
    );
  }
}
