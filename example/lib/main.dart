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
      title: 'RuuviSensor Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const RuuviScannerPage(),
    );
  }
}

class RuuviScannerPage extends StatefulWidget {
  const RuuviScannerPage({super.key});

  @override
  State<RuuviScannerPage> createState() => _RuuviScannerPageState();
}

class _RuuviScannerPageState extends State<RuuviScannerPage> {
  final RuuviScanner _scanner = RuuviScanner();
  final RuuviBleScanner _bleScanner = RuuviBleScanner();
  List<RuuviDevice> _devices = [];
  List<RuuviBleScanResult> _bleDevices = [];
  bool _isScanning = false;
  bool _isBleScanningActive = false;
  String _statusMessage = 'Ready to scan';

  @override
  void initState() {
    super.initState();
    _scanner.devicesStream.listen((devices) {
      setState(() {
        _devices = devices;
      });
    });

    _bleScanner.devicesStream.listen((devices) {
      setState(() {
        _bleDevices = devices;
      });
    });
  }

  @override
  void dispose() {
    _scanner.dispose();
    _bleScanner.dispose();
    super.dispose();
  }

  Future<void> _checkSetup() async {
    try {
      // The ruuvi_sensor package will handle permissions automatically
      // when startScan() is called. This method is now simplified.
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Setup complete - ready to scan';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Setup check failed: $e';
      });
    }
  }

  Future<void> _startScan() async {
    try {
      if (!mounted) return;
      setState(() {
        _isScanning = true;
        _statusMessage = 'Checking setup...';
      });

      await _checkSetup();

      if (!mounted) return;
      setState(() {
        _statusMessage = 'Scanning for RuuviTag devices...';
      });

      await _scanner.startScan(timeout: const Duration(seconds: 30));

      if (!mounted) return;
      setState(() {
        _statusMessage = 'Scan completed';
        _isScanning = false;
      });
    } on RuuviException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Ruuvi Error: $e';
        _isScanning = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Error: $e';
        _isScanning = false;
      });
    }
  }

  Future<void> _startContinuousScan() async {
    try {
      if (!mounted) return;
      setState(() {
        _isScanning = true;
        _statusMessage = 'Starting live mode...';
      });

      await _checkSetup();

      if (!mounted) return;
      setState(() {
        _statusMessage = 'Live mode - scanning continuously...';
      });

      await _scanner.startContinuousScan();

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Live mode failed: $e';
        _isScanning = false;
      });
    }
  }

  Future<void> _stopScan() async {
    try {
      await _scanner.stopScan();
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _statusMessage = 'Scan stopped';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Error stopping scan: $e';
      });
    }
  }

  Future<void> _startBleScan() async {
    try {
      if (!mounted) return;
      setState(() {
        _isBleScanningActive = true;
        _statusMessage = 'Scanning with new BLE system...';
      });

      await _bleScanner.startScan(timeout: const Duration(seconds: 30));

      if (!mounted) return;
      setState(() {
        _statusMessage = 'BLE scan completed';
        _isBleScanningActive = false;
      });
    } on RuuviException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'BLE Scan Error: $e';
        _isBleScanningActive = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'BLE Scan Error: $e';
        _isBleScanningActive = false;
      });
    }
  }

  Future<void> _stopBleScan() async {
    try {
      await _bleScanner.stopScan();
      if (!mounted) return;
      setState(() {
        _isBleScanningActive = false;
        _statusMessage = 'BLE scan stopped';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Error stopping BLE scan: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('RuuviSensor Example'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  _statusMessage,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _isScanning ? null : _startScan,
                      child: const Text('Scan Once'),
                    ),
                    ElevatedButton(
                      onPressed: _isScanning ? null : _startContinuousScan,
                      child: const Text('Live Mode'),
                    ),
                    ElevatedButton(
                      onPressed: _isScanning ? _stopScan : null,
                      child: const Text('Stop'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Nouvelle rangée pour le scanner BLE
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _isBleScanningActive ? null : _startBleScan,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: const Text('Scan (New BLE)'),
                    ),
                    ElevatedButton(
                      onPressed: _isBleScanningActive ? _stopBleScan : null,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Stop BLE'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Text(
                  'Old System: ${_devices.length} RuuviTag(s)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'New BLE System: ${_bleDevices.length} RuuviTag(s)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.green),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                // Ancien système
                if (_devices.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Old System (flutter_blue_plus)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ..._devices.map((device) => RuuviDeviceCard(device: device)),
                ],

                // Nouveau système
                if (_bleDevices.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'New BLE System (flutter_reactive_ble)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ),
                  ..._bleDevices.map((device) => RuuviBleDeviceCard(device: device)),
                ],

                // Message si aucun device
                if (_devices.isEmpty && _bleDevices.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: Text('No RuuviTags found. Try scanning!'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RuuviDeviceCard extends StatelessWidget {
  final RuuviDevice device;

  const RuuviDeviceCard({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    final data = device.lastData;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  device.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${device.rssi} dBm',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Serial: ${device.serialNumber}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (data != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildDataColumn(
                    'Temperature',
                    data.temperature.isNaN
                        ? 'N/A'
                        : '${data.temperature.toStringAsFixed(2)}°C',
                    Icons.thermostat,
                  ),
                  _buildDataColumn(
                    'Humidity',
                    data.humidity.isNaN 
                        ? 'N/A' 
                        : '${data.humidity.toStringAsFixed(1)}%',
                    Icons.water_drop,
                  ),
                  _buildDataColumn(
                    'Pressure',
                    data.pressure.isNaN 
                        ? 'N/A' 
                        : '${(data.pressure / 100).toStringAsFixed(0)} hPa',
                    Icons.speed,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => _showDeviceDetails(context, device),
                child: const Text('View Details'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDataColumn(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 24),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _showDeviceDetails(BuildContext context, RuuviDevice device) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RuuviDeviceDetailsPage(device: device),
      ),
    );
  }
}

class RuuviBleDeviceCard extends StatelessWidget {
  final RuuviBleScanResult device;

  const RuuviBleDeviceCard({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  device.displayName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Row(
                  children: [
                    Icon(Icons.bluetooth, size: 16, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(
                      '${device.rssi} dBm',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Device ID: ${device.deviceId}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (device.hasValidData) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildDataColumn(
                    'Temperature',
                    device.temperature != null
                        ? '${device.temperature!.toStringAsFixed(2)}°C'
                        : 'N/A',
                    Icons.thermostat,
                  ),
                  _buildDataColumn(
                    'Humidity',
                    device.humidity != null
                        ? '${device.humidity!.toStringAsFixed(1)}%'
                        : 'N/A',
                    Icons.water_drop,
                  ),
                  _buildDataColumn(
                    'Pressure',
                    device.pressure != null
                        ? '${(device.pressure! / 100).toStringAsFixed(0)} hPa'
                        : 'N/A',
                    Icons.speed,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => _showBleDeviceDetails(context, device),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('View Details (New System)'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDataColumn(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 24),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _showBleDeviceDetails(BuildContext context, RuuviBleScanResult device) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RuuviBleDeviceDetailsPage(device: device),
      ),
    );
  }
}

class RuuviDeviceDetailsPage extends StatefulWidget {
  final RuuviDevice device;

  const RuuviDeviceDetailsPage({super.key, required this.device});

  @override
  State<RuuviDeviceDetailsPage> createState() => _RuuviDeviceDetailsPageState();
}

class _RuuviDeviceDetailsPageState extends State<RuuviDeviceDetailsPage> {
  bool _isConnected = false;
  bool _isConnecting = false;
  String _statusMessage = 'Not connected';
  RuuviMeasurement? _historicalData;

  // Nouvelles variables pour RuuviHistoryReader
  final RuuviHistoryReader _historyReader = RuuviHistoryReader();
  RuuviTagInformation? _deviceInformation;
  RuuviHistoryCollection? _newHistoryData;
  bool _isLoadingNewHistory = false;

  @override
  void dispose() {
    // Disconnect from device if still connected to avoid memory leaks
    if (_isConnected) {
      widget.device.disconnect().catchError((e) {
        // Ignore errors during dispose
      });
    }
    super.dispose();
  }

  Future<void> _connectToDevice() async {
    if (!mounted) return;
    setState(() {
      _isConnecting = true;
      _statusMessage = 'Connecting...';
    });

    try {
      await widget.device.connect();
      if (!mounted) return;
      setState(() {
        _isConnected = true;
        _isConnecting = false;
        _statusMessage = 'Connected';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _statusMessage = 'Connection failed: $e';
      });
    }
  }

  Future<void> _disconnectFromDevice() async {
    try {
      await widget.device.disconnect();
      if (!mounted) return;
      setState(() {
        _isConnected = false;
        _statusMessage = 'Disconnected';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Disconnect failed: $e';
      });
    }
  }

  Future<void> _getSerialNumber() async {
    if (!_isConnected) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Must be connected to get serial number';
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _statusMessage = 'Reading serial number...';
    });

    try {
      final serialNumber = await widget.device.readSerialNumber();
      if (!mounted) return;

      setState(() {
        _statusMessage = 'Serial Number: $serialNumber';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Failed to read serial number: $e';
      });
    }
  }

  Future<void> _getDeviceInfo() async {
    if (!_isConnected) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Must be connected to get device info';
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _statusMessage = 'Reading Device Information Service...\nCheck logs for details!';
    });

    try {
      final deviceInfo = await widget.device.readDeviceInformationService();
      if (!mounted) return;

      if (deviceInfo.isNotEmpty && !deviceInfo.containsKey('error')) {
        final infoText = deviceInfo.entries
            .map((e) => '${e.key.replaceAll('_', ' ')}: ${e.value}')
            .join('\n');

        setState(() {
          _statusMessage = 'Device Information Service:\n$infoText';
        });
      } else {
        setState(() {
          _statusMessage = deviceInfo['error'] ?? 'No device information available.\n\nThis RuuviTag may not expose the Device Information Service (180A).\n\nCheck logs for more details.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Failed to read device info: $e';
      });
    }
  }

  Future<void> _getHistoricalData() async {
    if (!_isConnected) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Must be connected to get historical data';
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _statusMessage = 'Retrieving historical data...\nThis may take several minutes.';
    });

    try {
      // Get historical data (Cut-RAWv2 format)
      final data = await widget.device.getStoredData(
        timeout: const Duration(seconds: 30), // Reasonable timeout for history
      );

      if (!mounted) return;
      setState(() {
        _historicalData = data;
        if (data.totalCount > 0) {
          _statusMessage = 'Retrieved ${data.totalCount} measurements from ${data.startTime} to ${data.endTime}';
        } else {
          _statusMessage = 'No historical data available.\nNote: Many RuuviTags don\'t support historical data retrieval or need firmware 3.x+';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Historical data failed: $e\n\nNote: Historical data requires:\n- Firmware 3.x or higher\n- Device must have been logging for some time\n- Some RuuviTags don\'t support this feature';
      });
    }
  }

  // Nouvelle méthode pour lire les informations du device avec RuuviHistoryReader
  Future<void> _getNewDeviceInfo() async {
    if (!mounted) return;
    setState(() {
      _statusMessage = 'Reading device information with RuuviHistoryReader...';
    });

    try {
      final deviceInfo = await _historyReader.getDeviceInformation(widget.device.serialNumber);
      if (!mounted) return;
      setState(() {
        _deviceInformation = deviceInfo;
        _statusMessage = 'Device info loaded:\n${deviceInfo.getDisplayName()}\nIdentifier: ${deviceInfo.getIdentifier()}\nManufacturer: ${deviceInfo.getManufacturer() ?? 'N/A'}\nModel: ${deviceInfo.getModel() ?? 'N/A'}\nFirmware: ${deviceInfo.getFirmwareVersion() ?? 'N/A'}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Failed to read device info with RuuviHistoryReader: $e';
      });
    }
  }

  // Nouvelle méthode pour récupérer l'historique avec RuuviHistoryReader
  Future<void> _getNewHistoryData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingNewHistory = true;
      _statusMessage = 'Reading history with RuuviHistoryReader...\nThis may take several minutes.';
    });

    try {
      final history = await _historyReader.getHistory(
        widget.device.serialNumber,
        startDate: DateTime.now().subtract(const Duration(days: 1)), // Dernières 24h
      );

      if (!mounted) return;
      setState(() {
        _newHistoryData = history;
        _isLoadingNewHistory = false;
        if (history.isNotEmpty) {
          final averages = history.getAverages();
          _statusMessage = 'New history loaded: ${history.length} measurements\n'
              'Time range: ${history.first?.timestamp} to ${history.last?.timestamp}\n'
              'Avg temp: ${averages['temperature']?.toStringAsFixed(2) ?? 'N/A'}°C\n'
              'Avg humidity: ${averages['humidity']?.toStringAsFixed(1) ?? 'N/A'}%\n'
              'Avg pressure: ${averages['pressure']?.toStringAsFixed(1) ?? 'N/A'} hPa';
        } else {
          _statusMessage = 'No new history data available';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingNewHistory = false;
        _statusMessage = 'Failed to read new history: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.device.lastData;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.name),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Device Information',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Serial Number', widget.device.serialNumber),
            _buildInfoRow('RSSI', '${widget.device.rssi} dBm'),
            _buildInfoRow('Status', _statusMessage),
            
            if (data != null) ...[
              const SizedBox(height: 24),
              Text(
                'Current Sensor Data',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              _buildInfoRow('Temperature', data.temperature.isNaN ? 'N/A' : '${data.temperature.toStringAsFixed(2)}°C'),
              _buildInfoRow('Humidity', data.humidity.isNaN ? 'N/A' : '${data.humidity.toStringAsFixed(2)}%'),
              _buildInfoRow('Pressure', data.pressure.isNaN ? 'N/A' : '${data.pressure.toStringAsFixed(0)} Pa'),
              if (data.batteryVoltage != null)
                _buildInfoRow('Battery', '${data.batteryVoltage} mV'),
              if (data.accelerationX != null)
                _buildInfoRow('Acceleration X', '${data.accelerationX!.toStringAsFixed(3)} G'),
              if (data.accelerationY != null)
                _buildInfoRow('Acceleration Y', '${data.accelerationY!.toStringAsFixed(3)} G'),
              if (data.accelerationZ != null)
                _buildInfoRow('Acceleration Z', '${data.accelerationZ!.toStringAsFixed(3)} G'),
            ],
            
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isConnecting ? null : (_isConnected ? _disconnectFromDevice : _connectToDevice),
                    child: Text(_isConnected ? 'Disconnect' : 'Connect'),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isConnected ? _getSerialNumber : null,
                    child: const Text('Serial'),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isConnected ? _getDeviceInfo : null,
                    child: const Text('Device Info'),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isConnected ? _getHistoricalData : null,
                    child: const Text('History'),
                  ),
                ),
              ],
            ),

            // Nouvelle rangée de boutons pour RuuviHistoryReader
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _getNewDeviceInfo,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('New Device Info', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoadingNewHistory ? null : _getNewHistoryData,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    child: Text(_isLoadingNewHistory ? 'Loading...' : 'New History', style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),

            if (_historicalData != null) ...[
              const SizedBox(height: 24),
              Text(
                'Historical Data (${_historicalData!.totalCount} measurements)',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _historicalData!.measurements.length,
                  itemBuilder: (context, index) {
                    final measurement = _historicalData!.measurements[index];
                    return ListTile(
                      title: Text(
                        measurement.timestamp.toString().substring(0, 19),
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        'T: ${measurement.temperature.isNaN ? 'N/A' : measurement.temperature.toStringAsFixed(2)}°C, '
                        'H: ${measurement.humidity.isNaN ? 'N/A' : measurement.humidity.toStringAsFixed(1)}%, '
                        'P: ${measurement.pressure.isNaN ? 'N/A' : (measurement.pressure / 100).toStringAsFixed(0)} hPa',
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  },
                ),
              ),
            ],

            // Affichage des nouvelles données d'historique
            if (_newHistoryData != null) ...[
              const SizedBox(height: 24),
              Text(
                'New History Data (${_newHistoryData!.length} measurements)',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.orange),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: _newHistoryData!.measurements.length,
                  itemBuilder: (context, index) {
                    final measurement = _newHistoryData!.measurements[index];
                    return ListTile(
                      dense: true,
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
                      leading: const Icon(Icons.history, size: 16, color: Colors.orange),
                    );
                  },
                ),
              ),
            ],

            // Affichage des informations du device
            if (_deviceInformation != null) ...[
              const SizedBox(height: 24),
              Text(
                'Device Information (RuuviHistoryReader)',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Display Name', _deviceInformation!.getDisplayName()),
                    _buildInfoRow('Identifier', _deviceInformation!.getIdentifier()),
                    _buildInfoRow('MAC Address', _deviceInformation!.getMacAddress()),
                    if (_deviceInformation!.getManufacturer() != null)
                      _buildInfoRow('Manufacturer', _deviceInformation!.getManufacturer()!),
                    if (_deviceInformation!.getModel() != null)
                      _buildInfoRow('Model', _deviceInformation!.getModel()!),
                    if (_deviceInformation!.getFirmwareVersion() != null)
                      _buildInfoRow('Firmware', _deviceInformation!.getFirmwareVersion()!),
                    if (_deviceInformation!.getHardwareVersion() != null)
                      _buildInfoRow('Hardware', _deviceInformation!.getHardwareVersion()!),
                    _buildInfoRow('Has Serial Number', _deviceInformation!.hasSerialNumber().toString()),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}

class RuuviBleDeviceDetailsPage extends StatefulWidget {
  final RuuviBleScanResult device;

  const RuuviBleDeviceDetailsPage({super.key, required this.device});

  @override
  State<RuuviBleDeviceDetailsPage> createState() => _RuuviBleDeviceDetailsPageState();
}

class _RuuviBleDeviceDetailsPageState extends State<RuuviBleDeviceDetailsPage> {
  final RuuviHistoryReader _historyReader = RuuviHistoryReader();
  RuuviTagInformation? _deviceInformation;
  RuuviHistoryCollection? _historyData;
  bool _isLoading = false;
  String _statusMessage = 'Ready to test new BLE system';

  Future<void> _getDeviceInfo() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _statusMessage = 'Reading device information...';
    });

    try {
      final deviceInfo = await _historyReader.getDeviceInformation(widget.device.deviceId);
      if (!mounted) return;
      setState(() {
        _deviceInformation = deviceInfo;
        _isLoading = false;
        _statusMessage = 'Device info loaded successfully!';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusMessage = 'Failed to read device info: $e';
      });
    }
  }

  Future<void> _getHistory() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _statusMessage = 'Reading history (last 24h)...\nThis may take several minutes.';
    });

    try {
      final history = await _historyReader.getHistory(
        widget.device.deviceId,
        startDate: DateTime.now().subtract(const Duration(days: 1)),
      );

      if (!mounted) return;
      setState(() {
        _historyData = history;
        _isLoading = false;
        if (history.isNotEmpty) {
          final averages = history.getAverages();
          _statusMessage = 'History loaded: ${history.length} measurements\n'
              'Avg temp: ${averages['temperature']?.toStringAsFixed(2) ?? 'N/A'}°C\n'
              'Avg humidity: ${averages['humidity']?.toStringAsFixed(1) ?? 'N/A'}%\n'
              'Avg pressure: ${averages['pressure']?.toStringAsFixed(1) ?? 'N/A'} hPa';
        } else {
          _statusMessage = 'No history data available';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusMessage = 'Failed to read history: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.displayName),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New BLE System Test',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green),
            ),
            const SizedBox(height: 16),

            _buildInfoRow('Device ID', widget.device.deviceId),
            _buildInfoRow('Display Name', widget.device.displayName),
            _buildInfoRow('RSSI', '${widget.device.rssi} dBm'),
            _buildInfoRow('Data Format', widget.device.dataFormat?.toString() ?? 'N/A'),
            _buildInfoRow('Last Seen', widget.device.lastSeen.toString().substring(0, 19)),

            if (widget.device.hasValidData) ...[
              const SizedBox(height: 16),
              Text(
                'Current Sensor Data',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _buildInfoRow('Temperature', widget.device.temperature != null ? '${widget.device.temperature!.toStringAsFixed(2)}°C' : 'N/A'),
              _buildInfoRow('Humidity', widget.device.humidity != null ? '${widget.device.humidity!.toStringAsFixed(1)}%' : 'N/A'),
              _buildInfoRow('Pressure', widget.device.pressure != null ? '${(widget.device.pressure! / 100).toStringAsFixed(0)} hPa' : 'N/A'),
              if (widget.device.batteryVoltage != null)
                _buildInfoRow('Battery', '${widget.device.batteryVoltage} mV'),
            ],

            const SizedBox(height: 24),
            _buildInfoRow('Status', _statusMessage),

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _getDeviceInfo,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('Get Device Info'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _getHistory,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    child: const Text('Get History'),
                  ),
                ),
              ],
            ),

            if (_deviceInformation != null) ...[
              const SizedBox(height: 24),
              Text(
                'Device Information',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.green),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Identifier', _deviceInformation!.getIdentifier()),
                    _buildInfoRow('Display Name', _deviceInformation!.getDisplayName()),
                    if (_deviceInformation!.getManufacturer() != null)
                      _buildInfoRow('Manufacturer', _deviceInformation!.getManufacturer()!),
                    if (_deviceInformation!.getModel() != null)
                      _buildInfoRow('Model', _deviceInformation!.getModel()!),
                    if (_deviceInformation!.getFirmwareVersion() != null)
                      _buildInfoRow('Firmware', _deviceInformation!.getFirmwareVersion()!),
                    _buildInfoRow('Has Serial Number', _deviceInformation!.hasSerialNumber().toString()),
                  ],
                ),
              ),
            ],

            if (_historyData != null && _historyData!.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'History Data (${_historyData!.length} measurements)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.orange),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _historyData!.measurements.length,
                  itemBuilder: (context, index) {
                    final measurement = _historyData!.measurements[index];
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
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
