'use strict';

const { ensureFirebase } = require('../firebase');

/**
 * Deterministic direct chat id — must match iOS `FirestoreChatMapper.directChatId`.
 * @param {string} a
 * @param {string} b
 * @returns {string}
 */
function directChatId(a, b) {
  return [a, b].sort().join('_');
}

/**
 * @param {string} userId
 * @returns {Promise<string|null>}
 */
async function fcmTokenForUser(userId) {
  const db = ensureFirebase().firestore();
  const snap = await db.collection('users').doc(userId).get();
  if (!snap.exists) return null;
  const token = snap.get('fcmToken');
  return typeof token === 'string' && token.length > 0 ? token : null;
}

/**
 * @param {{
 *   token: string,
 *   title: string,
 *   body: string,
 *   data: Record<string, string>
 * }} params
 */
async function sendPush({ token, title, body, data }) {
  const messaging = ensureFirebase().messaging();

  // FCM data values must be strings.
  const stringData = {};
  for (const [key, value] of Object.entries(data)) {
    if (value == null) continue;
    stringData[key] = String(value);
  }

  try {
    const id = await messaging.send({
      token,
      notification: { title, body },
      data: stringData,
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    });
    console.log(`[push] sent type=${stringData.type} id=${id}`);
  } catch (error) {
    console.error(`[push] send failed type=${stringData.type}:`, error.message || error);
  }
}

/**
 * @param {string} userId
 * @returns {Promise<string>}
 */
async function displayNameForUser(userId) {
  const db = ensureFirebase().firestore();
  const snap = await db.collection('users').doc(userId).get();
  if (!snap.exists) return 'Someone';
  const name = snap.get('displayName');
  if (typeof name === 'string' && name.trim().length > 0) {
    return name.trim();
  }
  return 'Someone';
}

module.exports = {
  directChatId,
  fcmTokenForUser,
  sendPush,
  displayNameForUser,
};
