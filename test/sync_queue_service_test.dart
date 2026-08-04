import 'package:flutter_test/flutter_test.dart';
import 'package:oro_ticket_app/data/locals/service/sync_queue_service.dart';

void main() {
  group('SyncQueueService retry scheduling', () {
    test('uses longer backoff for 429 and grows with each retry', () {
      final first = SyncQueueService.calculateBackoff(retryCount: 0, statusCode: 429);
      final second = SyncQueueService.calculateBackoff(retryCount: 1, statusCode: 429);

      expect(first.inSeconds, greaterThanOrEqualTo(60));
      expect(second.inSeconds, greaterThanOrEqualTo(120));
    });

    test('caps exponential backoff for general server failures', () {
      final backoff = SyncQueueService.calculateBackoff(retryCount: 6, statusCode: 500);

      expect(backoff.inSeconds, greaterThanOrEqualTo(30));
      expect(backoff.inSeconds, lessThanOrEqualTo(60));
    });
  });
}
