import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oro_ticket_app/core/constants/colors.dart';
import 'package:oro_ticket_app/core/constants/typography.dart';

class ResetDashboardDialog extends StatelessWidget {
  final VoidCallback onReset;
  final TextEditingController passwordController = TextEditingController();
  final RxBool isPasswordVisible = false.obs;

  ResetDashboardDialog({super.key, required this.onReset});

  void togglePasswordVisibility() {
    isPasswordVisible.toggle();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Reset Dashboard',
              style: AppTextStyles.subtitle4,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Enter your Password to Reset Dashboard',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption2,
            ),
            const SizedBox(height: 20),
            Obx(() => TextField(
                  controller: passwordController,
                  obscureText: !isPasswordVisible.value,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12))),
                    hoverColor: AppColors.primary,
                    focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.primaryHover),
                        borderRadius: BorderRadius.all(Radius.circular(12))),
                    suffixIcon: IconButton(
                      icon: Icon(isPasswordVisible.value
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: togglePasswordVisibility,
                    ),
                  ),
                )),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                if (passwordController.text.isNotEmpty) {
                  onReset();
                  passwordController.clear();
                  isPasswordVisible.value = false;
                  Get.back();
                } else {
                  Get.snackbar(
                    'Error',
                    'Please enter your password',
                    backgroundColor: AppColors.error,
                    snackPosition: SnackPosition.BOTTOM,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryHover,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Reset',
                style: AppTextStyles.button,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                passwordController.clear();
                isPasswordVisible.value = false;
                Get.back();
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.primaryHover),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12))),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                'Cancel',
                style: AppTextStyles.buttonMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
