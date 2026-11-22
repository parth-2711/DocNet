# FamilyVault — Synchronization Engine

**Version:** 1.0

## 1. Objectives

- Synchronize metadata and encrypted file versions across authorized devices.
- Support intermittent connectivity.
- Resume interrupted transfers.
- Preserve immutable history.
- Detect concurrent replacement.
- Avoid silent data loss.
- Provide visible, understandable status.

## 2. Synchronization model

Firestore listeners notify the client about metadata changes. They do not replace the file-transfer engine. Encrypted file bytes are transferred separately through Cloud Storage or an authorized transfer adapter.

Each device maintains:
- Last manifest cursor.
- Per-document known current version.
- Local encrypted cache state.
- Pending operations.
- Upload/download progress.
- Conflict records.
- Last successful sync time.

## 3. Local operation queue

Suggested table:

```text
sync_operations
- operation_id
- user_id
- device_id
- operation_type
- document_id
- version_id
- expected_parent_version_id
- encrypted_payload_reference
- status
- retry_count
- next_attempt_at
- idempotency_key
- created_at
- updated_at
- last_error_code
```

Statuses:
- queued
- preparing
- uploading
- uploaded
- committing
- completed
- retry_wait
- conflict
- failed_permanent
- cancelled

Persist queue state before beginning network transfer.

## 4. State machine

```text
queued
  |
  v
preparing
  |
  v
uploading
  |
  v
uploaded
  |
  v
committing
  |
  +---- committed ----> completed
  |
  +---- parent changed -> conflict
  |
  +---- transient error -> retry_wait
  |
  +---- permanent error -> failed_permanent
```

Downloads:
```text
remote_change
  |
  v
download_pending
  |
  v
downloading
  |
  v
ciphertext_verified
  |
  v
decrypting
  |
  +---- success -> locally_available
  |
  +---- auth/tag failure -> security_error
```

## 5. Manifest protocol

Client requests a paginated manifest using an opaque cursor. Manifest contains only resources the caller may access.

Each item should include:
- Document ID.
- Vault scope.
- Current version ID.
- Version number.
- Updated sequence/time.
- Encrypted metadata reference/payload.
- Key epoch.
- Tombstone/deletion status.

Do not expose unauthorized resource existence. Cursor must be opaque and safely scoped to user and query.

## 6. Upload workflow

1. Validate local file and quota estimate.
2. Generate document/version IDs.
3. Encrypt file locally.
4. Persist encrypted temporary file and queue operation.
5. Request upload session.
6. Upload ciphertext with resumable transfer if available.
7. Verify transfer completion.
8. Call commit endpoint with expected parent version.
9. Backend validates session/object/size/ownership/quota.
10. Backend transactionally checks expected parent and commits immutable version.
11. Client updates local manifest and marks operation complete.
12. Other devices receive metadata update.

If app terminates, resume from persisted state. If upload session expires, request a new session for the same encrypted payload and idempotent operation where policy permits.

## 7. Download workflow

1. Detect remote version newer than local.
2. Confirm user/device has access.
3. Retrieve authorized key envelope.
4. Download ciphertext to app-private encrypted cache.
5. Verify container structure and integrity.
6. Unwrap key and decrypt.
7. Verify authenticated context.
8. Mark local version available.
9. Update device acknowledgement.

Do not write plaintext to a general download folder unless the user explicitly exports.

## 8. Conflict handling

Use optimistic concurrency:
- Client includes `expectedParentVersionId`.
- Backend transaction compares it with current version.
- If equal, commit.
- If unequal, return `VERSION_CONFLICT`.

Never resolve content conflicts using last-write-wins.

Conflict UI should show:
- Local version date/device.
- Remote version date/device.
- Available previews after local decryption.
- Keep remote.
- Keep local as a new version.
- Save both as separate documents where useful.

The selected result is committed as a new immutable version with the latest current version as parent.

## 9. Retry policy

Retry transient failures:
- Network unavailable.
- Timeout.
- 429/rate limit after server retry delay.
- Temporary 5xx.
- Resumable upload interruption.

Do not blindly retry:
- Permission denied.
- Invalid file.
- Quota exceeded.
- Revoked device.
- Invalid key envelope.
- Permanent version conflict.

Use exponential backoff with jitter and maximum retry windows. Respect server-provided retry hints.

## 10. Offline behavior

Available offline:
- Cached document list.
- Local search index for downloaded metadata.
- Previously downloaded encrypted files.
- Upload queue for newly selected documents.
- Pending metadata changes where conflict-safe.

Not guaranteed offline:
- Family membership changes.
- New shares.
- Permission revocation state.
- Latest remote version.
- Cloud recovery.
- Subscription validation.

Clearly label cached information as potentially stale.

## 11. Background execution

Android:
- WorkManager, constraints for network/battery.
- Do not assume exact execution time.

iOS:
- BackgroundTasks and permitted background transfer APIs.
- User-visible foreground sync fallback.

Windows:
- Foreground sync and optional desktop background process after security review.

Web:
- Foreground sync and Service Worker where supported.
- Do not promise continuous background sync.

## 12. Deletion and tombstones

A delete creates a tombstone and updates metadata. A cleanup worker removes objects after retention and policy checks. A device that reconnects must process tombstones and remove local cached content according to policy.

A remote tombstone cannot erase copies exported outside the app.

## 13. Storage consistency and orphan cleanup

Potential orphan cases:
- Upload completed but commit failed.
- Client abandoned upload.
- Duplicate retry created an unused temporary object.
- Metadata deletion succeeded but object cleanup failed.

Use upload sessions, idempotency, object lifecycle rules, and scheduled reconciliation. Cleanup must verify object ownership and retention state before deletion.

## 14. Device acknowledgements

Record per-device acknowledgement of a version/manifest cursor. Use this for sync status and cleanup safety, not as a security authorization decision.

Do not retain old versions indefinitely solely because a device has not synced. Define retention and user communication.

## 15. Sync UI states

- Up to date.
- Syncing.
- Waiting for connection.
- Upload pending.
- Download pending.
- Conflict needs attention.
- Sync failed.
- Access revoked.
- Local copy available.
- Local copy not downloaded.

## 16. Required tests

- Offline upload then reconnect.
- Interrupted upload and resume.
- Duplicate completion request.
- Session expiry.
- Concurrent updates from two devices.
- Revocation during transfer.
- Device removed while offline.
- Metadata listener reconnect.
- Missing remote object.
- Corrupted ciphertext.
- Insufficient local storage.
- App killed during each upload state.
- Clock skew.
- Pagination/cursor expiration.
- Tombstone processing.
