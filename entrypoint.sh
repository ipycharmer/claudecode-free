#!/bin/sh
# ── Colors (POSIX sh compatible) ─────────────────────────────────────────────
B3='\033[38;5;33m'
B4='\033[38;5;39m'
B5='\033[38;5;51m'
W='\033[1;97m'
DIM='\033[2;37m'
NC='\033[0m'

p() { printf "${B4}  ◈${NC}  ${DIM}${1}${NC}\n"; sleep "${2:-0.3}"; }

# ── Write ~/.claude config ────────────────────────────────────────────────────
mkdir -p /root/.claude

cat > /root/.claude/api-key-helper.sh << HELPER
#!/bin/sh
echo "${OPENROUTER_API_KEY}"
HELPER
chmod +x /root/.claude/api-key-helper.sh

cat > /root/.claude/settings.json << SETTINGS
{
  "apiKeyHelper": "/root/.claude/api-key-helper.sh",
  "env": {
    "ANTHROPIC_BASE_URL": "http://127.0.0.1:3456",
    "ANTHROPIC_MODEL": "${TARGET_MODEL}",
    "ANTHROPIC_SMALL_FAST_MODEL": "${TARGET_MODEL}"
  },
  "hasCompletedOnboarding": true,
  "autoUpdaterStatus": "disabled"
}
SETTINGS

# ── Start proxy ────────────────────────────────────────────────────────────────
p "Initializing proxy..." 0.4
node /proxy/proxy.js > /tmp/proxy.log 2>&1 &
PROXY_PID=$!

p "Connecting to OpenRouter..." 0.5

for i in $(seq 1 25); do
  if wget -q -O- http://127.0.0.1:3456/health >/dev/null 2>&1; then
    break
  fi
  sleep 0.25
done

p "Model: ${TARGET_MODEL}" 0.4
p "Ready." 0.5

printf "\n"

trap "kill $PROXY_PID 2>/dev/null" EXIT

export ANTHROPIC_BASE_URL="http://127.0.0.1:3456"
export ANTHROPIC_MODEL="${TARGET_MODEL}"
export ANTHROPIC_SMALL_FAST_MODEL="${TARGET_MODEL}"

exec claude "$@"
