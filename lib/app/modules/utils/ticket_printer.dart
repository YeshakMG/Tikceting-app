import 'dart:typed_data';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:collection/collection.dart';
import 'package:oro_ticket_app/app/modules/ticket/model/exit_ticket_qr_model.dart';

class TicketPrinter {
  final BlueThermalPrinter _printer = BlueThermalPrinter.instance;

  static const List<String> _builtInKeywords = [
    'thermal', 'printer', 'pos', 'internal', 'built', '58mm', '80mm', 'mini', 'receipt'
  ];

  Future<PrintResult> connectAndPrintVerified({
    required int copies,
    required List<String> texts,
    List<String>? passengerQRDatas,
    String? exitText,
    ExitTicketQRData? exitQRData,
  }) async {
    try {
      final connected = await _ensureConnected();
      if (!connected) {
        return PrintResult(success: false, error: "Bluetooth is not connected");
      }

      // Reset printer
      await _printer.writeBytes(Uint8List.fromList([27, 64]));
      await Future.delayed(const Duration(milliseconds: 80));

      // Print main tickets with individual QR codes
      for (int i = 0; i < copies; i++) {
        await _printText(texts[i]);

        if (passengerQRDatas != null && passengerQRDatas.length > i && passengerQRDatas[i].isNotEmpty) {
          await _printer.printQRcode(passengerQRDatas[i], 110, 110, 1);
          await _printer.printNewLine();
        }
        await _printer.printNewLine();
      }

      // Print Exit Ticket (once at the end)
      if (exitText != null && exitText.isNotEmpty) {
        await _printer.printNewLine();
        await _printText('============================');
        await _printText('      EXIT TICKET');
        await _printText('============================');
        await _printer.printNewLine();

        await _printText(exitText);

        if (exitQRData != null) {
          await _printText('Scan for Exit Verification');
          await _printer.printNewLine();
          await _printer.printQRcode(exitQRData.toQRString(), 220, 220, 1);
        }
        await _printer.printNewLine();
      }

      await _printer.paperCut();
      return PrintResult(success: true);
    } catch (e) {
      print('❌ Bluetooth print error: $e');
      try {
        await _printer.disconnect();
      } catch (_) {}
      return PrintResult(success: false, error: e.toString());
    }
  }

  Future<bool> _ensureConnected() async {
    bool? isConnected = await _printer.isConnected;
    if (isConnected == true) return true;

    final devices = await _printer.getBondedDevices();
    if (devices.isEmpty) return false;

    BluetoothDevice? target = devices.firstWhereOrNull((d) {
      final name = (d.name ?? '').toLowerCase();
      return _builtInKeywords.any((k) => name.contains(k));
    });

    target ??= devices.first;

    print('🔗 [TicketPrinter] Auto-connecting to: ${target.name}');
    await _printer.connect(target);
    await Future.delayed(const Duration(milliseconds: 1300));

    return await _printer.isConnected ?? false;
  }

  Future<bool> ensureConnected() async {
    return await _ensureConnected();
  }

  Future<void> _printText(String text) async {
    for (final line in text.split('\n')) {
      if (line.trim().isEmpty) {
        await _printer.printNewLine();
      } else {
        final isBoldLine = line.contains('<B>') && line.contains('</B>');
        final printableLine = line.replaceAll('<B>', '').replaceAll('</B>', '');

        if (isBoldLine) {
          // ESC E 1 => bold on
          await _printer.writeBytes(Uint8List.fromList([27, 69, 1]));
        }

        await _printer.printCustom(printableLine, 1, 0);

        if (isBoldLine) {
          // ESC E 0 => bold off
          await _printer.writeBytes(Uint8List.fromList([27, 69, 0]));
        }
      }
    }
  }
}

class PrintResult {
  final bool success;
  final String? error;

  PrintResult({
    required this.success,
    this.error,
  });
}
