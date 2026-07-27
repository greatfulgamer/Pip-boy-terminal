#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# Pip-Boy Terminal — Portable Fleet Terminal
# ════════════════════════════════════════════════════════════════
# Self-contained portable terminal client for the NCR GX-9000 fleet.
# Runs on any device — phone (Termux), tablet, laptop, container.
# Auto-detects identity, connects to fleet services, gives you the bridge.
#
# One command:
#   bash <(curl -fsSL https://raw.githubusercontent.com/greatfulgamer/Pip-boy-terminal/main/pipboy.sh)
#
# Or locally:
#   bash pipboy.sh
# ════════════════════════════════════════════════════════════════

set -euo pipefail

GREEN='\033[0;32m'; AMBER='\033[0;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${AMBER}⚠${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; }

PIP_DIR="$HOME/.pipboy"
MAINFRAME="$PIP_DIR/mainframe"
BLAST_PORT=8190

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  PIP-BOY TERMINAL — Fleet Bridge        ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
echo ""

# ── 1. Detect identity ──────────────────────────────────────

HOSTNAME=$(hostname 2>/dev/null || echo "pipboy")
TS_IP=""
TS_HOST=""

if command -v tailscale &>/dev/null; then
    TS_IP=$(tailscale ip -4 2>/dev/null || echo "")
    if [ -n "$TS_IP" ]; then
        TS_HOST=$(tailscale status 2>/dev/null | awk -v ip="$TS_IP" '$1 == ip {print $2; exit}' || echo "$HOSTNAME")
    fi
fi

# Allow override via env var
PIP_ID="${PIPBOY_ID:-${TS_HOST:-$HOSTNAME}}"

echo -e "  ${GREEN}Identity:${NC} $PIP_ID"
echo -e "  ${GREEN}Tailscale:${NC} ${TS_IP:-offline (local mode)}"
echo ""

# ── 2. Ensure dependencies ───────────────────────────────────

if ! command -v python3 &>/dev/null; then
    fail "Python 3 required — install it first"
fi

if ! command -v git &>/dev/null; then
    warn "git not found — skipping mainframe clone"
    SKIP_MAINFRAME=true
else
    SKIP_MAINFRAME=false
fi

# ── 3. Clone mainframe (minimal) ─────────────────────────────

if [ "$SKIP_MAINFRAME" = false ]; then
    if [ -d "$MAINFRAME/.git" ]; then
        GIT_TERMINAL_PROMPT=0 git -C "$MAINFRAME" pull --ff-only 2>/dev/null && ok "Mainframe updated" || warn "Pull failed — continuing with local copy"
    else
        mkdir -p "$PIP_DIR"
        GIT_TERMINAL_PROMPT=0 git clone --depth 1 "https://github.com/greatfulgamer/NCR-RobCo-GX-9000-Mainframe.git" "$MAINFRAME" 2>/dev/null && ok "Mainframe cloned" || warn "Clone failed — limited functionality"
    fi
fi

# ── 4. Fleet connection test ──────────────────────────────────

echo ""
echo -e "${CYAN}─── Fleet Connection ───${NC}"

# Test blaster on randall-clark
BLAST_RESULT=$(python3 -c "
import socket, json
try:
    s = socket.socket()
    s.settimeout(5)
    s.connect(('100.114.132.6', $BLAST_PORT))
    s.sendall(b'ping {}\n')
    resp = b''
    while True:
        chunk = s.recv(4096)
        if not chunk: break
        resp += chunk
    s.close()
    data = json.loads(resp.decode())
    if data.get('ok'):
        print('ONLINE')
        print('  Hostname:', data.get('hostname', '?'))
        print('  IP:', data.get('ts_ip', '?'))
        print('  Uptime:', data.get('uptime', '?'))
    else:
        print('ERROR:', data.get('error', 'unknown'))
except Exception as e:
    print('OFFLINE:', str(e)[:60])
" 2>/dev/null)

echo -e "  ${AMBER}Blaster (randall-clark):${NC}"
echo "$BLAST_RESULT" | while IFS= read -r line; do echo "    $line"; done

# Test Tower
TOWER_STATUS=$(curl -s -o /dev/null -w '%{http_code}' http://100.75.58.91:8082 2>/dev/null || echo "000")
if [ "$TOWER_STATUS" = "200" ]; then
    ok "Tower (Mr. New Vegas): ONLINE"
else
    warn "Tower: OFFLINE (HTTP $TOWER_STATUS)"
fi

# ── 5. Quick commands menu ────────────────────────────────────

echo ""
echo -e "${CYAN}─── Quick Commands ───${NC}"
echo ""
echo -e "  ${GREEN}pipboy ping${NC}         — ping fleet authority"
echo -e "  ${GREEN}pipboy chat${NC}         — read fleet chat"
echo -e "  ${GREEN}pipboy chat \"msg\"${NC}   — send message"
echo -e "  ${GREEN}pipboy who${NC}          — fleet identity manifest"
echo -e "  ${GREEN}pipboy status${NC}       — fleet status overview"
echo -e "  ${GREEN}pipboy tower${NC}        — open Tower in browser"
echo ""

# ── 6. Save state ────────────────────────────────────────────

cat > "$PIP_DIR/state.json" << STATE
{
    "identity": "$PIP_ID",
    "tailscale_ip": "${TS_IP:-none}",
    "tailscale_host": "${TS_HOST:-none}",
    "last_seen": "$(date -Iseconds)",
    "tower_status": "$TOWER_STATUS",
    "blaster_status": "$(echo "$BLAST_RESULT" | head -1)"
}
STATE

echo -e "  ${CYAN}Session saved:${NC} $PIP_DIR/state.json"
echo -e "  ${CYAN}─────────────────────────────────────${NC}"
echo ""

# ── 7. Interactive mode (if run interactively) ────────────────

if [ -t 0 ]; then
    echo -e "  Type ${GREEN}pipboy help${NC} for commands, or ${GREEN}exit${NC} to leave."
    echo ""
    while true; do
        printf "${GREEN}%s${NC}> " "$PIP_ID"
        read -r cmd || break
        case "$cmd" in
            exit|quit) echo "  See you, wastelander."; break ;;
            ping)
                bash "$0" --ping
                ;;
            chat)
                bash "$0" --chat
                ;;
            chat\ *)
                bash "$0" --chat-send "${cmd#chat }"
                ;;
            who|identity|manifest)
                bash "$0" --who
                ;;
            status)
                bash "$0" --status
                ;;
            tower)
                bash "$0" --tower
                ;;
            help|"")
                echo "  ping | chat | chat <msg> | who | status | tower | exit"
                ;;
            *)
                # Try to send as blaster command
                bash "$0" --blast "$cmd"
                ;;
        esac
    done
else
    echo "  Run interactively for terminal mode."
fi
