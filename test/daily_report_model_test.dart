import 'package:flutter_test/flutter_test.dart';
import 'package:lembah_wilis/Models/daily_report_model.dart';

void main() {
  group('TicketSummary.fromInput', () {
    test('counts physical, free, and paid tickets from the serial range', () {
      final ticket = TicketSummary.fromInput(
        ticketTypeId: 'regular',
        ticketName: 'Reguler',
        price: 25000,
        serialStart: '0001',
        serialEnd: '0050',
        freeCount: 5,
      );

      expect(ticket.serialStart, '0001');
      expect(ticket.serialCount, 50);
      expect(ticket.freeCount, 5);
      expect(ticket.paidCount, 45);
    });

    test('rejects invalid ranges and free ticket counts', () {
      TicketSummary create({
        required String start,
        required String end,
        required int free,
      }) => TicketSummary.fromInput(
        ticketTypeId: 'regular',
        ticketName: 'Reguler',
        price: 25000,
        serialStart: start,
        serialEnd: end,
        freeCount: free,
      );

      expect(() => create(start: '10', end: '9', free: 0), throwsArgumentError);
      expect(() => create(start: '1', end: '3', free: 4), throwsArgumentError);
      expect(() => create(start: 'A', end: '3', free: 0), throwsArgumentError);
    });
  });

  test('ReportData totals visitors and combines cash with QRIS', () {
    final reports = ReportData.fromTickets(
      ticketSummary: {
        'regular': TicketSummary.fromInput(
          ticketTypeId: 'regular',
          ticketName: 'Reguler',
          price: 25000,
          serialStart: '1',
          serialEnd: '3',
          freeCount: 1,
        ),
        'child': TicketSummary.fromInput(
          ticketTypeId: 'child',
          ticketName: 'Anak',
          price: 15000,
          serialStart: '1',
          serialEnd: '2',
          freeCount: 0,
        ),
      },
      cashRevenue: 50000,
      qrisRevenue: 25000,
    );

    expect(reports.totalVisitors, 5);
    expect(reports.totalRevenue, 75000);
  });
}
