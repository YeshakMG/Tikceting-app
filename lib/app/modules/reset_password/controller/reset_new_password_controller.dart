import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ResetNewPasswordController extends GetxController {
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  var userEmail = ''.obs;
  var isLoading = false.obs;
  var resetError = ''.obs;
  var resetSuccess = ''.obs;
  var isPasswordVisible = false.obs;
  var isConfirmPasswordVisible = false.obs;

  /// Get API base URL from .env file
  String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000';

  @override
  void onInit() {
    super.onInit();
    // Get email from arguments
    if (Get.arguments != null && Get.arguments is String) {
      userEmail.value = Get.arguments as String;
    }
  }

  void togglePasswordVisibility() {
    isPasswordVisible.value = !isPasswordVisible.value;
  }

  void toggleConfirmPasswordVisibility() {
    isConfirmPasswordVisible.value = !isConfirmPasswordVisible.value;
  }

  /// Reset password with OTP
  Future<void> resetPassword() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    // Check if passwords match
    if (passwordController.text != confirmPasswordController.text) {
      resetError.value = "Passwords do not match";
      return;
    }

    // Reset previous messages
    resetError.value = "";
    resetSuccess.value = "";
    isLoading.value = true;

    try {
      final password = passwordController.text.trim();
      
      print('🔵 Resetting password for email: ${userEmail.value}');
      print('🌐 API URL: $apiBaseUrl/auth/reset-password');
      
      // Make POST request to /auth/reset-password
      final response = await http.post(
        Uri.parse('$apiBaseUrl/auth/reset-password'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': userEmail.value,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 30));

      print('✅ API Response Status Code: ${response.statusCode}');
      print('📋 API Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('🎉 Password reset successful');
        resetSuccess.value = "Password reset successfully! Redirecting to login...";

        // Navigate back to SignInView after short delay
        await Future.delayed(const Duration(seconds: 2));
        Get.offAllNamed('/sign-in');
      } else {
        print('❌ Password reset failed with status: ${response.statusCode}');
        // Handle error response
        try {
          final errorBody = jsonDecode(response.body);
          resetError.value =
              errorBody['message'] ?? "Failed to reset password. Please try again.";
        } catch (e) {
          resetError.value = "Failed to reset password. Please try again.";
        }
      }
    } on TimeoutException {
      print('⏱️ Request timeout');
      resetError.value = "Request timeout. Please check your connection and try again.";
    } catch (e) {
      print('❌ Error: ${e.runtimeType} - ${e.toString()}');
      resetError.value = "Error: ${e.toString()}";
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
}
