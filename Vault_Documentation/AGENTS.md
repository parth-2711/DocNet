# FamilyVault — AI Coding Agent Instructions

These instructions apply to AI coding assistants working in this repository.

## 1. Read before coding

Before making changes, read:
- `PRD.md`
- `ARCHITECTURE.md`
- `DATABASE_SCHEMA.md`
- `API_SPECIFICATION.md`
- `ENCRYPTION.md`
- `SYNC_ENGINE.md`
- `SECURITY_MODEL.md`
- `THEME.md`
- `DEVELOPMENT_ROADMAP.md`

If the task conflicts with these documents, stop and explain the conflict before changing architecture.

## 2. General engineering rules

- Inspect the existing project before editing.
- Preserve existing naming conventions and project structure unless a change is required and explained.
- Do not rename unrelated variables, classes, functions, or files.
- Do not rewrite entire files when a focused change is sufficient.
- Use feature-first clean architecture.
- Keep widgets free of direct Firebase queries and cryptographic implementation.
- Use Riverpod for application state.
- Use repository interfaces for data access.
- Add loading, empty, error, offline, and success states.
- Keep all user-facing strings localizable.
- Write tests with each feature.
- Update relevant Markdown documentation when behavior or schema changes.

## 3. Security rules

- Never invent cryptographic algorithms or protocols.
- Never upload plaintext document content.
- Never log document content, names, identity numbers, keys, recovery secrets, access tokens, or decrypted OCR text.
- Never store raw keys in SharedPreferences, plain SQLite, localStorage, or Firestore.
- Never bypass backend authorization because a UI control is hidden.
- Never create public Storage objects for private documents.
- Never assume family membership grants document access.
- Never claim that revocation erases a recipient's previously downloaded copy.
- Never change key hierarchy without updating `ENCRYPTION.md` and adding an ADR.
- Do not use production user documents for tests.

## 4. Firebase rules

- Default deny.
- Validate `request.auth`.
- Validate owner and recipient.
- Restrict role and billing writes to trusted backend.
- Test Firestore and Storage Rules in Firebase Emulator Suite.
- Do not assume Storage Rules can read arbitrary Firestore documents.
- Keep indexes and rules under version control.

## 5. Synchronization rules

- Document versions are immutable.
- Use expected parent version for commit.
- Never use last-write-wins for file content.
- Persist pending operations before transfer.
- Make retryable operations idempotent.
- Distinguish transient and permanent errors.
- Do not mark a file synced before commit succeeds.
- Verify ciphertext and authentication before exposing plaintext.

## 6. Flutter conventions

- Keep `main.dart` limited to initialization.
- Configure dependency injection/providers centrally.
- Use GoRouter for navigation.
- Use typed domain models.
- Avoid `dynamic` unless justified.
- Handle platform-specific functionality behind interfaces.
- Do not assume Firebase plugin support on Windows.
- Keep CPU-heavy encryption and hashing off the UI thread/isolate.
- Dispose streams, controllers, and listeners correctly.

## 7. Required workflow for each task

1. Restate the task and relevant requirement IDs.
2. Inspect impacted files.
3. Identify dependencies and risks.
4. Propose a small implementation plan.
5. Make the smallest coherent change.
6. Add or update tests.
7. Run formatter and analyzer.
8. Run relevant tests.
9. Review logs and output for sensitive data.
10. Summarize changed files, tests, limitations, and next step.

## 8. Completion report format

For every task, report:
- What changed.
- Files created/modified.
- Requirement IDs addressed.
- Tests added.
- Commands run and results.
- Security considerations.
- Known limitations.
- Suggested next task.

## 9. Do not

- Implement the entire product in one step.
- Hardcode API secrets or billing secrets.
- Commit Firebase service-account JSON.
- Use real Aadhaar/PAN documents in screenshots or fixtures.
- Add analytics parameters containing sensitive content.
- Use unreviewed custom encryption.
- Disable security rules to make a feature work.
- Suppress analyzer errors without explanation.
