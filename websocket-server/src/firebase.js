'use strict';

const admin = require('firebase-admin');

let initialized = false;

/**
 * Initializes Firebase Admin once. Supports:
 * - FIREBASE_SERVICE_ACCOUNT env (JSON string) — Railway / Render
 * - GOOGLE_APPLICATION_CREDENTIALS file path — local dev
 * - Application Default Credentials — Fly.io / GCP
 */
function ensureFirebase() {
  if (initialized) {
    return admin;
  }

  const projectId = process.env.FIREBASE_PROJECT_ID;

  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: projectId || serviceAccount.project_id,
    });
  } else if (projectId) {
    admin.initializeApp({ projectId });
  } else {
    admin.initializeApp();
  }

  initialized = true;
  return admin;
}

/**
 * Verifies a Firebase ID token and returns the decoded claims.
 * @param {string} idToken
 * @returns {Promise<import('firebase-admin/auth').DecodedIdToken>}
 */
async function verifyIdToken(idToken) {
  const firebase = ensureFirebase();
  return firebase.auth().verifyIdToken(idToken);
}

module.exports = { ensureFirebase, verifyIdToken };
