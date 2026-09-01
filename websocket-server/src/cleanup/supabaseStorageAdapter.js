'use strict';

function createSupabaseStorageAdapter({
  url = process.env.SUPABASE_URL,
  serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY,
  bucket = process.env.SUPABASE_STORAGE_BUCKET || 'chat-images',
  fetchImpl = globalThis.fetch,
} = {}) {
  return {
    async deleteKnownProfileObjects(userId) {
      // Current iOS avatars are Firestore base64. This prefix is reserved for
      // server-owned profile binaries and is safe to delete without touching
      // chat/community media. Firestore profilePosts are deleted separately
      // because their document path contains the account UID.
      if (!url || !serviceRoleKey) return;
      const prefix = `profiles/${userId}/`;
      while (true) {
        const objects = await request('/storage/v1/object/list/' + encodeURIComponent(bucket), {
          method: 'POST',
          body: JSON.stringify({ prefix, limit: 100, offset: 0 }),
        });
        const paths = (objects || []).filter((item) => item?.name).map((item) => `${prefix}${item.name}`);
        if (paths.length === 0) return;
        await request('/storage/v1/object/' + encodeURIComponent(bucket), {
          method: 'DELETE',
          body: JSON.stringify({ prefixes: paths }),
        });
        if (paths.length < 100) return;
      }
    },
  };

  async function request(path, init) {
    const response = await fetchImpl(url.replace(/\/$/, '') + path, {
      ...init,
      headers: {
        apikey: serviceRoleKey,
        Authorization: `Bearer ${serviceRoleKey}`,
        'Content-Type': 'application/json',
      },
    });
    if (!response.ok) throw new Error(`Supabase storage request failed (${response.status})`);
    if (response.status === 204) return null;
    return response.json();
  }
}

module.exports = { createSupabaseStorageAdapter };
