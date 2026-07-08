import 'package:get/get.dart';

class FleetTypeController extends GetxController {
  RxList<Map<String,dynamic>> allFleetType = <Map<String,dynamic>>[


        {'name': 'Tata', 'level': 'Level 2', 'totalSeat': 24},
    {'name': 'Tata', 'level': 'Level 2', 'totalSeat': 24},
    {'name': 'Bus', 'level': 'Level 3', 'totalSeat': 60},
    {'name': 'Tata', 'level': 'Level 2', 'totalSeat': 24},
    {'name': 'Minibus', 'level': 'Level 1', 'totalSeat': 14},
    {'name': 'Minibus', 'level': 'Level 1', 'totalSeat': 14},
    {'name': 'Tata', 'level': 'Level 2', 'totalSeat': 24},
  ].obs;
  RxList<Map<String,dynamic>> fleetTypes = <Map<String,dynamic>>[].obs;
  @override
  void onInit() {
    fleetTypes.value = List.from(allFleetType);
    super.onInit();
    
  } 
  void filterFleetType(String query) {
    if (query.isEmpty) {
      fleetTypes.value = List.from(allFleetType);
    } else {
      fleetTypes.value = allFleetType
          .where((item) => item['name'].toString().toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
  }

}