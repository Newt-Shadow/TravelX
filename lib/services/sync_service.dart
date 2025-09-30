// services/sync_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'storage_service.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class SyncService {
  static final SyncService instance = SyncService._internal();
  static const String BACKEND_URL = 'http://http://34.55.89.158:5000/api/trips';

  final Connectivity _conn = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  final Map<String, int> _attempts = {};
  final Duration baseDelay = const Duration(seconds: 3);

  SyncService._internal() {
    // Listen to connectivity changes
    _sub = _conn.onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      for (final res in results) {
        if (res == ConnectivityResult.mobile ||
            res == ConnectivityResult.wifi) {
          print(
            "📶 Connectivity detected, attempting to sync all pending trips...",
          );
          _trySyncAll();
          break;
        }
      }
    });
  }

  static void initialize() {
    print("🔹 SyncService initialized");
  }

  /// Enqueue a single trip key to attempt sync
  Future<void> enqueueAndSync(String key) async {
    print("📥 Enqueue request to sync trip with key: $key");
    await _trySyncKey(key);
  }

  /// Sync all pending trips
  Future<void> _trySyncAll() async {
    final keys = StorageService.pendingKeys();
    for (final k in keys) {
      await _trySyncKey(k);
    }
  }

  /// Attempt to sync a single trip
  Future<void> _trySyncKey(String key) async {
    final rawTrip = StorageService.getTrip(key);
    final currentUserId = AuthService.currentUserId;
    if (currentUserId == null) {
      print(
        "⚠️ Cannot sync trip $key, user is not logged in. Will retry later.",
      );
      return;
    }
    if (rawTrip == null) {
      print("⚠️ No trip found for key $key");
      return;
    }

    Map<String, dynamic> trip;
    if (rawTrip is Map) {
      trip = Map<String, dynamic>.from(rawTrip);
    } else if (rawTrip is String) {
      try {
        final decoded = jsonDecode(rawTrip as String);
        if (decoded is Map) {
          trip = Map<String, dynamic>.from(decoded);
        } else {
          print(
            "⚠️ Decoded trip is not a Map for $key: ${decoded.runtimeType}",
          );
          return;
        }
      } catch (e) {
        print("⚠️ Failed to decode trip $key: $e");
        return;
      }
    } else {
      print("⚠️ Unexpected trip type for $key: ${rawTrip.runtimeType}");
      return;
    }

    final attempts = (_attempts[key] ?? 0) + 1;
    _attempts[key] = attempts;

    // Try sending with anon hash userId
    trip['anonUserId'] = currentUserId;

    bool sent = await _sendTrip(trip);

    // Retry once with original userId if first attempt fails
    // if (!sent && attempts == 1) {
    //   print("⚠️ Retrying trip $key with original userId...");
    //   trip['userId'] = originalUserId;
    //   sent = await _sendTrip(trip);
    // }

    if (sent) {
      await StorageService.deleteTrip(key);
      _attempts.remove(key);
    } else {
      final delay = _backoff(attempts);
      print("⏱ Backoff for ${delay.inSeconds}s before next retry for $key");
      await Future.delayed(delay);
    }
  }

  /// Send trip to backend
  Future<bool> _sendTrip(Map<String, dynamic> trip) async {
    final key = trip['id'] ?? 'unknown';
    print("📤 Sending trip $key with anonUserId ${trip['anonUserId']}...");
    try {
      final res = await http
          .post(
            Uri.parse(BACKEND_URL),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(trip),
          )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode == 200 ||
          res.statusCode == 201 ||
          res.statusCode == 202) {
        print("✅ Trip $key sent successfully!");
        return true;
      } else {
        print("❌ Backend responded with ${res.statusCode} for trip $key");
        return false;
      }
    } catch (e) {
      print("⚠️ Failed to send trip $key: $e");
      return false;
    }
  }

  /// Exponential backoff for retries
  Duration _backoff(int attempts) {
    final factor = pow(2, min(attempts, 6)).toInt();
    return Duration(seconds: baseDelay.inSeconds * factor);
  }
}
