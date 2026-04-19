# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Two layers:

1. **The 2004 game** at the repo root: `ueb10.asm` (2,149 lines of MASM/TASM-style x86 real-mode assembly) plus `balduin.exe` (3,577 bytes), `sprites.bmp`, and `level001.bld`…`level005.bld`. Written by Heiko and Lars at Fachhochschule Wedel. Treat as historical artifacts — do not modify unless explicitly asked.
2. **The 2026 web launcher** in `web/`: a single HTML page that runs the original `.exe` unmodified in the browser via js-dos (DOSBox compiled to WebAssembly). Deployed to https://balduin.la0x.com via Cloudflare Pages.

## Common commands

| Command | What it does |
|---|---|
| `make build` | Rebuild `web/balduin.zip` from the root game files + an inline `dosbox.conf` (`cycles=fixed 26532`) |
| `make run` | `make build` then serve `web/` at `http://localhost:8765/` |
| `make deploy` | `make build` then `wrangler pages deploy web --project-name=balduin --branch=main --commit-dirty=true` |
| `make clean` | Remove `web/balduin.zip` |

`web/balduin.zip` is a **build artifact**, not a source file — it is committed so deploys don't rebuild unnecessarily, but any change to the root game files requires `make build`.

## Web launcher architecture

`web/index.html` uses **js-dos v6**, not v8. v8 has two bugs that block this game:

- The default backend panics with a `RangeError` in `protocol.ts` when the game's VGA mode-13h framebuffer arrives.
- The `dosboxX` backend renders text but never auto-mounts the bundle as `C:` — only DOSBox-X's built-in `Z:` exists.

js-dos v6 avoids both via `fs.extract("balduin.zip")` which mounts the zip as `C:`.

**Critical v6 quirk:** the element passed to `Dos(...)` must be a `<canvas>`, not a `<div>`. With a `<div>`, js-dos v6's SDL layer crashes with `TypeError: canvas.getContext is not a function` the moment the game switches to mode 13h.

The game is launched with:

```js
main([
  "-conf", "dosbox.conf",
  "-c", `config -set "cpu cycles=fixed ${cycles}"`,
  "-c", "balduin.exe",
])
```

`?cycles=N` in the URL overrides the bundled default. `26532` sits just above the "can finish a frame in the 14.3 ms VGA-retrace window" threshold and below the "wasting host CPU" range — the game is vsync-locked to ~70 Hz, so more cycles don't buy more FPS.

## Debugging the live site (`debug/`)

Four zero-dependency Node scripts attach to a Chrome with remote debugging enabled and inspect the running page. They use Node 22+'s built-in `WebSocket` and `fetch`.

Start Chrome once:

```
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --remote-debugging-port=9222 \
  --user-data-dir=/tmp/chrome-balduin-debug \
  http://localhost:8765/
```

Then:

```
node debug/cdp-logs.mjs localhost:8765 10            # console + exceptions, incl. web workers
node debug/cdp-screenshot.mjs localhost:8765 out.png # viewport
node debug/cdp-fullshot.mjs localhost:8765 out.png   # full scrollable page
node debug/cdp-clip.mjs localhost:8765 out.png 0 0 1200 200
```

`cdp-logs.mjs` subscribes to both the main target and every attached worker — js-dos runs DOSBox in a worker, so its logs/panics only appear with worker attach.

## Deploy notes

Cloudflare Pages project: `balduin`, production branch: `main`. The custom domain `balduin.la0x.com` was added via the Pages API. **The wrangler OAuth token does not have `zone:edit`**, so DNS changes must be made in the Cloudflare dashboard (`la0x.com` → DNS → `CNAME balduin → balduin.pages.dev`, proxied). The Pages SSL cert auto-provisions once the CNAME resolves.
