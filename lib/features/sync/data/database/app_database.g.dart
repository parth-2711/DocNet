// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SyncOperationsTableTable extends SyncOperationsTable
    with TableInfo<$SyncOperationsTableTable, SyncOperationsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncOperationsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _operationIdMeta = const VerificationMeta(
    'operationId',
  );
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationTypeMeta = const VerificationMeta(
    'operationType',
  );
  @override
  late final GeneratedColumn<String> operationType = GeneratedColumn<String>(
    'operation_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _documentIdMeta = const VerificationMeta(
    'documentId',
  );
  @override
  late final GeneratedColumn<String> documentId = GeneratedColumn<String>(
    'document_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionIdMeta = const VerificationMeta(
    'versionId',
  );
  @override
  late final GeneratedColumn<String> versionId = GeneratedColumn<String>(
    'version_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expectedParentVersionIdMeta =
      const VerificationMeta('expectedParentVersionId');
  @override
  late final GeneratedColumn<String> expectedParentVersionId =
      GeneratedColumn<String>(
        'expected_parent_version_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _encryptedPayloadReferenceMeta =
      const VerificationMeta('encryptedPayloadReference');
  @override
  late final GeneratedColumn<String> encryptedPayloadReference =
      GeneratedColumn<String>(
        'encrypted_payload_reference',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextAttemptAtMeta = const VerificationMeta(
    'nextAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextAttemptAt =
      GeneratedColumn<DateTime>(
        'next_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _idempotencyKeyMeta = const VerificationMeta(
    'idempotencyKey',
  );
  @override
  late final GeneratedColumn<String> idempotencyKey = GeneratedColumn<String>(
    'idempotency_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastErrorCodeMeta = const VerificationMeta(
    'lastErrorCode',
  );
  @override
  late final GeneratedColumn<String> lastErrorCode = GeneratedColumn<String>(
    'last_error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    operationId,
    userId,
    deviceId,
    operationType,
    documentId,
    versionId,
    expectedParentVersionId,
    encryptedPayloadReference,
    status,
    retryCount,
    nextAttemptAt,
    idempotencyKey,
    createdAt,
    updatedAt,
    lastErrorCode,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_operations_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncOperationsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('operation_id')) {
      context.handle(
        _operationIdMeta,
        operationId.isAcceptableOrUnknown(
          data['operation_id']!,
          _operationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('operation_type')) {
      context.handle(
        _operationTypeMeta,
        operationType.isAcceptableOrUnknown(
          data['operation_type']!,
          _operationTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationTypeMeta);
    }
    if (data.containsKey('document_id')) {
      context.handle(
        _documentIdMeta,
        documentId.isAcceptableOrUnknown(data['document_id']!, _documentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_documentIdMeta);
    }
    if (data.containsKey('version_id')) {
      context.handle(
        _versionIdMeta,
        versionId.isAcceptableOrUnknown(data['version_id']!, _versionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_versionIdMeta);
    }
    if (data.containsKey('expected_parent_version_id')) {
      context.handle(
        _expectedParentVersionIdMeta,
        expectedParentVersionId.isAcceptableOrUnknown(
          data['expected_parent_version_id']!,
          _expectedParentVersionIdMeta,
        ),
      );
    }
    if (data.containsKey('encrypted_payload_reference')) {
      context.handle(
        _encryptedPayloadReferenceMeta,
        encryptedPayloadReference.isAcceptableOrUnknown(
          data['encrypted_payload_reference']!,
          _encryptedPayloadReferenceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_encryptedPayloadReferenceMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
        _nextAttemptAtMeta,
        nextAttemptAt.isAcceptableOrUnknown(
          data['next_attempt_at']!,
          _nextAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('idempotency_key')) {
      context.handle(
        _idempotencyKeyMeta,
        idempotencyKey.isAcceptableOrUnknown(
          data['idempotency_key']!,
          _idempotencyKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_idempotencyKeyMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('last_error_code')) {
      context.handle(
        _lastErrorCodeMeta,
        lastErrorCode.isAcceptableOrUnknown(
          data['last_error_code']!,
          _lastErrorCodeMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {operationId};
  @override
  SyncOperationsTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncOperationsTableData(
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      operationType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_type'],
      )!,
      documentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_id'],
      )!,
      versionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version_id'],
      )!,
      expectedParentVersionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}expected_parent_version_id'],
      ),
      encryptedPayloadReference: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encrypted_payload_reference'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      nextAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_attempt_at'],
      ),
      idempotencyKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}idempotency_key'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      lastErrorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error_code'],
      ),
    );
  }

  @override
  $SyncOperationsTableTable createAlias(String alias) {
    return $SyncOperationsTableTable(attachedDatabase, alias);
  }
}

class SyncOperationsTableData extends DataClass
    implements Insertable<SyncOperationsTableData> {
  final String operationId;
  final String userId;
  final String deviceId;
  final String operationType;
  final String documentId;
  final String versionId;
  final String? expectedParentVersionId;
  final String encryptedPayloadReference;
  final String status;
  final int retryCount;
  final DateTime? nextAttemptAt;
  final String idempotencyKey;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastErrorCode;
  const SyncOperationsTableData({
    required this.operationId,
    required this.userId,
    required this.deviceId,
    required this.operationType,
    required this.documentId,
    required this.versionId,
    this.expectedParentVersionId,
    required this.encryptedPayloadReference,
    required this.status,
    required this.retryCount,
    this.nextAttemptAt,
    required this.idempotencyKey,
    required this.createdAt,
    required this.updatedAt,
    this.lastErrorCode,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['operation_id'] = Variable<String>(operationId);
    map['user_id'] = Variable<String>(userId);
    map['device_id'] = Variable<String>(deviceId);
    map['operation_type'] = Variable<String>(operationType);
    map['document_id'] = Variable<String>(documentId);
    map['version_id'] = Variable<String>(versionId);
    if (!nullToAbsent || expectedParentVersionId != null) {
      map['expected_parent_version_id'] = Variable<String>(
        expectedParentVersionId,
      );
    }
    map['encrypted_payload_reference'] = Variable<String>(
      encryptedPayloadReference,
    );
    map['status'] = Variable<String>(status);
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || nextAttemptAt != null) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt);
    }
    map['idempotency_key'] = Variable<String>(idempotencyKey);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || lastErrorCode != null) {
      map['last_error_code'] = Variable<String>(lastErrorCode);
    }
    return map;
  }

  SyncOperationsTableCompanion toCompanion(bool nullToAbsent) {
    return SyncOperationsTableCompanion(
      operationId: Value(operationId),
      userId: Value(userId),
      deviceId: Value(deviceId),
      operationType: Value(operationType),
      documentId: Value(documentId),
      versionId: Value(versionId),
      expectedParentVersionId: expectedParentVersionId == null && nullToAbsent
          ? const Value.absent()
          : Value(expectedParentVersionId),
      encryptedPayloadReference: Value(encryptedPayloadReference),
      status: Value(status),
      retryCount: Value(retryCount),
      nextAttemptAt: nextAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextAttemptAt),
      idempotencyKey: Value(idempotencyKey),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      lastErrorCode: lastErrorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(lastErrorCode),
    );
  }

  factory SyncOperationsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncOperationsTableData(
      operationId: serializer.fromJson<String>(json['operationId']),
      userId: serializer.fromJson<String>(json['userId']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      operationType: serializer.fromJson<String>(json['operationType']),
      documentId: serializer.fromJson<String>(json['documentId']),
      versionId: serializer.fromJson<String>(json['versionId']),
      expectedParentVersionId: serializer.fromJson<String?>(
        json['expectedParentVersionId'],
      ),
      encryptedPayloadReference: serializer.fromJson<String>(
        json['encryptedPayloadReference'],
      ),
      status: serializer.fromJson<String>(json['status']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      nextAttemptAt: serializer.fromJson<DateTime?>(json['nextAttemptAt']),
      idempotencyKey: serializer.fromJson<String>(json['idempotencyKey']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      lastErrorCode: serializer.fromJson<String?>(json['lastErrorCode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'operationId': serializer.toJson<String>(operationId),
      'userId': serializer.toJson<String>(userId),
      'deviceId': serializer.toJson<String>(deviceId),
      'operationType': serializer.toJson<String>(operationType),
      'documentId': serializer.toJson<String>(documentId),
      'versionId': serializer.toJson<String>(versionId),
      'expectedParentVersionId': serializer.toJson<String?>(
        expectedParentVersionId,
      ),
      'encryptedPayloadReference': serializer.toJson<String>(
        encryptedPayloadReference,
      ),
      'status': serializer.toJson<String>(status),
      'retryCount': serializer.toJson<int>(retryCount),
      'nextAttemptAt': serializer.toJson<DateTime?>(nextAttemptAt),
      'idempotencyKey': serializer.toJson<String>(idempotencyKey),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'lastErrorCode': serializer.toJson<String?>(lastErrorCode),
    };
  }

  SyncOperationsTableData copyWith({
    String? operationId,
    String? userId,
    String? deviceId,
    String? operationType,
    String? documentId,
    String? versionId,
    Value<String?> expectedParentVersionId = const Value.absent(),
    String? encryptedPayloadReference,
    String? status,
    int? retryCount,
    Value<DateTime?> nextAttemptAt = const Value.absent(),
    String? idempotencyKey,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<String?> lastErrorCode = const Value.absent(),
  }) => SyncOperationsTableData(
    operationId: operationId ?? this.operationId,
    userId: userId ?? this.userId,
    deviceId: deviceId ?? this.deviceId,
    operationType: operationType ?? this.operationType,
    documentId: documentId ?? this.documentId,
    versionId: versionId ?? this.versionId,
    expectedParentVersionId: expectedParentVersionId.present
        ? expectedParentVersionId.value
        : this.expectedParentVersionId,
    encryptedPayloadReference:
        encryptedPayloadReference ?? this.encryptedPayloadReference,
    status: status ?? this.status,
    retryCount: retryCount ?? this.retryCount,
    nextAttemptAt: nextAttemptAt.present
        ? nextAttemptAt.value
        : this.nextAttemptAt,
    idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    lastErrorCode: lastErrorCode.present
        ? lastErrorCode.value
        : this.lastErrorCode,
  );
  SyncOperationsTableData copyWithCompanion(SyncOperationsTableCompanion data) {
    return SyncOperationsTableData(
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      userId: data.userId.present ? data.userId.value : this.userId,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      operationType: data.operationType.present
          ? data.operationType.value
          : this.operationType,
      documentId: data.documentId.present
          ? data.documentId.value
          : this.documentId,
      versionId: data.versionId.present ? data.versionId.value : this.versionId,
      expectedParentVersionId: data.expectedParentVersionId.present
          ? data.expectedParentVersionId.value
          : this.expectedParentVersionId,
      encryptedPayloadReference: data.encryptedPayloadReference.present
          ? data.encryptedPayloadReference.value
          : this.encryptedPayloadReference,
      status: data.status.present ? data.status.value : this.status,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      idempotencyKey: data.idempotencyKey.present
          ? data.idempotencyKey.value
          : this.idempotencyKey,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      lastErrorCode: data.lastErrorCode.present
          ? data.lastErrorCode.value
          : this.lastErrorCode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncOperationsTableData(')
          ..write('operationId: $operationId, ')
          ..write('userId: $userId, ')
          ..write('deviceId: $deviceId, ')
          ..write('operationType: $operationType, ')
          ..write('documentId: $documentId, ')
          ..write('versionId: $versionId, ')
          ..write('expectedParentVersionId: $expectedParentVersionId, ')
          ..write('encryptedPayloadReference: $encryptedPayloadReference, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastErrorCode: $lastErrorCode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    operationId,
    userId,
    deviceId,
    operationType,
    documentId,
    versionId,
    expectedParentVersionId,
    encryptedPayloadReference,
    status,
    retryCount,
    nextAttemptAt,
    idempotencyKey,
    createdAt,
    updatedAt,
    lastErrorCode,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncOperationsTableData &&
          other.operationId == this.operationId &&
          other.userId == this.userId &&
          other.deviceId == this.deviceId &&
          other.operationType == this.operationType &&
          other.documentId == this.documentId &&
          other.versionId == this.versionId &&
          other.expectedParentVersionId == this.expectedParentVersionId &&
          other.encryptedPayloadReference == this.encryptedPayloadReference &&
          other.status == this.status &&
          other.retryCount == this.retryCount &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.idempotencyKey == this.idempotencyKey &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.lastErrorCode == this.lastErrorCode);
}

class SyncOperationsTableCompanion
    extends UpdateCompanion<SyncOperationsTableData> {
  final Value<String> operationId;
  final Value<String> userId;
  final Value<String> deviceId;
  final Value<String> operationType;
  final Value<String> documentId;
  final Value<String> versionId;
  final Value<String?> expectedParentVersionId;
  final Value<String> encryptedPayloadReference;
  final Value<String> status;
  final Value<int> retryCount;
  final Value<DateTime?> nextAttemptAt;
  final Value<String> idempotencyKey;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String?> lastErrorCode;
  final Value<int> rowid;
  const SyncOperationsTableCompanion({
    this.operationId = const Value.absent(),
    this.userId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.operationType = const Value.absent(),
    this.documentId = const Value.absent(),
    this.versionId = const Value.absent(),
    this.expectedParentVersionId = const Value.absent(),
    this.encryptedPayloadReference = const Value.absent(),
    this.status = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.idempotencyKey = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.lastErrorCode = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncOperationsTableCompanion.insert({
    required String operationId,
    required String userId,
    required String deviceId,
    required String operationType,
    required String documentId,
    required String versionId,
    this.expectedParentVersionId = const Value.absent(),
    required String encryptedPayloadReference,
    required String status,
    this.retryCount = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    required String idempotencyKey,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.lastErrorCode = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : operationId = Value(operationId),
       userId = Value(userId),
       deviceId = Value(deviceId),
       operationType = Value(operationType),
       documentId = Value(documentId),
       versionId = Value(versionId),
       encryptedPayloadReference = Value(encryptedPayloadReference),
       status = Value(status),
       idempotencyKey = Value(idempotencyKey),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SyncOperationsTableData> custom({
    Expression<String>? operationId,
    Expression<String>? userId,
    Expression<String>? deviceId,
    Expression<String>? operationType,
    Expression<String>? documentId,
    Expression<String>? versionId,
    Expression<String>? expectedParentVersionId,
    Expression<String>? encryptedPayloadReference,
    Expression<String>? status,
    Expression<int>? retryCount,
    Expression<DateTime>? nextAttemptAt,
    Expression<String>? idempotencyKey,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? lastErrorCode,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (operationId != null) 'operation_id': operationId,
      if (userId != null) 'user_id': userId,
      if (deviceId != null) 'device_id': deviceId,
      if (operationType != null) 'operation_type': operationType,
      if (documentId != null) 'document_id': documentId,
      if (versionId != null) 'version_id': versionId,
      if (expectedParentVersionId != null)
        'expected_parent_version_id': expectedParentVersionId,
      if (encryptedPayloadReference != null)
        'encrypted_payload_reference': encryptedPayloadReference,
      if (status != null) 'status': status,
      if (retryCount != null) 'retry_count': retryCount,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (lastErrorCode != null) 'last_error_code': lastErrorCode,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncOperationsTableCompanion copyWith({
    Value<String>? operationId,
    Value<String>? userId,
    Value<String>? deviceId,
    Value<String>? operationType,
    Value<String>? documentId,
    Value<String>? versionId,
    Value<String?>? expectedParentVersionId,
    Value<String>? encryptedPayloadReference,
    Value<String>? status,
    Value<int>? retryCount,
    Value<DateTime?>? nextAttemptAt,
    Value<String>? idempotencyKey,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String?>? lastErrorCode,
    Value<int>? rowid,
  }) {
    return SyncOperationsTableCompanion(
      operationId: operationId ?? this.operationId,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      operationType: operationType ?? this.operationType,
      documentId: documentId ?? this.documentId,
      versionId: versionId ?? this.versionId,
      expectedParentVersionId:
          expectedParentVersionId ?? this.expectedParentVersionId,
      encryptedPayloadReference:
          encryptedPayloadReference ?? this.encryptedPayloadReference,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastErrorCode: lastErrorCode ?? this.lastErrorCode,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (operationType.present) {
      map['operation_type'] = Variable<String>(operationType.value);
    }
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (versionId.present) {
      map['version_id'] = Variable<String>(versionId.value);
    }
    if (expectedParentVersionId.present) {
      map['expected_parent_version_id'] = Variable<String>(
        expectedParentVersionId.value,
      );
    }
    if (encryptedPayloadReference.present) {
      map['encrypted_payload_reference'] = Variable<String>(
        encryptedPayloadReference.value,
      );
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt.value);
    }
    if (idempotencyKey.present) {
      map['idempotency_key'] = Variable<String>(idempotencyKey.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (lastErrorCode.present) {
      map['last_error_code'] = Variable<String>(lastErrorCode.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncOperationsTableCompanion(')
          ..write('operationId: $operationId, ')
          ..write('userId: $userId, ')
          ..write('deviceId: $deviceId, ')
          ..write('operationType: $operationType, ')
          ..write('documentId: $documentId, ')
          ..write('versionId: $versionId, ')
          ..write('expectedParentVersionId: $expectedParentVersionId, ')
          ..write('encryptedPayloadReference: $encryptedPayloadReference, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastErrorCode: $lastErrorCode, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedDocumentsTableTable extends CachedDocumentsTable
    with TableInfo<$CachedDocumentsTableTable, CachedDocumentsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedDocumentsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _documentIdMeta = const VerificationMeta(
    'documentId',
  );
  @override
  late final GeneratedColumn<String> documentId = GeneratedColumn<String>(
    'document_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionIdMeta = const VerificationMeta(
    'versionId',
  );
  @override
  late final GeneratedColumn<String> versionId = GeneratedColumn<String>(
    'version_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerUidMeta = const VerificationMeta(
    'ownerUid',
  );
  @override
  late final GeneratedColumn<String> ownerUid = GeneratedColumn<String>(
    'owner_uid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localCiphertextPathMeta =
      const VerificationMeta('localCiphertextPath');
  @override
  late final GeneratedColumn<String> localCiphertextPath =
      GeneratedColumn<String>(
        'local_ciphertext_path',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _encryptedMetadataJsonMeta =
      const VerificationMeta('encryptedMetadataJson');
  @override
  late final GeneratedColumn<String> encryptedMetadataJson =
      GeneratedColumn<String>(
        'encrypted_metadata_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _fileSizeBytesMeta = const VerificationMeta(
    'fileSizeBytes',
  );
  @override
  late final GeneratedColumn<int> fileSizeBytes = GeneratedColumn<int>(
    'file_size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    documentId,
    versionId,
    ownerUid,
    localCiphertextPath,
    encryptedMetadataJson,
    fileSizeBytes,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_documents_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedDocumentsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('document_id')) {
      context.handle(
        _documentIdMeta,
        documentId.isAcceptableOrUnknown(data['document_id']!, _documentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_documentIdMeta);
    }
    if (data.containsKey('version_id')) {
      context.handle(
        _versionIdMeta,
        versionId.isAcceptableOrUnknown(data['version_id']!, _versionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_versionIdMeta);
    }
    if (data.containsKey('owner_uid')) {
      context.handle(
        _ownerUidMeta,
        ownerUid.isAcceptableOrUnknown(data['owner_uid']!, _ownerUidMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerUidMeta);
    }
    if (data.containsKey('local_ciphertext_path')) {
      context.handle(
        _localCiphertextPathMeta,
        localCiphertextPath.isAcceptableOrUnknown(
          data['local_ciphertext_path']!,
          _localCiphertextPathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_localCiphertextPathMeta);
    }
    if (data.containsKey('encrypted_metadata_json')) {
      context.handle(
        _encryptedMetadataJsonMeta,
        encryptedMetadataJson.isAcceptableOrUnknown(
          data['encrypted_metadata_json']!,
          _encryptedMetadataJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_encryptedMetadataJsonMeta);
    }
    if (data.containsKey('file_size_bytes')) {
      context.handle(
        _fileSizeBytesMeta,
        fileSizeBytes.isAcceptableOrUnknown(
          data['file_size_bytes']!,
          _fileSizeBytesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fileSizeBytesMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {documentId, versionId};
  @override
  CachedDocumentsTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedDocumentsTableData(
      documentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_id'],
      )!,
      versionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version_id'],
      )!,
      ownerUid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_uid'],
      )!,
      localCiphertextPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_ciphertext_path'],
      )!,
      encryptedMetadataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encrypted_metadata_json'],
      )!,
      fileSizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_size_bytes'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $CachedDocumentsTableTable createAlias(String alias) {
    return $CachedDocumentsTableTable(attachedDatabase, alias);
  }
}

class CachedDocumentsTableData extends DataClass
    implements Insertable<CachedDocumentsTableData> {
  final String documentId;
  final String versionId;
  final String ownerUid;
  final String localCiphertextPath;
  final String encryptedMetadataJson;
  final int fileSizeBytes;
  final DateTime cachedAt;
  const CachedDocumentsTableData({
    required this.documentId,
    required this.versionId,
    required this.ownerUid,
    required this.localCiphertextPath,
    required this.encryptedMetadataJson,
    required this.fileSizeBytes,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['document_id'] = Variable<String>(documentId);
    map['version_id'] = Variable<String>(versionId);
    map['owner_uid'] = Variable<String>(ownerUid);
    map['local_ciphertext_path'] = Variable<String>(localCiphertextPath);
    map['encrypted_metadata_json'] = Variable<String>(encryptedMetadataJson);
    map['file_size_bytes'] = Variable<int>(fileSizeBytes);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CachedDocumentsTableCompanion toCompanion(bool nullToAbsent) {
    return CachedDocumentsTableCompanion(
      documentId: Value(documentId),
      versionId: Value(versionId),
      ownerUid: Value(ownerUid),
      localCiphertextPath: Value(localCiphertextPath),
      encryptedMetadataJson: Value(encryptedMetadataJson),
      fileSizeBytes: Value(fileSizeBytes),
      cachedAt: Value(cachedAt),
    );
  }

  factory CachedDocumentsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedDocumentsTableData(
      documentId: serializer.fromJson<String>(json['documentId']),
      versionId: serializer.fromJson<String>(json['versionId']),
      ownerUid: serializer.fromJson<String>(json['ownerUid']),
      localCiphertextPath: serializer.fromJson<String>(
        json['localCiphertextPath'],
      ),
      encryptedMetadataJson: serializer.fromJson<String>(
        json['encryptedMetadataJson'],
      ),
      fileSizeBytes: serializer.fromJson<int>(json['fileSizeBytes']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'documentId': serializer.toJson<String>(documentId),
      'versionId': serializer.toJson<String>(versionId),
      'ownerUid': serializer.toJson<String>(ownerUid),
      'localCiphertextPath': serializer.toJson<String>(localCiphertextPath),
      'encryptedMetadataJson': serializer.toJson<String>(encryptedMetadataJson),
      'fileSizeBytes': serializer.toJson<int>(fileSizeBytes),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CachedDocumentsTableData copyWith({
    String? documentId,
    String? versionId,
    String? ownerUid,
    String? localCiphertextPath,
    String? encryptedMetadataJson,
    int? fileSizeBytes,
    DateTime? cachedAt,
  }) => CachedDocumentsTableData(
    documentId: documentId ?? this.documentId,
    versionId: versionId ?? this.versionId,
    ownerUid: ownerUid ?? this.ownerUid,
    localCiphertextPath: localCiphertextPath ?? this.localCiphertextPath,
    encryptedMetadataJson: encryptedMetadataJson ?? this.encryptedMetadataJson,
    fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  CachedDocumentsTableData copyWithCompanion(
    CachedDocumentsTableCompanion data,
  ) {
    return CachedDocumentsTableData(
      documentId: data.documentId.present
          ? data.documentId.value
          : this.documentId,
      versionId: data.versionId.present ? data.versionId.value : this.versionId,
      ownerUid: data.ownerUid.present ? data.ownerUid.value : this.ownerUid,
      localCiphertextPath: data.localCiphertextPath.present
          ? data.localCiphertextPath.value
          : this.localCiphertextPath,
      encryptedMetadataJson: data.encryptedMetadataJson.present
          ? data.encryptedMetadataJson.value
          : this.encryptedMetadataJson,
      fileSizeBytes: data.fileSizeBytes.present
          ? data.fileSizeBytes.value
          : this.fileSizeBytes,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedDocumentsTableData(')
          ..write('documentId: $documentId, ')
          ..write('versionId: $versionId, ')
          ..write('ownerUid: $ownerUid, ')
          ..write('localCiphertextPath: $localCiphertextPath, ')
          ..write('encryptedMetadataJson: $encryptedMetadataJson, ')
          ..write('fileSizeBytes: $fileSizeBytes, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    documentId,
    versionId,
    ownerUid,
    localCiphertextPath,
    encryptedMetadataJson,
    fileSizeBytes,
    cachedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedDocumentsTableData &&
          other.documentId == this.documentId &&
          other.versionId == this.versionId &&
          other.ownerUid == this.ownerUid &&
          other.localCiphertextPath == this.localCiphertextPath &&
          other.encryptedMetadataJson == this.encryptedMetadataJson &&
          other.fileSizeBytes == this.fileSizeBytes &&
          other.cachedAt == this.cachedAt);
}

class CachedDocumentsTableCompanion
    extends UpdateCompanion<CachedDocumentsTableData> {
  final Value<String> documentId;
  final Value<String> versionId;
  final Value<String> ownerUid;
  final Value<String> localCiphertextPath;
  final Value<String> encryptedMetadataJson;
  final Value<int> fileSizeBytes;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const CachedDocumentsTableCompanion({
    this.documentId = const Value.absent(),
    this.versionId = const Value.absent(),
    this.ownerUid = const Value.absent(),
    this.localCiphertextPath = const Value.absent(),
    this.encryptedMetadataJson = const Value.absent(),
    this.fileSizeBytes = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedDocumentsTableCompanion.insert({
    required String documentId,
    required String versionId,
    required String ownerUid,
    required String localCiphertextPath,
    required String encryptedMetadataJson,
    required int fileSizeBytes,
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  }) : documentId = Value(documentId),
       versionId = Value(versionId),
       ownerUid = Value(ownerUid),
       localCiphertextPath = Value(localCiphertextPath),
       encryptedMetadataJson = Value(encryptedMetadataJson),
       fileSizeBytes = Value(fileSizeBytes),
       cachedAt = Value(cachedAt);
  static Insertable<CachedDocumentsTableData> custom({
    Expression<String>? documentId,
    Expression<String>? versionId,
    Expression<String>? ownerUid,
    Expression<String>? localCiphertextPath,
    Expression<String>? encryptedMetadataJson,
    Expression<int>? fileSizeBytes,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (documentId != null) 'document_id': documentId,
      if (versionId != null) 'version_id': versionId,
      if (ownerUid != null) 'owner_uid': ownerUid,
      if (localCiphertextPath != null)
        'local_ciphertext_path': localCiphertextPath,
      if (encryptedMetadataJson != null)
        'encrypted_metadata_json': encryptedMetadataJson,
      if (fileSizeBytes != null) 'file_size_bytes': fileSizeBytes,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedDocumentsTableCompanion copyWith({
    Value<String>? documentId,
    Value<String>? versionId,
    Value<String>? ownerUid,
    Value<String>? localCiphertextPath,
    Value<String>? encryptedMetadataJson,
    Value<int>? fileSizeBytes,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return CachedDocumentsTableCompanion(
      documentId: documentId ?? this.documentId,
      versionId: versionId ?? this.versionId,
      ownerUid: ownerUid ?? this.ownerUid,
      localCiphertextPath: localCiphertextPath ?? this.localCiphertextPath,
      encryptedMetadataJson:
          encryptedMetadataJson ?? this.encryptedMetadataJson,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (versionId.present) {
      map['version_id'] = Variable<String>(versionId.value);
    }
    if (ownerUid.present) {
      map['owner_uid'] = Variable<String>(ownerUid.value);
    }
    if (localCiphertextPath.present) {
      map['local_ciphertext_path'] = Variable<String>(
        localCiphertextPath.value,
      );
    }
    if (encryptedMetadataJson.present) {
      map['encrypted_metadata_json'] = Variable<String>(
        encryptedMetadataJson.value,
      );
    }
    if (fileSizeBytes.present) {
      map['file_size_bytes'] = Variable<int>(fileSizeBytes.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedDocumentsTableCompanion(')
          ..write('documentId: $documentId, ')
          ..write('versionId: $versionId, ')
          ..write('ownerUid: $ownerUid, ')
          ..write('localCiphertextPath: $localCiphertextPath, ')
          ..write('encryptedMetadataJson: $encryptedMetadataJson, ')
          ..write('fileSizeBytes: $fileSizeBytes, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SyncOperationsTableTable syncOperationsTable =
      $SyncOperationsTableTable(this);
  late final $CachedDocumentsTableTable cachedDocumentsTable =
      $CachedDocumentsTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    syncOperationsTable,
    cachedDocumentsTable,
  ];
}

typedef $$SyncOperationsTableTableCreateCompanionBuilder =
    SyncOperationsTableCompanion Function({
      required String operationId,
      required String userId,
      required String deviceId,
      required String operationType,
      required String documentId,
      required String versionId,
      Value<String?> expectedParentVersionId,
      required String encryptedPayloadReference,
      required String status,
      Value<int> retryCount,
      Value<DateTime?> nextAttemptAt,
      required String idempotencyKey,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<String?> lastErrorCode,
      Value<int> rowid,
    });
typedef $$SyncOperationsTableTableUpdateCompanionBuilder =
    SyncOperationsTableCompanion Function({
      Value<String> operationId,
      Value<String> userId,
      Value<String> deviceId,
      Value<String> operationType,
      Value<String> documentId,
      Value<String> versionId,
      Value<String?> expectedParentVersionId,
      Value<String> encryptedPayloadReference,
      Value<String> status,
      Value<int> retryCount,
      Value<DateTime?> nextAttemptAt,
      Value<String> idempotencyKey,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String?> lastErrorCode,
      Value<int> rowid,
    });

class $$SyncOperationsTableTableFilterComposer
    extends Composer<_$AppDatabase, $SyncOperationsTableTable> {
  $$SyncOperationsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get versionId => $composableBuilder(
    column: $table.versionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get expectedParentVersionId => $composableBuilder(
    column: $table.expectedParentVersionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encryptedPayloadReference => $composableBuilder(
    column: $table.encryptedPayloadReference,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncOperationsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncOperationsTableTable> {
  $$SyncOperationsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get versionId => $composableBuilder(
    column: $table.versionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get expectedParentVersionId => $composableBuilder(
    column: $table.expectedParentVersionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encryptedPayloadReference => $composableBuilder(
    column: $table.encryptedPayloadReference,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncOperationsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncOperationsTableTable> {
  $$SyncOperationsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get versionId =>
      $composableBuilder(column: $table.versionId, builder: (column) => column);

  GeneratedColumn<String> get expectedParentVersionId => $composableBuilder(
    column: $table.expectedParentVersionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get encryptedPayloadReference => $composableBuilder(
    column: $table.encryptedPayloadReference,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => column,
  );
}

class $$SyncOperationsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncOperationsTableTable,
          SyncOperationsTableData,
          $$SyncOperationsTableTableFilterComposer,
          $$SyncOperationsTableTableOrderingComposer,
          $$SyncOperationsTableTableAnnotationComposer,
          $$SyncOperationsTableTableCreateCompanionBuilder,
          $$SyncOperationsTableTableUpdateCompanionBuilder,
          (
            SyncOperationsTableData,
            BaseReferences<
              _$AppDatabase,
              $SyncOperationsTableTable,
              SyncOperationsTableData
            >,
          ),
          SyncOperationsTableData,
          PrefetchHooks Function()
        > {
  $$SyncOperationsTableTableTableManager(
    _$AppDatabase db,
    $SyncOperationsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncOperationsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncOperationsTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SyncOperationsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> operationId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> operationType = const Value.absent(),
                Value<String> documentId = const Value.absent(),
                Value<String> versionId = const Value.absent(),
                Value<String?> expectedParentVersionId = const Value.absent(),
                Value<String> encryptedPayloadReference = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<String> idempotencyKey = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> lastErrorCode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncOperationsTableCompanion(
                operationId: operationId,
                userId: userId,
                deviceId: deviceId,
                operationType: operationType,
                documentId: documentId,
                versionId: versionId,
                expectedParentVersionId: expectedParentVersionId,
                encryptedPayloadReference: encryptedPayloadReference,
                status: status,
                retryCount: retryCount,
                nextAttemptAt: nextAttemptAt,
                idempotencyKey: idempotencyKey,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastErrorCode: lastErrorCode,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String operationId,
                required String userId,
                required String deviceId,
                required String operationType,
                required String documentId,
                required String versionId,
                Value<String?> expectedParentVersionId = const Value.absent(),
                required String encryptedPayloadReference,
                required String status,
                Value<int> retryCount = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                required String idempotencyKey,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<String?> lastErrorCode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncOperationsTableCompanion.insert(
                operationId: operationId,
                userId: userId,
                deviceId: deviceId,
                operationType: operationType,
                documentId: documentId,
                versionId: versionId,
                expectedParentVersionId: expectedParentVersionId,
                encryptedPayloadReference: encryptedPayloadReference,
                status: status,
                retryCount: retryCount,
                nextAttemptAt: nextAttemptAt,
                idempotencyKey: idempotencyKey,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastErrorCode: lastErrorCode,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncOperationsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncOperationsTableTable,
      SyncOperationsTableData,
      $$SyncOperationsTableTableFilterComposer,
      $$SyncOperationsTableTableOrderingComposer,
      $$SyncOperationsTableTableAnnotationComposer,
      $$SyncOperationsTableTableCreateCompanionBuilder,
      $$SyncOperationsTableTableUpdateCompanionBuilder,
      (
        SyncOperationsTableData,
        BaseReferences<
          _$AppDatabase,
          $SyncOperationsTableTable,
          SyncOperationsTableData
        >,
      ),
      SyncOperationsTableData,
      PrefetchHooks Function()
    >;
typedef $$CachedDocumentsTableTableCreateCompanionBuilder =
    CachedDocumentsTableCompanion Function({
      required String documentId,
      required String versionId,
      required String ownerUid,
      required String localCiphertextPath,
      required String encryptedMetadataJson,
      required int fileSizeBytes,
      required DateTime cachedAt,
      Value<int> rowid,
    });
typedef $$CachedDocumentsTableTableUpdateCompanionBuilder =
    CachedDocumentsTableCompanion Function({
      Value<String> documentId,
      Value<String> versionId,
      Value<String> ownerUid,
      Value<String> localCiphertextPath,
      Value<String> encryptedMetadataJson,
      Value<int> fileSizeBytes,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

class $$CachedDocumentsTableTableFilterComposer
    extends Composer<_$AppDatabase, $CachedDocumentsTableTable> {
  $$CachedDocumentsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get versionId => $composableBuilder(
    column: $table.versionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerUid => $composableBuilder(
    column: $table.ownerUid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localCiphertextPath => $composableBuilder(
    column: $table.localCiphertextPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encryptedMetadataJson => $composableBuilder(
    column: $table.encryptedMetadataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileSizeBytes => $composableBuilder(
    column: $table.fileSizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedDocumentsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedDocumentsTableTable> {
  $$CachedDocumentsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get versionId => $composableBuilder(
    column: $table.versionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerUid => $composableBuilder(
    column: $table.ownerUid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localCiphertextPath => $composableBuilder(
    column: $table.localCiphertextPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encryptedMetadataJson => $composableBuilder(
    column: $table.encryptedMetadataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileSizeBytes => $composableBuilder(
    column: $table.fileSizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedDocumentsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedDocumentsTableTable> {
  $$CachedDocumentsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get versionId =>
      $composableBuilder(column: $table.versionId, builder: (column) => column);

  GeneratedColumn<String> get ownerUid =>
      $composableBuilder(column: $table.ownerUid, builder: (column) => column);

  GeneratedColumn<String> get localCiphertextPath => $composableBuilder(
    column: $table.localCiphertextPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get encryptedMetadataJson => $composableBuilder(
    column: $table.encryptedMetadataJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fileSizeBytes => $composableBuilder(
    column: $table.fileSizeBytes,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CachedDocumentsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedDocumentsTableTable,
          CachedDocumentsTableData,
          $$CachedDocumentsTableTableFilterComposer,
          $$CachedDocumentsTableTableOrderingComposer,
          $$CachedDocumentsTableTableAnnotationComposer,
          $$CachedDocumentsTableTableCreateCompanionBuilder,
          $$CachedDocumentsTableTableUpdateCompanionBuilder,
          (
            CachedDocumentsTableData,
            BaseReferences<
              _$AppDatabase,
              $CachedDocumentsTableTable,
              CachedDocumentsTableData
            >,
          ),
          CachedDocumentsTableData,
          PrefetchHooks Function()
        > {
  $$CachedDocumentsTableTableTableManager(
    _$AppDatabase db,
    $CachedDocumentsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedDocumentsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedDocumentsTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CachedDocumentsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> documentId = const Value.absent(),
                Value<String> versionId = const Value.absent(),
                Value<String> ownerUid = const Value.absent(),
                Value<String> localCiphertextPath = const Value.absent(),
                Value<String> encryptedMetadataJson = const Value.absent(),
                Value<int> fileSizeBytes = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedDocumentsTableCompanion(
                documentId: documentId,
                versionId: versionId,
                ownerUid: ownerUid,
                localCiphertextPath: localCiphertextPath,
                encryptedMetadataJson: encryptedMetadataJson,
                fileSizeBytes: fileSizeBytes,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String documentId,
                required String versionId,
                required String ownerUid,
                required String localCiphertextPath,
                required String encryptedMetadataJson,
                required int fileSizeBytes,
                required DateTime cachedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedDocumentsTableCompanion.insert(
                documentId: documentId,
                versionId: versionId,
                ownerUid: ownerUid,
                localCiphertextPath: localCiphertextPath,
                encryptedMetadataJson: encryptedMetadataJson,
                fileSizeBytes: fileSizeBytes,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedDocumentsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedDocumentsTableTable,
      CachedDocumentsTableData,
      $$CachedDocumentsTableTableFilterComposer,
      $$CachedDocumentsTableTableOrderingComposer,
      $$CachedDocumentsTableTableAnnotationComposer,
      $$CachedDocumentsTableTableCreateCompanionBuilder,
      $$CachedDocumentsTableTableUpdateCompanionBuilder,
      (
        CachedDocumentsTableData,
        BaseReferences<
          _$AppDatabase,
          $CachedDocumentsTableTable,
          CachedDocumentsTableData
        >,
      ),
      CachedDocumentsTableData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SyncOperationsTableTableTableManager get syncOperationsTable =>
      $$SyncOperationsTableTableTableManager(_db, _db.syncOperationsTable);
  $$CachedDocumentsTableTableTableManager get cachedDocumentsTable =>
      $$CachedDocumentsTableTableTableManager(_db, _db.cachedDocumentsTable);
}
