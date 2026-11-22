# FamilyVault — API Specification

**Backend:** Firebase Cloud Functions Gen 2 (TypeScript)  
**Authentication:** Firebase Authentication  
**Authorization:** Server-side checks plus Firestore/Storage Rules  
**Version:** 1.0

## 1. API conventions

### 1.1 Transport

- Callable functions for authenticated app workflows.
- HTTPS endpoints for workflows requiring explicit HTTP semantics or transfer authorization.
- Firebase SDKs for supported direct Firestore and Storage operations.
- All sensitive operations require a valid authenticated principal.
- Enforce App Check where supported and appropriate.

### 1.2 Standard success response

```json
{
  "success": true,
  "data": {},
  "error": null,
  "requestId": "request-id"
}
```

### 1.3 Standard error response

```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "PERMISSION_DENIED",
    "message": "The requested operation is not permitted."
  },
  "requestId": "request-id"
}
```

Do not return internal stack traces, secrets, object credentials, or sensitive existence information.

### 1.4 Common validation

Every function validates:
- Authentication UID.
- App Check where configured.
- Payload schema and size.
- Resource existence without leaking unauthorized existence.
- Ownership and membership.
- Permission scope.
- Quota.
- Rate limit.
- Idempotency where operation can be retried.
- State transition validity.

### 1.5 Idempotency

Mutating operations accept a client-generated high-entropy `idempotencyKey`. Store the result for a bounded retention period. Repeating the same operation with the same key returns the original outcome rather than creating duplicates.

## 2. Authentication and user endpoints

Firebase Authentication SDK handles registration, sign-in, provider linking, token refresh, and password reset.

### `initializeUser`

Input:
```json
{
  "displayName": "Parth",
  "language": "en",
  "keyProfileId": "profile-id"
}
```

Behavior:
- Require authenticated user.
- Create profile if absent.
- Never overwrite an existing profile blindly.
- Return profile summary.

### `getUserProfile`

Input: none or requested profile identifier restricted to self.

### `updateUserProfile`

Input:
```json
{
  "displayName": "New display name",
  "language": "gu",
  "themeMode": "system"
}
```

### `registerDevice`

Input:
```json
{
  "deviceId": "random-id",
  "platform": "windows",
  "deviceLabel": "Home laptop",
  "publicKey": "base64",
  "keyFingerprint": "fingerprint",
  "appVersion": "1.0.0"
}
```

Behavior:
- Verify enrollment challenge.
- Verify account/recovery authorization.
- Prevent device ID takeover.
- Record public key only.
- Do not accept private key material.

### `revokeDevice`

Input:
```json
{
  "deviceId": "device-id",
  "reauthenticationProof": "provider/session-specific-proof"
}
```

Behavior:
- Reauthenticate for sensitive action.
- Mark device revoked.
- Invalidate future access.
- Trigger key policy workflow.
- Notify account owner.

## 3. Document endpoints

### `createDocument`

Input:
```json
{
  "documentId": "random-id",
  "encryptedMetadata": {
    "ciphertext": "base64",
    "nonce": "base64",
    "tag": "base64",
    "formatVersion": 1
  },
  "vaultType": "personal",
  "idempotencyKey": "random-key"
}
```

Behavior:
- Confirm caller owns new document ID.
- Validate encrypted metadata envelope format and size.
- Create initial metadata record.
- Do not accept arbitrary owner UID from client.

### `requestUpload`

Input:
```json
{
  "documentId": "document-id",
  "versionId": "version-id",
  "expectedParentVersionId": null,
  "encryptedSize": 500000,
  "contentTypeHint": "application/pdf",
  "idempotencyKey": "random-key"
}
```

Response:
```json
{
  "sessionId": "session-id",
  "storageObjectPath": "temporary/uid/session",
  "expiresAt": "timestamp",
  "uploadMode": "firebase-storage-authenticated"
}
```

Behavior:
- Verify ownership/share permission.
- Check quota.
- Validate size.
- Create short-lived upload session.
- Return only the authorized object path or transfer instructions.
- Never return a public permanent URL.

### `completeUpload`

Input:
```json
{
  "sessionId": "session-id",
  "versionId": "version-id",
  "expectedParentVersionId": null,
  "encryptedMetadata": {},
  "keyEnvelope": {},
  "idempotencyKey": "random-key"
}
```

Behavior:
- Verify session owner and expiry.
- Verify object exists at expected path.
- Verify actual object size against session.
- Validate metadata/envelope structure.
- Use transaction to verify current parent version and commit version.
- Mark session complete.
- Update current version pointer.
- Emit generic event.
- Return committed version ID.

If the parent version changed, return `VERSION_CONFLICT` and do not change current pointer.

### `listDocuments`

Input:
```json
{
  "vaultType": "personal",
  "categoryFilter": null,
  "pageSize": 30,
  "cursor": null
}
```

Return encrypted metadata and minimal authorized fields. Enforce bounded page size.

### `getDocument`

Input:
```json
{
  "documentId": "document-id"
}
```

Verify access and return metadata, current version, and envelope references the caller is authorized to retrieve.

### `getDocumentVersions`

Input:
```json
{
  "documentId": "document-id",
  "pageSize": 20,
  "cursor": null
}
```

### `restoreVersion`

Input:
```json
{
  "documentId": "document-id",
  "sourceVersionId": "old-version-id",
  "expectedCurrentVersionId": "current-version-id",
  "idempotencyKey": "random-key"
}
```

Behavior:
- Verify owner permission.
- Verify source version exists.
- Create a new version or restore operation according to immutable-version design.
- Never rewrite historical version.

### `deleteDocument`

Input:
```json
{
  "documentId": "document-id",
  "expectedCurrentVersionId": "version-id",
  "idempotencyKey": "random-key"
}
```

Soft delete by default.

### `permanentlyDeleteDocument`

Requires recent authentication and explicit confirmation. Initiates asynchronous deletion of objects, versions, envelopes, indexes, and metadata under retention policy.

## 4. Family endpoints

### `createFamily`

Input:
```json
{
  "familyId": "random-id",
  "encryptedFamilyName": {},
  "initialKeyEnvelope": {},
  "idempotencyKey": "random-key"
}
```

Caller becomes owner. Backend validates plan limit and initial key data format.

### `inviteFamilyMember`

Input:
```json
{
  "familyId": "family-id",
  "email": "invitee@example.com",
  "proposedRole": "member",
  "expiresInHours": 72,
  "idempotencyKey": "random-key"
}
```

Generate high-entropy single-use invitation token. Store token hash. Rate-limit invitations. Avoid exposing whether unrelated accounts exist.

### `acceptFamilyInvitation`

Input:
```json
{
  "invitationToken": "secret-token",
  "devicePublicKeyFingerprint": "fingerprint",
  "keyEnvelope": {}
}
```

Verify token, expiry, intended recipient, account identity, family capacity, and acceptance state. Commit membership and envelope safely.

### `rejectFamilyInvitation`

Input: invitation token or invitation ID after authorization.

### `removeFamilyMember`

Input:
```json
{
  "familyId": "family-id",
  "memberUid": "member-uid",
  "idempotencyKey": "random-key"
}
```

Verify caller role, prohibit invalid owner removal, revoke membership, trigger key rotation, and record activity.

### `leaveFamily`

Input:
```json
{
  "familyId": "family-id",
  "idempotencyKey": "random-key"
}
```

Owner must transfer ownership or close family under explicit rules.

### `transferFamilyOwnership`

Requires reauthentication, recipient acceptance, and transactional role update.

## 5. Sharing endpoints

### `grantDocumentAccess`

Input:
```json
{
  "documentId": "document-id",
  "recipientUid": "recipient-uid",
  "familyId": "family-id",
  "permissions": {
    "view": true,
    "download": false,
    "replace": false,
    "reshare": false
  },
  "wrappedKeyEnvelope": {},
  "expiresAt": null,
  "idempotencyKey": "random-key"
}
```

Verify owner and recipient membership. Save permission and envelope as one logical operation. Do not trust client-provided role claims.

### `updateDocumentPermission`

Only owner or explicit access manager can update. Prevent recipient self-escalation.

### `revokeDocumentAccess`

Mark access revoked, block future service retrieval, remove/disable active envelope, update access indexes, and notify recipient generically.

### `getAuthorizedKeyEnvelope`

Input:
```json
{
  "documentId": "document-id",
  "versionId": "version-id"
}
```

Return only the envelope intended for the authenticated UID and active key identity.

### `rotateFamilyKeys`

Use a staged rotation:
1. Create new key epoch.
2. Distribute envelopes to remaining active members.
3. Require acknowledgement or define controlled transition.
4. Mark new epoch active.
5. Ensure future shared content uses new epoch.
6. Retain historical access policy explicitly.

Do not claim rotation removes plaintext already obtained by former members.

## 6. Synchronization endpoints

### `getSyncManifest`

Input:
```json
{
  "cursor": null,
  "pageSize": 100,
  "vaultScopes": ["personal", "family"]
}
```

Return authorized version identifiers, change sequence/cursor, and minimal metadata. The manifest must not expose unauthorized document existence.

### `acknowledgeSync`

Input:
```json
{
  "deviceId": "device-id",
  "documentId": "document-id",
  "versionId": "version-id",
  "verificationStatus": "authenticated-decryption-success"
}
```

Treat acknowledgement as device telemetry, not proof of authorization.

### `reportSyncConflict`

Input:
```json
{
  "documentId": "document-id",
  "localVersionId": "version-id",
  "remoteVersionId": "version-id",
  "deviceId": "device-id"
}
```

Avoid sending plaintext filenames or contents.

### `resolveSyncConflict`

Input includes chosen content/version and expected current parent. Commit with optimistic concurrency and idempotency.

## 7. Document request endpoints

- `createDocumentRequest`
- `respondToDocumentRequest`
- `cancelDocumentRequest`
- `listDocumentRequests`

Every request verifies family membership, target user, request state, expiry, and rate limits. Fulfillment requires an explicit share operation.

## 8. Notification endpoints

Notifications are normally emitted by trusted backend events, not arbitrary client requests.

Payload example:
```json
{
  "type": "document_shared",
  "eventId": "event-id",
  "resourceId": "opaque-id"
}
```

Push notification text must be generic. Fetch authorized details after opening the app.

## 9. Billing endpoints

- `validatePurchase`
- `processStoreNotification`
- `getEntitlements`
- `reconcileSubscription`

Only backend-validated receipts/purchase tokens can update entitlement. Store secrets belong in managed secret storage, not source code.

## 10. Deletion and export endpoints

- `requestAccountExport`
- `getExportStatus`
- `requestAccountDeletion`
- `getDeletionStatus`
- `cancelDeletion` only where policy permits and before irreversible cleanup.

Exports must be encrypted or delivered through a short-lived authenticated mechanism. Explain that plaintext export creates an external copy.

## 11. Error codes

- `UNAUTHENTICATED`
- `APP_CHECK_FAILED`
- `INVALID_ARGUMENT`
- `PERMISSION_DENIED`
- `NOT_FOUND`
- `RESOURCE_EXHAUSTED`
- `QUOTA_EXCEEDED`
- `UPLOAD_SESSION_EXPIRED`
- `UPLOAD_SIZE_MISMATCH`
- `VERSION_CONFLICT`
- `KEY_ENVELOPE_MISSING`
- `KEY_EPOCH_MISMATCH`
- `INVITATION_EXPIRED`
- `INVITATION_ALREADY_USED`
- `FAMILY_MEMBER_LIMIT_REACHED`
- `DEVICE_REVOKED`
- `REAUTHENTICATION_REQUIRED`
- `INTERNAL`

## 12. Rate limits and abuse controls

Apply configurable limits to:
- Invitation creation.
- Login-sensitive workflows.
- Recovery attempts.
- Key-envelope retrieval.
- Share/revoke operations.
- Upload session creation.
- Document requests.
- Export/deletion requests.

Use server-side enforcement. Client-side throttling is only a UX measure.

## 13. API testing

- Authentication missing/expired.
- Wrong owner.
- Wrong family.
- Viewer attempting admin action.
- Recipient attempting permission escalation.
- Expired invitation.
- Replayed idempotency key.
- Duplicate upload completion.
- Parent version mismatch.
- Object missing or size mismatch.
- Revoked device.
- Quota exceeded.
- Concurrent family removal and share operation.
