import 'package:hive/hive.dart';

part 'user_model.g.dart'; // This will be generated

@HiveType(typeId: 7) // Assign a unique typeId
class UserModel {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String email;
  @HiveField(2)
  final String fullName;
  @HiveField(3)
  final String roleId;
  @HiveField(4)
  final String? companyName;
  @HiveField(5)
  final String? logoUrl;
  @HiveField(6)
  final String companyId;
  @HiveField(7)
  final String? companyPhoneNo;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.roleId,
    required this.companyId,
    this.companyName,
    this.logoUrl,
    this.companyPhoneNo,
  });

  factory UserModel.fromLoginJson(Map<String, dynamic> json) {
    // Try nested parsing
    final companyUser = json['company_user'];
    final user = companyUser != null ? companyUser['user'] : json;
    final company = companyUser != null ? companyUser['company'] : null;

    return UserModel(
      id: user?['id'] ?? '',
      email: user?['email'] ?? '',
      fullName: user?['full_name'] ?? '',
      roleId: user?['role_id'] ?? '',
      companyId: companyUser?['company_id'] ?? '',
      companyName:
          company?['name'] ?? json['company_name'] ?? 'Unknown Company',
      logoUrl: company?['logo_url'],
      companyPhoneNo: company?['phone'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'full_name': fullName,
        'role_id': roleId,
        'company_id': companyId,
        'name': companyName,
        'logo_url': logoUrl,
        'phone_no': companyPhoneNo,
      };
}
