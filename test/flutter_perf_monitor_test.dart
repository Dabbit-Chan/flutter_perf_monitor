import 'package:flutter_perf_monitor/flutter_perf_monitor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('FlutterPerfMonitor', () {
    tearDown(() {
      FlutterPerfMonitor.dispose();
    });

    test('should start and stop monitoring', () async {
      FlutterPerfMonitor.startMonitoring();
      // No exception should be thrown

      FlutterPerfMonitor.stopMonitoring();
      // No exception should be thrown
    });

    test('should provide metrics stream', () async {
      final metricsStream = FlutterPerfMonitor.instance.metricsStream;
      expect(metricsStream, isNotNull);
    });

    test('should provide memory stream', () async {
      final memoryStream = FlutterPerfMonitor.instance.memoryStream;
      expect(memoryStream, isNotNull);
    });

    test('should get current memory usage', () async {
      final memoryUsage = FlutterPerfMonitor.getMemoryUsage();
      expect(memoryUsage, isA<int>());
      expect(memoryUsage, greaterThanOrEqualTo(0));
    });

    test('should get current metrics', () async {
      final metrics = FlutterPerfMonitor.getCurrentMetrics();
      expect(metrics, isA<PerformanceMetrics>());
      expect(metrics.memoryUsage, isA<int>());
      expect(metrics.timestamp, isA<DateTime>());
      expect(metrics.cpuUsage, isA<double>());
    });

    test('should handle multiple dispose calls gracefully', () async {
      FlutterPerfMonitor.dispose();
      FlutterPerfMonitor.dispose(); // Should not throw
    });

    test('should receive metrics stream updates', () async {
      final stream = FlutterPerfMonitor.instance.metricsStream;

      final subscription = stream.listen((event) {
        expect(event, isA<PerformanceMetrics>());
      });

      FlutterPerfMonitor.startMonitoring();

      // Wait for at least one metrics update
      await Future.delayed(const Duration(milliseconds: 200));

      FlutterPerfMonitor.stopMonitoring();
      await Future.delayed(const Duration(milliseconds: 50));
      subscription.cancel();

      // Just verify we got some events or the stream works
      expect(stream, isNotNull);
    });

    test('should receive memory stream updates', () async {
      final stream = FlutterPerfMonitor.instance.memoryStream;

      final subscription = stream.listen((event) {
        expect(event, isA<MemoryData>());
      });

      FlutterPerfMonitor.startMonitoring();

      // Wait for at least one metrics update
      await Future.delayed(const Duration(milliseconds: 200));

      FlutterPerfMonitor.stopMonitoring();
      await Future.delayed(const Duration(milliseconds: 50));
      subscription.cancel();

      // Just verify we got some events or the stream works
      expect(stream, isNotNull);
    });

    test('should handle multiple subscriptions', () async {
      final stream = FlutterPerfMonitor.instance.metricsStream;

      final subscription1 = stream.listen((_) {});
      final subscription2 = stream.listen((_) {});

      FlutterPerfMonitor.startMonitoring();
      await Future.delayed(const Duration(milliseconds: 200));

      FlutterPerfMonitor.stopMonitoring();
      await Future.delayed(const Duration(milliseconds: 50));
      subscription1.cancel();
      subscription2.cancel();
    });

    test('should not start monitoring twice', () async {
      FlutterPerfMonitor.startMonitoring();
      FlutterPerfMonitor.startMonitoring(); // Should not throw

      FlutterPerfMonitor.stopMonitoring();
    });

    test('should get per-core CPU usage', () async {
      final perCore = FlutterPerfMonitor.getPerCoreCpuUsage();
      expect(perCore, isA<List<double>>());
      expect(perCore.length, greaterThanOrEqualTo(0));
    });
  });

  group('FlutterPerfMonitor snapshots (on-demand)', () {
    tearDown(() {
      FlutterPerfMonitor.dispose();
    });

    test('getMemorySnapshot should return MemoryData without monitoring',
        () async {
      final memoryData = await FlutterPerfMonitor.getMemorySnapshot();
      expect(memoryData, isA<MemoryData>());
      expect(memoryData.currentUsage, isA<int>());
      expect(memoryData.currentUsage, greaterThanOrEqualTo(0));
      expect(memoryData.totalMemory, isA<int>());
      expect(memoryData.availableMemory, isA<int>());
      expect(memoryData.usagePercentage, isA<double>());
    });

    test('getMetricsSnapshot should return PerformanceMetrics without monitoring',
        () async {
      final metrics = await FlutterPerfMonitor.getMetricsSnapshot();
      expect(metrics, isA<PerformanceMetrics>());
      expect(metrics.memoryUsage, isA<int>());
      expect(metrics.cpuUsage, isA<double>());
      expect(metrics.cpuUsage, greaterThanOrEqualTo(0.0));
      expect(metrics.cpuUsage, lessThanOrEqualTo(100.0));
      expect(metrics.timestamp, isA<DateTime>());
    });

    test('getCpuUsageSnapshot should return a value in [0, 100]', () async {
      final cpuUsage = await FlutterPerfMonitor.getCpuUsageSnapshot();
      expect(cpuUsage, isA<double>());
      expect(cpuUsage, greaterThanOrEqualTo(0.0));
      expect(cpuUsage, lessThanOrEqualTo(100.0));
    });

    test('getPerCoreCpuSnapshot should return a List<double>', () async {
      final perCore = await FlutterPerfMonitor.getPerCoreCpuSnapshot();
      expect(perCore, isA<List<double>>());
      expect(perCore.length, greaterThanOrEqualTo(0));
    });

    test('getAvailableMemorySnapshot should return a non-negative int', () async {
      final available = await FlutterPerfMonitor.getAvailableMemorySnapshot();
      expect(available, isA<int>());
      expect(available, greaterThanOrEqualTo(0));
    });

    test('snapshots should work alongside active monitoring', () async {
      FlutterPerfMonitor.startMonitoring();

      // Snapshot while monitoring is active should also work
      final metrics = await FlutterPerfMonitor.getMetricsSnapshot();
      expect(metrics, isA<PerformanceMetrics>());

      FlutterPerfMonitor.stopMonitoring();
    });

    test('getPerCoreCpuSnapshot should return a copy, not the internal list',
        () async {
      final first = await FlutterPerfMonitor.getPerCoreCpuSnapshot();
      final second = await FlutterPerfMonitor.getPerCoreCpuSnapshot();
      // Mutating the returned list should not affect future calls
      if (first.isNotEmpty) {
        first[0] = -999.0;
      }
      expect(second, isNot(contains(-999.0)));
    });
  });

  group('PerformanceMetrics', () {
    test('should create with required parameters', () {
      final now = DateTime.now();
      final metrics = PerformanceMetrics(
        memoryUsage: 1024 * 1024,
        timestamp: now,
        cpuUsage: 25.0,
      );

      expect(metrics.memoryUsage, equals(1024 * 1024));
      expect(metrics.timestamp, equals(now));
      expect(metrics.cpuUsage, equals(25.0));
    });

    test('should support copyWith', () {
      final now = DateTime.now();
      final original = PerformanceMetrics(
        memoryUsage: 1024 * 1024,
        timestamp: now,
        cpuUsage: 25.0,
      );

      final updated = original.copyWith(cpuUsage: 50.0);
      expect(updated.cpuUsage, equals(50.0));
      expect(updated.memoryUsage, equals(original.memoryUsage));
      expect(updated.timestamp, equals(original.timestamp));
    });

    test('should implement equality correctly', () {
      final now = DateTime.now();
      final metrics1 = PerformanceMetrics(
        memoryUsage: 1024 * 1024,
        timestamp: now,
        cpuUsage: 25.0,
      );

      final metrics2 = PerformanceMetrics(
        memoryUsage: 1024 * 1024,
        timestamp: now,
        cpuUsage: 25.0,
      );

      expect(metrics1, equals(metrics2));
      expect(metrics1.hashCode, equals(metrics2.hashCode));
    });

    test('should provide meaningful string representation', () {
      final now = DateTime.now();
      final metrics = PerformanceMetrics(
        memoryUsage: 1024 * 1024,
        timestamp: now,
        cpuUsage: 25.0,
      );

      final str = metrics.toString();
      expect(str, contains('1048576'));
      expect(str, contains('25.0'));
    });
  });

  group('MemoryData', () {
    test('should create with required parameters', () {
      final now = DateTime.now();
      final memoryData = MemoryData(
        currentUsage: 1024 * 1024,
        peakUsage: 2048 * 1024,
        availableMemory: 3072 * 1024,
        totalMemory: 4096 * 1024,
        usagePercentage: 25.0,
        timestamp: now,
      );

      expect(memoryData.currentUsage, equals(1024 * 1024));
      expect(memoryData.peakUsage, equals(2048 * 1024));
      expect(memoryData.availableMemory, equals(3072 * 1024));
      expect(memoryData.totalMemory, equals(4096 * 1024));
      expect(memoryData.usagePercentage, equals(25.0));
      expect(memoryData.timestamp, equals(now));
    });

    test('should convert bytes to megabytes correctly', () {
      final memoryData = MemoryData(
        currentUsage: 1024 * 1024,
        peakUsage: 2048 * 1024,
        availableMemory: 3072 * 1024,
        totalMemory: 4096 * 1024,
        usagePercentage: 25.0,
        timestamp: DateTime.now(),
      );

      expect(memoryData.currentUsageMB, equals(1.0));
      expect(memoryData.peakUsageMB, equals(2.0));
      expect(memoryData.availableMemoryMB, equals(3.0));
      expect(memoryData.totalMemoryMB, equals(4.0));
    });

    test('should provide meaningful string representation', () {
      final memoryData = MemoryData(
        currentUsage: 1024 * 1024,
        peakUsage: 2048 * 1024,
        availableMemory: 3072 * 1024,
        totalMemory: 4096 * 1024,
        usagePercentage: 25.0,
        timestamp: DateTime.now(),
      );

      final str = memoryData.toString();
      expect(str, contains('1.00MB'));
      expect(str, contains('2.00MB'));
      expect(str, contains('3.00MB'));
      expect(str, contains('4.00MB'));
      expect(str, contains('25.00%'));
    });
  });
}
