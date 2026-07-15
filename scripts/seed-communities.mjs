#!/usr/bin/env node

import { readFileSync, existsSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

const projectId = process.env.FIREBASE_PROJECT_ID ?? 'circlelink-dfa74';
const firebaseClientId = '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const firebaseClientSecret = 'j9iVZfS8kkCEFUPaAeJV0sAi';
const firebaseScopes = [
  'email',
  'openid',
  'https://www.googleapis.com/auth/cloudplatformprojects.readonly',
  'https://www.googleapis.com/auth/firebase',
  'https://www.googleapis.com/auth/cloud-platform',
].join(' ');

const communities = [
  {
    id: 'swiftui-builders',
    name: 'SwiftUI Builders',
    description: 'iOS developers sharing SwiftUI patterns, layouts, and app architecture tips.',
    interestTag: 'Tech',
    memberCount: 0,
  },
  {
    id: 'weekend-runners',
    name: 'Weekend Runners',
    description: 'Casual running group for 5K plans, park loops, and post-run coffee chats.',
    interestTag: 'Sports',
    memberCount: 0,
  },
  {
    id: 'indie-music-circle',
    name: 'Indie Music Circle',
    description: 'Discover playlists, live shows, and new artists outside the mainstream charts.',
    interestTag: 'Music',
    memberCount: 0,
  },
  {
    id: 'street-photo-walks',
    name: 'Street Photo Walks',
    description: 'Urban photography meetups with composition challenges and gear-free friendly vibes.',
    interestTag: 'Photography',
    memberCount: 0,
  },
  {
    id: 'board-game-night',
    name: 'Board Game Night',
    description: 'Weekly tabletop sessions from party games to strategy epics — beginners welcome.',
    interestTag: 'Gaming',
    memberCount: 0,
  },
  {
    id: 'foodie-explorers',
    name: 'Foodie Explorers',
    description: 'Try new restaurants, swap recipes, and plan group tastings around the city.',
    interestTag: 'Food',
    memberCount: 0,
  },
  {
    id: 'nature-hikers',
    name: 'Nature Hikers',
    description: 'Day hikes, trail recommendations, and low-pressure outdoor adventures.',
    interestTag: 'Nature',
    memberCount: 0,
  },
  {
    id: 'book-club-circle',
    name: 'Book Club Circle',
    description: 'Monthly reads, spoiler-safe discussions, and recommendations across genres.',
    interestTag: 'Books',
    memberCount: 0,
  },
  {
    id: 'travel-buddies',
    name: 'Travel Buddies',
    description: 'Plan weekend trips, share itineraries, and find travel partners by interest.',
    interestTag: 'Travel',
    memberCount: 0,
  },
  {
    id: 'movie-marathon',
    name: 'Movie Marathon',
    description: 'Watch parties, director deep-dives, and curated lists for film lovers.',
    interestTag: 'Movies',
    memberCount: 0,
  },
];

function loadRefreshToken() {
  const configPath = join(homedir(), '.config', 'configstore', 'firebase-tools.json');
  if (!existsSync(configPath)) {
    throw new Error('Firebase CLI config not found. Run: npx firebase-tools@latest login');
  }

  const config = JSON.parse(readFileSync(configPath, 'utf8'));
  const refreshToken = config?.tokens?.refresh_token;
  if (!refreshToken) {
    throw new Error('Firebase refresh token missing. Run: npx firebase-tools@latest login');
  }

  return refreshToken;
}

async function fetchAccessToken(refreshToken) {
  const body = new URLSearchParams({
    client_id: firebaseClientId,
    client_secret: firebaseClientSecret,
    refresh_token: refreshToken,
    grant_type: 'refresh_token',
    scope: firebaseScopes,
  });

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body,
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`OAuth token refresh failed (${response.status}): ${text}`);
  }

  const json = await response.json();
  if (!json.access_token) {
    throw new Error('OAuth response did not include access_token');
  }

  return json.access_token;
}

function toFirestoreValue(value) {
  if (typeof value === 'string') {
    return { stringValue: value };
  }
  if (typeof value === 'number' && Number.isInteger(value)) {
    return { integerValue: String(value) };
  }
  if (typeof value === 'boolean') {
    return { booleanValue: value };
  }
  throw new Error(`Unsupported Firestore value: ${value}`);
}

function toFirestoreFields(data) {
  return Object.fromEntries(
    Object.entries(data).map(([key, value]) => [key, toFirestoreValue(value)])
  );
}

async function upsertCommunity(accessToken, community) {
  const { id, ...data } = community;
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/communities?documentId=${encodeURIComponent(id)}`;

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ fields: toFirestoreFields(data) }),
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Failed to create communities/${id} (${response.status}): ${text}`);
  }
}

async function main() {
  const refreshToken = loadRefreshToken();
  const accessToken = await fetchAccessToken(refreshToken);

  for (const community of communities) {
    await upsertCommunity(accessToken, community);
    console.log(`✓ communities/${community.id}`);
  }

  console.log(`\nSeeded ${communities.length} communities in ${projectId}.`);
}

main().catch((error) => {
  console.error('Seed failed:', error.message ?? error);
  process.exit(1);
});
