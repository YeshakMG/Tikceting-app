import 'package:get/get.dart';

class TariffController extends GetxController {
  var selectedArrival = ''.obs;
  var arrivals = ['Adama', 'Addis Ababa', 'Jimma', 'Bale'].obs;

  var tariffs = <Map<String, dynamic>>[].obs;
  var filteredTariffs = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchTariffs();
  }

  void fetchTariffs() {
    tariffs.value = [
      {"arrival": "Adama", "level": "Level 1", "fleet_category": "Mini Bus", "price": 50},
      {"arrival": "Adama", "level": "Level 2", "fleet_category": "Coaster", "price": 70},
      {"arrival": "Adama", "level": "Level 3", "fleet_category": "Bus", "price": 90},
      {"arrival": "Jimma", "level": "Level 1", "fleet_category": "Mini Bus", "price": 60},
      {"arrival": "Jimma", "level": "Level 2", "fleet_category": "Coaster", "price": 80},
      {"arrival": "Jimma", "level": "Level 3", "fleet_category": "Bus", "price": 100},
    ];
    filteredTariffs.assignAll(tariffs);
  }

  void filterTariffs(String arrival) {
    selectedArrival.value = arrival;
    filteredTariffs.value = tariffs.where((tariff) => tariff['arrival'] == arrival).toList();
  }
}

