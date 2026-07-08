import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oro_ticket_app/core/constants/colors.dart';
import '../../sign_in/services/auth_service.dart';

class ChangePasswordController extends GetxController {
  final AuthService _authService = Get.find<AuthService>();

  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final isCurrentPasswordVisible = false.obs;
  final isNewPasswordVisible = false.obs;
  final isConfirmPasswordVisible = false.obs;
  final isLoading = false.obs;
  final changeError = ''.obs;
  final changeSuccess = ''.obs;

  // Form key
  final formKey = GlobalKey<FormState>();

  @override
  void onInit() {
    super.onInit();
    clearFields();
  }

  void clearFields() {
    currentPasswordController.clear();
    newPasswordController.clear();
    confirmPasswordController.clear();
    changeError.value = '';
    changeSuccess.value = '';
    isCurrentPasswordVisible.value = false;
    isNewPasswordVisible.value = false;
    isConfirmPasswordVisible.value = false;
  }

  void toggleCurrentPasswordVisibility() {
    isCurrentPasswordVisible.value = !isCurrentPasswordVisible.value;
  }

  void toggleNewPasswordVisibility() {
    isNewPasswordVisible.value = !isNewPasswordVisible.value;
  }

  void toggleConfirmPasswordVisibility() {
    isConfirmPasswordVisible.value = !isConfirmPasswordVisible.value;
  }

  String? validateCurrentPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Current password is required';
    }
    return null;
  }

  String? validateNewPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'New password is required';
    }
    if (value.length < 6) {
      return 'New password must be at least 6 characters';
    }
    return null;
  }

  String? validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your new password';
    }
    if (value != newPasswordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> changePassword() async {
    final currentPassword = currentPasswordController.text;
    final newPassword = newPasswordController.text;

    isLoading.value = true;
    changeError.value = '';
    changeSuccess.value = '';

    try {
      final result = await _authService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      if (result['success'] == true) {
        changeSuccess.value = 'Password changed successfully';
        clearFields();
        Get.snackbar(
          'Success',
          'Password changed successfully',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.success,
          colorText: AppColors.backgroundAlt,
          duration: const Duration(seconds: 3),
        );
        // Automatically logout after success
        Future.delayed(const Duration(seconds: 3), () async {
          await _authService.logout();
        });
      } else {
        _handleChangePasswordError(result);
      }
    } catch (e) {
      changeError.value = 'An unexpected error occurred';
      Get.snackbar(
        'Error',
        'An unexpected error occurred',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: AppColors.titleAlt,
        duration: const Duration(seconds: 4),
      );
    } finally {
      isLoading.value = false;
    }
  }

  void _handleChangePasswordError(Map<String, dynamic> result) {
    String title = 'Change Password Failed';
    String message = 'An error occurred while changing password';

    if (result['statusCode'] != null) {
      final statusCode = result['statusCode'] as int;
      switch (statusCode) {
        case 400:
          title = 'Bad Request';
          message = result['message'] ?? 'Invalid request data';
          break;
        case 401:
          title = 'Unauthorized';
          message = 'Current password is incorrect';
          break;
        case 422:
          title = 'Validation Error';
          message = result['message'] ?? 'Validation failed';
          break;
        case 500:
          title = 'Server Error';
          message = 'Internal server error, please try again later';
          break;
        default:
          message = result['message'] ?? 'Failed to change password';
      }
    } else if (result['message'] != null) {
      message = result['message'].toString();
    }

    changeError.value = message;
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.error,
      colorText: AppColors.titleAlt,
      duration: const Duration(seconds: 4),
    );
  }

  @override
  void onClose() {
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
}