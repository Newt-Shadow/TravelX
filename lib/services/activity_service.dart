import 'dart:async';
import 'package:flutter_activity_recognition/flutter_activity_recognition.dart';
import 'package:collection/collection.dart';

/// Advanced wrapper around flutter_activity_recognition
/// - Broadcast stream
/// - Confidence filtering
/// - Automatic restart on failure
/// - Pause/resume support
/// - Latest activity caching
class ActivityService {
  final FlutterActivityRecognition _ar = FlutterActivityRecognition.instance;
  StreamSubscription<Activity>? _sub;
  final StreamController<Activity> _controller = StreamController<Activity>.broadcast();
  final int minConfidence; // Minimum confidence (0-100) to emit an event
  final Duration restartDelay; // Delay before restarting after error

  bool _isRunning = false;
  Activity? _latestActivity;

  Stream<Activity> get stream => _controller.stream;
  Activity? get latestActivity => _latestActivity;

  ActivityService({this.minConfidence = 60, this.restartDelay = const Duration(seconds: 3)});

  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _subscribe();
  }

  void stop() {
    _isRunning = false;
    _sub?.cancel();
    _sub = null;
  }

  void _subscribe() {
    try {
      _sub = _ar.activityStream.listen(
        (activity) {
          // Only emit if confidence >= threshold
          final conf = _mapConfidenceToInt(activity.confidence);
          if (conf >= minConfidence) {
            _latestActivity = activity;
            _controller.add(activity);
          }
        },
        onError: (err) async {
          _controller.addError(err);
          // Retry after a short delay if still running
          if (_isRunning) {
            await Future.delayed(restartDelay);
            _subscribe();
          }
        },
        onDone: () async {
          if (_isRunning) {
            await Future.delayed(restartDelay);
            _subscribe();
          }
        },
        cancelOnError: true,
      );
    } catch (e, st) {
      _controller.addError(e, st);
      // fallback retry
      if (_isRunning) {
        Future.delayed(restartDelay, _subscribe);
      }
    }
  }

  /// Map ActivityConfidence enum to integer 0-100
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

  /// Pause the stream without disposing subscriptions
  void pause() {
    _sub?.pause();
  }

  /// Resume the stream
  void resume() {
    _sub?.resume();
  }

  /// Force re-emit latest activity (useful for UI sync)
  void emitLatest() {
    if (_latestActivity != null) _controller.add(_latestActivity!);
  }

  void dispose() {
    stop();
    _controller.close();
  }
}
