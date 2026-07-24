import 'package:hive/hive.dart';
part 'terminal_destination.g.dart';

@HiveType(typeId: 10)
class TerminalDestination extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String departureTerminalId;

  @HiveField(2)
  final String arrivalTerminalId;

  @HiveField(3)
  final double distance;

  @HiveField(4)
  final String roadType;

  @HiveField(5)
  final Map<String, double>? roadDistances;

  @HiveField(6)
  final String? departureTerminalName;

  @HiveField(7)
  final String? arrivalTerminalName;

  TerminalDestination({
    required this.id,
    required this.departureTerminalId,
    required this.arrivalTerminalId,
    required this.distance,
    required this.roadType,
    this.roadDistances,
    this.departureTerminalName,
    this.arrivalTerminalName,
  });

  factory TerminalDestination.fromJson(Map<String, dynamic> json) {
    // Parse road distances if present
    Map<String, double>? roadDistances;
    if (json['road_distances'] != null) {
      roadDistances = {};
      final distances = json['road_distances'] as Map<String, dynamic>;
      distances.forEach((key, value) {
        roadDistances![key] = (value as num).toDouble();
      });
    }

    final parsedRoadType = (json['road_type'] ?? 'asphalt').toString();
    final parsedDistance = double.tryParse(json['distance'].toString()) ?? 0.0;

    // If segmented road distances exist, always use their sum for KM display.
    // This covers hybrid and mislabeled mixed-road payloads alike.
    final resolvedDistance = roadDistances != null && roadDistances.isNotEmpty
      ? roadDistances.values.fold<double>(0.0, (sum, d) => sum + d)
      : parsedDistance;

    return TerminalDestination(
      id: json['id']?.toString() ?? '',
      departureTerminalId: json['departure_terminal_id']?.toString() ?? '',
      arrivalTerminalId: json['arrival_terminal_id']?.toString() ?? '',
      distance: resolvedDistance,
      roadType: parsedRoadType,
      roadDistances: roadDistances,
      departureTerminalName: json['departureTerminal']?['name']?.toString(),
      arrivalTerminalName: json['arrivalTerminal']?['name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'departure_terminal_id': departureTerminalId,
      'arrival_terminal_id': arrivalTerminalId,
      'distance': distance,
      'road_type': roadType,
    };

    if (roadDistances != null && roadDistances!.isNotEmpty) {
      map['road_distances'] = Map<String, dynamic>.from(roadDistances!);
    }

    if (departureTerminalName != null) {
      map['departureTerminal'] = {'name': departureTerminalName};
    }
    if (arrivalTerminalName != null) {
      map['arrivalTerminal'] = {'name': arrivalTerminalName};
    }

    return map;
  }

  // Helper method to check if route has mixed road types
  bool get hasMixedRoadTypes =>
      roadDistances != null && roadDistances!.isNotEmpty;

  // Get all road segments for calculation
  List<RoadSegment> getRoadSegments() {
    if (hasMixedRoadTypes) {
      return roadDistances!.entries
          .map((entry) => RoadSegment(
                roadType: entry.key,
                distance: entry.value,
              ))
          .toList();
    } else {
      return [
        RoadSegment(
          roadType: roadType,
          distance: distance,
        )
      ];
    }
  }
}

// Simple road segment class
class RoadSegment {
  final String roadType;
  final double distance;

  RoadSegment({
    required this.roadType,
    required this.distance,
  });
}
