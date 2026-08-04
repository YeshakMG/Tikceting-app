import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:oro_ticket_app/core/constants/colors.dart';
import 'package:oro_ticket_app/data/locals/models/service_charge_model.dart';
import 'package:oro_ticket_app/data/locals/hive_boxes.dart';

import 'package:oro_ticket_app/data/locals/models/user_model.dart';
import 'package:oro_ticket_app/app/modules/sign_in/services/auth_service.dart';
import 'package:oro_ticket_app/data/repositories/sync_repository.dart';
import 'package:uuid/uuid.dart';

// Fix the import for Ethiopian datetime
import 'package:ethiopian_datetime/ethiopian_datetime.dart';

class ServiceChargeSyncResult {
  final bool success;
  final String message;

  const ServiceChargeSyncResult({
    required this.success,
    required this.message,
  });
}

class HomeController extends GetxController {
  static const Uuid _uuid = Uuid();
  final Rx<UserModel?> user = Rx<UserModel?>(null);
  final RxString companyName = ''.obs;
  final RxString companyId = ''.obs;
  final RxString companyLogoUrl = ''.obs; // Add missing property
  final RxDouble serviceChargeToday = 0.0.obs;
  final RxString ethiopianDate = ''.obs;
  final RxString serviceChargeText = ''.obs;
  final RxString companyPhoneNo = ''.obs;
  final SyncRepository _syncRepository = SyncRepository();

  @override
  void onInit() {
    super.onInit();
    loadUser();
    loadTodayServiceCharge();
    updateEthiopianDate();
  }

  void loadUser() async {
    final authService = Get.find<AuthService>();
    final token = await authService.getToken();
    print('Token: $token');

    if (token == null) {
      debugPrint('No token found — skipping user load');
      return;
    }

    final loadedUser = await authService.getUser();

    if (loadedUser != null && loadedUser.companyName != null) {
      user.value = loadedUser;
      companyName.value = loadedUser.companyName!;
      companyLogoUrl.value = loadedUser.logoUrl ?? '';
      companyId.value = loadedUser.companyId;
      companyPhoneNo.value = loadedUser.companyPhoneNo ?? '';
    } else {
      Get.snackbar("Error", "User must have valid company info");
    }
  }

  Future<void> loadTodayServiceCharge() async {
    try {
      final box = Hive.box<ServiceChargeModel>(HiveBoxes.serviceChargeBox);

      // Get the latest entry (if you want the most recent, not first)
      final entry = box.isNotEmpty ? box.getAt(box.length - 1) : null;

      if (entry != null) {
        // Force a UI update by reassigning
        serviceChargeToday.value = entry.serviceChargeAmount;
        // Optional: Add a refresh trigger
        serviceChargeToday.refresh();
      } else {
        serviceChargeToday.value = 0.0;
      }
    } catch (e) {
      print("Error loading service charge: $e");
      serviceChargeToday.value = 0.0;
    }
  }

  void updateEthiopianDate() {
    final now = DateTime.now();
    final ethDate = now.convertToEthiopian();
    ethiopianDate.value =
        "${ethDate.day.toString().padLeft(2, '0')}-${ethDate.month.toString().padLeft(2, '0')}-${ethDate.year}";
  }

  void addOrUpdateServiceCharge({
    required double baseCharge,
    required int seatCount,
    required String departureTerminal,
  }) async {
    try {
      final box = Hive.box<ServiceChargeModel>(HiveBoxes.serviceChargeBox);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final currentUserId = user.value?.id ?? "Unknown";
      final newChargeAmount = baseCharge * seatCount;

      // Find existing service charge entry for today and user
      ServiceChargeModel? existingEntry;
      try {
        existingEntry = box.values.firstWhere((entry) {
          final entryDate = DateTime(
              entry.dateTime.year, entry.dateTime.month, entry.dateTime.day);
          return entry.employeeId == currentUserId && entryDate == today;
        });
      } catch (_) {
        existingEntry = null;
      }

      if (existingEntry != null) {
        // Update existing entry
        final index = box.values.toList().indexOf(existingEntry);
        final key = box.keyAt(index);

        final updatedEntry = ServiceChargeModel(
          departureTerminal: existingEntry.departureTerminal,
          dateTime: existingEntry.dateTime,
          serviceChargeAmount:
              existingEntry.serviceChargeAmount + newChargeAmount,
          employeeId: existingEntry.employeeId,
          companyId: existingEntry.companyId,
          employeeName: user.value?.fullName ?? '',
          transactionId: existingEntry.transactionId.isNotEmpty
              ? existingEntry.transactionId
              : _uuid.v4(),
        );

        await box.put(key, updatedEntry);
        print(
            "✅ Service charge updated. New total: ${updatedEntry.serviceChargeAmount}");
      } else {
        // Add new entry
        final newEntry = ServiceChargeModel(
          departureTerminal: departureTerminal,
          dateTime: now,
          serviceChargeAmount: newChargeAmount,
          employeeId: currentUserId,
          companyId: user.value?.companyId ?? "Unknown",
          employeeName: user.value?.fullName ?? '',
          transactionId: _uuid.v4(),
        );

        await box.add(newEntry);
        print("✅ New service charge added: $newChargeAmount");
      }

      // Reload today's total after update
      await loadTodayServiceCharge();
    } catch (e) {
      print("❌ Failed to add/update service charge: $e");
    }
  }

  // Dummy placeholder for syncing trips
  Future<void> syncTrips() async {
    try {
      await _syncRepository.syncTripsToServer();
      Get.snackbar(
        "Success",
        "Data synced successfully",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.primaryHover,
        colorText: AppColors.background,
      );
     } catch (e) {
       Get.snackbar(
         "Error",
         "Failed to sync data. Please try again.",
         snackPosition: SnackPosition.BOTTOM,
         backgroundColor: AppColors.error,
         colorText: AppColors.background,
       );
       rethrow;
     }
  }

  Future<ServiceChargeSyncResult> syncServiceCharge() async {
    final box = Hive.box<ServiceChargeModel>(HiveBoxes.serviceChargeBox);

    if (box.isEmpty) {
      return const ServiceChargeSyncResult(
        success: true,
        message: "No service charges to sync.",
      );
    }

    final connectivityResults = await Connectivity().checkConnectivity();
    final hasNetwork = connectivityResults
        .any((result) => result != ConnectivityResult.none);
    if (!hasNetwork) {
      return const ServiceChargeSyncResult(
        success: false,
        message: "No internet connection. Please connect and try again.",
      );
    }

    try {
      await _syncRepository.syncServiceChargeToServer();

      if (box.isNotEmpty) {
        return const ServiceChargeSyncResult(
          success: false,
          message:
              "Sync timed out or server did not accept all records. Please try again.",
        );
      }

      Get.snackbar(
        "Success",
        "Service charge synced successfully",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.primaryHover,
        colorText: AppColors.background,
      );
      return const ServiceChargeSyncResult(
        success: true,
        message: "Service charge synced successfully.",
      );
    } catch (e) {
      final message =
          e is TimeoutException || e.toString().contains('TimeoutException')
              ? "Sync timed out. Please check your connection and try again."
              : "Failed to sync service charge. Please try again.";
      return ServiceChargeSyncResult(success: false, message: message);
    }
  }

  void resetDashboard() async {
    serviceChargeToday.value = 0.0;
    serviceChargeText.value = '';

    try {
      print('ℹ️ Dashboard reset requested; preserving local service-charge records');
    } catch (e) {
      print('❌ Error resetting dashboard summary: $e');
    }
  }

  void refreshDashboard() {
    loadUser();
    loadTodayServiceCharge();
    updateEthiopianDate();
  }
}
