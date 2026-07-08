import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oro_ticket_app/app/modules/departure/controllers/departure_controllers.dart';
import 'package:oro_ticket_app/core/constants/colors.dart';
import 'package:oro_ticket_app/core/constants/typography.dart';
import 'package:oro_ticket_app/widgets/app_scafold.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class DepartureView extends GetView<DepartureControllers> {
  final DepartureControllers controller = Get.put(DepartureControllers());
  final RefreshController _refreshController = RefreshController();

  DepartureView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Departure',
      userName: 'Employee Name',
      showBottomNavBar: true,
      actions: [
        IconButton(
            onPressed: () {},
            icon: Icon(
              Icons.more_horiz,
              color: AppColors.background,
            ))
      ],
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: Obx(() {
                final terminal = controller.terminal.value;

                return SmartRefresher(
                  controller: _refreshController,
                  onRefresh: () async {
                    controller.loadTerminal();
                    _refreshController.refreshCompleted();
                  },
                  child: terminal == null
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 120),
                            Center(child: Text('No terminal found')),
                          ],
                        )
                      : ListView(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 16),
                              color: AppColors.cardAlt,
                              child: const Text(
                                'Departure Terminal Name',
                                style: AppTextStyles.buttonMedium,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 16),
                              color: AppColors.card,
                              child: Text(
                                terminal.name,
                                style: AppTextStyles.buttonMedium,
                              ),
                            ),
                          ],
                        ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
