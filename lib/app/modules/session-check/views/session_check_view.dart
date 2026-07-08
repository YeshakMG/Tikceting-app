import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:oro_ticket_app/app/modules/sign_in/services/auth_service.dart';

class SessionCheckView extends StatefulWidget {
  const SessionCheckView({super.key});

  @override
  State<SessionCheckView> createState() => _SessionCheckViewState();
}

class _SessionCheckViewState extends State<SessionCheckView> {
  final AuthService _authService = Get.find<AuthService>();

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    await Future.delayed(
        const Duration(milliseconds: 300)); // small splash delay
    bool loggedIn = await _authService.isLoggedIn();

    if (loggedIn) {
      // Optional: get last route from Hive
      String? lastRoute = Hive.box('appState').get('lastRoute');
      if (lastRoute != null && lastRoute != '/session-check') {
        Get.offNamed(lastRoute);
      } else {
        Get.offNamed('/home');
      }
    } else {
      Get.offAllNamed('/splash-screen');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
