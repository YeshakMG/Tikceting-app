import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

class ResetPasswordController extends GetxController {
  final emailController = TextEditingController();

  var isLoading = false.obs;
  var resetError = ''.obs;
  var resetSuccess = ''.obs;

  /// Call this when the user taps "Reset Password"
  Future<void> resetPassword() async {
    if (emailController.text.isEmpty) {
      resetError.value = "Please enter your email";
      return;
    }

    // Reset previous messages
    resetError.value = "";
    resetSuccess.value = "";
    isLoading.value = true;

    try {
      // TODO: Replace this with your actual API call
      await Future.delayed(const Duration(seconds: 2));

      // Success message
      resetSuccess.value =
          "Password reset instructions have been sent to your email.";

      // ✅ Mark first install as done
      final appState = Hive.box('appState');
      appState.put('isFirstInstall', false);

      // ✅ Navigate to SignInView after short delay
      await Future.delayed(const Duration(seconds: 1));
      Get.offAllNamed('/sign-in'); // or Routes.SIGN_IN if using AppPages.Routes
    } catch (e) {
      resetError.value = "Failed to reset password. Please try again.";
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    emailController.dispose();
    super.onClose();
  }
}
