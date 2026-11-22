/**
 * Standard API conventions and types (API_SPECIFICATION.md Sections 1 & 11).
 */

export interface StandardSuccessResponse<T> {
  success: true;
  data: T;
  error: null;
  requestId: string;
}

export interface ApiErrorDetail {
  code: string;
  message: string;
}

export interface StandardErrorResponse {
  success: false;
  data: null;
  error: ApiErrorDetail;
  requestId: string;
}

export type StandardResponse<T> = StandardSuccessResponse<T> | StandardErrorResponse;

export enum ErrorCode {
  UNAUTHENTICATED = 'UNAUTHENTICATED',
  PERMISSION_DENIED = 'PERMISSION_DENIED',
  INVALID_ARGUMENT = 'INVALID_ARGUMENT',
  NOT_FOUND = 'NOT_FOUND',
  ALREADY_EXISTS = 'ALREADY_EXISTS',
  VERSION_CONFLICT = 'VERSION_CONFLICT',
  UPLOAD_SESSION_EXPIRED = 'UPLOAD_SESSION_EXPIRED',
  UPLOAD_SIZE_MISMATCH = 'UPLOAD_SIZE_MISMATCH',
  RATE_LIMITED = 'RATE_LIMITED',
  INTERNAL = 'INTERNAL'
}

export interface UserProfileData {
  uid: string;
  displayName: string;
  email?: string;
  language: string;
  themeMode?: string;
  onboardingCompleted: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface DeviceRecordData {
  deviceId: string;
  platform: string;
  deviceLabel: string;
  publicKey: string;
  keyFingerprint: string;
  appVersion: string;
  enrolledAt: string;
  lastSeenAt: string;
  status: 'active' | 'revoked';
}

export interface EncryptedMetadataPayload {
  ciphertext: string;
  nonce: string;
  tag: string;
  formatVersion: number;
}

export interface DocumentRecordData {
  documentId: string;
  ownerUid: string;
  vaultType: 'personal' | 'family';
  category: string;
  currentVersionId: string;
  versionCount: number;
  encryptedMetadata: EncryptedMetadataPayload;
  isDeleted: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface UploadSessionData {
  sessionId: string;
  ownerUid: string;
  documentId: string;
  versionId: string;
  expectedParentVersionId?: string | null;
  storageObjectPath: string;
  expectedEncryptedSize: number;
  status: 'created' | 'uploading' | 'uploaded' | 'committed' | 'expired' | 'cancelled';
  uploadedBytes: number;
  createdAt: string;
  expiresAt: string;
  idempotencyKey: string;
}

