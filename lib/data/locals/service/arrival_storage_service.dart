// lib/data/locals/service/arrival_terminal_storage_service.dart
import 'package:hive/hive.dart';
import 'package:oro_ticket_app/data/locals/models/arrival_terminal_model.dart';

class ArrivalTerminalStorageService {
  static const _boxName = 'arrivalTerminalsBox';

  static Future<Box<ArrivalTerminalModel>> _openBox() async {
    return await Hive.openBox<ArrivalTerminalModel>(_boxName);
  }

  static Future<void> saveTerminals(
      List<ArrivalTerminalModel> terminals) async {
    final box = await _openBox();
    await box.clear();
    await box.addAll(terminals);
  }

  static List<ArrivalTerminalModel> getTerminals() {
    final box = Hive.box<ArrivalTerminalModel>(_boxName);
    return box.values.toList();
  }

  static Future<void> clearTerminals() async {
    final box = await _openBox();
    await box.clear();
  }
}
