import * as admin from 'firebase-admin';
import { ErrorCode } from '../types';
import { successResponse, errorResponse } from '../utils/response';

export async function handleGetSyncManifest(
  uid: string,
  data: {
    cursor?: string | null;
    pageSize?: number;
    vaultScopes?: string[];
  },
  db: admin.firestore.Firestore
) {
  if (!uid) {
    return errorResponse(ErrorCode.UNAUTHENTICATED, 'Authentication required');
  }

  const limit = Math.min(Math.max(data.pageSize || 50, 1), 100);
  let query = db
    .collection('users')
    .doc(uid)
    .collection('documents')
    .orderBy('updatedAt', 'asc')
    .limit(limit);

  if (data.cursor) {
    query = query.startAfter(data.cursor);
  }

  const snapshot = await query.get();
  const items = snapshot.docs.map((doc) => {
    const d = doc.data();
    return {
      documentId: d.documentId,
      vaultScope: d.vaultType || 'personal',
      currentVersionId: d.currentVersionId || '',
      versionNumber: d.versionCount || 1,
      updatedAt: d.updatedAt,
      isDeleted: d.isDeleted || false,
      encryptedMetadataRef: `users/${uid}/documents/${d.documentId}/meta.bin`
    };
  });

  const nextCursor = items.length === limit ? items[items.length - 1].updatedAt : null;
  return successResponse({
    items,
    cursor: nextCursor,
    timestamp: new Date().toISOString()
  });
}

export async function handleResolveSyncConflict(
  uid: string,
  data: {
    documentId: string;
    chosenVersionId: string;
    expectedParentVersionId?: string | null;
    strategy: 'keepRemote' | 'keepLocal' | 'saveBoth';
  },
  db: admin.firestore.Firestore
) {
  if (!uid) {
    return errorResponse(ErrorCode.UNAUTHENTICATED, 'Authentication required');
  }

  const docRef = db.collection('users').doc(uid).collection('documents').doc(data.documentId);
  const snap = await docRef.get();
  if (!snap.exists) {
    return errorResponse(ErrorCode.NOT_FOUND, 'Document not found');
  }

  const now = new Date().toISOString();

  if (data.strategy === 'keepRemote') {
    // Retain remote version as current, discard local
    return successResponse({ resolvedStrategy: 'keepRemote', status: 'resolved' });
  }

  if (data.strategy === 'keepLocal') {
    // Advance currentVersionId to chosenVersionId
    await docRef.update({
      currentVersionId: data.chosenVersionId,
      updatedAt: now
    });
    return successResponse({ resolvedStrategy: 'keepLocal', newVersionId: data.chosenVersionId });
  }

  // saveBoth: Keep remote as is, client creates separate forked document
  return successResponse({ resolvedStrategy: 'saveBoth', status: 'forkPrepared' });
}

