#!/usr/bin/env node
// Injects custom.css into Slack's webapp via the Chrome DevTools Protocol.
// Requires Node 22+ (built-in fetch + WebSocket). No npm dependencies.
//
// Slack must be running with --remote-debugging-port=<PORT> (see slack-css.sh).
//
// Waits for the debug port, attaches to each Slack page, injects the CSS,
// then sits idle on the open socket so it can re-inject after a page reload.
// Exits when Slack quits (the sockets close); slack-css.sh handles relaunch.

import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

if (typeof WebSocket === "undefined") {
  console.error("Node 22 or newer is required (no global WebSocket).");
  process.exit(1);
}

const PORT = process.env.SLACK_DEBUG_PORT || 9222;
const STYLE_ID = "hide-tab-rail-slackbot";
const CSS = readFileSync(join(dirname(fileURLToPath(import.meta.url)), "custom.css"), "utf8");

// Runs inside the page. Idempotent.
const INJECT_EXPR = `(() => {
  let el = document.getElementById(${JSON.stringify(STYLE_ID)});
  if (!el) {
    el = document.createElement("style");
    el.id = ${JSON.stringify(STYLE_ID)};
    (document.head || document.documentElement).appendChild(el);
  }
  el.textContent = ${JSON.stringify(CSS)};
})()`;

const log = (...a) => console.log(new Date().toISOString(), ...a);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function listSlackPages() {
  try {
    const targets = await (await fetch(`http://127.0.0.1:${PORT}/json`)).json();
    return targets.filter(
      (t) => t.type === "page" && t.url.startsWith("https://app.slack.com/")
    );
  } catch {
    return [];
  }
}

// Wait (up to ~2 min) for the debug port and at least one webapp page.
async function waitForPages() {
  for (let i = 0; i < 120; i++) {
    const pages = await listSlackPages();
    if (pages.length) return pages;
    await sleep(1000);
  }
  throw new Error(`Slack debug port ${PORT} never came up`);
}

// Attach to one page, inject now and after every load. Resolves when the
// socket closes (Slack quit or the window went away).
function attach(target) {
  return new Promise((done) => {
    const ws = new WebSocket(target.webSocketDebuggerUrl);
    let id = 0;
    const send = (method, params = {}) =>
      ws.send(JSON.stringify({ id: ++id, method, params }));

    ws.onopen = () => {
      send("Page.enable");
      send("Runtime.evaluate", { expression: INJECT_EXPR });
      log(`injected into ${target.url}`);
    };
    ws.onmessage = (ev) => {
      const msg = JSON.parse(ev.data);
      if (msg.method === "Page.loadEventFired") {
        send("Runtime.evaluate", { expression: INJECT_EXPR });
        log("re-injected after reload");
      }
    };
    ws.onerror = (e) => log(`socket error: ${e.message ?? "unknown"}`);
    ws.onclose = () => {
      log(`disconnected from ${target.url}`);
      done();
    };
  });
}

const pages = await waitForPages();
await Promise.all(pages.map(attach));
log("all Slack pages gone; exiting");
