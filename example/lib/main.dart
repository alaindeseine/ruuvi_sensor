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
  List<RuuviDevice> _devices = [];
  bool _isScanning = false;
  String _statusMessage = 'Ready to scan';

  @override
  void initState() {
    super.initState();
    _scanner.devicesStream.listen((devices) {
      setState(() {
        _devices = devices;
      });
    });
  }

  @override
  void dispose() {
    _scanner.dispose();
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
                Text(
                  'Found ${_devices.length} RuuviTag(s)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _devices.length,
              itemBuilder: (context, index) {
                final device = _devices[index];
                return RuuviDeviceCard(device: device);
              },
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
      _statusMessage = 'Reading device information...';
    });

    try {
      final deviceInfo = await widget.device.readDeviceInfo();
      if (!mounted) return;

      final infoText = deviceInfo.entries
          .map((e) => '${e.key}: ${e.value}')
          .join('\n');

      setState(() {
        _statusMessage = 'Device Info:\n$infoText';
      });
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
      // Get data from last 24 hours
      final data = await widget.device.getStoredData(
        startTime: DateTime.now().subtract(const Duration(hours: 24)),
        timeout: const Duration(minutes: 10), // Longer timeout
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
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isConnected ? _getDeviceInfo : null,
                    child: const Text('Device Info'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isConnected ? _getHistoricalData : null,
                    child: const Text('Get History'),
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
