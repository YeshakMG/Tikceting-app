import 'package:hive/hive.dart';

part 'vehicle_print_lock_model.g.dart';

@HiveType(typeId: 11)
class VehiclePrintLock extends HiveObject {
  @HiveField(0)
  final String vehicleId;

  @HiveField(1)
  late final DateTime lockUntil;

  VehiclePrintLock({
    required this.vehicleId,
    required this.lockUntil,
  });
}