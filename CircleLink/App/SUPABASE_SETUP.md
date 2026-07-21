# Supabase Storage Setup (Phase 6 — Chat images)

CircleLink uses **Supabase Storage only for chat image attachments** (free tier).
Auth and database stay on Firebase — Supabase is **not** used for login or Firestore.

Firestore message documents store only the public `imageURL` — not the binary.
Firebase Storage is **not** required.

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
-- Allow anyone to read chat images (public bucket)
CREATE POLICY "Public read chat images"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'chat-images');

-- Allow uploads to chat-images bucket (MVP — tighten in production)
CREATE POLICY "Anon upload chat images"
ON storage.objects FOR INSERT
TO anon
WITH CHECK (
  bucket_id = 'chat-images'
  AND (storage.foldername(name))[1] = 'chats'
);
```

> **Production:** replace anon upload with authenticated policies or signed uploads.

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

Without `SupabaseSecrets.plist`, **text chat works** but image upload fails with a clear error.

## 5. File layout in Supabase

```
chat-images/
  chats/
    {chatId}/
      {clientMessageId}.jpg
```

## 6. Data flow

```
User attaches image
  → ImageCompressor.compressForChat
  → SupabaseChatImageStorage.uploadChatImage
  → Supabase Storage (chat-images bucket)
  → public URL
  → Firestore message { imageURL }
  → MessageCell loads URL via ImageLoader
```

## Free tier limits (typical)

- ~1 GB storage
- ~2 GB bandwidth/month

Enough for MVP and testing.
