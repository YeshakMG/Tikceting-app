// tariff_view.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oro_ticket_app/widgets/app_scafold.dart';
import '../controller/tarrif_controller.dart';

class TariffView extends StatelessWidget {
  final TariffController controller = Get.put(TariffController());

  TariffView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Tariff Management',
      userName: '',
      currentBottomNavIndex: 0,
      actions: const [
        Icon(Icons.more_horiz, color: Colors.white),
        SizedBox(width: 16),
      ],
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Obx(() => DropdownButton<String>(
                  value: controller.selectedArrival.value.isEmpty
                      ? null
                      : controller.selectedArrival.value,
                  hint: Text('Select Arrival'),
                  onChanged: (value) {
                    if (value != null) controller.filterTariffs(value);
                  },
                  items: controller.arrivals
                      .map((arrival) => DropdownMenuItem(
                            value: arrival,
                            child: Text(arrival),
                          ))
                      .toList(),
                )),
            SizedBox(height: 20),
            Obx(() => Expanded(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Level')),
                      DataColumn(label: Text('Fleet Category')),
                      DataColumn(label: Text('Price')),
                    ],
                    rows: controller.filteredTariffs
                        .map((tariff) => DataRow(cells: [
                              DataCell(Text(tariff['level'] ?? '')),
                              DataCell(Text(tariff['fleet_category'] ?? '')),
                              DataCell(Text('${tariff['price']}')),
                            ]))
                        .toList(),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}