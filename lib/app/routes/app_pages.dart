import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oro_ticket_app/app/modules/departure/bindings/departure_bindings.dart';
import 'package:oro_ticket_app/app/modules/departure/view/departure_view.dart';
import 'package:oro_ticket_app/app/modules/localReport/bindings/local_report_binding.dart';
import 'package:oro_ticket_app/app/modules/localReport/view/local_report_view.dart';
import 'package:oro_ticket_app/app/modules/sync/binding/sync_binding.dart';
import 'package:oro_ticket_app/app/modules/sync/view/sync_view.dart';
import 'package:oro_ticket_app/app/modules/ticket/binding/ticket_binding.dart';
import 'package:oro_ticket_app/app/modules/ticket/view/ticket_view.dart';

import '../modules/arrivals/bindings/arrival_bindings.dart';
import '../modules/arrivals/views/arrival_view.dart';
import '../modules/fleettype/bindings/fleettype_bindings.dart';
import '../modules/fleettype/views/fleettype_view.dart';
import '../modules/home/bindings/home_binding.dart';
import '../modules/home/views/home_view.dart';
import '../modules/session-check/bindings/session_check_binding.dart';
import '../modules/session-check/views/session_check_view.dart';
import '../modules/sign_in/bindings/sign_in_binding.dart';
import '../modules/sign_in/views/sign_in_view.dart';
import '../modules/splash_screen/bindings/splash_screen_binding.dart';
import '../modules/splash_screen/views/splash_screen_view.dart';
import '../modules/vehicles/bindings/vehicles_bindings.dart';
import '../modules/vehicles/views/vehicles_view.dart';
import '../modules/reset_password/binding/reset_password_binding.dart';
import '../modules/reset_password/view/reset_password_view.dart';
import '../modules/change_password/binding/change_password_binding.dart';
import '../modules/change_password/view/change_password_view.dart';


part 'app_routes.dart';

class AppPages {
  AppPages._();

  // static const INITIAL = Routes.HOME;
  static const INITIAL = Routes.SESSION_CHECK;

  static final routes = [
    GetPage(
      name: _Paths.SPLASH_SCREEN,
      page: () => SplashScreenView(),
      binding: SplashScreenBinding(),
    ),
    GetPage(
      name: _Paths.SIGN_IN,
      page: () => SignInView(),
      binding: SignInBinding(),
    ),
    GetPage(
      name: _Paths.HOME,
      page: () => HomeView(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: _Paths.VEHICLES,
      page: () => VehiclesView(),
      binding: VehiclesBindings(),
    ),
    GetPage(
      name: _Paths.FLEET_TYPE,
      page: () => FleetTypeView(),
      binding: FleetTypeBindings(),
    ),
    GetPage(
      name: _Paths.DEPARTURE,
      page: () => DepartureView(),
      binding: DepartureBindings(),
    ),
    GetPage(
      name: _Paths.SESSION_CHECK,
      page: () => const SessionCheckView(),
      binding: SessionCheckBinding(),
    ),
    GetPage(
      name: _Paths.ARRIVALS,
      page: () => ArrivalLocationView(),
      binding: ArrivalLocationBinding(),
    ),
    GetPage(
      name: _Paths.TICKET,
      page: () => TicketView(),
      binding: TicketBinding(),
    ),
    GetPage(
      name: _Paths.HISTORY,
      page: () => LocalReportView(),
      binding: LocalReportBinding(),
    ),
    GetPage(
      name: _Paths.SYNC,
      page: () => SyncView(),
      binding: SyncBinding(),
    ),
    GetPage(
      name: _Paths.RESET_PASSWORD,
      page: () => const ResetPasswordView(),
      binding: ResetPasswordBinding(),
    ),
    GetPage(
      name: _Paths.CHANGE_PASSWORD,
      page: () => const ChangePasswordView(),
      binding: ChangePasswordBinding(),
    ),

  ];
}
