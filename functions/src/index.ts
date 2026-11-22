import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';

import { handleInitializeUser, handleGetUserProfile, handleUpdateUserProfile } from './modules/users';
import { handleRegisterDevice, handleRevokeDevice } from './modules/devices';
import {
  handleCreateDocument,
  handleRequestUpload,
  handleCompleteUpload,
  handleListDocuments,
  handleDeleteDocument
} from './modules/documents';
import { handleGrantDocumentAccess, handleRevokeDocumentAccess, handleGetAuthorizedKeyEnvelope } from './modules/sharing';
import {
  handleCreateFamily,
  handleInviteFamilyMember,
  handleAcceptFamilyInvitation,
  handleRemoveFamilyMember
} from './modules/family';
import {
  handleCreateDocumentRequest,
  handleRespondToDocumentRequest,
  handleListDocumentRequests
} from './modules/requests';
import { handleGetSyncManifest, handleResolveSyncConflict } from './modules/sync';

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const storage = admin.storage();

function getCallerUid(request: { auth?: { uid: string } }): string {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError('unauthenticated', 'User must be authenticated.');
  }
  return request.auth.uid;
}

// ==================== User & Device Endpoints ====================

export const initializeUser = onCall(async (request) => {
  const uid = getCallerUid(request);
  return handleInitializeUser(uid, request.data, db);
});

export const getUserProfile = onCall(async (request) => {
  const uid = getCallerUid(request);
  return handleGetUserProfile(uid, request.data?.targetUid, db);
});

export const updateUserProfile = onCall(async (request) => {
  const uid = getCallerUid(request);
  return handleUpdateUserProfile(uid, request.data, db);
});

export const registerDevice = onCall(async (request) => {
  const uid = getCallerUid(request);
  return handleRegisterDevice(uid, request.data, db);
});

export const revokeDevice = onCall(async (request) => {
  const uid = getCallerUid(request);
  return handleRevokeDevice(uid, request.data, db);
});

// ==================== Document Endpoints ====================

export const createDocument = onCall(async (request) => {
  const uid = getCallerUid(request);
  return handleCreateDocument(uid, request.data, db);
});

export const requestUpload = onCall(async (request) => {
  const uid = getCallerUid(request);
  return handleRequestUpload(uid, request.data, db);
});

export const completeUpload = onCall(async (request) => {
  const uid = getCallerUid(request);
  return handleCompleteUpload(uid, request.data, db, storage);
});

export const listDocuments = onCall(async (request) => {
  const uid = getCallerUid(request);
  return handleListDocuments(uid, request.data || {}, db);
});

export const deleteDocument = onCall(async (request) => {
  const uid = getCallerUid(request);
  return handleDeleteDocument(uid, request.data, db);
});

// ==================== Sharing Endpoints ====================

export const grantDocumentAccess = onCall(async (request) => {
  const uid = getCallerUid(request);
  return handleGrantDocumentAccess(uid, request.data, db);
});

export const revokeDocumentAccess = onCall(async (request) => {
  const uid = getCallerUid(request);
  return handleRevokeDocumentAccess(uid, request.data, db);
});

export const getAuthorizedKeyEnvelope = onCall(async (request) => {
  const uid = getCallerUid(request);
  return handleGetAuthorizedKeyEnvelope(uid, request.data, db);
});

// ==================== Family Endpoints ====================

export const createFamily = onCall(async (request) => {
  const uid = getCallerUid(request);
  return handleCreateFamily(uid, request.data, db);
});

export const inviteFamilyMember = onCall(async (request) => {
  const uid = getCallerUid(request);
  return handleInviteFamilyMember(uid, request.data, db);
});

export const acceptFamilyInvitation = onCall(async (request) => {
  const uid = getCallerUid(request);
  return handleAcceptFamilyInvitation(uid, request.data, db);
});

export const removeFamilyMember = onCall(async (request) => {
  const uid = getCallerUid(request);
  return handleRemoveFamilyMember(uid, request.data, db);
});

// ==================== Document Requests ====================

export const createDocumentRequest = onCall(async (request) => {
  const uid = getCallerUid(request);
  return handleCreateDocumentRequest(uid, request.data, db);
});

export const respondToDocumentRequest = onCall(async (request) => {
  const uid = getCallerUid(request);
  return handleRespondToDocumentRequest(uid, request.data, db);
});

export const listDocumentRequests = onCall(async (request) => {
  const uid = getCallerUid(request);
  return handleListDocumentRequests(uid, request.data, db);
});

// ==================== Sync Endpoints ====================

export const getSyncManifest = onCall(async (request) => {
  const uid = getCallerUid(request);
  return handleGetSyncManifest(uid, request.data || {}, db);
});

export const resolveSyncConflict = onCall(async (request) => {
  const uid = getCallerUid(request);
  return handleResolveSyncConflict(uid, request.data, db);
});

