# vicoop-provider

Public **release binaries** for `vicoop-provider` — the one-shot orchestrator that
stands up a local backend, bridges it through vicoop-bridge, and onboards it to
a2x-internal-router as OpenAI-compatible inference.

> This repository contains **only the compiled release artifacts**. The source
> lives in a separate (private) repository; nothing is built or developed here.
> Each GitHub Release here carries the prebuilt, SHA256-checksummed binaries for
> macOS / Linux / Windows, published automatically by the source repo's release
> workflow.

## Prerequisites

The binary is self-contained — it downloads its own dependencies (vicoop-client
and the vicoop-codex backend) during `up`, so the host needs **no Node.js, `jq`,
or build tools**. It does assume the following, from install through first run.
`vicoop-provider doctor` checks the ones it can detect (platform, the backend CLI
+ sign-in, a2x reachability); the rest are listed here.

**Platform** — prebuilt binaries exist for **macOS (Apple Silicon)**, **Linux
x86-64 / arm64**, and **Windows x64** only. There is **no Intel-Mac (x86-64)
build** — the installer won't match it and the tool can't self-upgrade there.
64-bit OS required.

**Install-time host tools**

- macOS / Linux: `curl` or `wget` on PATH (the installer aborts without one).
  Checksum verification additionally uses `sha256sum` / `shasum` when present.
- Windows: the one-liner needs **PowerShell** — the `irm … | iex` bootstrap and
  `install.ps1` use PowerShell cmdlets, so they can't run in `cmd.exe` directly
  (there is no `.bat` installer). Windows PowerShell 5.1 ships in-box with Windows
  10/11 and Server 2016+, so it's normally already there; but a locked-down
  corporate machine may restrict it (Group Policy / AppLocker / Constrained
  Language Mode). If PowerShell is blocked — or you'd rather not use it — download
  the `windows-x64.exe` from the
  [latest release](https://github.com/planetarium/vicoop-provider/releases/latest)
  manually and put it on your PATH. Once installed, the `vicoop-provider` command
  itself runs from **both `cmd` and PowerShell**.

**Network egress** (no GitHub token needed) — required for install and the first
`up`; warm re-runs on an already-provisioned host don't re-download:

- `github.com` + `api.github.com` — to fetch and version-check the binaries.
- the **vicoop-bridge server** (`vicoop-bridge-server.fly.dev`) over **HTTPS *and*
  WebSocket (WSS)** — the agent only stays reachable while the daemon holds a live
  WS session, so a proxy or firewall that blocks outbound WebSockets will break it.
- the **a2x-internal-router** (`a2x-internal-router.fly.dev`) over HTTPS.

**Accounts** — the browser sign-ins walked through during [first run](#first-run):

- a **Google** account (authorizes the bridge agent owner);
- an **a2x** account via Privy (the a2x device-flow sign-in);
- for the `vicoop-codex` backend, a **ChatGPT** account;
- a **consumer API key** (`o2a-live-…`) minted in the a2x console — needed to
  actually *call* inference (the one step `up` can't do for you).

**Backend-specific**

- **`vicoop-codex`** — `up` installs the backend for you. Its default sign-in is a
  local-redirect OAuth flow, so it needs **a browser on this machine** and a free
  **localhost port (1455, falling back to 1457)**. On a headless / remote host,
  use `up -b vicoop-codex --headless` (device-code flow — needs vicoop-codex
  ≥0.4.0, which `up` installs automatically, and device-code enabled on your
  account).
- **`claude`** — you must install and authenticate Anthropic's
  [Claude Code](https://docs.claude.com/en/docs/claude-code/setup) CLI **yourself**
  (`claude` on PATH, plus `claude setup-token`, an interactive sign-in, or
  `ANTHROPIC_API_KEY` / `CLAUDE_CODE_OAUTH_TOKEN`). On **Linux**, Claude Code's
  default sandbox also needs **`bubblewrap` (`bwrap`)** on PATH.

**Runtime** — `up` runs the bridge as a **detached background daemon** that must
keep running for the agent to stay reachable (no service/reboot supervision — if
it dies, re-run `up`). State lives under writable home directories
(`~/.vicoop-provider`, `~/.vicoop`, `~/.vicoop-codex`, `~/.local/bin`).

> `vicoop-provider doctor` is a best-effort preflight, not a guarantee: it does
> **not** probe the bridge / WebSocket reachability, GitHub, daemon liveness, the
> localhost port, or filesystem permissions — so a clean report can still precede
> an `up` failure on one of those.

## Install

**macOS / Linux:**

```bash
curl -fsSL https://raw.githubusercontent.com/planetarium/vicoop-provider/main/install.sh | sh
```

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/planetarium/vicoop-provider/main/install.ps1 | iex
```

Or grab a binary directly from the [latest release](https://github.com/planetarium/vicoop-provider/releases/latest).

The installer downloads the matching standalone binary, SHA256-verifies it, and
installs it as `vicoop-provider` (no Node.js required). It prints the final
location — on macOS/Linux that's `/usr/local/bin` or `~/.local/bin`; on Windows
`%LOCALAPPDATA%\Programs\vicoop-provider`. If that directory isn't on your `PATH`
the installer says so — add it (on Windows, **restart your shell** so the PATH
change takes effect), then confirm:

```bash
vicoop-provider --version
```

## First run

`vicoop-provider` is a **single, idempotent command** that takes you from a fresh
machine to a local backend that's callable as OpenAI-compatible inference through
a2x-internal-router. Pick a backend and run `up`:

```bash
vicoop-provider up -b vicoop-codex     # expose a ChatGPT/Codex-backed agent
# or
vicoop-provider up -b claude           # expose a Claude Code-backed agent
```

`-b/--backend` is **required** (`vicoop-codex` or `claude`). Running
`vicoop-provider` with no subcommand just prints help — it never silently starts
the pipeline.

### What `up` does

It installs what's missing, walks you through the (unavoidable) browser sign-ins
with clear on-screen prompts, registers the agent, and runs the bridge daemon in
the background:

```
vicoop-provider up -b vicoop-codex
  1/4  Dependencies     install vicoop-client + the backend (vicoop-codex | claude)
  2/4  Authentication   backend sign-in  +  bridge owner sign-in        ← browser
  3/4  Bridge agent     register the agent, mint a caller key, run the daemon (detached)
  4/4  a2x onboarding   device-flow login → become provider → register agent  ← browser
  ✓    Provider is up   prints the agent slug + a ready-to-use inference curl
```

Every step checks "already done?" first. **Run it again later and — if you're
already signed in — it brings everything back to a fully-running, registered
state with zero interaction** (it just heals the daemon and confirms
registration).

### Browser sign-ins

The **only** manual steps are the browser sign-ins. They use different identity
providers, so they can't be merged:

| Gate | Provider | Flow |
|---|---|---|
| backend (`vicoop-codex`) | ChatGPT | local redirect — **browser must be on this machine** (callback to `http://localhost:1455`), or pass `--headless` for the device-code flow (browser can be anywhere) |
| backend (`claude`) | — | you authenticate Claude Code yourself first (see below) |
| bridge owner | Google | device flow — browser can be on any machine |
| a2x | Privy | device flow — browser can be on any machine |

> **Headless / remote hosts:** the `vicoop-codex` backend sign-in is the only gate
> that normally needs a browser on *this* machine. Run
> `up -b vicoop-codex --headless` and it switches to the device-code flow — it
> prints a URL + one-time code you open on any device, so no local browser or
> `localhost:1455` callback is required.

> **Claude backend:** `vicoop-provider` does **not** install or sign in Anthropic's
> CLI for you. Install [Claude Code](https://docs.claude.com/en/docs/claude-code/setup)
> and authenticate it first — run `claude setup-token` (long-lived OAuth token),
> sign in once with `claude`, or set `ANTHROPIC_API_KEY` — then run `up -b claude`.

### When it finishes

On success it prints a summary — the bridge agent id, the A2A endpoint, the
daemon pid, and your **a2x slug** (the model name you call) — followed by a
ready-to-use verification `curl`.

Calling inference needs a **consumer** API key (`o2a-live-…`), which is minted in
the a2x console (a Privy-gated, console-only action — outside the automated path).
Once you've minted one, verify end-to-end (`<slug>` is the slug from the summary):

```bash
curl -s https://a2x-internal-router.fly.dev/api/v1/chat/completions \
  -H "authorization: Bearer o2a-live-…" -H 'content-type: application/json' \
  -d '{"model":"<slug>","messages":[{"role":"user","content":"ping"}]}'
```

Check the running state anytime with:

```bash
vicoop-provider status     # installed / signed in / daemon running / registered
```

## Commands

| Command | Description |
|---|---|
| `vicoop-provider up -b <backend>` | Run the full idempotent pipeline; `-b vicoop-codex` or `-b claude` required. |
| `vicoop-provider status [--json]` | What's installed (with the latest available version), signed in, running, registered. |
| `vicoop-provider upgrade [deps…]` | Upgrade vicoop-provider and its dependency CLIs to their latest releases. |
| `vicoop-provider logs [-f]` | Show / follow the bridge daemon log. |
| `vicoop-provider down` | Stop the background daemon (state preserved). |
| `vicoop-provider doctor` | Diagnose host prerequisites. |
| `vicoop-provider reset [--creds]` | Stop the daemon and forget state (optionally delete credentials). |

Useful `up` flags: `--headless` (device-code sign-in for vicoop-codex; no local
browser), `--agent-id`, `--name`, `--a2x-url`, `--bridge-server`,
`--pricing-mode per_token|per_call`,
`--input-price/--output-price/--price-per-call`, `--no-open` (don't auto-open the
browser), `--reinstall`, `--json`. Run `vicoop-provider up --help` for the full
list.

## Upgrading

```bash
vicoop-provider status     # shows installed vs. latest version of each component
vicoop-provider upgrade     # pulls the latest release binaries (no token needed — this repo is public)
```

`upgrade` accepts a subset to limit what it touches
(`vicoop-provider | vicoop-client | vicoop-codex`), and `--force` re-downloads
even binaries already at the latest version.

## State

All orchestrator state lives in `~/.vicoop-provider/` (mode `600`) — the bridge
agent id, the minted caller key, the resolved A2A endpoint, the a2x management
token and slug, plus `daemon.log` for the detached daemon. This is what makes
re-runs interaction-free. To start over, `vicoop-provider reset` (add `--creds`
to also drop the underlying bridge/backend credentials).

## Troubleshooting

- **`daemon did not become healthy` / card 404** — the agent card only serves
  while the daemon holds a live WS session. Check `vicoop-provider logs`.
- **`claude CLI not found` / `not authenticated`** — install Claude Code and run
  `claude setup-token` (or set `ANTHROPIC_API_KEY`), then re-run.
- **a2x `provider_required`** — `up` promotes you to provider automatically; if it
  recurs, promote once in the Privy console, then re-run.
- **Lost `~/.vicoop-provider/` state** — re-running `up` rebuilds it; it mints a
  fresh caller key and (if the agent isn't already in a2x) re-registers.
