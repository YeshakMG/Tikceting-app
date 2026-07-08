import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:oro_ticket_app/data/locals/models/departure_terminal_model.dart';
import 'package:oro_ticket_app/data/locals/service/departure_terminal_storage_service.dart';
import 'package:oro_ticket_app/data/repositories/sync_repository.dart';

class DepartureControllers extends GetxController {
  final SyncRepository syncRepo = SyncRepository();
  Rx<DepartureTerminalModel?> terminal = Rx<DepartureTerminalModel?>(null);

  @override
  void onInit() {
    super.onInit();
    loadTerminal();
  }

  void loadTerminal() {
    // terminal.value = DepartureTerminalStorageService.getTerminal();
    terminal.value = syncRepo.getLocalDepartureTerminal();
    if (kDebugMode) {
      print('--- Current Stored Departure Terminal ---');
      if (terminal.value == null) {
        print('No terminal stored');
      } else {
        print(terminal.value!.toJson());
      }
    }
  }

  Future<void> syncTerminalFromApi(Map<String, dynamic> json) async {
    await syncRepo.syncDepartureTerminal(json);
    loadTerminal();
  }
}
