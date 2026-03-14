#!/usr/bin/env node
// serve.mjs — HTTP adapter for rhino-os
// Exposes rhino CLI commands over HTTP for multi-channel access.
// Local-only by default (127.0.0.1).

import { createServer } from 'node:http';
import { execSync } from 'node:child_process';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const RHINO_BIN = resolve(__dirname, 'rhino');
const PORT = parseInt(process.env.RHINO_PORT || '7100', 10);
const HOST = '127.0.0.1';

const ALLOWED_COMMANDS = new Set(['score', 'eval', 'status', 'feature', 'self', 'config', 'skill']);

function runRhino(cmd, args = []) {
    const fullCmd = [RHINO_BIN, cmd, ...args].map(a => `'${a.replace(/'/g, "'\\''")}'`).join(' ');
    try {
        const output = execSync(fullCmd, {
            timeout: 120_000,
            encoding: 'utf-8',
            env: { ...process.env, NO_COLOR: '1' },
        });
        return { ok: true, output: output.trim() };
    } catch (err) {
        return { ok: false, output: (err.stdout || err.message || '').trim() };
    }
}

const server = createServer((req, res) => {
    // CORS headers for local dev
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
        res.writeHead(204);
        res.end();
        return;
    }

    if (req.method !== 'POST') {
        res.writeHead(405, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ ok: false, output: 'Method not allowed. Use POST.' }));
        return;
    }

    // Parse command from URL path: POST /score → rhino score
    const cmd = req.url.replace(/^\//, '').split('?')[0];

    if (!cmd || !ALLOWED_COMMANDS.has(cmd)) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
            ok: false,
            output: `Unknown command: ${cmd}. Allowed: ${[...ALLOWED_COMMANDS].join(', ')}`,
        }));
        return;
    }

    // Read body for optional args
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
        let args = [];
        if (body) {
            try {
                const parsed = JSON.parse(body);
                if (Array.isArray(parsed.args)) {
                    args = parsed.args.map(String);
                } else if (typeof parsed.args === 'string') {
                    args = parsed.args.split(/\s+/).filter(Boolean);
                }
            } catch {
                // Ignore parse errors, run with no args
            }
        }

        const result = runRhino(cmd, args);
        res.writeHead(result.ok ? 200 : 500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(result));
    });
});

server.listen(PORT, HOST, () => {
    console.log(`rhino serve listening on http://${HOST}:${PORT}`);
    console.log(`Endpoints: ${[...ALLOWED_COMMANDS].map(c => `POST /${c}`).join(', ')}`);
});
