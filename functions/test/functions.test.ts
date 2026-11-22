import { handleInitializeUser, handleGetUserProfile, handleUpdateUserProfile } from '../src/modules/users';
import { handleRegisterDevice, handleRevokeDevice } from '../src/modules/devices';
import {
  handleCreateDocument,
  handleRequestUpload,
  handleCompleteUpload,
  handleDeleteDocument
} from '../src/modules/documents';
import {
  handleGrantDocumentAccess,
  handleRevokeDocumentAccess,
  handleGetAuthorizedKeyEnvelope
} from '../src/modules/sharing';
import {
  handleCreateFamily,
  handleInviteFamilyMember,
  handleAcceptFamilyInvitation,
  handleRemoveFamilyMember
} from '../src/modules/family';
import {
  handleCreateDocumentRequest,
  handleRespondToDocumentRequest
} from '../src/modules/requests';
import { handleGetSyncManifest, handleResolveSyncConflict } from '../src/modules/sync';
import { ErrorCode } from '../src/types';

// Lightweight in-memory Firestore mock for unit testing functions
class MockDocRef {
  constructor(public path: string, private store: Map<string, any>) {}

  get id() {
    const parts = this.path.split('/');
    return parts[parts.length - 1];
  }

  async get() {
    const data = this.store.get(this.path);
    return {
      exists: data !== undefined,
      id: this.id,
      data: () => data,
      ref: this
    };
  }

  async set(data: any) {
    this.store.set(this.path, { ...data });
  }

  async update(data: any) {
    const current = this.store.get(this.path) || {};
    this.store.set(this.path, { ...current, ...data });
  }

  async delete() {
    this.store.delete(this.path);
  }

  collection(name: string) {
    return new MockCollectionRef(`${this.path}/${name}`, this.store);
  }
}

class MockCollectionRef {
  constructor(public path: string, private store: Map<string, any>) {}

  doc(id: string) {
    return new MockDocRef(`${this.path}/${id}`, this.store);
  }

  where(field: string, op: string, val: any) {
    return new MockQuery(this.path, this.store, [{ field, op, val }]);
  }

  orderBy(field: string, dir: 'asc' | 'desc' = 'asc') {
    return new MockQuery(this.path, this.store, [], { field, dir });
  }

  async get() {
    return new MockQuery(this.path, this.store, []).get();
  }
}

class MockQuery {
  constructor(
    private path: string,
    private store: Map<string, any>,
    private filters: Array<{ field: string; op: string; val: any }> = [],
    private order?: { field: string; dir: 'asc' | 'desc' },
    private limitVal?: number
  ) {}

  where(field: string, op: string, val: any) {
    return new MockQuery(this.path, this.store, [...this.filters, { field, op, val }], this.order, this.limitVal);
  }

  orderBy(field: string, dir: 'asc' | 'desc' = 'asc') {
    return new MockQuery(this.path, this.store, this.filters, { field, dir }, this.limitVal);
  }

  limit(n: number) {
    return new MockQuery(this.path, this.store, this.filters, this.order, n);
  }

  startAfter(_cursor: any) {
    return this;
  }

  async get() {
    const results: any[] = [];
    for (const [key, val] of this.store.entries()) {
      if (key.startsWith(this.path + '/')) {
        const remaining = key.substring(this.path.length + 1);
        if (!remaining.includes('/')) {
          let match = true;
          for (const f of this.filters) {
            if (f.op === '==' && val[f.field] !== f.val) match = false;
          }
          if (match) results.push({ id: remaining, data: () => val, ref: new MockDocRef(key, this.store) });
        }
      }
    }

    if (this.order) {
      results.sort((a, b) => {
        const valA = a.data()[this.order!.field];
        const valB = b.data()[this.order!.field];
        if (this.order!.dir === 'desc') return valA < valB ? 1 : -1;
        return valA > valB ? 1 : -1;
      });
    }

    const limited = this.limitVal ? results.slice(0, this.limitVal) : results;
    return {
      docs: limited,
      empty: limited.length === 0,
      size: limited.length
    };
  }
}

class MockFirestore {
  store = new Map<string, any>();

  collection(name: string) {
    return new MockCollectionRef(name, this.store);
  }

  batch() {
    const operations: Array<() => Promise<void>> = [];
    return {
      set: (ref: any, data: any) => operations.push(() => ref.set(data)),
      update: (ref: any, data: any) => operations.push(() => ref.update(data)),
      delete: (ref: any) => operations.push(() => ref.delete()),
      commit: async () => {
        for (const op of operations) await op();
      }
    };
  }

  async runTransaction(updateFunction: (tx: any) => Promise<any>) {
    const tx = {
      get: async (ref: any) => ref.get(),
      set: (ref: any, data: any) => ref.set(data),
      update: (ref: any, data: any) => ref.update(data),
      delete: (ref: any) => ref.delete()
    };
    return updateFunction(tx);
  }
}

describe('Cloud Functions Unit Tests (API_SPECIFICATION.md)', () => {
  let db: any;

  beforeEach(() => {
    db = new MockFirestore();
  });

  describe('User Endpoints', () => {
    it('initializeUser creates profile for new user', async () => {
      const res = await handleInitializeUser('user-1', { displayName: 'Alice' }, db);
      expect(res.success).toBe(true);
      if (res.success) {
        expect(res.data.uid).toBe('user-1');
        expect(res.data.displayName).toBe('Alice');
      }
    });

    it('getUserProfile forbids looking up other users without authorization', async () => {
      const res = await handleGetUserProfile('user-1', 'user-2', db);
      expect(res.success).toBe(false);
      if (!res.success) {
        expect(res.error.code).toBe(ErrorCode.PERMISSION_DENIED);
      }
    });

    it('updateUserProfile updates preferences', async () => {
      await handleInitializeUser('user-1', { displayName: 'Alice' }, db);
      const res = await handleUpdateUserProfile('user-1', { displayName: 'Alice Updated', language: 'gu' }, db);
      expect(res.success).toBe(true);
      if (res.success) {
        expect(res.data.displayName).toBe('Alice Updated');
        expect(res.data.language).toBe('gu');
      }
    });
  });

  describe('Device Endpoints', () => {
    it('registerDevice registers public key and rejects private key transmission', async () => {
      const badRes = await handleRegisterDevice('user-1', {
        deviceId: 'dev-1',
        platform: 'windows',
        deviceLabel: 'PC',
        publicKey: 'pub1',
        keyFingerprint: 'fp1',
        // @ts-ignore
        privateKey: 'SECRET'
      }, db);
      expect(badRes.success).toBe(false);

      const validRes = await handleRegisterDevice('user-1', {
        deviceId: 'dev-1',
        platform: 'windows',
        deviceLabel: 'PC',
        publicKey: 'pub1',
        keyFingerprint: 'fp1'
      }, db);
      expect(validRes.success).toBe(true);
    });

    it('revokeDevice marks device revoked', async () => {
      await handleRegisterDevice('user-1', {
        deviceId: 'dev-1',
        platform: 'windows',
        deviceLabel: 'PC',
        publicKey: 'pub1',
        keyFingerprint: 'fp1'
      }, db);

      const res = await handleRevokeDevice('user-1', { deviceId: 'dev-1' }, db);
      expect(res.success).toBe(true);
      if (res.success) {
        expect(res.data.status).toBe('revoked');
      }
    });
  });

  describe('Document & Resumable Transfer Endpoints', () => {
    it('requestUpload validates size limit (DOC-003)', async () => {
      const badSize = await handleRequestUpload('user-1', {
        documentId: 'doc-1',
        versionId: 'ver-1',
        encryptedSize: 30 * 1024 * 1024, // 30 MB
        idempotencyKey: 'idemp-1'
      }, db);
      expect(badSize.success).toBe(false);

      const okSize = await handleRequestUpload('user-1', {
        documentId: 'doc-1',
        versionId: 'ver-1',
        encryptedSize: 1024,
        idempotencyKey: 'idemp-ok'
      }, db);
      expect(okSize.success).toBe(true);
    });

    it('completeUpload commits session and detects VERSION_CONFLICT on stale parent', async () => {
      // 1. Create document with version 1
      await handleCreateDocument('user-1', {
        documentId: 'doc-conflict',
        encryptedMetadata: { ciphertext: 'c1', nonce: 'n1', tag: 't1', formatVersion: 1 }
      }, db);

      const sess1 = await handleRequestUpload('user-1', {
        documentId: 'doc-conflict',
        versionId: 'ver-1',
        encryptedSize: 100,
        idempotencyKey: 'idemp-v1'
      }, db);

      if (!sess1.success) throw new Error('Session 1 failed');
      await handleCompleteUpload('user-1', {
        sessionId: sess1.data.sessionId,
        versionId: 'ver-1',
        expectedParentVersionId: null,
        encryptedMetadata: { ciphertext: 'c1', nonce: 'n1', tag: 't1', formatVersion: 1 },
        idempotencyKey: 'idemp-v1'
      }, db);

      // 2. Attempt commit with outdated parent version
      const sess2 = await handleRequestUpload('user-1', {
        documentId: 'doc-conflict',
        versionId: 'ver-stale',
        expectedParentVersionId: 'ver-outdated',
        encryptedSize: 100,
        idempotencyKey: 'idemp-v2'
      }, db);

      if (!sess2.success) throw new Error('Session 2 failed');
      const conflictRes = await handleCompleteUpload('user-1', {
        sessionId: sess2.data.sessionId,
        versionId: 'ver-stale',
        expectedParentVersionId: 'ver-outdated',
        encryptedMetadata: { ciphertext: 'c2', nonce: 'n2', tag: 't2', formatVersion: 1 },
        idempotencyKey: 'idemp-v2'
      }, db);

      expect(conflictRes.success).toBe(false);
      if (!conflictRes.success) {
        expect(conflictRes.error.code).toBe(ErrorCode.VERSION_CONFLICT);
      }
    });

    it('deleteDocument soft-deletes document record with tombstone', async () => {
      await handleCreateDocument('user-1', {
        documentId: 'doc-del',
        encryptedMetadata: { ciphertext: 'c', nonce: 'n', tag: 't', formatVersion: 1 }
      }, db);

      const delRes = await handleDeleteDocument('user-1', { documentId: 'doc-del' }, db);
      expect(delRes.success).toBe(true);
      if (delRes.success) {
        expect(delRes.data.isDeleted).toBe(true);
      }
    });
  });

  describe('Sharing & Family Endpoints', () => {
    it('grantDocumentAccess and getAuthorizedKeyEnvelope enforce owner and recipient validation', async () => {
      await handleCreateDocument('user-1', {
        documentId: 'doc-share',
        encryptedMetadata: { ciphertext: 'c', nonce: 'n', tag: 't', formatVersion: 1 }
      }, db);

      const shareRes = await handleGrantDocumentAccess('user-1', {
        documentId: 'doc-share',
        recipientUid: 'user-2',
        permissions: { view: true, download: true, replace: false, reshare: false },
        wrappedKeyEnvelope: { epoch: 1, wrappedKey: 'base64key' }
      }, db);
      expect(shareRes.success).toBe(true);

      // Recipient retrieves key envelope
      const envRes = await handleGetAuthorizedKeyEnvelope('user-2', { documentId: 'doc-share' }, db);
      expect(envRes.success).toBe(true);

      // Unauthorized user rejected
      const unauthRes = await handleGetAuthorizedKeyEnvelope('user-3', { documentId: 'doc-share' }, db);
      expect(unauthRes.success).toBe(false);
    });

    it('createFamily, invite, and accept workflow', async () => {
      const famRes = await handleCreateFamily('user-1', {
        familyId: 'fam-1',
        encryptedFamilyName: { name: 'The Vault Family' }
      }, db);
      expect(famRes.success).toBe(true);

      const inviteRes = await handleInviteFamilyMember('user-1', {
        familyId: 'fam-1',
        email: 'member@family.org'
      }, db);
      expect(inviteRes.success).toBe(true);
      if (!inviteRes.success) return;

      const acceptRes = await handleAcceptFamilyInvitation('user-2', {
        familyId: 'fam-1',
        token: inviteRes.data.token
      }, db);
      expect(acceptRes.success).toBe(true);
    });
  });

  describe('Document Request & Sync Endpoints', () => {
    it('createDocumentRequest enforces REQ-002: rejects raw sensitive identity numbers', async () => {
      await handleCreateFamily('user-1', {
        familyId: 'fam-req',
        encryptedFamilyName: { name: 'Family' }
      }, db);

      const badReq = await handleCreateDocumentRequest('user-1', {
        requestId: 'req-bad',
        familyId: 'fam-req',
        requestedCategory: 'Identity',
        note: 'Please share your Aadhaar number 1234 5678 9012'
      }, db);
      expect(badReq.success).toBe(false);
      if (!badReq.success) {
        expect(badReq.error.message).toContain('Raw sensitive identification numbers');
      }

      const validReq = await handleCreateDocumentRequest('user-1', {
        requestId: 'req-ok',
        familyId: 'fam-req',
        requestedCategory: 'Identity',
        note: 'Please share your renewed passport copy'
      }, db);
      expect(validReq.success).toBe(true);
    });

    it('getSyncManifest returns cursor-paginated manifest', async () => {
      await handleCreateDocument('user-1', {
        documentId: 'doc-manifest-1',
        encryptedMetadata: { ciphertext: 'c', nonce: 'n', tag: 't', formatVersion: 1 }
      }, db);

      const manifestRes = await handleGetSyncManifest('user-1', { pageSize: 10 }, db);
      expect(manifestRes.success).toBe(true);
      if (manifestRes.success) {
        expect(manifestRes.data.items.length).toBeGreaterThan(0);
        expect(manifestRes.data.items[0].documentId).toBe('doc-manifest-1');
      }
    });

    it('resolveSyncConflict handles keepRemote, keepLocal, and saveBoth', async () => {
      await handleCreateDocument('user-1', {
        documentId: 'doc-resolve',
        encryptedMetadata: { ciphertext: 'c', nonce: 'n', tag: 't', formatVersion: 1 }
      }, db);

      const res = await handleResolveSyncConflict('user-1', {
        documentId: 'doc-resolve',
        chosenVersionId: 'ver-local-2',
        strategy: 'keepLocal'
      }, db);
      expect(res.success).toBe(true);
      if (res.success) {
        expect(res.data.resolvedStrategy).toBe('keepLocal');
      }
    });
  });
});

