import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oro_ticket_app/app/modules/reset_password/controller/reset_new_password_controller.dart';
import 'package:oro_ticket_app/core/constants/colors.dart';
import 'package:oro_ticket_app/core/constants/dimensions.dart';
import 'package:oro_ticket_app/core/constants/typography.dart';

class ResetNewPasswordView extends GetView<ResetNewPasswordController> {
  const ResetNewPasswordView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Reset Password"),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingMedium,
            vertical: AppDimensions.paddingMedium,
          ),
          child: Form(
            key: controller.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: AppDimensions.verticalSpacingLarge),

                // Title
                Text(
                  'Create New Password',
                  style: AppTextStyles.heading1,
                ),

                SizedBox(height: AppDimensions.verticalSpacingMedium),

                Text(
                  'Enter a strong password to secure your account',
                  style: AppTextStyles.caption2,
                ),

                SizedBox(height: AppDimensions.verticalSpacingLarge),

                // New Password
                Obx(() => TextFormField(
                      controller: controller.passwordController,
                      obscureText: !controller.isPasswordVisible.value,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Password is required';
                        }
                        if (value.length < 8) {
                          return 'Password must be at least 8 characters';
                        }
                        if (!RegExp(r'[A-Z]').hasMatch(value)) {
                          return 'Password must contain uppercase letter';
                        }
                        if (!RegExp(r'[a-z]').hasMatch(value)) {
                          return 'Password must contain lowercase letter';
                        }
                        if (!RegExp(r'[0-9]').hasMatch(value)) {
                          return 'Password must contain a number';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12))),
                        hoverColor: AppColors.primary,
                        focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: AppColors.primaryHover),
                            borderRadius: BorderRadius.all(Radius.circular(12))),
                        suffixIcon: IconButton(
                          icon: Icon(controller.isPasswordVisible.value
                              ? Icons.visibility
                              : Icons.visibility_off),
                          onPressed: controller.togglePasswordVisibility,
                        ),
                      ),
                    )),

                SizedBox(height: AppDimensions.verticalSpacingMedium),

                // Confirm Password
                Obx(() => TextFormField(
                      controller: controller.confirmPasswordController,
                      obscureText: !controller.isConfirmPasswordVisible.value,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value != controller.passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12))),
                        hoverColor: AppColors.primary,
                        focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: AppColors.primaryHover),
                            borderRadius: BorderRadius.all(Radius.circular(12))),
                        suffixIcon: IconButton(
                          icon: Icon(controller.isConfirmPasswordVisible.value
                              ? Icons.visibility
                              : Icons.visibility_off),
                          onPressed: controller.toggleConfirmPasswordVisibility,
                        ),
                      ),
                    )),

                SizedBox(height: AppDimensions.verticalSpacingMedium),

                // Error message
                Obx(() {
                  if (controller.resetError.value.isNotEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.error),
                      ),
                      child: Text(
                        controller.resetError.value,
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 14,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }),

                SizedBox(height: AppDimensions.verticalSpacingMedium),

                // Success message
                Obx(() {
                  if (controller.resetSuccess.value.isNotEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.success),
                      ),
                      child: Text(
                        controller.resetSuccess.value,
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 14,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }),

                SizedBox(height: AppDimensions.verticalSpacingLarge),

                // Reset Button
                Obx(() => SizedBox(
                      height: AppDimensions.buttonHeight,
                      child: ElevatedButton(
                        onPressed: controller.isLoading.value
                            ? null
                            : () {
                                print('✅ Reset password button pressed');
                                controller.resetPassword();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppDimensions.borderRadius),
                          ),
                        ),
                        child: controller.isLoading.value
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                'Reset Password',
                                style: AppTextStyles.button,
                              ),
                      ),
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
