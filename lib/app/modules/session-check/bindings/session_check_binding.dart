import 'package:get/get.dart';

import '../controllers/session_check_controller.dart';

class SessionCheckBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SessionCheckController>(
      () => SessionCheckController(),
    );
  }
}
