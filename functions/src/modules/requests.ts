import * as admin from 'firebase-admin';
import { ErrorCode } from '../types';
import { successResponse, errorResponse } from '../utils/response';

export async function handleCreateDocumentRequest(
  callerUid: string,
  data: {
    requestId: string;
    familyId: string;
    requestedCategory: string;
    note?: string;
    targetUserUid?: string;
  },
  db: admin.firestore.Firestore
) {
  if (!callerUid) {
    return errorResponse(ErrorCode.UNAUTHENTICATED, 'Authentication required');
  }

  if (!data.requestId || !data.familyId || !data.requestedCategory) {
    return errorResponse(ErrorCode.INVALID_ARGUMENT, 'Missing required document request parameters');
  }

  // Security check: REQ-002: Never accept raw government/personal identification numbers in requests
  if (data.note && /\b\d{4}[ -]?\d{4}[ -]?\d{4}\b/.test(data.note)) {
    return errorResponse(ErrorCode.INVALID_ARGUMENT, 'Raw sensitive identification numbers must not be submitted in request notes');
  }

  // Verify caller is member of family
  const memberDoc = await db.collection('families').doc(data.familyId).collection('members').doc(callerUid).get();
  if (!memberDoc.exists) {
    return errorResponse(ErrorCode.PERMISSION_DENIED, 'Caller is not a member of the specified family');
  }

  const now = new Date().toISOString();
  const expiresAt = new Date(Date.now() + 14 * 24 * 60 * 60 * 1000).toISOString(); // 14 days

  const requestRef = db.collection('documentRequests').doc(data.requestId);
  const requestData = {
    requestId: data.requestId,
    familyId: data.familyId,
    requesterUid: callerUid,
    targetUserUid: data.targetUserUid || null,
    requestedCategory: data.requestedCategory,
    note: data.note || null,
    status: 'pending',
    createdAt: now,
    expiresAt
  };

  await requestRef.set(requestData);
  return successResponse(requestData);
}

export async function handleRespondToDocumentRequest(
  callerUid: string,
  data: {
    requestId: string;
    action: 'fulfill' | 'decline';
    fulfilledDocumentId?: string;
  },
  db: admin.firestore.Firestore
) {
  if (!callerUid) {
    return errorResponse(ErrorCode.UNAUTHENTICATED, 'Authentication required');
  }

  const reqRef = db.collection('documentRequests').doc(data.requestId);
  const snap = await reqRef.get();

  if (!snap.exists) {
    return errorResponse(ErrorCode.NOT_FOUND, 'Document request not found');
  }

  const current = snap.data();
  if (current?.status !== 'pending') {
    return errorResponse(ErrorCode.INVALID_ARGUMENT, 'Request is no longer pending');
  }

  const now = new Date().toISOString();
  if (data.action === 'fulfill') {
    if (!data.fulfilledDocumentId) {
      return errorResponse(ErrorCode.INVALID_ARGUMENT, 'fulfilledDocumentId required to fulfill request');
    }
    await reqRef.update({
      status: 'fulfilled',
      fulfilledDocumentId: data.fulfilledDocumentId,
      fulfilledByUid: callerUid,
      updatedAt: now
    });
  } else {
    await reqRef.update({
      status: 'declined',
      updatedAt: now
    });
  }

  const updated = (await reqRef.get()).data();
  return successResponse(updated);
}

export async function handleListDocumentRequests(
  callerUid: string,
  data: { familyId: string },
  db: admin.firestore.Firestore
) {
  if (!callerUid) {
    return errorResponse(ErrorCode.UNAUTHENTICATED, 'Authentication required');
  }

  const query = await db
    .collection('documentRequests')
    .where('familyId', '==', data.familyId)
    .orderBy('createdAt', 'desc')
    .get();

  const requests = query.docs.map((d) => d.data());
  return successResponse({ requests, count: requests.length });
}

