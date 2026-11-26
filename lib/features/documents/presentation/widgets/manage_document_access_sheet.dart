import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../family/domain/entities/document_permission.dart';
import '../../../family/presentation/controllers/family_controller.dart';
import '../../domain/entities/document_record.dart';

/// Opens a granular per-document Access Management & Sharing sheet where the owner
/// (or authorized co-sharer) can grant, inspect, edit, or revoke individual user
/// permissions by email or from any space member.
Future<void> showManageDocumentAccessSheet({
  required BuildContext context,
  required WidgetRef ref,
  required DocumentRecord document,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ManageDocumentAccessSheet(document: document),
  );
}

class _ManageDocumentAccessSheet extends ConsumerStatefulWidget {
  final DocumentRecord document;

  const _ManageDocumentAccessSheet({required this.document});

  @override
  ConsumerState<_ManageDocumentAccessSheet> createState() =>
      _ManageDocumentAccessSheetState();
}

class _ManageDocumentAccessSheetState
    extends ConsumerState<_ManageDocumentAccessSheet> {
  final _emailController = TextEditingController();
  bool _isLoadingPermissions = true;
  bool _isSubmitting = false;
  List<DocumentPermission> _permissions = [];
  String _accessLevel = 'view'; // 'view', 'download', 'edit'
  int? _expiryDays; // null = Never
  String? _statusMessage;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadPermissions() async {
    setState(() => _isLoadingPermissions = true);
    try {
      final familyRepo = ref.read(familyRepositoryProvider);
      final list = await familyRepo.getPermissions(widget.document.documentId);
      if (mounted) {
        setState(() {
          _permissions = list;
          _isLoadingPermissions = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingPermissions = false);
      }
    }
  }

  Future<void> _grantAccess({
    required String email,
    String? knownUid,
    String? knownDisplayName,
  }) async {
    final normalized = email.trim().toLowerCase();
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(normalized)) {
      setState(() {
        _isError = true;
        _statusMessage = 'Please enter a valid recipient email address.';
      });
      return;
    }

    final authProfile = ref.read(authControllerProvider).userProfile;
    final currentUid = authProfile?.uid ?? 'guest-uid';
    final currentEmail = authProfile?.email?.trim().toLowerCase() ?? '';
    if (normalized == currentEmail || knownUid == widget.document.ownerUid) {
      setState(() {
        _isError = true;
        _statusMessage = 'You already own this document.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _statusMessage = null;
      _isError = false;
    });

    try {
      // Resolve recipient UID & display name if available
      final familyState = ref.read(familyControllerProvider);
      final memberMatch = familyState.members.where(
        (m) => m.email.trim().toLowerCase() == normalized,
      );
      String? targetUid = knownUid;
      String? targetName = knownDisplayName;

      if (memberMatch.isNotEmpty) {
        targetUid ??= memberMatch.first.uid;
        targetName ??= memberMatch.first.displayName;
      } else {
        final lookupProfile = await ref
            .read(familyControllerProvider.notifier)
            .lookupUserByEmail(normalized);
        targetUid ??= lookupProfile?.uid ?? 'email-$normalized';
        targetName ??=
            lookupProfile?.effectiveDisplayName ??
            AuthController.deriveDisplayName(normalized);
      }

      final canDownload =
          _accessLevel == 'download' || _accessLevel == 'edit';
      final canEdit = _accessLevel == 'edit';
      final expiresAt = _expiryDays != null
          ? DateTime.now().toUtc().add(Duration(days: _expiryDays!))
          : null;

      await ref.read(shareDocumentUseCaseProvider).execute(
            documentId: widget.document.documentId,
            granterUid: currentUid,
            recipientUid: targetUid,
            recipientEmail: normalized,
            recipientDisplayName: targetName,
            canView: true,
            canDownload: canDownload,
            canEdit: canEdit,
            canShare: false,
            expiresAt: expiresAt,
          );

      _emailController.clear();
      await _loadPermissions();
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isError = false;
          _statusMessage = 'Access granted to $targetName ($normalized)';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isError = true;
          _statusMessage = e.toString().replaceFirst('Bad state: ', '');
        });
      }
    }
  }

  Future<void> _revokeAccess(DocumentPermission perm) async {
    final authProfile = ref.read(authControllerProvider).userProfile;
    final currentUid = authProfile?.uid ?? 'guest-uid';

    setState(() => _isSubmitting = true);
    try {
      await ref.read(revokeDocumentAccessUseCaseProvider).execute(
            documentId: widget.document.documentId,
            revokerUid: currentUid,
            granteeId: perm.granteeId,
            granteeEmail: perm.granteeEmail,
          );
      await _loadPermissions();
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isError = false;
          _statusMessage =
              'Revoked access for ${perm.granteeDisplayName ?? perm.granteeEmail ?? perm.granteeId}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isError = true;
          _statusMessage = 'Failed to revoke: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final familyState = ref.watch(familyControllerProvider);
    final currentUid =
        ref.watch(authControllerProvider).userProfile?.uid ?? 'guest-uid';
    final spaceMembers = familyState.members
        .where((m) => m.uid != widget.document.ownerUid && m.uid != currentUid)
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.55,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.standard,
          12,
          AppSpacing.standard,
          MediaQuery.of(context).viewInsets.bottom + AppSpacing.standard,
        ),
        child: ListView(
          controller: scrollController,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(100),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isDark
                            ? AppColors.darkPrimary
                            : AppColors.lightPrimary)
                        .withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.admin_panel_settings_outlined,
                    color: isDark
                        ? AppColors.darkPrimary
                        : AppColors.lightPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Manage Document Access',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        widget.document.decryptedName ?? 'Encrypted Document',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Status Banner
            if (_statusMessage != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _isError
                      ? AppColors.lightError.withAlpha(25)
                      : const Color(0xFF10B981).withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isError
                        ? AppColors.lightError.withAlpha(80)
                        : const Color(0xFF10B981).withAlpha(80),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isError
                          ? Icons.error_outline_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 18,
                      color: _isError
                          ? AppColors.lightError
                          : const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _isError
                              ? AppColors.lightError
                              : const Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Grant Access By Email Section
            Text(
              'Share With Specific Person',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Only the users you add here can see and decrypt this document. Other documents stay completely private.',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'User Email Address',
                hintText: 'e.g. classmate@gmail.com',
                prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20),
                filled: true,
                fillColor: isDark
                    ? AppColors.darkSurfaceVariant.withAlpha(80)
                    : AppColors.lightBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            // Quick pick from space members
            if (spaceMembers.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Or tap a space member:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: spaceMembers.map((member) {
                  return ActionChip(
                    avatar: CircleAvatar(
                      radius: 10,
                      child: Text(
                        member.displayName.substring(0, 1).toUpperCase(),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                    label: Text(
                      member.displayName,
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            _emailController.text = member.email;
                          },
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 14),
            Text(
              'Permission Level',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  label: const Text('View Only'),
                  selected: _accessLevel == 'view',
                  onSelected: (_) => setState(() => _accessLevel = 'view'),
                ),
                ChoiceChip(
                  label: const Text('View & Download'),
                  selected: _accessLevel == 'download',
                  onSelected: (_) => setState(() => _accessLevel = 'download'),
                ),
                ChoiceChip(
                  label: const Text('Collaborator (Edit)'),
                  selected: _accessLevel == 'edit',
                  onSelected: (_) => setState(() => _accessLevel = 'edit'),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Text(
              'Access Expiry',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  label: const Text('Never'),
                  selected: _expiryDays == null,
                  onSelected: (_) => setState(() => _expiryDays = null),
                ),
                ChoiceChip(
                  label: const Text('24 Hours'),
                  selected: _expiryDays == 1,
                  onSelected: (_) => setState(() => _expiryDays = 1),
                ),
                ChoiceChip(
                  label: const Text('7 Days'),
                  selected: _expiryDays == 7,
                  onSelected: (_) => setState(() => _expiryDays = 7),
                ),
                ChoiceChip(
                  label: const Text('30 Days'),
                  selected: _expiryDays == 30,
                  onSelected: (_) => setState(() => _expiryDays = 30),
                ),
              ],
            ),

            const SizedBox(height: 14),
            SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.key_rounded, size: 18),
                label: const Text('Grant Encrypted Access'),
                onPressed: _isSubmitting
                    ? null
                    : () => _grantAccess(email: _emailController.text),
              ),
            ),

            const Divider(height: 28),
            Text(
              'People With Access (${_permissions.length + 1})',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),

            // Owner Row
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFD97706).withAlpha(30),
                child: const Icon(
                  Icons.shield_rounded,
                  color: Color(0xFFD97706),
                  size: 18,
                ),
              ),
              title: Text(
                widget.document.ownerUid == currentUid
                    ? 'You (Document Owner)'
                    : 'Document Owner',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              subtitle: const Text(
                'Full control • View, Download, Edit & Revoke',
                style: TextStyle(fontSize: 11),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'OWNER',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFD97706),
                  ),
                ),
              ),
            ),

            if (_isLoadingPermissions)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_permissions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Private — Only you currently have access to this document.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              )
            else
              ..._permissions.map((perm) {
                final title = perm.granteeDisplayName ??
                    perm.granteeEmail ??
                    perm.granteeId;
                final levelLabel = perm.canEdit
                    ? 'COLLABORATOR'
                    : (perm.canDownload ? 'DOWNLOAD' : 'VIEW ONLY');
                final expiryNote = perm.expiresAt == null
                    ? ''
                    : (perm.isExpired
                          ? ' • EXPIRED'
                          : ' • Expires in ${perm.expiresAt!.difference(DateTime.now().toUtc()).inDays + 1}d');

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF2563EB).withAlpha(25),
                    child: Text(
                      title.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    '${perm.granteeEmail ?? perm.granteeId} • $levelLabel$expiryNote',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: perm.isExpired ? AppColors.lightError : null,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.person_remove_outlined,
                      color: AppColors.lightError,
                      size: 20,
                    ),
                    tooltip: 'Revoke Access',
                    onPressed:
                        _isSubmitting ? null : () => _revokeAccess(perm),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
