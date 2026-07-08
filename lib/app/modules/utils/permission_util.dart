// lib/utils/permission_util.dart
import 'package:permission_handler/permission_handler.dart';

Future<void> requestBluetoothPermissions() async {
  await Permission.bluetooth.request();
  await Permission.bluetoothConnect.request();
  await Permission.location.request();
}
