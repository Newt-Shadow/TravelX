import 'auth_service.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_activity_recognition/flutter_activity_recognition.dart';
import 'storage_service.dart';
import 'gps_service.dart';
import 'accel_service.dart';
import 'bluetooth_service.dart';
// Add this import at the top
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';
import '../screens/trip_completion_screen.dart';
import 'activity_service.dart';
import 'notification_service.dart';
import 'sync_service.dart';
import '../models/trip.dart';
import '../utils/filters.dart';
import '../utils/graph_learning.dart';

// --- ADDED: Enum for type-safe state management ---
enum DetectionState { idle, possible_start, collecting, possible_stop }

class DetectionService {

  TripSegment? get currentSegment => _currentSegment;
  DetectionState get state => _state;
  // --- ADDED: Centralized constants for easier tuning ---
  static const _kMaxWalkSpeed = 2.5; // m/s
  static const _kMaxBikeSpeed = 6.5; // m/s
  static const _kMinVehicleSpeed = 6.5; // m/s
  static const _kMinTrainSpeed = 20.0; // m/s
  static const _kRunAccelVarThreshold = 2.5;
  static const _kBusAccelVarThreshold = 0.06;
  static const _kGpsDisplacementThreshold = 0.51; // meters
  // --- NEW: Constants for discarding short/accidental trips ---
  static const _kMinValidTripDurationSec = 30; // seconds
  static const _kContinuationGapMin = 5; // minutes

  // --- Service Dependencies ---
  final GpsService gps;
  final AccelService accel;
  final BluetoothService bt;
  final ActivityService activity;
  final _uuid = const Uuid();

  // --- CORRECTED: Use the new ContextualTransitionGraph ---
  final ContextualTransitionGraph _tGraph;

  // --- State for new features ---
  int _lastStopTime = 0; // ms
  final int _tripStartCooldownSec = 5;
  String? _previousSegmentMode;

  // --- Buffers and windows ---
  final List<Map<String, dynamic>> _gpsBuffer = [];
  final List<double> _accelBuffer = [];
  final int gpsWindowSec = 8;
  final int accelWindow = 30;

  // --- Tunable Parameters ---
  final int startConsensusSec = 6;
  final int stopConsensusSec = 5;
  final int fullStopAfterIdleSec = 5;
  final int _minSegmentDurationSec = 4;
  final Duration _watchdogTimeout = const Duration(minutes: 5);

  // --- Internal Timestamps ---
  int _lastMovingDetectedAt = 0;
  int _lastIdleDetectedAt = 0;
  int _lastGpsUpdateAt = 0;
  int _lastActivityHintAt = 0;
  int _lastModeChangeAt = 0;
  int _possibleStopStartedAt = 0;
  int _possibleStartBeganAt = 0; // --- NEW: Tracks start of movement for consensus ---

  // --- State machine and data collection state ---
  bool collecting = false;
  late Trip _currentTrip;
  TripSegment? _currentSegment;
  DetectionState _state = DetectionState.idle;

  // --- Hysteresis & Hinting ---
  final List<String> _modeHistory = [];
  final int _hysteresisN = 3;
  String? _lastActivityHint;

  // --- Subscriptions & Timers ---
  StreamSubscription<Position>? _gpsSub;
  StreamSubscription<double>? _accelSub;
  StreamSubscription<List>? _btSub;
  StreamSubscription<Activity>? _activitySub;
  Timer? _watchdogTimer;

  // --- UI Stream ---
  final StreamController<TripSegment> _segmentsController = StreamController.broadcast();
  Stream<TripSegment> get segmentsStream => _segmentsController.stream;

  

  DetectionService({
    required this.gps,
    required this.accel,
    required this.bt,
    required this.activity,
  }) : _tGraph = ContextualTransitionGraph(decayFactor: 0.85) {
    final savedGraph = StorageService.loadTransitionGraph();
    if (savedGraph != null) {
      _tGraph.importGraph(savedGraph);
    }
  }

  void start() {
    print("✅ DetectionService started by AuthWrapper.");
    _init();
  }

  String get currentMode => _currentSegment?.mode ?? 'unknown';

  Future<void> overrideMode(String mode) async {
    if (!collecting) return;
    await _startNewSegment(mode);
  }

  void _init() {
    try {
      gps.start();
      accel.start();
      bt.startPeriodicScan(); // Start with periodic scanning
      activity.start();
    } catch (e) {
      print('sensor start error: $e');
    }
    _attachSubscriptions();
    _kickWatchdog();
  }

  void _attachSubscriptions() {
    _gpsSub?.cancel();
    _accelSub?.cancel();
    _btSub?.cancel();
    _activitySub?.cancel();

    _gpsSub = gps.stream.listen(_onGps, onError: (e) => print('gps err $e'));
    _accelSub = accel.linearMagnitude.listen(
      _onAccel,
      onError: (e) => print('accel err $e'),
    );
    _btSub = bt.stream.listen(_onBt, onError: (e) => print('bt err $e'));
    _activitySub = activity.stream.listen(
      _onActivity,
      onError: (e) => print('act err $e'),
    );
  }

  void stop() {
    print("🛑 DetectionService stopped by AuthWrapper.");
    _gpsSub?.cancel();
    _accelSub?.cancel();
    _btSub?.cancel();
    _activitySub?.cancel();
    if (!_segmentsController.isClosed) {
      _segmentsController.close();
    }
    gps.stop();
    accel.stop();
    bt.stopScan();
    bt.stopPassiveAdvertising();
    bt.stopActiveAdvertising();
    activity.stop();
    _watchdogTimer?.cancel();
  }

  // ... (rest of the file is unchanged, only including relevant parts)

  Future<void> startInternal(String detectedMode) async {
    if (detectedMode == 'stationary' || detectedMode == 'unknown') return;

    final userId = AuthService.currentUserId;

    if (userId == null) {
      print("⛔ Cannot start trip, user is not logged in.");
      collecting = false;
      _state = DetectionState.idle;
      return;
    }

    // ✅ Switch to continuous scanning for the duration of the trip
    bt.startContinuousScan();
    await bt.startActiveAdvertising(userId);
    final tripId = _uuid.v4();
    _currentTrip = Trip(
      id: tripId,
      anonUserId: userId,
      createdAt: DateTime.now().toUtc(),
    );
    _currentSegment = TripSegment(
      id: _uuid.v4(),
      start: DateTime.now().toUtc(),
      mode: detectedMode,
    );
    _currentTrip.segments.add(_currentSegment!);

    collecting = true;
    _state = DetectionState.collecting;
    _possibleStopStartedAt = 0;
    _previousSegmentMode = null;

    _segmentsController.add(_currentSegment!);
    NotificationService.showOngoing('Trip started', 'Mode: $detectedMode');

    _lastMovingDetectedAt = DateTime.now().toUtc().millisecondsSinceEpoch;
    _modeHistory.clear();
    _lastModeChangeAt = DateTime.now().toUtc().millisecondsSinceEpoch;
  }

  Future<void> stopInternal() async {
    if (!collecting) return;
    
    // ✅ Stop continuous scanning and active advertising
    bt.stopActiveAdvertising();
    // ✅ Revert to battery-saving periodic scanning
    bt.startPeriodicScan();

    collecting = false;
    _state = DetectionState.idle;
    _currentSegment?.end = DateTime.now().toUtc();
    final tripEndTime = DateTime.now().toUtc().millisecondsSinceEpoch;

    final tripDurationMs = tripEndTime - _currentTrip.createdAt.millisecondsSinceEpoch;
    final timeSinceLastTripMs = _lastStopTime > 0 ? tripEndTime - _lastStopTime : double.infinity;
    final isShortTrip = tripDurationMs < (_kMinValidTripDurationSec * 1000);
    final isNewSession = timeSinceLastTripMs > (_kContinuationGapMin * 60 * 1000);

    if (isShortTrip && isNewSession) {
      print("🗑 Discarding short, accidental trip (Duration: ${tripDurationMs / 1000}s).");
      _lastStopTime = tripEndTime;
      NotificationService.cancelOngoing();
      NotificationService.showOneShot('Trip Discarded', 'Movement was too short.');
      
      if (_currentSegment != null && !_segmentsController.isClosed) _segmentsController.add(_currentSegment!);
      _currentSegment = null;
      _resetSoftState();
      return;
    }

    _lastStopTime = tripEndTime;

    final cleaned = _sanitizeTrip(_currentTrip);
    final key = _currentTrip.id;
    await StorageService.saveTrip(key, cleaned);
    await SyncService.instance.enqueueAndSync(key);
    await StorageService.saveTransitionGraph(_tGraph.exportGraph());

    NotificationService.cancelOngoing();
    NotificationService.showOneShot('Trip saved', 'Trip stored locally.');

    if (_currentSegment != null && !_segmentsController.isClosed) _segmentsController.add(_currentSegment!);
    _currentSegment = null;
    _resetSoftState();
  }

  // ... (rest of the file is unchanged, only showing the relevant parts for brevity)
  // ... (make sure to copy the full original content for the parts marked as "...")

  // The rest of your _onGps, _onAccel, _onBt, _onActivity, _classifyMode, etc. methods remain the same.
  // The important change is how startInternal and stopInternal control the BluetoothService's scanning mode.

  void _onGps(Position p) {
    final ts = (p.timestamp ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    _gpsBuffer.add({
      'lat': p.latitude,
      'lng': p.longitude,
      'ts': ts,
      'speed': p.speed ?? 0.0,
      'accuracy': p.accuracy ?? 100.0,
    });
    _pruneGps();

    if (collecting && _currentSegment != null) {
      _currentSegment!.gps.add({
        'lat': p.latitude,
        'lng': p.longitude,
        'ts': ts,
        'speed': p.speed,
      });
    }

    _lastGpsUpdateAt = DateTime.now().toUtc().millisecondsSinceEpoch;
    _kickWatchdog();
    _evaluateMovement();
  }

  void _onAccel(double mag) {
    _accelBuffer.add(mag);
    if (_accelBuffer.length > accelWindow) _accelBuffer.removeAt(0);

    if (collecting && _currentSegment != null) {
      _currentSegment!.accel.add({
        'mag': mag,
        'ts': DateTime.now().toUtc().millisecondsSinceEpoch,
      });
    }
    _kickWatchdog();
    _evaluateMovement();
  }

  void _onBt(List results) {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    try {
      final arr =
          results.map((r) {
            final deviceId =
                (r as dynamic).device?.id?.id ?? (r as dynamic).id ?? 'unknown';
            final rssi = (r as dynamic).rssi ?? 0;
            return {'id': deviceId, 'rssi': rssi, 'ts': now};
          }).toList();
      if (collecting && _currentSegment != null) {
        _currentSegment!.bt.addAll(arr);
      }
    } catch (e) {
      // ignore
    }
  }

  void _onActivity(Activity activityEvent) {
    try {
      final type = activityEvent.type;
      final confidence = activityEvent.confidence;
      final confVal = _mapConfidenceToInt(confidence);

      if (confVal >= 60) {
        final mode = _mapActivityToMode(type.name);
        if (mode != 'unknown') {
          _lastActivityHint = mode;
          _lastActivityHintAt = DateTime.now().toUtc().millisecondsSinceEpoch;
        }
      }

      if (confVal >= 75) {
        final mode = _mapActivityToMode(type.name);
        if (!collecting &&
            (_state == DetectionState.idle ||
                _state == DetectionState.possible_start)) {
          if (mode != 'stationary' && mode != 'unknown') {
            startInternal(mode);
          }
        } else if (collecting &&
            _currentSegment != null &&
            mode != _currentSegment!.mode) {
          _pushModeCandidate(mode, activityWeighted: true);
        }
      }
    } catch (e) {
      // ignore
    }
  }

  // --- HELPERS & CLASSIFICATION ---
  int _mapConfidenceToInt(ActivityConfidence conf) {
    switch (conf) {
      case ActivityConfidence.LOW:
        return 30;
      case ActivityConfidence.MEDIUM:
        return 60;
      case ActivityConfidence.HIGH:
        return 90;
    }
  }

  String _mapActivityToMode(String typeName) {
    switch (typeName.toLowerCase()) {
      case 'still':
      case 'stationary':
        return 'stationary';
      case 'walking':
        return 'walk';
      case 'running':
        return 'run';
      case 'on_bicycle':
      case 'cycling':
        return 'bike';
      case 'in_vehicle':
        return 'car';
      case 'on_foot':
        return 'walk';
      default:
        return 'unknown';
    }
  }

  void _pruneGps() {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    _gpsBuffer.removeWhere((e) => (now - e['ts']) > (gpsWindowSec * 1000));
  }

  Map<String, dynamic> _computeMetrics() {
    double speed = 0.0;
    double displacement = 0.0;
    if (_gpsBuffer.length >= 2) {
      final last = _gpsBuffer.last;
      final first = _gpsBuffer.first;
      displacement = Geolocator.distanceBetween(
        first['lat'],
        first['lng'],
        last['lat'],
        last['lng'],
      );
      final dt = max<double>(0.001, ((last['ts'] - first['ts']) / 1000.0));
      speed = displacement / dt;
    } else if (_gpsBuffer.length == 1) {
      speed = (_gpsBuffer.last['speed'] as double?) ?? 0.0;
    }

    final accelVar = Filters.variance(_accelBuffer);
    final accelMad = _computeMad(_accelBuffer);

    return {
      'speed': speed,
      'displacement': displacement,
      'accelVar': accelVar,
      'accelMad': accelMad,
    };
  }

  double _computeMad(List<double> buffer) {
    if (buffer.isEmpty) return 0.0;
    final sorted = List<double>.from(buffer)..sort();
    final med = sorted[sorted.length ~/ 2];
    final devs = sorted.map((v) => (v - med).abs()).toList()..sort();
    return devs.isEmpty ? 0.0 : devs[devs.length ~/ 2];
  }

  void _pushModeCandidate(String mode, {bool activityWeighted = false}) {
    if (mode == 'unknown') return;

    final votes = activityWeighted ? min(2, _hysteresisN - 1) : 1;
    for (int i = 0; i < votes; i++) {
      _modeHistory.add(mode);
      if (_modeHistory.length > _hysteresisN) _modeHistory.removeAt(0);
    }

    if (_modeHistory.length == _hysteresisN &&
        _modeHistory.every((m) => m == mode)) {
      final majorNow = _majorizeMode(mode);
      final majorCur = _majorizeMode(_currentSegment?.mode ?? 'unknown');
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      final durSinceLastMode = now - _lastModeChangeAt;

      if (!collecting) {
        if (majorNow != 'stationary' && majorNow != 'unknown') {
          startInternal(majorNow);
        }
      } else {
        if (majorNow != majorCur) {
          if (durSinceLastMode >= _minSegmentDurationSec * 1000 ||
              activityWeighted) {
            _startNewSegment(majorNow);
            _lastModeChangeAt = now;
          }
        }
      }
    }
  }

  String _majorizeMode(String m) {
    if (m.contains('walk')) return 'walk';
    if (m.contains('bike')) return 'bike';
    if (m == 'car' || m == 'bus' || m == 'train') return m;
    return m;
  }

  String _classifyMode(
    double speed,
    double accelVar,
    double accelMad, {
    String? activityHint,
    bool gpsStale = false,
    String? lastKnownMode,
  }) {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;

    if (gpsStale) {
      final hintIsFresh = (activityHint != null && _lastActivityHintAt > 0 && (now - _lastActivityHintAt) < 20000); // Extended to 20s

      if (hintIsFresh) {
        if (activityHint != 'stationary' && activityHint != 'unknown') {
          if (_validateActivityWithAccel(activityHint!, accelVar, accelMad)) {
            return activityHint;
          }
        }
        if (activityHint == 'stationary') {
          if (accelVar < 0.03 && accelMad < 0.02) return 'stationary';
          if (lastKnownMode == 'car' || lastKnownMode == 'bus') {
            return accelVar < 0.08 ? 'stationary' : lastKnownMode!;
          }
        }
      }

      if (lastKnownMode == 'car' || lastKnownMode == 'bus' || lastKnownMode == 'train') {
        if (_isVehicleIdling(accelVar, accelMad, lastKnownMode!)) {
          return 'stationary';
        }
        if (_isVehicleMoving(accelVar, accelMad, lastKnownMode!)) {
          return lastKnownMode;
        }
      }

      return _classifyFromAccelerometer(accelVar, accelMad, lastKnownMode);
    }

    final hint = (activityHint != null)
        ? activityHint
        : (_lastActivityHintAt > 0 && (now - _lastActivityHintAt) < 5000 ? _lastActivityHint : null);

    if (speed < 0.1 && accelVar < max(0.008, accelMad * 1.5)) return 'stationary';

    if (hint != null) {
      if (hint == 'walk' || hint == 'run') {
        if (accelVar > _kRunAccelVarThreshold && speed > 1.5) return 'run';
        if (accelVar > 0.3 && speed > 0.5) return 'walk';
        return 'walk';
      } else if (hint == 'bike') {
        if (_validateBikePattern(accelVar, accelMad, speed)) return 'bike';
        return 'walk';
      } else if (hint == 'car') {
        if (speed >= _kMinTrainSpeed) return 'train';
        if (_validateBusPattern(accelVar, accelMad)) return 'bus';
        return 'car';
      }
    }

    if (speed >= 0.15 && speed < _kMaxWalkSpeed) {
      if (accelVar > _kRunAccelVarThreshold && speed > 1.8) return 'run';
      if (accelVar > 0.2) return 'walk';
      return 'walk';
    }

    if (speed >= _kMaxWalkSpeed && speed < _kMaxBikeSpeed) {
      if (accelVar > 3.5) return 'run';
      if (_validateBikePattern(accelVar, accelMad, speed)) return 'bike';
      return 'smooth-bike';
    }

    if (speed >= _kMinVehicleSpeed && speed < _kMinTrainSpeed) {
      if (_validateBusPattern(accelVar, accelMad)) return 'bus';
      return 'car';
    }

    if (speed >= _kMinTrainSpeed) return 'train';

    return 'unknown';
  }

  bool _validateActivityWithAccel(String activity, double accelVar, double accelMad) {
    switch (activity) {
      case 'walk':
        return accelVar > 0.1 && accelVar < 2.0 && accelMad > 0.05;
      case 'run':
        return accelVar > 1.5 && accelMad > 0.2;
      case 'bike':
        return accelVar > 0.3 && accelVar < 1.5 && accelMad > 0.1;
      case 'car':
        return accelVar < 0.3 && accelMad < 0.15;
      case 'bus':
        return accelVar < 0.1 && accelMad < 0.08;
      default:
        return true;
    }
  }

  bool _isVehicleIdling(double accelVar, double accelMad, String vehicleType) {
    switch (vehicleType) {
      case 'car':
        return accelVar < 0.05 && accelMad < 0.03;
      case 'bus':
        return accelVar < 0.03 && accelMad < 0.02;
      case 'train':
        return accelVar < 0.08 && accelMad < 0.04;
      default:
        return accelVar < 0.05;
    }
  }

  bool _isVehicleMoving(double accelVar, double accelMad, String vehicleType) {
    switch (vehicleType) {
      case 'car':
        return accelVar > 0.02 && accelVar < 0.3;
      case 'bus':
        return accelVar > 0.01 && accelVar < 0.15;
      case 'train':
        return accelVar > 0.03 && accelVar < 0.2;
      default:
        return accelVar > 0.02;
    }
  }

  String _classifyFromAccelerometer(double accelVar, double accelMad, String? lastKnownMode) {
    if (accelVar < 0.01 && accelMad < 0.005) return 'stationary';
    
    if (accelVar > 2.0 && accelMad > 0.3) return 'run';
    
    if (accelVar > 0.3 && accelVar < 1.5 && accelMad > 0.1) {
      if (lastKnownMode == 'bike') return 'bike';
      return 'walk';
    }
    
    if (accelVar > 0.1 && accelVar < 0.5 && accelMad > 0.05) return 'walk';
    
    if (accelVar < 0.3 && accelMad < 0.15) {
      if (lastKnownMode == 'bus') return 'bus';
      if (lastKnownMode == 'train') return 'train';
      return 'car';
    }
    
    return 'unknown';
  }

  bool _validateBikePattern(double accelVar, double accelMad, double speed) {
    return accelVar > 0.2 && accelVar < 1.8 && 
           accelMad > 0.08 && accelMad < 0.4 &&
           speed > 1.0;
  }

  bool _validateBusPattern(double accelVar, double accelMad) {
    return accelVar < 0.15 && accelMad < 0.1;
  }


  int _adaptiveStopThreshold(String mode) {
    switch (mode) {
      case 'walk':
        return 15;
      case 'bike':
        return 10;
      case 'car':
        return 8;
      case 'train':
        return 5;
      case 'bus':
        return 8;
      default:
        return 20;
    }
  }

  void _evaluateMovement() {
    final metrics = _computeMetrics();
    final speed = metrics['speed'] as double;
    final disp = metrics['displacement'] as double;
    final accelVar = metrics['accelVar'] as double;
    final accelMad = metrics['accelMad'] as double;

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    if (_lastStopTime > 0 &&
        (now - _lastStopTime) < _tripStartCooldownSec * 1000) {
      return;
    }

    int consensusSec = startConsensusSec;
    final hintFresh =
        (_lastActivityHintAt > 0 && (now - _lastActivityHintAt) < 3000);
    if (hintFresh) consensusSec = 2;

    final idleSince = now - _lastMovingDetectedAt;
    if (_state == DetectionState.possible_stop && idleSince < 5000) {
      consensusSec = min(consensusSec, 2);
    }

    final noiseFloor = max<double>(0.005, accelMad);
    final adaptiveAccelThreshold = max<double>(0.02, noiseFloor * 3.0);
    final accelIndicatesMoving = accelVar > adaptiveAccelThreshold;

    final gpsIndicatesMoving =
        (speed > 0.2 && disp > _kGpsDisplacementThreshold);

    final gpsAgeMs = _lastGpsUpdateAt > 0 ? now - _lastGpsUpdateAt : 999999;
    final gpsStale = gpsAgeMs > 10000;
    final gpsTreatAsMoving = !gpsStale && gpsIndicatesMoving;

    final isMovingForStart = accelIndicatesMoving && gpsTreatAsMoving;
    final isMovingForContinue = accelIndicatesMoving || gpsTreatAsMoving;

    if (isMovingForContinue) {
      _lastMovingDetectedAt = now;
    } else {
      _lastIdleDetectedAt = now;
    }

    final tripAge =
        collecting ? now - _currentTrip.createdAt.millisecondsSinceEpoch : 0;

    if (_state == DetectionState.idle) {
      if (isMovingForStart) {
        _state = DetectionState.possible_start;
        _possibleStartBeganAt = now;
      }
    } else if (_state == DetectionState.possible_start) {
      if (!isMovingForStart) {
        _state = DetectionState.idle;
        _possibleStartBeganAt = 0;
        return;
      }

      if (now - _possibleStartBeganAt >= consensusSec * 1000) {
        final candidate = _classifyMode(
          speed,
          accelVar,
          accelMad,
          activityHint: _lastActivityHint,
          gpsStale: gpsStale,
          lastKnownMode: _currentSegment?.mode,
        );
        if (candidate != 'stationary' && candidate != 'unknown') {
          startInternal(candidate);
        } else {
          _state = DetectionState.idle;
        }
        _possibleStartBeganAt = 0;
      }
    } else if (_state == DetectionState.collecting) {
      final idleDuration = now - _lastMovingDetectedAt;
      final canStop = tripAge >= 15000;
      final fullyIdle = !accelIndicatesMoving && !gpsTreatAsMoving;

      if (fullyIdle && idleDuration >= stopConsensusSec * 1000 && canStop) {
        _startNewSegment('stationary');
        _state = DetectionState.possible_stop;
        _possibleStopStartedAt = now;
      } else if (isMovingForContinue) {
        final candidate = _classifyMode(
          speed,
          accelVar,
          accelMad,
          activityHint: _lastActivityHint,
          gpsStale: gpsStale,
          lastKnownMode: _currentSegment?.mode,
        );
        final activityWeighted =
            _lastActivityHint != null && (now - _lastActivityHintAt) < 3000;
        _pushModeCandidate(candidate, activityWeighted: activityWeighted);
      }
    } else if (_state == DetectionState.possible_stop) {
      final canStop = tripAge >= 15000;
      final curMode = _currentSegment?.mode ?? 'unknown';
      final stopThreshold = fullStopAfterIdleSec;
      final adaptiveFullStop = _adaptiveStopThreshold(curMode);
      final effectiveFullStopSec = max(stopThreshold, adaptiveFullStop);

      if (isMovingForContinue) {
        _possibleStopStartedAt = 0;
        _state = DetectionState.collecting;
        final candidate = _classifyMode(
          speed,
          accelVar,
          accelMad,
          activityHint: _lastActivityHint,
          gpsStale: gpsStale,
          lastKnownMode: _currentSegment?.mode,
        );
        final activityWeighted =
            _lastActivityHint != null && (now - _lastActivityHintAt) < 3000;
        _pushModeCandidate(candidate, activityWeighted: activityWeighted);
        return;
      }

      final idleSincePossibleStop =
          _possibleStopStartedAt > 0 ? now - _possibleStopStartedAt : 0;
      if (!isMovingForContinue &&
          idleSincePossibleStop >= effectiveFullStopSec * 1000 &&
          canStop) {
        stopInternal();
        _state = DetectionState.idle;
        _possibleStopStartedAt = 0;
      }
    }
  }

  Future<void> startManual([String? forcedMode]) async {
    if (collecting) return;
    final mode = forcedMode ?? 'auto-detect';
    await startInternal(mode);
  }

  Future<void> _startNewSegment(String mode) async {
    if (_currentSegment != null) {
      _currentSegment!.end = DateTime.now().toUtc();

      _tGraph.addTransition(_previousSegmentMode, _currentSegment!.mode, mode);

      _previousSegmentMode = _currentSegment!.mode;

      if(!_segmentsController.isClosed) _segmentsController.add(_currentSegment!);
    }
    _currentSegment = TripSegment(
      id: _uuid.v4(),
      start: DateTime.now().toUtc(),
      mode: mode,
    );
    _currentTrip.segments.add(_currentSegment!);
    if(!_segmentsController.isClosed) _segmentsController.add(_currentSegment!);
    _lastModeChangeAt = DateTime.now().toUtc().millisecondsSinceEpoch;
  }

  Future<void> stopManual() async {
    if (!collecting) return;
    await stopInternal();
  }

  void _resetSoftState() {
    final int rollingBufferSec = 10;
    final int rollingAccelSamples = 20;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    _gpsBuffer.retainWhere(
      (e) => (now - (e['ts'] as int)) <= (rollingBufferSec * 1000),
    );
    if (_accelBuffer.length > rollingAccelSamples) {
      _accelBuffer.removeRange(0, _accelBuffer.length - rollingAccelSamples);
    }
    _modeHistory.clear();
    _lastActivityHint = null;
    _lastActivityHintAt = 0;
    _lastMovingDetectedAt = 0;
    _lastIdleDetectedAt = 0;
    _possibleStopStartedAt = 0;
    _possibleStartBeganAt = 0;
    _kickWatchdog();
  }

  double _calculateTotalDistance(Trip t) {
    double totalDistance = 0.0;
    final allPoints =
        t.segments
            .expand((seg) => seg.gps)
            .map(
              (p) => LatLng(
                (p['lat'] as num).toDouble(),
                (p['lng'] as num).toDouble(),
              ),
            )
            .toList();

    if (allPoints.length < 2) {
      return 0.0;
    }

    for (int i = 0; i < allPoints.length - 1; i++) {
      totalDistance += Geolocator.distanceBetween(
        allPoints[i].latitude,
        allPoints[i].longitude,
        allPoints[i + 1].latitude,
        allPoints[i + 1].longitude,
      );
    }
    return totalDistance;
  }

  Map<String, dynamic> _sanitizeTrip(Trip t) {
    final segments =
        t.segments.map((s) {
          final gps =
              s.gps.map((p) {
                return {
                  'lat': double.parse((p['lat'] as double).toStringAsFixed(5)),
                  'lng': double.parse((p['lng'] as double).toStringAsFixed(5)),
                  'ts': p['ts'],
                };
              }).toList();
          return {
            'id': s.id,
            'start': s.start.toUtc().toIso8601String(),
            'end': s.end?.toUtc().toIso8601String(),
            'mode': s.mode,
            'gps': gps,
            'accel': s.accel,
            'bt': s.bt,
          };
        }).toList();

    return {
      'id': t.id,
      'anonUserId': t.anonUserId,
      'createdAt': t.createdAt.toUtc().toIso8601String(),
      'segments': segments,
      'companions': t.companions,
      'uploaded': false,
      'distance': _calculateTotalDistance(t),
    };
  }

  Map<String, Map<String, int>> exportTransitionGraph() =>
      _tGraph.exportGraph();

  void _kickWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer(_watchdogTimeout, _resetSubscriptionsAndSensors);
  }

  void _resetSubscriptionsAndSensors() {
    print('Watchdog: resetting sensors/subscriptions.');
    try {
      _gpsSub?.cancel();
      _accelSub?.cancel();
      _btSub?.cancel();
      _activitySub?.cancel();
      gps.start();
      accel.start();
      bt.startPeriodicScan();
      activity.start();
      _attachSubscriptions();
    } catch (e) {
      print('sensor restart error: $e');
    }
    _kickWatchdog();
  }
}

