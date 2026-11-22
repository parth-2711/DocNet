import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:docnet/core/logging/app_logger.dart';
import 'package:docnet/core/storage/local_vault_storage_service.dart';
import '../../domain/entities/family_invitation.dart';
import '../../domain/repositories/family_invitation_repository.dart';

/// Persistent implementation of FamilyInvitationRepository saving invitations
/// directly to on-device secure storage and synchronizing with Cloud Firestore
/// across application restarts and multiple devices.
class PersistentFamilyInvitationRepository
    implements FamilyInvitationRepository {
  final LocalVaultStorageService storageService;

  final Map<String, FamilyInvitation> _invitations = {};
  bool _loaded = false;

  PersistentFamilyInvitationRepository(this.storageService);

  static bool get _isTestEnvironment =>
      Platform.environment.containsKey('FLUTTER_TEST') ||
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  bool get _canUseFirestore =>
      Firebase.apps.isNotEmpty && !_isTestEnvironment;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;

    try {
      final data = await storageService.readJson('family_invitations');
      if (data is List) {
        for (final item in data) {
          if (item is Map<String, dynamic>) {
            final inv = FamilyInvitation.fromMap(item);
            _invitations[inv.invitationId] = inv;
          }
        }
      }
    } catch (_) {
      // Ignore initial missing file
    } finally {
      _loaded = true;
    }
  }

  Future<void> _persist() async {
    final list = _invitations.values.map((i) => i.toMap()).toList();
    await storageService.saveJson('family_invitations', list);
  }

  @override
  Future<void> saveInvitation(FamilyInvitation invitation) async {
    await _ensureLoaded();
    _invitations[invitation.invitationId] = invitation;
    await _persist();

    if (_canUseFirestore) {
      try {
        await _firestore
            .collection('family_invitations')
            .doc(invitation.invitationId)
            .set(invitation.toMap(), SetOptions(merge: true));
        AppLogger.info(
          'PersistentFamilyInvitationRepository',
          'Synced invitation ${invitation.invitationId} to Firestore',
        );
      } catch (e) {
        AppLogger.warn(
          'PersistentFamilyInvitationRepository',
          'Failed to sync invitation to Firestore: $e',
        );
      }
    }
  }

  @override
  Future<FamilyInvitation?> getInvitation(String invitationId) async {
    await _ensureLoaded();
    final existing = _invitations[invitationId];
    if (existing != null) return existing;

    if (_canUseFirestore) {
      try {
        final doc = await _firestore
            .collection('family_invitations')
            .doc(invitationId)
            .get();
        if (doc.exists && doc.data() != null) {
          final inv = FamilyInvitation.fromMap(doc.data()!);
          _invitations[inv.invitationId] = inv;
          await _persist();
          return inv;
        }
      } catch (e) {
        AppLogger.warn(
          'PersistentFamilyInvitationRepository',
          'Failed to fetch invitation from Firestore: $e',
        );
      }
    }
    return null;
  }

  @override
  Future<List<FamilyInvitation>> getIncomingInvitations({
    required String recipientUid,
    required String recipientEmail,
  }) async {
    await _ensureLoaded();
    final normalizedEmail = recipientEmail.trim().toLowerCase();

    if (_canUseFirestore) {
      try {
        if (normalizedEmail.isNotEmpty) {
          final snapshot = await _firestore
              .collection('family_invitations')
              .where('recipientEmail', isEqualTo: normalizedEmail)
              .where('status', isEqualTo: 'pending')
              .get();
          for (final doc in snapshot.docs) {
            final inv = FamilyInvitation.fromMap(doc.data());
            _invitations[inv.invitationId] = inv;
          }
        }
        if (recipientUid.isNotEmpty) {
          final snapshotUid = await _firestore
              .collection('family_invitations')
              .where('recipientUid', isEqualTo: recipientUid)
              .where('status', isEqualTo: 'pending')
              .get();
          for (final doc in snapshotUid.docs) {
            final inv = FamilyInvitation.fromMap(doc.data());
            _invitations[inv.invitationId] = inv;
          }
        }
        await _persist();
      } catch (e) {
        AppLogger.warn(
          'PersistentFamilyInvitationRepository',
          'Failed to fetch incoming invitations from Firestore: $e',
        );
      }
    }

    final results = _invitations.values.where((inv) {
      if (inv.status != InvitationStatus.pending) return false;
      final matchesUid =
          inv.recipientUid != null &&
          inv.recipientUid!.isNotEmpty &&
          inv.recipientUid == recipientUid;
      final matchesEmail =
          normalizedEmail.isNotEmpty &&
          inv.recipientEmail.trim().toLowerCase() == normalizedEmail;
      return matchesUid || matchesEmail;
    }).toList();

    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return results;
  }

  @override
  Future<List<FamilyInvitation>> getOutgoingInvitations(String familyId) async {
    await _ensureLoaded();

    if (_canUseFirestore) {
      try {
        final snapshot = await _firestore
            .collection('family_invitations')
            .where('familyId', isEqualTo: familyId)
            .where('status', isEqualTo: 'pending')
            .get();
        for (final doc in snapshot.docs) {
          final inv = FamilyInvitation.fromMap(doc.data());
          _invitations[inv.invitationId] = inv;
        }
        await _persist();
      } catch (e) {
        AppLogger.warn(
          'PersistentFamilyInvitationRepository',
          'Failed to fetch outgoing invitations from Firestore: $e',
        );
      }
    }

    final results = _invitations.values.where((inv) {
      return inv.familyId == familyId &&
          inv.status == InvitationStatus.pending;
    }).toList();

    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return results;
  }

  @override
  Future<void> updateInvitationStatus({
    required String invitationId,
    required InvitationStatus status,
  }) async {
    await _ensureLoaded();
    final existing = _invitations[invitationId];
    final now = DateTime.now().toUtc();
    if (existing != null) {
      _invitations[invitationId] = existing.copyWith(
        status: status,
        respondedAt: now,
      );
      await _persist();
    }

    if (_canUseFirestore) {
      try {
        await _firestore
            .collection('family_invitations')
            .doc(invitationId)
            .update({
              'status': status.name,
              'respondedAt': now.toIso8601String(),
            });
      } catch (e) {
        AppLogger.warn(
          'PersistentFamilyInvitationRepository',
          'Failed to update invitation status in Firestore: $e',
        );
      }
    }
  }

  @override
  Future<void> deleteInvitation(String invitationId) async {
    await _ensureLoaded();
    _invitations.remove(invitationId);
    await _persist();

    if (_canUseFirestore) {
      try {
        await _firestore
            .collection('family_invitations')
            .doc(invitationId)
            .delete();
      } catch (_) {}
    }
  }
}
