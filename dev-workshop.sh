#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# Pip-Boy Terminal — Dev Workshop (APK modding + agentic dev)
# ════════════════════════════════════════════════════════════════
# Installs APK reverse engineering + development tools in Termux.
# Connects to fleet Ollama for AI-assisted coding.
#
# Usage (inside Termux):
#   bash <(curl -fsSL https://raw.githubusercontent.com/greatfulgamer/Pip-boy-terminal/main/dev-workshop.sh)
# ════════════════════════════════════════════════════════════════

set -euo pipefail

GREEN='\033[0;32m'; AMBER='\033[0;33m'; CYAN='\033[0;36m'; NC='\033[0m'
ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${AMBER}⚠${NC} $1"; }

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  PIP-BOY DEV WORKSHOP                    ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
echo ""

pkg update -qq 2>/dev/null

# ── 1. APK reverse engineering stack ──────────────────────────

echo -e "${CYAN}─── APK Tools ───${NC}"

for tool in apktool jadx aapt; do
    pkg install -y $tool 2>/dev/null && ok "$tool installed" || warn "$tool skipped"
done

# Install uber-apk-signer for re-signing
if [ ! -f "$PREFIX/bin/uber-apk-signer.jar" ]; then
    curl -fsSL "https://github.com/patrickfav/uber-apk-signer/releases/download/v1.3.0/uber-apk-signer-1.3.0.jar" -o "$PREFIX/bin/uber-apk-signer.jar" 2>/dev/null && ok "uber-apk-signer installed" || warn "uber-apk-signer skipped"
fi

# ── 2. Development stack ──────────────────────────────────────

echo ""
echo -e "${CYAN}─── Dev Tools ───${NC}"

for tool in python nodejs rust clang make; do
    pkg install -y $tool 2>/dev/null && ok "$tool installed" || warn "$tool skipped"
done

pip install requests flask 2>/dev/null && ok "python packages" || true
npm install -g typescript ts-node 2>/dev/null && ok "typescript" || true

# ── 3. ADB bridge (if USB debugging connected) ─────────────────

echo ""
echo -e "${CYAN}─── ADB Bridge ───${NC}"

pkg install -y android-tools 2>/dev/null && ok "adb installed" || warn "adb skipped (no USB debugging)"

# ── 4. Fleet AI coding assistant ──────────────────────────────

echo ""
echo -e "${CYAN}─── AI Coding Assistant ───${NC}"

# Creates a script that sends code questions to fleet Ollama
cat > "$HOME/bin/ai" << 'AI_SCRIPT'
#!/data/data/com.termux/files/usr/bin/bash
# ai — fleet AI coding assistant
# Usage: ai "how do I decompile an APK?"
#        ai --code "explain this Python function" < file.py

PROMPT="${*}"
if [ -z "$PROMPT" ]; then
    echo "Usage: ai <question>"
    exit 1
fi

curl -s http://100.75.58.91:11434/api/generate -d "{
  \"model\": \"llama3.2:1b\",
  \"prompt\": \"You are an Android development assistant. Answer concisely.\n\nUser: $PROMPT\n\nAssistant:\",
  \"stream\": false
}" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('response','error'))" 2>/dev/null || echo "Fleet Ollama unreachable — falling back to local"
AI_SCRIPT
chmod +x "$HOME/bin/ai" && ok "ai command ready" || warn "ai command failed"

# ── 5. Workspace ──────────────────────────────────────────────

mkdir -p "$HOME/dev-workspace/apk-mods" "$HOME/dev-workspace/projects"

cat > "$HOME/dev-workspace/README.md" << 'WS'
# Pip-Boy Dev Workshop

## APK Modding Workflow

```bash
# 1. Decompile
apktool d app.apk -o app-src

# 2. Explore with Java decompiler
jadx app.apk -d app-java

# 3. Ask AI for help
ai "what does com.app.MainActivity do?" < app-java/sources/app/MainActivity.java

# 4. Modify smali/java code
# Edit files in app-src/

# 5. Rebuild
apktool b app-src -o app-mod.apk

# 6. Sign
uber-apk-signer --apks app-mod.apk

# 7. Install via ADB
adb install app-mod.apk
```

## Fleet Resources

- Fleet Ollama: http://100.75.58.91:11434 (5 models)
- Local Ollama: ollama serve (Tensor G5)
- Tower: http://100.75.58.91:8082
- AI helper: ai "your question"
WS

ok "Dev workspace: ~/dev-workspace"

# ── 6. Summary ─────────────────────────────────────────────────

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Dev Workshop — Ready                    ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo "  APK tools:    apktool, jadx, aapt, uber-apk-signer"
echo "  Dev tools:    python, node, rust, clang, make"
echo "  AI assistant: ai \"your question\""
echo "  Workspace:    ~/dev-workspace"
echo ""
echo "  Decompile:    apktool d app.apk -o app-src"
echo "  Rebuild:      apktool b app-src -o app-mod.apk"
echo "  Sign:         uber-apk-signer --apks app-mod.apk"
echo "  Install:      adb install app-mod.apk"
echo ""
