import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/bthome_device.dart';
import 'key_storage.dart';

/// BLE Scanner service for discovering BTHome devices
class BleScanner extends ChangeNotifier {
  final Map<String, BthomeDevice> _devices = {};
  final Map<String, Uint8List> _keyCache = {};
  bool _isScanning = false;
  String? _error;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothAdapterState>? _adapterSubscription;
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;

  /// When true, incoming scan results are discarded so the displayed device
  /// data stays frozen on whatever was last received.
  bool _paused = false;

  /// When true, the scanner automatically transitions to [_paused] as soon as
  /// it observes a BTHome packet whose packet_id differs from the one already
  /// stored for that device.
  bool _autoPause = false;

  /// Chronological log of distinct BTHome packets seen this session. Each
  /// entry is a fresh parse snapshot (before merging into the live device
  /// view), so its `measurements` reflect exactly what was in that one
  /// advertisement. Consecutive identical raw payloads from the same device
  /// are deduplicated to avoid flooding from retransmissions.
  final List<BthomeDevice> _history = [];
  static const int _historyMax = 500;

  /// All discovered BTHome devices (sorted by RSSI)
  List<BthomeDevice> get devices {
    final list = _devices.values.toList();
    // Sort by RSSI (stronger signal first)
    list.sort((a, b) => b.rssi.compareTo(a.rssi));
    return list;
  }

  /// Whether scanning is currently active
  bool get isScanning => _isScanning;

  /// Whether incoming packets are currently being ignored (frozen view).
  bool get isPaused => _paused;

  /// Whether auto-pause mode is armed.
  bool get isAutoPause => _autoPause;

  /// Pause processing of incoming packets. The BLE scan keeps running so
  /// resuming is instantaneous, but no device state is mutated until
  /// [resume] is called.
  void pause() {
    if (_paused) return;
    _paused = true;
    notifyListeners();
  }

  /// Resume processing of incoming packets.
  void resume() {
    if (!_paused) return;
    _paused = false;
    notifyListeners();
  }

  void togglePause() => _paused ? resume() : pause();

  /// Toggle auto-pause mode. When armed, the next BTHome packet whose
  /// packet_id differs from the currently-stored one will pause the scanner
  /// automatically (and discard that triggering packet so the prior data
  /// stays visible).
  void toggleAutoPause() {
    _autoPause = !_autoPause;
    notifyListeners();
  }

  /// Chronological packet log (oldest first).
  List<BthomeDevice> get history => List.unmodifiable(_history);

  /// Clear the packet history log.
  void clearHistory() {
    if (_history.isEmpty) return;
    _history.clear();
    notifyListeners();
  }

  bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Push a freshly parsed BTHome device snapshot onto the history log,
  /// dropping retransmissions of the identical payload from the same device.
  void _addToHistory(BthomeDevice device) {
    if (device.rawServiceData == null) return;
    // Look back to the most recent entry for this MAC and skip if identical.
    for (var i = _history.length - 1; i >= 0; i--) {
      if (_history[i].macAddress == device.macAddress) {
        final prev = _history[i].rawServiceData;
        if (prev != null && _bytesEqual(prev, device.rawServiceData!)) {
          return;
        }
        break;
      }
    }
    _history.add(device);
    while (_history.length > _historyMax) {
      _history.removeAt(0);
    }
  }

  /// Extract the packet_id measurement value from a device, if present.
  int? _packetIdOf(BthomeDevice device) {
    for (final m in device.measurements) {
      if (m.type == BthomeSensorType.packetId) {
        return m.value.toInt();
      }
    }
    return null;
  }

  /// Current error message, if any
  String? get error => _error;

  /// Bluetooth adapter state
  BluetoothAdapterState get adapterState => _adapterState;

  /// Whether Bluetooth is available and on
  bool get isBluetoothReady => _adapterState == BluetoothAdapterState.on;

  BleScanner() {
    FlutterBluePlus.setLogLevel(LogLevel.warning, color: false);
    _initAdapterListener();
    _loadKeys();
  }

  void _initAdapterListener() {
    _adapterSubscription = FlutterBluePlus.adapterState.listen((state) {
      _adapterState = state;
      notifyListeners();

      if (state == BluetoothAdapterState.on && !_isScanning) {
        // Auto-start scanning when Bluetooth becomes available
        startScan();
      } else if (state != BluetoothAdapterState.on && _isScanning) {
        stopScan();
      }
    });
  }

  Future<void> _loadKeys() async {
    final storedDevices = await KeyStorage.getStoredDevices();
    for (final mac in storedDevices) {
      final key = await KeyStorage.getKey(mac);
      if (key != null) {
        _keyCache[mac.toUpperCase().replaceAll(':', '').replaceAll('-', '')] = key;
      }
    }
  }

  /// Add or update encryption key for a device
  Future<void> setKey(String macAddress, String keyHex) async {
    await KeyStorage.setKeyFromHex(macAddress, keyHex);
    final key = await KeyStorage.getKey(macAddress);
    if (key != null) {
      final normalizedMac = macAddress.toUpperCase().replaceAll(':', '').replaceAll('-', '');
      _keyCache[normalizedMac] = key;
      if (_devices.containsKey(macAddress)) {
        notifyListeners();
      }
    }
  }

  /// Remove encryption key for a device
  Future<void> removeKey(String macAddress) async {
    await KeyStorage.removeKey(macAddress);
    final normalizedMac = macAddress.toUpperCase().replaceAll(':', '').replaceAll('-', '');
    _keyCache.remove(normalizedMac);
    notifyListeners();
  }

  /// Check if device has stored key
  bool hasKey(String macAddress) {
    final normalizedMac = macAddress.toUpperCase().replaceAll(':', '').replaceAll('-', '');
    return _keyCache.containsKey(normalizedMac);
  }

  /// Start scanning for BTHome devices
  Future<void> startScan() async {
    if (_isScanning) return;

    _error = null;

    if (_adapterState != BluetoothAdapterState.on) {
      _error = 'Bluetooth is not available';
      notifyListeners();
      return;
    }

    try {
      _isScanning = true;
      notifyListeners();

      _scanSubscription = FlutterBluePlus.onScanResults.listen(
        _handleScanResults,
        onError: (e) {
          _error = 'Scan error: $e';
          _isScanning = false;
          notifyListeners();
        },
      );

      // Auto-cancel subscription when scan completes
      FlutterBluePlus.cancelWhenScanComplete(_scanSubscription!);

      // Continuous scanning - no timeout
      // BTHome uses service DATA (0xFCD2), not advertised service UUIDs
      await FlutterBluePlus.startScan(
        androidScanMode: AndroidScanMode.lowLatency,
        continuousUpdates: true,
      );
    } catch (e) {
      _error = 'Failed to start scan: $e';
      _isScanning = false;
      notifyListeners();
    }
  }

  void _handleScanResults(List<ScanResult> results) async {
    if (_paused) return;
    for (final result in results) {
      final macAddress = result.device.remoteId.str;
      final name = result.advertisementData.advName;
      final serviceData = result.advertisementData.serviceData;

      // Check if this device has BTHome service data
      // Use string comparison since Guid equality may fail
      final bthomeKey = serviceData.keys.firstWhere(
        (key) => key.str.toLowerCase().contains('fcd2'),
        orElse: () => Guid('00000000-0000-0000-0000-000000000000'),
      );
      final hasBthomeData = bthomeKey.str.toLowerCase().contains('fcd2');

      if (hasBthomeData) {
        final data = serviceData[bthomeKey]!;
        final normalizedMac = macAddress.toUpperCase().replaceAll(':', '').replaceAll('-', '');

        // Extract scan response data
        final txPowerLevel = result.advertisementData.txPowerLevel;
        final appearance = result.advertisementData.appearance;

        // Extract manufacturer data (first entry if exists)
        int? manufacturerId;
        Uint8List? manufacturerData;
        if (result.advertisementData.manufacturerData.isNotEmpty) {
          final entry = result.advertisementData.manufacturerData.entries.first;
          manufacturerId = entry.key;
          manufacturerData = Uint8List.fromList(entry.value);
        }

        final device = await BthomeParser.parse(
          macAddress: macAddress,
          name: name.isNotEmpty ? name : null,
          rssi: result.rssi,
          serviceData: Uint8List.fromList(data),
          encryptionKey: _keyCache[normalizedMac],
          txPowerLevel: txPowerLevel,
          appearance: appearance,
          manufacturerId: manufacturerId,
          manufacturerData: manufacturerData,
        );

        if (device != null) {
          // Record this packet to the chronological history before merging
          // into the live device view, so the log reflects exactly what was
          // on the wire (single-packet measurements, original order).
          _addToHistory(device);

          // Merge measurements from multiple packets (e.g., weather stations)
          final existing = _devices[macAddress];

          // Auto-pause: if the just-parsed packet has a different packet_id
          // than the one already stored for this device, we still apply this
          // packet (so the details page shows what triggered the pause), but
          // we flip into _paused right after, before any further packets in
          // this batch get processed.
          bool autoPauseTriggered = false;
          if (_autoPause && existing != null) {
            final oldId = _packetIdOf(existing);
            final newId = _packetIdOf(device);
            if (oldId != null && newId != null && oldId != newId) {
              autoPauseTriggered = true;
            }
          }

          if (existing != null && device.measurements.isNotEmpty) {
            // Create a map of measurements by type for merging
            final measurementMap = <int, BthomeMeasurement>{};

            // Add existing measurements first
            for (final m in existing.measurements) {
              measurementMap[m.type.objectId] = m;
            }

            // Update/add new measurements
            for (final m in device.measurements) {
              measurementMap[m.type.objectId] = m;
            }

            // Create merged device with combined measurements
            _devices[macAddress] = device.copyWith(
              measurements: measurementMap.values.toList(),
              // Preserve existing scan response data if new one is missing
              txPowerLevel: device.txPowerLevel ?? existing.txPowerLevel,
              appearance: device.appearance ?? existing.appearance,
              manufacturerId: device.manufacturerId ?? existing.manufacturerId,
              esphomeVersion: device.esphomeVersion ?? existing.esphomeVersion,
            );
          } else {
            _devices[macAddress] = device;
          }

          // Flip into paused state AFTER the triggering packet has been
          // merged in, so the live view shows the packet that caused the
          // freeze. Skip any remaining results in this batch.
          if (autoPauseTriggered) {
            _paused = true;
            notifyListeners();
            return;
          }
          notifyListeners();
        }
      }
      // Skip non-BTHome devices - only show BTHome devices
    }
  }

  /// Stop scanning
  Future<void> stopScan() async {
    if (!_isScanning) return;

    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      // Ignore stop scan errors
    }

    _isScanning = false;
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    notifyListeners();
  }

  /// Clear all discovered devices
  void clearDevices() {
    _devices.clear();
    notifyListeners();
  }

  /// Refresh scan (stop and start)
  Future<void> refresh() async {
    await stopScan();
    clearDevices();
    await startScan();
  }

  @override
  void dispose() {
    stopScan();
    _adapterSubscription?.cancel();
    super.dispose();
  }
}
