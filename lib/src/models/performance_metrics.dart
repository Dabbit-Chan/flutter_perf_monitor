/// Represents overall performance metrics for a Flutter application.
class PerformanceMetrics {
  /// Creates a new PerformanceMetrics instance.
  ///
  /// [memoryUsage] - Current memory usage in bytes
  /// [timestamp] - Timestamp when metrics were collected
  /// [cpuUsage] - CPU usage percentage
  const PerformanceMetrics({
    required this.memoryUsage,
    required this.timestamp,
    required this.cpuUsage,
  });

  /// Current memory usage in bytes
  final int memoryUsage;

  /// Timestamp when metrics were collected
  final DateTime timestamp;

  /// CPU usage percentage
  final double cpuUsage;

  /// Creates a copy of this object with the given fields replaced by new values.
  PerformanceMetrics copyWith({
    int? memoryUsage,
    DateTime? timestamp,
    double? cpuUsage,
  }) {
    return PerformanceMetrics(
      memoryUsage: memoryUsage ?? this.memoryUsage,
      timestamp: timestamp ?? this.timestamp,
      cpuUsage: cpuUsage ?? this.cpuUsage,
    );
  }

  @override
  String toString() {
    return 'PerformanceMetrics(memoryUsage: $memoryUsage, '
        'timestamp: $timestamp, cpuUsage: $cpuUsage)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PerformanceMetrics &&
        other.memoryUsage == memoryUsage &&
        other.timestamp == timestamp &&
        other.cpuUsage == cpuUsage;
  }

  @override
  int get hashCode {
    return Object.hash(memoryUsage, timestamp, cpuUsage);
  }
}
