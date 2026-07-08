import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:oro_ticket_app/core/utils/security_utils.dart';
import 'package:oro_ticket_app/data/locals/models/user_model.dart';

class UserStorageService {
  static const _encryptedBoxName = 'encryptedUserData';
  static const _legacyBoxName = 'userData';
  static const _encryptionKeyId = 'user_data';

  static Future<Box<String>> get _encryptedBox async {
    return await Hive.openBox<String>(_encryptedBoxName);
  }

  static Future<Box<UserModel>> get _legacyBox async {
    return await Hive.openBox<UserModel>(_legacyBoxName);
  }

  static Future<void> saveUser(UserModel user) async {
    final encryptedBox = await _encryptedBox;
    final userJson = jsonEncode(user.toJson());
    final encryptedData = await SecurityUtils.encryptData(userJson, _encryptionKeyId);
    if (encryptedData != null) {
      await encryptedBox.put('currentUser', encryptedData);
      print('✅ User data encrypted and stored successfully');
    } else {
      throw Exception('Failed to encrypt user data');
    }
  }

  static Future<UserModel?> getUser() async {
    // First try to get from encrypted box
    final encryptedBox = await _encryptedBox;
    final encryptedData = encryptedBox.get('currentUser');
    if (encryptedData != null) {
      final decryptedJson = await SecurityUtils.decryptData(encryptedData, _encryptionKeyId);
      if (decryptedJson != null) {
        final userMap = jsonDecode(decryptedJson) as Map<String, dynamic>;
        return UserModel(
          id: userMap['id'] ?? '',
          email: userMap['email'] ?? '',
          fullName: userMap['full_name'] ?? '',
          roleId: userMap['role_id'] ?? '',
          companyId: userMap['company_id'] ?? '',
          companyName: userMap['name'],
          logoUrl: userMap['logo_url'],
          companyPhoneNo: userMap['phone_no'],
        );
      }
    }

    // Fall back to legacy unencrypted box and migrate
    try {
      final legacyBox = await _legacyBox;
      final legacyUser = legacyBox.get('currentUser');
      if (legacyUser != null) {
        print('🔄 Migrating legacy user data to encrypted storage...');
        await saveUser(legacyUser);
        await legacyBox.clear(); // Clear legacy data after migration
        print('✅ Legacy user data migrated successfully');
        return legacyUser;
      }
    } catch (e) {
      print('⚠️ Failed to access legacy user data: $e');
    }

    return null;
  }

  static Future<void> clearUser() async {
    final encryptedBox = await _encryptedBox;
    await encryptedBox.clear();

    // Also clear legacy box if it exists
    try {
      final legacyBox = await _legacyBox;
      await legacyBox.clear();
    } catch (e) {
      // Ignore errors for legacy box
    }
  }
}