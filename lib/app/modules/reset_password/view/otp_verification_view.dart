import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oro_ticket_app/app/modules/reset_password/controller/otp_verification_controller.dart';
import 'package:oro_ticket_app/core/constants/colors.dart';
import 'package:oro_ticket_app/core/constants/dimensions.dart';
import 'package:oro_ticket_app/core/constants/typography.dart';

class OtpVerificationView extends GetView<OtpVerificationController> {
  const OtpVerificationView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("OTP Verification"),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingMedium,
            vertical: AppDimensions.paddingMedium,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: AppDimensions.verticalSpacingLarge),

              // Success message
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.success),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: AppColors.success,
                      size: 28,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "OTP is successfully sent",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Obx(() => Text(
                          "to ${controller.userEmail.value}",
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.success,
                          ),
                          textAlign: TextAlign.center,
                        )),
                  ],
                ),
              ),

              SizedBox(height: AppDimensions.verticalSpacingLarge),

              // OTP Input Label
              const Text(
                "Enter 6-digit OTP",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),

              SizedBox(height: AppDimensions.verticalSpacingMedium),

              // OTP Input
              TextField(
                controller: controller.otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  counterText: "",
                  hintText: "000000",
                  hintStyle: TextStyle(
                    fontSize: 24,
                    color: Colors.grey.withOpacity(0.3),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              SizedBox(height: AppDimensions.verticalSpacingMedium),

              // Timer
              Obx(() => Center(
                    child: Column(
                      children: [
                        Text(
                          "Time remaining",
                          style: AppTextStyles.caption2,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          controller.formattedTime,
                          style: AppTextStyles.heading3.copyWith(
                            color: controller.timeRemaining.value <= 60
                                ? AppColors.error
                                : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  )),

              SizedBox(height: AppDimensions.verticalSpacingLarge),

              // Error message
              Obx(() {
                if (controller.otpError.value.isNotEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.error),
                    ),
                    child: Text(
                      controller.otpError.value,
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
                if (controller.otpSuccess.value.isNotEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.success),
                    ),
                    child: Text(
                      controller.otpSuccess.value,
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

              // Verify Button
              Obx(() => SizedBox(
                    height: AppDimensions.buttonHeight,
                    child: ElevatedButton(
                      onPressed: controller.isLoading.value
                          ? null
                          : controller.isTimerActive.value
                              ? () {
                                  print('✅ Verify button pressed');
                                  controller.verifyOtp();
                                }
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: Colors.grey,
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
                              'Verify OTP',
                              style: AppTextStyles.button,
                            ),
                    ),
                  )),

              SizedBox(height: AppDimensions.verticalSpacingMedium),

              // Resend OTP
              Obx(() => Center(
                    child: TextButton(
                      onPressed: controller.isTimerActive.value
                          ? null
                          : () {
                              print('🔄 Resend OTP button pressed');
                              controller.resendOtp();
                            },
                      child: Text(
                        "Didn't receive OTP? Resend",
                        style: AppTextStyles.caption2.copyWith(
                          color: controller.isTimerActive.value
                              ? Colors.grey
                              : AppColors.primary,
                        ),
                      ),
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
