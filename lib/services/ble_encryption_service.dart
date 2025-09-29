import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:crypto/crypto.dart';

/// A service to handle encryption and decryption of BLE advertisement payloads.
class BleEncryptionService {
  static const String _serviceUuid = "CDB7950D-73F1-4D4D-8E47-C090502DBD63";
  late final Encrypter _encrypter;
  late final IV _iv;

  BleEncryptionService() {
    // Derive a stable key and IV from the service UUID.
    // This ensures all instances of the app can decrypt messages from each other.
    final keyDigest = sha256.convert(utf8.encode('${_serviceUuid}_key'));
    final ivDigest = sha1.convert(utf8.encode('${_serviceUuid}_iv'));

    final key = Key(Uint8List.fromList(keyDigest.bytes));
    _iv = IV(Uint8List.fromList(ivDigest.bytes.sublist(0, 16)));
    _encrypter = Encrypter(AES(key, mode: AESMode.cbc, padding: 'PKCS7'));
  }

  /// Encrypts a data payload.
  Uint8List encryptPayload(Map<String, dynamic> data) {
    final jsonString = jsonEncode(data);
    final encrypted = _encrypter.encrypt(jsonString, iv: _iv);
    return encrypted.bytes;
  }

  /// Decrypts a data payload.
  /// Returns null if decryption fails.
  Map<String, dynamic>? decryptPayload(Uint8List encryptedBytes) {
    try {
      final encrypted = Encrypted(encryptedBytes);
      final decrypted = _encrypter.decrypt(encrypted, iv: _iv);
      return jsonDecode(decrypted) as Map<String, dynamic>;
    } catch (e) {
      // This will happen if we scan a device that is not another TravelX app.
      // It's expected and can be ignored.
      return null;
    }
  }
}
