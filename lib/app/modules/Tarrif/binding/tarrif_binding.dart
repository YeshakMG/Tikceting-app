import 'package:get/get.dart';
import '../controller/tarrif_controller.dart';

class TariffBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TariffController>(() => TariffController());
  }
}
