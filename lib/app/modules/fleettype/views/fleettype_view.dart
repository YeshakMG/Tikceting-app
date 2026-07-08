import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oro_ticket_app/widgets/app_scafold.dart';
import '../controllers/fleettype_controllers.dart';
import 'package:oro_ticket_app/core/constants/colors.dart';

class FleetTypeView extends StatelessWidget {
  const FleetTypeView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<FleetTypeController>();

    return AppScaffold(
      title: 'Fleet Type',
      userName: 'Employee Name',
      showBottomNavBar: true,
      actions: const [
        Icon(Icons.more_horiz, color: Colors.white),
        SizedBox(width: 16),
      ],
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Filter & Search Bar
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.filter_alt_outlined),
                  label: const Text('Filter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cardAlt,
                    foregroundColor: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    onChanged: controller.filterFleetType,
                    decoration: const InputDecoration(
                      hintText: 'Search',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Table Header
            Container(
              color: AppColors.backgroundAlt,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: Row(
                children: const [
                  Expanded(flex: 2, child: Text('Name')),
                  Expanded(flex: 2, child: Text('Level')),
                  Expanded(flex: 1, child: Text('Total seat')),
                ],
              ),
            ),
            // Table Data
            Expanded(
              child: Obx(() => ListView.builder(
                    itemCount: controller.fleetTypes.length,
                    itemBuilder: (_, index) {
                      final item = controller.fleetTypes[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: AppColors.divider),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(flex: 2, child: Text(item['name'] ?? '')),
                            Expanded(flex: 2, child: Text(item['level'] ?? '')),
                            Expanded(
                                flex: 1,
                                child: Text(item['totalSeat'].toString())),
                          ],
                        ),
                      );
                    },
                  )),
            ),
          ],
        ),
      ),
    );
  }
}
