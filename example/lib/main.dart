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
  String _activeButton = ''; // Track which button is active
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

  Future<void> _getAllHistory(RuuviBleScanResult tag) async {
    try {
      setState(() {
        _isLoadingHistory = true;
        _selectedTag = tag;
        _activeButton = 'all_${tag.deviceId}';
        _statusMessage = 'Loading ALL history for ${tag.displayName}...';
        _historyData.clear();
      });

      // Récupérer TOUT l'historique disponible avec startDate = null
      final history = await _historyReader.getAllHistory(tag.deviceId);

      setState(() {
        _isLoadingHistory = false;
        _activeButton = '';
        _historyData = history.measurements;
        _statusMessage = 'ALL History loaded: ${_historyData.length} measurements for ${tag.displayName}';
      });
    } catch (e) {
      setState(() {
        _isLoadingHistory = false;
        _activeButton = '';
        _statusMessage = 'ALL History error: $e';
      });
    }
  }

  Future<void> _getHistoryFromDate(RuuviBleScanResult tag) async {
    // Demander une date à l'utilisateur
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 1)),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );

    if (selectedDate == null) return;

    // Vérifier que le widget est encore monté
    if (!mounted) return;

    // Demander une heure
    final TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(selectedDate),
    );

    if (selectedTime == null) return;

    // Combiner date et heure
    final DateTime startDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    try {
      setState(() {
        _isLoadingHistory = true;
        _selectedTag = tag;
        _activeButton = 'date_${tag.deviceId}';
        _statusMessage = 'Loading history from ${startDateTime.toString().substring(0, 16)} for ${tag.displayName}...';
        _historyData.clear();
      });

      // Récupérer l'historique depuis la date spécifiée
      final history = await _historyReader.getHistory(
        tag.deviceId,
        startDate: startDateTime,
      );

      setState(() {
        _isLoadingHistory = false;
        _activeButton = '';
        _historyData = history.measurements;
        _statusMessage = 'History from ${startDateTime.toString().substring(0, 16)}: ${_historyData.length} measurements for ${tag.displayName}';
      });
    } catch (e) {
      setState(() {
        _isLoadingHistory = false;
        _activeButton = '';
        _statusMessage = 'History from date error: $e';
      });
    }
  }

  Future<void> _getHistoryFromEpoch(RuuviBleScanResult tag) async {
    try {
      setState(() {
        _isLoadingHistory = true;
        _selectedTag = tag;
        _activeButton = 'epoch_${tag.deviceId}';
        _statusMessage = 'Testing history from EPOCH (1970) for ${tag.displayName}...';
        _historyData.clear();
      });

      // Tester avec startTime = 0 (epoch)
      final history = await _historyReader.getHistoryFromEpoch(tag.deviceId);

      setState(() {
        _isLoadingHistory = false;
        _activeButton = '';
        _historyData = history.measurements;
        _statusMessage = 'EPOCH History: ${_historyData.length} measurements for ${tag.displayName}';
      });
    } catch (e) {
      setState(() {
        _isLoadingHistory = false;
        _activeButton = '';
        _statusMessage = 'EPOCH History error: $e';
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
                            trailing: SizedBox(
                              width: 200,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _isLoadingHistory ? null : () => _getAllHistory(tag),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                      ),
                                      child: _activeButton == 'all_${tag.deviceId}'
                                          ? const SizedBox(
                                              width: 12,
                                              height: 12,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text('All', style: TextStyle(fontSize: 8)),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _isLoadingHistory ? null : () => _getHistoryFromDate(tag),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                      ),
                                      child: _activeButton == 'date_${tag.deviceId}'
                                          ? const SizedBox(
                                              width: 12,
                                              height: 12,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text('Date', style: TextStyle(fontSize: 8)),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _isLoadingHistory ? null : () => _getHistoryFromEpoch(tag),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                      ),
                                      child: _activeButton == 'epoch_${tag.deviceId}'
                                          ? const SizedBox(
                                              width: 12,
                                              height: 12,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text('Epoch', style: TextStyle(fontSize: 8)),
                                    ),
                                  ),
                                ],
                              ),
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
