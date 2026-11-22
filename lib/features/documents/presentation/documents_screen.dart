import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../sync/domain/entities/conflict_resolution.dart';
import '../../sync/domain/entities/sync_operation.dart';
import '../../sync/presentation/controllers/sync_controller.dart';
import '../domain/entities/document_record.dart';
import '../domain/services/document_search_engine.dart';
import 'controllers/documents_controller.dart';
import 'widgets/upload_document_dialog.dart';

/// Documents screen matching THEME.md Section 8 & 11 and PRD.md DOC requirements.
class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  void _showUploadDialog(BuildContext context, WidgetRef ref) {
    showUploadDocumentDialog(context, ref);
  }

  void _showConflictDialog(
    BuildContext context,
    WidgetRef ref,
    SyncOperation conflictOp,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.lightWarning),
            SizedBox(width: 8),
            Text('Version Conflict'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A newer version of this document was committed from another authorized device (SYNC_ENGINE.md Section 8).',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.standard),
            Text(
              'Document ID: ${conflictOp.documentId.substring(0, conflictOp.documentId.length > 8 ? 8 : conflictOp.documentId.length)}...',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            if (conflictOp.expectedParentVersionId != null)
              Text(
                'Expected Parent: ${conflictOp.expectedParentVersionId!.substring(0, conflictOp.expectedParentVersionId!.length > 8 ? 8 : conflictOp.expectedParentVersionId!.length)}...',
                style: const TextStyle(fontSize: 12),
              ),
            const SizedBox(height: AppSpacing.standard),
            const Text(
              'How would you like to resolve this conflict?',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              ref
                  .read(syncControllerProvider.notifier)
                  .resolveConflict(
                    operationId: conflictOp.operationId,
                    strategy: ConflictResolutionStrategy.keepRemote,
                  );
            },
            child: const Text('Keep Remote'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              ref
                  .read(syncControllerProvider.notifier)
                  .resolveConflict(
                    operationId: conflictOp.operationId,
                    strategy: ConflictResolutionStrategy.saveBoth,
                  );
            },
            child: const Text('Save Both'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              ref
                  .read(syncControllerProvider.notifier)
                  .resolveConflict(
                    operationId: conflictOp.operationId,
                    strategy: ConflictResolutionStrategy.keepLocal,
                  );
            },
            child: const Text('Keep Local as New Version'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(documentsControllerProvider);
    final syncState = ref.watch(syncControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Documents',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: state.filter.favoritesOnly
                    ? Colors.amber.withAlpha(isDark ? 40 : 25)
                    : (isDark
                          ? AppColors.darkSurfaceVariant.withAlpha(120)
                          : AppColors.lightSurfaceVariant.withAlpha(160)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                state.filter.favoritesOnly
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                size: 20,
                color: state.filter.favoritesOnly ? Colors.amber : null,
              ),
            ),
            tooltip: state.filter.favoritesOnly
                ? 'Show All Documents'
                : 'Filter Favorites (SEARCH-005)',
            onPressed: () {
              ref
                  .read(documentsControllerProvider.notifier)
                  .toggleFavoritesOnly();
            },
          ),
          PopupMenuButton<DocumentSortOption>(
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceVariant.withAlpha(120)
                    : AppColors.lightSurfaceVariant.withAlpha(160),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sort_rounded, size: 20),
            ),
            tooltip: 'Sort Documents',
            initialValue: state.filter.sortBy,
            onSelected: (option) {
              ref
                  .read(documentsControllerProvider.notifier)
                  .setSortOption(option);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: DocumentSortOption.dateDesc,
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 16),
                    SizedBox(width: 8),
                    Text('Newest First'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: DocumentSortOption.dateAsc,
                child: Row(
                  children: [
                    Icon(Icons.history_rounded, size: 16),
                    SizedBox(width: 8),
                    Text('Oldest First'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: DocumentSortOption.nameAsc,
                child: Row(
                  children: [
                    Icon(Icons.sort_by_alpha_rounded, size: 16),
                    SizedBox(width: 8),
                    Text('Name (A - Z)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: DocumentSortOption.nameDesc,
                child: Row(
                  children: [
                    Icon(Icons.sort_by_alpha_rounded, size: 16),
                    SizedBox(width: 8),
                    Text('Name (Z - A)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: DocumentSortOption.sizeDesc,
                child: Row(
                  children: [
                    Icon(Icons.data_usage_rounded, size: 16),
                    SizedBox(width: 8),
                    Text('Size (Largest First)'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.small),
        ],
      ),
      body: Column(
        children: [
          // Conflict alert banner (SYNC_ENGINE.md Section 8 & 15)
          if (syncState.conflicts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.standard,
                vertical: AppSpacing.compact,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.standard,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkError.withAlpha(35)
                      : AppColors.lightError.withAlpha(20),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: (isDark ? AppColors.darkError : AppColors.lightError)
                        .withAlpha(80),
                    width: 1,
                  ),
                  boxShadow: AppShadows.softCard(isDark),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: isDark
                          ? AppColors.darkError
                          : AppColors.lightError,
                      size: 22,
                    ),
                    const SizedBox(width: AppSpacing.small),
                    Expanded(
                      child: Text(
                        '${syncState.conflicts.length} conflict(s) need attention.',
                        style: TextStyle(
                          color: isDark
                              ? AppColors.darkError
                              : AppColors.lightError,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? AppColors.darkError
                            : AppColors.lightError,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        minimumSize: const Size(60, 32),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        _showConflictDialog(
                          context,
                          ref,
                          syncState.conflicts.first,
                        );
                      },
                      child: const Text(
                        'Resolve',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Search Bar (SEARCH-001: Local on-device search)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.standard,
              vertical: AppSpacing.compact,
            ),
            child: Container(
              decoration: BoxDecoration(
                boxShadow: AppShadows.softCard(isDark),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search decrypted names, tags...',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? AppColors.darkTextSecondary.withAlpha(160)
                        : AppColors.lightTextSecondary.withAlpha(180),
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, size: 22),
                  suffixIcon: state.filter.searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            ref
                                .read(documentsControllerProvider.notifier)
                                .setSearchQuery('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark
                      ? AppColors.darkSurface
                      : AppColors.lightSurface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.standard,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: isDark
                          ? AppColors.darkOutline.withAlpha(40)
                          : AppColors.lightOutline.withAlpha(70),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: isDark
                          ? AppColors.darkOutline.withAlpha(40)
                          : AppColors.lightOutline.withAlpha(70),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: isDark
                          ? AppColors.darkPrimary
                          : AppColors.lightPrimary,
                      width: 1.5,
                    ),
                  ),
                ),
                onChanged: (val) {
                  ref
                      .read(documentsControllerProvider.notifier)
                      .setSearchQuery(val);
                },
              ),
            ),
          ),

          // Categories Filter Horizontal Scroll
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.standard,
              vertical: 4,
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.compact),
                  child: FilterChip(
                    avatar: state.filter.favoritesOnly
                        ? const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Colors.amber,
                          )
                        : null,
                    label: const Text('Favorites'),
                    selected: state.filter.favoritesOnly,
                    onSelected: (_) {
                      ref
                          .read(documentsControllerProvider.notifier)
                          .toggleFavoritesOnly();
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.compact),
                  child: FilterChip(
                    label: const Text('All'),
                    selected:
                        state.selectedCategory == 'All' &&
                        !state.filter.favoritesOnly,
                    onSelected: (selected) {
                      ref
                          .read(documentsControllerProvider.notifier)
                          .selectCategory('All');
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                ...AppConstants.defaultCategories.map((category) {
                  return Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.compact),
                    child: FilterChip(
                      label: Text(category),
                      selected: state.selectedCategory == category,
                      onSelected: (selected) {
                        ref
                            .read(documentsControllerProvider.notifier)
                            .selectCategory(category);
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Content Area
          Expanded(
            child: state.isUploading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: AppSpacing.standard),
                        Text(
                          'Encrypting file on device with AES-256-GCM...',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  )
                : state.documents.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.large),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.colorScheme.secondary.withAlpha(20),
                            ),
                            child: Icon(
                              Icons.folder_open_rounded,
                              size: 42,
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.standard),
                          Text(
                            'No documents in this category',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.compact),
                          Text(
                            'Documents uploaded here are encrypted with AES-256-GCM on this device before syncing.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.large),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 20),
                            label: const Text('Add Document'),
                            onPressed: () => _showUploadDialog(context, ref),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.standard,
                      vertical: AppSpacing.compact,
                    ),
                    itemCount: state.documents.length,
                    itemBuilder: (context, index) {
                      final doc = state.documents[index];
                      return _DocumentCard(doc: doc, isDark: isDark);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () => _showUploadDialog(context, ref),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }
}

/// Document card specification matching THEME.md Section 8.
class _DocumentCard extends ConsumerWidget {
  final DocumentRecord doc;
  final bool isDark;

  const _DocumentCard({required this.doc, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isPdf =
        doc.mimeType == 'application/pdf' ||
        doc.decryptedName?.toLowerCase().endsWith('.pdf') == true;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.compact),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.darkOutline.withAlpha(35)
              : AppColors.lightOutline.withAlpha(60),
          width: 1,
        ),
        boxShadow: AppShadows.softCard(isDark),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.standard,
            vertical: 6,
          ),
          leading: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: isPdf
                  ? const Color(0xFFDC2626).withAlpha(isDark ? 35 : 20)
                  : const Color(0xFF2563EB).withAlpha(isDark ? 35 : 20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
              color: isPdf ? const Color(0xFFEF4444) : const Color(0xFF3B82F6),
              size: 24,
            ),
          ),
          title: Text(
            doc.decryptedName ?? 'Encrypted Document',
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppCategoryTheme.getBackgroundColor(
                        doc.category,
                        isDark,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      doc.category,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppCategoryTheme.getColor(doc.category),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.small),
                  Text(
                    '${(doc.originalSizeBytes / 1024).toStringAsFixed(1)} KB (Encrypted)',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                ],
              ),
              if (doc.decryptedTags.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  children: doc.decryptedTags
                      .map(
                        (tag) => Text(
                          '#$tag',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.secondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  doc.isFavorite
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: doc.isFavorite
                      ? Colors.amber
                      : theme.colorScheme.secondary.withAlpha(150),
                  size: 22,
                ),
                tooltip: doc.isFavorite ? 'Unfavorite' : 'Favorite',
                onPressed: () {
                  ref
                      .read(documentsControllerProvider.notifier)
                      .toggleFavorite(doc.documentId);
                },
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 20),
                tooltip: 'More actions',
                onSelected: (value) {
                  if (value == 'open') {
                    context.go('/documents/${doc.documentId}');
                  } else if (value == 'delete') {
                    _confirmAndDelete(context, ref, doc);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'open',
                    child: Row(
                      children: [
                        Icon(Icons.visibility_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('Open'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: Colors.red,
                        ),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          onTap: () {
            context.go('/documents/${doc.documentId}');
          },
        ),
      ),
    );
  }

  Future<void> _confirmAndDelete(
    BuildContext context,
    WidgetRef ref,
    DocumentRecord doc,
  ) async {
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
          'Are you sure you want to delete "${doc.decryptedName ?? 'this document'}"?\n\nIt will be moved to trash and removed from your vault.',
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

    if (confirmed == true && context.mounted) {
      await ref
          .read(documentsControllerProvider.notifier)
          .deleteDocument(documentId: doc.documentId, ownerUid: doc.ownerUid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '"${doc.decryptedName ?? 'Document'}" moved to trash',
            ),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                ref
                    .read(documentsControllerProvider.notifier)
                    .restoreDocument(doc.documentId);
              },
            ),
          ),
        );
      }
    }
  }
}
