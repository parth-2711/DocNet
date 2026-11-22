import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../domain/entities/device_record.dart';
import 'controllers/device_controller.dart';

/// Device Management Screen matching PRD.md Section 6.11 (DEVICE-001 through DEVICE-007).
class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  void _showRenameDialog(
    BuildContext context,
    WidgetRef ref,
    DeviceRecord device,
  ) {
    final controller = TextEditingController(text: device.deviceLabel);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Rename Device'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Device Label'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                ref
                    .read(deviceControllerProvider.notifier)
                    .renameDevice(device.deviceId, newName);
              }
              Navigator.pop(dialogCtx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showRevokeDialog(
    BuildContext context,
    WidgetRef ref,
    DeviceRecord device,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Revoke Device Access?'),
        content: Text(
          'Are you sure you want to revoke "${device.deviceLabel}"? '
          'This device will immediately lose access to sync and key unwrapping (DEVICE-006).\n\n'
          'Note: Revocation cannot remotely erase files previously exported outside the app (DEVICE-007).',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.lightError,
            ),
            onPressed: () {
              ref
                  .read(deviceControllerProvider.notifier)
                  .revokeDevice(device.deviceId);
              Navigator.pop(dialogCtx);
            },
            child: const Text('Revoke Device'),
          ),
        ],
      ),
    );
  }

  void _showRevokeAllDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Revoke All Other Devices?'),
        content: const Text(
          'All other sessions and devices except this current device will be revoked (DEVICE-004).\n\n'
          'Revocation cannot remotely erase files previously exported outside the app (DEVICE-007).',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.lightError,
            ),
            onPressed: () {
              ref
                  .read(deviceControllerProvider.notifier)
                  .revokeAllOtherDevices();
              Navigator.pop(dialogCtx);
            },
            child: const Text('Revoke Others'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(deviceControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Refresh',
            onPressed: () {
              ref.read(deviceControllerProvider.notifier).loadDevices();
            },
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.standard),
              children: [
                // Warning Banner (DEVICE-007)
                Card(
                  color: isDark
                      ? AppColors.darkWarning.withAlpha(35)
                      : AppColors.lightWarning.withAlpha(20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.input),
                    side: BorderSide(
                      color: isDark
                          ? AppColors.darkWarning
                          : AppColors.lightWarning,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.standard),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: isDark
                              ? AppColors.darkWarning
                              : AppColors.lightWarning,
                          size: 22,
                        ),
                        const SizedBox(width: AppSpacing.standard),
                        Expanded(
                          child: Text(
                            'Revoking device authorization prevents future key unwrapping and sync. '
                            'However, revocation cannot remotely erase unencrypted files previously exported outside FamilyVault.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.standard),

                // Devices List Section
                Text(
                  'Authorized Devices (${state.devices.length})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.compact),

                ...state.devices.map((device) {
                  final isCurrent = device.deviceId == state.currentDeviceId;
                  final isRevoked = device.status == 'revoked';

                  return Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.compact),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isRevoked
                            ? (isDark
                                  ? AppColors.darkError.withAlpha(40)
                                  : AppColors.lightError.withAlpha(30))
                            : (isDark
                                  ? AppColors.darkPrimaryContainer
                                  : AppColors.lightPrimaryContainer),
                        child: Icon(
                          device.platform.toLowerCase().contains('windows')
                              ? Icons.laptop_outlined
                              : Icons.smartphone_outlined,
                          color: isRevoked
                              ? (isDark
                                    ? AppColors.darkError
                                    : AppColors.lightError)
                              : (isDark
                                    ? AppColors.darkPrimary
                                    : AppColors.lightPrimary),
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              device.deviceLabel,
                              style: TextStyle(
                                decoration: isRevoked
                                    ? TextDecoration.lineThrough
                                    : null,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (isCurrent)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.darkPrimaryContainer
                                    : AppColors.lightPrimaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'This Device',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          if (isRevoked)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.darkError.withAlpha(40)
                                    : AppColors.lightError.withAlpha(30),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Revoked',
                                style: TextStyle(
                                  color: isDark
                                      ? AppColors.darkError
                                      : AppColors.lightError,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(
                            'Platform: ${device.platform} • v${device.appVersion}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            'Enrolled: ${DateFormat('MMM d, y').format(device.enrolledAt.toLocal())}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                        ],
                      ),
                      trailing: isRevoked
                          ? null
                          : PopupMenuButton<String>(
                              onSelected: (val) {
                                if (val == 'rename') {
                                  _showRenameDialog(context, ref, device);
                                } else if (val == 'revoke') {
                                  _showRevokeDialog(context, ref, device);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'rename',
                                  child: Text('Rename'),
                                ),
                                if (!isCurrent)
                                  const PopupMenuItem(
                                    value: 'revoke',
                                    child: Text(
                                      'Revoke Access',
                                      style: TextStyle(
                                        color: AppColors.lightError,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  );
                }),

                const SizedBox(height: AppSpacing.large),

                // Revoke All Others Action (DEVICE-004)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark
                        ? AppColors.darkError
                        : AppColors.lightError,
                    side: BorderSide(
                      color: isDark
                          ? AppColors.darkError
                          : AppColors.lightError,
                    ),
                  ),
                  icon: const Icon(Icons.phonelink_erase_outlined),
                  label: const Text('Revoke All Other Devices'),
                  onPressed: () => _showRevokeAllDialog(context, ref),
                ),
              ],
            ),
    );
  }
}
