import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:oro_ticket_app/data/locals/models/arrival_terminal_model.dart';
import 'package:oro_ticket_app/data/locals/models/commission_rule_model.dart';
import 'package:oro_ticket_app/data/locals/models/departure_terminal_model.dart';
import 'package:oro_ticket_app/data/locals/models/service_charge_model.dart';
import 'package:oro_ticket_app/data/locals/models/tariff_model.dart';
import 'package:oro_ticket_app/data/locals/models/terminal_destination.dart';
import 'package:oro_ticket_app/data/locals/models/trip_model.dart';
import 'package:oro_ticket_app/data/locals/models/user_model.dart';
import 'package:oro_ticket_app/data/locals/models/vehicle_print_lock_model.dart';
import 'package:oro_ticket_app/data/locals/models/vehicle_route.dart';
import 'package:path_provider/path_provider.dart' as path_provider;

import 'models/vehicle_model.dart';

class HiveBoxes {
  static const String vehiclesBox = 'vehiclesBox';
  static const String departureTerminalsBox = 'departureTerminalsBox';
  static const String arrivalTerminalsBox = 'arrivalTerminalsBox';
  static const String commissionRulesBox = 'commissionRulesBox';
  static const String tripBox = 'tripBox';
  static const String serviceChargeBox = 'serviceChargeBox';
  static const String userBox = 'userData';
  static const String tariffsBox = 'tariffsBox';
  static const String vehiclePrintLockBox = 'vehiclePrintLocksBox';
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    try {
      final appDir = await path_provider.getApplicationDocumentsDirectory();
      await Hive.initFlutter(appDir.path);

      // Clear existing boxes if they exist
      // await _deleteBoxIfExists(vehiclesBox);
      // await _deleteBoxIfExists(departureTerminalsBox);
      // await _deleteBoxIfExists(arrivalTerminalsBox);
      // await _deleteBoxIfExists(commissionRulesBox);

      // Register adapters
      Hive.registerAdapter(VehicleModelAdapter());
      Hive.registerAdapter(DepartureTerminalModelAdapter());
      Hive.registerAdapter(ArrivalTerminalModelAdapter());
      Hive.registerAdapter(CommissionRuleModelAdapter());
      Hive.registerAdapter(TripModelAdapter());
      Hive.registerAdapter(ServiceChargeModelAdapter());
      Hive.registerAdapter(UserModelAdapter());
      Hive.registerAdapter(TariffModelAdapter());
      Hive.registerAdapter(TerminalDestinationAdapter());
      Hive.registerAdapter(VehicleRouteAdapter());
      Hive.registerAdapter(VehiclePrintLockAdapter());

      // Open boxes
      await Future.wait([
        Hive.openBox<VehicleModel>(vehiclesBox),
        Hive.openBox<DepartureTerminalModel>(departureTerminalsBox),
        Hive.openBox<ArrivalTerminalModel>(arrivalTerminalsBox),
        Hive.openBox<CommissionRuleModel>(commissionRulesBox),
        Hive.openBox<TripModel>(tripBox),
        Hive.openBox<ServiceChargeModel>(serviceChargeBox),
        Hive.openBox<UserModel>(userBox),
        Hive.openBox<TariffModel>(tariffsBox),
        Hive.openBox<VehiclePrintLock>('vehiclePrintLocksBox'),
      ]);

      _initialized = true;
    } catch (e) {
      debugPrint('Hive initialization failed: $e');
      rethrow;
    }
  }

  static Future<void> _deleteBoxIfExists(String boxName) async {
    if (await Hive.boxExists(boxName)) {
      await Hive.deleteBoxFromDisk(boxName);
    }
  }

  static Future<Box<T>> getBox<T>(String boxName) async {
    if (!_initialized) await init();
    if (!Hive.isBoxOpen(boxName)) {
      return await Hive.openBox<T>(boxName);
    }
    return Hive.box<T>(boxName);
  }
}
