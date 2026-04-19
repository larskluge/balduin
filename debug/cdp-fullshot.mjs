#!/usr/bin/env node
// Full-page screenshot via CDP.
// Usage: cdp-fullshot.mjs <page-url-substring> <output-png>

const urlMatch = process.argv[2] ?? "localhost:8765";
const outPath = process.argv[3] ?? "fullshot.png";
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

const metrics = await send("Page.getLayoutMetrics");
const { width, height } = metrics.cssContentSize;
const { data } = await send("Page.captureScreenshot", {
  format: "png",
  captureBeyondViewport: true,
  clip: { x: 0, y: 0, width, height, scale: 1 },
});
await writeFile(outPath, Buffer.from(data, "base64"));
console.log(`wrote ${outPath} (${Math.round(width)}×${Math.round(height)})`);
ws.close();
process.exit(0);
