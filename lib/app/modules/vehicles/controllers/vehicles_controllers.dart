import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:oro_ticket_app/data/locals/models/vehicle_model.dart';
import 'package:oro_ticket_app/data/repositories/sync_repository.dart';

class VehiclesController extends GetxController {
  final SyncRepository syncRepo = Get.find<SyncRepository>();
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  RxList<VehicleModel> allVehicles = <VehicleModel>[].obs;
  RxList<VehicleModel> filteredVehicles = <VehicleModel>[].obs;
  RxBool isLoading = false.obs;
  RxBool isSyncing = false.obs;
  RxString errorMessage = ''.obs;
  RxBool isConnected = false.obs;
  RxString connectionStatus = 'Checking connection...'.obs;

  // Pagination controls
  final int itemsPerPage = 10;
  RxInt currentPage = 1.obs;
  RxBool hasMore = true.obs;
  RxBool isPageLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    _listenToConnectivity();
    loadInitialVehicles();
    syncRepo.vehicleChanges.listen((_) => loadLocalVehicles());
  }

  @override
  void onClose() {
    _connectivitySubscription?.cancel();
    super.onClose();
  }

  Future<void> _listenToConnectivity() async {
    await updateConnectionStatus();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((_) async {
      await updateConnectionStatus();
      if (isConnected.value) {
        await loadInitialVehicles();
      }
    });
  }

  Future<void> updateConnectionStatus() async {
    try {
      final connectivityResults = await _connectivity.checkConnectivity();
      final hasNetwork = connectivityResults.any((result) => result != ConnectivityResult.none);

      if (!hasNetwork) {
        isConnected(false);
        connectionStatus('Offline');
        return;
      }

      final results = await InternetAddress.lookup('example.com');
      final hasInternet = results.isNotEmpty && results.first.rawAddress.isNotEmpty;
      isConnected(hasInternet);
      connectionStatus(hasInternet ? 'Online' : 'Offline');
    } catch (_) {
      isConnected(false);
      connectionStatus('Offline');
    }
  }

  Future<void> loadInitialVehicles() async {
    try {
      isLoading(true);
      errorMessage('');

      await updateConnectionStatus();
      await loadLocalVehicles();

      if (isConnected.value) {
        await syncRepo.syncAllCompanyUserVehicles(forceSync: true);
        await loadLocalVehicles();
      } else if (allVehicles.isEmpty) {
        errorMessage('No vehicles found (offline mode)');
      }
    } catch (e) {
      if (allVehicles.isEmpty) {
        errorMessage('Failed to load vehicles. Please check your internet connection and try again.');
      }
    } finally {
      isLoading(false);
    }
  }

  Future<void> loadLocalVehicles() async {
    final vehicles = await syncRepo.getVehicles();
    allVehicles.assignAll(vehicles);
    filteredVehicles.assignAll(vehicles);
    currentPage(1);
    hasMore(allVehicles.length > itemsPerPage);
  }

  Future<void> refreshVehicles() async {
    try {
      isSyncing(true);
      errorMessage('');
      await updateConnectionStatus();

      if (!isConnected.value) {
        Get.snackbar(
          'Offline',
          'No internet connection. Showing locally stored vehicles.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      await syncRepo.syncAllCompanyUserVehicles(forceSync: true);
      await loadLocalVehicles();
    } catch (e) {
      if (allVehicles.isEmpty) {
        errorMessage('Unable to sync vehicles. Please check your internet connection and try again.');
      } else {
        Get.snackbar('Sync issue', 'Showing locally stored vehicles', snackPosition: SnackPosition.BOTTOM);
      }
    } finally {
      isSyncing(false);
    }
  }

  Future<void> refreshVehiclesIfOnline() async {
    await updateConnectionStatus();
    if (isConnected.value) {
      await refreshVehicles();
    } else {
      Get.snackbar(
        'Offline',
        'No internet connection. Showing locally stored vehicles.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> loadMoreVehicles() async {
    if (!hasMore.value || isPageLoading.value) return;

    try {
      isPageLoading(true);
      currentPage++;

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
    currentPage(1);
    if (query.isEmpty) {
      filteredVehicles.assignAll(allVehicles);
    } else {
      filteredVehicles.assignAll(
        allVehicles.where((vehicle) =>
            vehicle.plateNumber.toLowerCase().contains(query.toLowerCase()) ||
            vehicle.status.toLowerCase().contains(query.toLowerCase())),
      );
    }
    hasMore(filteredVehicles.length > itemsPerPage);
  }
}
