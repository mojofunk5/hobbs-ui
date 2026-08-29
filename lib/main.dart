import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Empty by default so a production build (served behind Caddy, which proxies /api/* to the
// backend) hits a same-origin relative path. Local dev overrides it to the backend's own origin:
// flutter run -d chrome --dart-define=API_BASE=http://localhost:8080
const String _apiBase = String.fromEnvironment('API_BASE', defaultValue: '/api');

void main() {
  runApp(const HobbsApp());
}

class HobbsApp extends StatelessWidget {
  const HobbsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hobbs',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const HealthCheckPage(),
    );
  }
}

enum _HealthState { loading, up, down }

class HealthCheckPage extends StatefulWidget {
  const HealthCheckPage({super.key});

  @override
  State<HealthCheckPage> createState() => _HealthCheckPageState();
}

class _HealthCheckPageState extends State<HealthCheckPage> {
  _HealthState _state = _HealthState.loading;
  String _detail = '';

  @override
  void initState() {
    super.initState();
    _checkHealth();
  }

  Future<void> _checkHealth() async {
    setState(() => _state = _HealthState.loading);
    try {
      final response = await http.get(Uri.parse('$_apiBase/health'));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      setState(() {
        _state = response.statusCode == 200 && body['status'] == 'UP'
            ? _HealthState.up
            : _HealthState.down;
        _detail = 'HTTP ${response.statusCode}: ${response.body}';
      });
    } catch (e) {
      setState(() {
        _state = _HealthState.down;
        _detail = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hobbs')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              switch (_state) {
                _HealthState.loading => Icons.hourglass_empty,
                _HealthState.up => Icons.check_circle,
                _HealthState.down => Icons.error,
              },
              size: 64,
              color: switch (_state) {
                _HealthState.loading => Colors.grey,
                _HealthState.up => Colors.green,
                _HealthState.down => Colors.red,
              },
            ),
            const SizedBox(height: 16),
            Text(
              switch (_state) {
                _HealthState.loading => 'Checking backend...',
                _HealthState.up => 'Backend is UP',
                _HealthState.down => 'Backend is DOWN',
              },
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (_detail.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _detail,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
            const SizedBox(height: 24),
            OutlinedButton(onPressed: _checkHealth, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
