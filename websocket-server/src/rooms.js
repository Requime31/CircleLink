'use strict';

/** @typedef {import('ws').WebSocket} WebSocket */

/** @type {Map<string, Set<WebSocket>>} */
const rooms = new Map();

/** @type {Map<WebSocket, Set<string>>} */
const socketRooms = new Map();

/**
 * Room key format used by CircleLink: chat:{chatId}
 * @param {string} chatId
 */
function roomKey(chatId) {
  return `chat:${chatId}`;
}

/**
 * @param {WebSocket} socket
 * @param {string} chatId
 */
function joinRoom(socket, chatId) {
  const key = roomKey(chatId);

  if (!rooms.has(key)) {
    rooms.set(key, new Set());
  }
  rooms.get(key).add(socket);

  if (!socketRooms.has(socket)) {
    socketRooms.set(socket, new Set());
  }
  socketRooms.get(socket).add(key);
}

/**
 * @param {WebSocket} socket
 * @param {string} chatId
 */
function leaveRoom(socket, chatId) {
  const key = roomKey(chatId);
  const members = rooms.get(key);

  if (members) {
    members.delete(socket);
    if (members.size === 0) {
      rooms.delete(key);
    }
  }

  const joined = socketRooms.get(socket);
  if (joined) {
    joined.delete(key);
    if (joined.size === 0) {
      socketRooms.delete(socket);
    }
  }
}

/**
 * Removes a socket from every room (on disconnect).
 * @param {WebSocket} socket
 */
function leaveAllRooms(socket) {
  const joined = socketRooms.get(socket);
  if (!joined) {
    return;
  }

  for (const key of joined) {
    const members = rooms.get(key);
    if (members) {
      members.delete(socket);
      if (members.size === 0) {
        rooms.delete(key);
      }
    }
  }

  socketRooms.delete(socket);
}

/**
 * Broadcasts a JSON-serializable payload to all sockets in a chat room
 * except the optional sender.
 * @param {string} chatId
 * @param {object} payload
 * @param {WebSocket} [exclude]
 */
function broadcastToRoom(chatId, payload, exclude) {
  const members = rooms.get(roomKey(chatId));
  if (!members) {
    return;
  }

  const data = JSON.stringify(payload);

  for (const socket of members) {
    if (socket === exclude) {
      continue;
    }
    if (socket.readyState === socket.OPEN) {
      socket.send(data);
    }
  }
}

module.exports = {
  roomKey,
  joinRoom,
  leaveRoom,
  leaveAllRooms,
  broadcastToRoom,
};
