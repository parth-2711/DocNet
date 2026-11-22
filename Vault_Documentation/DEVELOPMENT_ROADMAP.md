# FamilyVault — Development Roadmap

**Version:** 1.0  
**Planning assumption:** Small focused team or solo developer using AI coding assistance. Schedule is indicative, not a delivery guarantee.

## 1. Delivery strategy

Build a vertical slice that proves the hardest technical risks before expanding the feature set.

Recommended sequence:
1. Platform feasibility.
2. Authentication.
3. Cryptographic protocol and recovery.
4. Personal encrypted upload/download.
5. Cross-device synchronization.
6. Version history and conflicts.
7. Family sharing and key distribution.
8. Security hardening.
9. Desktop/web parity.
10. Billing and launch.

Do not build the entire UI before proving encryption, recovery, and platform support.

## 2. Phase 0 — Product and technical discovery

Deliverables:
- Approved PRD.
- Threat model.
- Architecture decisions.
- Firebase project setup.
- Platform compatibility matrix.
- Cryptographic protocol review plan.
- Initial wireframes.
- Cost model.

Exit criteria:
- Windows and Web Firebase integration path validated.
- Candidate crypto library evaluated.
- Recovery flow approved.
- No unresolved architectural assumption blocks the core flow.

## 3. Phase 1 — Foundation

Tasks:
- Create Flutter project.
- Configure flavors/environments.
- Add Riverpod and GoRouter.
- Add design tokens and localization.
- Configure Firebase projects.
- Implement authentication.
- Implement user profile.
- Add Drift database.
- Add structured logging with redaction.
- Configure CI and tests.

Verification:
- Sign up/sign in/out.
- Token refresh.
- Account profile.
- Environment separation.
- No secrets committed.

## 4. Phase 2 — Security foundation

Tasks:
- Select reviewed cryptographic library.
- Finalize key hierarchy.
- Implement secure random generation.
- Implement file encryption container.
- Implement metadata encryption.
- Implement platform secure key storage adapters.
- Implement recovery setup and verification.
- Implement device enrollment.
- Add cross-platform test vectors.

Verification:
- Encrypt on Android, decrypt on Windows/Web and vice versa.
- Wrong key and tampering fail.
- Recovery works on a clean device.
- No raw keys in Firestore or logs.
- Security design reviewed.

## 5. Phase 3 — Personal vault

Tasks:
- File picker.
- Type/size validation.
- Category selection.
- Encrypted upload.
- Upload session.
- Commit workflow.
- Document list/detail.
- Encrypted metadata.
- Download/decrypt.
- PDF viewer.
- Soft delete.
- Storage quota display.

Verification:
- Cloud object is ciphertext.
- Unauthorized user denied.
- Retry is idempotent.
- Interrupted upload recovers.
- File integrity verified before preview.

## 6. Phase 4 — Version history and sync

Tasks:
- Immutable version model.
- Manifest API.
- Firestore listeners.
- Local operation queue.
- Upload/download scheduler.
- Retry/backoff.
- Device acknowledgement.
- Conflict detection.
- Conflict resolution UI.
- Tombstones and cleanup.

Verification:
- Two devices see committed version.
- Simultaneous replacement creates conflict.
- No last-write-wins content overwrite.
- Offline queue survives restart.
- Corrupt ciphertext is rejected.

## 7. Phase 5 — Family and sharing

Tasks:
- Create family.
- Invite/accept/reject.
- Roles.
- Member list.
- Public-key directory and verification.
- Document-level permissions.
- Key envelope generation.
- Shared family vault.
- Revoke access.
- Family key epochs and rotation.
- Activity events.

Verification:
- Family member cannot access private document by membership alone.
- Unauthorized envelope retrieval fails.
- Recipient can decrypt only after valid share.
- Removed member cannot retrieve future content.
- UI explains prior-copy limitation.

## 8. Phase 6 — Supporting features

Tasks:
- Notifications.
- Document requests.
- Device management.
- Expiry reminders.
- Scanner.
- On-device OCR.
- Search and filters.
- Export.
- Account deletion.
- Subscription entitlements.

Verification:
- Notifications contain no sensitive metadata.
- Export/deletion jobs are resumable.
- OCR text remains local/encrypted.
- Billing is backend-validated.

## 9. Phase 7 — Platform completion

Android:
- WorkManager integration.
- Keystore validation.
- Play Store policy review.

iOS:
- Keychain integration.
- Background task behavior.
- App Store privacy review.

Windows:
- Secure storage adapter.
- Native file handling.
- Installer/signing/update.
- Desktop sync behavior.

Web:
- Web Crypto.
- CSP.
- Browser persistence controls.
- XSS/dependency security review.
- Clear local cache.

## 10. Phase 8 — Release hardening

Tasks:
- Firebase Rules Emulator tests.
- Storage authorization tests.
- Function authorization tests.
- Penetration test.
- Cryptographic review.
- Performance tests.
- Cost/load tests.
- Accessibility review.
- Localization review.
- Privacy policy and terms.
- Support and incident response playbooks.
- Store listing and screenshots.

Release gate:
- No critical/high unresolved security findings.
- Recovery tested.
- Export/deletion tested.
- Cross-platform tests pass.
- Storage is not public.
- No plaintext document upload.
- Monitoring and alerts enabled.

## 11. Suggested sprint plan

| Sprint | Focus | Deliverable |
|---|---|---|
| 0 | Discovery | Approved architecture |
| 1 | Foundation | Auth + app shell |
| 2 | Crypto | Key and recovery prototype |
| 3 | Vault | Encrypted upload/download |
| 4 | Sync | Cross-device sync |
| 5 | Versions | History and conflicts |
| 6 | Family | Membership and invitations |
| 7 | Sharing | Key envelopes and shared vault |
| 8 | Hardening | Security and platform testing |
| 9 | Release | Candidate build and launch checks |

A sprint is complete only when its verification criteria pass.

## 12. Work breakdown and task rules

Every implementation task must contain:
- Task ID.
- Requirement IDs.
- Scope.
- Files/modules affected.
- Dependencies.
- Acceptance criteria.
- Unit tests.
- Integration/security tests.
- Manual verification steps.
- Rollback/migration considerations.

Do not ask an AI coding tool to implement “the whole app” in one prompt. Work in small, reviewable increments.

## 13. Risk register

| Risk | Likelihood/impact | Mitigation |
|---|---|---|
| Crypto protocol flaw | High/critical | Independent review before real data |
| Windows Firebase gaps | Medium/high | Early proof of concept |
| Web XSS | Medium/critical | CSP, minimal scripts, security review |
| Recovery complexity | High/critical | Prototype and test before vault launch |
| Firebase cost | Medium/high | Quotas, monitoring, lifecycle cleanup |
| Sync data loss | Medium/critical | Immutable versions and conflict tests |
| Family key rotation failure | Medium/critical | Staged epoch migration |
| Scope expansion | High/medium | P0/P1/P2 gates |

## 14. Solo developer execution advice

- Complete one end-to-end vertical slice at a time.
- Keep a `CHANGELOG.md` and `DECISIONS.md`.
- Ask the AI IDE to inspect existing files before changing them.
- Require tests with every security-sensitive change.
- Never let AI invent cryptographic algorithms.
- Never use real family identity documents in development.
- Use synthetic PDFs and test accounts.
- Review Firebase rules manually.
- Keep production credentials out of the repository.
- Do not launch zero-knowledge marketing claims before external verification.

## 15. V1 release definition

V1 is ready only when a user can:
1. Register and verify an account.
2. Set up and verify recovery.
3. Upload a PDF encrypted on-device.
4. Access it from a second authorized device.
5. Replace it and retain version history.
6. Resolve a concurrent update safely.
7. Create a family and invite a member.
8. Explicitly share a document with that member.
9. Revoke future access.
10. Work offline with selected cached documents.
11. Export their data.
12. Delete their account through a tested workflow.
