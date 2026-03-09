import { createServer, IncomingMessage, ServerResponse } from "http";
import { spawn, ChildProcess } from "child_process";
import * as fs from "fs";
import * as path from "path";
import * as os from "os";
import * as crypto from "crypto";

const PORT = parseInt(process.env.RHINO_PORT || "7890", 10);
const API_KEY = process.env.RHINO_API_KEY || "";
const CLAUDE_DIR = path.join(os.homedir(), ".claude");
const STATE_DIR = path.join(CLAUDE_DIR, "state");
const KNOWLEDGE_DIR = path.join(CLAUDE_DIR, "knowledge");
const LOG_DIR = path.join(CLAUDE_DIR, "logs");
const RUNS_DIR = path.join(CLAUDE_DIR, "state", "runs");
const EVALS_DIR = path.join(CLAUDE_DIR, "evals", "reports");
const HISTORY_FILE = path.join(EVALS_DIR, "history.jsonl");
const RHINO_DIR = process.env.RHINO_DIR || path.join(os.homedir(), "rhino-os");

for (const dir of [STATE_DIR, KNOWLEDGE_DIR, LOG_DIR, RUNS_DIR, EVALS_DIR]) {
  fs.mkdirSync(dir, { recursive: true });
}

// Clean up stuck "running" state from previous crashes
for (const file of fs.readdirSync(RUNS_DIR)) {
  if (!file.endsWith(".json")) continue;
  try {
    const runPath = path.join(RUNS_DIR, file);
    const run = JSON.parse(fs.readFileSync(runPath, "utf-8"));
    if (run.status === "running") {
      run.status = "failed";
      run.completedAt = new Date().toISOString();
      fs.writeFileSync(runPath, JSON.stringify(run, null, 2), "utf-8");
    }
  } catch { /* skip corrupt files */ }
}

// --- Run management ---

interface Run {
  id: string;
  agent: string;
  status: "queued" | "running" | "completed" | "failed";
  startedAt?: string;
  completedAt?: string;
  output: string[];
  cost?: number;
  pid?: number;
}

const runs = new Map<string, Run>();
let currentRun: string | null = null;
const runQueue: string[] = [];

function saveRun(run: Run) {
  const runFile = path.join(RUNS_DIR, `${run.id}.json`);
  fs.writeFileSync(runFile, JSON.stringify(run, null, 2), "utf-8");
}

function loadRun(id: string): Run | null {
  const runFile = path.join(RUNS_DIR, `${id}.json`);
  if (fs.existsSync(runFile)) {
    return JSON.parse(fs.readFileSync(runFile, "utf-8"));
  }
  return runs.get(id) || null;
}

// SSE connections waiting for run output
const sseConnections = new Map<string, ServerResponse[]>();

function processQueue() {
  if (currentRun) return;
  if (runQueue.length === 0) return;

  const runId = runQueue.shift()!;
  const run = runs.get(runId);
  if (!run) return;

  currentRun = runId;
  run.status = "running";
  run.startedAt = new Date().toISOString();
  saveRun(run);

  const agentArgs: string[] = [
    "-p",
    "--agent", run.agent,
    "--output-format", "stream-json",
    "--max-budget-usd", "2",
    "Run your default workflow.",
  ];

  const proc: ChildProcess = spawn("claude", agentArgs, {
    stdio: ["ignore", "pipe", "pipe"],
  });

  run.pid = proc.pid;

  proc.stdout?.on("data", (chunk: Buffer) => {
    const text = chunk.toString();
    run.output.push(text);

    // Forward to SSE listeners
    const listeners = sseConnections.get(runId) || [];
    for (const res of listeners) {
      try {
        res.write(`data: ${JSON.stringify({ type: "output", content: text })}\n\n`);
      } catch {
        // connection closed
      }
    }
  });

  proc.stderr?.on("data", (chunk: Buffer) => {
    run.output.push(`[stderr] ${chunk.toString()}`);
  });

  proc.on("close", (code) => {
    run.status = code === 0 ? "completed" : "failed";
    run.completedAt = new Date().toISOString();
    saveRun(run);

    // Notify SSE listeners of completion
    const listeners = sseConnections.get(runId) || [];
    for (const res of listeners) {
      try {
        res.write(`data: ${JSON.stringify({ type: "done", status: run.status })}\n\n`);
        res.end();
      } catch {
        // connection closed
      }
    }
    sseConnections.delete(runId);

    // Log session
    const sessionEntry = {
      ts: new Date().toISOString(),
      agent: run.agent,
      runId: run.id,
      status: run.status,
      duration_seconds: run.startedAt
        ? Math.round((Date.now() - new Date(run.startedAt).getTime()) / 1000)
        : 0,
    };
    fs.appendFileSync(
      path.join(LOG_DIR, "sessions.jsonl"),
      JSON.stringify(sessionEntry) + "\n",
      "utf-8"
    );

    currentRun = null;
    processQueue();
  });
}

// --- HTTP helpers ---

function readBody(req: IncomingMessage): Promise<string> {
  return new Promise((resolve) => {
    let body = "";
    req.on("data", (chunk) => (body += chunk));
    req.on("end", () => resolve(body));
  });
}

function json(res: ServerResponse, data: unknown, status = 200) {
  res.writeHead(status, { "Content-Type": "application/json" });
  res.end(JSON.stringify(data));
}

function notFound(res: ServerResponse) {
  json(res, { error: "not found" }, 404);
}

function unauthorized(res: ServerResponse) {
  json(res, { error: "unauthorized" }, 401);
}

// --- Route matching ---

function matchRoute(
  method: string,
  url: string,
  pattern: string
): Record<string, string> | null {
  if (method !== pattern.split(" ")[0]) return null;
  const pathPattern = pattern.split(" ")[1];
  const parts = url.split("?")[0].split("/");
  const patternParts = pathPattern.split("/");

  if (parts.length !== patternParts.length) return null;

  const params: Record<string, string> = {};
  for (let i = 0; i < parts.length; i++) {
    if (patternParts[i].startsWith(":")) {
      params[patternParts[i].slice(1)] = parts[i];
    } else if (parts[i] !== patternParts[i]) {
      return null;
    }
  }
  return params;
}

// --- Agents config ---

const VALID_AGENTS = ["sweep", "scout", "builder", "strategist", "design-engineer"];

// --- Server ---

const httpServer = createServer(async (req, res) => {
  const method = req.method || "GET";
  const url = req.url || "/";

  // CORS headers for local dev
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");

  if (method === "OPTIONS") {
    res.writeHead(204);
    res.end();
    return;
  }

  // Auth check
  if (API_KEY) {
    const authHeader = req.headers.authorization || "";
    const token = authHeader.replace("Bearer ", "");
    if (token !== API_KEY) {
      return unauthorized(res);
    }
  }

  let params: Record<string, string> | null;

  // POST /agents/:name/run
  params = matchRoute(method, url, "POST /agents/:name/run");
  if (params) {
    const agent = params.name;
    if (!VALID_AGENTS.includes(agent)) {
      return json(res, { error: `Unknown agent: ${agent}` }, 400);
    }

    const runId = crypto.randomUUID().slice(0, 8);
    const run: Run = {
      id: runId,
      agent,
      status: "queued",
      output: [],
    };

    runs.set(runId, run);
    saveRun(run);
    runQueue.push(runId);
    processQueue();

    return json(res, { runId, status: run.status }, 201);
  }

  // GET /agents/:name/status
  params = matchRoute(method, url, "GET /agents/:name/status");
  if (params) {
    const agent = params.name;
    if (!VALID_AGENTS.includes(agent)) {
      return json(res, { error: `Unknown agent: ${agent}` }, 400);
    }

    // Find last run for this agent
    const agentRuns = Array.from(runs.values())
      .filter((r) => r.agent === agent)
      .sort((a, b) => (b.startedAt || "").localeCompare(a.startedAt || ""));

    const lastRun = agentRuns[0] || null;

    return json(res, {
      agent,
      lastRun: lastRun
        ? { id: lastRun.id, status: lastRun.status, startedAt: lastRun.startedAt }
        : null,
      queuedRuns: runQueue.filter((id) => runs.get(id)?.agent === agent).length,
    });
  }

  // GET /runs/:id
  params = matchRoute(method, url, "GET /runs/:id");
  if (params && !url.includes("/stream")) {
    const run = loadRun(params.id);
    if (!run) return notFound(res);
    return json(res, {
      id: run.id,
      agent: run.agent,
      status: run.status,
      startedAt: run.startedAt,
      completedAt: run.completedAt,
      output: run.output.join(""),
    });
  }

  // GET /runs/:id/stream
  params = matchRoute(method, url, "GET /runs/:id/stream");
  if (params) {
    const run = runs.get(params.id) || loadRun(params.id);
    if (!run) return notFound(res);

    res.writeHead(200, {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      Connection: "keep-alive",
    });

    // Send buffered output
    for (const chunk of run.output) {
      res.write(`data: ${JSON.stringify({ type: "output", content: chunk })}\n\n`);
    }

    if (run.status === "completed" || run.status === "failed") {
      res.write(`data: ${JSON.stringify({ type: "done", status: run.status })}\n\n`);
      res.end();
      return;
    }

    // Register for live updates
    if (!sseConnections.has(run.id)) {
      sseConnections.set(run.id, []);
    }
    sseConnections.get(run.id)!.push(res);

    req.on("close", () => {
      const conns = sseConnections.get(run.id);
      if (conns) {
        const idx = conns.indexOf(res);
        if (idx !== -1) conns.splice(idx, 1);
      }
    });
    return;
  }

  // GET /state/latest
  if (method === "GET" && url === "/state/latest") {
    const sweepFile = path.join(STATE_DIR, "sweep-latest.md");
    if (!fs.existsSync(sweepFile)) {
      return json(res, { content: null, message: "No sweep state found" });
    }
    const content = fs.readFileSync(sweepFile, "utf-8");
    return json(res, { content, updatedAt: fs.statSync(sweepFile).mtime.toISOString() });
  }

  // GET /budget
  if (method === "GET" && url === "/budget") {
    const sessionsFile = path.join(LOG_DIR, "sessions.jsonl");
    const result: Record<string, number> = {};
    let todayTotal = 0;
    let weekTotal = 0;
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const weekAgo = new Date(Date.now() - 7 * 86400000);

    if (fs.existsSync(sessionsFile)) {
      const lines = fs.readFileSync(sessionsFile, "utf-8").trim().split("\n").filter(Boolean);
      for (const line of lines) {
        try {
          const entry = JSON.parse(line);
          const cost = entry.cost_usd || 0;
          const ts = new Date(entry.ts);
          const agent = entry.agent || "unknown";
          result[agent] = (result[agent] || 0) + cost;
          if (ts >= today) todayTotal += cost;
          if (ts >= weekAgo) weekTotal += cost;
        } catch {
          // skip
        }
      }
    }

    return json(res, { today: todayTotal, thisWeek: weekTotal, byAgent: result });
  }

  // POST /knowledge/backup
  if (method === "POST" && url === "/knowledge/backup") {
    const timestamp = new Date().toISOString().replace(/[:.]/g, "-").slice(0, 19);
    const backupDir = path.join(CLAUDE_DIR, "backups", `knowledge-${timestamp}`);
    fs.mkdirSync(backupDir, { recursive: true });

    const copyDir = (src: string, dest: string) => {
      fs.mkdirSync(dest, { recursive: true });
      for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
        const srcPath = path.join(src, entry.name);
        const destPath = path.join(dest, entry.name);
        if (entry.isDirectory()) copyDir(srcPath, destPath);
        else fs.copyFileSync(srcPath, destPath);
      }
    };

    if (fs.existsSync(KNOWLEDGE_DIR)) {
      copyDir(KNOWLEDGE_DIR, backupDir);
    }

    return json(res, { snapshotPath: backupDir, timestamp });
  }

  // --- Eval endpoints ---

  // GET /evals/history — all eval results
  if (method === "GET" && url === "/evals/history") {
    if (!fs.existsSync(HISTORY_FILE)) {
      return json(res, { evals: [], count: 0 });
    }
    const lines = fs.readFileSync(HISTORY_FILE, "utf-8").trim().split("\n").filter(Boolean);
    const evals = lines.map((l) => { try { return JSON.parse(l); } catch { return null; } }).filter(Boolean);
    return json(res, { evals, count: evals.length });
  }

  // GET /evals/summary — aggregated stats
  if (method === "GET" && url === "/evals/summary") {
    if (!fs.existsSync(HISTORY_FILE)) {
      return json(res, { total: 0, ship: 0, fixes: 0, blocked: 0, ceilingAvg: 0, perspectivesAvg: 0, history: [] });
    }
    const lines = fs.readFileSync(HISTORY_FILE, "utf-8").trim().split("\n").filter(Boolean);
    const evals = lines.map((l) => { try { return JSON.parse(l); } catch { return null; } }).filter(Boolean);

    let ship = 0, fixes = 0, blocked = 0;
    let ceilingSum = 0, ceilingCount = 0;
    let perspSum = 0, perspCount = 0;
    const allGaps: Record<string, number> = {};

    for (const e of evals) {
      if (e.verdict === "SHIP") ship++;
      else if (e.verdict === "SHIP WITH FIXES" || e.verdict === "SHIP_WITH_FIXES") fixes++;
      else if (e.verdict === "BLOCKED") blocked++;
      if (typeof e.ceiling === "number") { ceilingSum += e.ceiling; ceilingCount++; }
      if (typeof e.perspectives === "number") { perspSum += e.perspectives; perspCount++; }
      if (Array.isArray(e.ceiling_gaps)) {
        for (const g of e.ceiling_gaps) { allGaps[g] = (allGaps[g] || 0) + 1; }
      }
    }

    const topGaps = Object.entries(allGaps).sort((a, b) => b[1] - a[1]).slice(0, 10).map(([gap, count]) => ({ gap, count }));

    return json(res, {
      total: evals.length,
      ship,
      fixes,
      blocked,
      shipRate: evals.length > 0 ? Math.round((ship / evals.length) * 100) : 0,
      ceilingAvg: ceilingCount > 0 ? Math.round((ceilingSum / ceilingCount) * 100) / 100 : null,
      perspectivesAvg: perspCount > 0 ? Math.round((perspSum / perspCount) * 100) / 100 : null,
      topGaps,
      history: evals.slice(-30),
    });
  }

  // GET /evals/reports/:name — individual report
  params = matchRoute(method, url, "GET /evals/reports/:name");
  if (params) {
    const reportFile = path.join(EVALS_DIR, path.basename(params.name));
    if (!fs.existsSync(reportFile)) return notFound(res);
    const content = fs.readFileSync(reportFile, "utf-8");
    res.writeHead(200, { "Content-Type": "text/markdown" });
    res.end(content);
    return;
  }

  // --- Dashboard ---

  // GET / or /dashboard — serve the dashboard HTML
  if (method === "GET" && (url === "/" || url === "/dashboard")) {
    const dashboardFile = path.join(RHINO_DIR, "src", "api-server", "dashboard.html");
    if (fs.existsSync(dashboardFile)) {
      const html = fs.readFileSync(dashboardFile, "utf-8");
      res.writeHead(200, { "Content-Type": "text/html" });
      res.end(html);
      return;
    }
    res.writeHead(200, { "Content-Type": "text/html" });
    res.end("<html><body><h1>rhino-os</h1><p>Dashboard not found. Reinstall rhino-os.</p></body></html>");
    return;
  }

  // GET /health
  if (method === "GET" && url === "/health") {
    return json(res, { status: "ok", version: "1.0.0" });
  }

  return notFound(res);
});

httpServer.on("error", (err: NodeJS.ErrnoException) => {
  if (err.code === "EADDRINUSE") {
    console.error(`Port ${PORT} is already in use.`);
    console.error(`Kill the existing process: lsof -ti :${PORT} | xargs kill`);
    console.error(`Or use a different port: RHINO_PORT=7891 node src/api-server/index.ts`);
    process.exit(1);
  }
  throw err;
});

httpServer.listen(PORT, "127.0.0.1", () => {
  console.log(`rhino API server listening on http://127.0.0.1:${PORT}`);
  console.log("Press Ctrl+C to stop");
});

// Graceful shutdown
process.on("SIGTERM", () => {
  console.log("Shutting down...");
  httpServer.close();
  process.exit(0);
});

process.on("SIGINT", () => {
  console.log("Shutting down...");
  httpServer.close();
  process.exit(0);
});
