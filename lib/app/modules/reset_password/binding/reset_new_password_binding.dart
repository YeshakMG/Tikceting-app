import 'package:get/get.dart';
import 'package:oro_ticket_app/app/modules/reset_password/controller/reset_new_password_controller.dart';

class ResetNewPasswordBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ResetNewPasswordController>(
      () => ResetNewPasswordController(),
    );
  }
}
