import 'package:bubble_chart/bubble_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:handy_extensions/handy_extensions.dart';
import 'package:oro_ticket_app/app/modules/home/controllers/home_controller.dart';
import 'package:oro_ticket_app/core/constants/app_graphs.dart';
import 'package:oro_ticket_app/core/constants/colors.dart';
import 'package:oro_ticket_app/core/constants/typography.dart';
import 'package:oro_ticket_app/data/locals/service/trip_storage_service.dart';
import 'package:oro_ticket_app/data/locals/service/vehicle_storage_service.dart';

class DashboardCard extends StatefulWidget {
  final HomeController controller = Get.put(HomeController());
  DashboardCard({super.key});

  @override
  State<DashboardCard> createState() => _DashboardCardState();
}

class _DashboardCardState extends State<DashboardCard> {
  final DashboardController controller = Get.put(DashboardController());
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final tickets = controller.ticketsSoldToday.value;
      final revenue = controller.revenueToday.value;
      final growth = controller.dailyGrowth.value;
      final serviceCharge = controller.totalServiceCharge * tickets;
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 2),
            )
          ],
        ),
        child: Row(
          children: [
            // Left side (text content)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Daily Revenue", style: AppTextStyles.subtitle2),
                  SizedBox(height: 8),
                  Text(
                      "${revenue.toStringAsFixed(1).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} ETB",
                      style: AppTextStyles.displayMedium),
                  SizedBox(height: 4),
                  Text(
                      "You have sold ${tickets.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} tickets today",
                      style: AppTextStyles.caption),
                ],
              ),
            ),
            // Right side (bubble chart)
            SizedBox(
              width: 130,
              height: 130,
              child: AppGraphs.defaultChartLayout(
                children: [
                  BubbleNode.leaf(
                    value: 50,
                    options: BubbleOptions(
                      child: Text("1%", style: AppTextStyles.buttonSmall),
                      color: Colors.lightGreen,
                    ),
                  ),
                  BubbleNode.leaf(
                    value: 30,
                    options: BubbleOptions(
                      child: Text(serviceCharge.toStringAsFixed(0),
                          style: AppTextStyles.buttonSmall),
                      color: AppColors.success,
                    ), //no of vehicles
                  ),
                  BubbleNode.leaf(
                    value: 20,
                    options: BubbleOptions(
                      child: Text("${tickets.toInt()}",
                          style: AppTextStyles.buttonSmall),
                      color: AppColors.bottomNavUnselected,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class DashboardController extends GetxController {
  var ticketsSoldToday = 0.obs;
  var revenueToday = 0.0.obs;
  var dailyGrowth = 0.0.obs;
  var totalServiceCharge = 0.0.obs;
  var numberofVehicles = 0.obs;

  final TripStorageService tripStorageService = TripStorageService();
  final VehicleStorageService vehicleStorageService = VehicleStorageService();

  @override
  void onInit() {
    super.onInit();
    loadDashboardData();
  }

  void loadDashboardData() {
    final trips = tripStorageService.getAllTrips();

    final today = DateTime.now();
    final todayTrips = trips.where((trip) {
      print("Trip ID: ${trip.arrivalName}, Vehicle ID: ${trip.vehicleId}");
      return trip.dateAndTime.isSameDay(today);
    }).toList();

    int totalSeatsSold = 0;
    double totalRevenue = 0.0;
    for (var trip in todayTrips) {
      final vehicle = vehicleStorageService.getVehicleSeatCount(trip.vehicleId);
      if (vehicle != null) {
        print("Info: $vehicle."); // This is always null
        totalSeatsSold += vehicle;
        ticketsSoldToday.value = totalSeatsSold;
        totalRevenue += trip.totalPaid * vehicle;
      }
    }
    // ticketsSoldToday.value = todayTrips.length;
    totalServiceCharge.value = todayTrips.fold(
      0.0,
      (sum, trips) => sum + trips.serviceCharge,
    );

    revenueToday.value = totalRevenue;
    // todayTrips.fold(
    //   0.0,
    //   (sum, trip) => sum + trip.totalPaid,
    // );
  }
}
