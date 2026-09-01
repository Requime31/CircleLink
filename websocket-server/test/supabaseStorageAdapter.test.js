'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { createSupabaseStorageAdapter } = require('../src/cleanup/supabaseStorageAdapter');

test('profile cleanup uses an account-bounded prefix', async () => {
  const requests = [];
  const fetchImpl = async (url, init) => {
    requests.push({ url, init, body: JSON.parse(init.body) });
    if (init.method === 'POST') {
      return { ok: true, status: 200, json: async () => [{ name: 'avatar.jpg' }] };
    }
    return { ok: true, status: 204, json: async () => null };
  };
  const storage = createSupabaseStorageAdapter({
    url: 'https://project.supabase.co',
    serviceRoleKey: 'test-only-key',
    bucket: 'chat-images',
    fetchImpl,
  });

  await storage.deleteKnownProfileObjects('abc');

  assert.equal(requests[0].body.prefix, 'profiles/abc/');
  assert.deepEqual(requests[1].body.prefixes, ['profiles/abc/avatar.jpg']);
});
