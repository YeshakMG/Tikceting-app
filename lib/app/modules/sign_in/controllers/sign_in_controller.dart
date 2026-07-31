// lib/modules/auth/controllers/sign_in_controller.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oro_ticket_app/core/constants/colors.dart';

import '../../home/controllers/home_controller.dart';
import '../services/auth_service.dart';

class SignInController extends GetxController {
  final AuthService _authService = Get.find<AuthService>();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final isPasswordVisible = false.obs;
  final isLoading = false.obs;
  final loginError = ''.obs;

  // Form key
  final formKey = GlobalKey<FormState>();

  @override
  void onInit() {
    super.onInit();
    // Clear text fields when sign-in view is initialized (including after logout)
    clearFields();

    ever(loginError, (error) {
      if (error.isNotEmpty) {
        Get.snackbar(
          'Login Error',
          error,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.error,
          colorText: AppColors.titleAlt,
          duration: const Duration(seconds: 4),
          margin: const EdgeInsets.all(10),
          borderRadius: 8,
        );
        loginError.value = '';
      }
    });
  }

  void clearFields() {
    emailController.clear();
    passwordController.clear();
    loginError.value = '';
    isPasswordVisible.value = false;
  }

  void togglePasswordVisibility() {
    isPasswordVisible.value = !isPasswordVisible.value;
  }

  // Validate and submit login
  Future<void> login() async {
    // Clear previous error before new login attempt
    loginError.value = '';
    
    final email = emailController.text.trim();
    final password = passwordController.text;

    // Guard for direct login() calls even if UI form validation is bypassed.
    if (email.isEmpty || password.isEmpty) {
      loginError.value = 'Please enter both email and password.';
      return;
    }

    isLoading.value = true;

    try {
      final result = await _authService.login(email: email, password: password);

      if (result['success'] == true) {
        final homeController = Get.find<HomeController>();
        homeController.loadUser();
        await _authService.fetchAndStoreProfileData();

        // Show success message before navigation
        Get.snackbar(
          'Success',
          'Login successful',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.success,
          colorText: AppColors.backgroundAlt,
          duration: const Duration(seconds: 2),
        );

        // Navigate after snackbar finishes
        Future.delayed(const Duration(seconds: 2, milliseconds: 500), () {
          Get.offAllNamed('/home');
        });
      } else {
        _handleLoginError(result);
      }
     } catch (e) {
       print("Error:$e");
       loginError.value = 'Network error occurred. Please check your connection and try again.';
    } finally {
      isLoading.value = false;
    }
  }

  void _handleLoginError(Map<String, dynamic> result) {
    String message = 'An error occurred during login';
    final serverMessage = (result['message'] ?? '').toString();
    final normalizedServerMessage = serverMessage.toLowerCase();

    if (result['rate_limited'] == true) {
      message = result['snackbar_message'] ??
          'For security reasons, login attempts are limited. Please wait before trying again.';
    } else if (result['error_type'] == 'config') {
      message = result['message'] ??
          'App configuration is invalid. Please contact support.';
    } else if (result['error_type'] == 'network') {
      message = result['message'] ??
          'Unable to connect to the server. Please check your internet connection and try again.';
    } else if (result['statusCode'] != null) {
      final statusCode = result['statusCode'] as int;
      switch (statusCode) {
        case 400:
          if (normalizedServerMessage.contains('version') ||
              normalizedServerMessage.contains('update')) {
            message = 'Please update your mobile application to the latest version.';
          } else {
            message = result['message'] ??
                'Invalid request data. Please check your email and password.';
          }
          break;
        case 401:
          message = 'Email or password is incorrect.';
          break;
        case 403:
          message = 'Access denied. Please contact support if you believe this is an error.';
          break;
        case 404:
          message = 'Login endpoint not found. Please try again later.';
          break;
        case 422:
          final errors = result['errors'];
          if (errors is List && errors.isNotEmpty) {
            message = errors.first.toString();
          } else {
            message = result['message'] ??
                'Please enter a valid email and password.';
          }
          break;
        case 426:
          message = 'Please update your mobile application to the latest version.';
          break;
        case 429:
          message = 'Too many login attempts. Please wait a minute and try again.';
          break;
        case 500:
          message = 'Server error occurred. Please try again later.';
          break;
        case 502:
          message = 'Server temporarily unavailable. Please try again later.';
          break;
        case 503:
          message = 'Service is currently unavailable. Please try again later.';
          break;
        default:
          if (normalizedServerMessage.contains('version') ||
              normalizedServerMessage.contains('update')) {
            message = 'Please update your mobile application to the latest version.';
          } else if (normalizedServerMessage.contains('email') &&
              normalizedServerMessage.contains('password')) {
            message = 'Email or password is incorrect.';
          } else {
            message = result['message'] ??
                'An unexpected error occurred during login.';
          }
      }
    } else if (result['errors'] != null) {
      if (result['errors'] is List && result['errors'].isNotEmpty) {
        message = result['errors'].first.toString();
      } else if (result['errors'] is String) {
        message = result['errors'];
      }
    } else if (result['message'] != null) {
      if (normalizedServerMessage.contains('version') ||
          normalizedServerMessage.contains('update')) {
        message = 'Please update your mobile application to the latest version.';
      } else if (normalizedServerMessage.contains('email') &&
          normalizedServerMessage.contains('password')) {
        message = 'Email or password is incorrect.';
      } else {
        message = result['message'];
      }
    }

    loginError.value = message;
    print('📢 Login error set: $message');
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}