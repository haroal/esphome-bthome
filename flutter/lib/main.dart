import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'models/bthome_device.dart';
import 'services/ble_scanner.dart';

void main() {
  runApp(const BthomeScannerApp());
}

class BthomeScannerApp extends StatelessWidget {
  const BthomeScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BTHome',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const DeviceListScreen(),
    );
  }
}

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  late final BleScanner _scanner;
  bool _permissionsGranted = false;

  @override
  void initState() {
    super.initState();
    _scanner = BleScanner();
    _scanner.addListener(_onScannerUpdate);
    _checkPermissions();
  }

  void _onScannerUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _checkPermissions() async {
    if (Platform.isIOS) {
      // iOS handles Bluetooth permissions automatically via CoreBluetooth
      // Just start scanning - the system will prompt if needed
      setState(() => _permissionsGranted = true);
      _scanner.startScan();
      return;
    }

    // Android requires explicit permission requests
    final bluetoothScan = await Permission.bluetoothScan.request();
    final bluetoothConnect = await Permission.bluetoothConnect.request();
    final location = await Permission.locationWhenInUse.request();

    setState(() {
      _permissionsGranted = bluetoothScan.isGranted &&
          bluetoothConnect.isGranted &&
          location.isGranted;
    });

    if (_permissionsGranted) {
      _scanner.startScan();
    }
  }

  @override
  void dispose() {
    _scanner.removeListener(_onScannerUpdate);
    _scanner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('BTHome'),
            actions: [
              if (_scanner.isScanning)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
          _buildBody(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (!_permissionsGranted) {
      return SliverFillRemaining(
        child: _StatusView(
          icon: Icons.bluetooth_disabled,
          title: 'Bluetooth Access Required',
          subtitle: 'Grant permissions to discover nearby devices',
          action: FilledButton.icon(
            onPressed: _checkPermissions,
            icon: const Icon(Icons.lock_open),
            label: const Text('Grant Access'),
          ),
        ),
      );
    }

    if (!_scanner.isBluetoothReady) {
      return const SliverFillRemaining(
        child: _StatusView(
          icon: Icons.bluetooth_disabled,
          title: 'Bluetooth is Off',
          subtitle: 'Enable Bluetooth to discover devices',
        ),
      );
    }

    if (_scanner.error != null) {
      return SliverFillRemaining(
        child: _StatusView(
          icon: Icons.error_outline,
          iconColor: Colors.red,
          title: 'Something went wrong',
          subtitle: _scanner.error!,
          action: FilledButton.tonal(
            onPressed: _scanner.refresh,
            child: const Text('Try Again'),
          ),
        ),
      );
    }

    final devices = _scanner.devices;
    if (devices.isEmpty) {
      return const SliverFillRemaining(
        child: _StatusView(
          icon: Icons.bluetooth_searching,
          title: 'Searching...',
          subtitle: 'Looking for BTHome devices nearby',
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.separated(
        itemCount: devices.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) => DeviceCard(
          device: devices[index],
          scanner: _scanner,
        ),
      ),
    );
  }
}

class _StatusView extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final Widget? action;

  const _StatusView({
    required this.icon,
    this.iconColor,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 72,
              color: iconColor ?? Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class DeviceCard extends StatelessWidget {
  final BthomeDevice device;
  final BleScanner scanner;

  const DeviceCard({super.key, required this.device, required this.scanner});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Generic BLE devices (not BTHome)
    if (!device.isBthome) {
      return Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerLow,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onLongPress: () => _copyDeviceId(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.bluetooth,
                    size: 20,
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name ?? 'Unknown Device',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      Text(
                        device.macAddress,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outlineVariant,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                _SignalStrength(rssi: device.rssi, dimmed: true),
              ],
            ),
          ),
        ),
      );
    }

    // BTHome devices
    final needsKey = device.isEncrypted && device.measurements.isEmpty;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: needsKey
            ? () => _showKeyDialog(context)
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DeviceDetailsScreen(
                      device: device,
                      scanner: scanner,
                    ),
                  ),
                ),
        onLongPress: () => _copyDeviceId(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _EncryptionBadge(device: device),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.name ?? 'Unknown Device',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          device.macAddress,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _SignalStrength(rssi: device.rssi),
                      if (device.distanceString != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          device.distanceString!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              if (needsKey) ...[
                const SizedBox(height: 12),
                _EncryptedHint(device: device),
              ] else if (device.measurements.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: device.measurements
                      .map((m) => _MeasurementChip(measurement: m))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _copyDeviceId(BuildContext context) {
    // On iOS this is a UUID, on Android it's the MAC address
    Clipboard.setData(ClipboardData(text: device.macAddress));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied device ID'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showKeyDialog(BuildContext context) {
    final hasKey = scanner.hasKey(device.macAddress);

    if (hasKey) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove Key'),
          content: Text(
            'Remove encryption key for ${device.name ?? device.macAddress}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                scanner.removeKey(device.macAddress);
                Navigator.pop(context);
              },
              child: const Text('Remove'),
            ),
          ],
        ),
      );
    } else {
      final controller = TextEditingController();
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Add Encryption Key'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Encryption Key',
              hintText: '32 character hex key',
              border: OutlineInputBorder(),
            ),
            maxLength: 32,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final key = controller.text.trim();
                if (key.length == 32) {
                  try {
                    await scanner.setKey(device.macAddress, key);
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Invalid key: $e')),
                      );
                    }
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      );
    }
  }
}

class _EncryptionBadge extends StatelessWidget {
  final BthomeDevice device;

  const _EncryptionBadge({required this.device});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = _getIconAndColor(theme);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }

  (IconData, Color) _getIconAndColor(ThemeData theme) {
    if (!device.isEncrypted) {
      return (Icons.sensors, theme.colorScheme.primary);
    }
    if (device.measurements.isNotEmpty) {
      return (Icons.verified_user, Colors.green);
    }
    if (device.decryptionFailed) {
      return (Icons.lock, Colors.red);
    }
    return (Icons.lock, Colors.orange);
  }
}

class _EncryptedHint extends StatelessWidget {
  final BthomeDevice device;

  const _EncryptedHint({required this.device});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isError = device.decryptionFailed;
    final color = isError ? Colors.red : theme.colorScheme.tertiary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.key, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isError ? 'Wrong key - tap to update' : 'Tap to add encryption key',
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
          Icon(Icons.chevron_right, size: 16, color: color),
        ],
      ),
    );
  }
}

class _SignalStrength extends StatelessWidget {
  final int rssi;
  final bool dimmed;

  const _SignalStrength({required this.rssi, this.dimmed = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bars = _getBars();
    final activeColor = dimmed
        ? theme.colorScheme.outline
        : theme.colorScheme.primary;
    final inactiveColor = theme.colorScheme.outlineVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (int i = 0; i < 4; i++)
          Container(
            width: 3,
            height: 6.0 + (i * 3),
            margin: const EdgeInsets.only(right: 2),
            decoration: BoxDecoration(
              color: i < bars ? activeColor : inactiveColor,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
      ],
    );
  }

  int _getBars() {
    if (rssi >= -50) return 4;
    if (rssi >= -60) return 3;
    if (rssi >= -70) return 2;
    return 1;
  }
}

class _MeasurementChip extends StatelessWidget {
  final BthomeMeasurement measurement;

  const _MeasurementChip({required this.measurement});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getIconForType(measurement.type),
            size: 16,
            color: theme.colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 6),
          Text(
            measurement.displayValue,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _getIconForType(BthomeSensorType type) {
  switch (type) {
    case BthomeSensorType.temperature:
    case BthomeSensorType.temperature01:
    case BthomeSensorType.temperatureSint8:
    case BthomeSensorType.temperatureSint8035:
      return Icons.thermostat;
    case BthomeSensorType.humidity:
    case BthomeSensorType.humidityUint8:
      return Icons.water_drop;
    case BthomeSensorType.battery:
      return Icons.battery_full;
    case BthomeSensorType.batteryLow:
      return Icons.battery_alert;
    case BthomeSensorType.pressure:
      return Icons.speed;
    case BthomeSensorType.illuminance:
      return Icons.light_mode;
    case BthomeSensorType.motion:
    case BthomeSensorType.moving:
      return Icons.directions_walk;
    case BthomeSensorType.door:
    case BthomeSensorType.opening:
      return Icons.door_front_door;
    case BthomeSensorType.windowBinary:
      return Icons.window;
    case BthomeSensorType.power:
    case BthomeSensorType.powerBinary:
      return Icons.power;
    case BthomeSensorType.voltage:
    case BthomeSensorType.voltage01:
      return Icons.bolt;
    case BthomeSensorType.current:
    case BthomeSensorType.currentSint16:
      return Icons.electrical_services;
    case BthomeSensorType.co2:
      return Icons.co2;
    case BthomeSensorType.smoke:
      return Icons.smoke_free;
    case BthomeSensorType.button:
      return Icons.touch_app;
    default:
      return Icons.sensors;
  }
}

class DeviceDetailsScreen extends StatefulWidget {
  final BthomeDevice device;
  final BleScanner scanner;

  const DeviceDetailsScreen({
    super.key,
    required this.device,
    required this.scanner,
  });

  @override
  State<DeviceDetailsScreen> createState() => _DeviceDetailsScreenState();
}

class _DeviceDetailsScreenState extends State<DeviceDetailsScreen> {
  late BthomeDevice _device;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _device = widget.device;
    widget.scanner.addListener(_onScannerUpdate);
    // Refresh UI every second to update "Last Advertisement" time
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _onScannerUpdate() {
    final updated = widget.scanner.devices.firstWhere(
      (d) => d.macAddress == widget.device.macAddress,
      orElse: () => _device,
    );
    if (mounted) {
      setState(() => _device = updated);
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    widget.scanner.removeListener(_onScannerUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_device.name ?? 'Device Details'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDeviceInfo(theme),
          const SizedBox(height: 24),
          if (_device.measurements.isNotEmpty) ...[
            Text(
              'Measurements',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ..._device.orderedMeasurements.map((m) => _MeasurementTile(measurement: m)),
          ],
        ],
      ),
    );
  }

  Widget _buildDeviceInfo(ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _EncryptionBadge(device: _device),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _device.name ?? 'Unknown Device',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _device.macAddress,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.outline,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            _RawDataRow(hex: _device.advertisementHex),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.signal_cellular_alt,
              label: 'Signal Strength',
              value: '${_device.rssi} dBm',
            ),
            if (_device.txPowerLevel != null) ...[
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.podcasts,
                label: 'TX Power',
                value: '${_device.txPowerLevel} dBm',
              ),
            ],
            if (_device.distanceString != null) ...[
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.straighten,
                label: 'Distance',
                value: _device.distanceString!,
              ),
            ],
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.access_time,
              label: 'Last Advertisement',
              value: _formatTimeSince(_device.lastSeen),
            ),
            if (_device.esphomeVersion != null) ...[
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.info_outline,
                label: 'ESPHome Version',
                value: _device.esphomeVersion!,
              ),
            ],
            if (_device.isEncrypted) ...[
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.lock,
                label: 'Encryption',
                value: _device.decryptionFailed ? 'Invalid Key' : 'Enabled',
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTimeSince(DateTime lastSeen) {
    final diff = DateTime.now().difference(lastSeen);
    if (diff.inSeconds < 5) {
      return 'Just now';
    } else if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${diff.inHours}h ago';
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: theme.colorScheme.outline,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _MeasurementTile extends StatelessWidget {
  final BthomeMeasurement measurement;

  const _MeasurementTile({required this.measurement});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getIconForType(measurement.type),
                size: 24,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        measurement.type.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _MetaBadge(
                        label: '#${measurement.orderIndex}',
                        tooltip: 'Position within the last packet',
                      ),
                      if (measurement.packetId != null) ...[
                        const SizedBox(width: 4),
                        _MetaBadge(
                          label: 'pkt ${measurement.packetId}',
                          tooltip: 'Packet ID of the last packet containing it',
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    measurement.displayValue,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  final String label;
  final String tooltip;

  const _MetaBadge({required this.label, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontFamily: 'monospace',
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _RawDataRow extends StatelessWidget {
  final String hex;

  const _RawDataRow({required this.hex});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.data_object,
              size: 18,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(width: 8),
            Text(
              'Raw',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const Spacer(),
            Text(
              '${hex.length ~/ 2} bytes',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(6),
          ),
          child: SelectableText(
            hex,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              fontFeatures: const [FontFeature.tabularFigures()],
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

