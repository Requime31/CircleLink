#!/usr/bin/env node
'use strict';

const { createFirebaseCleanupAdapters } = require('./firebaseCleanupAdapter');
const { createSupabaseStorageAdapter } = require('./supabaseStorageAdapter');
const { runAccountCleanup } = require('./accountCleanup');

async function main() {
  const dryRun = process.argv.includes('--dry-run');
  const pageSize = positiveInteger(process.env.ACCOUNT_CLEANUP_PAGE_SIZE, 25);
  const concurrency = positiveInteger(process.env.ACCOUNT_CLEANUP_CONCURRENCY, 3);
  const { firestore, auth } = createFirebaseCleanupAdapters();
  const storage = createSupabaseStorageAdapter();
  const summary = await runAccountCleanup({
    firestore,
    auth,
    storage,
    dryRun,
    pageSize,
    concurrency,
  });
  if (summary.failed > 0) process.exitCode = 1;
}

function positiveInteger(value, fallback) {
  const parsed = Number(value);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
}

main().catch((error) => {
  console.error({ event: 'account_cleanup_fatal', message: error?.message || 'unknown_error' });
  process.exitCode = 1;
});
