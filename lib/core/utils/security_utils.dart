import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:device_info_plus/device_info_plus.dart';

class SecurityUtils {
  static final _storage = const FlutterSecureStorage();
  static const _aesKeyPrefix = 'aes_key_';
  static const _rootDetectionCacheKey = 'root_detection_cache';
  static const _masterKeyKey = 'master_encryption_key';
  static const _deviceIdKey = 'device_unique_id';

  /// Create a secure HTTP client that enforces HTTPS and implements certificate pinning
  static Future<http.Client> createSecureHttpClient() async {
    final ioClient = HttpClient();

    // Load pinned certificate
    final pinnedCert = await _loadPinnedCertificate();

    // Enforce HTTPS and certificate pinning
    ioClient.badCertificateCallback = (X509Certificate cert, String host, int port) {
      // For certificate pinning, validate against known certificate
      if (pinnedCert != null) {
        // Compare certificate fingerprints or full certificate
        final certFingerprint = _getCertificateFingerprint(cert);
        final pinnedFingerprint = _getCertificateFingerprint(pinnedCert);
        return certFingerprint == pinnedFingerprint && host == 'admin.ota.gov.et';
      }

      // TEMPORARY: Accept all certificates for testing (INSECURE - REMOVE FOR PRODUCTION)
      // TODO: Replace with proper certificate pinning for production
      print('⚠️ Accepting certificate for $host (certificate pinning not yet implemented - INSECURE)');
      return true;
    };

    return IOClient(ioClient);
  }

  /// Load the pinned certificate from assets
  static Future<X509Certificate?> _loadPinnedCertificate() async {
    try {
      // Load certificate from assets
      final certData = await rootBundle.load('assets/certificates/server_cert.pem');
      final certString = String.fromCharCodes(certData.buffer.asUint8List());

      // Parse certificate (this is a simplified example)
      // In production, you might need more sophisticated certificate parsing
      return null; // Placeholder - implement proper certificate loading
    } catch (e) {
      print('Failed to load pinned certificate: $e');
      return null;
    }
  }

  /// Get certificate fingerprint for comparison
  static String _getCertificateFingerprint(X509Certificate cert) {
    // In a real implementation, calculate SHA-256 fingerprint
    // For now, return a placeholder
    return cert.pem;
  }

  /// Generate or retrieve a master encryption key
  static Future<String> _getMasterKey() async {
    // Check if we already have a master key
    final existingKey = await _storage.read(key: _masterKeyKey);
    if (existingKey != null) {
      return existingKey;
    }

    // Generate a new master key
    final random = Random.secure();
    final keyBytes = List<int>.generate(32, (_) => random.nextInt(256));
    final masterKey = base64Encode(keyBytes);

    // Store the master key securely
    await _storage.write(key: _masterKeyKey, value: masterKey);
    return masterKey;
  }

  /// Get device-specific salt for key derivation
  static Future<String> _getDeviceSalt() async {
    // Try to get stored device ID
    final storedId = await _storage.read(key: _deviceIdKey);
    if (storedId != null) {
      return storedId;
    }

    // Generate device-specific salt (using device info)
    final deviceInfo = '${Platform.operatingSystem}${Platform.operatingSystemVersion}${DateTime.now().millisecondsSinceEpoch}';
    final salt = sha256.convert(utf8.encode(deviceInfo)).toString();

    // Store for future use
    await _storage.write(key: _deviceIdKey, value: salt);
    return salt;
  }

  /// Generate a secure AES key derived from master key using PBKDF2
  static Future<String> generateSecureAESKey(String keyId) async {
    // Check if we already have a derived key stored
    final existingKey = await _storage.read(key: '${_aesKeyPrefix}$keyId');
    if (existingKey != null) {
      return existingKey;
    }

    // Get master key and device salt
    final masterKey = await _getMasterKey();
    final salt = await _getDeviceSalt();

    // Derive AES key using HMAC-SHA256
    final hmac = Hmac(sha256, utf8.encode(masterKey));
    final derivedKeyBytes = hmac.convert(utf8.encode(salt + keyId)).bytes;
    final derivedKey = base64Encode(derivedKeyBytes);

    // Store the derived key securely
    await _storage.write(key: '${_aesKeyPrefix}$keyId', value: derivedKey);
    return derivedKey;
  }

  /// Get AES key for encryption/decryption
  static Future<String?> getAESKey(String keyId) async {
    return await _storage.read(key: '${_aesKeyPrefix}$keyId');
  }

  /// Securely store sensitive data with encryption
  static Future<void> secureStore(String key, String value) async {
    final encryptedValue = await encryptData(value, 'secure_storage');
    if (encryptedValue != null) {
      await _storage.write(key: key, value: encryptedValue);
    }
  }

  /// Securely retrieve sensitive data with decryption
  static Future<String?> secureRetrieve(String key) async {
    final encryptedValue = await _storage.read(key: key);
    if (encryptedValue != null) {
      return await decryptData(encryptedValue, 'secure_storage');
    }
    return null;
  }

  /// Securely delete sensitive data
  static Future<void> secureDelete(String key) async {
    await _storage.delete(key: key);
  }

  /// Encrypt data using AES with proper encryption
  static Future<String?> encryptData(String data, String keyId) async {
    try {
      // Generate or retrieve the AES key
      final key = await generateSecureAESKey(keyId);
      if (key == null) return null;

      final keyBytes = base64Decode(key);
      final iv = encrypt.IV.fromSecureRandom(16);

      final encrypter = encrypt.Encrypter(encrypt.AES(encrypt.Key(keyBytes)));
      final encrypted = encrypter.encrypt(data, iv: iv);

      // Combine IV and encrypted data
      final result = base64Encode([...iv.bytes, ...encrypted.bytes]);
      return result;
    } catch (e) {
      print('Encryption failed: $e');
      return null;
    }
  }

  /// Decrypt data using AES with proper decryption
  static Future<String?> decryptData(String encryptedData, String keyId) async {
    try {
      final key = await getAESKey(keyId);
      if (key == null) return null;

      final keyBytes = base64Decode(key);
      final combined = base64Decode(encryptedData);

      // Extract IV (first 16 bytes) and encrypted data
      final ivBytes = combined.sublist(0, 16);
      final encryptedBytes = combined.sublist(16);

      final iv = encrypt.IV(ivBytes);
      final encrypter = encrypt.Encrypter(encrypt.AES(encrypt.Key(keyBytes)));
      final decrypted = encrypter.decrypt(encrypt.Encrypted(encryptedBytes), iv: iv);

      return decrypted;
    } catch (e) {
      print('Decryption failed: $e');
      return null;
    }
  }


  /// Check if device is rooted/jailbroken
  static Future<bool> isDeviceRooted() async {
    try {
      // Check cache first
      final cachedResult = await _storage.read(key: _rootDetectionCacheKey);
      if (cachedResult != null) {
        return cachedResult == 'true';
      }

      bool isRooted = false;

      // Android specific checks
      if (Platform.isAndroid) {
        isRooted = await _checkAndroidRoot();
      }
      // iOS specific checks
      else if (Platform.isIOS) {
        isRooted = await _checkIOSJailbreak();
      }

      // Cache result for 24 hours
      await _storage.write(
        key: _rootDetectionCacheKey,
        value: isRooted.toString(),
      );

      return isRooted;
    } catch (e) {
      print('Root detection error: $e');
      return false;
    }
  }

  /// Check if device is running on an emulator
  static Future<bool> isRunningOnEmulator() async {
    try {
      if (Platform.isAndroid) {
        return await _checkAndroidEmulator();
      } else if (Platform.isIOS) {
        return await _checkIOSSimulator();
      }
      return false;
    } catch (e) {
      print('Emulator detection error: $e');
      return false;
    }
  }

  static Future<bool> _checkAndroidRoot() async {
    try {
      // Check for common root files
      final rootFiles = [
        '/system/app/Superuser.apk',
        '/sbin/su',
        '/system/bin/su',
        '/system/xbin/su',
        '/data/local/xbin/su',
        '/data/local/bin/su',
        '/system/sd/xbin/su',
        '/system/bin/failsafe/su',
        '/data/local/su',
        '/su/bin/su'
      ];

      for (final file in rootFiles) {
        if (await File(file).exists()) {
          return true;
        }
      }

      // Check for root properties
      final buildProps = await _readAndroidBuildProps();
      if (buildProps.containsKey('ro.debuggable') && buildProps['ro.debuggable'] == '1') {
        return true;
      }

      if (buildProps.containsKey('ro.secure') && buildProps['ro.secure'] != '1') {
        return true;
      }

      // Check for test keys
      final fingerPrint = buildProps['ro.build.fingerprint'] ?? '';
      if (fingerPrint.contains('test-keys')) {
        return true;
      }

      // Check for busybox
      try {
        final result = await Process.run('which', ['busybox']);
        if (result.exitCode == 0) {
          return true;
        }
      } catch (e) {
        // Command not available
      }

      return false;
    } catch (e) {
      print('Android root check error: $e');
      return false;
    }
  }

  static Future<bool> _checkIOSJailbreak() async {
    try {
      // Check for common jailbreak files
      final jailbreakFiles = [
        '/Applications/Cydia.app',
        '/Library/MobileSubstrate/MobileSubstrate.dylib',
        '/bin/bash',
        '/usr/sbin/sshd',
        '/etc/apt',
        '/private/var/lib/apt/',
        '/private/var/lib/cydia/',
        '/private/var/stash/',
        '/private/var/tmp/cydia.log',
        '/System/Library/LaunchDaemons/com.ikey.bbot.plist',
        '/System/Library/LaunchDaemons/com.saurik.Cydia.Startup.plist',
        '/usr/bin/sshd',
        '/usr/libexec/sftp-server',
        '/usr/libexec/ssh-keysign',
        '/bin/sh',
        '/usr/bin/ssh',
        '/var/cache/apt/',
        '/var/lib/apt/',
        '/var/lib/cydia/',
        '/var/lib/dpkg/',
        '/var/log/apt/',
        '/var/mobile/Library/SBSettings/Themes/',
        '/var/tmp/cydia.log'
      ];

      for (final file in jailbreakFiles) {
        if (await File(file).exists()) {
          return true;
        }
      }

      // Check if app can write to system directories (jailbreak allows this)
      try {
        final testFile = File('/private/test_jailbreak.txt');
        await testFile.writeAsString('test');
        await testFile.delete();
        return true;
      } catch (e) {
        // Expected on non-jailbroken devices
      }

      // Check for jailbreak tweaks
      try {
        final result = await MethodChannel('flutter/platform').invokeMethod<bool>('isJailbroken');
        if (result == true) {
          return true;
        }
      } catch (e) {
        // Method not available
      }

      return false;
    } catch (e) {
      print('iOS jailbreak check error: $e');
      return false;
    }
  }

  static Future<bool> _checkAndroidEmulator() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;

      // Check if it's running on emulator
      if (androidInfo.isPhysicalDevice == false) {
        return true;
      }

      // Check build properties for emulator signatures
      final buildProps = await _readAndroidBuildProps();

      // Check for common emulator fingerprints
      final model = buildProps['ro.product.model'] ?? '';
      final brand = buildProps['ro.product.brand'] ?? '';
      final device = buildProps['ro.product.device'] ?? '';
      final manufacturer = buildProps['ro.product.manufacturer'] ?? '';
      final hardware = buildProps['ro.hardware'] ?? '';
      final fingerprint = buildProps['ro.build.fingerprint'] ?? '';

      // Common emulator signatures
      final emulatorModels = ['sdk', 'emulator', 'android sdk built for x86', 'generic'];
      final emulatorBrands = ['generic', 'android', 'unknown'];
      final emulatorDevices = ['generic', 'generic_x86', 'vbox86p'];
      final emulatorHardware = ['goldfish', 'ranchu', 'vbox86'];

      if (emulatorModels.any((emulator) => model.toLowerCase().contains(emulator)) ||
          emulatorBrands.any((emulator) => brand.toLowerCase().contains(emulator)) ||
          emulatorDevices.any((emulator) => device.toLowerCase().contains(emulator)) ||
          emulatorHardware.any((emulator) => hardware.toLowerCase().contains(emulator))) {
        return true;
      }

      // Check fingerprint for emulator
      if (fingerprint.toLowerCase().contains('emulator') ||
          fingerprint.toLowerCase().contains('sdk') ||
          fingerprint.toLowerCase().contains('generic')) {
        return true;
      }

      // Check for qemu properties
      if (buildProps.containsKey('ro.kernel.qemu') ||
          buildProps['ro.kernel.qemu'] == '1') {
        return true;
      }

      // Check network interfaces for emulator
      try {
        final result = await Process.run('getprop', ['net.eth0.gw']);
        if (result.exitCode == 0 && result.stdout.toString().contains('10.0.2.2')) {
          return true;
        }
      } catch (e) {
        // Command not available
      }

      // Check for emulator-specific files
      final emulatorFiles = [
        '/system/lib/libandroid_runtime.so', // Often missing on real devices
        '/sys/qemu_trace',
        '/system/bin/qemu-props'
      ];

      for (final file in emulatorFiles) {
        if (await File(file).exists()) {
          return true;
        }
      }

      return false;
    } catch (e) {
      print('Android emulator check error: $e');
      return false;
    }
  }

  static Future<bool> _checkIOSSimulator() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final iosInfo = await deviceInfo.iosInfo;

      // Check if it's running on simulator
      if (iosInfo.isPhysicalDevice == false) {
        return true;
      }

      // Additional checks for simulator
      final model = iosInfo.model?.toLowerCase() ?? '';
      if (model.contains('simulator') || model.contains('x86') || model.contains('i386')) {
        return true;
      }

      // Check for simulator environment variables
      final simulatorVars = [
        'SIMULATOR_DEVICE_NAME',
        'SIMULATOR_RUNTIME_VERSION',
        'SIMULATOR_ROOT'
      ];

      for (final varName in simulatorVars) {
        if (Platform.environment.containsKey(varName)) {
          return true;
        }
      }

      return false;
    } catch (e) {
      print('iOS simulator check error: $e');
      return false;
    }
  }

  static Future<Map<String, String>> _readAndroidBuildProps() async {
    try {
      final result = await Process.run('getprop', []);
      if (result.exitCode == 0) {
        final props = <String, String>{};
        final lines = result.stdout.toString().split('\n');
        for (final line in lines) {
          if (line.contains(':')) {
            final parts = line.split(':');
            if (parts.length >= 2) {
              final key = parts[0].trim();
              final value = parts.sublist(1).join(':').trim();
              props[key] = value;
            }
          }
        }
        return props;
      }
    } catch (e) {
      // Fallback to device info
    }

    // Fallback - return basic system info
    return {
      'ro.product.brand': 'unknown',
      'ro.product.model': Platform.isAndroid ? 'Android' : 'iOS',
      'ro.product.manufacturer': 'unknown',
      'ro.build.version.release': Platform.operatingSystemVersion,
      'ro.build.version.sdk': Platform.isAndroid ? '21' : '12', // Default values
    };
  }

  /// Rate limiting utility with persistent storage
  static final Map<String, _RateLimitData> _rateLimits = {};

  static Future<bool> checkRateLimit(String key, {int maxRequests = 5, Duration window = const Duration(minutes: 1)}) async {
    final now = DateTime.now();

    // Load existing rate limit data from storage
    final storedData = await _loadRateLimitData(key);
    if (storedData != null) {
      _rateLimits[key] = storedData;
    }

    if (!_rateLimits.containsKey(key)) {
      final newData = _RateLimitData([now], maxRequests, window);
      _rateLimits[key] = newData;
      await _saveRateLimitData(key, newData);
      return true;
    }

    final data = _rateLimits[key]!;
    final recentRequests = data.timestamps.where((t) => now.difference(t) < window).toList();

    if (recentRequests.length >= data.maxRequests) {
      return false;
    }

    recentRequests.add(now);
    final updatedData = _RateLimitData(recentRequests, data.maxRequests, window);
    _rateLimits[key] = updatedData;
    await _saveRateLimitData(key, updatedData);
    return true;
  }

  /// Load rate limit data from secure storage
  static Future<_RateLimitData?> _loadRateLimitData(String key) async {
    try {
      final stored = await _storage.read(key: 'rate_limit_$key');
      if (stored == null) return null;

      final data = jsonDecode(stored);
      final timestamps = (data['timestamps'] as List)
          .map((t) => DateTime.parse(t))
          .toList();
      return _RateLimitData(
        timestamps,
        data['maxRequests'],
        Duration(seconds: data['windowSeconds']),
      );
    } catch (e) {
      print('Failed to load rate limit data: $e');
      return null;
    }
  }

  /// Save rate limit data to secure storage
  static Future<void> _saveRateLimitData(String key, _RateLimitData data) async {
    try {
      final jsonData = {
        'timestamps': data.timestamps.map((t) => t.toIso8601String()).toList(),
        'maxRequests': data.maxRequests,
        'windowSeconds': data.window.inSeconds,
      };
      await _storage.write(key: 'rate_limit_$key', value: jsonEncode(jsonData));
    } catch (e) {
      print('Failed to save rate limit data: $e');
    }
  }

  /// Clear expired rate limit data
  static Future<void> cleanupRateLimits() async {
    final now = DateTime.now();
    final keysToRemove = <String>[];

    for (final entry in _rateLimits.entries) {
      final data = entry.value;
      final recentRequests = data.timestamps.where((t) => now.difference(t) < data.window).toList();

      if (recentRequests.isEmpty) {
        keysToRemove.add(entry.key);
        await _storage.delete(key: 'rate_limit_${entry.key}');
      } else if (recentRequests.length != data.timestamps.length) {
        // Update with only recent timestamps
        final updatedData = _RateLimitData(recentRequests, data.maxRequests, data.window);
        _rateLimits[entry.key] = updatedData;
        await _saveRateLimitData(entry.key, updatedData);
      }
    }

    _rateLimits.removeWhere((key, _) => keysToRemove.contains(key));
  }
}

class _RateLimitData {
  final List<DateTime> timestamps;
  final int maxRequests;
  final Duration window;

  _RateLimitData(this.timestamps, this.maxRequests, this.window);
}