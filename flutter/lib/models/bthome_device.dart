import 'dart:math' as math;
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

/// BTHome service UUID (0xFCD2)
const int bthomeServiceUuid = 0xFCD2;

/// Device info byte flags
const int bthomeUnencrypted = 0x40;
const int bthomeEncrypted = 0x41;
const int bthomeTriggerUnencrypted = 0x44;
const int bthomeTriggerEncrypted = 0x45;

/// BTHome sensor types with their properties
enum BthomeSensorType {
  packetId(0x00, 'Packet ID', '', 1, false, 1.0),
  battery(0x01, 'Battery', '%', 1, false, 1.0),
  temperature(0x02, 'Temperature', '°C', 2, true, 0.01),
  humidity(0x03, 'Humidity', '%', 2, false, 0.01),
  pressure(0x04, 'Pressure', 'hPa', 3, false, 0.01),
  illuminance(0x05, 'Illuminance', 'lux', 3, false, 0.01),
  massKg(0x06, 'Mass', 'kg', 2, false, 0.01),
  massLb(0x07, 'Mass', 'lb', 2, false, 0.01),
  dewpoint(0x08, 'Dew Point', '°C', 2, true, 0.01),
  countUint8(0x09, 'Count', '', 1, false, 1.0),
  energy(0x0A, 'Energy', 'kWh', 3, false, 0.001),
  power(0x0B, 'Power', 'W', 3, false, 0.01),
  voltage(0x0C, 'Voltage', 'V', 2, false, 0.001),
  pm25(0x0D, 'PM2.5', 'µg/m³', 2, false, 1.0),
  pm10(0x0E, 'PM10', 'µg/m³', 2, false, 1.0),
  genericBoolean(0x0F, 'Generic', '', 1, false, 1.0, isBinary: true),
  powerBinary(0x10, 'Power', '', 1, false, 1.0, isBinary: true),
  opening(0x11, 'Opening', '', 1, false, 1.0, isBinary: true),
  co2(0x12, 'CO2', 'ppm', 2, false, 1.0),
  tvoc(0x13, 'TVOC', 'µg/m³', 2, false, 1.0),
  moisture(0x14, 'Moisture', '%', 2, false, 0.01),
  batteryLow(0x15, 'Battery Low', '', 1, false, 1.0, isBinary: true),
  batteryCharging(0x16, 'Charging', '', 1, false, 1.0, isBinary: true),
  co(0x17, 'CO', '', 1, false, 1.0, isBinary: true),
  cold(0x18, 'Cold', '', 1, false, 1.0, isBinary: true),
  connectivity(0x19, 'Connectivity', '', 1, false, 1.0, isBinary: true),
  door(0x1A, 'Door', '', 1, false, 1.0, isBinary: true),
  garageDoor(0x1B, 'Garage Door', '', 1, false, 1.0, isBinary: true),
  gas(0x1C, 'Gas', '', 1, false, 1.0, isBinary: true),
  heat(0x1D, 'Heat', '', 1, false, 1.0, isBinary: true),
  light(0x1E, 'Light', '', 1, false, 1.0, isBinary: true),
  lock(0x1F, 'Lock', '', 1, false, 1.0, isBinary: true),
  moistureBinary(0x20, 'Moisture', '', 1, false, 1.0, isBinary: true),
  motion(0x21, 'Motion', '', 1, false, 1.0, isBinary: true),
  moving(0x22, 'Moving', '', 1, false, 1.0, isBinary: true),
  occupancy(0x23, 'Occupancy', '', 1, false, 1.0, isBinary: true),
  plug(0x24, 'Plug', '', 1, false, 1.0, isBinary: true),
  presence(0x25, 'Presence', '', 1, false, 1.0, isBinary: true),
  problem(0x26, 'Problem', '', 1, false, 1.0, isBinary: true),
  running(0x27, 'Running', '', 1, false, 1.0, isBinary: true),
  safety(0x28, 'Safety', '', 1, false, 1.0, isBinary: true),
  smoke(0x29, 'Smoke', '', 1, false, 1.0, isBinary: true),
  sound(0x2A, 'Sound', '', 1, false, 1.0, isBinary: true),
  tamper(0x2B, 'Tamper', '', 1, false, 1.0, isBinary: true),
  vibration(0x2C, 'Vibration', '', 1, false, 1.0, isBinary: true),
  windowBinary(0x2D, 'Window', '', 1, false, 1.0, isBinary: true),
  humidityUint8(0x2E, 'Humidity', '%', 1, false, 1.0),
  moistureUint8(0x2F, 'Moisture', '%', 1, false, 1.0),
  countUint16(0x3D, 'Count', '', 2, false, 1.0),
  countUint32(0x3E, 'Count', '', 4, false, 1.0),
  rotation(0x3F, 'Rotation', '°', 2, true, 0.1),
  distanceMm(0x40, 'Distance', 'mm', 2, false, 1.0),
  distanceM(0x41, 'Distance', 'm', 2, false, 0.1),
  duration(0x42, 'Duration', 's', 3, false, 0.001),
  current(0x43, 'Current', 'A', 2, false, 0.001),
  speed(0x44, 'Speed', 'm/s', 2, false, 0.01),
  temperature01(0x45, 'Temperature', '°C', 2, true, 0.1),
  uvIndex(0x46, 'UV Index', '', 1, false, 0.1),
  volumeLiter(0x47, 'Volume', 'L', 2, false, 0.1),
  volumeMl(0x48, 'Volume', 'mL', 2, false, 1.0),
  volumeFlowRate(0x49, 'Flow Rate', 'm³/hr', 2, false, 0.001),
  voltage01(0x4A, 'Voltage', 'V', 2, false, 0.1),
  gas2(0x4B, 'Gas', '', 3, false, 0.001),
  gas3(0x4C, 'Gas', '', 4, false, 0.001),
  energyUint32(0x4D, 'Energy', 'kWh', 4, false, 0.001),
  volumeUint32(0x4E, 'Volume', 'L', 4, false, 0.001),
  water(0x4F, 'Water', '', 4, false, 0.001),
  timestamp(0x50, 'Timestamp', '', 4, false, 1.0),
  acceleration(0x51, 'Acceleration', 'm/s²', 2, false, 0.001),
  gyroscope(0x52, 'Gyroscope', '°/s', 2, false, 0.001),
  text(0x53, 'Text', '', 0, false, 1.0),
  raw(0x54, 'Raw', '', 0, false, 1.0),
  volumeStorage(0x55, 'Volume', 'L', 4, false, 0.001),
  conductivity(0x56, 'Conductivity', 'µS/cm', 2, false, 1.0),
  temperatureSint8(0x57, 'Temperature', '°C', 1, true, 1.0),
  temperatureSint8035(0x58, 'Temperature', '°C', 1, true, 0.35),
  countSint8(0x59, 'Count', '', 1, true, 1.0),
  countSint16(0x5A, 'Count', '', 2, true, 1.0),
  countSint32(0x5B, 'Count', '', 4, true, 1.0),
  powerSint32(0x5C, 'Power', 'W', 4, true, 0.01),
  currentSint16(0x5D, 'Current', 'A', 2, true, 0.001),
  direction(0x5E, 'Direction', '°', 2, false, 0.01),
  precipitation(0x5F, 'Precipitation', 'mm', 2, false, 0.1),
  channel(0x60, 'Channel', '', 1, false, 1.0),
  rotationalSpeed(0x61, 'Rotational Speed', 'rpm', 2, false, 1.0),
  button(0x3A, 'Button', '', 1, false, 1.0),
  dimmer(0x3C, 'Dimmer', '', 2, false, 1.0);

  final int objectId;
  final String name;
  final String unit;
  final int dataBytes;
  final bool isSigned;
  final double factor;
  final bool isBinary;

  const BthomeSensorType(
    this.objectId,
    this.name,
    this.unit,
    this.dataBytes,
    this.isSigned,
    this.factor, {
    this.isBinary = false,
  });

  static BthomeSensorType? fromObjectId(int id) {
    for (final type in BthomeSensorType.values) {
      if (type.objectId == id) {
        return type;
      }
    }
    return null;
  }
}

/// Represents a single BTHome measurement
class BthomeMeasurement {
  final BthomeSensorType type;
  final double value;
  final DateTime timestamp;

  /// Position of the measurement within the most recent BTHome packet it
  /// appeared in. Useful to verify that ordering stays stable across packets.
  final int orderIndex;

  /// Packet ID (object 0x00) of the most recent BTHome packet this measurement
  /// arrived in. Null if the packet did not contain a packet_id field.
  final int? packetId;

  BthomeMeasurement({
    required this.type,
    required this.value,
    this.orderIndex = 0,
    this.packetId,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  String get displayValue {
    if (type.isBinary) {
      return value == 1.0 ? 'On' : 'Off';
    }
    final formatted = value.toStringAsFixed(
      value.truncateToDouble() == value ? 0 : 2,
    );
    return type.unit.isEmpty ? formatted : '$formatted ${type.unit}';
  }
}

/// Represents a BLE device (BTHome or generic)
class BthomeDevice {
  final String macAddress;
  final String? name;
  final int rssi;
  final bool isBthome;
  final bool isEncrypted;
  final bool decryptionFailed;
  final List<BthomeMeasurement> measurements;
  final Uint8List? rawServiceData;
  final DateTime lastSeen;
  // Scan response data
  final int? txPowerLevel;
  final int? appearance;
  final int? manufacturerId;
  final String? esphomeVersion;

  BthomeDevice({
    required this.macAddress,
    this.name,
    required this.rssi,
    this.isBthome = true,
    this.isEncrypted = false,
    this.decryptionFailed = false,
    this.measurements = const [],
    this.rawServiceData,
    DateTime? lastSeen,
    this.txPowerLevel,
    this.appearance,
    this.manufacturerId,
    this.esphomeVersion,
  }) : lastSeen = lastSeen ?? DateTime.now();

  /// Get appearance name from code
  String? get appearanceName {
    if (appearance == null) return null;
    switch (appearance) {
      case 0x0540:
        return 'Sensor';
      case 0x0541:
        return 'Motion Sensor';
      case 0x0542:
        return 'Contact Sensor';
      case 0x0300:
        return 'Thermometer';
      default:
        return 'Device (0x${appearance!.toRadixString(16)})';
    }
  }

  /// Calculate estimated distance in meters from RSSI and TX power
  /// Uses log-distance path loss model: d = 10 ^ ((txPower - rssi) / (10 * n))
  /// where n is path loss exponent (2.0 for free space, 2.5-4.0 for indoors)
  double? get estimatedDistance {
    if (txPowerLevel == null) return null;
    const pathLossExponent = 2.5; // Indoor environment
    final distance = _pow(10, (txPowerLevel! - rssi) / (10 * pathLossExponent));
    return distance;
  }

  /// Get distance as formatted string
  String? get distanceString {
    final dist = estimatedDistance;
    if (dist == null) return null;
    if (dist < 1) {
      return '${(dist * 100).toStringAsFixed(0)} cm';
    } else if (dist < 10) {
      return '${dist.toStringAsFixed(1)} m';
    } else {
      return '${dist.toStringAsFixed(0)} m';
    }
  }

  static double _pow(num base, num exponent) {
    return math.pow(base.toDouble(), exponent.toDouble()).toDouble();
  }

  /// Create a generic (non-BTHome) BLE device
  factory BthomeDevice.generic({
    required String macAddress,
    String? name,
    required int rssi,
  }) {
    return BthomeDevice(
      macAddress: macAddress,
      name: name,
      rssi: rssi,
      isBthome: false,
      isEncrypted: false,
      measurements: const [],
    );
  }

  /// Get advertisement data as hex string for copying
  String get advertisementHex {
    if (rawServiceData == null || rawServiceData!.isEmpty) {
      return macAddress;
    }
    return rawServiceData!
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join('');
  }

  List<BthomeMeasurement> get orderedMeasurements {
    return measurements..sort(
      (a, b) =>
          ((a.packetId ?? 0) * 1000 + a.orderIndex) -
          ((b.packetId ?? 0) * 1000 + b.orderIndex),
    );
  }

  BthomeDevice copyWith({
    String? macAddress,
    String? name,
    int? rssi,
    bool? isBthome,
    bool? isEncrypted,
    bool? decryptionFailed,
    List<BthomeMeasurement>? measurements,
    Uint8List? rawServiceData,
    DateTime? lastSeen,
    int? txPowerLevel,
    int? appearance,
    int? manufacturerId,
    String? esphomeVersion,
  }) {
    return BthomeDevice(
      macAddress: macAddress ?? this.macAddress,
      name: name ?? this.name,
      rssi: rssi ?? this.rssi,
      isBthome: isBthome ?? this.isBthome,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      decryptionFailed: decryptionFailed ?? this.decryptionFailed,
      measurements: measurements ?? this.measurements,
      rawServiceData: rawServiceData ?? this.rawServiceData,
      lastSeen: lastSeen ?? this.lastSeen,
      txPowerLevel: txPowerLevel ?? this.txPowerLevel,
      appearance: appearance ?? this.appearance,
      manufacturerId: manufacturerId ?? this.manufacturerId,
      esphomeVersion: esphomeVersion ?? this.esphomeVersion,
    );
  }
}

/// Parser for BTHome service data with encryption support
class BthomeParser {
  /// Parse ESPHome version from manufacturer data (4 bytes after manufacturer ID)
  static String? parseEsphomeVersion(Uint8List mfrData) {
    if (mfrData.length < 4) return null;
    // Version code is little-endian: [patch, minor, major_low, major_high]
    final patch = mfrData[0];
    final minor = mfrData[1];
    final major = mfrData[2] | (mfrData[3] << 8);
    return '$major.$minor.$patch';
  }

  /// Parse BTHome service data from raw bytes
  static Future<BthomeDevice?> parse({
    required String macAddress,
    String? name,
    required int rssi,
    required Uint8List serviceData,
    Uint8List? encryptionKey,
    int? txPowerLevel,
    int? appearance,
    int? manufacturerId,
    Uint8List? manufacturerData,
  }) async {
    if (serviceData.isEmpty) return null;

    // Parse ESPHome version from manufacturer data
    String? esphomeVersion;
    if (manufacturerData != null && manufacturerData.length >= 4) {
      esphomeVersion = parseEsphomeVersion(manufacturerData);
    }

    final deviceInfo = serviceData[0];
    final isEncrypted =
        deviceInfo == bthomeEncrypted || deviceInfo == bthomeTriggerEncrypted;

    if (isEncrypted) {
      if (encryptionKey == null || encryptionKey.length != 16) {
        return BthomeDevice(
          macAddress: macAddress,
          name: name,
          rssi: rssi,
          isEncrypted: true,
          measurements: [],
          rawServiceData: serviceData,
          txPowerLevel: txPowerLevel,
          appearance: appearance,
          manufacturerId: manufacturerId,
          esphomeVersion: esphomeVersion,
        );
      }

      // Try to decrypt
      final decrypted = _decrypt(
        macAddress: macAddress,
        deviceInfo: deviceInfo,
        serviceData: serviceData,
        key: encryptionKey,
      );

      if (decrypted == null) {
        return BthomeDevice(
          macAddress: macAddress,
          name: name,
          rssi: rssi,
          isEncrypted: true,
          decryptionFailed: true,
          measurements: [],
          rawServiceData: serviceData,
          txPowerLevel: txPowerLevel,
          appearance: appearance,
          manufacturerId: manufacturerId,
          esphomeVersion: esphomeVersion,
        );
      }

      final measurements = _parseMeasurements(decrypted);
      return BthomeDevice(
        macAddress: macAddress,
        name: name,
        rssi: rssi,
        isEncrypted: true,
        measurements: measurements,
        rawServiceData: serviceData,
        txPowerLevel: txPowerLevel,
        appearance: appearance,
        manufacturerId: manufacturerId,
        esphomeVersion: esphomeVersion,
      );
    }

    final measurements = _parseMeasurements(serviceData.sublist(1));
    return BthomeDevice(
      macAddress: macAddress,
      name: name,
      rssi: rssi,
      isEncrypted: false,
      measurements: measurements,
      rawServiceData: serviceData,
      txPowerLevel: txPowerLevel,
      appearance: appearance,
      manufacturerId: manufacturerId,
      esphomeVersion: esphomeVersion,
    );
  }

  /// Decrypt BTHome encrypted payload using AES-CCM
  static Uint8List? _decrypt({
    required String macAddress,
    required int deviceInfo,
    required Uint8List serviceData,
    required Uint8List key,
  }) {
    // Encrypted format: [device_info(1)][ciphertext(n)][mic(4)][counter(4)]
    // Total: 1 + n + 4 + 4 = at least 9 bytes for empty payload
    if (serviceData.length < 9) return null;

    // Extract counter (last 4 bytes)
    final counterBytes = serviceData.sublist(serviceData.length - 4);

    // Extract MIC (4 bytes before counter)
    final mic = serviceData.sublist(
      serviceData.length - 8,
      serviceData.length - 4,
    );

    // Extract ciphertext (between device_info and mic)
    final ciphertext = serviceData.sublist(1, serviceData.length - 8);
    if (ciphertext.isEmpty) return Uint8List(0);

    // Build nonce (13 bytes): MAC(6) + UUID(2) + device_info(1) + counter(4)
    final macBytes = _parseMacAddress(macAddress);
    if (macBytes == null) return null;

    final nonce = Uint8List(13);
    nonce.setRange(0, 6, macBytes);
    nonce[6] = 0xD2; // BTHome UUID low byte
    nonce[7] = 0xFC; // BTHome UUID high byte
    nonce[8] = deviceInfo;
    nonce.setRange(9, 13, counterBytes);

    // Decrypt using AES-CCM with pointycastle
    try {
      final ccm = CCMBlockCipher(AESEngine());
      final params = AEADParameters(
        KeyParameter(key),
        32, // 4 bytes * 8 = 32 bits MAC
        nonce,
        Uint8List(0), // no additional authenticated data
      );

      ccm.init(false, params); // false = decrypt

      // CCM expects ciphertext + MAC concatenated
      final ciphertextWithMac = Uint8List(ciphertext.length + mic.length);
      ciphertextWithMac.setRange(0, ciphertext.length, ciphertext);
      ciphertextWithMac.setRange(
        ciphertext.length,
        ciphertextWithMac.length,
        mic,
      );

      final plaintext = Uint8List(ccm.getOutputSize(ciphertextWithMac.length));
      final len = ccm.processBytes(
        ciphertextWithMac,
        0,
        ciphertextWithMac.length,
        plaintext,
        0,
      );
      ccm.doFinal(plaintext, len);

      return plaintext.sublist(0, ciphertext.length);
    } catch (e) {
      return null;
    }
  }

  /// Parse MAC address string to bytes (reversed for little-endian)
  static Uint8List? _parseMacAddress(String mac) {
    final cleanMac = mac.replaceAll(':', '').replaceAll('-', '');
    if (cleanMac.length != 12) return null;

    try {
      final bytes = Uint8List(6);
      for (var i = 0; i < 6; i++) {
        bytes[5 - i] = int.parse(
          cleanMac.substring(i * 2, i * 2 + 2),
          radix: 16,
        );
      }
      return bytes;
    } catch (e) {
      return null;
    }
  }

  /// Parse measurements from decrypted/unencrypted payload
  static List<BthomeMeasurement> _parseMeasurements(Uint8List data) {
    // First pass: collect (type, value) pairs in order and locate packet_id.
    final parsed = <({BthomeSensorType type, double value})>[];
    var offset = 0;
    int? packetId;

    while (offset < data.length) {
      final objectId = data[offset];
      offset++;

      final sensorType = BthomeSensorType.fromObjectId(objectId);
      if (sensorType == null) {
        break;
      }

      if (offset + sensorType.dataBytes > data.length) {
        break;
      }

      final value = _parseValue(
        data,
        offset,
        sensorType.dataBytes,
        sensorType.isSigned,
        sensorType.factor,
      );

      if (sensorType == BthomeSensorType.packetId) {
        packetId = value.toInt();
      }
      parsed.add((type: sensorType, value: value));
      offset += sensorType.dataBytes;
    }

    // Second pass: stamp each measurement with its position in this packet
    // and the packet_id (if any) of the containing packet.
    final measurements = <BthomeMeasurement>[];
    for (var i = 0; i < parsed.length; i++) {
      measurements.add(
        BthomeMeasurement(
          type: parsed[i].type,
          value: parsed[i].value,
          orderIndex: i,
          packetId: packetId,
        ),
      );
    }
    return measurements;
  }

  static double _parseValue(
    Uint8List data,
    int offset,
    int bytes,
    bool isSigned,
    double factor,
  ) {
    int rawValue = 0;

    for (var i = 0; i < bytes; i++) {
      rawValue |= data[offset + i] << (8 * i);
    }

    if (isSigned) {
      final maxPositive = 1 << (8 * bytes - 1);
      if (rawValue >= maxPositive) {
        rawValue -= 1 << (8 * bytes);
      }
    }

    return rawValue * factor;
  }
}
