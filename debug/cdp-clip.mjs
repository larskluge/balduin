#!/usr/bin/env node
// Screenshot a specific clip of a Chrome tab via CDP.
// Usage: cdp-clip.mjs <page-url-substring> <output-png> <x> <y> <w> <h>

const urlMatch = process.argv[2] ?? "localhost:8765";
const outPath = process.argv[3] ?? "clip.png";
const x = Number(process.argv[4] ?? 0);
const y = Number(process.argv[5] ?? 0);
const width = Number(process.argv[6] ?? 1200);
const height = Number(process.argv[7] ?? 200);
const port = 9222;

const tabs = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
const tab = tabs.find((t) => t.type === "page" && t.url.includes(urlMatch));
if (!tab) { console.error("no tab"); process.exit(1); }

const { writeFile } = await import("node:fs/promises");
const ws = new WebSocket(tab.webSocketDebuggerUrl);
let id = 0;
const pending = new Map();
const send = (method, params = {}) => {
  const msgId = ++id;
  ws.send(JSON.stringify({ id: msgId, method, params }));
  return new Promise((resolve) => pending.set(msgId, resolve));
};
ws.addEventListener("message", (ev) => {
  const msg = JSON.parse(ev.data);
  if (msg.id && pending.has(msg.id)) {
    pending.get(msg.id)(msg.result);
    pending.delete(msg.id);
  }
});
await new Promise((r) => ws.addEventListener("open", r, { once: true }));

const { data } = await send("Page.captureScreenshot", {
  format: "png",
  captureBeyondViewport: true,
  clip: { x, y, width, height, scale: 1 },
});
await writeFile(outPath, Buffer.from(data, "base64"));
console.log(`wrote ${outPath} (${width}×${height})`);
ws.close();
process.exit(0);
