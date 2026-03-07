import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import * as fs from "fs";
import * as path from "path";
import * as os from "os";

const CLAUDE_DIR = path.join(os.homedir(), ".claude");
const STATE_DIR = path.join(CLAUDE_DIR, "state");
const KNOWLEDGE_DIR = path.join(CLAUDE_DIR, "knowledge");
const LOG_DIR = path.join(CLAUDE_DIR, "logs");
const PORTFOLIO_FILE = path.join(KNOWLEDGE_DIR, "portfolio.json");
const LANDSCAPE_FILE = path.join(KNOWLEDGE_DIR, "landscape.json");
const TASTE_FILE = path.join(KNOWLEDGE_DIR, "taste.jsonl");
const EDIT_PATTERNS_FILE = path.join(LOG_DIR, "edit-patterns.jsonl");

// Ensure dirs exist
for (const dir of [STATE_DIR, KNOWLEDGE_DIR, LOG_DIR]) {
  fs.mkdirSync(dir, { recursive: true });
}

// --- Portfolio types ---
interface Project {
  name: string;
  path?: string;
  stage: "idea" | "building" | "pre-launch" | "launched" | "growing" | "paused" | "killed";
  one_liner: string;
  target_user: string;
  core_loop: { complete: boolean; missing?: string };
  users: number;
  revenue_monthly: number;
  last_commit?: string;
  velocity_2wk?: number;
  features: Feature[];
  kill_criteria: KillCheck[];
  moat: string;
  updated: string;
}

interface Feature {
  name: string;
  status: "shipped" | "building" | "planned" | "killed";
  value_mechanism?: string;
  user_signal?: string;
}

interface KillCheck {
  condition: string;
  triggered: boolean;
  checked: string;
}

interface Portfolio {
  projects: Project[];
  last_review: string;
  focus: { primary: string; secondary?: string; kill?: string[] };
}

interface LandscapePosition {
  id?: string;
  position: string;
  confidence: "strong" | "moderate" | "weak";
  evidence: string[];
  implications: string;
  updated: string;
}

interface Landscape {
  positions: LandscapePosition[];
  updated: string;
}

function loadPortfolio(): Portfolio {
  if (fs.existsSync(PORTFOLIO_FILE)) {
    return JSON.parse(fs.readFileSync(PORTFOLIO_FILE, "utf-8"));
  }
  return { projects: [], last_review: "", focus: { primary: "" } };
}

function savePortfolio(p: Portfolio) {
  fs.writeFileSync(PORTFOLIO_FILE, JSON.stringify(p, null, 2), "utf-8");
}

function loadLandscape(): Landscape {
  if (fs.existsSync(LANDSCAPE_FILE)) {
    return JSON.parse(fs.readFileSync(LANDSCAPE_FILE, "utf-8"));
  }
  return { positions: [], updated: "" };
}

function saveLandscape(l: Landscape) {
  fs.writeFileSync(LANDSCAPE_FILE, JSON.stringify(l, null, 2), "utf-8");
}

const server = new Server(
  { name: "rhino-state", version: "1.0.0" },
  { capabilities: { tools: {} } }
);

// --- Tool definitions ---

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "rhino_get_state",
      description:
        "Read inter-agent state files from ~/.claude/state/. Returns file contents with optional filtering by filename pattern.",
      inputSchema: {
        type: "object" as const,
        properties: {
          filename: {
            type: "string",
            description:
              'Specific state file to read (e.g., "sweep-latest.md"). If omitted, lists all state files.',
          },
        },
      },
    },
    {
      name: "rhino_set_state",
      description:
        "Write inter-agent state to ~/.claude/state/. Used by agents to share findings with other agents.",
      inputSchema: {
        type: "object" as const,
        properties: {
          filename: {
            type: "string",
            description: 'State file name (e.g., "sweep-latest.md")',
          },
          content: {
            type: "string",
            description: "Full content to write to the state file",
          },
        },
        required: ["filename", "content"],
      },
    },
    {
      name: "rhino_query_knowledge",
      description:
        "Query knowledge files from ~/.claude/knowledge/. Supports filtering by agent name and confidence level.",
      inputSchema: {
        type: "object" as const,
        properties: {
          agent: {
            type: "string",
            description:
              'Agent name (e.g., "scout", "design-engineer"). If omitted, queries all agents.',
          },
          file: {
            type: "string",
            description:
              'Specific file to read (e.g., "knowledge.md", "search-strategy.md"). Defaults to "knowledge.md".',
          },
          confidence: {
            type: "string",
            description:
              'Filter by confidence level: "confirmed", "strong", "weak". Only applies to knowledge.md.',
          },
        },
      },
    },
    {
      name: "rhino_update_knowledge",
      description:
        "Append to or update a knowledge file. For .md files, appends content. For .jsonl files, appends a JSON line.",
      inputSchema: {
        type: "object" as const,
        properties: {
          agent: {
            type: "string",
            description: 'Agent name (e.g., "scout", "design-engineer")',
          },
          file: {
            type: "string",
            description:
              'File to update (e.g., "knowledge.md", "eval-history.jsonl")',
          },
          content: {
            type: "string",
            description:
              "Content to append. For .jsonl files, should be a valid JSON string.",
          },
          mode: {
            type: "string",
            description:
              '"append" (default) adds to end. "replace" overwrites the file.',
            enum: ["append", "replace"],
          },
        },
        required: ["agent", "file", "content"],
      },
    },
    {
      name: "rhino_log_session",
      description:
        "Log session metadata (agent, cost, duration) to ~/.claude/logs/sessions.jsonl.",
      inputSchema: {
        type: "object" as const,
        properties: {
          agent: {
            type: "string",
            description: "Agent name that ran",
          },
          duration_seconds: {
            type: "number",
            description: "Session duration in seconds",
          },
          cost_usd: {
            type: "number",
            description: "Estimated cost in USD",
          },
          summary: {
            type: "string",
            description: "Brief summary of what the session accomplished",
          },
        },
        required: ["agent"],
      },
    },
    {
      name: "rhino_get_usage",
      description:
        "Query usage stats from ~/.claude/logs/usage.jsonl. Returns tool call counts and session history.",
      inputSchema: {
        type: "object" as const,
        properties: {
          period: {
            type: "string",
            description:
              '"today", "week", "month", or "all". Defaults to "today".',
            enum: ["today", "week", "month", "all"],
          },
          group_by: {
            type: "string",
            description: '"tool" or "agent". Defaults to "tool".',
            enum: ["tool", "agent"],
          },
        },
      },
    },
    {
      name: "rhino_backup_knowledge",
      description:
        "Create a timestamped snapshot of all knowledge files to ~/.claude/backups/.",
      inputSchema: {
        type: "object" as const,
        properties: {},
      },
    },
    {
      name: "rhino_portfolio",
      description:
        "Read, update, or evaluate the project portfolio. Returns structured data about all projects, their stages, features, kill criteria, and focus recommendations. Use 'evaluate' action to run kill criteria checks and get Buy/Sell/Hold verdicts.",
      inputSchema: {
        type: "object" as const,
        properties: {
          action: {
            type: "string",
            description: '"read" returns full portfolio. "update" modifies a project. "evaluate" runs kill criteria and returns verdicts. "add" adds a new project. "remove" removes a project.',
            enum: ["read", "update", "evaluate", "add", "remove"],
          },
          project: {
            type: "string",
            description: "Project name (required for update/add/remove)",
          },
          data: {
            type: "string",
            description: "JSON string of project fields to update or add (for update/add actions)",
          },
        },
        required: ["action"],
      },
    },
    {
      name: "rhino_landscape",
      description:
        "Read or update the 2026 landscape model. Contains opinionated strategic positions (not trends) that agents reason from. Scout updates these; strategist reads them.",
      inputSchema: {
        type: "object" as const,
        properties: {
          action: {
            type: "string",
            description: '"read" returns all positions. "add" adds a position. "update" modifies a position. "remove" removes a position.',
            enum: ["read", "add", "update", "remove"],
          },
          position: {
            type: "string",
            description: "The position statement (used as identifier for update/remove)",
          },
          data: {
            type: "string",
            description: 'JSON string with fields: confidence ("strong"/"moderate"/"weak"), evidence (string[]), implications (string)',
          },
        },
        required: ["action"],
      },
    },
    {
      name: "rhino_taste",
      description:
        "Record, query, or export taste signals. Taste entries are observations about the founder's preferences learned from their decisions — what they accept, reject, change, or consistently choose. Agents write here when they observe a preference pattern. Strategist and other agents read to align with founder's judgment.",
      inputSchema: {
        type: "object" as const,
        properties: {
          action: {
            type: "string",
            description: '"read" returns all taste entries. "record" adds a new observation. "query" filters by domain. "export" returns a portable taste profile.',
            enum: ["read", "record", "query", "export"],
          },
          domain: {
            type: "string",
            description: 'Category: "product", "design", "strategy", "technical", "communication". Used for record and query.',
          },
          signal: {
            type: "string",
            description: 'The observed preference (for record). e.g., "Prefers dense data layouts over whitespace", "Rejects onboarding flows — wants users dropped into value immediately"',
          },
          evidence: {
            type: "string",
            description: "What decision or action this was observed from (for record)",
          },
          strength: {
            type: "string",
            description: '"strong" (seen 3+ times), "moderate" (seen twice), "weak" (seen once). Defaults to "weak".',
            enum: ["strong", "moderate", "weak"],
          },
          landscape_id: {
            type: "string",
            description: "Optional landscape position ID this taste signal aligns with. Links decisions to strategic positions.",
          },
        },
        required: ["action"],
      },
    },
    {
      name: "rhino_agent_context",
      description:
        "Returns a curated context briefing for the current task. Assembles relevant taste signals, edit patterns (auto-extracted from coding behavior), portfolio focus, landscape positions, and last session summary into a single context block. Call this FIRST in any agent session to ground yourself in the founder's preferences and strategic context.",
      inputSchema: {
        type: "object" as const,
        properties: {
          project: {
            type: "string",
            description: "Project name to focus context on. If omitted, returns general context.",
          },
          domain: {
            type: "string",
            description: 'Filter taste signals by domain: "product", "design", "strategy", "technical". If omitted, returns all strong+moderate signals.',
          },
        },
      },
    },
  ],
}));

// --- Tool implementations ---

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  switch (name) {
    case "rhino_get_state": {
      const filename = args?.filename as string | undefined;
      if (filename) {
        const filePath = path.join(STATE_DIR, path.basename(filename));
        if (!fs.existsSync(filePath)) {
          return { content: [{ type: "text", text: `State file '${filename}' not found.` }] };
        }
        const content = fs.readFileSync(filePath, "utf-8");
        return { content: [{ type: "text", text: content }] };
      }
      // List all state files
      const files = fs.readdirSync(STATE_DIR).filter((f) => !f.startsWith("."));
      if (files.length === 0) {
        return { content: [{ type: "text", text: "No state files found." }] };
      }
      const listing = files.map((f) => {
        const stat = fs.statSync(path.join(STATE_DIR, f));
        const ageHours = Math.round((Date.now() - stat.mtimeMs) / 3600000);
        return `- ${f} (${ageHours}h ago, ${stat.size} bytes)`;
      });
      return { content: [{ type: "text", text: listing.join("\n") }] };
    }

    case "rhino_set_state": {
      const filename = args?.filename as string;
      const content = args?.content as string;
      const filePath = path.join(STATE_DIR, path.basename(filename));
      fs.writeFileSync(filePath, content, "utf-8");
      return { content: [{ type: "text", text: `State written to ${filename}` }] };
    }

    case "rhino_query_knowledge": {
      const agent = args?.agent as string | undefined;
      const file = (args?.file as string) || "knowledge.md";
      const confidence = args?.confidence as string | undefined;

      const dirs = agent
        ? [path.join(KNOWLEDGE_DIR, agent)]
        : fs.readdirSync(KNOWLEDGE_DIR)
            .filter((d) => d !== "_template" && fs.statSync(path.join(KNOWLEDGE_DIR, d)).isDirectory())
            .map((d) => path.join(KNOWLEDGE_DIR, d));

      const results: string[] = [];
      for (const dir of dirs) {
        const filePath = path.join(dir, file);
        if (!fs.existsSync(filePath)) continue;
        let content = fs.readFileSync(filePath, "utf-8");
        const agentName = path.basename(dir);

        if (confidence && file === "knowledge.md") {
          // Filter sections by confidence level
          const sections = content.split(/^## /m);
          const filtered = sections.filter((s) =>
            s.toLowerCase().includes(confidence.toLowerCase())
          );
          content = filtered.length > 0 ? filtered.map((s) => `## ${s}`).join("") : `No ${confidence} entries found.`;
        }

        results.push(`--- ${agentName}/${file} ---\n${content}`);
      }

      return {
        content: [{ type: "text", text: results.length > 0 ? results.join("\n\n") : "No knowledge files found." }],
      };
    }

    case "rhino_update_knowledge": {
      const agent = args?.agent as string;
      const file = args?.file as string;
      const content = args?.content as string;
      const mode = (args?.mode as string) || "append";

      const dir = path.join(KNOWLEDGE_DIR, agent);
      fs.mkdirSync(dir, { recursive: true });
      const filePath = path.join(dir, file);

      if (mode === "replace") {
        fs.writeFileSync(filePath, content, "utf-8");
        return { content: [{ type: "text", text: `Replaced ${agent}/${file}` }] };
      }

      // Append
      const separator = file.endsWith(".jsonl") ? "\n" : "\n\n";
      const existing = fs.existsSync(filePath) ? fs.readFileSync(filePath, "utf-8") : "";
      const newContent = existing ? existing.trimEnd() + separator + content + "\n" : content + "\n";
      fs.writeFileSync(filePath, newContent, "utf-8");
      return { content: [{ type: "text", text: `Appended to ${agent}/${file}` }] };
    }

    case "rhino_log_session": {
      const entry = {
        ts: new Date().toISOString(),
        agent: args?.agent,
        duration_seconds: args?.duration_seconds,
        cost_usd: args?.cost_usd,
        summary: args?.summary,
      };
      const filePath = path.join(LOG_DIR, "sessions.jsonl");
      fs.appendFileSync(filePath, JSON.stringify(entry) + "\n", "utf-8");
      return { content: [{ type: "text", text: `Session logged for ${entry.agent}` }] };
    }

    case "rhino_get_usage": {
      const period = (args?.period as string) || "today";
      const groupBy = (args?.group_by as string) || "tool";
      const usagePath = path.join(LOG_DIR, "usage.jsonl");

      if (!fs.existsSync(usagePath)) {
        return { content: [{ type: "text", text: "No usage data found." }] };
      }

      const lines = fs.readFileSync(usagePath, "utf-8").trim().split("\n").filter(Boolean);
      const now = new Date();
      let cutoff: Date;

      switch (period) {
        case "today":
          cutoff = new Date(now.getFullYear(), now.getMonth(), now.getDate());
          break;
        case "week":
          cutoff = new Date(now.getTime() - 7 * 86400000);
          break;
        case "month":
          cutoff = new Date(now.getTime() - 30 * 86400000);
          break;
        default:
          cutoff = new Date(0);
      }

      const counts: Record<string, number> = {};
      let total = 0;

      for (const line of lines) {
        try {
          const entry = JSON.parse(line);
          const ts = new Date(entry.ts);
          if (ts >= cutoff) {
            const key = groupBy === "agent" ? (entry.agent || "unknown") : (entry.tool || "unknown");
            counts[key] = (counts[key] || 0) + 1;
            total++;
          }
        } catch {
          // skip malformed lines
        }
      }

      const sorted = Object.entries(counts)
        .sort((a, b) => b[1] - a[1])
        .map(([k, v]) => `  ${k}: ${v}`)
        .join("\n");

      return {
        content: [{ type: "text", text: `Usage (${period}, by ${groupBy}):\nTotal: ${total}\n${sorted}` }],
      };
    }

    case "rhino_backup_knowledge": {
      const timestamp = new Date().toISOString().replace(/[:.]/g, "-").slice(0, 19);
      const backupDir = path.join(CLAUDE_DIR, "backups", `knowledge-${timestamp}`);
      fs.mkdirSync(backupDir, { recursive: true });

      // Copy knowledge directory
      const copyDir = (src: string, dest: string) => {
        fs.mkdirSync(dest, { recursive: true });
        for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
          const srcPath = path.join(src, entry.name);
          const destPath = path.join(dest, entry.name);
          if (entry.isDirectory()) {
            copyDir(srcPath, destPath);
          } else {
            fs.copyFileSync(srcPath, destPath);
          }
        }
      };

      if (fs.existsSync(KNOWLEDGE_DIR)) {
        copyDir(KNOWLEDGE_DIR, backupDir);
      }

      // Count files
      let fileCount = 0;
      const countFiles = (dir: string) => {
        for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
          if (entry.isDirectory()) countFiles(path.join(dir, entry.name));
          else fileCount++;
        }
      };
      countFiles(backupDir);

      return {
        content: [{ type: "text", text: `Knowledge backed up to ${backupDir} (${fileCount} files)` }],
      };
    }

    case "rhino_portfolio": {
      const action = args?.action as string;
      const projectName = args?.project as string | undefined;
      const data = args?.data as string | undefined;
      const portfolio = loadPortfolio();

      switch (action) {
        case "read": {
          if (portfolio.projects.length === 0) {
            return { content: [{ type: "text", text: "Portfolio is empty. Use action 'add' to add projects." }] };
          }
          return { content: [{ type: "text", text: JSON.stringify(portfolio, null, 2) }] };
        }
        case "add": {
          if (!projectName || !data) {
            return { content: [{ type: "text", text: "Both 'project' and 'data' required for add." }], isError: true };
          }
          const newProject: Project = {
            name: projectName,
            stage: "idea",
            one_liner: "",
            target_user: "",
            core_loop: { complete: false },
            users: 0,
            revenue_monthly: 0,
            features: [],
            kill_criteria: [
              { condition: "No real user need in 30 days", triggered: false, checked: "" },
              { condition: "Can't name one person who'd pay", triggered: false, checked: "" },
              { condition: "Core loop incomplete for >2 months", triggered: false, checked: "" },
            ],
            moat: "none",
            updated: new Date().toISOString(),
            ...JSON.parse(data),
            name: projectName,
          };
          portfolio.projects.push(newProject);
          savePortfolio(portfolio);
          return { content: [{ type: "text", text: `Added project: ${projectName}` }] };
        }
        case "update": {
          if (!projectName) {
            return { content: [{ type: "text", text: "'project' required for update." }], isError: true };
          }
          const idx = portfolio.projects.findIndex(p => p.name === projectName);
          if (idx === -1) {
            return { content: [{ type: "text", text: `Project '${projectName}' not found.` }], isError: true };
          }
          if (data) {
            const updates = JSON.parse(data);
            portfolio.projects[idx] = { ...portfolio.projects[idx], ...updates, name: projectName, updated: new Date().toISOString() };
          }
          savePortfolio(portfolio);
          return { content: [{ type: "text", text: `Updated project: ${projectName}` }] };
        }
        case "remove": {
          if (!projectName) {
            return { content: [{ type: "text", text: "'project' required for remove." }], isError: true };
          }
          portfolio.projects = portfolio.projects.filter(p => p.name !== projectName);
          savePortfolio(portfolio);
          return { content: [{ type: "text", text: `Removed project: ${projectName}` }] };
        }
        case "evaluate": {
          const verdicts: string[] = [];
          const now = new Date();

          for (const project of portfolio.projects) {
            const signals: string[] = [];
            let verdict: "BUY" | "HOLD" | "SELL" = "HOLD";

            // Check kill criteria
            for (const kc of project.kill_criteria) {
              if (kc.triggered) {
                signals.push(`KILL TRIGGER: ${kc.condition}`);
              }
            }

            // Evaluate stage-specific signals
            if (project.stage === "idea" || project.stage === "building") {
              if (project.users === 0 && project.core_loop.complete === false) {
                signals.push("Pre-launch, core loop incomplete");
              }
              if (project.core_loop.missing) {
                signals.push(`Missing: ${project.core_loop.missing}`);
              }
            }

            if (project.users === 0 && ["launched", "growing"].includes(project.stage)) {
              signals.push("WARN: Launched but zero users");
            }

            if (project.moat === "none") {
              signals.push("No moat identified — commoditizable");
            }

            // Derive verdict
            const killTriggered = project.kill_criteria.some(kc => kc.triggered);
            if (killTriggered || project.stage === "killed") {
              verdict = "SELL";
            } else if (project.users > 0 && project.core_loop.complete) {
              verdict = "BUY";
            } else if (project.stage === "paused") {
              verdict = "SELL";
            }

            // Feature health
            const shippedFeatures = project.features.filter(f => f.status === "shipped").length;
            const buildingFeatures = project.features.filter(f => f.status === "building").length;
            const killedFeatures = project.features.filter(f => f.status === "killed").length;

            verdicts.push(
              `## ${project.name} → ${verdict}\n` +
              `Stage: ${project.stage} | Users: ${project.users} | MRR: $${project.revenue_monthly}\n` +
              `Core loop: ${project.core_loop.complete ? "complete" : "INCOMPLETE"}\n` +
              `Features: ${shippedFeatures} shipped, ${buildingFeatures} building, ${killedFeatures} killed\n` +
              `Moat: ${project.moat}\n` +
              `Signals:\n${signals.map(s => `  - ${s}`).join("\n") || "  (none)"}`
            );
          }

          // Focus recommendation
          const buyProjects = portfolio.projects.filter(p => !p.kill_criteria.some(k => k.triggered) && p.stage !== "killed" && p.stage !== "paused");
          const focusRec = buyProjects.length > 2
            ? `\nFOCUS WARNING: ${buyProjects.length} active projects. 1 project at 100% = escape velocity. ${buyProjects.length} at ${Math.round(100/buyProjects.length)}% = none escape.`
            : "";

          portfolio.last_review = now.toISOString();
          savePortfolio(portfolio);

          return { content: [{ type: "text", text: verdicts.join("\n\n") + focusRec }] };
        }
        default:
          return { content: [{ type: "text", text: `Unknown portfolio action: ${action}` }], isError: true };
      }
    }

    case "rhino_landscape": {
      const action = args?.action as string;
      const positionText = args?.position as string | undefined;
      const data = args?.data as string | undefined;
      const landscape = loadLandscape();

      switch (action) {
        case "read": {
          if (landscape.positions.length === 0) {
            return { content: [{ type: "text", text: "Landscape is empty. Use action 'add' to add positions." }] };
          }
          const output = landscape.positions.map(p =>
            `[${p.confidence.toUpperCase()}] ${p.position}\n` +
            `  Implications: ${p.implications}\n` +
            `  Evidence: ${p.evidence.join("; ")}\n` +
            `  Updated: ${p.updated}`
          ).join("\n\n");
          return { content: [{ type: "text", text: output }] };
        }
        case "add": {
          if (!positionText) {
            return { content: [{ type: "text", text: "'position' required." }], isError: true };
          }
          const parsed = data ? JSON.parse(data) : {};
          const id = positionText.toLowerCase().replace(/[^a-z0-9]+/g, '-').slice(0, 40);
          const newPos: LandscapePosition = {
            id,
            position: positionText,
            confidence: parsed.confidence || "weak",
            evidence: parsed.evidence || [],
            implications: parsed.implications || "",
            updated: new Date().toISOString(),
          };
          landscape.positions.push(newPos);
          landscape.updated = new Date().toISOString();
          saveLandscape(landscape);
          return { content: [{ type: "text", text: `Position added (id: ${id}): ${positionText}` }] };
        }
        case "update": {
          if (!positionText) {
            return { content: [{ type: "text", text: "'position' required." }], isError: true };
          }
          const searchText = positionText.toLowerCase();
          const idx = landscape.positions.findIndex(p =>
            p.id === searchText ||
            p.position === positionText ||
            p.position.toLowerCase().includes(searchText)
          );
          if (idx === -1) {
            return { content: [{ type: "text", text: `Position not found: ${positionText}` }], isError: true };
          }
          if (data) {
            const updates = JSON.parse(data);
            landscape.positions[idx] = { ...landscape.positions[idx], ...updates, updated: new Date().toISOString() };
          }
          landscape.updated = new Date().toISOString();
          saveLandscape(landscape);
          return { content: [{ type: "text", text: `Position updated: ${landscape.positions[idx].position}` }] };
        }
        case "remove": {
          if (!positionText) {
            return { content: [{ type: "text", text: "'position' required." }], isError: true };
          }
          const rmText = positionText.toLowerCase();
          landscape.positions = landscape.positions.filter(p =>
            p.id !== rmText &&
            p.position !== positionText &&
            !p.position.toLowerCase().includes(rmText)
          );
          landscape.updated = new Date().toISOString();
          saveLandscape(landscape);
          return { content: [{ type: "text", text: `Position removed: ${positionText}` }] };
        }
        default:
          return { content: [{ type: "text", text: `Unknown landscape action: ${action}` }], isError: true };
      }
    }

    case "rhino_taste": {
      const action = args?.action as string;
      const domain = args?.domain as string | undefined;
      const signal = args?.signal as string | undefined;
      const evidence = args?.evidence as string | undefined;
      const strength = (args?.strength as string) || "weak";
      const landscapeId = args?.landscape_id as string | undefined;

      switch (action) {
        case "record": {
          if (!signal || !domain) {
            return { content: [{ type: "text", text: "'signal' and 'domain' required for record." }], isError: true };
          }

          // Deduplication: check for existing similar signal in same domain
          if (fs.existsSync(TASTE_FILE)) {
            const existingLines = fs.readFileSync(TASTE_FILE, "utf-8").trim().split("\n").filter(Boolean);
            const signalLower = signal.toLowerCase();
            const entries = existingLines.map(l => { try { return JSON.parse(l); } catch { return null; } }).filter(Boolean);
            const matchIdx = entries.findIndex((e: { domain: string; signal: string }) =>
              e.domain === domain && (
                e.signal.toLowerCase() === signalLower ||
                e.signal.toLowerCase().includes(signalLower) ||
                signalLower.includes(e.signal.toLowerCase())
              )
            );

            if (matchIdx !== -1) {
              // Promote strength: weak→moderate→strong
              const existing = entries[matchIdx];
              const strengthOrder = ["weak", "moderate", "strong"];
              const currentIdx = strengthOrder.indexOf(existing.strength || "weak");
              const newStrength = strengthOrder[Math.min(currentIdx + 1, 2)];
              existing.strength = newStrength;
              existing.ts = new Date().toISOString();
              if (evidence) existing.evidence = evidence;
              if (landscapeId) existing.landscape_id = landscapeId;

              // Rewrite file with updated entry
              const updatedLines = entries.map((e: object) => JSON.stringify(e)).join("\n") + "\n";
              fs.writeFileSync(TASTE_FILE, updatedLines, "utf-8");
              return { content: [{ type: "text", text: `Taste deduplicated: [${domain}] ${signal} (strength promoted to ${newStrength})` }] };
            }
          }

          const entry: Record<string, string> = {
            ts: new Date().toISOString(),
            domain,
            signal,
            evidence: evidence || "",
            strength,
          };
          if (landscapeId) entry.landscape_id = landscapeId;
          fs.appendFileSync(TASTE_FILE, JSON.stringify(entry) + "\n", "utf-8");
          return { content: [{ type: "text", text: `Taste recorded: [${domain}] ${signal}${landscapeId ? ` (linked to: ${landscapeId})` : ""}` }] };
        }
        case "read": {
          if (!fs.existsSync(TASTE_FILE)) {
            return { content: [{ type: "text", text: "No taste signals recorded yet." }] };
          }
          const lines = fs.readFileSync(TASTE_FILE, "utf-8").trim().split("\n").filter(Boolean);
          const entries = lines.map(l => { try { return JSON.parse(l); } catch { return null; } }).filter(Boolean);

          // Group by domain
          const byDomain: Record<string, typeof entries> = {};
          for (const e of entries) {
            byDomain[e.domain] = byDomain[e.domain] || [];
            byDomain[e.domain].push(e);
          }

          const output = Object.entries(byDomain).map(([d, items]) =>
            `## ${d}\n` + items.map((i: { strength: string; signal: string; evidence: string }) =>
              `  [${i.strength}] ${i.signal}${i.evidence ? ` (from: ${i.evidence})` : ""}`
            ).join("\n")
          ).join("\n\n");

          return { content: [{ type: "text", text: output || "No taste signals recorded yet." }] };
        }
        case "query": {
          if (!domain) {
            return { content: [{ type: "text", text: "'domain' required for query." }], isError: true };
          }
          if (!fs.existsSync(TASTE_FILE)) {
            return { content: [{ type: "text", text: `No taste signals for domain '${domain}'.` }] };
          }
          const lines = fs.readFileSync(TASTE_FILE, "utf-8").trim().split("\n").filter(Boolean);
          const filtered = lines
            .map(l => { try { return JSON.parse(l); } catch { return null; } })
            .filter((e: { domain?: string } | null) => e && e.domain === domain);

          if (filtered.length === 0) {
            return { content: [{ type: "text", text: `No taste signals for domain '${domain}'.` }] };
          }

          const output = filtered.map((i: { strength: string; signal: string; evidence: string }) =>
            `[${i.strength}] ${i.signal}${i.evidence ? ` (from: ${i.evidence})` : ""}`
          ).join("\n");
          return { content: [{ type: "text", text: `## ${domain}\n${output}` }] };
        }
        case "export": {
          if (!fs.existsSync(TASTE_FILE)) {
            return { content: [{ type: "text", text: "No taste signals to export." }] };
          }
          const lines = fs.readFileSync(TASTE_FILE, "utf-8").trim().split("\n").filter(Boolean);
          const entries = lines.map(l => { try { return JSON.parse(l); } catch { return null; } }).filter(Boolean);

          // Build portable taste profile
          const profile: Record<string, { signals: Array<{ signal: string; strength: string; evidence: string; landscape_id?: string }> }> = {};
          for (const e of entries) {
            if (!profile[e.domain]) profile[e.domain] = { signals: [] };
            profile[e.domain].signals.push({
              signal: e.signal,
              strength: e.strength,
              evidence: e.evidence,
              ...(e.landscape_id ? { landscape_id: e.landscape_id } : {}),
            });
          }

          // Add edit pattern analysis if available
          let editProfile: Record<string, number> | null = null;
          if (fs.existsSync(EDIT_PATTERNS_FILE)) {
            const patternLines = fs.readFileSync(EDIT_PATTERNS_FILE, "utf-8").trim().split("\n").filter(Boolean);
            const tallies: Record<string, number> = {};
            for (const pl of patternLines) {
              try {
                const pe = JSON.parse(pl);
                for (const p of (pe.patterns || [])) {
                  tallies[p] = (tallies[p] || 0) + 1;
                }
              } catch { /* skip */ }
            }
            if (Object.keys(tallies).length > 0) editProfile = tallies;
          }

          const exportData = {
            version: "1.0",
            exported: new Date().toISOString(),
            taste_signals: profile,
            ...(editProfile ? { edit_patterns: editProfile } : {}),
          };

          return { content: [{ type: "text", text: JSON.stringify(exportData, null, 2) }] };
        }
        default:
          return { content: [{ type: "text", text: `Unknown taste action: ${action}` }], isError: true };
      }
    }

    case "rhino_agent_context": {
      const project = args?.project as string | undefined;
      const ctxDomain = args?.domain as string | undefined;
      const sections: string[] = [];

      // 1. Taste signals (strong + moderate, filtered by domain if provided)
      if (fs.existsSync(TASTE_FILE)) {
        const lines = fs.readFileSync(TASTE_FILE, "utf-8").trim().split("\n").filter(Boolean);
        const entries = lines.map(l => { try { return JSON.parse(l); } catch { return null; } }).filter(Boolean);
        const relevant = entries.filter((e: { strength: string; domain: string }) => {
          if (ctxDomain && e.domain !== ctxDomain) return false;
          return e.strength === "strong" || e.strength === "moderate";
        });
        if (relevant.length > 0) {
          const tasteLines = relevant.map((e: { strength: string; domain: string; signal: string; landscape_id?: string }) =>
            `  [${e.strength}/${e.domain}] ${e.signal}${e.landscape_id ? ` (linked: ${e.landscape_id})` : ""}`
          );
          sections.push(`## Taste Profile\nFounder preferences (observed from decisions):\n${tasteLines.join("\n")}`);
        }
      }

      // 2. Edit pattern analysis (behavioral, auto-extracted)
      if (fs.existsSync(EDIT_PATTERNS_FILE)) {
        const patternLines = fs.readFileSync(EDIT_PATTERNS_FILE, "utf-8").trim().split("\n").filter(Boolean);

        // Filter by project if specified
        const relevant = project
          ? patternLines.filter(l => { try { return JSON.parse(l).project === project; } catch { return false; } })
          : patternLines;

        // Only analyze last 7 days
        const weekAgo = new Date(Date.now() - 7 * 86400000).toISOString();
        const recent = relevant.filter(l => {
          try { return JSON.parse(l).ts >= weekAgo; } catch { return false; }
        });

        if (recent.length > 0) {
          const tallies: Record<string, number> = {};
          for (const pl of recent) {
            try {
              const pe = JSON.parse(pl);
              for (const p of (pe.patterns || [])) {
                tallies[p] = (tallies[p] || 0) + 1;
              }
            } catch { /* skip */ }
          }

          // Derive human-readable preferences from tallies
          const prefs: string[] = [];
          if ((tallies.naming_camel || 0) > (tallies.naming_snake || 0) * 2) prefs.push("Strongly prefers camelCase naming");
          else if ((tallies.naming_snake || 0) > (tallies.naming_camel || 0) * 2) prefs.push("Strongly prefers snake_case naming");

          if ((tallies.quotes_single || 0) > (tallies.quotes_double || 0) * 2) prefs.push("Uses single quotes");
          else if ((tallies.quotes_double || 0) > (tallies.quotes_single || 0) * 2) prefs.push("Uses double quotes");

          if ((tallies.semicolons_removed || 0) > (tallies.semicolons_added || 0)) prefs.push("Removes semicolons (no-semi style)");
          else if ((tallies.semicolons_added || 0) > (tallies.semicolons_removed || 0)) prefs.push("Adds semicolons consistently");

          if ((tallies.comments_removed || 0) > (tallies.comments_added || 0) * 2) prefs.push("Tends to remove comments — prefers self-documenting code");
          else if ((tallies.comments_added || 0) > (tallies.comments_removed || 0) * 2) prefs.push("Adds comments actively");

          if ((tallies.decl_const || 0) > (tallies.decl_let || 0) * 3) prefs.push("Strong const preference over let");
          if ((tallies.fn_arrow || 0) > (tallies.fn_keyword || 0) * 2) prefs.push("Prefers arrow functions");
          else if ((tallies.fn_keyword || 0) > (tallies.fn_arrow || 0) * 2) prefs.push("Prefers function keyword");

          if ((tallies.error_early_return || 0) > (tallies.error_try_catch || 0)) prefs.push("Prefers early return over try/catch");
          if ((tallies.import_esm || 0) > (tallies.import_cjs || 0) * 2) prefs.push("Uses ES module imports");
          else if ((tallies.import_cjs || 0) > (tallies.import_esm || 0) * 2) prefs.push("Uses CommonJS require");

          if ((tallies.code_deletion || 0) > (tallies.code_expansion || 0)) prefs.push("Tends to reduce code — values conciseness");

          if ((tallies.indent_tabs || 0) > (tallies.indent_2space || 0) + (tallies.indent_4space || 0)) prefs.push("Uses tabs for indentation");
          else if ((tallies.indent_2space || 0) > (tallies.indent_4space || 0)) prefs.push("Uses 2-space indentation");
          else if ((tallies.indent_4space || 0) > (tallies.indent_2space || 0)) prefs.push("Uses 4-space indentation");

          if (prefs.length > 0) {
            sections.push(`## Coding Style (auto-extracted from ${recent.length} edits, last 7d)\n${prefs.map(p => `  - ${p}`).join("\n")}`);
          }
        }
      }

      // 3. Portfolio focus
      const portfolio = loadPortfolio();
      if (portfolio.focus.primary) {
        let focusSection = `## Portfolio Focus\nPrimary: ${portfolio.focus.primary}`;
        if (portfolio.focus.secondary) focusSection += `\nSecondary: ${portfolio.focus.secondary}`;
        if (portfolio.focus.kill && portfolio.focus.kill.length > 0) focusSection += `\nKill list: ${portfolio.focus.kill.join(", ")}`;

        // If project specified, show its status
        if (project) {
          const proj = portfolio.projects.find(p => p.name === project);
          if (proj) {
            focusSection += `\n\n${project}: ${proj.stage} | ${proj.users} users | Core loop: ${proj.core_loop.complete ? "complete" : "INCOMPLETE"}`;
          }
        }
        sections.push(focusSection);
      }

      // 4. Relevant landscape positions
      const landscape = loadLandscape();
      if (landscape.positions.length > 0) {
        const strongPositions = landscape.positions
          .filter(p => p.confidence === "strong")
          .map(p => `  [${p.id || "?"}] ${p.position}`);
        if (strongPositions.length > 0) {
          sections.push(`## Landscape (strong positions)\n${strongPositions.join("\n")}`);
        }
      }

      // 5. Drift detection (if project specified)
      if (project) {
        const usagePath = path.join(LOG_DIR, "usage.jsonl");
        if (fs.existsSync(usagePath)) {
          const weekAgo = new Date(Date.now() - 7 * 86400000).toISOString();
          const usageLines = fs.readFileSync(usagePath, "utf-8").trim().split("\n").filter(Boolean);
          const projectCounts: Record<string, number> = {};
          let totalEdits = 0;
          for (const ul of usageLines) {
            try {
              const ue = JSON.parse(ul);
              if (ue.ts >= weekAgo && (ue.tool === "Edit" || ue.tool === "Write") && ue.project) {
                projectCounts[ue.project] = (projectCounts[ue.project] || 0) + 1;
                totalEdits++;
              }
            } catch { /* skip */ }
          }
          if (totalEdits > 0) {
            const projectEdits = projectCounts[project] || 0;
            const projectPct = Math.round((projectEdits / totalEdits) * 100);
            const otherProjects = Object.entries(projectCounts)
              .filter(([p]) => p !== project)
              .sort((a, b) => b[1] - a[1])
              .slice(0, 3)
              .map(([p, c]) => `${p}: ${Math.round((c / totalEdits) * 100)}%`);

            let driftNote = `## Focus Allocation (last 7d)\n  ${project}: ${projectPct}% of edits`;
            if (otherProjects.length > 0) driftNote += `\n  Other: ${otherProjects.join(", ")}`;
            if (portfolio.focus.primary === project && projectPct < 50) {
              driftNote += `\n  DRIFT WARNING: ${project} is your stated primary but only ${projectPct}% of actual work`;
            }
            sections.push(driftNote);
          }
        }
      }

      // 6. Last session context
      if (project) {
        const sessionFile = path.join(KNOWLEDGE_DIR, "sessions", `${project}.md`);
        if (fs.existsSync(sessionFile)) {
          const sessionContent = fs.readFileSync(sessionFile, "utf-8");
          // Get last entry
          const entries = sessionContent.split(/^## /m).filter(Boolean);
          if (entries.length > 0) {
            const lastEntry = entries[entries.length - 1].trim();
            const truncated = lastEntry.split("\n").slice(0, 10).join("\n");
            sections.push(`## Last Session\n## ${truncated}`);
          }
        }
      }

      if (sections.length === 0) {
        return { content: [{ type: "text", text: "No context available yet. Use rhino-os for a few sessions to build up taste signals and edit patterns." }] };
      }

      return { content: [{ type: "text", text: sections.join("\n\n") }] };
    }

    default:
      return { content: [{ type: "text", text: `Unknown tool: ${name}` }], isError: true };
  }
});

// --- Start server ---

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((err) => {
  console.error("rhino-state MCP server error:", err);
  process.exit(1);
});
