import * as admin from 'firebase-admin';
import { ErrorCode, UserProfileData } from '../types';
import { successResponse, errorResponse } from '../utils/response';

export async function handleInitializeUser(
  uid: string,
  data: { displayName?: string; language?: string; keyProfileId?: string },
  db: admin.firestore.Firestore
) {
  if (!uid) {
    return errorResponse(ErrorCode.UNAUTHENTICATED, 'Authentication required');
  }

  const userRef = db.collection('users').doc(uid);
  const snap = await userRef.get();

  const now = new Date().toISOString();

  if (snap.exists) {
    const existing = snap.data() as UserProfileData;
    return successResponse(existing);
  }

  const newProfile: UserProfileData = {
    uid,
    displayName: data.displayName || 'Vault User',
    language: data.language || 'en',
    themeMode: 'system',
    onboardingCompleted: false,
    createdAt: now,
    updatedAt: now
  };

  await userRef.set(newProfile);
  return successResponse(newProfile);
}

export async function handleGetUserProfile(
  callerUid: string,
  targetUid: string | undefined,
  db: admin.firestore.Firestore
) {
  if (!callerUid) {
    return errorResponse(ErrorCode.UNAUTHENTICATED, 'Authentication required');
  }

  const requestedUid = targetUid || callerUid;
  // Non-self lookups require validation; by default users can only read their own profile
  if (requestedUid !== callerUid) {
    return errorResponse(ErrorCode.PERMISSION_DENIED, 'Access denied to requested profile');
  }

  const snap = await db.collection('users').doc(requestedUid).get();
  if (!snap.exists) {
    return errorResponse(ErrorCode.NOT_FOUND, 'User profile not found');
  }

  return successResponse(snap.data() as UserProfileData);
}

export async function handleUpdateUserProfile(
  uid: string,
  data: { displayName?: string; language?: string; themeMode?: string },
  db: admin.firestore.Firestore
) {
  if (!uid) {
    return errorResponse(ErrorCode.UNAUTHENTICATED, 'Authentication required');
  }

  const userRef = db.collection('users').doc(uid);
  const snap = await userRef.get();
  if (!snap.exists) {
    return errorResponse(ErrorCode.NOT_FOUND, 'User profile not found');
  }

  const now = new Date().toISOString();
  const updates: Partial<UserProfileData> = {
    updatedAt: now
  };

  if (data.displayName !== undefined) updates.displayName = data.displayName;
  if (data.language !== undefined) updates.language = data.language;
  if (data.themeMode !== undefined) updates.themeMode = data.themeMode;

  await userRef.update(updates);
  const updated = (await userRef.get()).data() as UserProfileData;
  return successResponse(updated);
}

