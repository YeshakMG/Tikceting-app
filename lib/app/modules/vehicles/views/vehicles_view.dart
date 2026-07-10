import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oro_ticket_app/app/modules/vehicles/controllers/vehicles_controllers.dart';
import 'package:oro_ticket_app/core/constants/colors.dart';
import 'package:oro_ticket_app/core/constants/typography.dart';
import 'package:oro_ticket_app/widgets/app_scafold.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:vs_scrollbar/vs_scrollbar.dart';

class VehiclesView extends StatelessWidget {
  final VehiclesController controller = Get.put(VehiclesController());
  final RefreshController _refreshController = RefreshController();
  final ScrollController _scrollController = ScrollController();

  VehiclesView({super.key}) {
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      controller.loadMoreVehicles();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Vehicles',
      userName: 'Employee',
      showBottomNavBar: true,
      currentBottomNavIndex: 0,
      actions: [
        Obx(
          () => controller.isSyncing.value
              ? const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.sync),
                  onPressed: () => controller.refreshVehiclesIfOnline(),
                  color: AppColors.background,
                ),
        ),
      ],
      body: Column(
        children: [
          Obx(
            () => Container(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.cardAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total vehicles',
                        style: AppTextStyles.buttonMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${controller.allVehicles.length}',
                        style: AppTextStyles.buttonMediumB.copyWith(fontSize: 20),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: controller.isConnected.value
                          ? Colors.green.shade100
                          : Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          controller.isConnected.value ? Icons.wifi : Icons.wifi_off,
                          size: 16,
                          color: controller.isConnected.value ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          controller.connectionStatus.value,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              onChanged: controller.filterVehicles,
              decoration: InputDecoration(
                hintText: 'Search by plate number or status',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.backgroundAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          // Vehicles list
          Obx(
            () {
              if (controller.isLoading.value && controller.allVehicles.isEmpty) {
                return const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (controller.errorMessage.isNotEmpty) {
                return Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        controller.errorMessage.value,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.buttonMedium
                            .copyWith(color: Colors.red),
                      ),
                    ),
                  ),
                );
              }

              return Expanded(
                child: SmartRefresher(
                  controller: _refreshController,
                  onRefresh: () async {
                    await controller.refreshVehicles();
                    _refreshController.refreshCompleted();
                  },
                  child: VsScrollbar(
                    controller: _scrollController,
                    showTrackOnHover: true,
                    isAlwaysShown: true,
                    scrollbarFadeDuration: const Duration(milliseconds: 500),
                    scrollbarTimeToFade: const Duration(milliseconds: 800),
                    style: VsScrollbarStyle(
                      hoverThickness: 2.0,
                      radius: const Radius.circular(8),
                      thickness: 4.0,
                      color: AppColors.primary.withValues(alpha: 0.05),
                    ),
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: controller.paginatedVehicles.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          // Header row with proper table structure
                          return Container(
                            color: AppColors.cardAlt,
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 16),
                            child: Table(
                              columnWidths: const {
                                0: FlexColumnWidth(2), // Plate Number - wider
                                1: FlexColumnWidth(1), // Level - medium
                                2: FlexColumnWidth(
                                    1.5), // Fleet Type - medium-wide
                              },
                              children: [
                                TableRow(
                                  children: [
                                    _buildHeaderCell("Plate Number"),
                                    _buildHeaderCell("Level", TextAlign.center),
                                    _buildHeaderCell(
                                        "Fleet Type", TextAlign.center),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }

                        final vehicle = controller.paginatedVehicles[index - 1];
                        final rowColor =
                            (index % 2 == 0) ? Colors.grey[100] : Colors.white;

                        return Container(
                          color: rowColor,
                          child: ExpansionTile(
                            tilePadding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            title: Table(
                              columnWidths: const {
                                0: FlexColumnWidth(2), // Plate Number
                                1: FlexColumnWidth(1), // Level
                                2: FlexColumnWidth(1.5), // Fleet Type
                              },
                              children: [
                                TableRow(
                                  children: [
                                    // Plate Number cell
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8.0),
                                      child: Text(
                                        "${vehicle.plateRegion}${vehicle.plateNumber}",
                                        style: AppTextStyles.buttonMediumB,
                                      ),
                                    ),
                                    // Level cell
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8.0),
                                      child: Text(
                                        vehicle.vehicleLevel,
                                        textAlign: TextAlign.center,
                                        style: AppTextStyles.body2,
                                      ),
                                    ),
                                    // Fleet Type cell
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8.0),
                                      child: Text(
                                        vehicle.fleetType,
                                        textAlign: TextAlign.center,
                                        style: AppTextStyles.buttonMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 8.0),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    "Seat Capacity: ${vehicle.seatCapacity}",
                                    style: AppTextStyles.caption3,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 8.0),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    children: [
                                      const Text(
                                        "Status: ",
                                        style: AppTextStyles.caption3,
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: (vehicle.status == "active")
                                              ? Colors.green
                                              : Colors.grey,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          vehicle.status,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, [TextAlign? textAlign]) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Text(
        text,
        style: AppTextStyles.buttonMedium.copyWith(
          fontWeight: FontWeight.w500,
        ),
        textAlign: textAlign ?? TextAlign.start,
      ),
    );
  }
}