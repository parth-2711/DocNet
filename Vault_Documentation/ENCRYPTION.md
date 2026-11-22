# FamilyVault — Encryption and Key Management Specification

**Security classification:** Critical  
**Status:** Design baseline requiring independent cryptographic review

> This document is not a cryptographic protocol implementation. Do not ship real identity documents until the protocol, libraries, key lifecycle, recovery, and platform implementations have been independently reviewed and tested.

## 1. Security objective

FamilyVault aims to ensure that document content and sensitive metadata are encrypted on the client before upload. Firebase stores ciphertext and authorization metadata. The service does not hold a universal key that can decrypt every user's documents.

The system must protect confidentiality and integrity against:
- Cloud storage disclosure.
- Database disclosure.
- Unauthorized family members.
- Accidental exposure through logs or analytics.
- Unauthorized access to key envelopes.

It cannot protect content from a fully compromised endpoint while the document is open or from a recipient who has already copied plaintext.

## 2. Cryptographic requirements

Candidate primitives, subject to protocol review:

| Purpose | Candidate |
|---|---|
| Authenticated file encryption | AES-256-GCM |
| Key derivation | HKDF-SHA-256 |
| Password-derived recovery wrapping | Argon2id |
| Public-key key agreement | X25519 |
| Hashing | SHA-256 |
| Randomness | Platform CSPRNG |
| Local key protection | Android Keystore, iOS Keychain, Windows DPAPI, Web Crypto |

Use maintained cryptographic libraries. Do not implement AES, X25519, Argon2id, nonce generation, or key wrapping manually.

## 3. Key hierarchy

Proposed conceptual hierarchy:

```text
User recovery secret
       |
       v
Recovery wrapping key (derived using reviewed KDF)
       |
       v
Wrapped user vault key
       |
       v
User vault key
       |
       +---- wraps document DEKs
       |
       +---- protects account key material

Family group key (per epoch)
       |
       +---- wraps shared document keys or group metadata keys

Device private key
       |
       +---- participates in approved device enrollment/key exchange
```

A precise protocol must specify:
- Which key encrypts each object.
- Which key wraps each DEK.
- How keys are versioned.
- How recipient public keys are authenticated.
- How key rotation is performed.
- How recovery works.
- How algorithm migration works.

## 4. Document encryption

For each document version:
1. Generate a unique random DEK.
2. Generate a unique nonce according to the selected AEAD requirements.
3. Encrypt file bytes with authenticated encryption.
4. Bind relevant immutable metadata using authenticated additional data (AAD).
5. Store ciphertext, nonce, tag, format version, and wrapped DEK.
6. Never reuse a nonce with the same AES-GCM key.
7. Never overwrite ciphertext for an existing committed version.

For large files, use a reviewed chunked authenticated-encryption format. Do not independently invent chunk framing. Each chunk needs unique nonce derivation and authenticated ordering/length information.

## 5. Metadata encryption

Encrypt:
- Document name.
- Description.
- User-defined tags.
- OCR text.
- Sensitive category labels where needed.
- Expiry dates.
- Sensitive change notes.
- Potentially folder names.

Minimize plaintext metadata. Operational metadata such as random IDs, encrypted object size, timestamps, and access-control identifiers may remain visible only after threat-model review.

## 6. Associated authenticated data

AAD can bind ciphertext to immutable context such as:
- Document ID.
- Version ID.
- Owner ID or vault ID.
- Format version.
- Key epoch.

This prevents ciphertext from being moved between contexts without detection. The exact AAD format must be canonical, versioned, and identical on every platform.

## 7. Key envelope and family sharing

A key envelope contains a document DEK wrapped for an authorized recipient or group key.

Requirements:
- Recipient public key must be authenticated.
- Envelope binds recipient identity, document ID, key ID, and protocol version.
- Recipient private key remains client-controlled.
- Envelope retrieval is permission-checked.
- Envelope rotation and revocation are explicit.
- Public-key replacement must not silently redirect future shares.

Use an established, reviewed protocol/library for public-key wrapping. Do not simply encrypt a key with an unauthenticated public key copied from a database without identity binding.

## 8. Recovery

Recovery must be a first-class onboarding feature.

Possible design:
- User creates or receives a high-entropy recovery secret.
- A reviewed KDF derives a wrapping key with documented parameters and unique salt.
- Vault key is wrapped locally.
- Wrapped key and KDF descriptor are stored in cloud metadata.
- Recovery secret is never sent to Firebase.
- User verifies recovery through a controlled test.
- Recovery is rate-limited locally and UX explains consequences.

Do not claim password reset recovers encrypted data. Firebase account password and vault recovery are distinct.

## 9. Device enrollment

Preferred flows:
1. Existing trusted device approves a new device and securely provisions key material using an authenticated protocol.
2. User uses recovery secret to restore key access.
3. Backend records new public key and device status.
4. Existing device can be revoked.
5. Key rotation is triggered where threat model requires it.

Avoid sending a raw private key through a generic API or storing it in Firestore.

## 10. Key rotation

Rotation triggers:
- Device lost or compromised.
- Family member removed.
- Public key replacement.
- Cryptographic algorithm migration.
- Suspected key exposure.
- User-requested security reset.

Rotation must define:
- New key generation.
- Rewrapping of active DEKs.
- Historical version policy.
- Family epoch transition.
- Device acknowledgements.
- Failure recovery.
- Orphaned envelope cleanup.

A former member cannot be made to forget plaintext or keys already obtained. Rotation protects future content and future service access, not previously copied data.

## 11. Secure local storage

- Store only required key material.
- Protect keys using platform keystore/keychain/DPAPI facilities.
- Prefer hardware-backed protection where supported.
- Do not store secrets in SharedPreferences, plain SQLite, files, logs, crash reports, or clipboard.
- Encrypt sensitive local database fields.
- Restrict app-private directories.
- Clear plaintext temporary files.
- Avoid generating plaintext thumbnails unless necessary; if generated, protect and expire them.
- Disable or carefully manage OS backups for sensitive local caches.
- Require reauthentication for high-risk operations.

## 12. Web-specific considerations

- Use Web Crypto API.
- Do not persist raw keys in localStorage.
- Use non-extractable CryptoKey objects where compatible with the recovery design.
- Browser storage persistence is a deliberate trust decision.
- Use strict CSP and minimize third-party JavaScript.
- Defend against XSS and dependency compromise.
- Clear local decrypted data on logout.
- Explain shared-browser risk.
- Do not claim browser-side encryption protects a user from malicious scripts executing in the same origin.

## 13. File format

Define a versioned encrypted container format. It should include:
- Magic identifier.
- Format version.
- Algorithm suite identifier.
- Nonce/chunk framing.
- Authenticated metadata.
- Ciphertext length.
- Authentication tag(s).
- Optional encrypted file metadata.
- Key-envelope reference, not raw key.

The container parser must reject malformed, truncated, oversized, or unsupported inputs safely.

## 14. Integrity and tamper handling

- Verify authentication tags before exposing plaintext.
- Treat any tag failure as a security failure.
- Never show partially decrypted content.
- Verify expected document/version context.
- Use keyed integrity identifiers if equality leakage from plain hashes is a concern.
- Avoid exposing detailed cryptographic failure information to unauthorized parties.

## 15. Threat limitations

The system cannot fully protect against:
- Malware on an unlocked endpoint.
- Screen capture or photography.
- A recipient copying a decrypted file.
- A user exporting plaintext.
- A compromised operating system.
- Browser XSS while the vault is unlocked.
- Weak user recovery secret.
- Social engineering.

Communicate these limitations accurately.

## 16. Required cryptographic tests

- Published test vectors for each primitive.
- Cross-platform encrypt/decrypt compatibility.
- Wrong key fails.
- Wrong nonce fails.
- Tampered ciphertext fails.
- Tampered tag fails.
- Wrong AAD fails.
- Duplicate nonce prevention tests.
- Key envelope wrong-recipient failure.
- Recovery round-trip.
- Device enrollment/revocation tests.
- Key rotation tests.
- Chunk reordering/truncation tests.
- Fuzz testing of container parser.

## 17. Release gate

No real sensitive documents in production until:
- Protocol design review completed.
- Library selection reviewed.
- Cross-platform test vectors pass.
- Recovery has been tested from a clean device.
- Key rotation and family removal tested.
- Local cache and temporary-file handling reviewed.
- Independent security assessment completed.
