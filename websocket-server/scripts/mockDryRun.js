'use strict';

const { runAccountCleanup } = require('../src/cleanup/accountCleanup');

const due = {
  id: 'opaque-test-id',
  accountState: 'deactivated',
  scheduledDeletionAt: new Date('2026-01-01T00:00:00Z'),
};
const mutation = async () => { throw new Error('dry-run attempted a mutation'); };

runAccountCleanup({
  firestore: {
    listDueAccounts: async ({ cursor }) => cursor
      ? { accounts: [], nextCursor: null }
      : { accounts: [due], nextCursor: null },
    getAccount: async () => due,
    claimAccountIfStillDue: mutation,
    anonymizeAuthoredContent: mutation,
    deletePrivateAccountData: mutation,
    deleteConnectionsAndModeration: mutation,
    deleteAccountIfStillDue: mutation,
  },
  auth: { deleteUser: mutation, isUserNotFound: () => false },
  storage: { deleteKnownProfileObjects: mutation },
  clock: () => new Date('2026-02-01T00:00:00Z'),
  dryRun: true,
}).catch(() => { process.exitCode = 1; });
