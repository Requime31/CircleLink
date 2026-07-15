'use strict';

const http = require('http');
const { WebSocketServer } = require('ws');
const { v4: uuidv4 } = require('uuid');

const { ensureFirebase, verifyIdToken } = require('./firebase');
const { joinRoom, leaveRoom, leaveAllRooms, broadcastToRoom } = require('./rooms');

const PORT = Number(process.env.PORT || 8080);
const AUTH_TIMEOUT_MS = Number(process.env.AUTH_TIMEOUT_MS || 10_000);

ensureFirebase();

/** @typedef {import('ws').WebSocket & { userId?: string, isAuthenticated?: boolean }} AuthenticatedSocket */

/**
 * Sends a CircleLink error event: { type: "error", code: "..." }
 * @param {import('ws').WebSocket} socket
 * @param {string} code
 */
function sendError(socket, code) {
  if (socket.readyState === socket.OPEN) {
    socket.send(JSON.stringify({ type: 'error', code }));
  }
}

/**
 * @param {import('ws').WebSocket} socket
 * @param {string} raw
 * @param {AuthenticatedSocket} ctx
 */
async function handleMessage(socket, raw, ctx) {
  let event;
  try {
    event = JSON.parse(raw);
  } catch {
    sendError(socket, 'invalid_json');
    return;
  }

  const { type } = event;

  switch (type) {
    case 'auth': {
      if (ctx.isAuthenticated) {
        sendError(socket, 'already_authenticated');
        return;
      }

      const token = event.token;
      if (!token || typeof token !== 'string') {
        sendError(socket, 'missing_token');
        socket.close(4001, 'missing_token');
        return;
      }

      try {
        const decoded = await verifyIdToken(token);
        ctx.userId = decoded.uid;
        ctx.isAuthenticated = true;
        console.log(`[auth] user ${decoded.uid} authenticated`);
      } catch (err) {
        console.warn('[auth] token verification failed:', err.message);
        sendError(socket, 'auth_failed');
        socket.close(4001, 'auth_failed');
      }
      break;
    }

    case 'join': {
      if (!ctx.isAuthenticated) {
        sendError(socket, 'not_authenticated');
        return;
      }

      const chatId = event.chatId;
      if (!chatId || typeof chatId !== 'string') {
        sendError(socket, 'invalid_chat_id');
        return;
      }

      joinRoom(socket, chatId);
      console.log(`[join] user ${ctx.userId} → chat:${chatId}`);
      break;
    }

    case 'leave': {
      if (!ctx.isAuthenticated) {
        sendError(socket, 'not_authenticated');
        return;
      }

      const chatId = event.chatId;
      if (!chatId || typeof chatId !== 'string') {
        sendError(socket, 'invalid_chat_id');
        return;
      }

      leaveRoom(socket, chatId);
      console.log(`[leave] user ${ctx.userId} ← chat:${chatId}`);
      break;
    }

    case 'message': {
      if (!ctx.isAuthenticated) {
        sendError(socket, 'not_authenticated');
        return;
      }

      const { chatId, text, clientMessageId } = event;
      if (!chatId || typeof chatId !== 'string') {
        sendError(socket, 'invalid_chat_id');
        return;
      }
      if (!text || typeof text !== 'string') {
        sendError(socket, 'invalid_message');
        return;
      }

      const messageId =
        clientMessageId && typeof clientMessageId === 'string' ? clientMessageId : uuidv4();

      const payload = {
        type: 'message.new',
        chatId,
        messageId,
        senderId: ctx.userId,
        text,
        clientMessageId: messageId,
        createdAt: new Date().toISOString(),
      };

      // Broadcast to room participants (including sender for MVP echo)
      broadcastToRoom(chatId, payload);
      console.log(
        `[message] user ${ctx.userId} in chat:${chatId} clientId=${clientMessageId ?? 'n/a'}`
      );
      break;
    }

    default:
      sendError(socket, 'unknown_event');
  }
}

const server = http.createServer((_req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/plain' });
  res.end('CircleLink WebSocket server\n');
});

const wss = new WebSocketServer({ server });

wss.on('connection', (socket) => {
  /** @type {AuthenticatedSocket} */
  const ctx = socket;
  ctx.isAuthenticated = false;

  const authTimer = setTimeout(() => {
    if (!ctx.isAuthenticated && socket.readyState === socket.OPEN) {
      sendError(socket, 'auth_timeout');
      socket.close(4001, 'auth_timeout');
    }
  }, AUTH_TIMEOUT_MS);

  socket.on('message', async (data) => {
    const raw = data.toString();

    if (!ctx.isAuthenticated) {
      // Only auth is allowed before authentication
      let event;
      try {
        event = JSON.parse(raw);
      } catch {
        sendError(socket, 'invalid_json');
        socket.close(4001, 'invalid_json');
        return;
      }

      if (event.type !== 'auth') {
        sendError(socket, 'auth_required');
        socket.close(4001, 'auth_required');
        return;
      }
    }

    await handleMessage(socket, raw, ctx);

    if (ctx.isAuthenticated) {
      clearTimeout(authTimer);
    }
  });

  socket.on('close', () => {
    clearTimeout(authTimer);
    leaveAllRooms(socket);
    console.log(`[disconnect] user ${ctx.userId ?? 'anonymous'}`);
  });

  socket.on('error', (err) => {
    console.error('[socket error]', err.message);
  });
});

server.listen(PORT, () => {
  console.log(`CircleLink WebSocket server listening on port ${PORT}`);
});
