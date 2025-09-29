import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/gps_service.dart';

class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({super.key});

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  final List<LatLng> _points = [];
  GoogleMapController? _controller;
  final _gps = GpsService();

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      // ✅ Check permissions
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError("Location services are disabled.");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError("Location permissions are denied.");
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showError(
            "Location permissions are permanently denied. Please enable them in settings.");
        return;
      }

      // ✅ Start GPS service
      _gps.start();
      _gps.stream.listen((pos) {
        final p = LatLng(pos.latitude, pos.longitude);
        setState(() => _points.add(p));
        _controller?.animateCamera(CameraUpdate.newLatLng(p));
      });
    } catch (e) {
      _showError("Error accessing location: $e");
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _gps.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Live Trip Map")),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(0, 0),
          zoom: 3,
        ),
        onMapCreated: (c) => _controller = c,
        polylines: {
          Polyline(
            polylineId: const PolylineId('live'),
            points: _points,
            color: Colors.indigo,
            width: 5,
          )
        },
      ),
    );
  }
}
