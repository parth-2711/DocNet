# FamilyVault — Project Documentation Pack

This folder contains the product and engineering baseline for FamilyVault.

## Documents

1. `PRD.md` — Product vision, scope, requirements, UX, acceptance criteria.
2. `ARCHITECTURE.md` — System layers, Firebase services, trust boundaries, data flows.
3. `DATABASE_SCHEMA.md` — Firestore collections, fields, object paths, indexes, rules.
4. `API_SPECIFICATION.md` — Backend function contracts, inputs, behavior, errors.
5. `ENCRYPTION.md` — Key hierarchy, encryption, recovery, sharing, rotation.
6. `SYNC_ENGINE.md` — Offline queue, transfer lifecycle, conflict resolution.
7. `SECURITY_MODEL.md` — Threats, controls, security testing, release gate.
8. `THEME.md` — Brand direction, colors, components, screen and accessibility rules.
9. `DEVELOPMENT_ROADMAP.md` — Phases, sprint plan, verification and release gates.
10. `AGENTS.md` — Instructions for AI coding assistants.

## Important implementation note

This is a detailed product and architecture baseline, not a completed security certification or executable backend. The cryptographic protocol, key recovery, public-key identity binding, Windows integration, Web security, and Firebase authorization design require implementation proofs and independent review before real sensitive documents are stored.

## Suggested first implementation task

Create a minimal Flutter application and prove, on each target platform, authentication, local key protection, client-side encryption/decryption, encrypted upload/download, and recovery using synthetic test files. Do not begin with the full UI.
