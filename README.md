# vicoop-provider

Public **release binaries** for `vicoop-provider` — the one-shot orchestrator that
stands up a local backend, bridges it through vicoop-bridge, and onboards it to
a2x-internal-router as OpenAI-compatible inference.

> This repository contains **only the compiled release artifacts**. The source
> lives in a separate (private) repository; nothing is built or developed here.
> Each GitHub Release here carries the prebuilt, SHA256-checksummed binaries for
> macOS / Linux / Windows, published automatically by the source repo's release
> workflow.

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

## Upgrading

```bash
vicoop-provider status     # shows installed vs. latest version of each component
vicoop-provider upgrade     # pulls the latest release binaries (no token needed — this repo is public)
```
