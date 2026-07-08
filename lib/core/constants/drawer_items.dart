import 'package:flutter/material.dart';
import 'package:oro_ticket_app/core/constants/colors.dart';

class DrawerItems {
  static const List<Map<String, dynamic>> items = [
    {
      'title': 'Vehicles',
      'icon': Icons.directions_car,
    },
    // {
    //   'title': 'Vehicle categories',
    //   'icon': Icons.directions_bus,
    // },
    {
      'title': 'Terminal Name',
      'icon': Icons.departure_board_rounded,
    },
    {
      'title': 'Arrival Terminal',
      'icon': Icons.share_arrival_time,
    },
    // {
    //   'title': 'Tariff',
    //   'icon': Icons.price_change,
    // },
    {
      'title': 'Change Password',
      'icon': Icons.lock,
    },
    {
      'title': 'Logout',
      'icon': Icons.logout,
      'isDividerNeeded': true,
      'color': AppColors.error,
    },
  ];
}
