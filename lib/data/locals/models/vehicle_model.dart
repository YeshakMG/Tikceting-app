import 'dart:convert';

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
    dynamic pick(Map<String, dynamic> source, List<String> keys) {
      for (final key in keys) {
        if (source.containsKey(key) && source[key] != null) {
          return source[key];
        }
      }
      return null;
    }

    String readString(Map<String, dynamic> source, List<String> keys,
        {String fallback = ''}) {
      final value = pick(source, keys);
      if (value == null) return fallback;
      final text = value.toString().trim();
      return text.isEmpty ? fallback : text;
    }

    String readObjectLabel(dynamic value, {String fallbackKey = 'name'}) {
      if (value == null) return '';
      if (value is Map) {
        return value[fallbackKey]?.toString() ??
            value['title']?.toString() ??
            value['label']?.toString() ??
            value['id']?.toString() ??
            '';
      }
      return value.toString();
    }

    String? readObjectId(dynamic value, {String fallbackKey = 'id'}) {
      if (value == null) return null;
      if (value is Map) {
        return value[fallbackKey]?.toString() ??
            value['id']?.toString() ??
            null;
      }
      return value.toString();
    }

    List<String> readListValues(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value.map((item) {
          if (item is Map) {
            return item['name']?.toString() ??
                item['title']?.toString() ??
                item['label']?.toString() ??
                item['id']?.toString() ??
                item.toString();
          }
          return item?.toString() ?? '';
        }).toList();
      }
      return [value.toString()];
    }

    // Keep tariff objects as serialized JSON so complete pricing metadata
    // is preserved in Hive and can be used during ticket calculation.
    List<String> readTariffValues(dynamic value) {
      if (value == null) return [];

      if (value is List) {
        return value.map((item) {
          if (item is Map) {
            try {
              return jsonEncode(Map<String, dynamic>.from(item));
            } catch (_) {
              return item.toString();
            }
          }
          return item?.toString() ?? '';
        }).where((e) => e.isNotEmpty).toList();
      }

      if (value is Map) {
        // Some APIs return tariffs as an object keyed by id/index instead of a list.
        // Flatten it into individual JSON objects for downstream matching logic.
        final values = value.values.toList();
        final looksLikeCollection = values.isNotEmpty && values.every((v) => v is Map);

        if (looksLikeCollection) {
          return values.map((item) {
            try {
              return jsonEncode(Map<String, dynamic>.from(item as Map));
            } catch (_) {
              return item.toString();
            }
          }).where((e) => e.isNotEmpty).toList();
        }

        try {
          return [jsonEncode(Map<String, dynamic>.from(value))];
        } catch (_) {
          return [value.toString()];
        }
      }

      return [value.toString()];
    }

    VehicleRoute? readCurrentRoute(dynamic value) {
      if (value == null) return null;

      try {
        if (value is List && value.isNotEmpty) {
          final firstItem = value.first;
          if (firstItem is Map) {
            return VehicleRoute.fromJson(Map<String, dynamic>.from(firstItem));
          }
          final destId = firstItem?.toString() ?? '';
          return VehicleRoute(
            id: destId,
            vehicleId: readString(json, ['id']),
            terminalDestinationId: destId,
            assignedAt: null,
            unassignedAt: null,
            isOnTemporary: false,
            terminalDestination: null,
          );
        }

        if (value is Map) {
          return VehicleRoute.fromJson(Map<String, dynamic>.from(value));
        }
      } catch (e) {
        print('⚠️ Vehicle route parse failed: $e');
      }

      return null;
    }

    List<String> extractTariffs(Map<String, dynamic> source) {
      final collected = <String>[];

      void addAny(dynamic value) {
        final parsed = readTariffValues(value);
        for (final entry in parsed) {
          if (entry.trim().isNotEmpty && !collected.contains(entry)) {
            collected.add(entry);
          }
        }
      }

      addAny(pick(source, ['tariffs', 'tariff', 'vehicleTariffs', 'vehicle_tariffs']));

      final routeSource = pick(source, ['vehicleTerminalDestinations', 'vehicle_terminal_destinations']);
      if (routeSource is List) {
        for (final item in routeSource) {
          if (item is! Map) continue;
          final routeMap = Map<String, dynamic>.from(item);
          addAny(pick(routeMap, ['tariffs', 'tariff']));

          final terminalDest = pick(routeMap, ['terminalDestination', 'terminal_destination']);
          if (terminalDest is Map) {
            final tdMap = Map<String, dynamic>.from(terminalDest);
            addAny(pick(tdMap, ['tariffs', 'tariff']));
          }
        }
      }

      return collected;
    }

    VehicleRoute? route;
    try {
      final routeSource = pick(json, [
        'vehicleTerminalDestinations',
        'vehicle_terminal_destinations',
      ]);
      route = readCurrentRoute(routeSource);
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

    return VehicleModel(
      id: readString(json, ['id']),
      plateNumber: readString(json, ['plate_number', 'plateNumber']),
      plateRegion: readString(json, ['plate_region', 'plateRegion']),
      fleetType: readObjectLabel(pick(json, ['fleetType', 'fleet_type'])),
      vehicleLevel: readObjectLabel(pick(json, ['vehicleLevel', 'vehicle_level'])),
      associationName: readObjectLabel(pick(json, ['association', 'associations'])),
      seatCapacity: parseSeat(pick(json, ['seat_capacity', 'seatCapacity'])),
      status: readString(json, ['status'], fallback: 'active'),
      assignedTerminalId: pick(json, ['assigned_terminal_id', 'assignedTerminalId'])?.toString(),
      createdBy: pick(json, ['created_by', 'createdBy'])?.toString(),
      updatedBy: pick(json, ['updated_by', 'updatedBy'])?.toString(),
      createdAt: pick(json, ['created_at', 'createdAt'])?.toString(),
      updatedAt: pick(json, ['updated_at', 'updatedAt'])?.toString(),
      arrivalTerminals: readListValues(pick(json, ['arrival_terminals', 'arrivalTerminals'])),
      tariffs: extractTariffs(json),
      vehicleLevelId: pick(json, ['vehicle_level_id', 'vehicleLevelId'])?.toString() ??
          readObjectId(pick(json, ['vehicleLevel', 'vehicle_level'])),
      fleetTypeId: pick(json, ['fleet_type_id', 'fleetTypeId'])?.toString() ??
          readObjectId(pick(json, ['fleetType', 'fleet_type'])),
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