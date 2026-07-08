import 'package:blue_thermal_printer/blue_thermal_printer.dart';

class BluetoothPrintService {
  final BlueThermalPrinter printer = BlueThermalPrinter.instance;

  Future<void> printTicket(String text) async {
    final isConnected = await printer.isConnected ?? false;

    if (!isConnected) {
      List<BluetoothDevice> devices = await printer.getBondedDevices();
      if (devices.isNotEmpty) {
        await printer.connect(devices.first); // Optionally show a picker
      }
    }

    if (await printer.isConnected ?? false) {
      printer.printNewLine();
      printer.printCustom("Oromia Ticket", 3, 1); // title, size, align
      printer.printNewLine();
      printer.printCustom(text, 1, 0); // content
      printer.printNewLine();
      printer.paperCut();
    }
  }
}
