import 'package:hive/hive.dart';

part 'tariff_model.g.dart';

@HiveType(typeId: 8)
class TariffModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String? terminalDestinationId;

  @HiveField(2)
  final String? fleetTypeId;

  @HiveField(3)
  final String vehicleLevelId;

  @HiveField(4)
  final String roadType;

  @HiveField(5)
  final double pricePerKm;

  @HiveField(6)
  final String? vehicleLevelName;

  @HiveField(7)
  final DateTime? createdAt;

  @HiveField(8)
  final DateTime? updatedAt;

  @HiveField(9)
  final DateTime? deletedAt;

  TariffModel({
    required this.id,
    this.terminalDestinationId,
    this.fleetTypeId,
    required this.vehicleLevelId,
    required this.roadType,
    required this.pricePerKm,
    this.vehicleLevelName,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  // In TariffModel, update fromJson:
  factory TariffModel.fromJson(Map<String, dynamic> json) {
    // Parse price_per_km with fallback to tariff field
    double parsedPrice = 0.0;

    // First try price_per_km
    if (json['price_per_km'] != null) {
      final priceStr = json['price_per_km'].toString();
      parsedPrice = double.tryParse(priceStr) ?? 0.0;
      print('✅ Found price_per_km: $parsedPrice for tariff ${json['id']}');
    }
    // Fallback to legacy tariff field
    else if (json['tariff'] != null) {
      final tariffStr = json['tariff'].toString();
      parsedPrice = double.tryParse(tariffStr) ?? 0.0;
      print(
          '⚠️ Using legacy tariff field: $parsedPrice for tariff ${json['id']}');
    } else {
      print('❌ No price found for tariff ${json['id']}');
    }

    return TariffModel(
      id: json['id'],
      terminalDestinationId: json['terminal_destination_id'],
      fleetTypeId: json['fleet_type_id'],
      vehicleLevelId: json['vehicle_level_id'],
      roadType: json['road_type'] ?? 'asphalt',
      pricePerKm: parsedPrice,
      vehicleLevelName: json['vehicleLevel']?['name'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'terminal_destination_id': terminalDestinationId,
        'fleet_type_id': fleetTypeId,
        'vehicle_level_id': vehicleLevelId,
        'road_type': roadType,
        'price_per_km': pricePerKm.toStringAsFixed(2),
        'vehicleLevel': vehicleLevelName != null
            ? {
                'name': vehicleLevelName,
              }
            : null,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
        'deleted_at': deletedAt?.toIso8601String(),
      };

  @override
  String toString() {
    return 'TariffModel(id: $id, roadType: $roadType, pricePerKm: $pricePerKm, vehicleLevelId: $vehicleLevelId, terminalDestinationId: $terminalDestinationId)';
  }

  bool isValid() {
    return pricePerKm > 0.0 && vehicleLevelId.isNotEmpty && roadType.isNotEmpty;
  }

  TariffModel copyWith({
    String? id,
    String? terminalDestinationId,
    String? fleetTypeId,
    String? vehicleLevelId,
    String? roadType,
    double? pricePerKm,
    String? vehicleLevelName,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return TariffModel(
      id: id ?? this.id,
      terminalDestinationId:
          terminalDestinationId ?? this.terminalDestinationId,
      fleetTypeId: fleetTypeId ?? this.fleetTypeId,
      vehicleLevelId: vehicleLevelId ?? this.vehicleLevelId,
      roadType: roadType ?? this.roadType,
      pricePerKm: pricePerKm ?? this.pricePerKm,
      vehicleLevelName: vehicleLevelName ?? this.vehicleLevelName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
