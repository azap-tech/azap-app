import 'package:azap_native_manager_app/stores/ticket.dart';
import 'package:mobx/mobx.dart';

part 'tickets.g.dart';

class Tickets extends _Tickets with _$Tickets {}

// The store-class
abstract class _Tickets with Store {
  @observable
  ObservableList<Ticket> list = ObservableList<Ticket>();

  @action
  void addTicket(Ticket ticket) {
    list.add(ticket);
  }

  @action
  void addTickets(List<Ticket> tickets) {
    list.addAll(tickets);
  }
}