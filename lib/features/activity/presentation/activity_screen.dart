import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../domain/entities/activity_event.dart';
import 'controllers/activity_controller.dart';

/// Activity Screen matching THEME.md Section 7, 10 & 11 and PRD.md Section 6.12.
class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(activityControllerProvider);
    final filteredEvents = state.filteredEvents;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Refresh',
            onPressed: () {
              ref.read(activityControllerProvider.notifier).loadEvents();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.standard,
              vertical: AppSpacing.compact,
            ),
            child: Row(
              children: [
                _buildFilterChip(context, ref, 'All', state.filter),
                _buildFilterChip(context, ref, 'Documents', state.filter),
                _buildFilterChip(context, ref, 'Sharing', state.filter),
                _buildFilterChip(context, ref, 'Family', state.filter),
                _buildFilterChip(context, ref, 'Security', state.filter),
              ],
            ),
          ),
          const Divider(height: 1),

          // Events List or Empty State
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredEvents.isEmpty
                ? _buildEmptyState(context, state.filter)
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.standard),
                    itemCount: filteredEvents.length,
                    separatorBuilder: (_, index) =>
                        const SizedBox(height: AppSpacing.compact),
                    itemBuilder: (context, index) {
                      final event = filteredEvents[index];
                      return _buildActivityCard(context, event, isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    WidgetRef ref,
    String label,
    String currentFilter,
  ) {
    final isSelected = currentFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.compact),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onSelected: (_) {
          ref.read(activityControllerProvider.notifier).setFilter(label);
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String currentFilter) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filterText = currentFilter == 'All'
        ? 'No security or vault events recorded yet.'
        : 'No events under the "$currentFilter" category.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.large),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? AppColors.darkOutline.withAlpha(40)
                  : AppColors.lightOutline.withAlpha(70),
            ),
            boxShadow: AppShadows.softCard(isDark),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.secondary.withAlpha(25),
                ),
                child: Icon(
                  Icons.history_toggle_off_rounded,
                  size: 40,
                  color: theme.colorScheme.secondary,
                ),
              ),
              const SizedBox(height: AppSpacing.standard),
              Text(
                'No Activity Found',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: AppSpacing.compact),
              Text(
                filterText,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityCard(
    BuildContext context,
    ActivityEvent event,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final iconData = _getEventIcon(event.eventType);
    final iconColor = _getEventColor(event.eventType, isDark);
    final formattedTime = DateFormat(
      'MMM d, y • h:mm a',
    ).format(event.timestamp.toLocal());

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.darkOutline.withAlpha(35)
              : AppColors.lightOutline.withAlpha(60),
        ),
        boxShadow: AppShadows.softCard(isDark),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.standard),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(isDark ? 40 : 25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(iconData, color: iconColor, size: 22),
              ),
              const SizedBox(width: AppSpacing.standard),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.summary,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 13,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formattedTime,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    if (event.targetDocumentId != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurfaceVariant
                              : AppColors.lightSurfaceVariant,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Doc ID: ${event.targetDocumentId!.substring(0, event.targetDocumentId!.length > 8 ? 8 : event.targetDocumentId!.length)}...',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontFamily: 'monospace',
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getEventIcon(ActivityEventType type) {
    switch (type) {
      case ActivityEventType.documentCreated:
        return Icons.upload_file_outlined;
      case ActivityEventType.documentReplaced:
        return Icons.update_outlined;
      case ActivityEventType.documentDeleted:
        return Icons.delete_outline;
      case ActivityEventType.documentRestored:
        return Icons.restore_page_outlined;
      case ActivityEventType.documentExported:
        return Icons.file_download_outlined;
      case ActivityEventType.shareGranted:
        return Icons.share_outlined;
      case ActivityEventType.shareRevoked:
        return Icons.person_remove_outlined;
      case ActivityEventType.familyCreated:
        return Icons.family_restroom_outlined;
      case ActivityEventType.familyInvitationSent:
        return Icons.mail_outline;
      case ActivityEventType.familyMemberJoined:
        return Icons.person_add_alt_1_outlined;
      case ActivityEventType.familyMemberRemoved:
        return Icons.group_remove_outlined;
      case ActivityEventType.familyRoleUpdated:
        return Icons.admin_panel_settings_outlined;
      case ActivityEventType.recoveryPhraseGenerated:
      case ActivityEventType.recoveryPhraseVerified:
        return Icons.vpn_key_outlined;
      case ActivityEventType.deviceEnrolled:
      case ActivityEventType.deviceRevoked:
        return Icons.devices_outlined;
      case ActivityEventType.signIn:
      case ActivityEventType.signOut:
        return Icons.lock_outline;
    }
  }

  Color _getEventColor(ActivityEventType type, bool isDark) {
    switch (type) {
      case ActivityEventType.documentCreated:
      case ActivityEventType.documentReplaced:
      case ActivityEventType.documentRestored:
        return isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
      case ActivityEventType.documentDeleted:
      case ActivityEventType.deviceRevoked:
      case ActivityEventType.familyMemberRemoved:
      case ActivityEventType.shareRevoked:
        return isDark ? AppColors.darkError : AppColors.lightError;
      case ActivityEventType.documentExported:
      case ActivityEventType.shareGranted:
        return Colors.blue;
      case ActivityEventType.familyCreated:
      case ActivityEventType.familyInvitationSent:
      case ActivityEventType.familyMemberJoined:
      case ActivityEventType.familyRoleUpdated:
        return Colors.teal;
      case ActivityEventType.recoveryPhraseGenerated:
      case ActivityEventType.recoveryPhraseVerified:
      case ActivityEventType.deviceEnrolled:
      case ActivityEventType.signIn:
      case ActivityEventType.signOut:
        return Colors.orange;
    }
  }
}
