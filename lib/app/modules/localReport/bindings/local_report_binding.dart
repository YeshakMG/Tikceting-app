import 'package:get/get.dart';
import '../controller/local_report_controller.dart';

class LocalReportBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LocalReportController>(
      () => LocalReportController(),
    );
  }
}