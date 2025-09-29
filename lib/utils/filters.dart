// utils/filters.dart
/// Utility filters (moving average, high-pass functions).
class Filters {
  static double movingAverage(List<double> buffer) {
    if (buffer.isEmpty) return 0.0;
    return buffer.reduce((a, b) => a + b) / buffer.length;
  }

  /// Compute variance of recent list
  static double variance(List<double> buffer) {
    if (buffer.length < 2) return 0.0;
    final mean = movingAverage(buffer);
    double s = 0;
    for (final v in buffer) s += (v - mean) * (v - mean);
    return s / buffer.length;
  }
}
