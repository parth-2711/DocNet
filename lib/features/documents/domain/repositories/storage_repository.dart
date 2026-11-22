import 'dart:typed_data';

/// Cloud / local object store contract for encrypted file containers (ARCHITECTURE.md Section 4 & 6).
abstract class StorageRepository {
  /// Stores encrypted binary bytes at the specified object reference.
  Future<void> putObject({required String objectRef, required Uint8List data});

  /// Retrieves encrypted binary bytes from the specified object reference.
  Future<Uint8List?> getObject(String objectRef);

  /// Checks whether an object exists at the reference.
  Future<bool> objectExists(String objectRef);

  /// Deletes stored object at reference.
  Future<void> deleteObject(String objectRef);

  /// Clears all stored objects (e.g. for testing / account wipe).
  Future<void> clearAll();
}
