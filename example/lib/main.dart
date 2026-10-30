import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ruuvi_sensor/ruuvi_sensor.dart';

void main() => runApp(const RuuviExampleApp());

class RuuviExampleApp extends StatelessWidget {
  const RuuviExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ruuvi Sensor Example',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const ScanPage(),
    );
  }
}

/// Lists nearby RuuviTags with their live advertised values.
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final _scanner = RuuviBleScanner();
  StreamSubscription<List<RuuviBleScanResult>>? _subscription;
  List<RuuviBleScanResult> _tags = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _subscription = _scanner.devicesStream.listen(
      (tags) => setState(() => _tags = tags),
      onError: (Object e) => setState(() => _error = '$e'),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _toggleScan() async {
    setState(() => _error = null);
    try {
      if (_scanner.isScanning) {
        await _scanner.stopScan();
      } else {
        await _scanner.startScan(timeout: const Duration(seconds: 30));
      }
    } on RuuviException catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RuuviTags')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleScan,
        icon: Icon(
          _scanner.isScanning ? Icons.stop : Icons.bluetooth_searching,
        ),
        label: Text(_scanner.isScanning ? 'Stop' : 'Scan'),
      ),
      body: Column(
        children: [
          if (_error != null)
            MaterialBanner(
              content: Text(_error!),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _error = null),
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          Expanded(
            child: _tags.isEmpty
                ? const Center(child: Text('Tap Scan to look for RuuviTags'))
                : ListView(
                    children: [
                      for (final tag in _tags)
                        ListTile(
                          leading: const Icon(Icons.sensors),
                          title: Text(tag.displayName),
                          subtitle: Text(_describe(tag)),
                          trailing: Text('${tag.rssi} dBm'),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => TagPage(tag: tag),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  static String _describe(RuuviBleScanResult tag) {
    // Any value can be null: unsupported data format or sensor not available.
    return [
      if (tag.temperature != null) '${tag.temperature!.toStringAsFixed(2)} °C',
      if (tag.humidity != null) '${tag.humidity!.toStringAsFixed(1)} %',
      if (tag.pressureHPa != null) '${tag.pressureHPa!.toStringAsFixed(1)} hPa',
      if (tag.batteryVoltage != null) '${tag.batteryVoltage} mV',
      'format ${tag.dataFormat}',
    ].join('  ·  ');
  }
}

/// Reads device information and the logged history of one tag.
class TagPage extends StatefulWidget {
  const TagPage({super.key, required this.tag});

  final RuuviBleScanResult tag;

  @override
  State<TagPage> createState() => _TagPageState();
}

class _TagPageState extends State<TagPage> {
  final _reader = RuuviHistoryReader();
  RuuviTagInformation? _info;
  RuuviHistoryCollection? _history;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reader.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on RuuviException catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _readInfo() => _run(() async {
    _info = await _reader.getDeviceInformation(widget.tag.deviceId);
  });

  Future<void> _readHistory() => _run(() async {
    _history = await _reader.getAllHistory(widget.tag.deviceId);
  });

  @override
  Widget build(BuildContext context) {
    final info = _info;
    final history = _history;
    return Scaffold(
      appBar: AppBar(title: Text(widget.tag.displayName)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: _busy ? null : _readInfo,
                  child: const Text('Device info'),
                ),
                FilledButton(
                  onPressed: _busy ? null : _readHistory,
                  child: const Text('Read history'),
                ),
              ],
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (info != null)
            ListTile(
              title: Text(
                '${info.getModel() ?? 'RuuviTag'} '
                '${info.getHardwareVersion() ?? ''}',
              ),
              subtitle: Text(
                'Firmware ${info.getFirmwareVersion() ?? '?'}'
                ' · ID ${info.getIdentifier()}',
              ),
            ),
          if (history != null) ...[
            ListTile(
              title: Text('${history.length} measurements'),
              subtitle: Text(
                history.isComplete
                    ? 'Complete history'
                    : 'Incomplete: the transfer stopped early',
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                children: [
                  // Newest first. Fields a tag doesn't log are null.
                  for (final m in history.measurements.reversed)
                    ListTile(
                      dense: true,
                      title: Text(m.timestamp.toLocal().toString()),
                      subtitle: Text(
                        [
                          if (m.temperature != null)
                            '${m.temperature!.toStringAsFixed(2)} °C',
                          if (m.humidity != null)
                            '${m.humidity!.toStringAsFixed(1)} %',
                          if (m.pressure != null)
                            '${m.pressure!.toStringAsFixed(1)} hPa',
                        ].join('  ·  '),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
