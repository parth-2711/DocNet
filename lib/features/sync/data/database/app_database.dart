import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// Drift table definition for local sync operations queue (SYNC_ENGINE.md Section 3).
class SyncOperationsTable extends Table {
  TextColumn get operationId => text()();
  TextColumn get userId => text()();
  TextColumn get deviceId => text()();
  TextColumn get operationType => text()();
  TextColumn get documentId => text()();
  TextColumn get versionId => text()();
  TextColumn get expectedParentVersionId => text().nullable()();
  TextColumn get encryptedPayloadReference => text()();
  TextColumn get status => text()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();
  TextColumn get idempotencyKey => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get lastErrorCode => text().nullable()();

  @override
  Set<Column> get primaryKey => {operationId};
}

/// Drift table definition for offline cached encrypted documents (PRD.md DOC-017).
class CachedDocumentsTable extends Table {
  TextColumn get documentId => text()();
  TextColumn get versionId => text()();
  TextColumn get ownerUid => text()();
  TextColumn get localCiphertextPath => text()();
  TextColumn get encryptedMetadataJson => text()();
  IntColumn get fileSizeBytes => integer()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {documentId, versionId};
}

@DriftDatabase(tables: [SyncOperationsTable, CachedDocumentsTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;
}
