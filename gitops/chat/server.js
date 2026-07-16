"use strict";

// Basic realtime chat backend for self-hosted Supabase.
//
// The browser only ever talks to this server (Supabase's Kong gateway is
// ClusterIP-only, not reachable from a browser). This server proxies:
//   - auth          -> Supabase Auth (GoTrue) with the anon key
//   - message CRUD  -> Postgres via PostgREST, scoped to the caller's JWT so
//                      row-level security is enforced as that user
//   - live updates  -> subscribes once to Supabase Realtime with the service
//                      key and fans new rows out to browsers over SSE

const express = require("express");
const { createClient } = require("@supabase/supabase-js");

const {
  SUPABASE_URL,
  SUPABASE_ANON_KEY,
  SUPABASE_SERVICE_KEY,
  PORT = "8080",
} = process.env;

for (const [k, v] of Object.entries({
  SUPABASE_URL,
  SUPABASE_ANON_KEY,
  SUPABASE_SERVICE_KEY,
})) {
  if (!v) {
    console.error(`Missing required env var: ${k}`);
    process.exit(1);
  }
}

// Auth calls (signup/login) use the public anon key.
const anon = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});

// The Realtime listener uses the service key so it sees every insert
// regardless of RLS. It never touches user requests.
const service = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});

// A per-request client bound to the caller's access token. All reads/writes
// go through this, so Postgres RLS decides what the user may see or insert.
function userClient(token) {
  return createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
}

// ---------------------------------------------------------------------------
// SSE hub: browsers connect to /api/stream and receive each new message.
// ---------------------------------------------------------------------------
const sseClients = new Set();

function broadcast(message) {
  const frame = `data: ${JSON.stringify(message)}\n\n`;
  for (const res of sseClients) res.write(frame);
}

// One Realtime subscription for the whole server, fanned out to all browsers.
function startRealtime() {
  service
    .channel("public:messages")
    .on(
      "postgres_changes",
      { event: "INSERT", schema: "public", table: "messages" },
      (payload) => broadcast(payload.new)
    )
    .subscribe((status) => console.log(`realtime channel: ${status}`));
}

// ---------------------------------------------------------------------------
// App
// ---------------------------------------------------------------------------
const app = express();
app.use(express.json({ limit: "16kb" }));
app.use(express.static(`${__dirname}/public`));

app.get("/health", (_req, res) => res.json({ ok: true }));

async function signup(req, res) {
  const { email, password } = req.body || {};
  if (!email || !password)
    return res.status(400).json({ error: "email and password required" });

  const { data, error } = await anon.auth.signUp({ email, password });
  if (error) return res.status(400).json({ error: error.message });
  // With email confirmation off (local), a session is returned immediately.
  res.status(201).json({ user: data.user, session: data.session });
}

async function login(req, res) {
  const { email, password } = req.body || {};
  if (!email || !password)
    return res.status(400).json({ error: "email and password required" });

  const { data, error } = await anon.auth.signInWithPassword({
    email,
    password,
  });
  if (error) return res.status(401).json({ error: error.message });
  res.json({
    access_token: data.session.access_token,
    email: data.user.email,
    user_id: data.user.id,
  });
}

// Validate a bearer token and attach the user + a scoped client.
async function requireAuth(req, res, next) {
  const header = req.get("authorization") || "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : null;
  if (!token) return res.status(401).json({ error: "missing bearer token" });

  const { data, error } = await anon.auth.getUser(token);
  if (error || !data.user)
    return res.status(401).json({ error: "invalid token" });

  req.token = token;
  req.user = data.user;
  next();
}

async function listMessages(req, res) {
  const { data, error } = await userClient(req.token)
    .from("messages")
    .select("id, content, user_email, created_at")
    .order("id", { ascending: true })
    .limit(200);
  if (error) return res.status(500).json({ error: error.message });
  res.json(data);
}

async function postMessage(req, res) {
  const content = (req.body && req.body.content ? req.body.content : "").trim();
  if (!content) return res.status(400).json({ error: "content required" });
  if (content.length > 2000)
    return res.status(400).json({ error: "content too long (max 2000)" });

  const { data, error } = await userClient(req.token)
    .from("messages")
    .insert({
      content,
      user_id: req.user.id,
      user_email: req.user.email,
    })
    .select("id, content, user_email, created_at")
    .single();
  if (error) return res.status(500).json({ error: error.message });
  res.status(201).json(data);
}

// SSE stream. EventSource cannot send headers, so the token comes as a query
// param and is validated the same way.
async function stream(req, res) {
  const token = req.query.token;
  if (!token) return res.status(401).end();
  const { data, error } = await anon.auth.getUser(String(token));
  if (error || !data.user) return res.status(401).end();

  res.set({
    "Content-Type": "text/event-stream",
    "Cache-Control": "no-cache",
    Connection: "keep-alive",
  });
  res.flushHeaders();
  res.write(": connected\n\n");

  sseClients.add(res);
  const keepAlive = setInterval(() => res.write(": ping\n\n"), 25000);
  req.on("close", () => {
    clearInterval(keepAlive);
    sseClients.delete(res);
  });
}

app.post("/api/signup", signup);
app.post("/api/login", login);
app.get("/api/messages", requireAuth, listMessages);
app.post("/api/messages", requireAuth, postMessage);
app.get("/api/stream", stream);

startRealtime();
app.listen(Number(PORT), () =>
  console.log(`chat-app listening on ${PORT} -> ${SUPABASE_URL}`)
);
