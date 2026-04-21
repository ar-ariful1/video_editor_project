// backend/realtime/ws_server.js
// WebSocket server — real-time export progress, notifications
// Deployed as ECS/Fargate container alongside Lambda

const WebSocket = require('ws');
const jwt       = require('jsonwebtoken');
const { Pool }  = require('pg');
const http      = require('http');

const db         = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });
const JWT_SECRET = process.env.JWT_SECRET;
const PORT       = process.env.WS_PORT || 8080;

// ── Client registry ───────────────────────────────────────────────────────────
const clients = new Map();       // socketId → { ws, userId, subscriptions }
const userSockets = new Map();   // userId → Set<socketId>

let socketIdCounter = 0;
const newSocketId = () => `ws_${++socketIdCounter}`;

// ── Server setup ──────────────────────────────────────────────────────────────
const server = http.createServer((req, res) => {
  if (req.url === '/health') { res.writeHead(200); res.end('OK'); return; }
  res.writeHead(404); res.end();
});

const wss = new WebSocket.Server({ server, path: '/ws' });

wss.on('connection', async (ws, req) => {
  // Authenticate via JWT in query string
  const url   = new URL(req.url, 'ws://localhost');
  const token = url.searchParams.get('token');

  let userId = null;
  try {
    const claims = jwt.verify(token, JWT_SECRET);
    userId = claims.sub;
  } catch (e) {
    ws.close(4001, 'Unauthorized');
    return;
  }

  const socketId = newSocketId();
  const client   = { ws, userId, subscriptions: new Set(), lastPing: Date.now() };
  clients.set(socketId, client);

  if (!userSockets.has(userId)) userSockets.set(userId, new Set());
  userSockets.get(userId).add(socketId);

  console.log(`✅ WS connect: ${socketId} (user: ${userId})`);

  // Send connection ack
  send(ws, { type: 'connected', data: { socketId, userId, ts: new Date().toISOString() } });

  // Message handler
  ws.on('message', (raw) => {
    try {
      const msg = JSON.parse(raw.toString());
      handleMessage(socketId, client, msg);
    } catch (e) {
      console.warn('WS parse error:', e.message);
    }
  });

  // Disconnect
  ws.on('close', () => {
    clients.delete(socketId);
    userSockets.get(userId)?.delete(socketId);
    if (userSockets.get(userId)?.size === 0) userSockets.delete(userId);
    console.log(`❌ WS disconnect: ${socketId}`);
  });

  ws.on('error', (e) => console.warn(`WS error ${socketId}:`, e.message));
});

// ── Message handler ───────────────────────────────────────────────────────────
function handleMessage(socketId, client, msg) {
  const { type, data } = msg;

  switch (type) {
    case 'ping':
      client.lastPing = Date.now();
      send(client.ws, { type: 'pong', data: { ts: new Date().toISOString() } });
      break;

    case 'subscribe_export':
      if (data.jobId) {
        client.subscriptions.add(`export:${data.jobId}`);
        console.log(`📡 ${socketId} subscribed to export:${data.jobId}`);
      }
      break;

    case 'unsubscribe_export':
      client.subscriptions.delete(`export:${data.jobId}`);
      break;

    default:
      console.log(`Unknown WS message type: ${type}`);
  }
}

// ── Broadcast to specific user ────────────────────────────────────────────────
function notifyUser(userId, message) {
  const sids = userSockets.get(userId);
  if (!sids) return 0;
  let sent = 0;
  for (const sid of sids) {
    const client = clients.get(sid);
    if (client && client.ws.readyState === WebSocket.OPEN) {
      send(client.ws, message);
      sent++;
    }
  }
  return sent;
}

// ── Broadcast export progress ──────────────────────────────────────────────────
function broadcastExportProgress(jobId, userId, progress, status, outputUrl, error) {
  const message = {
    type: status === 'done' ? 'exportComplete' :
          status === 'failed' ? 'exportFailed' : 'exportProgress',
    data: { jobId, progress, status, outputUrl, error, ts: new Date().toISOString() },
  };

  // Notify all clients subscribed to this export
  const topic = `export:${jobId}`;
  let sent = 0;
  for (const [, client] of clients) {
    if (client.subscriptions.has(topic) && client.ws.readyState === WebSocket.OPEN) {
      send(client.ws, message);
      sent++;
    }
  }

  // Also notify by userId directly
  if (userId) sent += notifyUser(userId, message);

  return sent;
}

// ── Broadcast new template ────────────────────────────────────────────────────
function broadcastNewTemplate(template) {
  const message = { type: 'newTemplate', data: template };
  let sent = 0;
  for (const [, client] of clients) {
    if (client.ws.readyState === WebSocket.OPEN) {
      send(client.ws, message);
      sent++;
    }
  }
  return sent;
}

// ── Internal HTTP API (called by Lambda) ──────────────────────────────────────
server.on('request', (req, res) => {
  if (req.method !== 'POST') return;
  let body = '';
  req.on('data', (chunk) => { body += chunk; });
  req.on('end', () => {
    try {
      const data = JSON.parse(body);
      let result = {};

      if (req.url === '/internal/export-progress') {
        const sent = broadcastExportProgress(data.jobId, data.userId, data.progress, data.status, data.outputUrl, data.error);
        result = { broadcast: sent };
      }
      if (req.url === '/internal/new-template') {
        const sent = broadcastNewTemplate(data);
        result = { broadcast: sent };
      }
      if (req.url === '/internal/notify-user') {
        const sent = notifyUser(data.userId, data.message);
        result = { broadcast: sent };
      }
      if (req.url === '/stats') {
        result = { connections: clients.size, users: userSockets.size };
      }

      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(result));
    } catch (e) {
      res.writeHead(400); res.end(JSON.stringify({ error: e.message }));
    }
  });
});

// ── Heartbeat check (remove dead connections) ──────────────────────────────────
setInterval(() => {
  const now = Date.now();
  for (const [sid, client] of clients) {
    if (now - client.lastPing > 60_000) { // 60s timeout
      client.ws.terminate();
      clients.delete(sid);
      userSockets.get(client.userId)?.delete(sid);
    }
  }
}, 30_000);

// ── Helpers ───────────────────────────────────────────────────────────────────
function send(ws, data) {
  try { ws.send(JSON.stringify(data)); } catch (_) {}
}

// ── Start ─────────────────────────────────────────────────────────────────────
server.listen(PORT, () => {
  console.log(`🚀 WebSocket server running on port ${PORT}`);
  console.log(`   Health: http://localhost:${PORT}/health`);
  console.log(`   WS:     ws://localhost:${PORT}/ws`);
});

module.exports = { broadcastExportProgress, broadcastNewTemplate, notifyUser };
