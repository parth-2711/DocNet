# FamilyVault — Database Schema

**Database:** Cloud Firestore  
**Object store:** Firebase Cloud Storage  
**Version:** 1.0

## 1. Schema principles

1. Firebase UID is the canonical user identity.
2. Server-visible metadata is minimized.
3. Sensitive names, descriptions, tags, OCR text, and expiry values are encrypted or kept local.
4. File content is encrypted on the client before upload.
5. Document versions are immutable.
6. Permissions and key envelopes are separate concepts.
7. Family membership does not grant personal-vault access.
8. Every collection has explicit owner/tenant authorization.
9. Use server timestamps for authoritative events.
10. Use transactions for related metadata state changes.

## 2. Collection map

```text
users/{uid}
  devices/{deviceId}
  keyProfiles/{profileId}
  notifications/{notificationId}

families/{familyId}
  members/{uid}
  invitations/{invitationId}
  vaultDocuments/{documentId}
  keyEnvelopes/{envelopeId}
  activity/{activityId}

personalDocuments/{documentId}
  versions/{versionId}
  permissions/{permissionId}
  keyEnvelopes/{envelopeId}

documentRequests/{requestId}
uploadSessions/{sessionId}
deviceSync/{uid}/devices/{deviceId}
subscriptions/{uid}
deletionJobs/{uid}
```

## 3. Common field conventions

- IDs: random, non-sequential identifiers.
- Timestamps: Firestore server timestamps.
- Status: enum string.
- `schemaVersion`: integer for future migration.
- `createdAt`: immutable server timestamp.
- `updatedAt`: server timestamp on allowed mutation.
- `ownerUid`: Firebase UID.
- `keyEpoch`: integer for group/key rotation.
- `requestId`: idempotency and support correlation.

Never put secrets or raw encryption keys in a document.

## 4. Users

Path: `users/{uid}`

```json
{
  "schemaVersion": 1,
  "uid": "firebase-auth-uid",
  "displayName": "Encrypted-or-user-approved-display-name",
  "email": "account-email",
  "photoRef": null,
  "accountStatus": "active",
  "createdAt": "SERVER_TIMESTAMP",
  "updatedAt": "SERVER_TIMESTAMP",
  "defaultFamilyId": null,
  "language": "en",
  "themeMode": "system",
  "onboardingCompleted": false,
  "keyProfileId": "key-profile-id"
}
```

Email may be available through Firebase Authentication and need not be duplicated unless the application has a clear use. Protect profile fields with strict rules.

## 5. Device records

Path: `users/{uid}/devices/{deviceId}`

```json
{
  "schemaVersion": 1,
  "deviceId": "random-device-id",
  "platform": "android",
  "deviceLabel": "Parth phone",
  "devicePublicKey": "base64-public-key",
  "keyFingerprint": "fingerprint",
  "status": "active",
  "enrolledAt": "SERVER_TIMESTAMP",
  "lastSeenAt": "SERVER_TIMESTAMP",
  "lastAcknowledgedSyncAt": null,
  "revokedAt": null,
  "appVersion": "1.0.0"
}
```

Do not store private keys here. Device labels should be user-editable and must not contain sensitive data.

## 6. Key profiles

Path: `users/{uid}/keyProfiles/{profileId}`

```json
{
  "schemaVersion": 1,
  "profileId": "profile-id",
  "publicKey": "base64-public-key",
  "publicKeyFingerprint": "fingerprint",
  "wrappedVaultKey": "base64-wrapped-key",
  "wrappingAlgorithm": "protocol-defined",
  "kdfDescriptor": {
    "algorithm": "Argon2id",
    "parametersVersion": 1,
    "salt": "base64-salt"
  },
  "recoveryConfigured": true,
  "keyVersion": 1,
  "createdAt": "SERVER_TIMESTAMP",
  "status": "active"
}
```

The exact fields and algorithms must be finalized by the reviewed cryptographic protocol. Never store the recovery secret or plaintext vault key.

## 7. Personal document metadata

Path: `personalDocuments/{documentId}`

```json
{
  "schemaVersion": 1,
  "documentId": "random-document-id",
  "ownerUid": "firebase-uid",
  "vaultType": "personal",
  "encryptedMetadata": {
    "ciphertext": "base64",
    "nonce": "base64",
    "tag": "base64",
    "formatVersion": 1
  },
  "currentVersionId": "version-id",
  "versionNumber": 1,
  "encryptedSize": 500000,
  "contentTypeHint": "application/pdf",
  "status": "active",
  "createdAt": "SERVER_TIMESTAMP",
  "updatedAt": "SERVER_TIMESTAMP",
  "deletedAt": null
}
```

`contentTypeHint` can reveal some information. Decide whether to retain it based on threat model. Do not use it as proof of file content. Validate file structure on the client and use safe download handling.

## 8. Version records

Path: `personalDocuments/{documentId}/versions/{versionId}`

```json
{
  "schemaVersion": 1,
  "versionId": "random-version-id",
  "documentId": "document-id",
  "versionNumber": 1,
  "parentVersionId": null,
  "storageObjectPath": "encrypted-files/personal/uid/doc/version",
  "encryptedSize": 500000,
  "cipherSuite": "protocol-defined",
  "nonce": "base64",
  "authenticationTag": "base64",
  "integrityIdentifier": "keyed-or-protocol-defined-identifier",
  "keyEnvelopeId": "envelope-id",
  "uploadedBy": "firebase-uid",
  "createdAt": "SERVER_TIMESTAMP",
  "status": "committed",
  "commitRequestId": "idempotency-key"
}
```

The version record is immutable after commit except for narrowly defined retention/deletion status transitions. Never update the ciphertext of an existing version.

## 9. Document permissions

Path: `personalDocuments/{documentId}/permissions/{permissionId}`

```json
{
  "schemaVersion": 1,
  "permissionId": "permission-id",
  "documentId": "document-id",
  "ownerUid": "owner-uid",
  "recipientUid": "recipient-uid",
  "familyId": "family-id-or-null",
  "canView": true,
  "canDownload": false,
  "canReplace": false,
  "canReshare": false,
  "status": "active",
  "expiresAt": null,
  "grantedAt": "SERVER_TIMESTAMP",
  "revokedAt": null
}
```

Only the owner or a specifically authorized access manager can modify permissions. Recipient cannot elevate their own permissions.

## 10. Key envelopes

Path: `personalDocuments/{documentId}/keyEnvelopes/{envelopeId}`

```json
{
  "schemaVersion": 1,
  "envelopeId": "envelope-id",
  "documentId": "document-id",
  "recipientUid": "recipient-uid",
  "recipientKeyFingerprint": "fingerprint",
  "wrappedDocumentKey": "base64-ciphertext",
  "protocolVersion": 1,
  "keyEpoch": 1,
  "createdAt": "SERVER_TIMESTAMP",
  "status": "active"
}
```

Access must be restricted to the intended recipient and authorized owner workflow. A wrapped key is still security-sensitive metadata.

## 11. Family records

Path: `families/{familyId}`

```json
{
  "schemaVersion": 1,
  "familyId": "random-family-id",
  "ownerUid": "owner-uid",
  "encryptedFamilyName": {
    "ciphertext": "base64",
    "nonce": "base64",
    "tag": "base64"
  },
  "status": "active",
  "memberCount": 3,
  "keyEpoch": 1,
  "createdAt": "SERVER_TIMESTAMP",
  "updatedAt": "SERVER_TIMESTAMP"
}
```

Family name should be encrypted if the threat model treats it as sensitive. `memberCount` is operational metadata.

## 12. Family members

Path: `families/{familyId}/members/{uid}`

```json
{
  "schemaVersion": 1,
  "uid": "firebase-uid",
  "role": "member",
  "status": "active",
  "joinedAt": "SERVER_TIMESTAMP",
  "invitedBy": "inviter-uid",
  "keyEpochAcknowledged": 1,
  "permissions": {
    "manageMembers": false,
    "manageFamilySettings": false
  }
}
```

Roles: `owner`, `admin`, `member`, `viewer`. Document-level access remains separate.

## 13. Family invitations

Path: `families/{familyId}/invitations/{invitationId}`

```json
{
  "schemaVersion": 1,
  "invitationId": "invitation-id",
  "tokenHash": "server-side-hash",
  "invitedEmailNormalized": "person@example.com",
  "invitedBy": "uid",
  "proposedRole": "member",
  "status": "pending",
  "createdAt": "SERVER_TIMESTAMP",
  "expiresAt": "TIMESTAMP",
  "acceptedBy": null,
  "acceptedAt": null
}
```

Invitation token must be high entropy, single-use, expiring, and never logged. Email visibility must follow privacy policy.

## 14. Family vault document references

Path: `families/{familyId}/vaultDocuments/{documentId}`

```json
{
  "schemaVersion": 1,
  "documentId": "document-id",
  "sourceOwnerUid": "owner-uid",
  "sourceVaultType": "personal",
  "sharedBy": "uid",
  "status": "active",
  "sharedAt": "SERVER_TIMESTAMP",
  "keyEpoch": 1,
  "permissionRef": "permission-id"
}
```

This is a reference and authorization index, not a second plaintext copy. The object storage design must specify whether the encrypted object remains at the owner's path or is copied to a family path.

## 15. Document requests

Path: `documentRequests/{requestId}`

```json
{
  "schemaVersion": 1,
  "requestId": "request-id",
  "familyId": "family-id",
  "requesterUid": "uid",
  "recipientUid": "uid",
  "encryptedRequestDetails": "ciphertext",
  "status": "pending",
  "createdAt": "SERVER_TIMESTAMP",
  "expiresAt": "TIMESTAMP",
  "respondedAt": null
}
```

## 16. Upload sessions

Path: `uploadSessions/{sessionId}`

```json
{
  "schemaVersion": 1,
  "sessionId": "session-id",
  "ownerUid": "uid",
  "documentId": "document-id",
  "versionId": "version-id",
  "expectedParentVersionId": "version-id-or-null",
  "storageObjectPath": "temporary-or-final-path",
  "expectedEncryptedSize": 500000,
  "status": "created",
  "createdAt": "SERVER_TIMESTAMP",
  "expiresAt": "TIMESTAMP",
  "idempotencyKey": "unique-key"
}
```

Upload sessions are short-lived. Backend verifies session ownership and object existence before commit.

## 17. Sync checkpoints

Path: `deviceSync/{uid}/devices/{deviceId}`

```json
{
  "schemaVersion": 1,
  "deviceId": "device-id",
  "lastManifestCursor": "opaque-cursor",
  "lastSuccessfulSyncAt": "SERVER_TIMESTAMP",
  "pendingOperationCount": 0,
  "appVersion": "1.0.0",
  "status": "active"
}
```

Do not trust a client checkpoint as proof of authorization or successful content verification.

## 18. Subscription records

Path: `subscriptions/{uid}`

```json
{
  "schemaVersion": 1,
  "planId": "free",
  "entitlementStatus": "active",
  "source": "google_play",
  "productId": null,
  "validUntil": null,
  "updatedAt": "SERVER_TIMESTAMP"
}
```

Only trusted backend billing validation may write entitlement state.

## 19. Deletion jobs

Path: `deletionJobs/{uid}`

```json
{
  "schemaVersion": 1,
  "uid": "uid",
  "status": "requested",
  "requestedAt": "SERVER_TIMESTAMP",
  "reauthenticatedAt": "SERVER_TIMESTAMP",
  "completedAt": null,
  "cleanupCursor": null
}
```

Use a state machine and idempotent cleanup workers.

## 20. Storage object layout

```text
encrypted-files/
  personal/{uid}/{documentId}/{versionId}.enc
  family/{familyId}/{documentId}/{versionId}.enc
  temporary/{uid}/{sessionId}.upload
```

Do not expose public read access. Avoid long-lived download URLs. Apply lifecycle cleanup to expired temporary objects.

## 21. Required indexes

Create indexes based on actual query patterns, likely including:
- User's documents by owner/status/updatedAt.
- Family members by status.
- Invitations by status/expiry.
- Permissions by recipient/status.
- Requests by recipient/status/createdAt.
- Upload sessions by owner/status/expiry.
- Activity by family/createdAt.

Do not create speculative indexes without query tests. Store the final index definitions in `firestore.indexes.json`.

## 22. Firestore and Storage rule requirements

- Deny by default.
- Require authentication.
- Validate UID/owner relationships.
- Enforce family membership for family metadata.
- Enforce recipient-specific envelope access.
- Prevent clients from writing privileged role or billing fields.
- Use backend-only writes for membership transitions, commits, and entitlements where practical.
- Storage Rules cannot be assumed to query arbitrary Firestore permission documents. Mirror necessary authorization state into a rules-compatible structure or mediate access through a backend.
- Test rules using Firebase Emulator Suite.

## 23. Schema migration

- Every persisted model has `schemaVersion`.
- Migrations are idempotent.
- Keep old readers during rolling client upgrades where possible.
- Never migrate encrypted payloads without a tested cryptographic migration plan.
- Maintain test fixtures for every supported schema version.
