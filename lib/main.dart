import 'dart:io';
import 'package:flutter/material.dart';
import 'package:oro_ticket_app/data/locals/service/backup_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive/hive.dart';
import 'package:oro_ticket_app/app/modules/home/controllers/home_controller.dart';
import 'package:oro_ticket_app/app/modules/reset_password/view/reset_password_view.dart';
import 'package:oro_ticket_app/app/modules/sign_in/views/sign_in_view.dart';
import 'package:oro_ticket_app/app/modules/sign_in/services/auth_service.dart';
import 'package:oro_ticket_app/app/routes/app_pages.dart';
import 'package:get/get.dart';
import 'package:oro_ticket_app/core/theme/app_theme.dart';
import 'package:oro_ticket_app/core/utils/security_utils.dart';
import 'package:oro_ticket_app/data/locals/hive_boxes.dart';
import 'package:oro_ticket_app/app/modules/reset_password/controller/reset_password_controller.dart';
import 'package:oro_ticket_app/core/constants/colors.dart';
import 'package:oro_ticket_app/core/constants/typography.dart';
import 'package:oro_ticket_app/data/locals/service/connectivity_service.dart';
import 'package:oro_ticket_app/data/repositories/enhanced_sync_repository.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveBoxes.init();
  await Hive.openBox('appState');
  await dotenv.load(fileName: ".env");

  // Register dependencies early (before any permission checks or runApp)
  Get.put(AuthService());
  Get.put(HomeController());
  Get.put(ResetPasswordController());
  Get.put(ConnectivityService());

  // Initialize enhanced sync repository as singleton
  Get.put(EnhancedSyncRepository(), permanent: true);
  final enhancedSyncRepo = Get.find<EnhancedSyncRepository>();

  // Check storage permission (required for backup/restore)
  final storageStatus = await Permission.manageExternalStorage.status;

  // Start periodic + auto background sync after restore and app startup
  // (moved later to avoid network/UI calls during restore)


  if (!storageStatus.isGranted) {
    // Block the app until storage permission is granted
    runApp(const StoragePermissionGate());
    return;
  }

  // Permission granted — continue normal initialization
  // Restore from encrypted backup if local data is missing
  await BackupService.restoreIfNeeded();

  // Initialize security utilities
  // await _initializeSecurity();

  runApp(const MyApp());

  // Now that the app is running, start periodic background sync (deferred)
  Future.delayed(const Duration(seconds: 2), () {
    // Start sync after a small delay so UI can initialize and Overlay is available
    try {
      final enhanced = Get.find<EnhancedSyncRepository>();
      enhanced.startPeriodicSync(interval: Duration(minutes: 2));
    } catch (e) {
      print('⚠️ Could not start periodic sync after startup: $e');
    }
  });
}

Future<void> _initializeSecurity() async {
  try {
    // Check for emulator/simulator
    final isEmulator = await SecurityUtils.isRunningOnEmulator();
    if (isEmulator) {
      print('🚫 SECURITY ALERT: App cannot run on emulator/simulator');
      // Show error and exit
      runApp(const SecurityErrorApp(
          message:
              'This application cannot run on emulators or simulators for security reasons.\n\nPlease use a physical device.'));
      return;
    }

    // Check for rooted/jailbroken devices
    final isRooted = await SecurityUtils.isDeviceRooted();
    if (isRooted) {
      print('🚫 SECURITY ALERT: Device appears to be rooted/jailbroken');
      // Show error and exit
      runApp(const SecurityErrorApp(
          message:
              'This application cannot run on rooted or jailbroken devices for security reasons.\n\nPlease use a standard device.'));
      return;
    }

    // Initialize rate limiting cleanup
    SecurityUtils.cleanupRateLimits();

    print('✅ Security initialization completed');
  } catch (e) {
    print('❌ Security initialization failed: $e');
    // Continue even if security check fails to avoid breaking the app
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Hive.box('appState');
    final isFirstInstall = appState.get('isFirstInstall', defaultValue: true);

    // Check if user is logged in using restored backup data
    final authService = Get.find<AuthService>();
    final initialRoute = authService.isLoggedInSync() 
        ? '/home' 
        : AppPages.INITIAL;

    return GetMaterialApp(
      theme: AppTheme.lightTheme,
      initialRoute: initialRoute,
      getPages: AppPages.routes,
      title: 'Oro Ticket App',
      debugShowCheckedModeBanner: false,
      routingCallback: (routing) {
        if (routing?.current != null && routing!.current != '/session-check') {
          Hive.box('appState').put('lastRoute', routing.current);
        }
      },
    );
  }
}

class SecurityErrorApp extends StatefulWidget {
  final String message;

  const SecurityErrorApp({super.key, required this.message});

  @override
  State<SecurityErrorApp> createState() => _SecurityErrorAppState();
}

class _SecurityErrorAppState extends State<SecurityErrorApp> {
  @override
  void initState() {
    super.initState();
    // Exit the app after showing the error for 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      exit(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.security,
                  size: 80,
                  color: AppColors.error,
                ),
                const SizedBox(height: 24),
                Text(
                  'Security Error',
                  style:
                      AppTextStyles.heading1.copyWith(color: AppColors.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.message,
                  style: AppTextStyles.body1,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Text(
                  'Application will close in 3 seconds...',
                  style: AppTextStyles.body2.copyWith(color: AppColors.error),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StoragePermissionGate extends StatefulWidget {
  const StoragePermissionGate({super.key});

  @override
  State<StoragePermissionGate> createState() => _StoragePermissionGateState();
}

class _StoragePermissionGateState extends State<StoragePermissionGate> {
  bool _isLoading = false;

  Future<void> _requestPermission() async {
    setState(() => _isLoading = true);

    final status = await Permission.manageExternalStorage.request();

    if (status.isGranted) {
      // Permission granted — perform restore from backup then start normal app
      await BackupService.restoreIfNeeded();
      runApp(const MyApp());
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Storage access is required to continue using the app."),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _openAppSettings() async {
    await openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.folder_off_outlined, size: 90, color: Colors.red),
                const SizedBox(height: 24),
                const Text(
                  "Storage Permission Required",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  "This app needs access to your device's storage.\n\n"
                  "Without this permission, the app cannot run.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _requestPermission,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Grant Storage Permission"),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _openAppSettings,
                  child: const Text("Open App Settings"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
