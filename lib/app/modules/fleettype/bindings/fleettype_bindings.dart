import 'package:get/get.dart';
import '../controllers/fleettype_controllers.dart';


class FleetTypeBindings extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<FleetTypeController>(
      () => FleetTypeController(),
    );
  }
}