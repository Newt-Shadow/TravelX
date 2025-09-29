import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';

/// Adaptive 2D Kalman Filter for GPS
class _KalmanFilter {
  double lat;
  double lon;
  double varLat;
  double varLon;

  _KalmanFilter({required this.lat, required this.lon})
      : varLat = 1,
        varLon = 1;

  /// Update filter with new observation and measurement accuracy
  void update(double newLat, double newLon, double accuracy) {
    // Process noise adapts to measurement accuracy
    final q = max(1e-6, accuracy / 1000); // larger for less accurate GPS
    varLat += q;
    varLon += q;

    // Measurement noise based on device-reported accuracy
    final r = max(1e-5, pow(accuracy / 10, 2)); // scales with accuracy

    final kLat = varLat / (varLat + r);
    final kLon = varLon / (varLon + r);

    lat += kLat * (newLat - lat);
    lon += kLon * (newLon - lon);

    varLat = (1 - kLat) * varLat;
    varLon = (1 - kLon) * varLon;
  }
}

class GpsService {
  StreamSubscription<Position>? _sub;
  final StreamController<Position> _controller = StreamController.broadcast();

  _KalmanFilter? _kf;
  final List<Position> _recentPositions = [];
  final int _windowSize = 5; // for dynamic outlier threshold

  Stream<Position> get stream => _controller.stream;

  void start() {
    final settings = const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );

    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (pos) {
        try {
          // Skip if accuracy is terrible (>50m)
          if (pos.accuracy > 50) return;

          // Initialize or update Kalman filter
          if (_kf == null) {
            _kf = _KalmanFilter(lat: pos.latitude, lon: pos.longitude);
          } else {
            _kf!.update(pos.latitude, pos.longitude, pos.accuracy);
          }

          // Add to recent positions buffer
          _recentPositions.add(pos);
          if (_recentPositions.length > _windowSize) _recentPositions.removeAt(0);

          // Dynamic outlier detection based on recent movement
          final threshold = _dynamicOutlierThreshold();
          final last = _recentPositions.isNotEmpty ? _recentPositions.last : pos;
          final dx = (_kf!.lat - last.latitude) * 111_139; // meters per degree
          final dy = (_kf!.lon - last.longitude) * 111_139;
          final dist = sqrt(dx * dx + dy * dy);
          if (dist > threshold) return; // skip outlier

          final smooth = Position(
            longitude: _kf!.lon,
            latitude: _kf!.lat,
            timestamp: pos.timestamp ?? DateTime.now().toUtc(),
            accuracy: pos.accuracy,
            altitude: pos.altitude,
            altitudeAccuracy: pos.altitudeAccuracy ?? pos.accuracy,
            heading: pos.heading,
            headingAccuracy: pos.headingAccuracy ?? 0.0,
            speed: pos.speed,
            speedAccuracy: pos.speedAccuracy,
          );

          _controller.add(smooth);
        } catch (e, st) {
          _controller.addError(e, st);
        }
      },
      onError: (e, st) => _controller.addError(e, st),
    );
  }

  /// Dynamically compute outlier threshold based on recent GPS variance
  double _dynamicOutlierThreshold() {
    if (_recentPositions.length < 2) return 50.0;
    double meanLat = _recentPositions.map((p) => p.latitude).reduce((a, b) => a + b) /
        _recentPositions.length;
    double meanLon = _recentPositions.map((p) => p.longitude).reduce((a, b) => a + b) /
        _recentPositions.length;

    double varSum = 0;
    for (var p in _recentPositions) {
      final dx = (p.latitude - meanLat) * 111_139;
      final dy = (p.longitude - meanLon) * 111_139;
      varSum += sqrt(dx * dx + dy * dy);
    }
    final std = varSum / _recentPositions.length;
    return max(10, std * 3); // allow 3x std deviation
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _kf = null;
    _recentPositions.clear();
  }
}
