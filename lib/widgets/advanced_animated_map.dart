import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/trip.dart';
import '../viewmodels/trip_detail_viewmodel.dart';

class AdvancedAnimatedMap extends StatefulWidget {
  const AdvancedAnimatedMap({super.key});

  @override
  State<AdvancedAnimatedMap> createState() => _AdvancedAnimatedMapState();
}

class _AdvancedAnimatedMapState extends State<AdvancedAnimatedMap> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final MapController _mapController = MapController();
  
  late final Trip _trip;
  late final TripDetailViewModel _viewModel;
  List<LatLng> _allPoints = [];
  List<double> _cumulativeDistances = [];
  double _totalDistance = 0;

  @override
  void initState() {
    super.initState();
    _viewModel = Provider.of<TripDetailViewModel>(context, listen: false);
    _trip = _viewModel.trip;

    _preparePathData();

    // The animation controller's value will represent the distance traveled.
    _controller = AnimationController(vsync: this, duration: _trip.segments.isNotEmpty 
      ? (_trip.segments.last.end ?? DateTime.now()).difference(_trip.segments.first.start) 
      : const Duration(seconds: 1));

    _controller.addListener(() {
      _viewModel.updateAnimationProgress(_controller.value);

      // Pan the map to follow the marker
      final currentPosition = _getPositionAtProgress(_controller.value);
      _mapController.move(currentPosition, _mapController.camera.zoom);
    });
    
    _controller.forward();
  }

  void _preparePathData() {
    const distance = Distance();
    _allPoints = _trip.segments
        .expand((seg) => seg.gps)
        .map((p) => LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()))
        .toList();

    _cumulativeDistances.add(0.0);
    for (int i = 0; i < _allPoints.length - 1; i++) {
      final dist = distance(_allPoints[i], _allPoints[i+1]);
      _totalDistance += dist;
      _cumulativeDistances.add(_totalDistance);
    }
  }

  LatLng _getPositionAtProgress(double progress) {
    final targetDistance = _totalDistance * progress;

    // Find the correct segment of the path
    for (int i = 0; i < _cumulativeDistances.length - 1; i++) {
      if (targetDistance >= _cumulativeDistances[i] && targetDistance <= _cumulativeDistances[i+1]) {
        // Interpolate between the two points
        final segmentDistance = _cumulativeDistances[i+1] - _cumulativeDistances[i];
        final segmentProgress = (targetDistance - _cumulativeDistances[i]) / segmentDistance;
        return LatLng(
          _allPoints[i].latitude + (_allPoints[i+1].latitude - _allPoints[i].latitude) * segmentProgress,
          _allPoints[i].longitude + (_allPoints[i+1].longitude - _allPoints[i].longitude) * segmentProgress,
        );
      }
    }
    return _allPoints.isNotEmpty ? _allPoints.last : LatLng(0,0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_allPoints.isEmpty) return const Center(child: Text("No GPS data"));

    return Consumer<TripDetailViewModel>(
      builder: (context, viewModel, child) {
        final animatedDistance = _totalDistance * viewModel.animationProgress;
        
        return FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _allPoints.first,
            initialZoom: 14,
          ),
          children: [
            TileLayer(urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png'),
            PolylineLayer(
              polylines: _buildSegmentPolylines(),
            ),
            if (viewModel.animationProgress < 1.0)
              MarkerLayer(markers: [
                Marker(
                  point: _getPositionAtProgress(viewModel.animationProgress),
                  width: 24,
                  height: 24,
                  child: const CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Padding(
                      padding: EdgeInsets.all(2.0),
                      child: CircleAvatar(backgroundColor: Colors.blueAccent),
                    ),
                  ),
                ),
              ]),
          ],
        );
      },
    );
  }

  List<Polyline> _buildSegmentPolylines() {
    List<Polyline> polylines = [];
    for (final segment in _trip.segments) {
      final points = segment.gps.map((p) => LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble())).toList();
      polylines.add(
        Polyline(
          points: points,
          strokeWidth: 5,
          color: _getColorForMode(segment.mode),
        )
      );
    }
    return polylines;
  }
  
  Color _getColorForMode(String mode) {
    switch (mode) {
      case 'walk': return Colors.green;
      case 'run': return Colors.orange;
      case 'bike': return Colors.blue;
      case 'car': return Colors.purple;
      case 'bus': return Colors.red;
      case 'train': return Colors.teal;
      default: return Colors.grey;
    }
  }
}