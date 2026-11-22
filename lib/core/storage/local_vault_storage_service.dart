import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../logging/app_logger.dart';

/// Global provider for the persistent local vault storage service.
final localVaultStorageServiceProvider = Provider<LocalVaultStorageService>((
  ref,
) {
  final service = LocalVaultStorageService();
  service.init();
  return service;
});

/// Manages persistent on-device local storage for encrypted vault blobs,
/// metadata state, and temporary decrypted preview buffers (PRD.md DOC-017, KEY-005).
class LocalVaultStorageService {
  Directory? _baseDir;
  Directory? _objectsDir;
  Directory? _metadataDir;
  Directory? _tempDir;
  bool _initialized = false;

  /// In-memory cache for fast synchronous access during application runtime
  final Map<String, Uint8List> _memoryObjectCache = {};

  LocalVaultStorageService() {
    final isTest =
        Platform.environment.containsKey('FLUTTER_TEST') ||
        Platform.script.toString().contains('_test.dart') ||
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (isTest) {
      _initSyncForTest();
    }
  }

  void _initSyncForTest() {
    if (_initialized) return;
    final testDir = Directory.systemTemp.createTempSync('family_vault_test_');
    _baseDir = Directory(p.join(testDir.path, 'family_vault'));
    _objectsDir = Directory(p.join(_baseDir!.path, 'objects'))
      ..createSync(recursive: true);
    _metadataDir = Directory(p.join(_baseDir!.path, 'metadata'))
      ..createSync(recursive: true);
    _tempDir = Directory(p.join(testDir.path, 'family_vault_temp'))
      ..createSync(recursive: true);
    _initialized = true;
  }

  Future<void> init() async {
    if (_initialized) return;

    try {
      final isTest =
          Platform.environment.containsKey('FLUTTER_TEST') ||
          Platform.script.toString().contains('_test.dart') ||
          WidgetsBinding.instance.runtimeType.toString().contains('Test');

      if (isTest) {
        _initSyncForTest();
        return;
      }

      final appDocDir = await getApplicationDocumentsDirectory().timeout(
        const Duration(seconds: 2),
        onTimeout: () =>
            Directory.systemTemp.createTempSync('family_vault_doc_'),
      );
      _baseDir = Directory(p.join(appDocDir.path, 'family_vault'));
      _objectsDir = Directory(p.join(_baseDir!.path, 'objects'));
      _metadataDir = Directory(p.join(_baseDir!.path, 'metadata'));

      final cacheDir = await getTemporaryDirectory().timeout(
        const Duration(seconds: 2),
        onTimeout: () =>
            Directory.systemTemp.createTempSync('family_vault_tmp_'),
      );
      _tempDir = Directory(p.join(cacheDir.path, 'family_vault_temp'));

      await _objectsDir!.create(recursive: true);
      await _metadataDir!.create(recursive: true);
      await _tempDir!.create(recursive: true);

      _initialized = true;
      AppLogger.info(
        'LocalVaultStorageService',
        'Persistent vault initialized at ${_baseDir!.path}',
      );
    } catch (e) {
      AppLogger.warn(
        'LocalVaultStorageService',
        'Failed to initialize filesystem storage; falling back to in-memory: $e',
      );
      _initialized = false;
    }
  }

  String _sanitizeRef(String objectRef) {
    return objectRef.replaceAll(RegExp(r'[\\/:]'), '_');
  }

  Future<void> saveObject(String objectRef, Uint8List data) async {
    _memoryObjectCache[objectRef] = data;

    if (!_initialized) await init();
    if (_objectsDir == null) return;

    try {
      final filename = _sanitizeRef(objectRef);
      final file = File(p.join(_objectsDir!.path, filename));
      await file.writeAsBytes(data, flush: true);
    } catch (e) {
      AppLogger.warn(
        'LocalVaultStorageService',
        'Error saving object to disk: $e',
      );
    }
  }

  Future<Uint8List?> getObject(String objectRef) async {
    if (_memoryObjectCache.containsKey(objectRef)) {
      return _memoryObjectCache[objectRef];
    }

    if (!_initialized) await init();
    if (_objectsDir == null) return null;

    try {
      final filename = _sanitizeRef(objectRef);
      final file = File(p.join(_objectsDir!.path, filename));
      if (await file.exists()) {
        final data = await file.readAsBytes();
        _memoryObjectCache[objectRef] = data;
        return data;
      }

      // Suffix fallback: if storageObjectRef has a different UID prefix,
      // match by the immutable versionId/filename suffix.
      if (await _objectsDir!.exists()) {
        final verSuffix = filename.contains('_versions_')
            ? filename.split('_versions_').last
            : filename;
        for (final entry in _objectsDir!.listSync()) {
          if (entry is File) {
            final entryName = p.basename(entry.path);
            if (entryName.endsWith(verSuffix) ||
                (verSuffix.length > 10 && entryName.contains(verSuffix))) {
              final data = await entry.readAsBytes();
              _memoryObjectCache[objectRef] = data;
              return data;
            }
          }
        }
      }
    } catch (e) {
      AppLogger.warn(
        'LocalVaultStorageService',
        'Error reading object from disk: $e',
      );
    }
    return null;
  }

  Future<bool> objectExists(String objectRef) async {
    if (_memoryObjectCache.containsKey(objectRef)) return true;

    if (!_initialized) await init();
    if (_objectsDir == null) return false;

    try {
      final filename = _sanitizeRef(objectRef);
      final file = File(p.join(_objectsDir!.path, filename));
      if (await file.exists()) return true;

      // Suffix fallback
      if (await _objectsDir!.exists()) {
        final verSuffix = filename.contains('_versions_')
            ? filename.split('_versions_').last
            : filename;
        for (final entry in _objectsDir!.listSync()) {
          if (entry is File) {
            final entryName = p.basename(entry.path);
            if (entryName.endsWith(verSuffix) ||
                (verSuffix.length > 10 && entryName.contains(verSuffix))) {
              return true;
            }
          }
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> deleteObject(String objectRef) async {
    _memoryObjectCache.remove(objectRef);

    if (!_initialized) await init();
    if (_objectsDir == null) return;

    try {
      final filename = _sanitizeRef(objectRef);
      final file = File(p.join(_objectsDir!.path, filename));
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      AppLogger.warn('LocalVaultStorageService', 'Error deleting object: $e');
    }
  }

  Future<void> saveJson(String name, dynamic data) async {
    if (!_initialized) await init();
    if (_metadataDir == null) return;

    try {
      final file = File(p.join(_metadataDir!.path, '$name.json'));
      final encoded = jsonEncode(data);
      file.writeAsStringSync(encoded, flush: true);
    } catch (e) {
      AppLogger.warn(
        'LocalVaultStorageService',
        'Error saving JSON metadata $name: $e',
      );
    }
  }

  Future<dynamic> readJson(String name) async {
    if (!_initialized) await init();
    if (_metadataDir == null) return null;

    try {
      final file = File(p.join(_metadataDir!.path, '$name.json'));
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        return jsonDecode(content);
      }
    } catch (e) {
      AppLogger.warn(
        'LocalVaultStorageService',
        'Error reading JSON metadata $name: $e',
      );
    }
    return null;
  }

  /// Writes a temporary decrypted file so external applications (e.g. PDF viewer)
  /// or system share sheets can access it. Automatically located in app cache.
  Future<File> writeTemporaryDecryptedFile({
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (!_initialized) await init();
    Directory tempTarget = _tempDir ?? Directory.systemTemp;

    final sanitizedName = p.basename(fileName);
    final file = File(p.join(tempTarget.path, sanitizedName));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Cleans up all temporary decrypted files from device cache (THEME.md Section 11)
  Future<void> clearTemporaryDecryptedFiles() async {
    if (!_initialized) await init();
    if (_tempDir != null && await _tempDir!.exists()) {
      try {
        final entries = _tempDir!.listSync();
        for (final entry in entries) {
          if (entry is File) {
            await entry.delete();
          }
        }
        AppLogger.info(
          'LocalVaultStorageService',
          'Cleaned up temporary decrypted cache files',
        );
      } catch (e) {
        AppLogger.warn(
          'LocalVaultStorageService',
          'Error cleaning temp files: $e',
        );
      }
    }
  }
}
