#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# Pip-Boy Terminal — Termux + Ollama Hybrid Path
# ════════════════════════════════════════════════════════════════
# For Pixel 10 / Android with Termux (F-Droid version).
# Installs Ollama locally, connects to fleet, creates a self-contained
# agentic terminal that can run models AND participate in fleet ops.
#
# Usage (inside Termux):
#   bash <(curl -fsSL https://raw.githubusercontent.com/greatfulgamer/Pip-boy-terminal/main/termux-pipboy.sh)
# ════════════════════════════════════════════════════════════════

set -euo pipefail

GREEN='\033[0;32m'; AMBER='\033[0;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${AMBER}⚠${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; }

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  PIP-BOY TERMINAL — Termux Hybrid       ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
echo ""

PIP_DIR="$HOME/.pipboy"

# ── 1. Install core packages ──────────────────────────────────

echo -e "${CYAN}─── Core Setup ───${NC}"
pkg update -qq 2>/dev/null && ok "pkg updated" || warn "pkg update skipped"

for pkg in python git curl jq ollama; do
    if ! command -v $pkg &>/dev/null 2>&1 && ! dpkg -l | grep -q "$pkg"; then
        pkg install -y $pkg 2>/dev/null && ok "$pkg installed" || warn "$pkg skipped"
    else
        ok "$pkg available"
    fi
done

# ── 2. Start Ollama ───────────────────────────────────────────

echo ""
echo -e "${CYAN}─── Ollama (Local LLM) ───${NC}"

if command -v ollama &>/dev/null; then
    # Start ollama server in background
    if ! curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
        nohup ollama serve > /tmp/ollama.log 2>&1 &
        sleep 3
    fi

    if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
        ok "Ollama running — local LLM ready"
        MODELS=$(curl -s http://localhost:11434/api/tags | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('models',[])))" 2>/dev/null || echo "0")
        echo "  Local models: $MODELS"
        if [ "$MODELS" = "0" ]; then
            echo "  Pull a model: ollama pull llama3.2:1b"
        fi
    else
        warn "Ollama failed to start — check /tmp/ollama.log"
    fi
else
    warn "Ollama not available — local LLM skipped"
fi

# ── 3. Clone Pip-Boy terminal ─────────────────────────────────

echo ""
echo -e "${CYAN}─── Pip-Boy Setup ───${NC}"

mkdir -p "$PIP_DIR"

if [ ! -f "$PIP_DIR/pipboy.sh" ]; then
    curl -fsSL "https://raw.githubusercontent.com/greatfulgamer/Pip-boy-terminal/main/pipboy.sh" -o "$PIP_DIR/pipboy.sh" 2>/dev/null && chmod +x "$PIP_DIR/pipboy.sh" && ok "Pip-Boy downloaded" || warn "Download failed"
else
    ok "Pip-Boy already installed"
fi

# ── 4. Fleet identity setup ───────────────────────────────────

echo ""
echo -e "${CYAN}─── Fleet Identity ───${NC}"

if command -v tailscale &>/dev/null; then
    TS_IP=$(tailscale ip -4 2>/dev/null || echo "")
    TS_HOST=$(tailscale status 2>/dev/null | awk -v ip="$TS_IP" '$1 == ip {print $2; exit}' || echo "")
    if [ -n "$TS_HOST" ]; then
        ok "Tailscale: $TS_HOST ($TS_IP)"
    else
        warn "Tailscale offline — local mode only"
        TS_HOST="pixel-10"
    fi
else
    warn "Tailscale not installed — install via Termux: pkg install tailscale"
    TS_HOST="pixel-10"
fi

echo "  Identity: $TS_HOST"
echo "  Fleet: NCR GX-9000"
echo ""
echo "  Connect to the fleet via:"
echo "    Tower:  http://100.75.58.91:8082"
echo "    Blaster: 100.114.132.6:8190"
echo "    Chat:   colonel-james-hsu:7976"
echo "    Ollama: 100.75.58.91:11434 (fleet)"

# ── 5. Create shortcut ────────────────────────────────────────

cat > "$HOME/bin/pipboy" << 'ALIAS'
#!/data/data/com.termux/files/usr/bin/bash
exec bash ~/.pipboy/pipboy.sh "$@"
ALIAS
chmod +x "$HOME/bin/pipboy" 2>/dev/null || true
ok "Shortcut: type 'pipboy' to launch"

# ── 6. Fleet test ─────────────────────────────────────────────

echo ""
echo -e "${CYAN}─── Fleet Connection Test ───${NC}"

python3 -c "
import socket, sys
try:
    s = socket.socket()
    s.settimeout(5)
    s.connect(('100.114.132.6', 8190))
    s.sendall(b'ping {}\n')
    resp = b''
    while True:
        chunk = s.recv(4096)
        if not chunk: break
        resp += chunk
    s.close()
    import json
    data = json.loads(resp.decode())
    if data.get('ok'):
        print(f'  Blaster: ONLINE — {data.get(\"hostname\",\"?\")} ({data.get(\"ts_ip\",\"?\")})')
    else:
        print(f'  Blaster: {data.get(\"error\", \"unknown\")}')
except Exception as e:
    print(f'  Blaster: OFFLINE (Tailscale required)')
" 2>/dev/null

# ── 7. Summary ────────────────────────────────────────────────

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Termux Pip-Boy — Ready                  ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo "  Local LLM:    ollama serve (localhost:11434)"
echo "  Fleet client: pipboy"
echo "  Tower:        http://100.75.58.91:8082"
echo "  Blaster:      echo 'ping {}' | nc 100.114.132.6 8190"
echo ""
echo "  Tensor G5 inference: ~8-10 tok/s (CPU-bound, small models)"
echo "  Pull a model: ollama pull llama3.2:1b"
echo ""
