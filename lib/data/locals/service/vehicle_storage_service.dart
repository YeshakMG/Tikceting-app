import 'package:hive/hive.dart';
import '../models/vehicle_model.dart';
import '../hive_boxes.dart';

class VehicleStorageService {
  Future<void> saveVehicles(List<VehicleModel> vehicles) async {
    final box = Hive.box<VehicleModel>(HiveBoxes.vehiclesBox);
    await box.clear();
    for (var vehicle in vehicles) {
      await box.put(vehicle.id, vehicle);
    }
  }

  List<VehicleModel> getVehicles() {
    final box = Hive.box<VehicleModel>(HiveBoxes.vehiclesBox);
    return box.values.toList();
  }

  // VehicleModel? getVehicleById(String id) {
  //   final box = Hive.box<VehicleModel>(HiveBoxes.vehiclesBox);
  //   return box.get(id);
  // }

  VehicleModel? getVehicleById(String vehicleId) {
    final box = Hive.box<VehicleModel>(HiveBoxes.vehiclesBox);
    for (var key in box.keys) {
      final vehicle = box.get(key);
      if (vehicle?.id == vehicleId) {
        return vehicle;
      }
    }
    return null; 
  }

  int? getVehicleSeatCount(String vehicleId) {
    final vehicle = getVehicleById(vehicleId);
    return vehicle?.seatCapacity;
  }
  // static Future<void> deleteVehicle(String id) async {
  //   final box = Hive.box<VehicleModel>(HiveBoxes.vehiclesBox);
  //   await box.delete(id);
  // }

  Future<void> clearAll() async {
    final box = Hive.box<VehicleModel>(HiveBoxes.vehiclesBox);
    await box.clear();
  }
}
