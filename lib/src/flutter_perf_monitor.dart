import 'dart:async';
// Conditional import for ProcessInfo (not available on web)
import 'dart:io' if (dart.library.html) 'flutter_perf_monitor_stub.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// JavaScript interop for web memory API (only available on web)
// Use stub on non-web platforms, dart:js on web
import 'flutter_perf_monitor_stub.dart' if (dart.library.html) 'dart:js' as js;
import 'models/memory_data.dart';
import 'models/performance_metrics.dart';

/// Main class for Flutter performance monitoring.
///
/// This class provides real-time performance monitoring capabilities including
/// memory usage monitoring, CPU usage monitoring, and performance metrics collection.
class FlutterPerfMonitor {
  static FlutterPerfMonitor? _instance;

  /// Gets the singleton instance of FlutterPerfMonitor.
  ///
  /// This getter ensures only one instance exists throughout the app lifecycle.
  static FlutterPerfMonitor get instance =>
      _instance ??= FlutterPerfMonitor._();

  FlutterPerfMonitor._();

  bool _isMonitoring = false;
  Timer? _monitoringTimer;

  int _peakMemoryUsage = 0;
  int _totalMemory = 0;
  int _availableMemory = 0;
  double _currentCpuUsage = 0.0;
  List<double> _perCoreCpuUsage = [];
  bool _hasLoggedMemoryWarning = false;
  static const MethodChannel _channel = MethodChannel('flutter_perf_monitor');

  final StreamController<PerformanceMetrics> _metricsController =
      StreamController<PerformanceMetrics>.broadcast();

  final StreamController<MemoryData> _memoryController =
      StreamController<MemoryData>.broadcast();

  /// Stream of performance metrics updates
  Stream<PerformanceMetrics> get metricsStream => _metricsController.stream;

  /// Stream of memory data updates
  Stream<MemoryData> get memoryStream => _memoryController.stream;

  /// Start performance monitoring
  ///
  /// Begins collecting performance metrics at regular intervals.
  /// The monitoring frequency can be adjusted by changing the [interval] parameter.
  static void startMonitoring({
    Duration interval = const Duration(milliseconds: 100),
  }) {
    if (instance._isMonitoring) return;

    instance._isMonitoring = true;
    instance._monitoringTimer = Timer.periodic(interval, (timer) async {
      await instance._collectMetrics();
    });

    if (kDebugMode) {
      debugPrint('Performance monitoring started');
    }
  }

  /// Stop performance monitoring
  ///
  /// Stops collecting performance metrics and cleans up resources.
  static void stopMonitoring() {
    if (!instance._isMonitoring) return;

    instance._isMonitoring = false;
    instance._monitoringTimer?.cancel();
    instance._monitoringTimer = null;

    if (kDebugMode) {
      debugPrint('Performance monitoring stopped');
    }
  }

  /// Get current memory usage in bytes
  static int getMemoryUsage() {
    return instance._getCurrentMemoryUsage();
  }

  /// Get total device memory in bytes
  static int getTotalMemory() {
    return instance._totalMemory;
  }

  /// Get current performance metrics
  static PerformanceMetrics getCurrentMetrics() {
    return instance._createPerformanceMetrics();
  }

  /// Get per-core CPU usage
  static List<double> getPerCoreCpuUsage() {
    return instance._perCoreCpuUsage;
  }

  // ===========================================================================
  //  On-demand snapshot methods
  //
  //  These methods perform a single, self-contained measurement without
  //  requiring startMonitoring()/stopMonitoring(). Each call fetches fresh
  //  data from the native platform where applicable.
  // ===========================================================================

  /// Get a one-time memory data snapshot without continuous monitoring.
  ///
  /// Fetches fresh memory information from the native platform (total memory,
  /// available memory) and combines it with the current process RSS usage to
  /// produce a complete [MemoryData] object.
  ///
  /// This method does NOT require [startMonitoring] to have been called.
  static Future<MemoryData> getMemorySnapshot() async {
    await instance._updateNativeMetrics();
    return instance._createMemoryData();
  }

  /// Get a one-time complete performance metrics snapshot.
  ///
  /// Fetches fresh native metrics (memory and CPU) and returns a combined
  /// [PerformanceMetrics] object containing memory usage and CPU usage.
  ///
  /// This method does NOT require [startMonitoring] to have been called.
  static Future<PerformanceMetrics> getMetricsSnapshot() async {
    await instance._updateNativeMetrics();
    return instance._createPerformanceMetrics();
  }

  /// Get a one-time CPU usage snapshot without continuous monitoring.
  ///
  /// Returns the current CPU usage as a percentage (0.0–100.0). On native
  /// platforms this value is fetched from the host.
  ///
  /// This method does NOT require [startMonitoring] to have been called.
  static Future<double> getCpuUsageSnapshot() async {
    await instance._updateNativeMetrics();
    return instance._currentCpuUsage.clamp(0.0, 100.0);
  }

  /// Get a one-time per-core CPU usage snapshot without continuous monitoring.
  ///
  /// Returns a list of per-core CPU usage percentages. On web an empty list is
  /// returned.
  ///
  /// This method does NOT require [startMonitoring] to have been called.
  static Future<List<double>> getPerCoreCpuSnapshot() async {
    await instance._updateNativeMetrics();
    return List<double>.from(instance._perCoreCpuUsage);
  }

  /// Get a one-time available memory snapshot without continuous monitoring.
  ///
  /// Returns the current available memory in bytes as reported by the native
  /// platform. On web this returns 0.
  ///
  /// This method does NOT require [startMonitoring] to have been called.
  static Future<int> getAvailableMemorySnapshot() async {
    await instance._updateNativeMetrics();
    return instance._availableMemory;
  }

  /// Dispose of resources
  ///
  /// This method should be called when the monitor is no longer needed.
  static void dispose() {
    stopMonitoring();
    instance._metricsController.close();
    instance._memoryController.close();
  }

  Future<void> _collectMetrics() async {
    if (!_isMonitoring) return;

    // Update native metrics first
    await _updateNativeMetrics();

    final memoryData = _createMemoryData();
    final performanceMetrics = _createPerformanceMetrics();

    if (_isMonitoring && !_memoryController.isClosed) {
      try {
        _memoryController.add(memoryData);
        _metricsController.add(performanceMetrics);
      } catch (_) {
        // Stream is closed, ignore
      }
    }
  }

  Future<void> _updateNativeMetrics() async {
    // No _isMonitoring guard here: this method is reused by the on-demand
    // snapshot methods so they can refresh native data in a single call.
    // Callers such as _collectMetrics guard on _isMonitoring themselves.

    // Skip native calls on web platform
    if (kIsWeb) {
      return;
    }

    try {
      // Get memory info from native
      final memoryResult = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getMemoryInfo',
      );
      if (memoryResult != null) {
        _totalMemory = memoryResult['totalMemory'] as int? ?? _totalMemory;
        _availableMemory =
            memoryResult['availableMemory'] as int? ?? _availableMemory;
      }

      // Get CPU info from native
      final cpuResult = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getCpuUsage',
      );
      if (cpuResult != null) {
        _currentCpuUsage =
            (cpuResult['totalUsage'] as num?)?.toDouble() ?? _currentCpuUsage;
        final perCoreList = cpuResult['perCoreUsage'] as List?;
        if (perCoreList != null) {
          _perCoreCpuUsage = perCoreList
              .map((e) => (e as num).toDouble())
              .toList();
        }
      }
    } catch (e) {
      // Silently fallback if native fails
      // Only log in debug mode if it's not a MissingPluginException (expected on web)
      if (kDebugMode && !e.toString().contains('MissingPluginException')) {
        debugPrint('Error getting native metrics: $e');
      }
    }
  }

  MemoryData _createMemoryData() {
    final currentUsage = _getCurrentMemoryUsage();
    if (currentUsage > _peakMemoryUsage) {
      _peakMemoryUsage = currentUsage;
    }

    return MemoryData(
      currentUsage: currentUsage,
      peakUsage: _peakMemoryUsage,
      availableMemory: _getAvailableMemory(),
      totalMemory: _totalMemory,
      usagePercentage: _totalMemory > 0
          ? (currentUsage / _totalMemory) * 100
          : 0.0,
      timestamp: DateTime.now(),
    );
  }

  PerformanceMetrics _createPerformanceMetrics() {
    final cpuUsage = _currentCpuUsage.clamp(0.0, 100.0);

    return PerformanceMetrics(
      memoryUsage: _getCurrentMemoryUsage(),
      timestamp: DateTime.now(),
      cpuUsage: cpuUsage,
    );
  }

  int _getCurrentMemoryUsage() {
    // On web, try to use browser's performance.memory API
    if (kIsWeb) {
      return _getWebMemoryUsage();
    }

    // Use dart:io ProcessInfo to get real RSS memory usage
    try {
      return ProcessInfo.currentRss;
    } catch (e) {
      // Silently return 0 on error (e.g., if ProcessInfo is not available)
      return 0;
    }
  }

  int _getWebMemoryUsage() {
    if (!kIsWeb) return 0;

    // Try to access performance.memory (available in Chrome/Chromium browsers)
    try {
      // Use JavaScript eval to access window.performance.memory.usedJSHeapSize
      // This is the most reliable way to access non-standard JavaScript APIs
      final result = js.context.callMethod('eval', [
        'window.performance && window.performance.memory && window.performance.memory.usedJSHeapSize || null',
      ]);

      if (result != null) {
        final memoryBytes = (result as num).toInt();
        if (memoryBytes > 0) {
          if (kDebugMode) {
            debugPrint(
              'Web memory: ${(memoryBytes / 1024 / 1024).toStringAsFixed(2)} MB',
            );
          }
          return memoryBytes;
        }
      }
    } catch (e) {
      // performance.memory is not available (e.g., in Firefox, Safari, or disabled)
      // This is expected and not an error - silently return 0
      if (kDebugMode && !_hasLoggedMemoryWarning) {
        _hasLoggedMemoryWarning = true;
        debugPrint('Web memory API not available: $e');
      }
    }
    return 0;
  }

  int _getAvailableMemory() {
    // Return native available memory if available
    return _availableMemory;
  }
}
