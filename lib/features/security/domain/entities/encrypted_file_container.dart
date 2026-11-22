import 'dart:convert';
import 'dart:typed_data';

/// Encrypted file container implementing the zero-knowledge specification
/// defined in ENCRYPTION.md Section 4 & 6.
///
/// Magic Header: 4 bytes ('F', 'V', 'L', 'T')
/// Format version: 1 byte (0x01)
/// Nonce length: 1 byte (12 bytes for AES-256-GCM)
/// MAC tag length: 1 byte (16 bytes)
/// Metadata AAD payload (canonical): documentId, versionId, ownerUid, keyEpoch
/// Ciphertext payload
class EncryptedFileContainer {
  static const List<int> magicBytes = [0x46, 0x56, 0x4C, 0x54]; // 'FVLT'
  static const int currentFormatVersion = 1;

  final int formatVersion;
  final String documentId;
  final String versionId;
  final String ownerUid;
  final int keyEpoch;
  final Uint8List nonce;
  final Uint8List cipherText;
  final Uint8List macTag;

  const EncryptedFileContainer({
    this.formatVersion = currentFormatVersion,
    required this.documentId,
    required this.versionId,
    required this.ownerUid,
    this.keyEpoch = 1,
    required this.nonce,
    required this.cipherText,
    required this.macTag,
  });

  /// Canonical Associated Authenticated Data (AAD) format defined in ENCRYPTION.md Section 6.
  /// Binds document ID, version ID, owner UID, format version, and key epoch to ciphertext.
  Uint8List computeAAD() {
    final canonicalString =
        'FVLT-AAD:v$formatVersion|$ownerUid|$documentId|$versionId|$keyEpoch';
    return Uint8List.fromList(utf8.encode(canonicalString));
  }

  /// Serializes the container into a binary format suitable for cloud object storage.
  Uint8List toBinary() {
    final docIdBytes = utf8.encode(documentId);
    final verIdBytes = utf8.encode(versionId);
    final ownerUidBytes = utf8.encode(ownerUid);

    final totalSize =
        4 + // Magic bytes
        1 + // Format version
        4 + // keyEpoch (int32)
        1 + // nonce length
        nonce.length +
        1 + // macTag length
        macTag.length +
        2 + // docId length (uint16)
        docIdBytes.length +
        2 + // verId length (uint16)
        verIdBytes.length +
        2 + // ownerUid length (uint16)
        ownerUidBytes.length +
        4 + // cipherText length (uint32)
        cipherText.length;

    final buffer = ByteData(totalSize);
    var offset = 0;

    // Write Magic Bytes
    for (var b in magicBytes) {
      buffer.setUint8(offset++, b);
    }

    // Format Version
    buffer.setUint8(offset++, formatVersion);

    // Key Epoch
    buffer.setUint32(offset, keyEpoch);
    offset += 4;

    // Nonce
    buffer.setUint8(offset++, nonce.length);
    for (var b in nonce) {
      buffer.setUint8(offset++, b);
    }

    // MAC Tag
    buffer.setUint8(offset++, macTag.length);
    for (var b in macTag) {
      buffer.setUint8(offset++, b);
    }

    // Document ID
    buffer.setUint16(offset, docIdBytes.length);
    offset += 2;
    for (var b in docIdBytes) {
      buffer.setUint8(offset++, b);
    }

    // Version ID
    buffer.setUint16(offset, verIdBytes.length);
    offset += 2;
    for (var b in verIdBytes) {
      buffer.setUint8(offset++, b);
    }

    // Owner UID
    buffer.setUint16(offset, ownerUidBytes.length);
    offset += 2;
    for (var b in ownerUidBytes) {
      buffer.setUint8(offset++, b);
    }

    // Ciphertext
    buffer.setUint32(offset, cipherText.length);
    offset += 4;
    for (var b in cipherText) {
      buffer.setUint8(offset++, b);
    }

    return buffer.buffer.asUint8List();
  }

  /// Deserializes binary container into an EncryptedFileContainer instance.
  factory EncryptedFileContainer.fromBinary(Uint8List bytes) {
    if (bytes.length < 24) {
      throw const FormatException(
        'Invalid EncryptedFileContainer: payload too short',
      );
    }

    final data = ByteData.sublistView(bytes);
    var offset = 0;

    // Verify Magic Bytes
    for (var i = 0; i < 4; i++) {
      if (data.getUint8(offset++) != magicBytes[i]) {
        throw const FormatException(
          'Invalid EncryptedFileContainer magic header',
        );
      }
    }

    final formatVer = data.getUint8(offset++);
    if (formatVer != currentFormatVersion) {
      throw FormatException(
        'Unsupported EncryptedFileContainer format version: $formatVer',
      );
    }

    final epoch = data.getUint32(offset);
    offset += 4;

    // Nonce
    final nonceLen = data.getUint8(offset++);
    final nonce = Uint8List.sublistView(bytes, offset, offset + nonceLen);
    offset += nonceLen;

    // MAC Tag
    final macLen = data.getUint8(offset++);
    final macTag = Uint8List.sublistView(bytes, offset, offset + macLen);
    offset += macLen;

    // Document ID
    final docIdLen = data.getUint16(offset);
    offset += 2;
    final docId = utf8.decode(bytes.sublist(offset, offset + docIdLen));
    offset += docIdLen;

    // Version ID
    final verIdLen = data.getUint16(offset);
    offset += 2;
    final verId = utf8.decode(bytes.sublist(offset, offset + verIdLen));
    offset += verIdLen;

    // Owner UID
    final ownerUidLen = data.getUint16(offset);
    offset += 2;
    final ownerUid = utf8.decode(bytes.sublist(offset, offset + ownerUidLen));
    offset += ownerUidLen;

    // Ciphertext
    final cipherLen = data.getUint32(offset);
    offset += 4;
    final cipherText = Uint8List.sublistView(bytes, offset, offset + cipherLen);

    return EncryptedFileContainer(
      formatVersion: formatVer,
      documentId: docId,
      versionId: verId,
      ownerUid: ownerUid,
      keyEpoch: epoch,
      nonce: nonce,
      cipherText: cipherText,
      macTag: macTag,
    );
  }
}
