import 'package:get/get.dart';
import 'package:oro_ticket_app/app/modules/reset_password/controller/otp_verification_controller.dart';

class OtpVerificationBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<OtpVerificationController>(
      () => OtpVerificationController(),
    );
  }
}
