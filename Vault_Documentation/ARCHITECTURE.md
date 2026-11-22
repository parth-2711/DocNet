# FamilyVault — System Architecture

**Version:** 1.0  
**Status:** Proposed baseline

## 1. Architecture goals

- Cross-platform Flutter product.
- Clear separation of presentation, domain, data, security, and synchronization.
- Firebase-managed identity and cloud services.
- Client-side encryption and decryption.
- No server-held universal decryption key.
- Immutable document versions.
- Explicit personal/family access boundaries.
- Testable backend workflows and platform adapters.

## 2. High-level architecture

```text
Android / iOS / Windows / Web
              |
       Flutter presentation
              |
       Riverpod application state
              |
       Domain use cases
              |
  +-----------+------------+----------------+
  |           |            |                |
Repositories Security     Sync           Platform
  |          services    engine          adapters
  |           |            |                |
  +-----------+------------+----------------+
              |
      Remote data adapters
              |
  +-----------+------------+----------------+
  |           |            |                |
Firebase Auth Firestore  Cloud Storage  Cloud Functions
                                      FCM / App Check
```

## 3. Layer responsibilities

### 3.1 Presentation

- Screens, widgets, navigation, forms, accessibility.
- Observes Riverpod state.
- Does not contain Firebase queries or cryptographic algorithms.
- Does not decide authorization based only on hidden UI controls.

### 3.2 Domain

- Entities and value objects.
- Use cases such as `UploadDocument`, `ReplaceDocument`, `ShareDocument`, `RestoreVersion`, `SyncVault`.
- Repository interfaces.
- Business validation independent of Firebase.

### 3.3 Data

- Firestore data sources.
- Storage transfer adapters.
- Callable/HTTPS function clients.
- Drift local persistence.
- DTO mapping.
- Repository implementations.

### 3.4 Security

- Cryptographically secure random generation.
- File encryption/decryption.
- Metadata encryption.
- Key hierarchy.
- Key envelopes.
- Recovery.
- Device key protection.
- Key rotation.
- Secure temporary-file management.

### 3.5 Synchronization

- Local operation queue.
- Remote manifest retrieval.
- Upload/download scheduling.
- Version comparison.
- Conflict detection.
- Retry/backoff.
- Device acknowledgement.
- Reconciliation.

## 4. Firebase service responsibilities

| Service | Responsibility |
|---|---|
| Authentication | Identity, provider linking, token refresh |
| Firestore | User/family/document metadata, permissions, envelopes, sync manifests |
| Cloud Storage | Encrypted document objects and temporary ciphertext |
| Cloud Functions Gen 2 | Authorization workflows, invitations, commits, quota checks, notifications |
| FCM | Generic push notifications |
| App Check | Reduce abuse from unauthorized app clients |
| Crashlytics | Crash diagnostics, excluding sensitive values |
| Analytics | Privacy-reviewed aggregate product events |

## 5. Trust boundaries

### Boundary A: User device

Trusted only while the OS, application binary, and active session are not compromised. Plaintext and usable keys exist here during authorized use.

### Boundary B: Firebase project

Treat as untrusted for confidentiality. Firebase may store ciphertext and metadata required for authorization, but must not receive plaintext document content or raw document keys.

### Boundary C: Other family devices

Each recipient is a separate principal. A family relationship does not imply decryption rights.

### Boundary D: External export destination

Once a user exports a plaintext file, FamilyVault cannot control subsequent copying or distribution.

## 6. Core data flows

### 6.1 Upload

1. User chooses a file.
2. Client validates file type and size.
3. Client generates a unique document version ID and random DEK.
4. Client encrypts file and authenticated metadata.
5. Client wraps the DEK for owner key material.
6. Client requests upload authorization/session.
7. Client uploads ciphertext.
8. Client calls completion with object identifier, expected parent version, encrypted metadata, and envelope.
9. Backend validates identity, quota, session, object existence, size, and version precondition.
10. Backend commits immutable version and current pointer transactionally.
11. Backend emits generic notification/event.
12. Other devices observe metadata and fetch ciphertext when required.

### 6.2 Download

1. Client obtains authorized metadata.
2. Client obtains an authorized envelope.
3. Client unwraps DEK locally.
4. Client downloads ciphertext.
5. Client authenticates/decrypts.
6. Client writes plaintext only to a protected temporary location or memory-backed viewer where feasible.
7. Client clears temporary plaintext after use according to platform policy.

### 6.3 Share

1. Owner chooses recipient and permissions.
2. Client obtains recipient public key from an authenticated key directory.
3. Client verifies key identity/fingerprint or uses a transparency/rotation mechanism.
4. Client wraps the document DEK for recipient.
5. Backend validates owner and recipient membership.
6. Backend records permission and envelope atomically.
7. Recipient receives generic notification.
8. Recipient retrieves envelope and decrypts locally.

### 6.4 Remove family member

1. Backend changes membership to revoked.
2. Future metadata/storage access is denied.
3. Active group key epoch is incremented.
4. Remaining members receive a new group key envelope.
5. New shared versions use the new key epoch.
6. Previously downloaded plaintext copies remain outside remote revocation control.

## 7. Windows and Web integration

Do not assume all Firebase Flutter plugins support Windows. Maintain interfaces such as:
- `AuthRepository`
- `DocumentMetadataDataSource`
- `EncryptedObjectStore`
- `FunctionGateway`
- `SecureKeyStore`

Provide platform-specific implementations behind those interfaces.

Web requirements:
- Use Web Crypto where appropriate.
- Avoid raw key persistence in localStorage.
- Apply strict Content Security Policy.
- Minimize third-party scripts.
- Protect against XSS and dependency compromise.
- Offer explicit trusted-browser persistence.
- Clear decrypted caches on logout.

Windows requirements:
- Protect key material with DPAPI/Credential Manager-backed integration.
- Store encrypted objects in app-private directories.
- Use safe temporary file names and restrictive ACLs.
- Provide signed releases and update verification.
- Test application data cleanup and device revocation.

## 8. Local persistence

Use Drift/SQLite for:
- Document metadata cache.
- Encrypted local file references.
- Upload/download jobs.
- Version manifests.
- Device sync checkpoints.
- User preferences.
- Conflict records.

Sensitive fields must be encrypted before persistence. The database itself should be protected by OS-level storage controls where available. Do not assume SQLite encryption is automatically provided by Drift.

## 9. Backend design

Cloud Functions Gen 2 modules:
- `auth`
- `users`
- `devices`
- `documents`
- `uploads`
- `versions`
- `families`
- `invitations`
- `sharing`
- `keyEnvelopes`
- `sync`
- `requests`
- `notifications`
- `billing`
- `deletion`
- `cleanup`

Functions must be small, authenticated, idempotent where possible, and independently testable.

## 10. Architecture decisions requiring ADRs

Create an ADR before changing:
1. Cryptographic protocol and key hierarchy.
2. Recovery and device enrollment.
3. Family key rotation and historical access policy.
4. Windows Firebase integration.
5. Web key persistence and threat model.
6. Storage authorization design.
7. Version retention and deletion.
8. Subscription entitlement source of truth.

## 11. Operational environments

Use separate Firebase projects:
- `familyvault-dev`
- `familyvault-staging`
- `familyvault-prod`

Never use production documents for development or automated tests. Use synthetic files and test accounts.

## 12. Observability

Monitor:
- Function error rate and latency.
- Upload completion/failure.
- Storage quota and cost.
- Firestore reads/writes.
- Sync queue age.
- Conflict rate.
- Invitation abuse.
- Authentication anomalies.
- App crash rate.

Logs use request IDs and non-sensitive identifiers only. Never log keys, plaintext, recovery material, document names, or identity numbers.
