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
  const selected = [...prioritized, ...rest].slice(0, 8);

  return { routes: selected, mobileOnly: ["/"] };
}

// --- Screenshot routes ---
async function screenshotRoutes(browser, url, routeConfig) {
  const screenshots = [];
  const page = await browser.newPage();

  const desktopVp = { width: 1440, height: 900, name: "desktop" };
  const mobileVp = { width: 390, height: 844, name: "mobile" };
  const { routes, mobileOnly = [] } = routeConfig;

  for (const route of routes) {
    // Desktop for all routes
    await page.setViewportSize({ width: desktopVp.width, height: desktopVp.height });
    try {
      await page.goto(`${url}${route}`, { waitUntil: "networkidle", timeout: 15000 });
      await page.waitForTimeout(1000);
      const buffer = await page.screenshot({ fullPage: true, type: "png" });
      screenshots.push({ route, viewport: "desktop", dimensions: `${desktopVp.width}x${desktopVp.height}`, base64: buffer.toString("base64") });
    } catch (err) {
      console.error(`  Failed: ${route} (desktop): ${err.message}`);
    }

    // Mobile only for specified routes
    if (mobileOnly.includes(route)) {
      await page.setViewportSize({ width: mobileVp.width, height: mobileVp.height });
      try {
        await page.goto(`${url}${route}`, { waitUntil: "networkidle", timeout: 15000 });
        await page.waitForTimeout(1000);
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

  return `You are a product taste evaluator with market awareness. You judge products the way a REAL USER experiences them — not how they're coded, not as an abstract design exercise.

You have context about this product, its market, and its founder's preferences. Use ALL of it.
${productSection}${marketSection}${tasteSection}
You are looking at screenshots of this application. Score each dimension 1-5 based on what you SEE, calibrated against what real users actually use daily (Instagram, Discord, Notion, Linear, Arc).

## Dimensions

1. **HIERARCHY** (does the eye know where to go?)
   5 = Clear visual order, primary action dominates, page "reads" naturally
   3 = Some hierarchy but competing elements
   1 = Everything same size/weight/color, no priority signal

2. **BREATHING_ROOM** (does the layout breathe?)
   5 = Intentional whitespace, groups separated, spacious but not empty
   3 = Adequate but uniform spacing, no rhythm
   1 = Cramped, no padding, walls of content

3. **CONTRAST** (do important things pop?)
   5 = Primary actions unmissable, clear interactive vs static distinction
   3 = Some contrast but could be stronger
   1 = Everything blends, can't tell what's clickable

4. **POLISH** (does it feel alive?)
   5 = Transitions visible, loading feedback present, micro-animations add delight
   3 = Some polish but inconsistent
   1 = Dead clicks, jarring state changes, elements appear/disappear

5. **EMOTIONAL_TONE** (does it match the product's identity?)
   5 = UI feels like THIS product — recognizable, matches the audience
   3 = Neutral, could be any product
   1 = Mismatch (campus app looks like enterprise SaaS, social app feels like admin panel)

6. **INFORMATION_DENSITY** (right amount per screen?)
   5 = Goldilocks — useful content, scannable, not overwhelming
   3 = Slightly off — too sparse or too dense
   1 = Extreme — wastefully empty or wall of content

7. **WAYFINDING** (can users navigate without thinking?)
   5 = Next action always obvious, no dead ends, navigation consistent
   3 = Works but has dead ends or unclear moments
   1 = Users would get lost, no clear path

8. **DISTINCTIVENESS** (is this memorable?)
   5 = You'd recognize this in a lineup — visual identity beyond framework defaults
   3 = Competent but generic, could be any product
   1 = Pure framework defaults, looks like a template

## Rules
- Score based on what you SEE, not what you imagine the code does
- Cite specific visual evidence: "the hero text competes with the sidebar nav for attention"
- Calibrate against products users ACTUALLY use daily — that's the bar, not "good for an early product"
- A score of 3 is "fine." 5 means "clearly thought about." 1 means "actively hurts."
- Be honest. Most AI-generated UIs score 2-3. That's the starting point, not a failure.
- Use the product context to judge FIT — does the UI serve THIS product's specific users and goals?

## Output Format (strict JSON)
{
  "overall": <number 1-5>,
  "dimensions": {
    "hierarchy": { "score": <1-5>, "evidence": "<what you see>" },
    "breathing_room": { "score": <1-5>, "evidence": "<what you see>" },
    "contrast": { "score": <1-5>, "evidence": "<what you see>" },
    "polish": { "score": <1-5>, "evidence": "<what you see>" },
    "emotional_tone": { "score": <1-5>, "evidence": "<what you see>" },
    "information_density": { "score": <1-5>, "evidence": "<what you see>" },
    "wayfinding": { "score": <1-5>, "evidence": "<what you see>" },
    "distinctiveness": { "score": <1-5>, "evidence": "<what you see>" }
  },
  "strongest": "<which dimension is best and why>",
  "weakest": "<which dimension needs most work and specific evidence>",
  "one_thing": "<the single highest-impact change — be specific, not generic>"
}

Routes screenshotted: ${routes.join(", ")}
Respond with ONLY the JSON object, no markdown fences.`;
}

// --- Call Claude via CLI (uses OAuth, no API key needed) ---
async function evaluateWithClaude(screenshots, routes, screenshotDir) {
  // Save screenshots to disk so claude CLI can read them
  const savedPaths = [];
  const maxScreenshots = 12; // 8 routes + ~4 mobile = 12 max from smart selection
  const selected = screenshots.slice(0, maxScreenshots);

  for (const ss of selected) {
    const filename = `${ss.route.replace(/\//g, "_") || "root"}-${ss.viewport}.png`;
    const filepath = join(screenshotDir, filename);
    writeFileSync(filepath, Buffer.from(ss.base64, "base64"));
    savedPaths.push({ path: filepath, route: ss.route, viewport: ss.viewport, dimensions: ss.dimensions });
  }

  // Build prompt with image references for claude -p
  let prompt = buildRubricPrompt(routes);
  prompt += "\n\nScreenshots are attached as images. Evaluate them and respond with ONLY the JSON object.";

  // Build claude args array (no shell interpolation — safe from injection)
  const claudeArgs = ["-p", "--output-format", "text"];
  for (const s of savedPaths) {
    claudeArgs.push("--image", s.path);
  }

  try {
    const output = execSync(`claude ${claudeArgs.map(a => `'${a.replace(/'/g, "'\\''")}'`).join(" ")}`, {
      encoding: "utf-8",
      input: prompt,
      maxBuffer: 10 * 1024 * 1024,
      timeout: 180000,
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
  try {
    const resp = await fetch(`http://localhost:${portNum}`, { signal: AbortSignal.timeout(5000) });
    return resp.ok || resp.status < 500;
  } catch {
    return false;
  }
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
      await fetch(serverUrl, { signal: AbortSignal.timeout(2000) });
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
  const CACHE_MAX_AGE = 2 * 60 * 60 * 1000; // 2 hours

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
