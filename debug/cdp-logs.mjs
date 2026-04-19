#!/usr/bin/env node
// Attaches to a Chrome tab + all its workers via DevTools Protocol,
// reloads the page, and prints console + errors for a few seconds.
// Usage: cdp-logs.mjs <page-url-substring> [seconds]

const urlMatch = process.argv[2] ?? "localhost:8765";
const seconds = Number(process.argv[3] ?? 10);
const port = 9222;

const tabs = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
const tab = tabs.find((t) => t.type === "page" && t.url.includes(urlMatch));
if (!tab) {
  console.error(`no tab matching "${urlMatch}" found. tabs:`);
  for (const t of tabs) console.error(`  ${t.type}\t${t.url}`);
  process.exit(1);
}
console.error(`attached: ${tab.url}`);

const ws = new WebSocket(tab.webSocketDebuggerUrl);
let id = 0;
const sessions = new Map(); // sessionId -> targetType

const send = (method, params = {}, sessionId) => {
  const msg = { id: ++id, method, params };
  if (sessionId) msg.sessionId = sessionId;
  ws.send(JSON.stringify(msg));
};

ws.addEventListener("open", () => {
  send("Target.setAutoAttach", {
    autoAttach: true,
    waitForDebuggerOnStart: false,
    flatten: true,
  });
  send("Runtime.enable");
  send("Log.enable");
  send("Page.enable");
  send("Page.reload", { ignoreCache: true });
});

const fmtArg = (a) => {
  if (a.value !== undefined) return JSON.stringify(a.value);
  if (a.description) return a.description;
  return a.type;
};

const tag = (sessionId) => {
  const t = sessions.get(sessionId);
  return t ? `[${t}] ` : "";
};

ws.addEventListener("message", (ev) => {
  const msg = JSON.parse(ev.data);
  const sid = msg.sessionId;

  if (msg.method === "Target.attachedToTarget") {
    const { sessionId, targetInfo } = msg.params;
    sessions.set(sessionId, targetInfo.type);
    console.error(`+ attached ${targetInfo.type}: ${targetInfo.url || targetInfo.title}`);
    send("Runtime.enable", {}, sessionId);
    send("Log.enable", {}, sessionId);
    send("Runtime.runIfWaitingForDebugger", {}, sessionId);
    return;
  }

  if (msg.method === "Runtime.consoleAPICalled") {
    const { type, args, stackTrace } = msg.params;
    const line = args.map(fmtArg).join(" ");
    console.log(`${tag(sid)}[console.${type}] ${line}`);
    if ((type === "error" || type === "warning") && stackTrace?.callFrames?.[0]) {
      const f = stackTrace.callFrames[0];
      console.log(`    at ${f.functionName || "<anon>"} (${f.url}:${f.lineNumber})`);
    }
  } else if (msg.method === "Runtime.exceptionThrown") {
    const e = msg.params.exceptionDetails;
    console.log(`${tag(sid)}[exception] ${e.text} ${e.exception?.description ?? ""}`);
    if (e.stackTrace?.callFrames?.[0]) {
      const f = e.stackTrace.callFrames[0];
      console.log(`    at ${f.functionName || "<anon>"} (${f.url}:${f.lineNumber})`);
    }
  } else if (msg.method === "Log.entryAdded") {
    const e = msg.params.entry;
    console.log(`${tag(sid)}[log.${e.level}] ${e.text}`);
  }
});

ws.addEventListener("error", (e) => console.error("ws error:", e.message));

setTimeout(() => {
  ws.close();
  process.exit(0);
}, seconds * 1000);
