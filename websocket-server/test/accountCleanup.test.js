'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { DELETED_IDENTITY, mapWithConcurrency, runAccountCleanup } = require('../src/cleanup/accountCleanup');

const NOW = new Date('2026-08-25T12:00:00.000Z');
const DUE = new Date('2026-08-24T12:00:00.000Z');
const FUTURE = new Date('2026-08-26T12:00:00.000Z');

function harness(accounts, options = {}) {
  const state = new Map(accounts.map((account) => [account.id, { ...account }]));
  const calls = [];
  let pageCalls = 0;
  let failOnce = options.failOnce || null;
  const firestore = {
    async listDueAccounts({ limit, cursor }) {
      pageCalls += 1;
      const due = [...state.values()]
        .filter((item) => item.accountState === 'deactivated' && item.scheduledDeletionAt <= NOW)
        .sort((a, b) => a.id.localeCompare(b.id));
      const start = cursor ? due.findIndex((item) => item.id === cursor.id) + 1 : 0;
      const page = due.slice(start, start + limit);
      return { accounts: page, nextCursor: page.length === limit ? { id: page.at(-1).id } : null };
    },
    async getAccount(id) {
      calls.push(['get', id]);
      return state.get(id) || null;
    },
    async claimAccountIfStillDue(id) {
      calls.push(['claim', id]);
      const account = state.get(id);
      if (!account || account.accountState !== 'deactivated' || account.scheduledDeletionAt > NOW) return false;
      account.cleanupClaimedAt = NOW;
      return true;
    },
    async anonymizeAuthoredContent(id, identity) {
      calls.push(['anonymize', id, identity]);
      if (failOnce === 'anonymize') { failOnce = null; throw new Error('temporary'); }
    },
    async deletePrivateAccountData(id) { calls.push(['private', id]); },
    async deleteConnectionsAndModeration(id) { calls.push(['related', id]); },
    async deleteAccountIfStillDue(id) {
      calls.push(['delete-user', id]);
      const account = state.get(id);
      if (!account || account.accountState !== 'deactivated' || account.scheduledDeletionAt > NOW || !account.cleanupClaimedAt) return false;
      state.delete(id);
      return true;
    },
  };
  const auth = {
    async deleteUser(id) {
      calls.push(['auth', id]);
      if (options.missingAuth) { const error = new Error('missing'); error.code = 'auth/user-not-found'; throw error; }
    },
    isUserNotFound: (error) => error.code === 'auth/user-not-found',
  };
  const storage = { async deleteKnownProfileObjects(id) { calls.push(['storage', id]); } };
  return { firestore, auth, storage, state, calls, get pageCalls() { return pageCalls; } };
}

async function run(h, options = {}) {
  return runAccountCleanup({
    firestore: h.firestore,
    auth: h.auth,
    storage: h.storage,
    clock: () => NOW,
    logger: { info() {} },
    ...options,
  });
}

test('active and not-due accounts are skipped by the due query', async () => {
  const h = harness([
    { id: 'active', accountState: 'active', scheduledDeletionAt: DUE },
    { id: 'future', accountState: 'deactivated', scheduledDeletionAt: FUTURE },
  ]);
  const summary = await run(h);
  assert.deepEqual(summary, { scanned: 0, cleaned: 0, skipped: 0, failed: 0, dryRun: false });
  assert.equal(h.calls.length, 0);
});

test('due account is anonymized and source user is deleted last', async () => {
  const h = harness([{ id: 'due', accountState: 'deactivated', scheduledDeletionAt: DUE }]);
  const summary = await run(h);
  assert.equal(summary.cleaned, 1);
  assert.deepEqual(h.calls.find((call) => call[0] === 'anonymize')[2], DELETED_IDENTITY);
  assert.equal(h.calls.at(-1)[0], 'delete-user');
});

test('restore race is skipped after per-user recheck', async () => {
  const h = harness([{ id: 'race', accountState: 'deactivated', scheduledDeletionAt: DUE }]);
  h.firestore.getAccount = async () => ({ id: 'race', accountState: 'active', scheduledDeletionAt: DUE });
  const summary = await run(h);
  assert.equal(summary.skipped, 1);
  assert.equal(h.calls.some((call) => call[0] === 'auth'), false);
});

test('restore winning between recheck and atomic claim is skipped', async () => {
  const h = harness([{ id: 'race', accountState: 'deactivated', scheduledDeletionAt: DUE }]);
  h.firestore.claimAccountIfStillDue = async () => {
    h.state.get('race').accountState = 'active';
    return false;
  };
  const summary = await run(h);
  assert.equal(summary.skipped, 1);
  assert.equal(h.calls.some((call) => call[0] === 'anonymize'), false);
  assert.equal(h.calls.some((call) => call[0] === 'auth'), false);
});

test('pagination processes bounded pages', async () => {
  const h = harness(['a', 'b', 'c', 'd', 'e'].map((id) => ({ id, accountState: 'deactivated', scheduledDeletionAt: DUE })));
  const summary = await run(h, { pageSize: 2, concurrency: 2 });
  assert.equal(summary.cleaned, 5);
  assert.ok(h.pageCalls >= 3);
});

test('dry-run rechecks but performs no mutations', async () => {
  const h = harness([{ id: 'due', accountState: 'deactivated', scheduledDeletionAt: DUE }]);
  const summary = await run(h, { dryRun: true });
  assert.equal(summary.cleaned, 1);
  assert.deepEqual(h.calls.map((call) => call[0]), ['get']);
  assert.equal(h.state.has('due'), true);
});

test('partial failure leaves due marker and retry completes', async () => {
  const h = harness([{ id: 'due', accountState: 'deactivated', scheduledDeletionAt: DUE }], { failOnce: 'anonymize' });
  const first = await run(h);
  assert.equal(first.failed, 1);
  assert.equal(h.state.has('due'), true);
  const second = await run(h);
  assert.equal(second.cleaned, 1);
  assert.equal(h.state.has('due'), false);
});

test('missing Auth user is an idempotent success', async () => {
  const h = harness([{ id: 'due', accountState: 'deactivated', scheduledDeletionAt: DUE }], { missingAuth: true });
  const summary = await run(h);
  assert.equal(summary.cleaned, 1);
});

test('second run is idempotent after cleanup', async () => {
  const h = harness([{ id: 'due', accountState: 'deactivated', scheduledDeletionAt: DUE }]);
  await run(h);
  const second = await run(h);
  assert.equal(second.scanned, 0);
  assert.equal(second.failed, 0);
});

test('concurrency never exceeds configured bound', async () => {
  let active = 0;
  let maximum = 0;
  await mapWithConcurrency([1, 2, 3, 4, 5, 6], 2, async () => {
    active += 1;
    maximum = Math.max(maximum, active);
    await new Promise((resolve) => setImmediate(resolve));
    active -= 1;
  });
  assert.equal(maximum, 2);
});
