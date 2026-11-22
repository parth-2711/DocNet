import * as admin from 'firebase-admin';
import { ErrorCode, DeviceRecordData } from '../types';
import { successResponse, errorResponse } from '../utils/response';

export async function handleRegisterDevice(
  uid: string,
  data: {
    deviceId: string;
    platform: string;
    deviceLabel: string;
    publicKey: string;
    keyFingerprint: string;
    appVersion?: string;
  },
  db: admin.firestore.Firestore
) {
  if (!uid) {
    return errorResponse(ErrorCode.UNAUTHENTICATED, 'Authentication required');
  }

  if (!data.deviceId || !data.publicKey || !data.keyFingerprint) {
    return errorResponse(ErrorCode.INVALID_ARGUMENT, 'Missing required device registration fields');
  }

  // Security check: Never accept private key material (API_SPECIFICATION.md Section 2)
  if (JSON.stringify(data).toLowerCase().includes('privatekey')) {
    return errorResponse(ErrorCode.INVALID_ARGUMENT, 'Private keys must never be transmitted');
  }

  const deviceRef = db.collection('users').doc(uid).collection('devices').doc(data.deviceId);
  const existing = await deviceRef.get();

  const now = new Date().toISOString();

  if (existing.exists) {
    const existingData = existing.data() as DeviceRecordData;
    // Check if device was revoked
    if (existingData.status === 'revoked') {
      return errorResponse(ErrorCode.PERMISSION_DENIED, 'Revoked device cannot be re-registered without re-enrollment challenge');
    }

    const updated: Partial<DeviceRecordData> = {
      deviceLabel: data.deviceLabel || existingData.deviceLabel,
      appVersion: data.appVersion || existingData.appVersion,
      lastSeenAt: now
    };
    await deviceRef.update(updated);
    return successResponse({ ...existingData, ...updated });
  }

  const newDevice: DeviceRecordData = {
    deviceId: data.deviceId,
    platform: data.platform || 'Unknown',
    deviceLabel: data.deviceLabel || 'New Device',
    publicKey: data.publicKey,
    keyFingerprint: data.keyFingerprint,
    appVersion: data.appVersion || '1.0.0',
    enrolledAt: now,
    lastSeenAt: now,
    status: 'active'
  };

  await deviceRef.set(newDevice);
  return successResponse(newDevice);
}

export async function handleRevokeDevice(
  uid: string,
  data: { deviceId: string; revokeAllOthers?: boolean },
  db: admin.firestore.Firestore
) {
  if (!uid) {
    return errorResponse(ErrorCode.UNAUTHENTICATED, 'Authentication required');
  }

  if (!data.deviceId && !data.revokeAllOthers) {
    return errorResponse(ErrorCode.INVALID_ARGUMENT, 'Missing deviceId');
  }

  const devicesRef = db.collection('users').doc(uid).collection('devices');
  const now = new Date().toISOString();

  if (data.revokeAllOthers) {
    const all = await devicesRef.where('status', '==', 'active').get();
    const batch = db.batch();
    let count = 0;

    for (const doc of all.docs) {
      if (doc.id !== data.deviceId) {
        batch.update(doc.ref, { status: 'revoked', revokedAt: now });
        count++;
      }
    }
    await batch.commit();
    return successResponse({ revokedCount: count, message: 'All other sessions revoked' });
  }

  const deviceDoc = await devicesRef.doc(data.deviceId).get();
  if (!deviceDoc.exists) {
    return errorResponse(ErrorCode.NOT_FOUND, 'Device not found');
  }

  await deviceDoc.ref.update({
    status: 'revoked',
    revokedAt: now
  });

  return successResponse({ deviceId: data.deviceId, status: 'revoked' });
}

