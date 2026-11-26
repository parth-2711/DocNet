import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/in_app_update_service.dart';
import '../theme/app_colors.dart';

/// Checks Google Play for app updates at startup and when returning to foreground,
/// and surfaces a sleek prompt when a flexible update is ready to install.
class AppUpdateGate extends ConsumerStatefulWidget {
  final Widget child;
  final bool autoCheck;

  const AppUpdateGate({
    super.key,
    required this.child,
    this.autoCheck = true,
  });

  @override
  ConsumerState<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends ConsumerState<AppUpdateGate>
    with WidgetsBindingObserver {
  bool _dismissedReadyBanner = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.autoCheck) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(appUpdateControllerProvider.notifier).checkForUpdate();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && widget.autoCheck) {
      final updateState = ref.read(appUpdateControllerProvider);
      if (updateState.status == AppUpdateStatus.idle ||
          updateState.status == AppUpdateStatus.readyToInstall) {
        ref.read(appUpdateControllerProvider.notifier).checkForUpdate();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppUpdateState>(appUpdateControllerProvider, (prev, next) {
      if (prev?.status != AppUpdateStatus.readyToInstall &&
          next.status == AppUpdateStatus.readyToInstall &&
          _dismissedReadyBanner) {
        setState(() => _dismissedReadyBanner = false);
      }
    });

    final updateState = ref.watch(appUpdateControllerProvider);
    final showReadyBanner =
        updateState.status == AppUpdateStatus.readyToInstall &&
        !_dismissedReadyBanner;

    if (!showReadyBanner) {
      return widget.child;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Material(
          color: isDark ? AppColors.darkSurface : AppColors.lightPrimary,
          elevation: 2,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.system_update_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Update downloaded and ready to install',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      ref
                          .read(appUpdateControllerProvider.notifier)
                          .completeFlexibleUpdate();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withAlpha(35),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                    ),
                    child: const Text(
                      'Restart',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                      size: 18,
                    ),
                    onPressed: () =>
                        setState(() => _dismissedReadyBanner = true),
                    tooltip: 'Dismiss',
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}
