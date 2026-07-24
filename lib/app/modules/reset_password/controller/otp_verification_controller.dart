import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OtpVerificationController extends GetxController {
  final otpController = TextEditingController();
  
  var userEmail = ''.obs;
  var isLoading = false.obs;
  var otpError = ''.obs;
  var otpSuccess = ''.obs;
  var timeRemaining = 300.obs; // 5 minutes in seconds
  var isTimerActive = true.obs;
  
  late Timer _timer;

  /// Get API base URL from .env file
  String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000';

  @override
  void onInit() {
    super.onInit();
    // Get email from arguments if passed
    if (Get.arguments != null && Get.arguments is String) {
      userEmail.value = Get.arguments as String;
    }
    startTimer();
  }

  /// Start 5-minute countdown timer
  void startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (timeRemaining.value > 0) {
        timeRemaining.value--;
      } else {
        _timer.cancel();
        isTimerActive.value = false;
        otpError.value = "OTP has expired. Please request a new one.";
      }
    });
  }

  /// Format seconds to MM:SS
  String get formattedTime {
    final minutes = timeRemaining.value ~/ 60;
    final seconds = timeRemaining.value % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Verify OTP with API
  Future<void> verifyOtp() async {
    if (otpController.text.isEmpty) {
      otpError.value = "Please enter the OTP";
      return;
    }

    if (otpController.text.length != 6) {
      otpError.value = "OTP must be 6 digits";
      return;
    }

    // Reset previous messages
    otpError.value = "";
    otpSuccess.value = "";
    isLoading.value = true;

    try {
      final otp = otpController.text.trim();
      
      print('🔵 Verifying OTP: $otp');
      print('📧 Email: ${userEmail.value}');
      print('🌐 API URL: $apiBaseUrl/auth/verify-otp');
      
      // Make POST request to verify OTP
      final response = await http.post(
        Uri.parse('$apiBaseUrl/auth/verify-otp'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': userEmail.value,
          'otp': otp,
        }),
      ).timeout(const Duration(seconds: 30));

      print('✅ API Response Status Code: ${response.statusCode}');
      print('📋 API Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('🎉 OTP verification successful');
        otpSuccess.value = "OTP verified successfully!";

        // Navigate to password reset view
        await Future.delayed(const Duration(seconds: 1));
        Get.offAllNamed('/reset-new-password', arguments: userEmail.value);
      } else {
        print('❌ OTP verification failed with status: ${response.statusCode}');
        try {
          final errorBody = jsonDecode(response.body);
          otpError.value = errorBody['message'] ?? "Invalid OTP. Please try again.";
        } catch (e) {
          otpError.value = "Invalid OTP. Please try again.";
        }
      }
    } on TimeoutException {
      print('⏱️ Request timeout');
      otpError.value = "Request timeout. Please check your connection.";
    } catch (e) {
      print('❌ Error: ${e.runtimeType} - ${e.toString()}');
      otpError.value = "Error: ${e.toString()}";
    } finally {
      isLoading.value = false;
    }
  }

  /// Resend OTP
  Future<void> resendOtp() async {
    print('🔄 Resending OTP to ${userEmail.value}');
    print('🌐 API URL: $apiBaseUrl/auth/request-password-reset');
    
    try {
      // Call API to resend OTP
      final response = await http.post(
        Uri.parse('$apiBaseUrl/auth/request-password-reset'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': userEmail.value,
        }),
      ).timeout(const Duration(seconds: 30));

      print('✅ Resend API Response: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        timeRemaining.value = 300; // Reset timer to 5 minutes
        isTimerActive.value = true;
        otpError.value = "";
        otpSuccess.value = "OTP resent successfully!";
        startTimer();
        
        // Clear success message after 3 seconds
        await Future.delayed(const Duration(seconds: 3));
        otpSuccess.value = "";
      } else {
        otpError.value = "Failed to resend OTP. Please try again.";
      }
    } catch (e) {
      print('❌ Error resending OTP: ${e.toString()}');
      otpError.value = "Error resending OTP. Please try again.";
    }
  }

  @override
  void onClose() {
    _timer.cancel();
    otpController.dispose();
    super.onClose();
  }
}
