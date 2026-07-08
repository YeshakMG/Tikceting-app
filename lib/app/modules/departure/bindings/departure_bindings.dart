import 'package:get/get.dart';
import '../controllers/departure_controllers.dart';

class DepartureBindings  extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DepartureControllers>(
      () => DepartureControllers(),
    );
  }
}