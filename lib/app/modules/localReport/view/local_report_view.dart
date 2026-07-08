import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oro_ticket_app/core/constants/colors.dart';
import 'package:oro_ticket_app/core/constants/typography.dart';
import 'package:oro_ticket_app/widgets/app_scafold.dart';
import 'package:vs_scrollbar/vs_scrollbar.dart';

import '../controller/local_report_controller.dart';

class LocalReportView extends StatelessWidget {
  final LocalReportController controller = Get.put(LocalReportController());

  LocalReportView({super.key});

  @override
  Widget build(BuildContext context) {
    final ScrollController _scrollController = ScrollController();
    return AppScaffold(
      title: 'Local Report',
      userName: 'Employee Name',
      currentBottomNavIndex: 2,
      body: Column(
        children: [
          // 🔍 Full-width search bar
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: controller.searchTrips,
                    decoration: InputDecoration(
                      hintText: 'Search trips',
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
              ],
            ),
          ),

          // Pull-to-refresh wrapper
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await controller.loadTripsFromHive();
                Get.snackbar("Refreshed", "Trip data reloaded");
              },
              child: Obx(() {
                if (controller.filteredTrips.isEmpty) {
                  return const Center(child: Text("No trips available"));
                }

                return VsScrollbar(
                  controller: _scrollController,
                  showTrackOnHover: true,
                  isAlwaysShown: true,
                  scrollbarFadeDuration: Duration(milliseconds: 500),
                  scrollbarTimeToFade: Duration(milliseconds: 800),
                  style: VsScrollbarStyle(
                    hoverThickness: 2.0,
                    radius: Radius.circular(8),
                    thickness: 4.0,
                    color: AppColors.primary.withValues(alpha: 0.05),
                  ),
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: controller.filteredTrips.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        // Header row
                        return Container(
                          color: AppColors.cardAlt,
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Plate",
                                  style: AppTextStyles.buttonMedium,
                                  textAlign: TextAlign.center),
                              Text(
                                "Route",
                                style: AppTextStyles.buttonMedium,
                                textAlign: TextAlign.center,
                              ),
                              Text("Total Price",
                                  style: AppTextStyles.buttonMedium,
                                  textAlign: TextAlign.center),
                            ],
                          ),
                        );
                      }

                      final trip = controller.filteredTrips[index - 1];
                      final plate = "${trip.plateRegion}${trip.plateNumber}";

                      // alternate row color
                      final rowColor =
                          (index % 2 == 0) ? Colors.grey[100] : Colors.white;

                      return Container(
                        color: rowColor,
                        child: ExpansionTile(
                          tilePadding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          title: Row(
                            children: [
                              // Plate
                              Expanded(
                                  child: Text(
                                plate,
                                style: AppTextStyles.caption3,
                              )),

                              // Route styled with down arrow
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      textAlign: TextAlign.center,
                                      trip.departureName,
                                      style: AppTextStyles.caption3,
                                    ),
                                    const Icon(
                                      Icons.arrow_downward,
                                      size: 16,
                                      color: AppColors.primary,
                                    ),
                                    Text(
                                      textAlign: TextAlign.center,
                                      trip.arrivalName,
                                      style: AppTextStyles.caption3,
                                    ),
                                  ],
                                ),
                              ),

                              // Total Price
                              Expanded(
                                child: Text(
                                  trip.totalPrice.toStringAsFixed(2),
                                  textAlign: TextAlign.right,
                                  style: AppTextStyles.buttonMedium,
                                ),
                              ),
                            ],
                          ),
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 3),
                                child: Text(
                                    "Association: ${trip.associationName}",
                                    style: AppTextStyles.caption3),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 3),
                                child: Text("Level: ${trip.vehicleLevel}",
                                    style: AppTextStyles.caption3),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 3),
                                child: Text(
                                    "Price: ${trip.price.toStringAsFixed(2)}",
                                    style: AppTextStyles.caption3),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 3),
                                child: Text(
                                    "Service Charge: ${trip.serviceCharge.toStringAsFixed(2)}",
                                    style: AppTextStyles.caption3),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              }),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.download,
            color: AppColors.background,
          ),
          onPressed: () => controller.generatePDFReport(),
        ),
      ],
    );
  }
}
