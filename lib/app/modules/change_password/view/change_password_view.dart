import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oro_ticket_app/app/modules/change_password/controller/change_password_controller.dart';
import 'package:oro_ticket_app/core/constants/colors.dart';
import 'package:oro_ticket_app/core/constants/dimensions.dart';
import 'package:oro_ticket_app/core/constants/typography.dart';

class ChangePasswordView extends GetView<ChangePasswordController> {
  const ChangePasswordView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Change Password"),
        backgroundColor: AppColors.primary,
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
                  'Change Your Password',
                  style: AppTextStyles.heading2,
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: AppDimensions.verticalSpacingMedium),

                Text(
                  'Enter your current password and choose a new one',
                  style: AppTextStyles.caption2,
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: AppDimensions.verticalSpacingLarge),

                // Current Password
                Obx(() => TextFormField(
                      controller: controller.currentPasswordController,
                      obscureText: !controller.isCurrentPasswordVisible.value,
                      validator: controller.validateCurrentPassword,
                      decoration: InputDecoration(
                        labelText: 'Current Password',
                        border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12))),
                        hoverColor: AppColors.primary,
                        focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: AppColors.primaryHover),
                            borderRadius: BorderRadius.all(Radius.circular(12))),
                        suffixIcon: IconButton(
                          icon: Icon(controller.isCurrentPasswordVisible.value
                              ? Icons.visibility
                              : Icons.visibility_off),
                          onPressed: controller.toggleCurrentPasswordVisibility,
                        ),
                      ),
                    )),

                SizedBox(height: AppDimensions.verticalSpacingMedium),

                // New Password
                Obx(() => TextFormField(
                      controller: controller.newPasswordController,
                      obscureText: !controller.isNewPasswordVisible.value,
                      validator: controller.validateNewPassword,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12))),
                        hoverColor: AppColors.primary,
                        focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: AppColors.primaryHover),
                            borderRadius: BorderRadius.all(Radius.circular(12))),
                        suffixIcon: IconButton(
                          icon: Icon(controller.isNewPasswordVisible.value
                              ? Icons.visibility
                              : Icons.visibility_off),
                          onPressed: controller.toggleNewPasswordVisibility,
                        ),
                      ),
                    )),

                SizedBox(height: AppDimensions.verticalSpacingMedium),

                // Confirm New Password
                Obx(() => TextFormField(
                      controller: controller.confirmPasswordController,
                      obscureText: !controller.isConfirmPasswordVisible.value,
                      validator: controller.validateConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
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

                SizedBox(height: AppDimensions.verticalSpacingLarge),

                // Change Password Button
                Obx(() => SizedBox(
                      height: AppDimensions.buttonHeight,
                      child: ElevatedButton(
                        onPressed: controller.isLoading.value
                            ? null
                            : () {
                                final isValid = controller.formKey.currentState?.validate() ?? false;
                                if (isValid) {
                                  controller.changePassword();
                                } else {
                                  Get.snackbar(
                                    'Validation Error',
                                    'Please correct the errors above',
                                    snackPosition: SnackPosition.BOTTOM,
                                    backgroundColor: AppColors.error,
                                    colorText: AppColors.titleAlt,
                                    duration: const Duration(seconds: 3),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
                          ),
                        ),
                        child: controller.isLoading.value
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                'Change Password',
                                style: AppTextStyles.button,
                              ),
                      ),
                    )),

                SizedBox(height: AppDimensions.verticalSpacingMedium),

                // Error Message
                Obx(() => Text(
                      controller.changeError.value,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    )),

                // Success Message
                Obx(() => Text(
                      controller.changeSuccess.value,
                      style: const TextStyle(color: Colors.green),
                      textAlign: TextAlign.center,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}