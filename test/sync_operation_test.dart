import 'package:flutter_test/flutter_test.dart';
import 'package:docnet/features/sync/domain/entities/sync_operation.dart';

void main() {
  SyncOperation createSampleOperation({
    SyncOperationStatus status = SyncOperationStatus.queued,
  }) {
    final now = DateTime.now().toUtc();
    return SyncOperation(
      operationId: 'op-001',
      userId: 'user-1',
      deviceId: 'device-1',
      operationType: SyncOperationType.upload,
      documentId: 'doc-1',
      versionId: 'ver-1',
      encryptedPayloadReference: '/local/cache/doc-1-ver-1.bin',
      status: status,
      idempotencyKey: 'idemp-12345',
      createdAt: now,
      updatedAt: now,
    );
  }

  group('SyncOperation State Machine Tests', () {
    test('Follows normal forward upload lifecycle', () {
      var op = createSampleOperation(status: SyncOperationStatus.queued);

      expect(op.canTransitionTo(SyncOperationStatus.preparing), isTrue);
      op = op.transitionTo(SyncOperationStatus.preparing);
      expect(op.status, equals(SyncOperationStatus.preparing));

      expect(op.canTransitionTo(SyncOperationStatus.uploading), isTrue);
      op = op.transitionTo(SyncOperationStatus.uploading);
      expect(op.status, equals(SyncOperationStatus.uploading));

      expect(op.canTransitionTo(SyncOperationStatus.uploaded), isTrue);
      op = op.transitionTo(SyncOperationStatus.uploaded);
      expect(op.status, equals(SyncOperationStatus.uploaded));

      expect(op.canTransitionTo(SyncOperationStatus.committing), isTrue);
      op = op.transitionTo(SyncOperationStatus.committing);
      expect(op.status, equals(SyncOperationStatus.committing));

      expect(op.canTransitionTo(SyncOperationStatus.completed), isTrue);
      op = op.transitionTo(SyncOperationStatus.completed);
      expect(op.status, equals(SyncOperationStatus.completed));
    });

    test('Disallows transitions out of terminal state', () {
      final completedOp = createSampleOperation(
        status: SyncOperationStatus.completed,
      );
      expect(
        completedOp.canTransitionTo(SyncOperationStatus.uploading),
        isFalse,
      );
      expect(
        () => completedOp.transitionTo(SyncOperationStatus.uploading),
        throwsA(isA<StateError>()),
      );
    });

    test('Allows transient failure retry transition', () {
      var op = createSampleOperation(status: SyncOperationStatus.uploading);

      expect(op.canTransitionTo(SyncOperationStatus.retryWait), isTrue);
      op = op.transitionTo(
        SyncOperationStatus.retryWait,
        errorCode: 'NETWORK_TIMEOUT',
        incrementRetry: 1,
      );

      expect(op.status, equals(SyncOperationStatus.retryWait));
      expect(op.retryCount, equals(1));
      expect(op.lastErrorCode, equals('NETWORK_TIMEOUT'));

      // After backoff, returns to queued
      expect(op.canTransitionTo(SyncOperationStatus.queued), isTrue);
      op = op.transitionTo(SyncOperationStatus.queued);
      expect(op.status, equals(SyncOperationStatus.queued));
    });

    test('Allows conflict state from committing', () {
      var op = createSampleOperation(status: SyncOperationStatus.committing);

      expect(op.canTransitionTo(SyncOperationStatus.conflict), isTrue);
      op = op.transitionTo(
        SyncOperationStatus.conflict,
        errorCode: 'PARENT_VERSION_MISMATCH',
      );
      expect(op.status, equals(SyncOperationStatus.conflict));
      expect(op.lastErrorCode, equals('PARENT_VERSION_MISMATCH'));
    });

    test('Can be cancelled from any non-terminal state', () {
      final op = createSampleOperation(status: SyncOperationStatus.preparing);
      expect(op.canTransitionTo(SyncOperationStatus.cancelled), isTrue);
      final cancelled = op.transitionTo(SyncOperationStatus.cancelled);
      expect(cancelled.status, equals(SyncOperationStatus.cancelled));
    });
  });
}
