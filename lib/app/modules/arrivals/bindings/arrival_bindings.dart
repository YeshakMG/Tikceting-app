import 'package:get/get.dart';
import '../controllers/arrival_controllers.dart';

class ArrivalLocationBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ArrivalLocationController>(() => ArrivalLocationController());
  }
}
