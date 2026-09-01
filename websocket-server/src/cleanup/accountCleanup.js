'use strict';

const DELETED_IDENTITY = Object.freeze({
  displayName: 'Deleted User',
  avatarURL: null,
  avatarBase64: null,
});

/**
 * Runs bounded, paginated cleanup without retaining the full due-user set.
 * Adapters are deliberately narrow so tests never need Firebase or Supabase.
 */
async function runAccountCleanup({
  firestore,
  auth,
  storage,
  clock = () => new Date(),
  logger = console,
  dryRun = false,
  pageSize = 25,
  concurrency = 3,
}) {
  if (!Number.isInteger(pageSize) || pageSize < 1) throw new Error('pageSize must be positive');
  if (!Number.isInteger(concurrency) || concurrency < 1) throw new Error('concurrency must be positive');

  const now = clock();
  const summary = { scanned: 0, cleaned: 0, skipped: 0, failed: 0, dryRun };
  let cursor = null;

  while (true) {
    const page = await firestore.listDueAccounts({ now, limit: pageSize, cursor });
    if (page.accounts.length === 0) break;
    summary.scanned += page.accounts.length;

    const results = await mapWithConcurrency(page.accounts, concurrency, (account) =>
      cleanupOne({ account, now, firestore, auth, storage, dryRun })
    );
    for (const result of results) summary[result] += 1;

    cursor = page.nextCursor;
    if (!cursor) break;
  }

  logger.info({ event: 'account_cleanup_complete', ...summary });
  return summary;
}

async function cleanupOne({ account, now, firestore, auth, storage, dryRun }) {
  try {
    const current = await firestore.getAccount(account.id);
    if (!isDue(current, now)) return 'skipped';
    if (dryRun) return 'cleaned';
    const claimed = await firestore.claimAccountIfStillDue(account.id, now);
    if (!claimed) return 'skipped';

    // Preserve authored content while removing personal snapshot fields.
    await firestore.anonymizeAuthoredContent(account.id, DELETED_IDENTITY);
    await storage.deleteKnownProfileObjects(account.id);
    await firestore.deletePrivateAccountData(account.id);
    await firestore.deleteConnectionsAndModeration(account.id);

    // Auth precedes the source profile deletion. If a later operation fails,
    // the due profile remains as a retry marker; a missing Auth user is success.
    try {
      await auth.deleteUser(account.id);
    } catch (error) {
      if (!auth.isUserNotFound(error)) throw error;
    }

    // The adapter must re-check state/deadline transactionally immediately
    // before deleting the due marker, closing the restore race.
    const deleted = await firestore.deleteAccountIfStillDue(account.id, now);
    return deleted ? 'cleaned' : 'skipped';
  } catch {
    return 'failed';
  }
}

function isDue(account, now) {
  return Boolean(
    account &&
      account.accountState === 'deactivated' &&
      account.scheduledDeletionAt instanceof Date &&
      account.scheduledDeletionAt.getTime() <= now.getTime()
  );
}

async function mapWithConcurrency(items, limit, operation) {
  const results = new Array(items.length);
  let next = 0;
  async function worker() {
    while (next < items.length) {
      const index = next++;
      results[index] = await operation(items[index]);
    }
  }
  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, worker));
  return results;
}

module.exports = { DELETED_IDENTITY, isDue, mapWithConcurrency, runAccountCleanup };
