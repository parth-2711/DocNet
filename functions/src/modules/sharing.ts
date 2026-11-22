import * as admin from 'firebase-admin';
import { ErrorCode } from '../types';
import { successResponse, errorResponse } from '../utils/response';

export async function handleGrantDocumentAccess(
  callerUid: string,
  data: {
    documentId: string;
    recipientUid: string;
    familyId?: string;
    permissions: {
      view: boolean;
      download: boolean;
      replace: boolean;
      reshare: boolean;
    };
    wrappedKeyEnvelope: Record<string, unknown>;
    expiresAt?: string | null;
  },
  db: admin.firestore.Firestore
) {
  if (!callerUid) {
    return errorResponse(ErrorCode.UNAUTHENTICATED, 'Authentication required');
  }

  if (!data.documentId || !data.recipientUid || !data.wrappedKeyEnvelope) {
    return errorResponse(ErrorCode.INVALID_ARGUMENT, 'Missing documentId, recipientUid, or wrappedKeyEnvelope');
  }

  // Security check: Verify caller owns document
  const docRef = db.collection('users').doc(callerUid).collection('documents').doc(data.documentId);
  const docSnap = await docRef.get();
  if (!docSnap.exists) {
    return errorResponse(ErrorCode.NOT_FOUND, 'Document not found');
  }

  const now = new Date().toISOString();
  const shareId = `${data.documentId}_${data.recipientUid}`;
  const shareRef = db.collection('shares').doc(shareId);

  const shareRecord = {
    shareId,
    documentId: data.documentId,
    ownerUid: callerUid,
    recipientUid: data.recipientUid,
    familyId: data.familyId || null,
    permissions: data.permissions,
    wrappedKeyEnvelope: data.wrappedKeyEnvelope,
    status: 'active',
    grantedAt: now,
    expiresAt: data.expiresAt || null
  };

  await shareRef.set(shareRecord);
  return successResponse(shareRecord);
}

export async function handleRevokeDocumentAccess(
  callerUid: string,
  data: { shareId?: string; documentId?: string; recipientUid?: string },
  db: admin.firestore.Firestore
) {
  if (!callerUid) {
    return errorResponse(ErrorCode.UNAUTHENTICATED, 'Authentication required');
  }

  let shareRef: admin.firestore.DocumentReference;
  if (data.shareId) {
    shareRef = db.collection('shares').doc(data.shareId);
  } else if (data.documentId && data.recipientUid) {
    shareRef = db.collection('shares').doc(`${data.documentId}_${data.recipientUid}`);
  } else {
    return errorResponse(ErrorCode.INVALID_ARGUMENT, 'Missing share identifier');
  }

  const snap = await shareRef.get();
  if (!snap.exists) {
    return errorResponse(ErrorCode.NOT_FOUND, 'Share record not found');
  }

  const shareData = snap.data();
  if (shareData?.ownerUid !== callerUid) {
    return errorResponse(ErrorCode.PERMISSION_DENIED, 'Only the document owner can revoke access');
  }

  await shareRef.update({
    status: 'revoked',
    revokedAt: new Date().toISOString()
  });

  return successResponse({ shareId: shareRef.id, status: 'revoked' });
}

export async function handleGetAuthorizedKeyEnvelope(
  callerUid: string,
  data: { documentId: string; ownerUid?: string },
  db: admin.firestore.Firestore
) {
  if (!callerUid) {
    return errorResponse(ErrorCode.UNAUTHENTICATED, 'Authentication required');
  }

  // Look for active share record for caller
  const shareSnap = await db
    .collection('shares')
    .where('documentId', '==', data.documentId)
    .where('recipientUid', '==', callerUid)
    .where('status', '==', 'active')
    .limit(1)
    .get();

  if (shareSnap.empty) {
    return errorResponse(ErrorCode.PERMISSION_DENIED, 'No active key envelope authorized for caller');
  }

  const record = shareSnap.docs[0].data();
  return successResponse({
    documentId: data.documentId,
    wrappedKeyEnvelope: record.wrappedKeyEnvelope,
    permissions: record.permissions
  });
}

