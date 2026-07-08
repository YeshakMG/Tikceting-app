import 'package:hive/hive.dart';
import '../models/departure_terminal_model.dart';
import '../hive_boxes.dart';

class DepartureTerminalStorageService {
  static Future<void> saveTerminal(DepartureTerminalModel terminal) async {
    final box = Hive.box<DepartureTerminalModel>(HiveBoxes.departureTerminalsBox);
    await box.clear();
    await box.put(terminal.id, terminal);
  }

  static DepartureTerminalModel? getTerminal() {
    final box = Hive.box<DepartureTerminalModel>(HiveBoxes.departureTerminalsBox);
    return box.values.isNotEmpty ? box.values.first : null;
  }

  static Future<void> clearAll() async {
    final box = Hive.box<DepartureTerminalModel>(HiveBoxes.departureTerminalsBox);
    await box.clear();
  }
  
}

