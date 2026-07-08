import 'package:hive/hive.dart';

part 'departure_terminal_model.g.dart';

@HiveType(typeId: 1)
class  DepartureTerminalModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String status;

  DepartureTerminalModel({
    required this.id,
    required this.name,
    required this.status,
  });

  factory DepartureTerminalModel.fromJson(Map<String, dynamic> json) {
    return DepartureTerminalModel(
      id: json['id'],
      name: json['name'],
      status: json['status'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'status': status,
      };
}
