import 'dart:convert';

class TripSegment {
  String id;
  DateTime start;
  DateTime? end;
  String mode;
  List<Map<String, dynamic>> gps;
  List<Map<String, dynamic>> accel;
  List<Map<String, dynamic>> bt;
  double? cost;
  String? notes;

  TripSegment({
    required this.id,
    required this.start,
    this.end,
    required this.mode,
    List<Map<String, dynamic>>? gps,
    List<Map<String, dynamic>>? accel,
    List<Map<String, dynamic>>? bt,
    this.cost,
    this.notes,
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
        'cost': cost,
        'notes': notes,
      };

  static TripSegment fromJson(Map<String, dynamic> m) {
    return TripSegment(
      id: m['id'] ?? 'unknown_segment_id',
      start: DateTime.tryParse(m['start'] ?? '') ?? DateTime.now(),
      end: m['end'] == null ? null : DateTime.tryParse(m['end']),
      mode: m['mode'] ?? 'unknown',
      gps: List<Map<String, dynamic>>.from(m['gps'] ?? []),
      accel: List<Map<String, dynamic>>.from(m['accel'] ?? []),
      bt: List<Map<String, dynamic>>.from(m['bt'] ?? []),
      cost: (m['cost'] as num?)?.toDouble(),
      notes: m['notes'] as String?,
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
  double? cost;
  String? notes;

  Trip({
    required this.id,
    required this.anonUserId,
    required this.createdAt,
    List<TripSegment>? segments,
    List<String>? companions,
    this.uploaded = false,
    this.uploadedAt,
    this.cost,
    this.notes,
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
        'cost': cost,
        'notes': notes,
      };

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
      uploadedAt:
          m['uploadedAt'] == null ? null : DateTime.tryParse(m['uploadedAt']),
      cost: (m['cost'] as num?)?.toDouble(),
      notes: m['notes'] as String?,
    );
  }
}