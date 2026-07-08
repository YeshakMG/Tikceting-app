import 'package:hive/hive.dart';
import 'package:oro_ticket_app/core/utils/security_utils.dart';

class TokenStorageService {
  static const _encryptedBoxName = 'encryptedTokenData';
  static const _encryptionKeyId = 'auth_token';

  static Future<Box<String>> get _encryptedBox async {
    return await Hive.openBox<String>(_encryptedBoxName);
  }

  static Future<void> saveToken(String token) async {
    final encryptedBox = await _encryptedBox;
    final encryptedToken = await SecurityUtils.encryptData(token, _encryptionKeyId);
    if (encryptedToken != null) {
      await encryptedBox.put('authToken', encryptedToken);
      print('✅ Token encrypted and stored successfully');
    } else {
      throw Exception('Failed to encrypt token');
    }
  }

  static Future<String?> getToken() async {
    final encryptedBox = await _encryptedBox;
    final encryptedToken = encryptedBox.get('authToken');
    if (encryptedToken != null) {
      return await SecurityUtils.decryptData(encryptedToken, _encryptionKeyId);
    }
    return null;
  }

  static Future<void> clearToken() async {
    final encryptedBox = await _encryptedBox;
    await encryptedBox.clear();
  }
}