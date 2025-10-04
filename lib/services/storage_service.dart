import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class StorageService {
  static const String _boxName = 'trips';
  static Box? _box;
  static final _uuid = Uuid();

  // Map to hold original IDs for retry purposes
  static final Map<String, String> _originalUserIds = {};

  static Future<void> init() async {
    print("🔹 Initializing Hive storage...");
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);

    print("🔹 Checking for old string trips to migrate...");
    for (final key in _box!.keys) {
      final v = _box!.get(key);
      if (v is String) {
        try {
          final decoded = jsonDecode(v);
          if (decoded is Map) {
            await _box!.put(key, Map<String, dynamic>.from(decoded));
            print("✅ Migrated trip $key to Map format.");
          }
        } catch (_) {}
      }
    }
  }

  static Box get box {
    if (_box == null) throw Exception('StorageService not initialized');
    return _box!;
  }

  static Future<void> saveTrip(String key, Map<String, dynamic> trip) async {
    print("💾 Saving trip locally with key: $key");
    if (trip.containsKey('userId')) {
      _originalUserIds[key] = trip['userId'];
    }
    await box.put(key, Map<String, dynamic>.from(trip));
  }

  static Future<void> updateTrip(
      String key, Map<String, dynamic> updates) async {
    final existingTrip = getTrip(key);
    if (existingTrip != null) {
      existingTrip.addAll(updates);
      await box.put(key, existingTrip);
      print("🔄 Updated trip $key with new details.");
    }
  }

  static Future<void> deleteTrip(String key) async {
    print("🗑 Deleting trip locally with key: $key");
    await box.delete(key);
    _originalUserIds.remove(key);
  }

  static Map<String, dynamic>? getTrip(String key) {
    final v = box.get(key);
    if (v == null) return null;

    if (v is Map) return Map<String, dynamic>.from(v);

    if (v is String) {
      try {
        return Map<String, dynamic>.from(jsonDecode(v));
      } catch (e) {
        print("⚠️ Failed to decode trip for key $key: $e");
        return null;
      }
    }
    return null;
  }

  static List<String> pendingKeys() {
    final keys =
        box.keys.cast<String>().where((k) => k != 'anon_user_id').toList();
    print("📊 Pending local trip keys: $keys");
    return keys;
  }

  /// Returns the anon hashed ID for sending.
  ///
  static Future<String> getOrCreateAnonUserId() async {
    const anonKey = 'anon_user_id';
    if (box.containsKey(anonKey)) {
      return box.get(anonKey) as String;
    }

    // Generate a new raw UUID and store it.
    final rawId = _uuid.v4();
    await box.put(anonKey, rawId);
    print("🔹 Created and stored new raw anon user ID: $rawId");
    return rawId;
  }

  /// Returns original user ID for retry if needed
  static String? getOriginalUserId(String key) {
    return _originalUserIds[key];
  }

  // In storage_service.dart

  // ... (inside the StorageService class)

  static Future<void> saveTransitionGraph(
    Map<String, Map<String, int>> graph,
  ) async {
    print("💾 Saving transition graph to storage...");
    // We encode the map to a JSON string to store it in Hive.
    await box.put('transition_graph', jsonEncode(graph));
  }

  static Map<String, dynamic>? loadTransitionGraph() {
    print("🧠 Loading transition graph from storage...");
    final rawGraph = box.get('transition_graph');
    if (rawGraph is String) {
      try {
        return jsonDecode(rawGraph) as Map<String, dynamic>;
      } catch (e) {
        print("⚠️ Could not decode transition graph: $e");
        return null;
      }
    }
    return null;
  }
}