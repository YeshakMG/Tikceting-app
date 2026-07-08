import 'package:hive/hive.dart';
import 'package:oro_ticket_app/data/locals/models/vehicle_route.dart';

part 'vehicle_model.g.dart';

@HiveType(typeId: 0)
class VehicleModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String plateNumber;

  @HiveField(2)
  final String plateRegion;

  @HiveField(3)
  final String fleetType;

  @HiveField(4)
  final String vehicleLevel;

  @HiveField(5)
  final String associationName;

  @HiveField(6)
  final int seatCapacity;

  @HiveField(7)
  final String status;

  @HiveField(8)
  final String? assignedTerminalId;

  @HiveField(9)
  final String? createdBy;

  @HiveField(10)
  final String? updatedBy;

  @HiveField(11)
  final String? createdAt;

  @HiveField(12)
  final String? updatedAt;

  @HiveField(13)
  final List<String>? arrivalTerminals;

  @HiveField(14)
  final List<String>? tariffs;

  // New fields for pricing
  @HiveField(15)
  final String? vehicleLevelId;

  @HiveField(16)
  final String? fleetTypeId;

  @HiveField(17)
  final VehicleRoute? currentRoute; // The assigned route

  VehicleModel({
    required this.id,
    required this.plateNumber,
    required this.plateRegion,
    required this.fleetType,
    required this.vehicleLevel,
    required this.associationName,
    required this.seatCapacity,
    required this.status,
    this.assignedTerminalId,
    required this.arrivalTerminals,
    required this.tariffs,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
    this.vehicleLevelId,
    this.fleetTypeId,
    this.currentRoute,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    // Parse the current route if vehicle has destinations
    VehicleRoute? route;
    try {
      final vtd = json['vehicleTerminalDestinations'];
      if (vtd is List && vtd.isNotEmpty) {
        final firstDestination = vtd.first;
        if (firstDestination is Map<String, dynamic>) {
          route = VehicleRoute.fromJson(firstDestination);
        } else {
          // destination may be a simple id (string/int) — create a minimal route
          final destId = firstDestination?.toString() ?? '';
          route = VehicleRoute(
            id: destId,
            vehicleId: json['id']?.toString() ?? '',
            terminalDestinationId: destId,
            assignedAt: null,
            unassignedAt: null,
            isOnTemporary: false,
            terminalDestination: null,
          );
        }
      }
    } catch (e) {
      // If parsing fails, skip route but don't crash restore
      print('⚠️ Vehicle route parse failed: $e');
      route = null;
    }

    // Safe parsers for commonly inconsistent backend types
    int parseSeat(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      final s = value.toString();
      return int.tryParse(s) ?? 0;
    }

    List<String> parseStringList(dynamic v) {
      if (v == null) return [];
      if (v is List) return v.map((e) => e?.toString() ?? '').toList();
      return [v.toString()];
    }

    return VehicleModel(
      id: json['id']?.toString() ?? '',
      plateNumber: json['plate_number']?.toString() ?? '',
      plateRegion: json['plate_region']?.toString() ?? '',
      fleetType: json['fleetType'] is Map
          ? (json['fleetType']['name']?.toString() ?? '')
          : (json['fleetType']?.toString() ?? ''),
      vehicleLevel: json['vehicleLevel'] is Map
          ? (json['vehicleLevel']['name']?.toString() ?? '')
          : (json['vehicleLevel']?.toString() ?? ''),
      associationName: json['association'] is Map
          ? (json['association']['name']?.toString() ?? '')
          : (json['association']?.toString() ?? ''),
      seatCapacity: parseSeat(json['seat_capacity']),
      status: json['status']?.toString() ?? 'active',
      assignedTerminalId: json['assigned_terminal_id']?.toString(),
      createdBy: json['created_by']?.toString(),
      updatedBy: json['updated_by']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      arrivalTerminals: parseStringList(json['arrival_terminals']),
      tariffs: parseStringList(json['tariffs']),
      vehicleLevelId: json['vehicle_level_id']?.toString() ??
          (json['vehicleLevel'] is Map ? json['vehicleLevel']['id']?.toString() : null),
      fleetTypeId: json['fleet_type_id']?.toString() ??
          (json['fleetType'] is Map ? json['fleetType']['id']?.toString() : null),
      currentRoute: route,
    );
  }

    Map<String, dynamic> toJson() => {
          'id': id,
          'plate_number': plateNumber,
          'plate_region': plateRegion,
          'fleetType': fleetType,
          'vehicleLevel': vehicleLevel,
          'association': associationName,
          'seat_capacity': seatCapacity,
          'status': status,
          'assigned_terminal_id': assignedTerminalId,
          'created_by': createdBy,
          'updated_by': updatedBy,
          'created_at': createdAt,
          'updated_at': updatedAt,
          'arrival_terminals': arrivalTerminals ?? [],
          'tariffs': tariffs ?? [],
          'vehicle_level_id': vehicleLevelId,
          'fleet_type_id': fleetTypeId,
          // Include current route for restore completeness
          'vehicleTerminalDestinations': currentRoute != null ? [currentRoute!.toJson()] : [],
    };
}