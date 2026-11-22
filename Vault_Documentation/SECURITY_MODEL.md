# FamilyVault — Security Model and Threat Assessment

**Version:** 1.0  
**Status:** Baseline; requires security review

## 1. Security objectives

1. Confidentiality of document content.
2. Integrity and authenticity of encrypted content.
3. Strict isolation between users.
4. Explicit family sharing.
5. Secure device enrollment and revocation.
6. Recoverable, user-controlled key management.
7. Minimal sensitive metadata exposure.
8. Safe deletion and export.
9. Auditable security-relevant events.

## 2. Assets

- Original documents.
- Document names and descriptions.
- Identity numbers and dates.
- Encryption keys and recovery material.
- Device private keys.
- Public-key identity bindings.
- Family membership and permissions.
- Authentication sessions.
- Encrypted objects and version history.
- Local cache and temporary plaintext files.
- Subscription and account metadata.

## 3. Trust assumptions

- Firebase Authentication establishes an account identity, not document decryption authority.
- Firebase services are not trusted with plaintext document content or raw DEKs.
- A family member is not automatically trusted with another member's documents.
- A client device is trusted only while not compromised.
- Push notifications are not trusted for sensitive content delivery.
- External exports are outside the application's control.
- Public keys require authenticated identity binding.

## 4. Threat actors

- Unauthenticated internet attacker.
- Authenticated malicious user.
- Malicious or compromised family member.
- Stolen-device holder.
- Malware on an endpoint.
- Malicious browser extension or injected script.
- Compromised dependency or build pipeline.
- Insider with cloud project access.
- Abuse actor creating invitations/uploads at scale.

## 5. Threat scenarios and controls

### T-01: Cloud storage disclosure

**Threat:** Attacker obtains stored file objects.  
**Controls:** Client-side authenticated encryption, unique keys/nonces, private storage, no public URLs, key envelopes separate from objects.

### T-02: Firestore data disclosure

**Threat:** Attacker obtains metadata and envelopes.  
**Controls:** Encrypt sensitive metadata, minimize fields, protect envelope access, no raw keys, rules and IAM review.

### T-03: Cross-user access

**Threat:** User changes a document ID to access another user's file.  
**Controls:** Backend ownership checks, Firestore Rules, Storage authorization, random IDs, negative authorization tests.

### T-04: Family privilege escalation

**Threat:** Member changes role or permissions in client request.  
**Controls:** Server-side role validation, privileged writes through trusted functions, rules deny client role mutation.

### T-05: Stolen unlocked device

**Threat:** Attacker opens cached documents.  
**Controls:** App lock, OS key protection, session revocation, local cache policy, optional reauthentication, minimize plaintext persistence.

### T-06: Lost recovery secret

**Threat:** User cannot decrypt documents.  
**Controls:** Mandatory verified recovery setup, recovery education, multiple approved recovery methods if designed. No false promise of support recovery.

### T-07: Recipient copies document

**Threat:** Recipient retains plaintext after access revocation.  
**Controls:** Clear warning, default view-only, watermarking only as deterrence if appropriate, audit trail. No claim of guaranteed recall.

### T-08: Malicious invitation

**Threat:** Attacker sends spam or token is guessed/replayed.  
**Controls:** High-entropy token, hash at rest, expiry, single use, rate limits, recipient verification.

### T-09: Upload abuse

**Threat:** Oversized or malformed files create cost or parser vulnerabilities.  
**Controls:** Size limits, quota checks, upload sessions, content validation, isolated parsing, rate limits.

### T-10: XSS in Web

**Threat:** Script reads unlocked data or invokes app actions.  
**Controls:** Strict CSP, output encoding, minimal third-party scripts, dependency pinning, secure coding review, no raw key storage in localStorage.

### T-11: Log leakage

**Threat:** Crash/analytics logs expose filenames, keys, tokens, or identity numbers.  
**Controls:** Structured allowlisted logging, redaction, automated secret scanning, test crash reports.

### T-12: Supply-chain compromise

**Threat:** Malicious dependency or build artifact.  
**Controls:** Lockfiles, dependency review, vulnerability scanning, signed builds, protected CI, release provenance.

## 6. Authentication and authorization

- Firebase Authentication for identity.
- Reauthentication for high-risk operations.
- Server-side authorization for every mutation.
- Least privilege for service accounts.
- Separate dev/staging/prod projects.
- App Check as abuse mitigation, not a replacement for authorization.
- Token validation and revocation handling.
- No client-controlled premium/role fields.

## 7. Firestore and Storage rules

- Default deny.
- Explicit per-collection rules.
- Validate `request.auth.uid`.
- Restrict owner-only writes.
- Restrict recipient envelopes.
- Prevent privilege escalation.
- Storage paths are not authorization.
- Do not assume Storage Rules can query arbitrary Firestore documents.
- Use a rules-compatible authorization mirror or backend-mediated transfer.
- Test positive and negative cases in Emulator Suite.

## 8. Key and cryptographic controls

Refer to `ENCRYPTION.md`. Mandatory:
- CSPRNG.
- Unique key/nonce policy.
- AEAD.
- Authenticated public-key binding.
- Versioned envelopes.
- Rotation.
- Recovery.
- Secure local storage.
- Cross-platform test vectors.
- Independent protocol review.

## 9. Local data protection

- App-private directories.
- OS secure storage.
- Encrypted sensitive database fields.
- No plaintext temp files unless required for viewer compatibility.
- Restrictive file permissions.
- Clear temp data after viewing/export.
- No sensitive clipboard use by default.
- Prevent unintended backup of plaintext caches.
- Lock app after configured inactivity.
- Reauthenticate for export, recovery, or key changes.

## 10. Privacy and data minimization

Do not collect:
- Document contents.
- Full Aadhaar/PAN values.
- Recovery phrase.
- Raw encryption keys.
- Plaintext OCR output.
- Sensitive filenames in analytics.
- Plaintext document contents in push notifications.

Collect only what is required for account operation, authorization, billing, diagnostics, and product improvement.

## 11. Abuse prevention

- Rate-limit invitation and recovery endpoints.
- Enforce quotas server-side.
- Validate file size and transfer sessions.
- Monitor abnormal download/upload patterns.
- Restrict export frequency where appropriate.
- Protect account deletion and recovery from social engineering.
- Alert users to new devices and security-sensitive changes.

## 12. Audit events

Record:
- Device enrollment/revocation.
- Share/revoke.
- Family membership change.
- Key rotation completion.
- Recovery operation.
- Account export/deletion.
- Security-relevant authentication events.

Do not record document content, secrets, tokens, or plaintext filenames.

## 13. Incident response

Prepare procedures for:
1. Suspected account takeover.
2. Device compromise.
3. Key exposure.
4. Cloud credential compromise.
5. Unauthorized object access.
6. Malicious release.
7. Data deletion failure.

Each procedure must define containment, revocation, rotation, notification, evidence preservation, recovery, and post-incident review.

## 14. Security testing checklist

- Firebase Rules Emulator tests.
- Storage Rules tests.
- Function authorization tests.
- IDOR tests.
- Role escalation tests.
- Replay/idempotency tests.
- Rate-limit tests.
- File parser fuzz tests.
- Cryptographic tampering tests.
- Local storage inspection.
- Web XSS/CSP review.
- Dependency scanning.
- Secret scanning.
- Signed build verification.
- Independent penetration test.
- Privacy review.

## 15. Security release gate

Do not release with:
- Any unresolved critical/high security issue.
- Unreviewed cryptographic protocol.
- Untested recovery.
- Publicly readable storage.
- Client-controlled authorization.
- Plaintext document upload.
- Unbounded upload endpoints.
- Sensitive data in logs or analytics.
- No account deletion/export procedure.

## 16. Security claims

Do not claim:
- “Impossible to hack.”
- “100% secure.”
- “Revoked files are deleted from every device.”
- “We can recover your vault if you lose every key.”
- “Zero knowledge” before the architecture and implementation have been independently verified.

Use accurate wording such as “documents are encrypted on your device before cloud upload” only after verified implementation.
