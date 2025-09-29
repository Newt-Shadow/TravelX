import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:latlong2/latlong.dart';
import '../models/trip.dart';
import 'storage_service.dart';

class RouteAnalysisService {
  final int _minPointsForRouteHash = 10;

  /// Creates a unique, fuzzy signature for a trip's path for route matching.
  String? generateRouteSignature(Trip trip) {
    final points = trip.segments.expand((s) => s.gps).toList();
    if (points.length < _minPointsForRouteHash) return null;

    final pathString = points
      .map((p) => "${(p['lat'] as num).toStringAsFixed(3)},${(p['lng'] as num).toStringAsFixed(3)}")
      .join('|');
    
    return sha256.convert(utf8.encode(pathString)).toString();
  }

  /// Analyzes a completed trip to determine its likely frequency.
  Future<String> determineTripFrequency(Trip currentTrip) async {
    final currentSignature = generateRouteSignature(currentTrip);
    if (currentSignature == null) return 'Once';

    final allTrips = await _getAllTrips();
    final now = DateTime.now();
    
    final List<Trip> matchedTrips = [];
    for (final trip in allTrips) {
      if (generateRouteSignature(trip) == currentSignature) {
        matchedTrips.add(trip);
      }
    }

    if (matchedTrips.length < 3) return 'Once';

    final dailyPattern = matchedTrips
        .where((t) => now.difference(t.createdAt).inDays < 7)
        .map((t) => t.createdAt.weekday)
        .toSet();

    if (dailyPattern.length >= 3) {
      return 'Daily';
    }

    final weeklyPattern = matchedTrips
        .where((t) => t.createdAt.weekday == now.weekday && now.difference(t.createdAt).inDays < 30)
        .length;
        
    if (weeklyPattern >= 2) {
      return 'Weekly';
    }
    
    return 'Recurring';
  }

  Future<List<Trip>> _getAllTrips() async {
    final keys = StorageService.box.keys.whereType<String>().where((k) => k != 'anon_user_id' && k != 'transition_graph');
    final trips = <Trip>[];
    for (final key in keys) {
      final tripMap = StorageService.getTrip(key);
      if (tripMap != null) {
        try {
          trips.add(Trip.fromJson(tripMap));
        } catch (e) {
          print("Error parsing trip from storage: $e");
        }
      }
    }
    return trips;
  }
}

