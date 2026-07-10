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
    dynamic pick(List<String> keys) {
      for (final key in keys) {
        if (json.containsKey(key) && json[key] != null) {
          return json[key];
        }
      }
      return null;
    }

    String readString(List<String> keys, {String fallback = ''}) {
      final value = pick(keys);
      if (value == null) return fallback;
      final text = value.toString().trim();
      return text.isEmpty ? fallback : text;
    }

    TerminalDestination? td;

    // Support different shapes: either nested under 'terminalDestination' or the map itself
    final nestedTerminalDestination = pick(['terminalDestination', 'terminal_destination']);
    if (nestedTerminalDestination != null && nestedTerminalDestination is Map) {
      td = TerminalDestination.fromJson(
        Map<String, dynamic>.from(nestedTerminalDestination),
      );
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
      id: readString(['id', 'route_id']),
      vehicleId: readString(['vehicle_id', 'vehicleId']),
      terminalDestinationId: readString([
        'terminal_destination_id',
        'terminalDestinationId',
      ]),
      assignedAt: pick(['assigned_at', 'assignedAt']) != null
          ? DateTime.tryParse(pick(['assigned_at', 'assignedAt']).toString())
          : null,
      unassignedAt: pick(['unassigned_at', 'unassignedAt']) != null
          ? DateTime.tryParse(pick(['unassigned_at', 'unassignedAt']).toString())
          : null,
      isOnTemporary: (pick(['is_on_temporary', 'isOnTemporary']) as bool?) ?? false,
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
