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

    double parseNum(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0.0;
    }

    Map<String, double>? parseDistanceMap(dynamic value) {
      if (value == null || value is! Map) return null;

      final parsed = <String, double>{};
      value.forEach((key, raw) {
        if (raw is Map) {
          final nested = raw['distance'] ?? raw['value'] ?? raw['km'];
          parsed[key.toString()] = parseNum(nested);
        } else {
          parsed[key.toString()] = parseNum(raw);
        }
      });

      return parsed.isEmpty ? null : parsed;
    }

    // Parse road distances if present
    Map<String, double>? roadDistances;
    final rawRoadDistances = pick(['road_distances', 'roadDistances']);
    if (rawRoadDistances != null && rawRoadDistances is Map) {
      roadDistances = {};
      final distances = Map<String, dynamic>.from(rawRoadDistances);
      distances.forEach((key, value) {
        if (value is Map) {
          final nested = value['distance'] ?? value['value'] ?? value['km'];
          roadDistances![key] = parseNum(nested);
        } else {
          roadDistances![key] = parseNum(value);
        }
      });
    }

    // Some APIs send distance as an object (e.g. by road type).
    roadDistances ??= parseDistanceMap(pick(['distance', 'total_distance', 'totalDistance']));

    final totalDistance = roadDistances != null
        ? roadDistances.values.fold<double>(0.0, (sum, d) => sum + d)
      : parseNum(pick(['distance', 'total_distance', 'totalDistance']));

    String parsedRoadType;
    if (roadDistances != null && roadDistances.isNotEmpty) {
      parsedRoadType = roadDistances.length > 1
          ? 'hybrid'
          : roadDistances.keys.first.toString();
    } else {
      parsedRoadType = readString(['road_type', 'roadType'], fallback: 'asphalt');
    }

    final departureTerminalRaw = pick(['departureTerminal', 'departure_terminal']);
    final arrivalTerminalRaw = pick(['arrivalTerminal', 'arrival_terminal']);

    final departureTerminalName = departureTerminalRaw is Map
        ? (departureTerminalRaw['name'] ?? departureTerminalRaw['terminal_name'])?.toString()
        : readString(['departure_terminal_name', 'departureTerminalName'], fallback: '');

    final arrivalTerminalName = arrivalTerminalRaw is Map
        ? (arrivalTerminalRaw['name'] ?? arrivalTerminalRaw['terminal_name'])?.toString()
        : readString(['arrival_terminal_name', 'arrivalTerminalName'], fallback: '');

    return TerminalDestination(
      id: readString(['id', 'terminal_destination_id', 'terminalDestinationId']),
      departureTerminalId: readString(['departure_terminal_id', 'departureTerminalId']),
      arrivalTerminalId: readString(['arrival_terminal_id', 'arrivalTerminalId']),
      distance: totalDistance,
      roadType: parsedRoadType,
      roadDistances: roadDistances,
      departureTerminalName: departureTerminalName,
      arrivalTerminalName: arrivalTerminalName,
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
