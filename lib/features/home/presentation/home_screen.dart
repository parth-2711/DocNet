import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../documents/domain/entities/document_record.dart';
import '../../documents/presentation/controllers/documents_controller.dart';
import '../../documents/presentation/widgets/upload_document_dialog.dart';
import '../../sync/presentation/controllers/sync_controller.dart';

/// Dashboard screen matching THEME.md Section 9 & 11 with professional human-designed UI.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final syncState = ref.watch(syncControllerProvider);
    final docsState = ref.watch(documentsControllerProvider);

    final totalBytes = docsState.documents.fold<int>(
      0,
      (sum, d) => sum + d.encryptedSizeBytes,
    );
    final usedMB = totalBytes / (1024 * 1024);
    final storageFraction = (totalBytes / (2 * 1024 * 1024 * 1024)).clamp(
      0.01,
      1.0,
    );
    final usedPercentage = ((totalBytes / (2 * 1024 * 1024 * 1024)) * 100)
        .toStringAsFixed(0);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          AppConstants.appName,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceVariant.withAlpha(120)
                    : AppColors.lightSurfaceVariant.withAlpha(160),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_none_rounded, size: 20),
            ),
            tooltip: 'Activity & Audit Log',
            onPressed: () => context.go('/activity'),
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceVariant.withAlpha(120)
                    : AppColors.lightSurfaceVariant.withAlpha(160),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.tune_rounded, size: 20),
            ),
            tooltip: 'Settings & Security',
            onPressed: () => context.go('/settings'),
          ),
          const SizedBox(width: AppSpacing.small),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.standard,
          vertical: AppSpacing.compact,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sync status banner (Sentinel Bar)
            InkWell(
              onTap: () {
                ref.read(syncControllerProvider.notifier).syncNow();
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.standard,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _getSyncBannerColor(syncState.status, isDark),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _getSyncBorderColor(syncState.status, isDark),
                    width: 1,
                  ),
                  boxShadow: AppShadows.softCard(isDark),
                ),
                child: Row(
                  children: [
                    _getSyncStatusDot(syncState.status, isDark),
                    const SizedBox(width: AppSpacing.compact),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getSyncMessage(syncState),
                            style: TextStyle(
                              fontSize: 13,
                              color: _getSyncTextColor(
                                syncState.status,
                                isDark,
                              ),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Tap to synchronize local vault with cloud',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (syncState.isSyncing)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withAlpha(15)
                              : Colors.black.withAlpha(10),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.refresh_rounded,
                          size: 16,
                          color: _getSyncTextColor(syncState.status, isDark),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.standard),

            // Encrypted Storage Hero Card
            Container(
              decoration: BoxDecoration(
                gradient: isDark
                    ? AppColors.heroGradientDark
                    : AppColors.heroGradientLight,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (isDark ? Colors.black : const Color(0xFF183653))
                        .withAlpha(isDark ? 80 : 35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
                border: Border.all(
                  color: isDark
                      ? Colors.white.withAlpha(15)
                      : Colors.white.withAlpha(40),
                  width: 1,
                ),
              ),
              child: Stack(
                children: [
                  // Subtle shield watermark in background
                  Positioned(
                    right: -15,
                    bottom: -20,
                    child: Icon(
                      Icons.shield_rounded,
                      size: 130,
                      color: Colors.white.withAlpha(12),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.standard + 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withAlpha(25),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.lock_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.small),
                                  const Flexible(
                                    child: Text(
                                      'Encrypted Storage',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(25),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$usedPercentage% Used',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.standard),
                        Text(
                          '${usedMB.toStringAsFixed(1)} MB of 2.0 GB used',
                          style: TextStyle(
                            color: Colors.white.withAlpha(220),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.small),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: storageFraction,
                            minHeight: 7,
                            backgroundColor: Colors.white.withAlpha(35),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF5DB7E8),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.standard),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _buildSecurityBadge('AES-256-GCM'),
                            _buildSecurityBadge('Argon2id KDF'),
                            _buildSecurityBadge('Zero-Knowledge'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.standard),

            // Quick Upload CTA button
            Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                gradient: isDark
                    ? AppColors.darkButtonGradient
                    : AppColors.buttonGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color:
                        (isDark
                                ? AppColors.darkPrimary
                                : AppColors.lightPrimary)
                            .withAlpha(45),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                label: const Text(
                  'Upload Document (Encrypted on this device)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                onPressed: () => showUploadDocumentDialog(context, ref),
              ),
            ),
            const SizedBox(height: AppSpacing.large),

            // Quick Access Categories for Students, Professionals & Everyday Use
            Text(
              'Quick Categories',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: AppSpacing.compact),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _QuickCategoryCard(
                    label: 'Education',
                    subtitle: 'Notes & IDs',
                    category: 'Education',
                    isDark: isDark,
                    onTap: () {
                      ref
                          .read(documentsControllerProvider.notifier)
                          .selectCategory('Education');
                      context.go('/documents');
                    },
                  ),
                  _QuickCategoryCard(
                    label: 'Work',
                    subtitle: 'Resumes & Docs',
                    category: 'Work',
                    isDark: isDark,
                    onTap: () {
                      ref
                          .read(documentsControllerProvider.notifier)
                          .selectCategory('Work');
                      context.go('/documents');
                    },
                  ),
                  _QuickCategoryCard(
                    label: 'Identity',
                    subtitle: 'Passports & IDs',
                    category: 'Identity',
                    isDark: isDark,
                    onTap: () {
                      ref
                          .read(documentsControllerProvider.notifier)
                          .selectCategory('Identity');
                      context.go('/documents');
                    },
                  ),
                  _QuickCategoryCard(
                    label: 'Certificates',
                    subtitle: 'Degrees & Awards',
                    category: 'Certificates',
                    isDark: isDark,
                    onTap: () {
                      ref
                          .read(documentsControllerProvider.notifier)
                          .selectCategory('Certificates');
                      context.go('/documents');
                    },
                  ),
                  _QuickCategoryCard(
                    label: 'Shared Spaces',
                    subtitle: 'Groups & Teams',
                    category: 'Shared',
                    isDark: isDark,
                    onTap: () => context.go('/family'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.large),

            // Recent Documents Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Documents',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: -0.3,
                  ),
                ),
                if (docsState.documents.isNotEmpty)
                  TextButton(
                    onPressed: () => context.go('/documents'),
                    child: const Text('See All'),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.compact),

            if (docsState.documents.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.large),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurface
                      : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkOutline.withAlpha(40)
                        : AppColors.lightOutline.withAlpha(70),
                    width: 1,
                  ),
                  boxShadow: AppShadows.softCard(isDark),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.secondary.withAlpha(20),
                        border: Border.all(
                          color: theme.colorScheme.secondary.withAlpha(40),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.shield_outlined,
                        size: 36,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.standard),
                    Text(
                      'Your vault is ready',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.micro),
                    Text(
                      'Add documents to store them securely across all your devices.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.standard),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add First Document'),
                      onPressed: () => showUploadDocumentDialog(context, ref),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docsState.documents.take(4).length,
                itemBuilder: (context, index) {
                  final doc = docsState.documents[index];
                  final sizeKb = (doc.originalSizeBytes / 1024).toStringAsFixed(
                    1,
                  );
                  final isPdf =
                      doc.decryptedName?.toLowerCase().endsWith('.pdf') ==
                          true ||
                      doc.mimeType == 'application/pdf';

                  return Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.compact),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurface
                          : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(14),
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
                      borderRadius: BorderRadius.circular(14),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.standard,
                          vertical: 4,
                        ),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isPdf
                                ? const Color(
                                    0xFFDC2626,
                                  ).withAlpha(isDark ? 35 : 20)
                                : const Color(
                                    0xFF2563EB,
                                  ).withAlpha(isDark ? 35 : 20),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isPdf
                                ? Icons.picture_as_pdf_rounded
                                : Icons.image_rounded,
                            color: isPdf
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF3B82F6),
                            size: 22,
                          ),
                        ),
                        title: Text(
                          doc.decryptedName ?? 'Encrypted Document',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
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
                                  fontWeight: FontWeight.bold,
                                  color: AppCategoryTheme.getColor(
                                    doc.category,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$sizeKb KB',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.lock_rounded,
                              size: 11,
                              color: isDark
                                  ? AppColors.darkSuccess
                                  : AppColors.lightSuccess,
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded, size: 18),
                          tooltip: 'Document actions',
                          onSelected: (value) async {
                            if (value == 'open') {
                              context.push('/documents/${doc.documentId}');
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
                                  Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        onTap: () =>
                            context.push('/documents/${doc.documentId}'),
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: AppSpacing.standard),
          ],
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

  Widget _buildSecurityBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withAlpha(30), width: 0.8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Color _getSyncBannerColor(SyncStatus status, bool isDark) {
    switch (status) {
      case SyncStatus.conflictNeedsAttention:
      case SyncStatus.syncFailed:
        return isDark
            ? AppColors.darkError.withAlpha(35)
            : AppColors.lightError.withAlpha(20);
      case SyncStatus.waitingForConnection:
        return isDark
            ? AppColors.darkWarning.withAlpha(35)
            : AppColors.lightWarning.withAlpha(20);
      case SyncStatus.syncing:
      case SyncStatus.uploadPending:
      case SyncStatus.downloadPending:
        return isDark
            ? AppColors.darkSecondary.withAlpha(35)
            : AppColors.lightSecondary.withAlpha(20);
      case SyncStatus.upToDate:
        return isDark ? const Color(0xFF162A22) : const Color(0xFFE8F5E9);
    }
  }

  Color _getSyncBorderColor(SyncStatus status, bool isDark) {
    switch (status) {
      case SyncStatus.conflictNeedsAttention:
      case SyncStatus.syncFailed:
        return (isDark ? AppColors.darkError : AppColors.lightError).withAlpha(
          80,
        );
      case SyncStatus.waitingForConnection:
        return (isDark ? AppColors.darkWarning : AppColors.lightWarning)
            .withAlpha(80);
      case SyncStatus.syncing:
      case SyncStatus.uploadPending:
      case SyncStatus.downloadPending:
        return (isDark ? AppColors.darkSecondary : AppColors.lightSecondary)
            .withAlpha(80);
      case SyncStatus.upToDate:
        return (isDark ? AppColors.darkSuccess : AppColors.lightSuccess)
            .withAlpha(70);
    }
  }

  Color _getSyncTextColor(SyncStatus status, bool isDark) {
    switch (status) {
      case SyncStatus.conflictNeedsAttention:
      case SyncStatus.syncFailed:
        return isDark ? AppColors.darkError : AppColors.lightError;
      case SyncStatus.waitingForConnection:
        return isDark ? AppColors.darkWarning : AppColors.lightWarning;
      case SyncStatus.syncing:
      case SyncStatus.uploadPending:
      case SyncStatus.downloadPending:
        return isDark ? AppColors.darkSecondary : AppColors.lightSecondary;
      case SyncStatus.upToDate:
        return isDark ? AppColors.darkSuccess : AppColors.lightSuccess;
    }
  }

  Widget _getSyncStatusDot(SyncStatus status, bool isDark) {
    final color = _getSyncTextColor(status, isDark);
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(120),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  String _getSyncMessage(SyncState state) {
    switch (state.status) {
      case SyncStatus.conflictNeedsAttention:
        return '${state.conflicts.length} conflict(s) need attention.';
      case SyncStatus.syncFailed:
        return 'Sync failed. Tap to retry.';
      case SyncStatus.waitingForConnection:
        return 'Offline. Waiting for network connection...';
      case SyncStatus.syncing:
        return 'Syncing encrypted documents...';
      case SyncStatus.uploadPending:
        return '${state.pendingUploadCount} item(s) pending sync.';
      case SyncStatus.downloadPending:
        return 'New remote versions available.';
      case SyncStatus.upToDate:
        return 'This device is up to date.';
    }
  }
}

class _QuickCategoryCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final String category;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickCategoryCard({
    required this.label,
    required this.subtitle,
    required this.category,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppCategoryTheme.getColor(category);
    final bgColor = AppCategoryTheme.getBackgroundColor(category, isDark);
    final icon = AppCategoryTheme.getIcon(category);

    return Container(
      width: 122,
      margin: const EdgeInsets.only(right: AppSpacing.compact),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? AppColors.darkOutline.withAlpha(35)
              : AppColors.lightOutline.withAlpha(60),
        ),
        boxShadow: AppShadows.softCard(isDark),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
