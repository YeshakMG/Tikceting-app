import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oro_ticket_app/core/constants/colors.dart';
import 'package:oro_ticket_app/core/constants/typography.dart';
import 'package:oro_ticket_app/widgets/app_scafold.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:vs_scrollbar/vs_scrollbar.dart';
import '../controllers/arrival_controllers.dart';

class ArrivalLocationView extends StatelessWidget {
  final ArrivalLocationController controller =
      Get.put(ArrivalLocationController());
  final RefreshController _refreshController = RefreshController();

  ArrivalLocationView({super.key});

  @override
  Widget build(BuildContext context) {
    final ScrollController _scrollController = ScrollController();
    return AppScaffold(
      title: "Arrival Locations",
      userName: "Employee Name",
      actions: [
        IconButton(
          icon: const Icon(Icons.more_horiz),
          onPressed: () => controller.syncLocations(),
          color: Colors.white,
        ),
      ],
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              onChanged: controller.filterLocations,
              decoration: InputDecoration(
                hintText: 'Search',
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

          // Locations list with pull-to-refresh
          Expanded(
            child: Obx(() {
              return SmartRefresher(
                controller: _refreshController,
                onRefresh: () async {
                  await controller.syncLocations();
                  _refreshController.refreshCompleted();
                },
                child: VsScrollbar(
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
                  child: ListView(
                    controller: _scrollController,
                    children: [
                      // Full-width header row
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
                        color: AppColors.cardAlt,
                        child: const Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Name',
                                style: AppTextStyles.buttonMediumB,
                                textAlign: TextAlign.left,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Distance',
                                style: AppTextStyles.buttonMediumB,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Road Type',
                                style: AppTextStyles.buttonMediumB,
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Data rows with alternating colors
                      ...controller.filteredLocations
                          .asMap()
                          .entries
                          .map((entry) {
                        final index = entry.key;
                        final terminal = entry.value;
                        final rowColor = index.isEven
                            ? AppColors.card
                            : AppColors.backgroundAlt;

                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                          color: rowColor,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  terminal.name,
                                  style: AppTextStyles.buttonMedium,
                                  textAlign: TextAlign.left,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '${terminal.distance.toStringAsFixed(1)} km',
                                  style: AppTextStyles.buttonMedium,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  terminal.roadType ?? '',
                                  style: AppTextStyles.buttonMedium,
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
