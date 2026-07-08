import 'package:get/get.dart';
import 'package:oro_ticket_app/app/modules/reset_password/controller/reset_password_controller.dart';

class ResetPasswordBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ResetPasswordController>(() => ResetPasswordController());
  }
}
