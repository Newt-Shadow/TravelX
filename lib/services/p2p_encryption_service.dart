import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import './storage_service.dart';
import 'package:asn1lib/asn1lib.dart';

/// Handles RSA key generation and end-to-end encryption for P2P sync.
class P2pEncryptionService {
  static const _keyIdentifier = 'p2p_rsa_keypair';
  AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>? _keyPair;

  /// Ensures an RSA key pair exists, generating one if necessary.
  Future<void> ensureKeyPair() async {
    if (_keyPair != null) return;

    final existingKeys = StorageService.box.get(_keyIdentifier);
    if (existingKeys is Map) {
      try {
        _keyPair = _decodeKeyPair(Map<String, String>.from(existingKeys.cast()));
        print("🔑 Loaded existing P2P RSA key pair from storage.");
        return;
      } catch (e) {
        print("⚠️ Could not decode existing keypair, generating a new one. Error: $e");
      }
    }

    print("🔑 No valid P2P RSA key pair found, generating a new one...");
    _keyPair = _generateRsaKeyPair();
    await _saveKeyPair(_keyPair!);
    print("✅ New P2P RSA key pair generated and saved.");
  }

  /// Encrypts data using a public key.
  Uint8List encryptForBackend(String jsonData, RSAPublicKey backendPublicKey) {
    final encrypter = PKCS1Encoding(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(backendPublicKey));
    final utf8Data = utf8.encode(jsonData);
    return encrypter.process(Uint8List.fromList(utf8Data));
  }

  String decryptWithPrivateKey(Uint8List encryptedData) {
    if (_keyPair == null) throw Exception("Keypair not initialized");
    final decrypter = PKCS1Encoding(RSAEngine())
      ..init(false, PrivateKeyParameter<RSAPrivateKey>(_keyPair!.privateKey));
    final decryptedBytes = decrypter.process(encryptedData);
    return utf8.decode(decryptedBytes);
  }

  String getPublicKeyAsPem() {
    if (_keyPair == null) throw Exception("Keypair not initialized");
    return _encodePublicKeyToPem(_keyPair!.publicKey);
  }

  AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> _generateRsaKeyPair() {
    final keyGen = RSAKeyGenerator()
      ..init(ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
        _createSecureRandom(),
      ));
    return keyGen.generateKeyPair() as AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>;
  }

  SecureRandom _createSecureRandom() {
    final secureRandom = FortunaRandom();
    final seedSource = Random.secure();
    final seeds = List<int>.generate(32, (_) => seedSource.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));
    return secureRandom;
  }

  Future<void> _saveKeyPair(AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> pair) async {
    final publicKeyPem = _encodePublicKeyToPem(pair.publicKey);
    final privateKeyPem = _encodePrivateKeyToPem(pair.privateKey);
    await StorageService.box.put(_keyIdentifier, {
      'public': publicKeyPem,
      'private': privateKeyPem,
    });
  }

  AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> _decodeKeyPair(Map<String, String> pemStrings) {
    final publicKey = _decodePublicKeyFromPem(pemStrings['public']!);
    final privateKey = _decodePrivateKeyFromPem(pemStrings['private']!);
    return AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>(publicKey, privateKey);
  }

  String _encodePublicKeyToPem(RSAPublicKey key) {
    var algorithmSeq = ASN1Sequence();
    var algorithmAsn1Obj = ASN1Object.fromBytes(
        Uint8List.fromList([0x6, 0x9, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01]));
    var paramsAsn1Obj = ASN1Object.fromBytes(Uint8List.fromList([0x5, 0x00]));
    algorithmSeq.add(algorithmAsn1Obj);
    algorithmSeq.add(paramsAsn1Obj);

    var publicKeySeq = ASN1Sequence();
    publicKeySeq.add(ASN1Integer(key.modulus!));
    publicKeySeq.add(ASN1Integer(key.exponent!));
    var publicKeySeqBitString = ASN1BitString(Uint8List.fromList(publicKeySeq.encodedBytes));

    var topLevelSeq = ASN1Sequence();
    topLevelSeq.add(algorithmSeq);
    topLevelSeq.add(publicKeySeqBitString);

    final pemString = base64.encode(topLevelSeq.encodedBytes);
    final formatted = _chunkString(pemString, 64).join('\n');

    return "-----BEGIN PUBLIC KEY-----\n$formatted\n-----END PUBLIC KEY-----";
  }

  String _encodePrivateKeyToPem(RSAPrivateKey privateKey) {
    var version = ASN1Integer(BigInt.from(0));
    var algorithmSeq = ASN1Sequence();
    var algorithmAsn1Obj = ASN1Object.fromBytes(
        Uint8List.fromList([0x6, 0x9, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01]));
    var paramsAsn1Obj = ASN1Object.fromBytes(Uint8List.fromList([0x5, 0x00]));
    algorithmSeq.add(algorithmAsn1Obj);
    algorithmSeq.add(paramsAsn1Obj);

    var privateKeySeq = ASN1Sequence();
    privateKeySeq.add(ASN1Integer(BigInt.from(0)));
    privateKeySeq.add(ASN1Integer(privateKey.n!));
    privateKeySeq.add(ASN1Integer(privateKey.publicExponent ?? BigInt.parse('65537')));
    privateKeySeq.add(ASN1Integer(privateKey.privateExponent!));
    privateKeySeq.add(ASN1Integer(privateKey.p!));
    privateKeySeq.add(ASN1Integer(privateKey.q!));
    privateKeySeq.add(ASN1Integer(privateKey.privateExponent! % (privateKey.p! - BigInt.one)));
    privateKeySeq.add(ASN1Integer(privateKey.privateExponent! % (privateKey.q! - BigInt.one)));
    privateKeySeq.add(ASN1Integer(privateKey.q!.modInverse(privateKey.p!)));
    
    var pkOctetString = ASN1OctetString(Uint8List.fromList(privateKeySeq.encodedBytes));
    var topLevelSeq = ASN1Sequence();
    topLevelSeq.add(version);
    topLevelSeq.add(algorithmSeq);
    topLevelSeq.add(pkOctetString);

    final pemString = base64.encode(topLevelSeq.encodedBytes);
    final formatted = _chunkString(pemString, 64).join('\n');

    return "-----BEGIN PRIVATE KEY-----\n$formatted\n-----END PRIVATE KEY-----";
  }

  RSAPublicKey _decodePublicKeyFromPem(String pem) {
    final bytes = _decodePem(pem);
    var asn1Parser = ASN1Parser(Uint8List.fromList(bytes));
    var topLevelSeq = asn1Parser.nextObject() as ASN1Sequence;
    var publicKeyBitString = topLevelSeq.elements![1] as ASN1BitString;
    var publicKeyAsn = ASN1Parser(publicKeyBitString.contentBytes());
    var publicKeySeq = publicKeyAsn.nextObject() as ASN1Sequence;
    var modulus = publicKeySeq.elements![0] as ASN1Integer;
    var exponent = publicKeySeq.elements![1] as ASN1Integer;
    return RSAPublicKey(modulus.valueAsBigInteger, exponent.valueAsBigInteger);
  }

  RSAPrivateKey _decodePrivateKeyFromPem(String pem) {
    final bytes = _decodePem(pem);
    var asn1Parser = ASN1Parser(Uint8List.fromList(bytes));
    var topLevelSeq = asn1Parser.nextObject() as ASN1Sequence;

    if (topLevelSeq.elements!.length == 3 && topLevelSeq.elements![2] is ASN1OctetString) {
      var privateKeyOctet = topLevelSeq.elements![2] as ASN1OctetString;
      var pkAsn = ASN1Parser(privateKeyOctet.contentBytes());
      var pkSeq = pkAsn.nextObject() as ASN1Sequence;
      var modulus = pkSeq.elements![1] as ASN1Integer;
      var privateExponent = pkSeq.elements![3] as ASN1Integer;
      var p = pkSeq.elements![4] as ASN1Integer;
      var q = pkSeq.elements![5] as ASN1Integer;
      return RSAPrivateKey(
        modulus.valueAsBigInteger,
        privateExponent.valueAsBigInteger,
        p.valueAsBigInteger,
        q.valueAsBigInteger,
      );
    } else {
      var modulus = topLevelSeq.elements![1] as ASN1Integer;
      var privateExponent = topLevelSeq.elements![3] as ASN1Integer;
      var p = topLevelSeq.elements![4] as ASN1Integer;
      var q = topLevelSeq.elements![5] as ASN1Integer;
      return RSAPrivateKey(
        modulus.valueAsBigInteger,
        privateExponent.valueAsBigInteger,
        p.valueAsBigInteger,
        q.valueAsBigInteger,
      );
    }
  }

  List<int> _decodePem(String pem) {
    var startsWith = [
      "-----BEGIN PUBLIC KEY-----",
      "-----BEGIN PRIVATE KEY-----",
      "-----BEGIN RSA PRIVATE KEY-----",
    ];
    var endsWith = [
      "-----END PUBLIC KEY-----",
      "-----END PRIVATE KEY-----",
      "-----END RSA PRIVATE KEY-----",
    ];
    for (var s in startsWith) {
      if (pem.startsWith(s)) {
        pem = pem.substring(s.length);
      }
    }
    for (var s in endsWith) {
      if (pem.endsWith(s)) {
        pem = pem.substring(0, pem.length - s.length);
      }
    }
    pem = pem.replaceAll('\n', '').replaceAll('\r', '');
    return base64.decode(pem);
  }

  List<String> _chunkString(String str, int chunkSize) {
    List<String> chunks = [];
    for (var i = 0; i < str.length; i += chunkSize) {
      chunks.add(str.substring(i, i + chunkSize > str.length ? str.length : i + chunkSize));
    }
    return chunks;
  }
}

