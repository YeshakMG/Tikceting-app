import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:oro_ticket_app/app/modules/arrivals/views/arrival_view.dart';
import 'package:oro_ticket_app/app/modules/departure/view/departure_view.dart';
import 'package:oro_ticket_app/app/modules/home/controllers/home_controller.dart';
import 'package:oro_ticket_app/app/modules/localReport/view/local_report_view.dart';
import 'package:oro_ticket_app/app/modules/sign_in/services/auth_service.dart';
import 'package:oro_ticket_app/app/modules/ticket/view/ticket_view.dart';
import 'package:oro_ticket_app/app/modules/vehicles/views/vehicles_view.dart';
import 'package:oro_ticket_app/app/routes/app_pages.dart';
import 'package:oro_ticket_app/core/constants/colors.dart';
import 'package:oro_ticket_app/core/constants/typography.dart';
import 'package:oro_ticket_app/widgets/bottom_navbar.dart';
import 'package:oro_ticket_app/widgets/custom_drawer.dart';

class AppScaffold extends StatefulWidget {
  final String title;
  final Widget? titleWidget;
  final Widget body;
  final List<Widget>? actions;
  final bool showBottomNavBar;
  final String userName;
  final int currentBottomNavIndex;
  final Function(int)? onBottomNavTap;

  const AppScaffold({
    super.key,
    required this.title,
    this.titleWidget,
    required this.body,
    this.actions,
    this.showBottomNavBar = true,
    required this.userName,
    this.currentBottomNavIndex = 0,
    this.onBottomNavTap,
  });

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  final homeController = Get.find<HomeController>();

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: AppColors.primary,
    ));

    return Obx(() {
      final user = homeController.user.value;
      final companyName = homeController.companyName.value;

      return Scaffold(
        drawer: CustomDrawer(
          userName: user?.fullName ?? 'Employee',
          companyLogoUrl: homeController.companyLogoUrl.value,
          companyName: companyName,
          onItemSelected: (item) async {
            switch (item) {
              case 'Vehicles':
                Get.toNamed(Routes.VEHICLES);
                break;
              // case 'Vehicle categories':
              //   Get.toNamed('/fleet-type');
              //   break;
              case 'Terminal Name':
                Get.toNamed(Routes.DEPARTURE);
                break;
              case 'Arrival Terminal':
                Get.toNamed(Routes.ARRIVALS);
                break;
              // case 'Tariff':
              //   Get.to(TariffView());
              //   break;
              case 'Change Password':
                Get.toNamed(Routes.CHANGE_PASSWORD);
                break;
              case 'Logout':
                confirmLogout();
                break;
            }
          },
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                color: AppColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Builder(
                      builder: (context) => IconButton(
                        icon: const Icon(Icons.menu, color: Colors.white),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                    ),
                    Expanded(
                      child: widget.titleWidget != null
                          ? widget.titleWidget!
                          : Text(widget.title, style: AppTextStyles.subtitle1),
                    ),
                    Row(children: widget.actions ?? []),
                  ],
                ),
              ),
              Expanded(child: widget.body),
            ],
          ),
        ),
        bottomNavigationBar: widget.showBottomNavBar
            ? BottomNavBar(
                currentIndex: widget.currentBottomNavIndex,
                onTap: widget.onBottomNavTap ??
                    (index) {
                      switch (index) {
                        case 0:
                          Get.offAllNamed('/home');
                          break;
                        case 1:
                          Get.to(TicketView());
                          break;
                        case 2:
                          Get.to(LocalReportView());
                          break;
                      }
                    },
              )
            : null,
      );
    });
  }
}

Future<void> confirmLogout() async {
  final authService = Get.find<AuthService>();
  final isLoading = false.obs;
  final Rx<String?> errorMessage = Rx<String?>(null);

  // Close snackbars to keep UI clean
  Get.closeAllSnackbars();

  await Get.dialog<bool>(
    Obx(() => AlertDialog(
          title: Text(
            'Confirm Logout',
            style: AppTextStyles.buttonMediumB.copyWith(
              fontSize: 14,
              color: Colors.red,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading.value) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Processing logout...',
                    style: AppTextStyles.buttonMediumB.copyWith(
                      fontSize: 12,
                      color: AppColors.bottomNavUnselected,
                    )),
              ] else if (errorMessage.value != null) ...[
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.orange, size: 48),
                const SizedBox(height: 16),
                Text(
                  errorMessage.value!,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption,
                ),
              ] else ...[
                Text('Are you sure you want to logout?',
                    style: AppTextStyles.body1.copyWith(
                      fontSize: 10,
                      color: AppColors.body,
                    )),
              ],
            ],
          ),
          actions: isLoading.value
              ? []
              : errorMessage.value != null
                  ? [
                      TextButton(
                        onPressed: () => Get.back(),
                        child: const Text('OK'),
                      ),
                    ]
                  : [
                      TextButton(
                        onPressed: () => Navigator.of(Get.context!).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () async {
                          isLoading.value = true;
                          errorMessage.value = null;

                          final success = await authService.logout();

                          if (!success) {
                            isLoading.value = false;
                            // Logic to check which one failed for a better message
                            errorMessage.value =
                                "Unsynced data detected. Please sync your Trips and Service Charges before logging out.";
                          }
                          // If success, AuthService.logout() handles navigation
                        },
                        child: const Text('Logout',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
        )),
  );
}
