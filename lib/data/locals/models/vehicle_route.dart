import 'package:hive/hive.dart';
import 'package:oro_ticket_app/data/locals/models/terminal_destination.dart';
part 'vehicle_route.g.dart';

@HiveType(typeId: 9)
class VehicleRoute extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String vehicleId;

  @HiveField(2)
  final String terminalDestinationId;

  @HiveField(3)
  final DateTime? assignedAt;

  @HiveField(4)
  final DateTime? unassignedAt;

  @HiveField(5)
  final bool isOnTemporary;

  @HiveField(6)
  final TerminalDestination? terminalDestination;

  VehicleRoute({
    required this.id,
    required this.vehicleId,
    required this.terminalDestinationId,
    this.assignedAt,
    this.unassignedAt,
    required this.isOnTemporary,
    this.terminalDestination,
  });

  factory VehicleRoute.fromJson(Map<String, dynamic> json) {
    TerminalDestination? td;

    // Support different shapes: either nested under 'terminalDestination' or the map itself
    if (json['terminalDestination'] != null && json['terminalDestination'] is Map) {
      td = TerminalDestination.fromJson(Map<String, dynamic>.from(json['terminalDestination']));
    } else if (json.containsKey('arrival_terminal_id') || json.containsKey('departure_terminal_id')) {
      // The json itself looks like a TerminalDestination
      try {
        td = TerminalDestination.fromJson(Map<String, dynamic>.from(json));
      } catch (_) {
        td = null;
      }
    } else {
      td = null;
    }

    return VehicleRoute(
      id: json['id']?.toString() ?? '',
      vehicleId: json['vehicle_id']?.toString() ?? '',
      terminalDestinationId: json['terminal_destination_id']?.toString() ?? '',
      assignedAt: json['assigned_at'] != null
          ? DateTime.tryParse(json['assigned_at'].toString())
          : null,
      unassignedAt: json['unassigned_at'] != null
          ? DateTime.tryParse(json['unassigned_at'].toString())
          : null,
      isOnTemporary: json['is_on_temporary'] ?? false,
      terminalDestination: td,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicle_id': vehicleId,
      'terminal_destination_id': terminalDestinationId,
      'assigned_at': assignedAt?.toIso8601String(),
      'unassigned_at': unassignedAt?.toIso8601String(),
      'is_on_temporary': isOnTemporary,
      'terminalDestination': terminalDestination != null ? terminalDestination!.toJson() : null,
    };
  }

  @override
String toString() => 'VehicleRoute(id: $id, vehicleId: $vehicleId, terminalDestinationId: $terminalDestinationId)';
 }
