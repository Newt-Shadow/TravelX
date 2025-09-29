import 'dart:convert';

class TripSegment {
  String id;
  DateTime start;
  DateTime? end;
  String mode;
  List<Map<String, dynamic>> gps;
  List<Map<String, dynamic>> accel;
  List<Map<String, dynamic>> bt;

  TripSegment({
    required this.id,
    required this.start,
    this.end,
    required this.mode,
    List<Map<String, dynamic>>? gps,
    List<Map<String, dynamic>>? accel,
    List<Map<String, dynamic>>? bt,
  })  : gps = gps ?? [],
        accel = accel ?? [],
        bt = bt ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'start': start.toUtc().toIso8601String(),
        'end': end?.toUtc().toIso8601String(),
        'mode': mode,
        'gps': gps,
        'accel': accel,
        'bt': bt,
      };

  /// ✅ FIXED: A robust factory that safely parses data.
  /// It handles nulls and uses tryParse to prevent crashes from bad date formats.
  static TripSegment fromJson(Map<String, dynamic> m) {
    return TripSegment(
      id: m['id'] ?? 'unknown_segment_id',
      start: DateTime.tryParse(m['start'] ?? '') ?? DateTime.now(),
      end: m['end'] == null ? null : DateTime.tryParse(m['end']),
      mode: m['mode'] ?? 'unknown',
      gps: List<Map<String, dynamic>>.from(m['gps'] ?? []),
      accel: List<Map<String, dynamic>>.from(m['accel'] ?? []),
      bt: List<Map<String, dynamic>>.from(m['bt'] ?? []),
    );
  }
}

class Trip {
String id;
String anonUserId;
DateTime createdAt;
List<TripSegment> segments;
List<String> companions;
bool uploaded;
DateTime? uploadedAt;

  Trip({
    required this.id,
    required this.anonUserId,
    required this.createdAt,
    List<TripSegment>? segments,
    List<String>? companions,
    this.uploaded = false,
    this.uploadedAt,
  })  : segments = segments ?? [],
        companions = companions ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'anonUserId': anonUserId,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'segments': segments.map((s) => s.toJson()).toList(),
        'companions': companions,
        'uploaded': uploaded,
        'uploadedAt': uploadedAt?.toUtc().toIso8601String(),
      };

  /// ✅ FIXED: A robust factory that safely parses the main trip object.
  static Trip fromJson(Map<String, dynamic> m) {
    final segmentsList = m['segments'] as List? ?? [];
    return Trip(
      id: m['id'] ?? 'unknown_trip_id',
      anonUserId: m['anonUserId'] ?? 'unknown_user',
      createdAt: DateTime.tryParse(m['createdAt'] ?? '') ?? DateTime.now(),
      segments: segmentsList
          .map((e) => TripSegment.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      companions: List<String>.from(m['companions'] ?? []),
      uploaded: m['uploaded'] as bool? ?? false,
      uploadedAt: m['uploadedAt'] == null ? null : DateTime.tryParse(m['uploadedAt']),
    );
  }
}

