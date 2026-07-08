// lib/controllers/arrival_controllers.dart
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:oro_ticket_app/data/repositories/sync_repository.dart';
import 'package:oro_ticket_app/data/locals/models/arrival_terminal_model.dart';

class ArrivalLocationController extends GetxController {
  final SyncRepository syncRepo = Get.put(SyncRepository());
  var locations = <ArrivalTerminalModel>[].obs;
  var filteredLocations = <ArrivalTerminalModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadLocations();
  }

  Future<void> loadLocations() async {
    // Load from local storage first
    locations.value = syncRepo.getLocalArrivalTerminals();
    filteredLocations.value = List.from(locations);

    // Then try to sync from API
    await syncLocations();
    List<ArrivalTerminalModel> localArrivals =
        syncRepo.getLocalArrivalTerminals();
    print('Number of arrivals stored: ${localArrivals.length}');
    for (var arrival in localArrivals) {
      print(arrival.toJson());
    }
  }

  Future<void> syncLocations() async {
    try {
      await syncRepo.syncCompanyUserArrivalTerminals();
      locations.value = syncRepo.getLocalArrivalTerminals();
      filteredLocations.value = List.from(locations);
    } catch (e) {
      if (kDebugMode) {
        print('Error Failed to sync arrival locations: $e');
      }
    }
  }

  void filterLocations(String query) {
    if (query.isEmpty) {
      filteredLocations.value = List.from(locations);
    } else {
      filteredLocations.value = locations.where((terminal) {
        return terminal.name.toLowerCase().contains(query.toLowerCase());
      }).toList();
    }
  }
}
