import 'package:flutter/material.dart';
import 'package:oro_ticket_app/core/constants/colors.dart';
import 'package:oro_ticket_app/core/constants/drawer_items.dart';
import 'package:oro_ticket_app/core/constants/typography.dart';
import 'package:oro_ticket_app/widgets/drawer_item_widget.dart';

class CustomDrawer extends StatelessWidget {
  final String userName;
  final String? companyLogoUrl;
  final String companyName;
  final Function(String)? onItemSelected;

  const CustomDrawer({
    super.key,
    required this.userName,
    this.companyLogoUrl,
    required this.companyName,
    this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            CustomDrawerHeader(
              userName: userName,
              companyLogoUrl: companyLogoUrl,
              companyName: companyName,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: DrawerItems.items
                    .map((item) => DrawerItem(
                          title: item['title'],
                          icon: item['icon'],
                          color: item['color'],
                          onTap: () => onItemSelected?.call(item['title']),
                        ))
                    .toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Powered by',
                    style: AppTextStyles.caption3
                        .copyWith(color: Colors.grey[400], fontSize: 10),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ethiopian Artificial Intelligence Institute',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 10,
                      color: Colors.grey[400],
                    ),
                    textAlign: TextAlign.center,
                  ),  
                  const SizedBox(height: 4),
                  Text(
                    'Version 1.0.4',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 10,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomDrawerHeader extends StatelessWidget {
  final String userName;
  final String? companyLogoUrl;
  final String companyName;

  const CustomDrawerHeader({
    super.key,
    required this.userName,
    this.companyLogoUrl,
    required this.companyName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      decoration: const BoxDecoration(color: AppColors.backgroundAlt),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Center(
              child: (companyLogoUrl != null && companyLogoUrl!.isNotEmpty)
                  ? ClipOval(
                      child: Image.network(
                        companyLogoUrl!,
                        height: 100,
                        width:
                            100, // Make sure width matches height for perfect circle
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return buildDefaultLogo(); // Fallback to default circular logo
                        },
                      ),
                    )
                  : buildDefaultLogo(),
            ),
            const SizedBox(height: 10),
            Text(userName, style: AppTextStyles.heading2),
            const SizedBox(height: 4),
            Text(companyName, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }

  Widget buildDefaultLogo() {
    return ClipOval(
      child: Image.asset(
        'assets/logo/OTA_logo.png',
        height: 100,
        width: 100,
        fit: BoxFit.cover,
      ),
    );
  }
}
