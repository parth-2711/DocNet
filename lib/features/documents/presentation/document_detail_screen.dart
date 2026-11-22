import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:docnet/core/storage/local_vault_storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../activity/domain/entities/activity_event.dart';
import '../../activity/presentation/controllers/activity_controller.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../family/presentation/controllers/family_controller.dart';
import '../domain/entities/document_record.dart';
import '../domain/entities/document_version.dart';
import '../domain/usecases/download_and_decrypt_usecase.dart';
import 'controllers/documents_controller.dart';

/// Document Detail Screen matching THEME.md Section 11 and PRD.md DOC-015, DOC-016, VER-005.
class DocumentDetailScreen extends ConsumerStatefulWidget {
  final String documentId;

  const DocumentDetailScreen({super.key, required this.documentId});

  @override
  ConsumerState<DocumentDetailScreen> createState() =>
      _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends ConsumerState<DocumentDetailScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  DocumentRecord? _document;
  List<DocumentVersion> _versions = [];
  DecryptedDocumentResult? _decryptedResult;

  @override
  void initState() {
    super.initState();
    _loadDocumentAndDecrypt();
  }

  Future<void> _loadDocumentAndDecrypt() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final docRepo = ref.read(documentRepositoryProvider);
      final downloadUseCase = ref.read(downloadAndDecryptUseCaseProvider);
      final authState = ref.read(authControllerProvider);
      final uid = authState.userProfile?.uid ?? 'guest-uid';

      final doc = await docRepo.getDocumentById(widget.documentId);
      if (doc == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Document not found';
        });
        return;
      }

      final versions = await docRepo.getVersions(widget.documentId);

      if (mounted) {
        setState(() {
          _document = doc;
          _versions = versions;
        });
      }

      // Decrypt on-device
      final decrypted = await downloadUseCase.execute(
        documentId: widget.documentId,
        recipientUid: uid,
      );

      if (mounted) {
        setState(() {
          _decryptedResult = decrypted;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _showReplaceDialog() {
    final messenger = ScaffoldMessenger.of(context);
    final formKey = GlobalKey<FormState>();
    final noteController = TextEditingController();
    Uint8List? newPickedBytes;
    String? newPickedFileName;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Replace Document Version'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Replacing creates a new immutable version (v${_versions.length + 1}). Prior versions remain intact in history.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.standard),
                OutlinedButton.icon(
                  icon: const Icon(Icons.attach_file),
                  label: Text(
                    newPickedBytes != null
                        ? 'Selected: $newPickedFileName'
                        : 'Pick New File from Device',
                  ),
                  onPressed: () async {
                    try {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
                        withData: true,
                      );
                      if (result != null && result.files.isNotEmpty) {
                        final file = result.files.single;
                        Uint8List? bytes = file.bytes;
                        if (bytes == null && file.path != null) {
                          bytes = await File(file.path!).readAsBytes();
                        }
                        if (bytes != null) {
                          setState(() {
                            newPickedBytes = bytes;
                            newPickedFileName = file.name;
                          });
                        }
                      }
                    } catch (_) {}
                  },
                ),
                const SizedBox(height: AppSpacing.standard),
                TextFormField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Change Note (Optional)',
                    hintText: 'e.g. Updated renewal copy',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogCtx);
                final authState = ref.read(authControllerProvider);
                final uid = authState.userProfile?.uid ?? 'guest-uid';
                final uploadUseCase = ref.read(uploadDocumentUseCaseProvider);

                final newBytes =
                    newPickedBytes ??
                    utf8.encode(
                      'Updated replacement content for ${_document?.decryptedName} at ${DateTime.now()}',
                    );

                await uploadUseCase.execute(
                  fileBytes: newBytes,
                  fileName:
                      newPickedFileName ??
                      _document?.decryptedName ??
                      'Document.pdf',
                  category: _document?.category ?? 'Identity',
                  ownerUid: uid,
                  existingDocumentId: _document?.documentId,
                  expectedParentVersionId: _document?.currentVersionId,
                  description: noteController.text.trim().isEmpty
                      ? null
                      : noteController.text.trim(),
                );

                await _loadDocumentAndDecrypt();
                if (!mounted) return;
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('New version created and encrypted.'),
                  ),
                );
              },
              child: const Text('Confirm Replacement'),
            ),
          ],
        ),
      ),
    );
  }

  void _showExportWarning() {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Export Unencrypted Copy'),
        content: const Text(
          'Warning: Exporting will decrypt this file and save it in plaintext outside FamilyVault. Once exported, FamilyVault cannot control subsequent copying or unauthorized access.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.lightWarning,
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              if (_document != null && _decryptedResult != null) {
                try {
                  final storageService = ref.read(
                    localVaultStorageServiceProvider,
                  );
                  final tempFile = await storageService
                      .writeTemporaryDecryptedFile(
                        fileName:
                            _document!.decryptedName ?? 'ExportedDocument.pdf',
                        bytes: _decryptedResult!.plaintextBytes,
                      );

                  await Share.shareXFiles(
                    [XFile(tempFile.path)],
                    text:
                        'Exported from FamilyVault: ${_document!.decryptedName}',
                  );

                  ref
                      .read(activityRepositoryProvider)
                      .logEvent(
                        ActivityEvent(
                          activityId: const Uuid().v4(),
                          actorUid: _document!.ownerUid,
                          targetDocumentId: _document!.documentId,
                          eventType: ActivityEventType.documentExported,
                          summary:
                              'Decrypted file exported via system share sheet',
                          timestamp: DateTime.now().toUtc(),
                        ),
                      );

                  if (!mounted) return;
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Decrypted file exported successfully.'),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(content: Text('Export failed: $e')),
                  );
                }
              }
            },
            child: const Text('Export Anyway'),
          ),
        ],
      ),
    );
  }

  void _showShareDialog() {
    final messenger = ScaffoldMessenger.of(context);
    final familyState = ref.read(familyControllerProvider);
    final members = familyState.members
        .where((m) => m.uid != _document?.ownerUid)
        .toList();

    if (members.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'No other members in your family space to share with. Invite a member in the Family tab first.',
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Share with Family Member'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(member.displayName.substring(0, 1).toUpperCase()),
                ),
                title: Text(member.displayName),
                subtitle: Text(member.email),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () async {
                  Navigator.pop(dialogCtx);
                  final shareUseCase = ref.read(shareDocumentUseCaseProvider);
                  final authState = ref.read(authControllerProvider);
                  final granterUid = authState.userProfile?.uid ?? 'guest-uid';

                  await shareUseCase.execute(
                    documentId: _document!.documentId,
                    granterUid: granterUid,
                    recipientUid: member.uid,
                    canView: true,
                    canDownload: false, // Least privilege default (SHARE-003)
                  );

                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Key envelope generated for ${member.displayName}. View access granted.',
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteConfirmDialog() async {
    final docId = widget.documentId;
    final docName = _document?.decryptedName ?? 'this document';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Document?'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "$docName"?\n\nThis document will be moved to trash and removed from your vault.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(documentsControllerProvider.notifier).deleteDocument(
          documentId: docId,
          ownerUid: _document?.ownerUid,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"$docName" moved to trash'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () {
                  ref
                      .read(documentsControllerProvider.notifier)
                      .restoreDocument(docId);
                },
              ),
            ),
          );
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete document: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_document?.decryptedName ?? 'Document Details'),
        actions: [
          IconButton(
            icon: Icon(
              _document?.isFavorite == true ? Icons.star : Icons.star_border,
              color: _document?.isFavorite == true ? Colors.amber : null,
            ),
            tooltip: _document?.isFavorite == true ? 'Unfavorite' : 'Favorite',
            onPressed: _document == null
                ? null
                : () async {
                    await ref
                        .read(documentsControllerProvider.notifier)
                        .toggleFavorite(_document!.documentId);
                    setState(() {
                      _document = _document!.copyWith(
                        isFavorite: !_document!.isFavorite,
                      );
                    });
                  },
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share with Family',
            onPressed: _document == null ? null : _showShareDialog,
          ),
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: 'Replace Version',
            onPressed: _document == null ? null : _showReplaceDialog,
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export Plaintext',
            onPressed: _decryptedResult == null ? null : _showExportWarning,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Delete',
            onPressed: _showDeleteConfirmDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.large),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: AppSpacing.standard),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    const SizedBox(height: AppSpacing.large),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Retry'),
                          onPressed: _loadDocumentAndDecrypt,
                        ),
                        const SizedBox(width: AppSpacing.standard),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                          ),
                          label: const Text('Delete Document'),
                          onPressed: _showDeleteConfirmDialog,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.standard),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Decrypted Preview Container
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.large),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurface
                          : AppColors.lightSurface,
                      borderRadius: AppRadius.inputBorderRadius,
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkOutline
                            : AppColors.lightOutline,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _document?.mimeType == 'application/pdf'
                              ? Icons.picture_as_pdf_outlined
                              : Icons.image_outlined,
                          size: 48,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: AppSpacing.standard),
                        Text(
                          _document?.decryptedName ?? 'Document',
                          style: theme.textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.compact),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkPrimaryContainer
                                : AppColors.lightPrimaryContainer,
                            borderRadius: AppRadius.pillBorderRadius,
                          ),
                          child: Text(
                            'Decrypted on this device',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppColors.darkPrimary
                                  : AppColors.lightPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.standard),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Open in Device Viewer'),
                          onPressed: _decryptedResult == null
                              ? null
                              : () async {
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  try {
                                    final storageService = ref.read(
                                      localVaultStorageServiceProvider,
                                    );
                                    final tempFile = await storageService
                                        .writeTemporaryDecryptedFile(
                                          fileName:
                                              _document?.decryptedName ??
                                              'Document.pdf',
                                          bytes:
                                              _decryptedResult!.plaintextBytes,
                                        );
                                    final openResult = await OpenFilex.open(
                                      tempFile.path,
                                    );
                                    if (!mounted) return;
                                    if (openResult.type != ResultType.done) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Opened with status: ${openResult.message}',
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (!mounted) return;
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Could not open file: $e',
                                        ),
                                      ),
                                    );
                                  }
                                },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.section),

                  // Metadata Summary
                  Text('Metadata', style: theme.textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.compact),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.standard),
                      child: Column(
                        children: [
                          _MetaRow(
                            label: 'Category',
                            value: _document?.category ?? 'Other',
                          ),
                          const Divider(),
                          _MetaRow(
                            label: 'Original Size',
                            value:
                                '${((_document?.originalSizeBytes ?? 0) / 1024).toStringAsFixed(1)} KB',
                          ),
                          const Divider(),
                          _MetaRow(
                            label: 'Encrypted Container Size',
                            value:
                                '${((_document?.encryptedSizeBytes ?? 0) / 1024).toStringAsFixed(1)} KB',
                          ),
                          const Divider(),
                          _MetaRow(
                            label: 'Format',
                            value: _document?.mimeType ?? 'Unknown',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.section),

                  // Version History (VER-005)
                  Text(
                    'Version History (${_versions.length})',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.compact),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _versions.length,
                    itemBuilder: (context, index) {
                      final v = _versions[index];
                      final isCurrent =
                          v.versionId == _document?.currentVersionId;

                      return Card(
                        margin: const EdgeInsets.only(
                          bottom: AppSpacing.compact,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isCurrent
                                ? (isDark
                                      ? AppColors.darkPrimary
                                      : AppColors.lightPrimary)
                                : (isDark
                                      ? AppColors.darkOutline
                                      : AppColors.lightOutline),
                            foregroundColor: Colors.white,
                            child: Text('v${v.versionNumber}'),
                          ),
                          title: Row(
                            children: [
                              Text('Version ${v.versionNumber}'),
                              if (isCurrent) ...[
                                const SizedBox(width: AppSpacing.compact),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.lightSuccess.withAlpha(30),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Current',
                                    style: TextStyle(
                                      color: AppColors.lightSuccess,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            'SHA-256: ${v.sha256.substring(0, 16)}...\nParent: ${v.parentVersionId == null ? 'Root (Initial)' : 'v${v.versionNumber - 1}'}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
