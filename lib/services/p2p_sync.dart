import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import './bluetooth_service.dart' as app_ble;
import './p2p_encryption_service.dart';
import './storage_service.dart';

enum P2pSyncState { idle, searching, connecting, transferring, success, failed }

/// Manages peer-to-peer synchronization of trip data over BLE.
class P2pSyncService {
  final app_ble.BluetoothService _btService;
  final P2pEncryptionService _encryptionService;
  final Connectivity _connectivity = Connectivity();

  StreamSubscription? _connectivitySub;
  bool _hasInternet = true;
  P2pSyncState _state = P2pSyncState.idle;

  P2pSyncService(this._btService, this._encryptionService) {
    _init();
  }

  P2pSyncState get state => _state;

  void _init() async {
    await _encryptionService.ensureKeyPair();

    // Initial connectivity check (now returns a List)
    final results = await _connectivity.checkConnectivity();
    _handleConnectivityChange(results);

    // Subscribe to connectivity changes (also a List now)
    _connectivitySub =
        _connectivity.onConnectivityChanged.listen(_handleConnectivityChange);
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final hasConnection =
        results.contains(ConnectivityResult.mobile) ||
        results.contains(ConnectivityResult.wifi);

    if (hasConnection != _hasInternet) {
      _hasInternet = hasConnection;
      print("📶 Internet connection status changed: $_hasInternet");
      _btService.updateAdvertisingData(isOnline: _hasInternet);
      if (!_hasInternet) {
        triggerP2pSyncCheck();
      }
    }
  }

  Future<void> triggerP2pSyncCheck() async {
    if (_hasInternet || _state != P2pSyncState.idle) return;

    final pendingKeys = StorageService.pendingKeys();
    if (pendingKeys.isEmpty) {
      print(" P2P: No pending trips to sync.");
      return;
    }

    print(
        " P2P: Offline with ${pendingKeys.length} pending trips. Searching for online buddy...");
    _state = P2pSyncState.searching;

    final onlineBuddy = await _findOnlineBuddy();

    if (onlineBuddy != null) {
      await _transferDataToBuddy(onlineBuddy, pendingKeys);
    } else {
      print(" P2P: No online buddies found after scan.");
      _state = P2pSyncState.failed;
      Timer(const Duration(seconds: 30), () => _state = P2pSyncState.idle);
    }
  }

  Future<BluetoothDevice?> _findOnlineBuddy() async {
    try {
      // Start scan with the service filter (no scanMode in v1.4.0)
      await FlutterBluePlus.startScan(
        withServices: [Guid(app_ble.BluetoothService.TRAVELX_SERVICE_UUID)],
        timeout: const Duration(seconds: 5),
      );

      // Collect scan results
      final scanResults = await FlutterBluePlus.scanResults.first.timeout(
        const Duration(seconds: 5),
        onTimeout: () => [],
      );

      for (final r in scanResults) {
        final data = _btService.decryptScanResult(r);
        if (data != null && data['online'] == true) {
          print(" P2P: Found online buddy: ${r.device.remoteId}");
          await FlutterBluePlus.stopScan();
          return r.device;
        }
      }
    } catch (e) {
      print(" P2P: Error while scanning for buddies: $e");
    } finally {
      await FlutterBluePlus.stopScan();
    }

    return null;
  }

  Future<void> _transferDataToBuddy(
      BluetoothDevice device, List<String> keys) async {
    _state = P2pSyncState.connecting;
    print(" P2P: Connecting to buddy ${device.remoteId}...");
    try {
      await device.connect();
      print(" P2P: Connected. Discovering services...");

      final services = await device.discoverServices();
      BluetoothCharacteristic? transferChar;

      print(" P2P: Data transfer simulation complete.");
      _state = P2pSyncState.success;
    } catch (e) {
      print(" P2P: Error during data transfer: $e");
      _state = P2pSyncState.failed;
    } finally {
      await device.disconnect();
      Timer(const Duration(seconds: 5), () => _state = P2pSyncState.idle);
    }
  }

  void dispose() {
    _connectivitySub?.cancel();
  }
}
