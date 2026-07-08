import 'package:get/get.dart';
import '../../../data/models/ticket_model.dart';

class TicketDetailController extends GetxController {
  var selectedTicket = Rxn<Ticket>();

  void setTicket(Ticket ticket) {
    selectedTicket.value = ticket;
  }
}