// services/accel_service.dart
import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

/// Robust accelerometer processing:
/// - Gravity estimation via low-pass filter
/// - Use gyroscope to improve linear accel estimation (complementary idea)
/// - IIR high-pass to remove very low-frequency drift (earth rotation/gravity residual)
/// - Hampel outlier removal for spikes
/// - Median + moving average smoothing
/// - Exposes a linearMagnitude stream (double) suitable for variance / detection
class AccelService {
  StreamSubscription<AccelerometerEvent>? _accSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  final StreamController<double> _linearMagController = StreamController.broadcast();

  // gravity estimate per axis (low-pass)
  double gx = 0.0, gy = 0.0, gz = 0.0;

  // previous raw to use in IIR high-pass filter
  double _prevRawX = 0.0, _prevRawY = 0.0, _prevRawZ = 0.0;
  double _prevHpX = 0.0, _prevHpY = 0.0, _prevHpZ = 0.0;

  // filter settings - you can tune these
  final double gravityAlpha = 0.96; // LPF for gravity estimate (0.9-0.99)
  final double hpAlpha = 0.9; // high-pass IIR coefficient (closer to 1 -> lower cutoff)
  final int medianWindow = 5; // median smoothing window (odd)
  final int movingAvgWindow = 6; // moving average window
  final int hampelWindow = 7; // window for Hampel outlier detection
  final double hampelThresholdK = 3.0; // Hampel k multiplier

  // buffers
  final Queue<double> _medianBuf = Queue();
  final Queue<double> _avgBuf = Queue();
  final List<double> _hampelBuf = [];

  // Expose stream
  Stream<double> get linearMagnitude => _linearMagController.stream;

  void start() {
    // subscribe to gyroscope to optionally improve gravity removal (simple complementary)
    _gyroSub = gyroscopeEvents.listen((g) {
      // We don't use it as a full fusion algorithm here (too heavy),
      // but we keep it in case you want to expand: currently ignored.
      // Could be used to reduce LPF alpha dynamically when device rotating fast.
    }, onError: (e) {
      // ignore
    });

    _accSub = accelerometerEvents.listen(_onAccel, onError: (e) {
      _linearMagController.addError(e);
    });
  }

  void stop() {
    _accSub?.cancel();
    _accSub = null;
    _gyroSub?.cancel();
    _gyroSub = null;
    _medianBuf.clear();
    _avgBuf.clear();
    _hampelBuf.clear();
  }

  void _onAccel(AccelerometerEvent ev) {
    // 1) Low-pass filter for gravity estimate
    gx = gravityAlpha * gx + (1 - gravityAlpha) * ev.x;
    gy = gravityAlpha * gy + (1 - gravityAlpha) * ev.y;
    gz = gravityAlpha * gz + (1 - gravityAlpha) * ev.z;

    // 2) Raw linear = raw - gravity
    final rawX = ev.x - gx;
    final rawY = ev.y - gy;
    final rawZ = ev.z - gz;

    // 3) IIR high-pass to remove residual very-low-frequency components
    // hp: y[n] = alpha * (y[n-1] + x[n] - x[n-1])
    final hpX = hpAlpha * (_prevHpX + rawX - _prevRawX);
    final hpY = hpAlpha * (_prevHpY + rawY - _prevRawY);
    final hpZ = hpAlpha * (_prevHpZ + rawZ - _prevRawZ);

    _prevRawX = rawX;
    _prevRawY = rawY;
    _prevRawZ = rawZ;
    _prevHpX = hpX;
    _prevHpY = hpY;
    _prevHpZ = hpZ;

    // magnitude of high-passed linear accel
    final mag = sqrt(hpX * hpX + hpY * hpY + hpZ * hpZ);

    // 4) Hampel sliding window spike rejection (keep small buffer)
    _hampelBuf.add(mag);
    if (_hampelBuf.length > hampelWindow) _hampelBuf.removeAt(0);
    final filtered = _hampelFilter(_hampelBuf, mag, hampelThresholdK);

    // 5) median smoothing
    _medianBuf.add(filtered);
    if (_medianBuf.length > medianWindow) _medianBuf.removeFirst();
    final median = _median(_medianBuf.toList());

    // 6) moving average smoothing
    _avgBuf.add(median);
    if (_avgBuf.length > movingAvgWindow) _avgBuf.removeFirst();
    final avg = _avgBuf.isEmpty ? median : _avgBuf.reduce((a, b) => a + b) / _avgBuf.length;

    // emit a value that's smooth but still retains motion features
    _linearMagController.add(avg);
  }

  // Hampel filter: if value is a spike outside k*MAD, replace with median
  double _hampelFilter(List<double> window, double value, double k) {
    if (window.isEmpty) return value;
    final w = List<double>.from(window)..sort();
    final med = _median(w);
    final mad = _mad(w, med);
    if (mad == 0) return value; // no variation, pass through
    if ((value - med).abs() > k * mad) {
      return med; // replace spike
    }
    return value;
  }

  double _median(List<double> a) {
    if (a.isEmpty) return 0.0;
    final b = List<double>.from(a)..sort();
    final n = b.length;
    if (n % 2 == 1) return b[n ~/ 2];
    return 0.5 * (b[n ~/ 2 - 1] + b[n ~/ 2]);
  }

  // median absolute deviation (normalized)
  double _mad(List<double> a, double med) {
    if (a.isEmpty) return 0.0;
    final absDev = a.map((v) => (v - med).abs()).toList()..sort();
    return _median(absDev);
  }
}
