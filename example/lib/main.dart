import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
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

  Future<void> _requestPermissions() async {
    // Request necessary permissions for BLE scanning
    List<Permission> permissions = [];

    // Permissions communes
    permissions.add(Permission.location);

    // Permissions spécifiques selon la version Android
    if (await Permission.bluetoothScan.status != PermissionStatus.permanentlyDenied) {
      permissions.addAll([
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ]);
    } else {
      // Fallback pour les anciennes versions Android
      permissions.addAll([
        Permission.bluetooth,
      ]);
    }

    for (final permission in permissions) {
      final status = await permission.request();
      if (status != PermissionStatus.granted) {
        setState(() {
          _statusMessage = 'Permission ${permission.toString().split('.').last} denied';
        });
        return;
      }
    }

    setState(() {
      _statusMessage = 'Permissions granted';
    });
  }

  Future<void> _startScan() async {
    try {
      setState(() {
        _isScanning = true;
        _statusMessage = 'Requesting permissions...';
      });

      await _requestPermissions();

      setState(() {
        _statusMessage = 'Scanning for RuuviTag devices...';
      });

      await _scanner.startScan(timeout: const Duration(seconds: 30));
      
      setState(() {
        _statusMessage = 'Scan completed';
        _isScanning = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
        _isScanning = false;
      });
    }
  }

  Future<void> _stopScan() async {
    try {
      await _scanner.stopScan();
      setState(() {
        _isScanning = false;
        _statusMessage = 'Scan stopped';
      });
    } catch (e) {
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
                      child: const Text('Start Scan'),
                    ),
                    ElevatedButton(
                      onPressed: _isScanning ? _stopScan : null,
                      child: const Text('Stop Scan'),
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
                        : '${data.temperature.toStringAsFixed(1)}°C',
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

  Future<void> _connectToDevice() async {
    setState(() {
      _isConnecting = true;
      _statusMessage = 'Connecting...';
    });

    try {
      await widget.device.connect();
      setState(() {
        _isConnected = true;
        _isConnecting = false;
        _statusMessage = 'Connected';
      });
    } catch (e) {
      setState(() {
        _isConnecting = false;
        _statusMessage = 'Connection failed: $e';
      });
    }
  }

  Future<void> _disconnectFromDevice() async {
    try {
      await widget.device.disconnect();
      setState(() {
        _isConnected = false;
        _statusMessage = 'Disconnected';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Disconnect failed: $e';
      });
    }
  }

  Future<void> _getHistoricalData() async {
    if (!_isConnected) {
      setState(() {
        _statusMessage = 'Must be connected to get historical data';
      });
      return;
    }

    setState(() {
      _statusMessage = 'Retrieving historical data...';
    });

    try {
      final data = await widget.device.getStoredData();
      setState(() {
        _historicalData = data;
        _statusMessage = 'Retrieved ${data.totalCount} measurements';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to get historical data: $e';
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
                const SizedBox(width: 16),
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
                        'T: ${measurement.temperature.isNaN ? 'N/A' : measurement.temperature.toStringAsFixed(1)}°C, '
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
