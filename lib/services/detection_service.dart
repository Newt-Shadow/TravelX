import 'dart:async';
import 'dart:math';
import 'package:TravelX/models/trip.dart';
import 'package:TravelX/screens/trip_completion_screen.dart';
import 'package:TravelX/services/activity_service.dart';
import 'package:TravelX/services/auth_service.dart';
import 'package:TravelX/services/notification_service.dart';
import 'package:TravelX/services/sync_service.dart';
import 'package:TravelX/utils/filters.dart';
import 'package:TravelX/utils/graph_learning.dart';
import 'package:flutter/material.dart';
import 'package:flutter_activity_recognition/flutter_activity_recognition.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import 'accel_service.dart';
import 'bluetooth_service.dart';
import 'gps_service.dart';
import 'storage_service.dart';

enum DetectionState { idle, possible_start, collecting, possible_stop }

class DetectionService {
  TripSegment? get currentSegment => _currentSegment;
  DetectionState get state => _state;

  static const _kMaxWalkSpeed = 2.5; // m/s
  static const _kMaxBikeSpeed = 8.0; // m/s
  static const _kMinVehicleSpeed = 4.0; // m/s
  static const _kMinTrainSpeed = 15.0; // m/s
  static const _kRunAccelVarThreshold = 2.0;
  static const _kBusAccelVarThreshold = 0.08;
  static const _kGpsDisplacementThreshold = 3.0; // meters

  static const _kMinValidTripDurationSec = 30; // seconds
  static const _kMinValidTripDistanceMeters = 3.0; // meters
  static const _kContinuationGapMin = 2; // minutes

  final GpsService gps;
  final AccelService accel;
  final BluetoothService bt;
  final ActivityService activity;
  final _uuid = const Uuid();

  final ContextualTransitionGraph _tGraph;

  double _movementConfidence = 0.0;
  static const _kMovementConfidenceStartThreshold = 0.7;
  static const _kMovementConfidenceStopThreshold = 0.2;
  static const _kConfidenceIncrement = 0.15;
  static const _kConfidenceDecrement = 0.10;

  int _lastStopTime = 0; // ms
  final int _tripStartCooldownSec = 5;
  String? _previousSegmentMode;

  final List<Map<String, dynamic>> _gpsBuffer = [];
  final List<double> _accelBuffer = [];
  final int gpsWindowSec = 8;
  final int accelWindow = 30;

  final int startConsensusSec = 6;
  final int stopConsensusSec = 5;
  final int fullStopAfterIdleSec = 5;
  final int _minSegmentDurationSec = 4;
  final Duration _watchdogTimeout = const Duration(minutes: 5);

  int _lastMovingDetectedAt = 0;
  int _lastIdleDetectedAt = 0;
  int _lastGpsUpdateAt = 0;
  int _lastActivityHintAt = 0;
  int _lastModeChangeAt = 0;
  int _possibleStopStartedAt = 0;
  int _possibleStartBeganAt = 0;

  bool collecting = false;
  late Trip _currentTrip;
  TripSegment? _currentSegment;
  DetectionState _state = DetectionState.idle;

  final List<String> _modeHistory = [];
  final int _hysteresisN = 3;
  String? _lastActivityHint;

  StreamSubscription<Position>? _gpsSub;
  StreamSubscription<double>? _accelSub;
  StreamSubscription<List>? _btSub;
  StreamSubscription<Activity>? _activitySub;
  Timer? _watchdogTimer;

  final StreamController<TripSegment> _segmentsController =
      StreamController.broadcast();
  Stream<TripSegment> get segmentsStream => _segmentsController.stream;

  final StreamController<Trip> _tripCompletionController =
      StreamController.broadcast();
  Stream<Trip> get tripCompletionStream => _tripCompletionController.stream;

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
      bt.startPeriodicScan();
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
    if (!_tripCompletionController.isClosed) {
      _tripCompletionController.close();
    }
    gps.stop();
    accel.stop();
    bt.stopScan();
    bt.stopPassiveAdvertising();
    bt.stopActiveAdvertising();
    activity.stop();
    _watchdogTimer?.cancel();
  }

  Future<void> startInternal(String detectedMode) async {
    if (detectedMode == 'stationary' || detectedMode == 'unknown') return;

    final userId = AuthService.currentUserId;

    if (userId == null) {
      print("⛔ Cannot start trip, user is not logged in.");
      collecting = false;
      _state = DetectionState.idle;
      return;
    }

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

    if (!_segmentsController.isClosed) {
      _segmentsController.add(_currentSegment!);
    }
    NotificationService.showOngoing('Trip started', 'Mode: $detectedMode');

    _lastMovingDetectedAt = DateTime.now().toUtc().millisecondsSinceEpoch;
    _modeHistory.clear();
    _lastModeChangeAt = DateTime.now().toUtc().millisecondsSinceEpoch;
  }

  Future<void> stopInternal() async {
    if (!collecting) return;

    bt.stopActiveAdvertising();
    bt.startPeriodicScan();

    collecting = false;
    _state = DetectionState.idle;
    _currentSegment?.end = DateTime.now().toUtc();
    final tripEndTime = DateTime.now().toUtc().millisecondsSinceEpoch;

    final tripDurationMs =
        tripEndTime - _currentTrip.createdAt.millisecondsSinceEpoch;
    final totalDistance = _calculateTotalDistance(_currentTrip);

    final isShortTrip = tripDurationMs < (_kMinValidTripDurationSec * 1000) ||
        totalDistance < _kMinValidTripDistanceMeters;

    if (isShortTrip) {
      print(
          "🗑 Discarding short/insignificant trip (Duration: ${tripDurationMs / 1000}s, Distance: ${totalDistance.toStringAsFixed(1)}m).");
      _lastStopTime = tripEndTime;
      NotificationService.cancelOngoing();
      NotificationService.showOneShot(
          'Trip Discarded', 'Movement was too short or insignificant.');

      if (_currentSegment != null && !_segmentsController.isClosed) {
        _segmentsController.add(_currentSegment!);
      }
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

    if (!_tripCompletionController.isClosed) {
      _tripCompletionController.add(_currentTrip);
    }

    if (_currentSegment != null && !_segmentsController.isClosed) {
      _segmentsController.add(_currentSegment!);
    }
    _currentSegment = null;
    _resetSoftState();
  }

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
      final arr = results.map((r) {
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
      final hintIsFresh = (activityHint != null &&
          _lastActivityHintAt > 0 &&
          (now - _lastActivityHintAt) < 20000);

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

      if (lastKnownMode == 'car' ||
          lastKnownMode == 'bus' ||
          lastKnownMode == 'train') {
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
        : (_lastActivityHintAt > 0 && (now - _lastActivityHintAt) < 5000
            ? _lastActivityHint
            : null);

    if (speed < 0.1 && accelVar < max(0.008, accelMad * 1.5)) {
      return 'stationary';
    }

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

  bool _validateActivityWithAccel(
      String activity, double accelVar, double accelMad) {
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

  String _classifyFromAccelerometer(
      double accelVar, double accelMad, String? lastKnownMode) {
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
    return accelVar > 0.2 &&
        accelVar < 1.8 &&
        accelMad > 0.08 &&
        accelMad < 0.4 &&
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

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    if (_lastStopTime > 0 &&
        (now - _lastStopTime) < _tripStartCooldownSec * 1000) {
      return;
    }

    final gpsAgeMs = _lastGpsUpdateAt > 0 ? now - _lastGpsUpdateAt : 999999;
    final gpsStale = gpsAgeMs > 15000;

    bool isMoving = false;
    if (!gpsStale && disp > _kGpsDisplacementThreshold) {
      isMoving = true;
    } else if (accelVar > 0.05) {
      isMoving = true;
    } else if (speed > 1.0) {
      isMoving = true;
    }

    if (isMoving) {
      _movementConfidence =
          min(1.0, _movementConfidence + _kConfidenceIncrement);
      _lastMovingDetectedAt = now;
    } else {
      _movementConfidence =
          max(0.0, _movementConfidence - _kConfidenceDecrement);
      _lastIdleDetectedAt = now;
    }

    if (_state == DetectionState.idle) {
      if (_movementConfidence > _kMovementConfidenceStartThreshold) {
        _state = DetectionState.possible_start;
        _possibleStartBeganAt = now;
      }
    } else if (_state == DetectionState.possible_start) {
      if (_movementConfidence < _kMovementConfidenceStartThreshold / 2) {
        _state = DetectionState.idle;
        _possibleStartBeganAt = 0;
        return;
      }

      if (now - _possibleStartBeganAt >= startConsensusSec * 1000) {
        final candidate = _classifyMode(
          speed,
          accelVar,
          metrics['accelMad'],
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
      if (_movementConfidence < _kMovementConfidenceStopThreshold) {
        _state = DetectionState.possible_stop;
        _possibleStopStartedAt = now;
        _startNewSegment('stationary');
      } else {
        final candidate = _classifyMode(
          speed,
          accelVar,
          metrics['accelMad'],
          gpsStale: gpsStale,
          lastKnownMode: _currentSegment?.mode,
        );
        _pushModeCandidate(candidate);
      }
    } else if (_state == DetectionState.possible_stop) {
      if (_movementConfidence > _kMovementConfidenceStartThreshold) {
        _state = DetectionState.collecting;
        _possibleStopStartedAt = 0;
        final candidate = _classifyMode(
          speed,
          accelVar,
          metrics['accelMad'],
          gpsStale: gpsStale,
          lastKnownMode: _currentSegment?.mode,
        );
        _startNewSegment(candidate);
        return;
      }

      final idleSincePossibleStop =
          _possibleStopStartedAt > 0 ? now - _possibleStopStartedAt : 0;
      final stopThreshold =
          _adaptiveStopThreshold(_currentSegment?.mode ?? 'unknown');

      if (idleSincePossibleStop >= stopThreshold * 1000) {
        stopInternal();
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

      if (!_segmentsController.isClosed) {
        _segmentsController.add(_currentSegment!);
      }
    }
    _currentSegment = TripSegment(
      id: _uuid.v4(),
      start: DateTime.now().toUtc(),
      mode: mode,
    );
    _currentTrip.segments.add(_currentSegment!);
    if (!_segmentsController.isClosed) {
      _segmentsController.add(_currentSegment!);
    }
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
    _movementConfidence = 0.0;
    _kickWatchdog();
  }

  double _calculateTotalDistance(Trip t) {
    double totalDistance = 0.0;
    final allPoints = t.segments
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
    final segments = t.segments.map((s) {
      final gps = s.gps.map((p) {
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