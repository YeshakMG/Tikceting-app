import 'package:get/get.dart';
import '../controllers/vehicles_controllers.dart';

class VehiclesBindings extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<VehiclesController>(() => VehiclesController());
  }
}
