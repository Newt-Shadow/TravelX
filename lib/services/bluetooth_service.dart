import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import './ble_encryption_service.dart';
import '../utils//nickname_generator.dart';
import 'dart:convert'; // Required for utf8.encode
import './p2p_encryption_service.dart';
import './storage_service.dart';

class BluetoothService {
  static const String TRAVELX_SERVICE_UUID =
      "CDB7950D-73F1-4D4D-8E47-C090502DBD63";

  StreamSubscription<List<ScanResult>>? _scanSub;
  final StreamController<List<ScanResult>> _controller =
      StreamController.broadcast();

  final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();
  final BleEncryptionService _encryptionService = BleEncryptionService();
  final P2pEncryptionService _p2pEncryptionService = P2pEncryptionService();
  String _currentNickname = NicknameGenerator.generate();
  String? _selfId;

  bool _isActivelyAdvertising = false;
  bool _isPassivelyAdvertising = false;
  bool _isOnline = true; // Assume online by default

  Timer? _periodicScanTimer;
  bool _isContinuousScanning = false;
  bool _isAdvertisingOperationInProgress = false;

  Stream<List<ScanResult>> get stream => _controller.stream;

  BluetoothService() {
    _initialize();
  }

  Future<void> _initialize() async {
    // Get the device's own anonymous ID to filter it out from scans
    _selfId = await StorageService.getOrCreateAnonUserId();

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      if (!_controller.isClosed) {
        final List<ScanResult> otherDevices = [];
        for (var r in results) {
          // Decrypt the payload to check the unique ID
          final data = decryptScanResult(r);
          // Only add if the payload is valid and the ID is not our own
          if (data != null && data['uuid'] != _selfId) {
            otherDevices.add(r);
          }
        }
        _controller.add(otherDevices);
      }
    }, onError: (e) {
      if (!_controller.isClosed) {
        _controller.addError(e);
      }
    });

    _p2pEncryptionService.ensureKeyPair();
  }

  Future<void> updateAdvertisingData({required bool isOnline}) async {
    if (_isOnline == isOnline) return; // No change
    _isOnline = isOnline;
    if (await isAdvertising()) {
      print("🔄 Updating advertising data with network status: $_isOnline");
      await _stopAdvertising();
      await _startAdvertising();
    }
  }

  Future<bool> isAdvertising() async {
    return await _peripheral.isAdvertising;
  }

  Future<void> startActiveAdvertising(String userId) async {
    _currentNickname = NicknameGenerator.generate();
    await _startAdvertising();
    _isActivelyAdvertising = true;
    print("📢 Started ACTIVE advertising as '$_currentNickname'.");
  }

  Future<void> stopActiveAdvertising() async {
    _isActivelyAdvertising = false;
    if (!_isPassivelyAdvertising) {
      await _stopAdvertising();
      print("🛑 Stopped ACTIVE advertising.");
    }
  }

  Future<void> startPassiveAdvertising(String userId) async {
    if (await isAdvertising() || _isActivelyAdvertising) return;
    await _startAdvertising();
    _isPassivelyAdvertising = true;
    print("Started passive advertising as '$_currentNickname'.");
  }

  Future<void> stopPassiveAdvertising() async {
    _isPassivelyAdvertising = false;
    if (!_isActivelyAdvertising) {
      await _stopAdvertising();
      print("🛑 Stopped passive advertising.");
    }
  }

  Future<void> _startAdvertising() async {
    if (_isAdvertisingOperationInProgress) return;
    _isAdvertisingOperationInProgress = true;

    try {
      // Ensure we have our own ID to advertise
      _selfId ??= await StorageService.getOrCreateAnonUserId();

      final payload = {
        'name': _currentNickname,
        'ts': DateTime.now().millisecondsSinceEpoch,
        'online': _isOnline,
        'uuid': _selfId, // Add the unique ID to the payload
      };
      final encryptedPayload = _encryptionService.encryptPayload(payload);

      final advertiseData = AdvertiseData(
        serviceUuid: TRAVELX_SERVICE_UUID,
        manufacturerId: 1234,
        manufacturerData: encryptedPayload,
      );

      await _peripheral.start(advertiseData: advertiseData);
    } catch (e) {
      print("Error starting advertising: $e");
    } finally {
      _isAdvertisingOperationInProgress = false;
    }
  }

  Future<void> _stopAdvertising() async {
    if (_isAdvertisingOperationInProgress) return;
    _isAdvertisingOperationInProgress = true;
    try {
      await _peripheral.stop();
    } catch (e) {
      print("Error stopping advertising: $e");
    } finally {
      _isAdvertisingOperationInProgress = false;
    }
  }

  void startContinuousScan() {
    if (_isContinuousScanning) return;
    print("🔬 Starting continuous BLE scan for active trip.");
    _periodicScanTimer?.cancel();
    _isContinuousScanning = true;
    FlutterBluePlus.startScan(
      withServices: [Guid(TRAVELX_SERVICE_UUID)],
    ).catchError((e) {
      print("Error starting continuous scan: $e");
    });
  }

  void startPeriodicScan({
    Duration interval = const Duration(seconds: 10),
    Duration scanWindow = const Duration(seconds: 5),
  }) {
    if (!_isContinuousScanning && _periodicScanTimer?.isActive == true) return;
    print(
        "⏰ Starting periodic BLE scan (every ${interval.inSeconds}s for ${scanWindow.inSeconds}s).");
    _isContinuousScanning = false;
    _periodicScanTimer?.cancel();

    FlutterBluePlus.startScan(
      withServices: [Guid(TRAVELX_SERVICE_UUID)],
      timeout: scanWindow,
    ).catchError((e) {
      print("Error during initial periodic scan: $e");
    });

    _periodicScanTimer = Timer.periodic(interval, (timer) {
      if (_isContinuousScanning) {
        timer.cancel();
        return;
      }
      print("⏰ Performing periodic BLE scan...");
      FlutterBluePlus.startScan(
        withServices: [Guid(TRAVELX_SERVICE_UUID)],
        timeout: scanWindow,
      ).catchError((e) {
        print("Error during periodic scan: $e");
      });
    });
  }

  void stopScan() {
    print("🛑 Stopping all BLE scans.");
    _periodicScanTimer?.cancel();
    _isContinuousScanning = false;
    FlutterBluePlus.stopScan().catchError((e) {
      print("Error stopping scan: $e");
    });
  }

  Map<String, dynamic>? decryptScanResult(ScanResult result) {
    final manufacturerData = result.advertisementData.manufacturerData;
    if (manufacturerData.isNotEmpty && manufacturerData.values.isNotEmpty) {
      final encryptedBytes = manufacturerData.values.first;
      return _encryptionService.decryptPayload(Uint8List.fromList(encryptedBytes));
    }
    return null;
  }

  void dispose() {
    _scanSub?.cancel();
    _controller.close();
    stopScan();
    _stopAdvertising();
  }
}