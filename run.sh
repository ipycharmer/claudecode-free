#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="claude-code-openrouter"
SAVED_KEY_FILE="$HOME/.claude-or-key"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors — assigned via $'...' so escapes are real bytes, not literals
B1=$'\033[38;5;19m'
B2=$'\033[38;5;27m'
B3=$'\033[38;5;33m'
B4=$'\033[38;5;39m'
B5=$'\033[38;5;45m'
W=$'\033[1;97m'
DIM=$'\033[2;37m'
BOLD=$'\033[1m'
NC=$'\033[0m'

BW=82  # box inner width (visible chars)

# ── Box drawing ───────────────────────────────────────────────────────────────
# All functions print exactly BW visible chars between │ borders.
# We strip ANSI codes to measure actual visible length before padding.

strip_ansi() { printf '%s' "$1" | sed $'s/\033\\[[0-9;]*m//g'; }

# Print one content row. Pass pre-colored string; we measure its visible length.
boxrow() {
  local colored="$1"
  local visible; visible=$(strip_ansi "$colored")
  local pad=$(( BW - ${#visible} - 2 ))  # -2 for leading "  "
  [ $pad -lt 0 ] && pad=0
  printf "${B4}│${NC}  %s%${pad}s${B4}│${NC}\n" "$colored" ""
}
boxblank() { printf "${B4}│%${BW}s│${NC}\n" ""; }
boxtop()   { printf "${B4}╔"; printf '═%.0s' $(seq 1 $BW); printf "╗${NC}\n"; }
boxmid()   { printf "${B4}╠"; printf '═%.0s' $(seq 1 $BW); printf "╣${NC}\n"; }
boxbot()   { printf "${B4}╚"; printf '═%.0s' $(seq 1 $BW); printf "╝${NC}\n"; }

boxcenter() {
  local text="$1" color="${2:-$W}"
  local pad=$(( (BW - ${#text}) / 2 ))
  local rpad=$(( BW - ${#text} - pad ))
  printf "${B4}│${NC}${color}%${pad}s%s%${rpad}s${NC}${B4}│${NC}\n" "" "$text" ""
}

sl() { sleep "${1:-0.1}"; }

typeprint() {
  local s="$1" delay="${2:-0.03}" c="${3:-}"
  printf "%s" "$c"
  echo -n "$s" | while IFS= read -r -n1 ch; do printf "%s" "$ch"; sleep "$delay"; done
  printf "%s" "$NC"
}

# ── Logo: IPYCHARMER in block letters ────────────────────────────────────────
draw_logo() {
  clear; sl 0.05; echo ""
  printf "${B3}  ██ ██████  ██   ██  ██████ ██  ██   █████  ██████  ██   ██ ███████ ██████  ${NC}\n"; sl 0.05
  printf "${B4}  ██ ██   ██  ██ ██  ██      ██  ██  ██   ██ ██   ██ ███ ███ ██      ██   ██ ${NC}\n"; sl 0.05
  printf "${B5}  ██ ██████    ███   ██      ███████  ███████ ██████  ██ █ ██ █████   ██████  ${NC}\n"; sl 0.05
  printf "${B4}  ██ ██       ██     ██      ██  ██  ██   ██ ██   ██ ██   ██ ██      ██   ██ ${NC}\n"; sl 0.05
  printf "${B3}  ██ ██      ██       ██████ ██  ██  ██   ██ ██   ██ ██   ██ ███████ ██   ██ ${NC}\n"; sl 0.15
  echo ""
  local sub="Claude Code  ×  OpenRouter  ×  Docker"
  local credit="Powered by ipycharmer  ·  github.com/ipycharmer"
  printf "%*s${B4}%s${NC}\n" $(( (79 - ${#sub}) / 2 )) "" "$sub"; sl 0.06
  printf "%*s${DIM}%s${NC}\n" $(( (79 - ${#credit}) / 2 )) "" "$credit"; sl 0.30
  echo ""
}

# ─────────────────────────────────────────────────────────────────────────────
draw_logo

# ── Build image ───────────────────────────────────────────────────────────────
if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
  printf "  ${B4}⚙${NC}  ${W}Building Docker image — one-time only...${NC}\n"; sl 0.1
  docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"
  printf "  ${B4}✓${NC}  ${W}Image ready.${NC}\n"; sl 0.3; echo ""
fi

# ── API Key ───────────────────────────────────────────────────────────────────
OR_KEY=""
sl 0.1

if [ -n "${OPENROUTER_API_KEY:-}" ]; then
  OR_KEY="$OPENROUTER_API_KEY"
  printf "  ${B4}✓${NC}  API key from ${DIM}environment${NC}\n"
elif [ -f "$SAVED_KEY_FILE" ]; then
  OR_KEY="$(cat "$SAVED_KEY_FILE")"
  MASKED="${OR_KEY:0:8}…${OR_KEY: -4}"
  printf "  ${B4}✓${NC}  API key loaded  ${DIM}(${MASKED}) — delete ${SAVED_KEY_FILE} to change${NC}\n"
fi
sl 0.15

if [ -z "$OR_KEY" ]; then
  printf "  ${B4}◆${NC}  ${W}OpenRouter API Key${NC}  ${DIM}→ https://openrouter.ai/keys${NC}\n\n"
  read -rsp "     Key: " OR_KEY; echo ""
  [ -z "$OR_KEY" ] && { printf "  ${B4}✗${NC}  Empty key — exiting.\n"; exit 1; }
  sl 0.1; echo ""
  read -rp "     Save key? [Y/n]: " SAVE_KEY; SAVE_KEY="${SAVE_KEY:-Y}"
  if [[ "$SAVE_KEY" =~ ^[Yy]$ ]]; then
    echo -n "$OR_KEY" > "$SAVED_KEY_FILE"; chmod 600 "$SAVED_KEY_FILE"
    printf "     ${B4}✓${NC}  Saved.\n"
  fi
fi
echo ""; sl 0.2

# ── Model picker ──────────────────────────────────────────────────────────────
MODEL_IDS=(
  "openrouter/owl-alpha"
  "nvidia/nemotron-3-super-120b-a12b:free"
  "inclusionai/ring-2.6-1t:free"
  "openai/gpt-oss-120b:free"
  "poolside/laguna-m.1:free"
)
MODEL_NAMES=( "Owl Alpha"            "Nemotron Super 120B" "Ring 2.6 1T"         "GPT-OSS 120B"        "Laguna M.1"         )
MODEL_PROVS=( "OpenRouter"           "NVIDIA"              "InclusionAI"         "OpenAI"              "Poolside"           )
MODEL_CTXS=(  "1.05M ctx"            "128K ctx"            "128K ctx"            "128K ctx"            "32K ctx"            )
MODEL_TAGS=(  "Agentic / native"     "Fast reasoning"      "1T param MoE"        "OSS flagship"        "Code specialist"    )

# ── Arrow-key model picker ────────────────────────────────────────────────────
_draw_model_menu() {
  local selected=$1 redraw=$2
  local total=${#MODEL_IDS[@]}
  # lines = boxtop(1) + boxcenter(1) + boxmid(1) + subtitle(1) + blank(1)
  #       + per model: row(1)+id(1)+blank(1) = 3 each
  #       + manual(1) + blank(1) + boxbot(1) = 3
  local rows=$(( 5 + total * 3 + 3 ))
  [ "$redraw" -gt 0 ] && printf "[%dA[J" "$rows"
  boxtop
  boxcenter "Choose a model" "$B4$BOLD"
  boxmid
  boxrow "${B5}★  ↑↓ arrows to move, Enter to select, [m] manual:${NC}"
  boxblank
  for i in "${!MODEL_IDS[@]}"; do
    local id="${MODEL_IDS[$i]}" nm="${MODEL_NAMES[$i]}"
    local pr="${MODEL_PROVS[$i]}" cx="${MODEL_CTXS[$i]}" tg="${MODEL_TAGS[$i]}"
    if [ "$i" -eq "$selected" ]; then
      boxrow "${B5}${BOLD} ❯ $(printf '%-21s' "$nm")${NC} ${B5}$(printf '%-12s' "$pr")${NC} ${B4}$(printf '%-11s' "$cx")${NC} ${B5}${BOLD}${tg}${NC}"
      boxrow "${B5}   ${id}${NC}"
    else
      boxrow "   ${DIM}$(printf '%-21s' "$nm")  $(printf '%-12s' "$pr")  $(printf '%-11s' "$cx")  ${tg}${NC}"
      boxrow "   ${DIM}${id}${NC}"
    fi
    boxblank
  done
  boxrow "${DIM}[m]  Type any OpenRouter model ID manually${NC}"
  boxblank
  boxbot
}

MODEL=""
_sel=0
_redraws=0
_draw_model_menu $_sel 0

while true; do
  IFS= read -rsn1 _key </dev/tty
  if [[ "$_key" == $'' ]]; then
    IFS= read -rsn2 -t 1 _rest </dev/tty 2>/dev/null || true
    case "$_rest" in
      "[A") [ "$_sel" -gt 0 ] && _sel=$((_sel-1)); _redraws=$((_redraws+1)); _draw_model_menu $_sel $_redraws ;;
      "[B") [ "$_sel" -lt $(( ${#MODEL_IDS[@]}-1 )) ] && _sel=$((_sel+1)); _redraws=$((_redraws+1)); _draw_model_menu $_sel $_redraws ;;
    esac
  elif [[ "$_key" == "" ]]; then
    MODEL="${MODEL_IDS[$_sel]}"; echo ""; break
  elif [[ "$_key" =~ [mM] ]]; then
    echo ""
    stty sane
    printf "  ${B4}◆${NC}  Model ID: "
    IFS= read -r MODEL </dev/tty
    [ -z "$MODEL" ] && MODEL="${MODEL_IDS[0]}"
    break
  elif [[ "$_key" =~ [1-9] ]]; then
    local _n=$((_key-1)) 2>/dev/null || _n=$((_key-1))
    if [ "$_n" -ge 0 ] && [ "$_n" -lt "${#MODEL_IDS[@]}" ]; then
      MODEL="${MODEL_IDS[$_n]}"; echo ""; break
    fi
  fi
done



# ── Workspace ─────────────────────────────────────────────────────────────────
sl 0.2; echo ""
printf "  ${B4}◆${NC}  ${W}Workspace folder${NC}  ${DIM}(blank = current directory)${NC}\n"
read -rp "  Path [$(pwd)]: " WS_IN
WORKSPACE="${WS_IN:-$(pwd)}"
WORKSPACE="${WORKSPACE/#\~/$HOME}"

# ── Summary ───────────────────────────────────────────────────────────────────
sl 0.2; echo ""
boxtop; sl 0.04
boxrow "${B4}Model    :${NC}  ${W}${MODEL}${NC}"; sl 0.04
boxrow "${B4}Workspace:${NC}  ${DIM}${WORKSPACE}${NC}"; sl 0.04
boxbot; sl 0.2
echo ""
printf "  ${B4}⟳${NC}  "; typeprint "Starting container..." 0.03 "$DIM"; echo ""
sl 0.4; echo ""

[ $# -ge 1 ] && shift || true

docker run --rm -it \
  -e OPENROUTER_API_KEY="$OR_KEY" \
  -e TARGET_MODEL="$MODEL" \
  -v "$WORKSPACE":/workspace \
  "$IMAGE_NAME" "$@"