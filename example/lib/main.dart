import 'package:flutter/material.dart';
import 'package:ruuvi_sensor/ruuvi_sensor.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RuuviSensor - New BLE System',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const RuuviHomePage(),
    );
  }
}

class RuuviHomePage extends StatefulWidget {
  const RuuviHomePage({super.key});

  @override
  State<RuuviHomePage> createState() => _RuuviHomePageState();
}

class _RuuviHomePageState extends State<RuuviHomePage> {
  final RuuviBleScanner _scanner = RuuviBleScanner();
  final RuuviHistoryReader _historyReader = RuuviHistoryReader();
  
  List<RuuviBleScanResult> _discoveredTags = [];
  List<RuuviHistoryMeasurement> _historyData = [];
  RuuviBleScanResult? _selectedTag;
  
  bool _isScanning = false;
  bool _isLoadingHistory = false;
  String _statusMessage = 'Ready to scan for RuuviTags';

  @override
  void initState() {
    super.initState();
    _scanner.devicesStream.listen((devices) {
      setState(() {
        _discoveredTags = devices;
      });
    });
  }

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    try {
      setState(() {
        _isScanning = true;
        _statusMessage = 'Scanning for RuuviTags...';
      });

      await _scanner.startScan(timeout: const Duration(seconds: 30));

      setState(() {
        _isScanning = false;
        _statusMessage = 'Scan completed. Found ${_discoveredTags.length} RuuviTags.';
      });
    } catch (e) {
      setState(() {
        _isScanning = false;
        _statusMessage = 'Scan error: $e';
      });
    }
  }

  Future<void> _stopScan() async {
    try {
      await _scanner.stopScan();
      setState(() {
        _isScanning = false;
        _statusMessage = 'Scan stopped.';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Stop scan error: $e';
      });
    }
  }

  Future<void> _getHistory(RuuviBleScanResult tag) async {
    try {
      setState(() {
        _isLoadingHistory = true;
        _selectedTag = tag;
        _statusMessage = 'Loading history for ${tag.displayName}...';
        _historyData.clear();
      });

      // Récupérer TOUT l'historique disponible (jusqu'à 10 jours)
      // Note: utiliser startDate = null pour récupérer toutes les données
      final history = await _historyReader.getAllHistory(tag.deviceId);

      setState(() {
        _isLoadingHistory = false;
        _historyData = history.measurements;
        _statusMessage = 'History loaded: ${_historyData.length} measurements for ${tag.displayName}';
      });
    } catch (e) {
      setState(() {
        _isLoadingHistory = false;
        _statusMessage = 'History error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RuuviSensor - New BLE System'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Colonne gauche : Capteurs découverts
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Discovered RuuviTags',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  
                  // Boutons de scan
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isScanning ? null : _startScan,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          child: Text(_isScanning ? 'Scanning...' : 'Scan'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isScanning ? _stopScan : null,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Stop'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Text(
                    'Found: ${_discoveredTags.length} tags',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  
                  // Liste des capteurs
                  Expanded(
                    child: ListView.builder(
                      itemCount: _discoveredTags.length,
                      itemBuilder: (context, index) {
                        final tag = _discoveredTags[index];
                        final isSelected = _selectedTag?.deviceId == tag.deviceId;
                        
                        return Card(
                          color: isSelected ? Colors.green.shade50 : null,
                          child: ListTile(
                            title: Text(tag.displayName),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('ID: ${tag.deviceId}'),
                                Text('RSSI: ${tag.rssi} dBm'),
                                if (tag.hasValidData)
                                  Text('T: ${tag.temperature?.toStringAsFixed(1)}°C, '
                                       'H: ${tag.humidity?.toStringAsFixed(1)}%, '
                                       'P: ${(tag.pressure! / 100).toStringAsFixed(0)} hPa'),
                              ],
                            ),
                            trailing: ElevatedButton(
                              onPressed: _isLoadingHistory ? null : () => _getHistory(tag),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                              child: const Text('Get History'),
                            ),
                            leading: Icon(
                              Icons.bluetooth,
                              color: isSelected ? Colors.green : Colors.grey,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            const VerticalDivider(),
            
            // Colonne droite : Historique
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'History Data',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  
                  if (_selectedTag != null) ...[
                    Text(
                      'Selected: ${_selectedTag!.displayName}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.green),
                    ),
                    const SizedBox(height: 8),
                  ],
                  
                  Text(
                    'Measurements: ${_historyData.length}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  
                  if (_isLoadingHistory)
                    const Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Loading history...'),
                        ],
                      ),
                    )
                  else if (_historyData.isEmpty)
                    const Center(
                      child: Text('No history data.\nSelect a tag and click "Get History".'),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: _historyData.length,
                        itemBuilder: (context, index) {
                          final measurement = _historyData[index];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.history, size: 16, color: Colors.orange),
                            title: Text(
                              measurement.timestamp.toString().substring(0, 19),
                              style: const TextStyle(fontSize: 13),
                            ),
                            subtitle: Text(
                              'T: ${measurement.temperature?.toStringAsFixed(2) ?? 'N/A'}°C, '
                              'H: ${measurement.humidity?.toStringAsFixed(1) ?? 'N/A'}%, '
                              'P: ${measurement.pressure?.toStringAsFixed(1) ?? 'N/A'} hPa',
                              style: const TextStyle(fontSize: 11),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        color: Colors.grey.shade100,
        child: Text(
          _statusMessage,
          style: const TextStyle(fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
