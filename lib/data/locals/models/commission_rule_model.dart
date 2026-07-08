import 'package:hive/hive.dart';

part 'commission_rule_model.g.dart';

@HiveType(typeId: 4) // make sure it's unique
class CommissionRuleModel {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String? companyId;

  @HiveField(2)
  final String? zoneId;

  @HiveField(3)
  final String? cityId;

  @HiveField(4)
  final double commissionRate;

  @HiveField(5)
  final String? description;

  @HiveField(6)
  final DateTime? createdAt;

  @HiveField(7)
  final DateTime? updatedAt;

  CommissionRuleModel({
    required this.id,
    this.companyId,
    this.zoneId,
    this.cityId,
    required this.commissionRate,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  factory CommissionRuleModel.fromJson(Map<String, dynamic> json) {
    return CommissionRuleModel(
      id: json['id'],
      companyId: json['company_id'],
      zoneId: json['zone_id'],
      cityId: json['city_id'],
      commissionRate:
          double.tryParse(json['commission_rate']?.toString() ?? '0') ?? 0.0,
      description: json['description'],
      createdAt: DateTime.tryParse(json['created_at'] ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'company_id': companyId,
        'zone_id': zoneId,
        'city_id': cityId,
        'commission_rate': commissionRate,
        'description': description,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };
}
