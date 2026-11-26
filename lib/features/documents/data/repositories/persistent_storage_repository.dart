import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:docnet/core/logging/app_logger.dart';
import 'package:docnet/core/storage/local_vault_storage_service.dart';
import '../../domain/repositories/storage_repository.dart';

/// Persistent implementation of StorageRepository saving encrypted binary objects
/// directly to the on-device secure file system, with optional chunked Firestore
/// encrypted blob sync for cross-device sharing (PRD.md DOC-017, SYNC_ENGINE.md Section 6).
class PersistentStorageRepository implements StorageRepository {
  final LocalVaultStorageService storageService;

  static const int _chunkCharLimit = 600000;

  PersistentStorageRepository(this.storageService);

  static bool get _isTestEnvironment =>
      Platform.environment.containsKey('FLUTTER_TEST') ||
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  bool get _canUseFirestore => Firebase.apps.isNotEmpty && !_isTestEnvironment;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  String _safeBlobDocId(String objectRef) =>
      objectRef.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

  @override
  Future<void> putObject({
    required String objectRef,
    required Uint8List data,
  }) async {
    await storageService.saveObject(objectRef, data);
  }

  @override
  Future<void> syncObjectToCloud(String objectRef) async {
    if (!_canUseFirestore) return;
    final data = await storageService.getObject(objectRef);
    if (data == null) return;

    try {
      final docId = _safeBlobDocId(objectRef);
      final encoded = base64Encode(data);
      final docRef = _firestore.collection('shared_blobs').doc(docId);

      if (encoded.length <= _chunkCharLimit) {
        await docRef.set({
          'objectRef': objectRef,
          'chunkCount': 0,
          'inlineData': encoded,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        });
      } else {
        final totalChunks = (encoded.length / _chunkCharLimit).ceil();
        for (int i = 0; i < totalChunks; i++) {
          final start = i * _chunkCharLimit;
          final end = (start + _chunkCharLimit < encoded.length)
              ? start + _chunkCharLimit
              : encoded.length;
          await docRef.collection('chunks').doc('chunk_$i').set({
            'index': i,
            'data': encoded.substring(start, end),
          });
        }
        await docRef.set({
          'objectRef': objectRef,
          'chunkCount': totalChunks,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        });
      }
      AppLogger.info(
        'PersistentStorageRepository',
        'Synced encrypted blob $docId to Firestore',
      );
    } catch (e) {
      AppLogger.warn(
        'PersistentStorageRepository',
        'Failed to sync encrypted blob to Firestore: $e',
      );
    }
  }

  @override
  Future<Uint8List?> getObject(String objectRef) async {
    final local = await storageService.getObject(objectRef);
    if (local != null) return local;

    if (_canUseFirestore) {
      try {
        final docId = _safeBlobDocId(objectRef);
        final docRef = _firestore.collection('shared_blobs').doc(docId);
        final docSnap = await docRef.get();
        if (docSnap.exists && docSnap.data() != null) {
          final map = docSnap.data()!;
          final chunkCount = map['chunkCount'] as int? ?? 0;
          String? fullBase64;
          if (chunkCount == 0 && map['inlineData'] is String) {
            fullBase64 = map['inlineData'] as String;
          } else if (chunkCount > 0) {
            final buffer = StringBuffer();
            for (int i = 0; i < chunkCount; i++) {
              final chunkSnap = await docRef
                  .collection('chunks')
                  .doc('chunk_$i')
                  .get();
              final part = chunkSnap.data()?['data'] as String?;
              if (part == null) return null;
              buffer.write(part);
            }
            fullBase64 = buffer.toString();
          }

          if (fullBase64 != null) {
            final bytes = Uint8List.fromList(base64Decode(fullBase64));
            await storageService.saveObject(objectRef, bytes);
            return bytes;
          }
        }
      } catch (e) {
        AppLogger.warn(
          'PersistentStorageRepository',
          'Failed to fetch encrypted blob from Firestore: $e',
        );
      }
    }

    return null;
  }

  @override
  Future<bool> objectExists(String objectRef) async {
    return await storageService.objectExists(objectRef);
  }

  @override
  Future<void> deleteObject(String objectRef) async {
    await storageService.deleteObject(objectRef);
  }

  @override
  Future<void> clearAll() async {
    // Retained for tests and reset workflows
  }
}
