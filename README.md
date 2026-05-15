<div align="center">

<a href="https://github.com/ipycharmer">
<pre>
    ██ ██████  ██   ██  ██████ ██  ██   █████  ██████  ██   ██ ███████ ██████
     ██ ██   ██  ██ ██  ██      ██  ██  ██   ██ ██   ██ ███ ███ ██      ██   ██
     ██ ██████    ███   ██      ███████  ███████ ██████  ██ █ ██ █████   ██████
     ██ ██       ██     ██      ██  ██  ██   ██ ██   ██ ██   ██ ██      ██   ██
     ██ ██      ██       ██████ ██  ██  ██   ██ ██   ██ ██   ██ ███████ ██   ██
</pre>
</a>

# Claude Code × OpenRouter × Docker

**Run Anthropic's agentic coding environment — free — on any machine.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue?style=flat-square&color=0055ff)](LICENSE)
[![OpenRouter](https://img.shields.io/badge/Powered%20by-OpenRouter-blue?style=flat-square&color=0033cc)](https://openrouter.ai)
[![Docker](https://img.shields.io/badge/Docker-Required-blue?style=flat-square&color=0055ff)](https://docker.com)
[![Made by ipycharmer](https://img.shields.io/badge/by-ipycharmer-cyan?style=flat-square&color=0099ff)](https://github.com/ipycharmer)

[**→ Quick Start**](#-quick-start) · [**→ Model Comparison**](#-model-benchmark) · [**→ What's Inside**](#-whats-inside-the-image) · [**→ LinkedIn**](https://www.linkedin.com/in/ipycharmer)

</div>

---

## What Is This?

Claude Code is Anthropic's terminal-based AI coding agent. It reads your files, writes code, runs bash commands, uses git, installs packages, and completes full engineering tasks autonomously — like having a senior engineer in your terminal.

**Normally it requires an Anthropic subscription.**

This project wraps Claude Code in Docker and routes all API calls through a custom proxy to OpenRouter — giving you access to powerful **free** AI models with zero Anthropic billing.

```
You  →  ./run.sh
              │
              ▼
        ┌─────────────────────────────────┐
        │         Docker Container        │
        │                                 │
        │   proxy.js (port 3456)          │
        │   ┌─────────────────────────┐   │
        │   │  Anthropic API format   │   │
        │   │         ↓               │   │
        │   │  OpenRouter API format  │   │
        │   └─────────────────────────┘   │
        │              │                  │
        │        Claude Code CLI          │
        └─────────────────────────────────┘
                       │
                       ▼
              openrouter.ai → free model
```

---

## ⚡ Quick Start

> **Requirements:** Docker Desktop (running) · macOS / Linux / WSL2 · Free [OpenRouter API key](https://openrouter.ai/keys)

```bash
# 1. Clone
git clone https://github.com/ipycharmer/claudecode-free
cd claudecode-free

# 2. Make executable
chmod +x run.sh

# 3. Launch
./run.sh
```

**First run builds the Docker image — takes ~10–15 minutes, never again after that.**

On every subsequent run `./run.sh` is instant. It will:
1. Load your saved API key (or ask once and save it)
2. Show an arrow-key model picker
3. Ask for your workspace folder
4. Launch Claude Code pointed at your project

---

## 🖥️ What It Looks Like

```
  ██ ██████  ██   ██  ██████ ██  ██   █████  ██████  ██   ██ ███████ ██████
  ██ ██   ██  ██ ██  ██      ██  ██  ██   ██ ██   ██ ███ ███ ██      ██   ██
  ██ ██████    ███   ██      ███████  ███████ ██████  ██ █ ██ █████   ██████
  ██ ██       ██     ██      ██  ██  ██   ██ ██   ██ ██   ██ ██      ██   ██
  ██ ██      ██       ██████ ██  ██  ██   ██ ██   ██ ██   ██ ███████ ██   ██

               Claude Code  ×  OpenRouter  ×  Docker
          Powered by ipycharmer  ·  github.com/ipycharmer

  ✓  API key loaded  (sk-or-v1…****)

╔══════════════════════════════════════════════════════════════════════════════════╗
│                                  Choose a model                                  │
╠══════════════════════════════════════════════════════════════════════════════════╣
│  ★  ↑↓ arrows to move, Enter to select, [m] manual:                              │
│                                                                                  │
│  ❯  Owl Alpha           OpenRouter   1.05M ctx   Agentic / native                │
│     openrouter/owl-alpha                                                         │
│                                                                                  │
│     Nemotron Super 120B  NVIDIA       128K ctx   Fast reasoning                  │
│     Ring 2.6 1T          InclusionAI  128K ctx   1T param MoE                    │
│     GPT-OSS 120B         OpenAI       128K ctx   OSS flagship                    │
│     Laguna M.1           Poolside     32K ctx    Code specialist                 │
│                                                                                  │
│  [m]  Type any OpenRouter model ID manually                                      │
╚══════════════════════════════════════════════════════════════════════════════════╝

  ◆  Workspace: /your/project

  ◈  Proxy ready → openrouter/owl-alpha

╭─── Claude Code v2.1.140 ──────────────────────────────────────────╮
│   openrouter/owl-alpha · API Usage Billing   │  /workspace        │
╰───────────────────────────────────────────────────────────────────╯

❯ list all files and fix any bugs you find

● I'll start by reading the directory...
  Listed 12 files · Found 2 issues · Applying fixes...
```

---

## 🤖 Models Available

| # | Model | Provider | Context | Limit |
|---|-------|----------|---------|-------|
| 1 | **Owl Alpha** ⭐ | OpenRouter | 1.05M | **None** |
| 2 | Nemotron Super 120B | NVIDIA | 128K | Shared |
| 3 | Ring 2.6 1T | InclusionAI | 128K | Shared |
| 4 | GPT-OSS 120B | OpenAI | 128K | Shared |
| 5 | Laguna M.1 | Poolside | 32K | Shared |
| m | *Any model ID* | OpenRouter | — | — |

> **Owl Alpha** is the only free model with **no daily usage restrictions**. My personal pick for open source projects. It logs your data — don't send sensitive info.
>
> All other free models share OpenRouter's rate limits. Read more at [openrouter.ai](https://openrouter.ai) or DM me: [linkedin.com/in/ipycharmer](https://www.linkedin.com/in/ipycharmer)

---

## 📊 Model Benchmark

Real test on a Flask project. Two prompts: (1) read directory, (2) write file summaries.

| Model | Prompt 1 | Prompt 2 | Notes |
|-------|----------|----------|-------|
| `openrouter/auto` | 5s | 20s | 💸 Fastest — paid |
| `baidu/cobuddy:free` | 28s | **26s** | ⚡ Fastest free |
| `openai/gpt-oss-120b:free` | 13s | 1m 8s | Solid |
| `z-ai/glm-4.5-air:free` | 16s | 1m | Good balance |
| `inclusionai/ring-2.6-1t:free` | 15s | 44s | Impressive |
| `minimax/minimax-m2` | 27s | 1m 39s | Average |
| `openrouter/free` | 14s | 2m 42s | Varies |
| `nvidia/nemotron-3-super-120b-a12b:free` | 21s | 2m 38s | Accurate |
| `poolside/laguna-m.1:free` | 22s | 1m 38s | Code-focused |
| **`openrouter/owl-alpha`** | 20s | **3m** | ✅ **100% accurate · No limits** |

---

## 📁 Project Structure

```
claudecode-free/
│
├── 🐳  Dockerfile          Full dev environment — Python, Node, Go, Rust, Chromium
├── 🔀  proxy.js            Anthropic → OpenRouter API translation + dedup
├── 🚀  entrypoint.sh       Container startup — configures Claude Code
├── 🎨  run.sh              TUI launcher — arrow keys, API key management
├── 🔍  debug.js            Debug proxy — logs all traffic
├── 🔍  debug-run.sh        Launch with debug proxy
└── 📖  README.md           This file
```

---

## 🛠️ What's Inside the Image

The Docker image is a complete development environment. Build it once, use forever.

| Category | What's Included |
|----------|----------------|
| 🐍 **Python** | `python3`, `pip`, flask, fastapi, pandas, numpy, pytest, black, ruff, sqlalchemy, requests, openai, anthropic, playwright, selenium, pillow, rich, pydantic |
| 🟨 **Node.js** | `node` 22, `npm`, `yarn`, `pnpm`, typescript, ts-node, eslint, prettier, nodemon, http-server |
| 🔵 **Go** | `go` 1.22 |
| 🦀 **Rust** | `cargo`, `rustc`, `rustup` |
| 🔧 **Shell Tools** | `jq`, `yq`, `ripgrep`, `fd`, `fzf`, `curl`, `wget`, `httpie` |
| 🗄️ **Database** | `sqlite3` |
| 🌐 **Browser** | Chromium (headless), Playwright, Puppeteer, Selenium |
| 📦 **Git** | Full git + SSH client |
| 🏗️ **Build** | `make`, `cmake`, `gcc`, `g++` |
| 🐳 **Docker CLI** | Connect to host socket for Docker-in-Docker |

### Browser Automation Example

```python
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch(
        executable_path="/usr/bin/chromium",
        args=["--no-sandbox", "--headless"]
    )
    page = browser.new_page()
    page.goto("https://example.com")
    page.screenshot(path="/workspace/screenshot.png")
    browser.close()
```

---

## 🧪 Test Setup (Benchmark Details)

```
test/
├── hell.py       # Simple Flask app: GET / → "Hello World"
├── test.md       # Empty — model writes hell.py description here
└── test2.md      # Empty — model writes improvement suggestions here
```

**Prompts used:**
1. `can you read current directory?`
2. `write everything about hell.py inside test.md whatever you think hell.py is and keep it under 100 words, and write whatever you think shouldve been added to hell.py inside test2.md and keep it under 100 words too`

---

## 💡 Tips & Tricks

**Skip permissions prompt:**
```bash
./run.sh . --dangerously-skip-permissions
```

**Change your API key:**
```bash
rm ~/.claude-or-key && ./run.sh
```

**Rebuild the image** (after Dockerfile changes):
```bash
docker rmi claudecode-free && ./run.sh
```

**Debug mode** (see all proxy traffic):
```bash
chmod +x debug-run.sh
./debug-run.sh openrouter/owl-alpha /path/to/project
```

**Docker-in-Docker** (model can run Docker commands):
```bash
docker run --rm -it \
  -e OPENROUTER_API_KEY="your-key" \
  -e TARGET_MODEL="openrouter/owl-alpha" \
  -v /your/project:/workspace \
  -v /var/run/docker.sock:/var/run/docker.sock \
  claudecode-free
```

---

## ⚖️ Legal & Compliance

This project **does not** violate any rights of Anthropic or Claude Code.

- ✅ Uses the Claude Code CLI as published on npm without modification
- ✅ Uses `ANTHROPIC_BASE_URL` — an officially supported environment variable documented by Anthropic
- ✅ Routes to OpenRouter using your own API key
- ✅ Does not bypass, crack, or reverse-engineer any Anthropic system
- ✅ Does not redistribute Anthropic's models or weights

This is equivalent to using any OpenAI-compatible provider with Claude Code. You are responsible for complying with [OpenRouter's Terms of Service](https://openrouter.ai/terms) and the terms of your chosen model.

> ⚠️ **Privacy:** Free models may log your prompts. Do not send sensitive data, API keys, passwords, or proprietary code through free-tier models.

---

<div align="center">

Built with <3 by **Ameer Hamza Nasir**

[![GitHub](https://img.shields.io/badge/GitHub-ipycharmer-blue?style=flat-square&logo=github&color=0055ff)](https://github.com/ipycharmer)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-ipycharmer-blue?style=flat-square&logo=linkedin&color=0077b5)](https://www.linkedin.com/in/ipycharmer)

*If this saved you money, drop a ⭐ on the repo.*

</div>
