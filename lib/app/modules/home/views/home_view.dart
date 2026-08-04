import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import 'package:oro_ticket_app/app/modules/home/controllers/home_controller.dart';
import 'package:oro_ticket_app/app/modules/sync/view/sync_view.dart';
import 'package:oro_ticket_app/core/constants/colors.dart';
import 'package:oro_ticket_app/core/constants/typography.dart';
import 'package:oro_ticket_app/data/locals/models/service_charge_model.dart';
import 'package:oro_ticket_app/data/locals/hive_boxes.dart';
import 'package:oro_ticket_app/widgets/app_scafold.dart';
import 'package:oro_ticket_app/widgets/daily_info_tile.dart';
import 'package:oro_ticket_app/widgets/dashboard_card.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final HomeController homeController = Get.put(HomeController());
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isConnected = false;
  String _connectionStatus = 'Checking connection...';

  void _closeActiveDialog() {
    final overlayContext = Get.overlayContext;
    if (overlayContext == null) return;
    final navigator = Navigator.of(overlayContext, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  @override
  void initState() {
    super.initState();
    _listenToConnectivity();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _listenToConnectivity() async {
    await _updateConnectionStatus();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((_) async {
      await _updateConnectionStatus();
    });
  }

  Future<void> _updateConnectionStatus() async {
    try {
      final connectivityResults = await _connectivity.checkConnectivity();
      final hasNetwork = connectivityResults.any((result) => result != ConnectivityResult.none);

      if (!hasNetwork) {
        setState(() {
          _isConnected = false;
          _connectionStatus = 'Offline';
        });
        return;
      }

      final results = await InternetAddress.lookup('example.com');
      final hasInternet = results.isNotEmpty && results.first.rawAddress.isNotEmpty;
      setState(() {
        _isConnected = hasInternet;
        _connectionStatus = hasInternet ? 'Online' : 'Offline';
      });
    } catch (_) {
      setState(() {
        _isConnected = false;
        _connectionStatus = 'Offline';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final user = homeController.user.value;
      final companyName = homeController.companyName.value;

      return PopScope(
        child: AppScaffold(
          title: 'Oromia Transport Agency',
          titleWidget: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Oromia Transport Agency',
                style: AppTextStyles.subtitle1,
              ),
              const SizedBox(width: 8),
              Container(
                height: 28,
                width: 28,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(4),
                child: ClipOval(
                  child: Image.asset(
                    'assets/logo/OTA_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
          userName: user?.fullName ?? 'Employee',
          body: SingleChildScrollView(
            child: Column(
              children: [
                // Header
                Container(
                  color: AppColors.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 👇 THIS IS THE FIX
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              companyName.isNotEmpty
                                  ? companyName
                                  : 'Unknown Company',
                              style: AppTextStyles.subtitle1
                                  .copyWith(color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user?.fullName ?? 'Employee Name',
                              style: AppTextStyles.buttonMedium
                                  .copyWith(color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _isConnected
                                  ? Colors.green.shade100
                                  : Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _isConnected ? Icons.wifi : Icons.wifi_off,
                                  size: 16,
                                  color: _isConnected
                                      ? Colors.green.shade700
                                      : Colors.orange.shade700,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _connectionStatus,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  Get.to(() => SyncView());
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withOpacity(0.3),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  textStyle: AppTextStyles.button,
                                ),
                                child: const Text(
                                'Trip list',
                                style: TextStyle(fontSize: 12),
                              ),
                              ),
                              IconButton(
                                onPressed: () async {
                                  Get.snackbar(
                                    'Syncing',
                                    'Please wait...',
                                    snackPosition: SnackPosition.BOTTOM,
                                    backgroundColor: Colors.blueGrey,
                                    colorText: Colors.white,
                                    showProgressIndicator: true,
                                    isDismissible: false,
                                  );

                                  try {
                                    await homeController.syncTrips();
                                    Get.closeCurrentSnackbar();
                                    Get.snackbar(
                                      'Success',
                                      'Synced Successfully!',
                                      snackPosition: SnackPosition.BOTTOM,
                                      backgroundColor: AppColors.primaryHover,
                                      colorText: AppColors.background,
                                    );
                                  } catch (e) {
                                    Get.closeCurrentSnackbar();
                                    Get.snackbar(
                                      'Error',
                                      e.toString(),
                                      snackPosition: SnackPosition.BOTTOM,
                                      backgroundColor: Colors.red,
                                      colorText: Colors.white,
                                    );
                                  }
                                },
                                icon: const Icon(Icons.sync, color: Colors.white),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Dashboard Metrics
                DashboardCard(),
                const SizedBox(height: 16),

                // Daily Info Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Daily Information",
                          style: AppTextStyles.heading3),
                      const SizedBox(height: 12),
                      Obx(() => DailyInfoTile(
                            icon: Icons.credit_card_rounded,
                            label: "Total Service Charge",
                            value:
                                "${homeController.serviceChargeToday.value.toStringAsFixed(2)} ETB",
                            onRefresh: () async {
                              await homeController.loadTodayServiceCharge();
                              Get.snackbar(
                                'Refreshed',
                                'Service charge updated',
                                snackPosition: SnackPosition.BOTTOM,
                                backgroundColor: AppColors.primaryHover,
                                colorText: AppColors.background,
                              );
                            },
                          )),
                      const SizedBox(height: 10),
                      Obx(() => DailyInfoTile(
                            icon: Icons.calendar_month_sharp,
                            label: "Date",
                            value: homeController.ethiopianDate.value,
                          )),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Reset Dashboard Button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final isSyncing = false.obs;
                        final showMessage = false.obs;
                        String message = '';

                        Get.dialog(
                          Obx(() => AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                title: Text(
                                  "Reset Dashboard",
                                  style: AppTextStyles.subtitle1
                                      .copyWith(color: AppColors.body),
                                  textAlign: TextAlign.center,
                                ),
                                content: isSyncing.value
                                    ? const Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircularProgressIndicator(),
                                          SizedBox(height: 16),
                                          Text('Syncing service charges...'),
                                        ],
                                      )
                                    : showMessage.value
                                        ? Text(
                                            message,
                                            style: AppTextStyles.caption2
                                                .copyWith(fontSize: 12),
                                          )
                                        : Text(
                                            "Do you want to sync service charges before resetting?",
                                            style: AppTextStyles.caption2
                                                .copyWith(fontSize: 12),
                                          ),
                                actions: isSyncing.value
                                    ? null // No actions during sync
                                    : showMessage.value
                                        ? [
                                            TextButton(
                                              onPressed: () {
                                                print('Message acknowledged');
                                                _closeActiveDialog();
                                              },
                                              child: Text(
                                                'OK',
                                                style: AppTextStyles
                                                    .buttonMediumB
                                                    .copyWith(fontSize: 12),
                                              ),
                                            ),
                                          ]
                                        : [
                                            TextButton(
                                              onPressed: () {
                                                print('Cancel clicked');
                                                _closeActiveDialog();
                                              },
                                              child: Text(
                                                'No',
                                                style: AppTextStyles
                                                    .buttonMediumB
                                                    .copyWith(fontSize: 12),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () async {
                                                print('Confirm clicked');

                                                // Check if there are service charges to sync
                                                final box = Hive.box<
                                                        ServiceChargeModel>(
                                                    HiveBoxes.serviceChargeBox);
                                                if (box.isEmpty) {
                                                  print(
                                                      'No service charges found');
                                                  // Show message in dialog for 3 seconds
                                                  message =
                                                      'No service charges to sync';
                                                  showMessage.value = true;

                                                  // Auto-close after 3 seconds
                                                  Future.delayed(
                                                      const Duration(
                                                          seconds: 3), () {
                                                    if (Get.isDialogOpen ??
                                                        false) {
                                                      _closeActiveDialog();
                                                    }
                                                  });
                                                  return;
                                                }

                                                print('Starting sync...');
                                                isSyncing.value = true;

                                                try {
                                                  final syncResult =
                                                      await homeController
                                                      .syncServiceCharge();

                                                  if (!syncResult.success) {
                                                    message =
                                                        '${syncResult.message}\nDashboard was not reset.';
                                                    showMessage.value = true;
                                                    isSyncing.value = false;
                                                    return;
                                                  }

                                                  // If sync successful → reset dashboard
                                                  homeController
                                                      .resetDashboard();

                                                  // Show success message in dialog for 3 seconds
                                                  message =
                                                      'Service charge synced and dashboard reset successfully';
                                                  showMessage.value = true;
                                                  isSyncing.value = false;

                                                  // Auto-close after 3 seconds
                                                  Future.delayed(
                                                      const Duration(
                                                          seconds: 3), () {
                                                    if (Get.isDialogOpen ??
                                                        false) {
                                                      _closeActiveDialog();
                                                    }
                                                  });
                                                } catch (e) {
                                                  print('Sync failed: $e');
                                                  isSyncing.value =
                                                      false; // Reset loading state

                                                  // Show error but keep dialog open for retry
                                                   Get.snackbar(
                                                     'Error',
                                                     'Failed to sync. Please try again.',
                                                     snackPosition:
                                                         SnackPosition.BOTTOM,
                                                     backgroundColor: Colors.red,
                                                     colorText: Colors.white,
                                                   );
                                                }
                                              },
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.white,
                                              ),
                                              child: Text(
                                                'Yes',
                                                style: AppTextStyles
                                                    .buttonMediumB
                                                    .copyWith(
                                                        fontSize: 12,
                                                        color: AppColors
                                                            .primaryHover),
                                              ),
                                            ),
                                          ],
                              )),
                          barrierDismissible:
                              !isSyncing.value && !showMessage.value,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        "Reset Dashboard",
                        style: AppTextStyles.button,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
