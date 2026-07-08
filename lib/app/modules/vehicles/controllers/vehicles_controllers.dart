import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:oro_ticket_app/app/modules/sign_in/services/auth_service.dart';
import 'package:oro_ticket_app/data/locals/models/vehicle_model.dart';
import 'package:oro_ticket_app/data/repositories/sync_repository.dart';

class VehiclesController extends GetxController {
  final SyncRepository syncRepo = Get.find<SyncRepository>();

  RxList<VehicleModel> allVehicles = <VehicleModel>[].obs;
  RxList<VehicleModel> filteredVehicles = <VehicleModel>[].obs;
  RxBool isLoading = false.obs;
  RxBool isSyncing = false.obs;
  RxString errorMessage = ''.obs;

  // Pagination controls
  final int itemsPerPage = 10;
  RxInt currentPage = 1.obs;
  RxBool hasMore = true.obs;
  RxBool isPageLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadInitialVehicles();
    syncRepo.vehicleChanges.listen((_) => loadLocalVehicles());
  }

  Future<void> loadInitialVehicles() async {
    try {
      isLoading(true);
      errorMessage('');

      // This will automatically handle offline case
      await loadLocalVehicles();

      // Only show error if we have no local data AND offline
      if (allVehicles.isEmpty && !(await syncRepo.isOnline)) {
        errorMessage('No vehicles found (offline mode)');
      }
     } catch (e) {
       errorMessage('Failed to load vehicles. Please check your internet connection and try again.');
     } finally {
       isLoading(false);
     }
  }

  Future<void> loadLocalVehicles() async {
    final vehicles = await syncRepo.getVehicles();
    allVehicles.assignAll(vehicles);
    filteredVehicles.assignAll(vehicles);
    hasMore(
        allVehicles.length >= itemsPerPage); // Assume more if we have full page
  }

  Future<void> refreshVehicles() async {
    try {
      isSyncing(true);
      errorMessage('');
      await syncRepo.syncAllCompanyUserVehicles(forceSync: true);
    } catch (e) {
      // Don't show error if we have local data
       if (allVehicles.isEmpty) {
         errorMessage('Unable to sync vehicles. Please check your internet connection and try again.');
       } else {
         Get.snackbar('Offline', 'Showing locally stored vehicles',
             snackPosition: SnackPosition.BOTTOM);
       }
     } finally {
       isSyncing(false);
     }
   }

  Future<void> refreshVehiclesIfOnline() async {
    final isOnline = await syncRepo.isOnline;
    if (isOnline) {
      await refreshVehicles();
    } else {
      Get.snackbar('Offline', 'No internet connection. Showing locally stored vehicles.',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> loadMoreVehicles() async {
    if (!hasMore.value || isPageLoading.value) return;

    try {
      isPageLoading(true);
      currentPage++;

      // In a real app, you might fetch next page from API here
      // For now we'll just show more of the locally stored vehicles

      // Simulate pagination from local storage
      final startIndex = (currentPage.value - 1) * itemsPerPage;
      if (startIndex < allVehicles.length) {
        hasMore(startIndex + itemsPerPage < allVehicles.length);
      } else {
        hasMore(false);
      }
    } finally {
      isPageLoading(false);
    }
  }

  List<VehicleModel> get paginatedVehicles {
    final endIndex = currentPage.value * itemsPerPage;
    return filteredVehicles.take(endIndex).toList();
  }

  void filterVehicles(String query) {
    currentPage(1); // Reset to first page when filtering
    if (query.isEmpty) {
      filteredVehicles.assignAll(allVehicles);
    } else {
      filteredVehicles.assignAll(
        allVehicles.where((v) =>
            v.plateNumber.toLowerCase().contains(query.toLowerCase()) ||
            (v.status?.toLowerCase().contains(query.toLowerCase()) ?? false)),
      );
    }
    hasMore(filteredVehicles.length > itemsPerPage);
  }
}
