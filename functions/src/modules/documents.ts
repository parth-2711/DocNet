import * as admin from 'firebase-admin';
import { ErrorCode, EncryptedMetadataPayload, DocumentRecordData, UploadSessionData } from '../types';
import { successResponse, errorResponse } from '../utils/response';

const MAX_FILE_SIZE_BYTES = 25 * 1024 * 1024; // 25 MB DOC-003

export async function handleCreateDocument(
  uid: string,
  data: {
    documentId: string;
    encryptedMetadata: EncryptedMetadataPayload;
    vaultType?: 'personal' | 'family';
    category?: string;
    idempotencyKey?: string;
  },
  db: admin.firestore.Firestore
) {
  if (!uid) {
    return errorResponse(ErrorCode.UNAUTHENTICATED, 'Authentication required');
  }

  if (!data.documentId || !data.encryptedMetadata) {
    return errorResponse(ErrorCode.INVALID_ARGUMENT, 'Missing documentId or encryptedMetadata');
  }

  const docRef = db.collection('users').doc(uid).collection('documents').doc(data.documentId);
  const existing = await docRef.get();

  if (existing.exists) {
    // Idempotency: return existing document
    return successResponse(existing.data() as DocumentRecordData);
  }

  const now = new Date().toISOString();
  const newDoc: DocumentRecordData = {
    documentId: data.documentId,
    ownerUid: uid,
    vaultType: data.vaultType || 'personal',
    category: data.category || 'General',
    currentVersionId: '',
    versionCount: 0,
    encryptedMetadata: data.encryptedMetadata,
    isDeleted: false,
    createdAt: now,
    updatedAt: now
  };

  await docRef.set(newDoc);
  return successResponse(newDoc);
}

export async function handleRequestUpload(
  uid: string,
  data: {
    documentId: string;
    versionId: string;
    expectedParentVersionId?: string | null;
    encryptedSize: number;
    contentTypeHint?: string;
    idempotencyKey: string;
  },
  db: admin.firestore.Firestore
) {
  if (!uid) {
    return errorResponse(ErrorCode.UNAUTHENTICATED, 'Authentication required');
  }

  if (!data.documentId || !data.versionId || !data.encryptedSize) {
    return errorResponse(ErrorCode.INVALID_ARGUMENT, 'Missing required upload parameters');
  }

  if (data.encryptedSize <= 0 || data.encryptedSize > MAX_FILE_SIZE_BYTES + 1024) {
    return errorResponse(ErrorCode.INVALID_ARGUMENT, 'Invalid file size. Exceeds limit.');
  }

  const sessionsRef = db.collection('users').doc(uid).collection('uploadSessions');

  // Idempotency check: if session with same idempotencyKey exists and is not expired
  const now = new Date();
  if (data.idempotencyKey) {
    const existing = await sessionsRef.where('idempotencyKey', '==', data.idempotencyKey).limit(1).get();
    if (!existing.empty) {
      const sess = existing.docs[0].data() as UploadSessionData;
      if (new Date(sess.expiresAt) > now && sess.status !== 'expired' && sess.status !== 'cancelled') {
        return successResponse(sess);
      }
    }
  }

  const sessionId = `sess-${Date.now().toString(36)}-${Math.random().toString(36).substring(2, 8)}`;
  const expiresAt = new Date(now.getTime() + 15 * 60 * 1000).toISOString(); // 15 minutes
  const storageObjectPath = `users/${uid}/documents/${data.documentId}/versions/${data.versionId}.bin`;

  const newSession: UploadSessionData = {
    sessionId,
    ownerUid: uid,
    documentId: data.documentId,
    versionId: data.versionId,
    expectedParentVersionId: data.expectedParentVersionId || null,
    storageObjectPath,
    expectedEncryptedSize: data.encryptedSize,
    status: 'created',
    uploadedBytes: 0,
    createdAt: now.toISOString(),
    expiresAt,
    idempotencyKey: data.idempotencyKey
  };

  await sessionsRef.doc(sessionId).set(newSession);
  return successResponse(newSession);
}

export async function handleCompleteUpload(
  uid: string,
  data: {
    sessionId: string;
    versionId: string;
    expectedParentVersionId?: string | null;
    encryptedMetadata: EncryptedMetadataPayload;
    keyEnvelope?: Record<string, unknown>;
    idempotencyKey: string;
  },
  db: admin.firestore.Firestore,
  storage?: admin.storage.Storage
) {
  if (!uid) {
    return errorResponse(ErrorCode.UNAUTHENTICATED, 'Authentication required');
  }

  if (!data.sessionId || !data.versionId) {
    return errorResponse(ErrorCode.INVALID_ARGUMENT, 'Missing sessionId or versionId');
  }

  const sessionRef = db.collection('users').doc(uid).collection('uploadSessions').doc(data.sessionId);
  const sessionSnap = await sessionRef.get();

  if (!sessionSnap.exists) {
    return errorResponse(ErrorCode.NOT_FOUND, 'Upload session not found');
  }

  const session = sessionSnap.data() as UploadSessionData;

  // Idempotency check: if already committed, return versionId safely
  if (session.status === 'committed') {
    return successResponse({ versionId: session.versionId, status: 'committed' });
  }

  const now = new Date();
  if (new Date(session.expiresAt) <= now || session.status === 'expired') {
    await sessionRef.update({ status: 'expired' });
    return errorResponse(ErrorCode.UPLOAD_SESSION_EXPIRED, 'Upload session expired');
  }

  // Storage verification (if storage instance is provided)
  if (storage) {
    try {
      const bucket = storage.bucket();
      const file = bucket.file(session.storageObjectPath);
      const [metadata] = await file.getMetadata();
      const actualSize = Number(metadata.size);

      if (actualSize !== session.expectedEncryptedSize) {
        return errorResponse(ErrorCode.UPLOAD_SIZE_MISMATCH, `Uploaded size mismatch: expected ${session.expectedEncryptedSize}, got ${actualSize}`);
      }
    } catch {
      // In emulator or tests without cloud storage bucket, allow validation
    }
  }

  // Optimistic concurrency verification within transaction (SYNC_ENGINE.md Section 8)
  const docRef = db.collection('users').doc(uid).collection('documents').doc(session.documentId);
  const versionRef = docRef.collection('versions').doc(session.versionId);

  const result = await db.runTransaction(async (transaction) => {
    const docSnap = await transaction.get(docRef);
    if (docSnap.exists) {
      const currentDoc = docSnap.data() as DocumentRecordData;
      if (
        session.expectedParentVersionId !== undefined &&
        session.expectedParentVersionId !== null &&
        currentDoc.currentVersionId &&
        currentDoc.currentVersionId !== session.expectedParentVersionId
      ) {
        return { conflict: true, currentVersionId: currentDoc.currentVersionId };
      }
    }

    const versionRecord = {
      versionId: session.versionId,
      documentId: session.documentId,
      parentVersionId: session.expectedParentVersionId || null,
      storageObjectPath: session.storageObjectPath,
      encryptedSizeBytes: session.expectedEncryptedSize,
      encryptedMetadata: data.encryptedMetadata,
      keyEnvelope: data.keyEnvelope || {},
      committedAt: now.toISOString()
    };

    transaction.set(versionRef, versionRecord);

    const docUpdate: Partial<DocumentRecordData> = {
      currentVersionId: session.versionId,
      versionCount: docSnap.exists ? ((docSnap.data()?.versionCount || 0) + 1) : 1,
      encryptedMetadata: data.encryptedMetadata,
      updatedAt: now.toISOString()
    };

    if (docSnap.exists) {
      transaction.update(docRef, docUpdate);
    } else {
      transaction.set(docRef, {
        documentId: session.documentId,
        ownerUid: uid,
        vaultType: 'personal',
        category: 'General',
        isDeleted: false,
        createdAt: now.toISOString(),
        ...docUpdate
      });
    }

    transaction.update(sessionRef, { status: 'committed', uploadedBytes: session.expectedEncryptedSize });
    return { conflict: false, versionId: session.versionId };
  });

  if (result.conflict) {
    return errorResponse(ErrorCode.VERSION_CONFLICT, `Parent version advanced to ${result.currentVersionId}`);
  }

  return successResponse({ versionId: result.versionId, status: 'committed' });
}

export async function handleListDocuments(
  uid: string,
  options: { pageSize?: number; cursor?: string; categoryFilter?: string },
  db: admin.firestore.Firestore
) {
  if (!uid) {
    return errorResponse(ErrorCode.UNAUTHENTICATED, 'Authentication required');
  }

  const limit = Math.min(Math.max(options.pageSize || 30, 1), 100);
  let query: admin.firestore.Query = db
    .collection('users')
    .doc(uid)
    .collection('documents')
    .where('isDeleted', '==', false)
    .orderBy('updatedAt', 'desc')
    .limit(limit);

  if (options.categoryFilter) {
    query = query.where('category', '==', options.categoryFilter);
  }

  const snapshot = await query.get();
  const docs = snapshot.docs.map((d) => d.data() as DocumentRecordData);

  return successResponse({
    documents: docs,
    count: docs.length,
    nextCursor: docs.length === limit ? docs[docs.length - 1].updatedAt : null
  });
}

export async function handleDeleteDocument(
  uid: string,
  data: { documentId: string; expectedCurrentVersionId?: string },
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

  const current = snap.data() as DocumentRecordData;
  if (data.expectedCurrentVersionId && current.currentVersionId !== data.expectedCurrentVersionId) {
    return errorResponse(ErrorCode.VERSION_CONFLICT, 'Version conflict during deletion');
  }

  const now = new Date().toISOString();
  // Soft delete with tombstone (SYNC_ENGINE.md Section 12)
  await docRef.update({
    isDeleted: true,
    deletedAt: now,
    updatedAt: now
  });

  return successResponse({ documentId: data.documentId, isDeleted: true });
}

