# Supabase Storage Setup (App Media)

CircleLink uses **Supabase Storage for image binaries** (free tier): chat attachments,
profile-post photos, community covers, and community-post photos.
Auth and database stay on Firebase — Supabase is **not** used for login or Firestore.

Firestore message, profile-post, and community documents store only public image URLs — not
the binary data.
Firebase Storage is **not** required.

> **Security:** uploads/downloads use HTTPS/TLS, but the current bucket and returned URLs are
> public. Possession of an image URL is sufficient to fetch it. Private signed URLs require a
> coordinated storage-policy and client change.

## 1. Create Supabase project

1. Go to [supabase.com](https://supabase.com) → New project (free tier)
2. Note **Project URL** and **anon public** key:
   - Settings → API → `Project URL`
   - Settings → API → `anon` `public` key

## 2. Create storage bucket

1. Storage → **New bucket**
2. Name: `chat-images` (must match `SupabaseConfiguration.chatImagesBucket`)
3. **Public bucket**: ON (MVP — images readable via URL in chat)

## 3. Storage policies (SQL)

In Supabase Dashboard → SQL Editor, run:

```sql
-- Allow anyone to read images (public bucket)
CREATE POLICY "Public read chat images"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'chat-images');

-- Allow uploads for chat + profile post images (MVP — tighten in production)
-- If you already created the old "Anon upload chat images" policy, drop it first:
-- DROP POLICY IF EXISTS "Anon upload chat images" ON storage.objects;

CREATE POLICY "Anon upload chat and profile images"
ON storage.objects FOR INSERT
TO anon
WITH CHECK (
  bucket_id = 'chat-images'
  AND (storage.foldername(name))[1] IN ('chats', 'profilePosts', 'communities', 'communityPosts')
);

-- Best-effort cleanup when a chat/profile image is deleted
CREATE POLICY "Anon delete chat and profile images"
ON storage.objects FOR DELETE
TO anon
USING (
  bucket_id = 'chat-images'
  AND (storage.foldername(name))[1] IN ('chats', 'profilePosts', 'communities', 'communityPosts')
);
```

> **Production:** replace anon upload/delete with authenticated policies or signed uploads.
> If INSERT still fails after this change, confirm the old chats-only policy was dropped.

## 4. Configure iOS app

1. Copy the template in the CircleLink target folder:

```bash
cp CircleLink/SupabaseSecrets.plist.example CircleLink/SupabaseSecrets.plist
```

2. Open `SupabaseSecrets.plist` and set:

| Key | Source |
|---|---|
| `SUPABASE_URL` | Settings → API → Project URL |
| `SUPABASE_ANON_KEY` | Settings → API → `anon` `public` key |

> **Git:** `SupabaseSecrets.plist` is in `.gitignore` — never commit real keys.
> Commit only `SupabaseSecrets.plist.example`.

3. Clean build (⇧⌘K) and run again.

Without `SupabaseSecrets.plist`, text chat and Firestore-backed features work, but all Supabase
media uploads fail with a clear error.

## 5. File layout in Supabase

```
chat-images/
  chats/
    {chatId}/
      {clientMessageId}.jpg
  profilePosts/
    {userId}/
      {postId}.jpg
  communities/
    {communityId}/
      cover.jpg
  communityPosts/
    {communityId}/
      {postId}.jpg
```

## 6. Data flow

```
Chat image:
  User attaches image
    → ImageCompressor.compressForChat
    → SupabaseChatImageStorage.uploadChatImage
    → public URL → Firestore message { imageURL }

Profile post image:
  User attaches image
    → ImageCompressor.compressForChat
    → SupabaseProfileImageStorage.uploadProfileImage
    → public URL → Firestore profilePosts { imageURL }

Community cover or post image:
  Admin/member selects image
    → ImageCompressor
    → SupabaseCommunityImageStorage.uploadCover / uploadPostImage
    → public URL → Firestore community / communityPosts document
```

Profile-post and community media deletion also removes the corresponding Storage object on a
best-effort basis. Chat attachments currently expose upload only and are retained with their
public object URL.

## Free tier limits (typical)

- ~1 GB storage
- ~2 GB bandwidth/month

Enough for MVP and testing.
