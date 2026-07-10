import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oro_ticket_app/app/modules/sign_in/controllers/sign_in_controller.dart';
import 'package:oro_ticket_app/core/constants/colors.dart';
import 'package:oro_ticket_app/core/constants/dimensions.dart';
import 'package:oro_ticket_app/core/constants/typography.dart';

class SignInView extends StatelessWidget {
  final SignInController controller = Get.put(SignInController());

  SignInView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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

                // Logo
                Center(
                  child: Image.asset(
                    'assets/logo/OTA_logo.png',
                    height: 150,
                  ),
                ),

                SizedBox(height: AppDimensions.verticalSpacingLarge),

                // Title
                Text(
                  'Sign in to your \nAccount',
                  style: AppTextStyles.heading1,
                ),

                SizedBox(height: AppDimensions.verticalSpacingMedium),

                Text(
                  'Enter your email and password to log in',
                  style: AppTextStyles.caption2,
                ),

                SizedBox(height: AppDimensions.verticalSpacingMedium),

                // Email
                TextFormField(
                  controller: controller.emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Email is required';
                    }
                    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                    if (!emailRegex.hasMatch(value.trim())) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12))),
                    hoverColor: AppColors.primary,
                    focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.primaryHover),
                        borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                ),

                SizedBox(height: AppDimensions.verticalSpacingMedium),

                // Password
                Obx(() => TextFormField(
                      controller: controller.passwordController,
                      obscureText: !controller.isPasswordVisible.value,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Password is required';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'Password',
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

                SizedBox(height: AppDimensions.verticalSpacingLarge),

                // Login Button
                Obx(() => SizedBox(
                      height: AppDimensions.buttonHeight,
                      child: ElevatedButton(
                        onPressed: controller.isLoading.value
                            ? null
                            : () {
                                print('🔘 Login button pressed');
                                // Trigger form validation to show field errors
                                final isValid = controller.formKey.currentState?.validate() ?? false;
                                print('✅ Form validation result: $isValid');

                                if (isValid) {
                                  print('🚀 Calling controller.login()');
                                  controller.login();
                                } else {
                                  print('❌ Form validation failed - showing snackbar');
                                  // Validation errors are already shown on fields
                                  // Optional: Show snackbar for additional feedback
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
                            borderRadius:
                                BorderRadius.circular(AppDimensions.borderRadius),
                          ),
                        ),
                        child: controller.isLoading.value
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                'Log In',
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