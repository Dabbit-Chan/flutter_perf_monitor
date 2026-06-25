import 'package:flutter/material.dart';
import 'package:flutter_perf_monitor/flutter_perf_monitor.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Performance Monitor Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MyHomePage(title: 'Flutter Performance Monitor Example'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _isMonitoring = false;

  @override
  void dispose() {
    FlutterPerfMonitor.dispose();
    super.dispose();
  }

  void _toggleMonitoring() {
    setState(() {
      _isMonitoring = !_isMonitoring;

      if (_isMonitoring) {
        FlutterPerfMonitor.startMonitoring();
      } else {
        FlutterPerfMonitor.stopMonitoring();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: const Color(0xFFFFFFFF),
      ),
      body: Stack(
        children: [
          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  'Performance Monitor Demo',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 20),
                Text(
                  'This app demonstrates the Flutter Performance Monitor package.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 40),

                ElevatedButton(
                  onPressed: _toggleMonitoring,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isMonitoring
                        ? const Color(0xFFF44336)
                        : const Color(0xFF4CAF50),
                    foregroundColor: const Color(0xFFFFFFFF),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 15,
                    ),
                  ),
                  child: Text(
                    _isMonitoring ? 'Stop Monitoring' : 'Start Monitoring',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  _isMonitoring
                      ? 'Performance monitoring is active. Check the overlay widget!'
                      : 'Click the button above to start performance monitoring.',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),

          // Performance monitor widget overlay
          if (_isMonitoring)
            const PerfMonitorWidget(
              alignment: Alignment.topLeft,
              backgroundColor: Color(0x80000000),
              textColor: Color(0xFFFFFFFF),
              showMemory: true,
              showCPU: true,
            ),
        ],
      ),
    );
  }
}
