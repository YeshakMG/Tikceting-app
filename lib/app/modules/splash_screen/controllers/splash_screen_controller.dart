import 'package:get/get.dart';
import 'package:oro_ticket_app/app/routes/app_pages.dart';

class SplashScreenController extends GetxController {

  final String copywrite = "Oro Ticket App 2025. All rights reserved".tr;

  @override
  void onInit() {
    super.onInit();
    showSplash();
  }

  void showSplash() async {
    Future.delayed(const Duration(seconds: 5), () {
      Get.offAllNamed(
        Routes.SIGN_IN,
      );
    });
  }

  @override
  void onReady() {
    super.onReady();
  }

  @override
  void onClose() {
    super.onClose();
  }
}
