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
 *   - ANTHROPIC_API_KEY env var
 *   - playwright (npx playwright install chromium)
 */

import { chromium } from "playwright";
import Anthropic from "@anthropic-ai/sdk";
import { readFileSync, existsSync, writeFileSync, readdirSync } from "fs";
import { join, resolve } from "path";
import { execSync, spawn } from "child_process";

// --- Config ---
const args = process.argv.slice(2);
let projectDir = ".";
let outputMode = "breakdown";
let baseUrl = null;
let port = null;
let skipServer = false;

for (let i = 0; i < args.length; i++) {
  if (args[i] === "--json") outputMode = "json";
  else if (args[i] === "--score") outputMode = "score";
  else if (args[i] === "--port") port = parseInt(args[i + 1]), i++;
  else if (args[i] === "--url") baseUrl = args[i + 1], skipServer = true, i++;
  else if (args[i] === "--help" || args[i] === "-h") {
    console.log(`Usage: node taste.mjs [project-dir] [--json] [--port 3000] [--url http://...]`);
    console.log(`\nEvaluates product taste by screenshotting every route and judging with Claude vision.`);
    console.log(`\nRequires: ANTHROPIC_API_KEY, playwright (npx playwright install chromium)`);
    process.exit(0);
  }
  else if (!args[i].startsWith("-")) projectDir = args[i];
}

projectDir = resolve(projectDir);

// --- Detect routes ---
function detectRoutes(srcDir) {
  const routes = [];

  // Next.js app router
  function walkDir(dir, prefix = "") {
    if (!existsSync(dir)) return;
    const entries = readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
      if (entry.name.startsWith("_") || entry.name.startsWith(".")) continue;
      if (entry.name === "node_modules" || entry.name === "api") continue;

      const fullPath = join(dir, entry.name);
      if (entry.isDirectory()) {
        // Dynamic routes: [id] → skip for now (need real data)
        if (entry.name.startsWith("[")) continue;
        walkDir(fullPath, `${prefix}/${entry.name}`);
      } else if (entry.name === "page.tsx" || entry.name === "page.jsx" || entry.name === "page.ts") {
        routes.push(prefix || "/");
      }
    }
  }

  // Find app directory
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

  // Always include root
  if (!routes.includes("/")) routes.unshift("/");

  return [...new Set(routes)];
}

// --- Screenshot routes ---
async function screenshotRoutes(browser, url, routes) {
  const screenshots = [];
  const page = await browser.newPage();

  // Set viewport to common sizes
  const viewports = [
    { width: 1440, height: 900, name: "desktop" },
    { width: 390, height: 844, name: "mobile" },
  ];

  for (const route of routes) {
    for (const vp of viewports) {
      await page.setViewportSize({ width: vp.width, height: vp.height });

      try {
        const fullUrl = `${url}${route}`;
        await page.goto(fullUrl, { waitUntil: "networkidle", timeout: 15000 });

        // Wait for content to render
        await page.waitForTimeout(1000);

        const buffer = await page.screenshot({ fullPage: true, type: "png" });
        screenshots.push({
          route,
          viewport: vp.name,
          dimensions: `${vp.width}x${vp.height}`,
          base64: buffer.toString("base64"),
        });
      } catch (err) {
        console.error(`  Failed to screenshot ${route} (${vp.name}): ${err.message}`);
      }
    }
  }

  await page.close();
  return screenshots;
}

// --- Build taste rubric prompt ---
function buildRubricPrompt(routes) {
  return `You are a product taste evaluator. You judge products the way a user EXPERIENCES them, not how they're coded.

You are looking at screenshots of a web application. Score each dimension 1-5 based on what you SEE.

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

5. **EMOTIONAL_TONE** (does it match the product?)
   5 = UI feels like THIS product's personality — recognizable
   3 = Neutral, could be any product
   1 = Mismatch (creative tool looks corporate, social app feels like enterprise)

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
- Compare to products users actually use (Instagram, Discord, Notion, Linear) — that's the bar
- A score of 3 is "fine." 5 means "this specific thing was clearly thought about." 1 means "this actively hurts."
- Be honest. Most AI-generated UIs score 2-3 across the board. That's not failure, it's the starting point.

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
  "weakest": "<which dimension needs most work and why>",
  "one_thing": "<the single highest-impact change to improve taste>"
}

Routes screenshotted: ${routes.join(", ")}
Respond with ONLY the JSON object, no markdown fences.`;
}

// --- Call Claude Vision ---
async function evaluateWithClaude(screenshots, routes) {
  const client = new Anthropic();

  // Build content array with images
  const content = [];

  content.push({
    type: "text",
    text: buildRubricPrompt(routes),
  });

  // Add screenshots (limit to avoid token explosion — max ~20 images)
  const maxScreenshots = 20;
  const selected = screenshots.slice(0, maxScreenshots);

  for (const ss of selected) {
    content.push({
      type: "text",
      text: `\n--- ${ss.route} (${ss.viewport}, ${ss.dimensions}) ---`,
    });
    content.push({
      type: "image",
      source: {
        type: "base64",
        media_type: "image/png",
        data: ss.base64,
      },
    });
  }

  if (screenshots.length > maxScreenshots) {
    content.push({
      type: "text",
      text: `\n(${screenshots.length - maxScreenshots} additional screenshots omitted for context limits)`,
    });
  }

  const response = await client.messages.create({
    model: "claude-sonnet-4-20250514",
    max_tokens: 2000,
    messages: [{ role: "user", content }],
  });

  // Parse JSON response
  const text = response.content[0].text;
  try {
    return JSON.parse(text);
  } catch {
    // Try extracting JSON from markdown fences
    const match = text.match(/\{[\s\S]*\}/);
    if (match) return JSON.parse(match[0]);
    throw new Error(`Failed to parse Claude response as JSON:\n${text}`);
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
    // Try to detect port from dev script
    const portMatch = scripts.dev.match(/-p\s*(\d+)|--port\s*(\d+)|PORT=(\d+)/);
    if (portMatch) detectedPort = parseInt(portMatch[1] || portMatch[2] || portMatch[3]);
  }

  if (port) detectedPort = port;

  console.error(`  Starting dev server on port ${detectedPort}...`);

  const child = spawn("npm", ["run", devCmd], {
    cwd: dir,
    stdio: "pipe",
    env: { ...process.env, PORT: String(detectedPort) },
  });

  // Wait for server to be ready
  const serverUrl = `http://localhost:${detectedPort}`;
  let ready = false;
  let attempts = 0;

  while (!ready && attempts < 30) {
    attempts++;
    try {
      await fetch(serverUrl);
      ready = true;
    } catch {
      await new Promise(r => setTimeout(r, 1000));
    }
  }

  if (!ready) {
    child.kill();
    throw new Error(`Dev server failed to start on port ${detectedPort} after 30s`);
  }

  console.error(`  Dev server ready at ${serverUrl}`);
  return { url: serverUrl, process: child, port: detectedPort };
}

// --- Main ---
async function main() {
  // Check for API key
  if (!process.env.ANTHROPIC_API_KEY) {
    console.error("Error: ANTHROPIC_API_KEY env var required");
    console.error("Set it: export ANTHROPIC_API_KEY=sk-ant-...");
    process.exit(1);
  }

  console.error("=== rhino taste — visual product evaluation ===\n");

  // Find source dir for route detection
  let srcDir = projectDir;
  if (existsSync(join(projectDir, "apps/web/src"))) srcDir = join(projectDir, "apps/web/src");
  else if (existsSync(join(projectDir, "src"))) srcDir = join(projectDir, "src");

  // Detect routes
  const routes = detectRoutes(srcDir);
  console.error(`  Found ${routes.length} routes: ${routes.join(", ")}`);

  // Start or connect to dev server
  let server = null;
  let url = baseUrl;

  if (!url) {
    server = await startDevServer(projectDir);
    url = server.url;
  }

  try {
    // Launch Playwright
    console.error("  Launching browser...");
    const browser = await chromium.launch({ headless: true });

    // Screenshot all routes
    console.error("  Screenshotting routes...");
    const screenshots = await screenshotRoutes(browser, url, routes);
    console.error(`  Captured ${screenshots.length} screenshots`);

    await browser.close();

    // Evaluate with Claude vision
    console.error("  Evaluating with Claude vision...\n");
    const result = await evaluateWithClaude(screenshots, routes);

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
    const reportDir = join(projectDir, ".claude", "evals", "reports");
    execSync(`mkdir -p "${reportDir}"`);
    const reportPath = join(reportDir, `taste-${new Date().toISOString().slice(0, 10)}.json`);
    writeFileSync(reportPath, JSON.stringify(result, null, 2));
    console.error(`  Report saved: ${reportPath}\n`);

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
