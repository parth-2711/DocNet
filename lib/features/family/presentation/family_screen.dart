import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../auth/domain/entities/user_profile.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../documents/domain/entities/document_request.dart';
import '../../documents/presentation/controllers/document_request_controller.dart';
import '../../documents/presentation/controllers/documents_controller.dart';
import '../domain/entities/family_invitation.dart';
import '../domain/entities/family_member.dart';
import 'controllers/family_controller.dart';

/// Family Vault Screen matching THEME.md Section 11 and PRD.md FAM/SHARE requirements.
class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key});

  void _showCreateFamilyDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController(text: 'My Family Group');

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Create Family Group'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Family Group Name',
            hintText: 'e.g. Godhani Family, Home Vault',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(dialogCtx);
                await ref
                    .read(familyControllerProvider.notifier)
                    .createFamily(name);
                if (context.mounted) {
                  final familyState = ref.read(familyControllerProvider);
                  if (familyState.errorMessage != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Failed to create group: ${familyState.errorMessage}',
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Family Group "$name" created successfully!',
                        ),
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Create Group'),
          ),
        ],
      ),
    );
  }

  void _showInviteDialog(BuildContext context, WidgetRef ref) {
    final messenger = ScaffoldMessenger.of(context);
    final emailController = TextEditingController();
    var selectedRole = FamilyRole.member;
    UserProfile? matchedUser;
    bool isChecking = false;
    String? statusMessage;
    bool isSuccess = false;
    bool isSending = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final familyState = ref.watch(familyControllerProvider);
          final currentEmail =
              ref.watch(authControllerProvider).userProfile?.email ?? '';

          Future<void> checkEmail(String email) async {
            final trimmed = email.trim().toLowerCase();
            if (trimmed.isEmpty) {
              setDialogState(() {
                matchedUser = null;
                statusMessage = null;
                isSuccess = false;
                isChecking = false;
              });
              return;
            }

            if (trimmed == currentEmail.trim().toLowerCase()) {
              setDialogState(() {
                matchedUser = null;
                statusMessage = 'You cannot invite your own account.';
                isSuccess = false;
                isChecking = false;
              });
              return;
            }

            if (familyState.members.any(
              (m) => m.email.trim().toLowerCase() == trimmed,
            )) {
              setDialogState(() {
                matchedUser = null;
                statusMessage = 'User is already a member of this family space.';
                isSuccess = false;
                isChecking = false;
              });
              return;
            }

            if (familyState.outgoingInvitations.any(
              (inv) =>
                  inv.recipientEmail.trim().toLowerCase() == trimmed &&
                  inv.status == InvitationStatus.pending,
            )) {
              setDialogState(() {
                matchedUser = null;
                statusMessage =
                    'An invitation is already pending for this user.';
                isSuccess = false;
                isChecking = false;
              });
              return;
            }

            setDialogState(() {
              isChecking = true;
              statusMessage = null;
            });

            try {
              final profile = await ref
                  .read(familyControllerProvider.notifier)
                  .lookupUserByEmail(trimmed);
              setDialogState(() {
                isChecking = false;
                if (profile != null) {
                  matchedUser = profile;
                  isSuccess = true;
                  final isSynthesized = profile.uid.startsWith('user-') ||
                      profile.uid.startsWith('pending-');
                  statusMessage = isSynthesized
                      ? 'Ready to invite: ${profile.effectiveDisplayName}'
                      : 'Account found: ${profile.effectiveDisplayName}';
                } else {
                  matchedUser = null;
                  isSuccess = false;
                  statusMessage = 'Please enter a valid email address.';
                }
              });
            } catch (_) {
              setDialogState(() {
                isChecking = false;
                matchedUser = null;
                isSuccess = false;
                statusMessage = 'Failed to lookup account. Please try again.';
              });
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            title: Row(
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
                    Icons.person_add_alt_1_rounded,
                    color: isDark
                        ? AppColors.darkPrimary
                        : AppColors.lightPrimary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Invite Family Member',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Enter the registered email of the user you want to invite. We will automatically fetch their verified account details.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Recipient Email Address',
                      hintText: 'user@example.com',
                      prefixIcon: const Icon(Icons.email_outlined, size: 20),
                      suffixIcon: isChecking
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : (isSuccess
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF10B981),
                                )
                              : null),
                      filled: true,
                      fillColor: isDark
                          ? AppColors.darkSurfaceVariant.withAlpha(80)
                          : AppColors.lightBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (val) {
                      checkEmail(val);
                    },
                  ),
                  const SizedBox(height: 12),
                  if (statusMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSuccess
                            ? const Color(0xFF10B981).withAlpha(25)
                            : Colors.amber.withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSuccess
                              ? const Color(0xFF10B981).withAlpha(80)
                              : Colors.amber.withAlpha(80),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSuccess
                                ? Icons.verified_user_rounded
                                : Icons.info_outline_rounded,
                            size: 18,
                            color: isSuccess
                                ? const Color(0xFF10B981)
                                : Colors.amber.shade800,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              statusMessage!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSuccess
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSuccess
                                    ? const Color(0xFF10B981)
                                    : (isDark
                                          ? Colors.amber.shade200
                                          : Colors.amber.shade900),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  DropdownButtonFormField<FamilyRole>(
                    initialValue: selectedRole,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Family Role',
                      filled: true,
                      fillColor: isDark
                          ? AppColors.darkSurfaceVariant.withAlpha(80)
                          : AppColors.lightBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: FamilyRole.admin,
                        child: Text(
                          'Admin (Full access & invites)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: FamilyRole.member,
                        child: Text(
                          'Member (Share & view documents)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: FamilyRole.viewer,
                        child: Text(
                          'Viewer (Read-only access)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedRole = val);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSending ? null : () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? AppColors.darkPrimary
                      : AppColors.lightPrimary,
                  foregroundColor: isDark
                      ? AppColors.darkBackground
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: (isSuccess && matchedUser != null && !isSending)
                    ? () async {
                        setDialogState(() => isSending = true);
                        try {
                          final targetEmail = emailController.text.trim();
                          await ref
                              .read(familyControllerProvider.notifier)
                              .sendInvitation(
                                recipientEmail: targetEmail,
                                role: selectedRole,
                              );
                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx);
                          }
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Invitation sent to ${matchedUser!.effectiveDisplayName} ($targetEmail)!',
                              ),
                              backgroundColor: const Color(0xFF10B981),
                            ),
                          );
                        } catch (e) {
                          setDialogState(() {
                            isSending = false;
                            statusMessage = e
                                .toString()
                                .replaceFirst('FormatException: ', '');
                            isSuccess = false;
                          });
                        }
                      }
                    : null,
                child: isSending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Send Invitation'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCreateRequestDialog(
    BuildContext context,
    WidgetRef ref,
    List<FamilyMember> members,
    String familyId,
    String currentUid,
  ) {
    final otherMembers = members.where((m) => m.uid != currentUid).toList();
    if (otherMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No other family members to request from.'),
        ),
      );
      return;
    }

    final titleController = TextEditingController();
    final notesController = TextEditingController();
    var selectedMemberUid = otherMembers.first.uid;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Request Document'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedMemberUid,
                  decoration: const InputDecoration(labelText: 'From Member'),
                  items: otherMembers
                      .map(
                        (m) => DropdownMenuItem(
                          value: m.uid,
                          child: Text(m.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => selectedMemberUid = val);
                  },
                ),
                const SizedBox(height: AppSpacing.standard),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Document Needed',
                    hintText: 'e.g. Passport copy, Birth Certificate',
                  ),
                ),
                const SizedBox(height: AppSpacing.standard),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    hintText: 'e.g. Needed for school admission',
                  ),
                ),
                const SizedBox(height: AppSpacing.compact),
                const Text(
                  'Do not include sensitive identity numbers in requests (REQ-002).',
                  style: TextStyle(fontSize: 11, color: AppColors.lightWarning),
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
                final title = titleController.text.trim();
                if (title.isNotEmpty) {
                  Navigator.pop(dialogCtx);
                  await ref
                      .read(documentRequestControllerProvider.notifier)
                      .createRequest(
                        familyId: familyId,
                        recipientUid: selectedMemberUid,
                        title: title,
                        notes: notesController.text.trim().isEmpty
                            ? null
                            : notesController.text.trim(),
                      );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Document request sent.')),
                    );
                  }
                }
              },
              child: const Text('Send Request'),
            ),
          ],
        ),
      ),
    );
  }

  void _showFulfillDialog(
    BuildContext context,
    WidgetRef ref,
    DocumentRequest req,
  ) {
    Uint8List? pickedFileBytes;
    String fileName = '${req.title.replaceAll(' ', '_')}.pdf';
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Fulfill: ${req.title}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Select a document from your device to encrypt and fulfill this request.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: AppSpacing.standard),
                OutlinedButton.icon(
                  icon: const Icon(Icons.attach_file),
                  label: Text(
                    pickedFileBytes != null
                        ? 'Selected: $fileName'
                        : 'Pick File from Device (PDF / Image)',
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
                            pickedFileBytes = bytes;
                            fileName = file.name;
                          });
                        }
                      }
                    } catch (_) {}
                  },
                ),
                const SizedBox(height: AppSpacing.standard),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Fulfillment Note (Optional)',
                    hintText: 'e.g. Attached certified copy',
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

                final bytes =
                    pickedFileBytes ??
                    utf8.encode('Encrypted fulfillment for ${req.title}');
                final uploadResult = await ref
                    .read(documentsControllerProvider.notifier)
                    .uploadDocument(
                      fileBytes: bytes,
                      fileName: fileName,
                      category: 'Family',
                      description: noteController.text.trim().isEmpty
                          ? 'Fulfilled request: ${req.title}'
                          : noteController.text.trim(),
                    );

                await ref
                    .read(documentRequestControllerProvider.notifier)
                    .fulfillRequest(
                      requestId: req.requestId,
                      documentId: uploadResult.document.documentId,
                    );

                // Grant view permission to requester
                final shareUseCase = ref.read(shareDocumentUseCaseProvider);
                final authState = ref.read(authControllerProvider);
                final granterUid = authState.userProfile?.uid ?? 'guest-uid';

                await shareUseCase.execute(
                  documentId: uploadResult.document.documentId,
                  granterUid: granterUid,
                  recipientUid: req.requesterUid,
                  canView: true,
                  canDownload: true,
                );

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Document encrypted and request fulfilled!',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Encrypt & Send'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(familyControllerProvider);
    final requestState = ref.watch(documentRequestControllerProvider);
    final currentUid = ref
        .watch(familyControllerProvider.notifier)
        .currentUserUid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Vault'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Invitations',
            onPressed: () async {
              await ref.read(familyControllerProvider.notifier).loadFamily();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Refreshed family data & invitations'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
          if (state.family != null)
            IconButton(
              icon: const Icon(Icons.person_add_outlined),
              tooltip: 'Invite Member',
              onPressed: () => _showInviteDialog(context, ref),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(familyControllerProvider.notifier).loadFamily(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.standard,
            vertical: AppSpacing.compact,
          ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trust Boundary Banner (ARCHITECTURE.md Boundary C & THEME.md)
            Container(
              padding: const EdgeInsets.all(AppSpacing.standard),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
                          .withAlpha(40),
                ),
                boxShadow: AppShadows.softCard(isDark),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color:
                          (isDark
                                  ? AppColors.darkPrimary
                                  : AppColors.lightPrimary)
                              .withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.shield_rounded,
                      color: isDark
                          ? AppColors.darkPrimary
                          : AppColors.lightPrimary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.standard),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Strict Cryptographic Isolation',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Family members can only access documents explicitly shared via wrapped key envelopes. Personal vault documents remain strictly inaccessible.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.standard),

            // Incoming Family Invitations Banner
            if (state.incomingInvitations.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.standard),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF064E3B), const Color(0xFF065F46)]
                        : [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF10B981).withAlpha(120),
                    width: 1.5,
                  ),
                  boxShadow: AppShadows.softCard(isDark),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.mark_email_unread_rounded,
                            color: Color(0xFF10B981),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Family Space Invitation (${state.incomingInvitations.length})',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF065F46),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...state.incomingInvitations.map(
                      (inv) => Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurfaceVariant.withAlpha(120)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(10),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'You have been invited to join "${inv.familyName}"',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Invited by ${inv.inviterDisplayName} (${inv.inviterEmail}) as ${inv.role.name.toUpperCase()}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () async {
                                    await ref
                                        .read(familyControllerProvider.notifier)
                                        .declineInvitation(inv.invitationId);
                                  },
                                  child: const Text('Decline'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('Accept & Join'),
                                  onPressed: () async {
                                    await ref
                                        .read(familyControllerProvider.notifier)
                                        .acceptInvitation(inv.invitationId);
                                    // Refresh documents so newly joined family documents appear
                                    ref
                                        .read(
                                          documentsControllerProvider.notifier,
                                        )
                                        .loadDocuments();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Joined "${inv.familyName}" successfully!',
                                          ),
                                          backgroundColor: const Color(
                                            0xFF10B981,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.standard),
            ],

            if (state.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (state.family == null)
              // No Family Space State
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.large),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurface
                      : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkOutline.withAlpha(40)
                        : AppColors.lightOutline.withAlpha(70),
                  ),
                  boxShadow: AppShadows.softCard(isDark),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.primary.withAlpha(25),
                      ),
                      child: Icon(
                        Icons.groups_rounded,
                        size: 40,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.standard),
                    Text(
                      'Create a Family Space',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.compact),
                    Text(
                      'Set up a shared space to securely exchange documents with family members while preserving personal privacy.',
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
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text('Create Family Space'),
                      onPressed: () => _showCreateFamilyDialog(context, ref),
                    ),
                  ],
                ),
              )
            else ...[
              // Active Family Space Details
              Container(
                padding: const EdgeInsets.all(AppSpacing.standard),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurface
                      : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkOutline.withAlpha(35)
                        : AppColors.lightOutline.withAlpha(60),
                  ),
                  boxShadow: AppShadows.softCard(isDark),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: isDark
                                ? AppColors.darkButtonGradient
                                : AppColors.buttonGradient,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.people_alt_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.standard),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                state.family!.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${state.members.length} Member(s) • Cryptographically Isolated',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: AppSpacing.large),
                    Text(
                      'Members & Roles',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.compact),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: state.members.length,
                      itemBuilder: (context, index) {
                        final member = state.members[index];
                        final isOwner = member.role == FamilyRole.owner;
                        final isCurrentUser = member.uid == currentUid;
                        final authState = ref.watch(authControllerProvider);
                        final currentProfile = authState.userProfile;

                        final displayTitle =
                            isCurrentUser && currentProfile != null
                            ? currentProfile.effectiveDisplayName
                            : (member.displayName.isNotEmpty &&
                                      member.displayName != 'Vault User' &&
                                      member.displayName != 'Google User'
                                  ? member.displayName
                                  : (member.email.contains('@')
                                        ? member.email.split('@').first
                                        : 'Family Member'));

                        final displayEmail =
                            isCurrentUser &&
                                currentProfile?.email != null &&
                                currentProfile!.email!.isNotEmpty &&
                                currentProfile.email != 'user@familyvault.app'
                            ? currentProfile.email!
                            : member.email;

                        final initialLetter = displayTitle.isNotEmpty
                            ? displayTitle.substring(0, 1).toUpperCase()
                            : (displayEmail.isNotEmpty
                                  ? displayEmail.substring(0, 1).toUpperCase()
                                  : 'U');

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: Material(
                            color: Colors.transparent,
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isOwner
                                      ? const Color(
                                          0xFFD97706,
                                        ).withAlpha(isDark ? 40 : 25)
                                      : (isDark
                                            ? AppColors.darkSurfaceVariant
                                            : AppColors.lightSurfaceVariant),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  initialLetter,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: isOwner
                                        ? const Color(0xFFD97706)
                                        : (isDark
                                              ? AppColors.darkTextPrimary
                                              : AppColors.lightTextPrimary),
                                  ),
                                ),
                              ),
                              title: Text(
                                displayTitle,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Row(
                                children: [
                                  Text(
                                    displayEmail,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isOwner
                                          ? const Color(
                                              0xFFD97706,
                                            ).withAlpha(30)
                                          : const Color(
                                              0xFF2563EB,
                                            ).withAlpha(30),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      member.role.name.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: isOwner
                                            ? const Color(0xFFD97706)
                                            : const Color(0xFF2563EB),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              trailing: !isOwner
                                  ? IconButton(
                                      icon: Icon(
                                        isCurrentUser
                                            ? Icons.exit_to_app_rounded
                                            : Icons.remove_circle_outline_rounded,
                                        color: AppColors.lightError,
                                        size: 20,
                                      ),
                                      tooltip: isCurrentUser
                                          ? 'Leave Family Space'
                                          : 'Remove Member',
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: Text(
                                              isCurrentUser
                                                  ? 'Leave Family Space?'
                                                  : 'Remove Member?',
                                            ),
                                            content: Text(
                                              isCurrentUser
                                                  ? 'Are you sure you want to leave "${state.family!.name}"? You will lose access to shared family documents.'
                                                  : 'Remove $displayTitle from "${state.family!.name}"? They will lose access to shared documents.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, false),
                                                child: const Text('Cancel'),
                                              ),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      AppColors.lightError,
                                                  foregroundColor: Colors.white,
                                                ),
                                                onPressed: () =>
                                                    Navigator.pop(ctx, true),
                                                child: Text(
                                                  isCurrentUser
                                                      ? 'Leave'
                                                      : 'Remove',
                                                ),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirm == true) {
                                          if (isCurrentUser) {
                                            await ref
                                                .read(
                                                  familyControllerProvider
                                                      .notifier,
                                                )
                                                .leaveFamily();
                                          } else {
                                            await ref
                                                .read(
                                                  familyControllerProvider
                                                      .notifier,
                                                )
                                                .removeMember(member.uid);
                                          }
                                        }
                                      },
                                    )
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                    Builder(
                      builder: (context) {
                        final pendingInvites = state.outgoingInvitations.where((inv) {
                          if (inv.status != InvitationStatus.pending) return false;
                          final alreadyMember = state.members.any((m) =>
                              m.email.trim().toLowerCase() ==
                              inv.recipientEmail.trim().toLowerCase());
                          return !alreadyMember;
                        }).toList();

                        final declinedInvites = state.outgoingInvitations
                            .where((inv) => inv.status == InvitationStatus.declined)
                            .toList();

                        if (pendingInvites.isEmpty && declinedInvites.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (pendingInvites.isNotEmpty) ...[
                              const Divider(height: AppSpacing.large),
                              Row(
                                children: [
                                  Icon(
                                    Icons.schedule_send_rounded,
                                    size: 16,
                                    color: isDark
                                        ? AppColors.darkPrimary
                                        : AppColors.lightPrimary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Pending Invitations (${pendingInvites.length})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ...pendingInvites.map(
                                (inv) => Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppColors.darkSurfaceVariant.withAlpha(50)
                                        : AppColors.lightSurfaceVariant.withAlpha(50),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isDark
                                          ? AppColors.darkOutline.withAlpha(30)
                                          : AppColors.lightOutline.withAlpha(40),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              inv.recipientDisplayName ??
                                                  inv.recipientEmail,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                            Text(
                                              '${inv.recipientEmail} • ${inv.role.name.toUpperCase()} (Pending)',
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
                                      TextButton(
                                        style: TextButton.styleFrom(
                                          foregroundColor: AppColors.lightError,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        onPressed: () async {
                                          await ref
                                              .read(
                                                familyControllerProvider
                                                    .notifier,
                                              )
                                              .cancelInvitation(inv.invitationId);
                                        },
                                        child: const Text(
                                          'Cancel Invite',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            if (declinedInvites.isNotEmpty) ...[
                              const Divider(height: AppSpacing.large),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.cancel_outlined,
                                    size: 16,
                                    color: Colors.redAccent,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Declined Invitations (${declinedInvites.length})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ...declinedInvites.map(
                                (inv) => Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withAlpha(isDark ? 30 : 15),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.red.withAlpha(60),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              inv.recipientDisplayName ??
                                                  inv.recipientEmail,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                            Text(
                                              '${inv.recipientEmail} • Invitation Declined',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark
                                                    ? Colors.red.shade200
                                                    : Colors.red.shade800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      TextButton(
                                        style: TextButton.styleFrom(
                                          foregroundColor: isDark
                                              ? Colors.red.shade200
                                              : Colors.red.shade800,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        onPressed: () async {
                                          await ref
                                              .read(
                                                familyControllerProvider
                                                    .notifier,
                                              )
                                              .cancelInvitation(inv.invitationId);
                                        },
                                        child: const Text(
                                          'Dismiss',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.standard),

              // Document Requests Section (PRD.md Section 6.8, REQ-001 through REQ-005)
              Container(
                padding: const EdgeInsets.all(AppSpacing.standard),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurface
                      : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkOutline.withAlpha(35)
                        : AppColors.lightOutline.withAlpha(60),
                  ),
                  boxShadow: AppShadows.softCard(isDark),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Document Requests (${requestState.incomingRequests.length})',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Request Document'),
                          onPressed: () => _showCreateRequestDialog(
                            context,
                            ref,
                            state.members,
                            state.family!.familyId,
                            currentUid,
                          ),
                        ),
                      ],
                    ),
                    if (requestState.incomingRequests.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.compact,
                        ),
                        child: Text(
                          'No pending document requests.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: requestState.incomingRequests.length,
                        itemBuilder: (context, index) {
                          final req = requestState.incomingRequests[index];
                          final isPending =
                              req.status == DocumentRequestStatus.pending;

                          return Material(
                            color: Colors.transparent,
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB).withAlpha(25),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.description_rounded,
                                  color: Color(0xFF2563EB),
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                req.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                req.notes != null
                                    ? '${req.notes} • ${req.status.name.toUpperCase()}'
                                    : 'Status: ${req.status.name.toUpperCase()}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                ),
                              ),
                              trailing: isPending
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextButton(
                                          onPressed: () {
                                            ref
                                                .read(
                                                  documentRequestControllerProvider
                                                      .notifier,
                                                )
                                                .declineRequest(req.requestId);
                                          },
                                          child: const Text('Decline'),
                                        ),
                                        const SizedBox(width: 4),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 6,
                                            ),
                                            minimumSize: const Size(60, 32),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          onPressed: () => _showFulfillDialog(
                                            context,
                                            ref,
                                            req,
                                          ),
                                          child: const Text(
                                            'Fulfill',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.standard),

              // Shared Family Documents Card
              Container(
                padding: const EdgeInsets.all(AppSpacing.standard),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurface
                      : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkOutline.withAlpha(35)
                        : AppColors.lightOutline.withAlpha(60),
                  ),
                  boxShadow: AppShadows.softCard(isDark),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Shared Family Documents (${ref.watch(documentsControllerProvider).rawDocuments.where((d) => d.category == 'Family').length})',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          icon: const Icon(Icons.upload_file_rounded, size: 18),
                          label: const Text('Share Document'),
                          onPressed: () => context.go('/documents'),
                        ),
                      ],
                    ),
                    Builder(
                      builder: (context) {
                        final familyDocs = ref
                            .watch(documentsControllerProvider)
                            .rawDocuments
                            .where((d) => d.category == 'Family')
                            .toList();
                        if (familyDocs.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.compact,
                            ),
                            child: Text(
                              'No shared family documents yet. Share a document from your vault or fulfill a request above.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          );
                        }
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: familyDocs.length,
                          itemBuilder: (context, index) {
                            final doc = familyDocs[index];
                            return Material(
                              color: Colors.transparent,
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF0284C7,
                                    ).withAlpha(25),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.file_present_rounded,
                                    color: Color(0xFF0284C7),
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  doc.decryptedName ?? 'Family Document',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  'Size: ${((doc.originalSizeBytes) / 1024).toStringAsFixed(1)} KB • Encrypted with AES-256-GCM',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                trailing: const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 13,
                                  color: Colors.grey,
                                ),
                                onTap: () =>
                                    context.go('/documents/${doc.documentId}'),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.standard),

              // Invite Member Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.group_add_rounded),
                  label: const Text(
                    'Invite Family Member',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onPressed: () => _showInviteDialog(context, ref),
                ),
              ),
              const SizedBox(height: AppSpacing.standard),
            ],
          ],
        ),
      ),
    ),
  );
  }
}
