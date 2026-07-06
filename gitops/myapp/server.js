// Sample app: talks to self-hosted Supabase through the Kong gateway using the
// anon key (injected from OpenBao via ESO). Proves the full stack end-to-end.
const express = require("express");
const { createClient } = require("@supabase/supabase-js");

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY;

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: { persistSession: false },
});

const app = express();
app.use(express.json());

app.get("/health", (_req, res) => res.json({ ok: true }));

// Show what the app is wired to (key masked).
app.get("/", (_req, res) =>
  res.json({
    app: "myapp",
    supabaseUrl: SUPABASE_URL,
    anonKey: SUPABASE_ANON_KEY ? SUPABASE_ANON_KEY.slice(0, 12) + "..." : null,
    try: ["GET /todos", "POST /todos {\"task\":\"...\"}"],
  })
);

app.get("/todos", async (_req, res) => {
  const { data, error } = await supabase
    .from("todos")
    .select("*")
    .order("id");
  if (error) return res.status(500).json({ error: error.message });
  res.json(data);
});

app.post("/todos", async (req, res) => {
  const task = (req.body && req.body.task) || "untitled";
  const { data, error } = await supabase
    .from("todos")
    .insert({ task })
    .select();
  if (error) return res.status(500).json({ error: error.message });
  res.status(201).json(data);
});

const PORT = 8080;
app.listen(PORT, () => console.log(`myapp listening on ${PORT} -> ${SUPABASE_URL}`));
