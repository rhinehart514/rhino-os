#!/usr/bin/env node

/**
 * taste.mjs — Visual taste evaluator. Your eval loss for product quality.
 *
 * The 2026 approach: don't grep the code, LOOK at the product.
 * 1. Starts dev server (or uses running one)
 * 2. Screenshots every route with Playwright
 * 3. Sends screenshots to Claude vision with taste rubric
 * 4. Returns scored breakdown with cited visual evidence
 *
 * This is the expensive eval — run on demand, not every commit.
 * score.sh is the cheap proxy (training loss). This is eval loss.
 *
 * Usage:
 *   node taste.mjs [project-dir] [--json] [--port 3000] [--url http://localhost:3000]
 *
 * Requires:
 *   - playwright (npx playwright install chromium)
 *   - claude CLI (for evaluation via OAuth — no API key needed)
 */

import { chromium } from "playwright";
import { readFileSync, existsSync, writeFileSync, readdirSync, statSync, mkdirSync } from "fs";
import { join, resolve } from "path";
import { execSync, spawn } from "child_process";

// --- Progress display ---
const DIM = "\x1b[2m";
const BOLD = "\x1b[1m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const NC = "\x1b[0m";
const spinChars = "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏";
let spinInterval = null;

function startSpinner(msg) {
  let i = 0;
  process.stderr.write(DIM);
  spinInterval = setInterval(() => {
    process.stderr.write(`\r  ${spinChars[i % spinChars.length]} ${msg}`);
    i++;
  }, 100);
}

function stopSpinner(msg) {
  if (spinInterval) {
    clearInterval(spinInterval);
    spinInterval = null;
  }
  process.stderr.write(`\r  ${GREEN}✓${NC} ${msg}\n`);
}

// --- rhino.yml config reader ---
function loadRhinoConfig() {
  const configPath = join(import.meta.dirname, "..", "config", "rhino.yml");
  if (!existsSync(configPath)) return {};
  const content = readFileSync(configPath, "utf-8");
  // Simple flat YAML parser — reads dotted paths
  const values = {};
  const stack = [];
  for (const line of content.split("\n")) {
    if (/^\s*#/.test(line) || !line.trim()) continue;
    const indent = line.length - line.trimStart().length;
    const match = line.trimStart().match(/^([a-zA-Z_][\w-]*):\s*(.*)/);
    if (!match) continue;
    const [, key, rawVal] = match;
    const val = rawVal.replace(/#.*/, "").trim();
    // Maintain indent stack for nesting
    while (stack.length > 0 && stack[stack.length - 1].indent >= indent) stack.pop();
    stack.push({ key, indent });
    if (val && val !== "~") {
      const fullKey = stack.map(s => s.key).join(".");
      values[fullKey] = val;
    }
  }
  return values;
}

const rhinoCfg = loadRhinoConfig();
function cfg(key, defaultVal) {
  const v = rhinoCfg[key];
  if (v === undefined || v === "~") return defaultVal;
  const num = Number(v);
  return isNaN(num) ? v : num;
}

// --- Config ---
const args = process.argv.slice(2);
let projectDir = ".";
let outputMode = "breakdown";
let baseUrl = null;
let port = null;
let skipServer = false;
let force = false;

for (let i = 0; i < args.length; i++) {
  if (args[i] === "--json") outputMode = "json";
  else if (args[i] === "--score") outputMode = "score";
  else if (args[i] === "--port") port = parseInt(args[i + 1]), i++;
  else if (args[i] === "--url") baseUrl = args[i + 1], skipServer = true, i++;
  else if (args[i] === "--force") force = true;
  else if (args[i] === "--help" || args[i] === "-h") {
    console.log(`Usage: node taste.mjs [project-dir] [--json] [--port 3000] [--url http://...] [--force]`);
    console.log(`\nEvaluates product taste by screenshotting every route and judging with Claude vision.`);
    console.log(`\nRequires: claude CLI (OAuth), playwright (npx playwright install chromium)`);
    process.exit(0);
  }
  else if (!args[i].startsWith("-")) projectDir = args[i];
}

projectDir = resolve(projectDir);

// --- Load taste.yml config (route selection) ---
function loadTasteConfig() {
  const configPaths = [
    join(projectDir, ".claude", "taste.yml"),
    join(projectDir, ".claude", "taste.yaml"),
  ];

  for (const p of configPaths) {
    if (existsSync(p)) {
      try {
        const content = readFileSync(p, "utf-8");
        // Simple YAML parser for our flat structure
        const config = { routes: [], mobile: [] };
        let currentKey = null;
        for (const line of content.split("\n")) {
          const trimmed = line.trim();
          if (trimmed.startsWith("#") || !trimmed) continue;
          if (trimmed === "routes:") { currentKey = "routes"; continue; }
          if (trimmed === "mobile:") { currentKey = "mobile"; continue; }
          if (currentKey && trimmed.startsWith("- ")) {
            const val = trimmed.slice(2).trim().replace(/#.*/, "").trim();
            if (val) config[currentKey].push(val);
          }
        }
        if (config.routes.length > 0) return config;
      } catch {}
    }
  }
  return null;
}

// --- Detect routes ---
function detectRoutes(srcDir) {
  // Check for taste.yml config first
  const config = loadTasteConfig();
  if (config) {
    return { routes: config.routes, mobileOnly: config.mobile || [] };
  }

  // Auto-detect: find all routes, then pick the most important ones
  const allRoutes = [];

  function walkDir(dir, prefix = "") {
    if (!existsSync(dir)) return;
    const entries = readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
      if (entry.name.startsWith("_") || entry.name.startsWith(".")) continue;
      if (entry.name === "node_modules" || entry.name === "api") continue;

      const fullPath = join(dir, entry.name);
      if (entry.isDirectory()) {
        if (entry.name.startsWith("[")) continue;
        walkDir(fullPath, `${prefix}/${entry.name}`);
      } else if (entry.name === "page.tsx" || entry.name === "page.jsx" || entry.name === "page.ts") {
        allRoutes.push(prefix || "/");
      }
    }
  }

  const appDirs = [
    join(srcDir, "app"),
    join(projectDir, "apps/web/src/app"),
    join(projectDir, "src/app"),
    join(projectDir, "app"),
  ];

  for (const appDir of appDirs) {
    if (existsSync(appDir)) {
      walkDir(appDir);
      break;
    }
  }

  if (!allRoutes.includes("/")) allRoutes.unshift("/");

  // Smart selection: cap at 8 routes, prioritize key pages
  const priorityKeywords = ["create", "new", "enter", "login", "sign", "onboard", "home", "dashboard", "profile", "settings", "about"];
  const prioritized = [];
  const rest = [];

  for (const route of [...new Set(allRoutes)]) {
    if (route === "/") { prioritized.unshift(route); continue; }
    const lower = route.toLowerCase();
    if (priorityKeywords.some(k => lower.includes(k))) {
      prioritized.push(route);
    } else {
      rest.push(route);
    }
  }

  // Take priority routes first, fill remaining with others, cap at 8
  const maxRoutes = cfg("taste.max_routes", 8);
  const selected = [...prioritized, ...rest].slice(0, maxRoutes);

  return { routes: selected, mobileOnly: ["/"] };
}

// --- Screenshot routes ---
async function screenshotRoutes(browser, url, routeConfig) {
  const screenshots = [];
  const page = await browser.newPage();

  const desktopVp = { width: cfg("taste.viewports.desktop.width", 1440), height: cfg("taste.viewports.desktop.height", 900), name: "desktop" };
  const mobileVp = { width: cfg("taste.viewports.mobile.width", 390), height: cfg("taste.viewports.mobile.height", 844), name: "mobile" };
  const { routes, mobileOnly = [] } = routeConfig;

  for (const route of routes) {
    // Desktop for all routes
    await page.setViewportSize({ width: desktopVp.width, height: desktopVp.height });
    try {
      await page.goto(`${url}${route}`, { waitUntil: "networkidle", timeout: cfg("taste.timeouts.page_load", 30000) });
      await page.waitForTimeout(cfg("taste.timeouts.post_load_wait", 1000));
      const buffer = await page.screenshot({ fullPage: true, type: "png" });
      screenshots.push({ route, viewport: "desktop", dimensions: `${desktopVp.width}x${desktopVp.height}`, base64: buffer.toString("base64") });
    } catch (err) {
      console.error(`  Failed: ${route} (desktop): ${err.message}`);
    }

    // Mobile only for specified routes
    if (mobileOnly.includes(route)) {
      await page.setViewportSize({ width: mobileVp.width, height: mobileVp.height });
      try {
        await page.goto(`${url}${route}`, { waitUntil: "networkidle", timeout: cfg("taste.timeouts.page_load", 30000) });
        await page.waitForTimeout(cfg("taste.timeouts.post_load_wait", 1000));
        const buffer = await page.screenshot({ fullPage: true, type: "png" });
        screenshots.push({ route, viewport: "mobile", dimensions: `${mobileVp.width}x${mobileVp.height}`, base64: buffer.toString("base64") });
      } catch (err) {
        console.error(`  Failed: ${route} (mobile): ${err.message}`);
      }
    }
  }

  await page.close();
  return screenshots;
}

// --- Load intelligence layers ---
function loadContext() {
  const ctx = { landscape: null, taste: null, product: null };

  // Landscape positions (from scout)
  const landscapePath = join(process.env.HOME, ".claude", "knowledge", "landscape.json");
  if (existsSync(landscapePath)) {
    try {
      const data = JSON.parse(readFileSync(landscapePath, "utf-8"));
      ctx.landscape = data.positions
        ?.filter(p => p.confidence === "strong")
        .map(p => p.position)
        .join("\n- ") || null;
    } catch {}
  }

  // Taste profile (accumulated preferences)
  const tastePath = join(process.env.HOME, ".claude", "knowledge", "taste.jsonl");
  if (existsSync(tastePath)) {
    try {
      const lines = readFileSync(tastePath, "utf-8").trim().split("\n").slice(-20);
      const signals = lines.map(l => {
        try { const j = JSON.parse(l); return `[${j.strength}] ${j.signal}`; } catch { return null; }
      }).filter(Boolean);
      if (signals.length) ctx.taste = signals.join("\n- ");
    } catch {}
  }

  // Project CLAUDE.md (product context)
  for (const p of [
    join(projectDir, "CLAUDE.md"),
    join(projectDir, ".claude", "CLAUDE.md"),
  ]) {
    if (existsSync(p)) {
      try {
        const content = readFileSync(p, "utf-8");
        // Extract product section (first ~50 lines or until ## that isn't Product)
        const lines = content.split("\n").slice(0, 80);
        ctx.product = lines.join("\n");
      } catch {}
      break;
    }
  }

  return ctx;
}

// --- Build taste rubric prompt ---
function buildRubricPrompt(routes) {
  const ctx = loadContext();

  let marketSection = "";
  if (ctx.landscape) {
    marketSection = `\n## Market Context (from landscape intelligence)
You know these things about the market. Use them to calibrate your judgment:
- ${ctx.landscape}
`;
  }

  let tasteSection = "";
  if (ctx.taste) {
    tasteSection = `\n## Founder's Taste Profile (accumulated preferences)
This founder has shown these preferences. Weight your evaluation accordingly:
- ${ctx.taste}
`;
  }

  let productSection = "";
  if (ctx.product) {
    productSection = `\n## Product Context
${ctx.product}
`;
  }

  return `You are a first-time user who just landed on this product. You have never seen it before. You don't know what it does. You don't care about the code, the architecture, or the design system. You care about ONE thing: does this thing give you value fast enough that you'd come back?

You have the attention span of someone with 40 browser tabs open. You will leave in 5 seconds if you don't understand what this is and what to do next.
${productSection}${marketSection}${tasteSection}
You are looking at screenshots of this application. Score each dimension 1-5 based on your EXPERIENCE as a real user seeing this cold — calibrated against products you actually use daily (Instagram, Discord, Notion, Linear, Arc). Those are the bar. Not "good for a student project." Not "good for an early product."

## Dimensions

1. **HIERARCHY** (do I know what this is and where to look?)
   5 = I understood what this product does and what to do first within 3 seconds
   3 = I can figure it out but had to scan around — nothing grabbed me
   1 = I have no idea what I'm looking at or what to do

2. **BREATHING_ROOM** (does this feel calm or chaotic?)
   5 = I feel relaxed looking at this — content is grouped, nothing is fighting for space
   3 = It's fine but feels a bit crowded or a bit empty — no rhythm
   1 = Overwhelming wall of stuff, or so empty I wonder if it's broken

3. **CONTRAST** (can I tell what's clickable?)
   5 = The main action is obvious, I know exactly what to tap/click without thinking
   3 = I can probably figure out what's interactive but nothing is pulling me toward it
   1 = Everything looks the same — I'd have to hover/tap randomly to discover what's clickable

4. **POLISH** (does this feel like someone cared?)
   5 = Smooth, responsive, things move intentionally — feels like a real product people use
   3 = Works but feels a bit lifeless or inconsistent — some parts polished, some rough
   1 = Feels broken or unfinished — jarring transitions, dead clicks, layout jumps

5. **EMOTIONAL_TONE** (would I tell a friend about this?)
   5 = This has personality — I can feel who it's for and it makes me want to explore
   3 = Neutral — competent but forgettable, I wouldn't mention it to anyone
   1 = Actively off-putting — feels corporate when it should be fun, or chaotic when it should be trustworthy

6. **INFORMATION_DENSITY** (do I feel informed or overwhelmed?)
   5 = I see exactly what I need, nothing I don't — content earns its space
   3 = Some useful info but also clutter, or too sparse to be useful without clicking deeper
   1 = Either drowning in data or staring at a near-empty screen wondering "where's the content?"

7. **WAYFINDING** (do I know what to do next?)
   5 = At every point I know where I am, what I can do, and how to get back — zero dead ends
   3 = I can navigate but hit a moment where I wasn't sure what to do or how to go back
   1 = I'm lost — no breadcrumbs, no obvious next step, I'd close the tab

8. **DISTINCTIVENESS** (would I recognize this tomorrow?)
   5 = This looks like ITSELF — I'd recognize it with the logo hidden
   3 = Competent but I've seen this template before — it's every shadcn/tailwind app
   1 = Pure framework defaults — literally indistinguishable from a tutorial project

## Rules
- You are a USER, not a designer. Score based on your gut reaction, not design theory.
- "I felt confused" beats "the visual hierarchy could be improved" — use first-person experience language.
- Cite what you FELT at specific moments: "I landed on the homepage and didn't know if this was a social app or a tool"
- Calibrate against your daily-use apps — that's the bar. Users don't grade on a curve.
- A score of 3 means "I wouldn't uninstall it but I wouldn't recommend it." 5 means "I'd show someone." 1 means "I'd close the tab."
- Be brutally honest. Most AI-generated UIs score 2-3. Most MVPs score 2-3. Say so.
- The product context tells you WHO this is for — judge whether the UI actually serves THOSE people, not abstract "users."

## Output Format (strict JSON)
{
  "overall": <number 1-5>,
  "dimensions": {
    "hierarchy": { "score": <1-5>, "evidence": "<what you experienced — first person>" },
    "breathing_room": { "score": <1-5>, "evidence": "<what you experienced>" },
    "contrast": { "score": <1-5>, "evidence": "<what you experienced>" },
    "polish": { "score": <1-5>, "evidence": "<what you experienced>" },
    "emotional_tone": { "score": <1-5>, "evidence": "<what you experienced>" },
    "information_density": { "score": <1-5>, "evidence": "<what you experienced>" },
    "wayfinding": { "score": <1-5>, "evidence": "<what you experienced>" },
    "distinctiveness": { "score": <1-5>, "evidence": "<what you experienced>" }
  },
  "strongest": "<which dimension and why — as a user>",
  "weakest": "<which dimension and the specific moment you felt it fail>",
  "would_return": "<yes/no and the honest reason — what would bring you back or what's missing>",
  "would_recommend": "<yes/no and who you'd tell or why you wouldn't>",
  "one_thing": "<the single change that would make you come back — be specific, not generic>"
}

Routes screenshotted: ${routes.join(", ")}
Respond with ONLY the JSON object, no markdown fences.`;
}

// --- Call Claude via CLI (uses OAuth, no API key needed) ---
async function evaluateWithClaude(screenshots, routes, screenshotDir) {
  // Save screenshots to disk so claude CLI can read them
  const savedPaths = [];
  const maxScreenshots = cfg("taste.max_screenshots", 12);
  const selected = screenshots.slice(0, maxScreenshots);

  for (const ss of selected) {
    const filename = `${ss.route.replace(/\//g, "_") || "root"}-${ss.viewport}.png`;
    const filepath = join(screenshotDir, filename);
    writeFileSync(filepath, Buffer.from(ss.base64, "base64"));
    savedPaths.push({ path: filepath, route: ss.route, viewport: ss.viewport, dimensions: ss.dimensions });
  }

  // Build prompt — tell Claude to read the screenshot files
  let prompt = buildRubricPrompt(routes);
  prompt += "\n\nRead each screenshot file below using the Read tool, then evaluate what you see.\n";
  for (const s of savedPaths) {
    prompt += `\n- ${s.path} (${s.route} — ${s.viewport} ${s.dimensions || ""})`;
  }
  prompt += "\n\nAfter reading ALL screenshots, respond with ONLY the JSON object.";

  // Build claude args array (no shell interpolation — safe from injection)
  const claudeArgs = ["-p", "--output-format", "text", "--allowedTools", "Read"];

  try {
    const output = execSync(`claude ${claudeArgs.map(a => `'${a.replace(/'/g, "'\\''")}'`).join(" ")}`, {
      encoding: "utf-8",
      input: prompt,
      maxBuffer: 10 * 1024 * 1024,
      timeout: cfg("taste.timeouts.eval_timeout", 180000),
      shell: true,
    });

    // Parse JSON response
    const text = output.trim();
    try {
      return JSON.parse(text);
    } catch {
      const match = text.match(/\{[\s\S]*\}/);
      if (match) return JSON.parse(match[0]);
      throw new Error(`Failed to parse Claude response as JSON:\n${text}`);
    }
  } catch (err) {
    if (err.status) {
      throw new Error(`claude CLI failed (exit ${err.status}). Is claude installed and authenticated?\n${err.stderr || ""}`);
    }
    throw err;
  }
}

// --- Check if server is already running on a port ---
async function isPortActive(portNum) {
  const check = async () => {
    try {
      const resp = await fetch(`http://localhost:${portNum}`, { signal: AbortSignal.timeout(cfg("taste.timeouts.port_check", 5000)) });
      return resp.ok || resp.status < 500;
    } catch {
      return false;
    }
  };
  // Double-check with a gap to avoid false positives (e.g. server shutting down)
  if (!await check()) return false;
  await new Promise(r => setTimeout(r, 500));
  return check();
}

// --- Start dev server ---
async function startDevServer(dir) {
  const pkgPath = join(dir, "package.json");
  if (!existsSync(pkgPath)) {
    throw new Error("No package.json found. Provide --url instead.");
  }

  const pkg = JSON.parse(readFileSync(pkgPath, "utf-8"));
  const scripts = pkg.scripts || {};

  // Determine dev command and port
  let devCmd = "dev";
  let detectedPort = 3000;

  if (scripts.dev) {
    const portMatch = scripts.dev.match(/-p\s*(\d+)|--port\s*(\d+)|PORT=(\d+)/);
    if (portMatch) detectedPort = parseInt(portMatch[1] || portMatch[2] || portMatch[3]);
  }

  if (port) detectedPort = port;

  // Check if server is already running
  if (await isPortActive(detectedPort)) {
    const serverUrl = `http://localhost:${detectedPort}`;
    stopSpinner(`dev server already running at ${serverUrl}`);
    return { url: serverUrl, process: null, port: detectedPort };
  }

  startSpinner(`starting dev server on port ${detectedPort}...`);

  const child = spawn("npm", ["run", devCmd], {
    cwd: dir,
    stdio: "pipe",
    env: { ...process.env, PORT: String(detectedPort) },
  });

  // Wait for server to be ready
  const serverUrl = `http://localhost:${detectedPort}`;
  let ready = false;
  let attempts = 0;

  while (!ready && attempts < 60) {
    attempts++;
    try {
      await fetch(serverUrl, { signal: AbortSignal.timeout(cfg("taste.timeouts.server_startup", 3000)) });
      ready = true;
    } catch {
      await new Promise(r => setTimeout(r, 1000));
    }
  }

  if (!ready) {
    child.kill();
    throw new Error(`Dev server failed to start on port ${detectedPort} after 60s`);
  }

  stopSpinner(`dev server ready at ${serverUrl}`);
  return { url: serverUrl, process: child, port: detectedPort };
}

// --- Main ---
async function main() {
  // Check for claude CLI
  try {
    execSync("which claude", { stdio: "pipe" });
  } catch {
    console.error("Error: claude CLI not found. Install Claude Code first.");
    process.exit(1);
  }

  console.error(`${BOLD}=== rhino taste — visual product evaluation ===${NC}\n`);

  // --- Freshness check ---
  const reportDir = join(projectDir, ".claude", "evals", "reports");
  const CACHE_MAX_AGE = cfg("taste.cache_ttl", 7200) * 1000;

  if (!force && existsSync(reportDir)) {
    const today = new Date().toISOString().slice(0, 10);
    const todayReport = join(reportDir, `taste-${today}.json`);
    if (existsSync(todayReport)) {
      const age = Date.now() - statSync(todayReport).mtimeMs;
      if (age < CACHE_MAX_AGE) {
        const cached = JSON.parse(readFileSync(todayReport, "utf-8"));
        const ageMin = Math.round(age / 60000);
        console.error(`${YELLOW}  Eval already ran ${ageMin}m ago. Use --force to re-run.${NC}\n`);

        // Show the cached result
        switch (outputMode) {
          case "json": console.log(JSON.stringify(cached)); break;
          case "score": console.log(cached.score_100); break;
          default:
            console.log(`=== Taste Score: ${cached.score_100}/100 (${cached.overall}/5) ===\n`);
            for (const [dim, data] of Object.entries(cached.dimensions)) {
              const bar = "█".repeat(data.score) + "░".repeat(5 - data.score);
              console.log(`  ${dim.padEnd(20)} ${bar} ${data.score}/5`);
              console.log(`  ${"".padEnd(20)} ${data.evidence}\n`);
            }
            console.log(`  Strongest: ${cached.strongest}`);
            console.log(`  Weakest:   ${cached.weakest}`);
            if (cached.would_return) console.log(`\n  Return?    ${cached.would_return}`);
            if (cached.would_recommend) console.log(`  Recommend? ${cached.would_recommend}`);
            console.log(`\n  → ${cached.one_thing}`);
        }
        return;
      }
    }
  }

  // Find source dir for route detection
  let srcDir = projectDir;
  if (existsSync(join(projectDir, "apps/web/src"))) srcDir = join(projectDir, "apps/web/src");
  else if (existsSync(join(projectDir, "src"))) srcDir = join(projectDir, "src");

  // Detect routes
  startSpinner("detecting routes...");
  const routeConfig = detectRoutes(srcDir);
  const { routes, mobileOnly } = routeConfig;
  const mobileCount = routes.filter(r => mobileOnly.includes(r)).length;
  stopSpinner(`${routes.length} routes (${mobileCount} with mobile): ${routes.join(", ")}`);

  // Start or connect to dev server
  let server = null;
  let url = baseUrl;

  if (!url) {
    startSpinner("checking dev server...");
    server = await startDevServer(projectDir);
    url = server.url;
  }

  try {
    // Launch Playwright
    startSpinner("launching browser...");
    const browser = await chromium.launch({ headless: true });
    stopSpinner("browser ready");

    // Screenshot routes
    const totalShots = routes.length + mobileCount;
    startSpinner(`screenshotting ${totalShots} views (${routes.length} desktop + ${mobileCount} mobile)...`);
    const screenshots = await screenshotRoutes(browser, url, routeConfig);
    stopSpinner(`captured ${screenshots.length} screenshots`);

    await browser.close();

    if (screenshots.length === 0) {
      throw new Error("No screenshots captured — dev server may have died. Check that `npm run dev` works and try again.");
    }

    // Save screenshots and evaluate with Claude via CLI (OAuth)
    const screenshotDir = join(projectDir, ".claude", "evals", "screenshots");
    mkdirSync(screenshotDir, { recursive: true });

    startSpinner("evaluating with Claude vision (this takes ~30s)...");
    const result = await evaluateWithClaude(screenshots, routes, screenshotDir);
    stopSpinner("evaluation complete");

    // Add metadata
    result.meta = {
      project: projectDir,
      routes: routes.length,
      screenshots: screenshots.length,
      timestamp: new Date().toISOString(),
      evaluator: "claude-vision",
    };

    // Convert 1-5 to 0-100 for consistency with score.sh
    result.score_100 = Math.round((result.overall / 5) * 100);

    // Add structured weakest_dimension for builder handoff (taste → builder)
    if (result.dimensions) {
      let minScore = 6, minDim = "";
      for (const [dim, data] of Object.entries(result.dimensions)) {
        if (data.score < minScore) { minScore = data.score; minDim = dim; }
      }
      if (minDim) result.weakest_dimension = minDim;
    }

    // Save result
    mkdirSync(reportDir, { recursive: true });
    const reportPath = join(reportDir, `taste-${new Date().toISOString().slice(0, 10)}.json`);
    writeFileSync(reportPath, JSON.stringify(result, null, 2));
    console.error(`\n  ${GREEN}Report saved: ${reportPath}${NC}\n`);

    // Output
    switch (outputMode) {
      case "json":
        console.log(JSON.stringify(result));
        break;
      case "score":
        console.log(result.score_100);
        break;
      case "breakdown":
      default:
        console.log(`=== Taste Score: ${result.score_100}/100 (${result.overall}/5) ===\n`);
        for (const [dim, data] of Object.entries(result.dimensions)) {
          const bar = "█".repeat(data.score) + "░".repeat(5 - data.score);
          console.log(`  ${dim.padEnd(20)} ${bar} ${data.score}/5`);
          console.log(`  ${"".padEnd(20)} ${data.evidence}\n`);
        }
        console.log(`  Strongest: ${result.strongest}`);
        console.log(`  Weakest:   ${result.weakest}`);
        if (result.would_return) console.log(`\n  Return?    ${result.would_return}`);
        if (result.would_recommend) console.log(`  Recommend? ${result.would_recommend}`);
        console.log(`\n  → ${result.one_thing}`);
        break;
    }
  } finally {
    if (server?.process) {
      server.process.kill();
      console.error("\n  Dev server stopped.");
    }
  }
}

main().catch(err => {
  console.error(`Error: ${err.message}`);
  process.exit(1);
});
