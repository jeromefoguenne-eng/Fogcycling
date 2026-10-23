/**
 * Fogcycling — Serveur Multijoueur Temps Réel (WebSockets / Phase 6)
 * Permet à plusieurs smartphones connectés sur le réseau local (LAN) ou dans le Cloud
 * de rouler et concourir simultanément sur le même col avec synchronisation 60 FPS (Dead Reckoning).
 *
 * Démarrage : node server/multiplayer_ws_server.js
 */

const http = require('http');
const crypto = require('crypto');

const PORT = process.env.PORT || 2567;
const clients = new Set();

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({
    service: 'Fogcycling Realtime Multiplayer Server (Phase 6)',
    status: 'online',
    connectedCyclists: clients.size,
  }));
});

// Handshake RFC 6455 WebSocket natif (sans dépendance npm externe requise)
server.on('upgrade', (req, socket) => {
  const key = req.headers['sec-websocket-key'];
  if (!key) {
    socket.destroy();
    return;
  }

  const acceptKey = crypto
    .createHash('sha1')
    .update(key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11', 'binary')
    .digest('base64');

  socket.write(
    'HTTP/1.1 101 Switching Protocols\r\n' +
    'Upgrade: websocket\r\n' +
    'Connection: Upgrade\r\n' +
    `Sec-WebSocket-Accept: ${acceptKey}\r\n\r\n`
  );

  clients.add(socket);

  socket.on('data', (buffer) => {
    const message = decodeWebSocketFrame(buffer);
    if (!message) return;

    // Broadcast autoritaire à tous les autres cyclistes du salon
    const outFrame = encodeWebSocketFrame(message);
    for (const client of clients) {
      if (client !== socket && !client.destroyed) {
        client.write(outFrame);
      }
    }
  });

  socket.on('close', () => clients.delete(socket));
  socket.on('error', () => clients.delete(socket));
});

function decodeWebSocketFrame(buffer) {
  if (buffer.length < 2) return null;
  const secondByte = buffer[1];
  const isMasked = (secondByte & 0x80) !== 0;
  let payloadLength = secondByte & 0x7f;
  let offset = 2;

  if (payloadLength === 126) {
    payloadLength = buffer.readUInt16BE(2);
    offset = 4;
  } else if (payloadLength === 127) {
    return null;
  }

  let maskKey = null;
  if (isMasked) {
    maskKey = buffer.slice(offset, offset + 4);
    offset += 4;
  }

  const payload = Buffer.alloc(payloadLength);
  for (let i = 0; i < payloadLength && offset + i < buffer.length; i++) {
    payload[i] = isMasked ? buffer[offset + i] ^ maskKey[i % 4] : buffer[offset + i];
  }
  return payload.toString('utf8');
}

function encodeWebSocketFrame(str) {
  const payload = Buffer.from(str, 'utf8');
  const len = payload.length;
  let header;

  if (len < 126) {
    header = Buffer.from([0x81, len]);
  } else {
    header = Buffer.alloc(4);
    header[0] = 0x81;
    header[1] = 126;
    header.writeUInt16BE(len, 2);
  }
  return Buffer.concat([header, payload]);
}

server.listen(PORT, '0.0.0.0', () => {
  console.log(`[Fogcycling Multiplayer Server] En ligne sur ws://0.0.0.0:${PORT}`);
});
