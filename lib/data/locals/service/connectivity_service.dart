import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

class ConnectivityService extends GetxService {
  final Connectivity _connectivity = Connectivity();

  final RxBool isConnected = false.obs;
  final Rx<ConnectivityResult> connectionType = ConnectivityResult.none.obs;

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  @override
  void onInit() {
    super.onInit();
    _initConnectivity();
    _setupListener();
  }

  Future<void> _initConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateStatus(result);
    } catch (e) {
      print('⚠️ Initial connectivity check failed: $e');
      isConnected.value = false;
    }
  }

  void _setupListener() {
    _subscription = _connectivity.onConnectivityChanged.listen(_updateStatus);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
    connectionType.value = result;
    isConnected.value = result != ConnectivityResult.none;
    print(
        '🌐 Connectivity changed: ${isConnected.value ? 'ONLINE' : 'OFFLINE'} (${result.name})');
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }
}
