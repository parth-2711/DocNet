import * as admin from 'firebase-admin';
import { ErrorCode } from '../types';
import { successResponse, errorResponse } from '../utils/response';

export async function handleCreateFamily(
  callerUid: string,
  data: {
    familyId: string;
    encryptedFamilyName: Record<string, unknown>;
    initialKeyEnvelope?: Record<string, unknown>;
  },
  db: admin.firestore.Firestore
) {
  if (!callerUid) {
    return errorResponse(ErrorCode.UNAUTHENTICATED, 'Authentication required');
  }

  if (!data.familyId || !data.encryptedFamilyName) {
    return errorResponse(ErrorCode.INVALID_ARGUMENT, 'Missing familyId or encryptedFamilyName');
  }

  const familyRef = db.collection('families').doc(data.familyId);
  const existing = await familyRef.get();
  if (existing.exists) {
    return errorResponse(ErrorCode.ALREADY_EXISTS, 'Family already exists');
  }

  const now = new Date().toISOString();
  const familyData = {
    familyId: data.familyId,
    ownerUid: callerUid,
    encryptedFamilyName: data.encryptedFamilyName,
    memberCount: 1,
    createdAt: now,
    updatedAt: now
  };

  const memberRef = familyRef.collection('members').doc(callerUid);
  const memberData = {
    uid: callerUid,
    familyId: data.familyId,
    role: 'owner',
    joinedAt: now
  };

  const batch = db.batch();
  batch.set(familyRef, familyData);
  batch.set(memberRef, memberData);
  await batch.commit();

  return successResponse({ ...familyData, member: memberData });
}

export async function handleInviteFamilyMember(
  callerUid: string,
  data: {
    familyId: string;
    email: string;
    proposedRole?: string;
  },
  db: admin.firestore.Firestore
) {
  if (!callerUid) {
    return errorResponse(ErrorCode.UNAUTHENTICATED, 'Authentication required');
  }

  if (!data.familyId || !data.email) {
    return errorResponse(ErrorCode.INVALID_ARGUMENT, 'Missing familyId or email');
  }

  // Caller must be family owner or admin
  const memberDoc = await db.collection('families').doc(data.familyId).collection('members').doc(callerUid).get();
  if (!memberDoc.exists) {
    return errorResponse(ErrorCode.PERMISSION_DENIED, 'Caller is not a member of this family');
  }

  const memberData = memberDoc.data();
  if (memberData?.role !== 'owner' && memberData?.role !== 'admin') {
    return errorResponse(ErrorCode.PERMISSION_DENIED, 'Only owner or admin can invite members');
  }

  const token = `inv-${Date.now().toString(36)}-${Math.random().toString(36).substring(2, 10)}`;
  const expiresAt = new Date(Date.now() + 72 * 60 * 60 * 1000).toISOString(); // 72 hours

  const inviteRef = db.collection('families').doc(data.familyId).collection('invitations').doc(token);
  const inviteData = {
    token,
    familyId: data.familyId,
    invitedBy: callerUid,
    email: data.email.toLowerCase().trim(),
    role: data.proposedRole || 'member',
    status: 'pending',
    createdAt: new Date().toISOString(),
    expiresAt
  };

  await inviteRef.set(inviteData);
  return successResponse({ token, familyId: data.familyId, expiresAt });
}

export async function handleAcceptFamilyInvitation(
  callerUid: string,
  data: {
    familyId: string;
    token: string;
    displayName?: string;
  },
  db: admin.firestore.Firestore
) {
  if (!callerUid) {
    return errorResponse(ErrorCode.UNAUTHENTICATED, 'Authentication required');
  }

  const inviteRef = db.collection('families').doc(data.familyId).collection('invitations').doc(data.token);
  const inviteSnap = await inviteRef.get();

  if (!inviteSnap.exists) {
    return errorResponse(ErrorCode.NOT_FOUND, 'Invalid invitation token');
  }

  const invite = inviteSnap.data();
  if (invite?.status !== 'pending') {
    return errorResponse(ErrorCode.INVALID_ARGUMENT, 'Invitation is no longer pending');
  }

  if (new Date(invite.expiresAt) < new Date()) {
    await inviteRef.update({ status: 'expired' });
    return errorResponse(ErrorCode.INVALID_ARGUMENT, 'Invitation expired');
  }

  const now = new Date().toISOString();
  const memberRef = db.collection('families').doc(data.familyId).collection('members').doc(callerUid);

  const batch = db.batch();
  batch.update(inviteRef, { status: 'accepted', acceptedBy: callerUid, acceptedAt: now });
  batch.set(memberRef, {
    uid: callerUid,
    familyId: data.familyId,
    role: invite.role || 'member',
    displayName: data.displayName || 'Family Member',
    joinedAt: now
  });

  const familyRef = db.collection('families').doc(data.familyId);
  batch.update(familyRef, {
    memberCount: admin.firestore.FieldValue.increment(1),
    updatedAt: now
  });

  await batch.commit();
  return successResponse({ familyId: data.familyId, role: invite.role || 'member', joinedAt: now });
}

export async function handleRemoveFamilyMember(
  callerUid: string,
  data: {
    familyId: string;
    targetUid: string;
  },
  db: admin.firestore.Firestore
) {
  if (!callerUid) {
    return errorResponse(ErrorCode.UNAUTHENTICATED, 'Authentication required');
  }

  // Caller role validation
  const familyRef = db.collection('families').doc(data.familyId);
  const callerMember = await familyRef.collection('members').doc(callerUid).get();
  if (!callerMember.exists) {
    return errorResponse(ErrorCode.PERMISSION_DENIED, 'Caller is not in this family');
  }

  const callerRole = callerMember.data()?.role;
  if (callerRole !== 'owner' && callerRole !== 'admin' && callerUid !== data.targetUid) {
    return errorResponse(ErrorCode.PERMISSION_DENIED, 'Insufficient permissions to remove member');
  }

  // Cannot remove owner unless transferring ownership
  const targetMember = await familyRef.collection('members').doc(data.targetUid).get();
  if (targetMember.exists && targetMember.data()?.role === 'owner') {
    return errorResponse(ErrorCode.INVALID_ARGUMENT, 'Owner cannot be removed. Transfer ownership first.');
  }

  const batch = db.batch();
  batch.delete(familyRef.collection('members').doc(data.targetUid));
  batch.update(familyRef, {
    memberCount: admin.firestore.FieldValue.increment(-1),
    updatedAt: new Date().toISOString()
  });

  await batch.commit();
  return successResponse({ familyId: data.familyId, removedUid: data.targetUid });
}

