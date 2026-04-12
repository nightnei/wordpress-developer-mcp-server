#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

INSTALL_DIR="$HOME/.wordpress-studio-mcp"
MCP_REPO="nightnei/wordpress-developer-mcp-server"
NODE_VERSION="24.13.1"

echo -e "${BLUE}${BOLD}🌸 Installing WordPress Developer MCP Server...${NC}"
echo -e "${GREEN}${BOLD}Turn your AI into a full-stack WordPress developer.${NC}"

# ── OS check ──────────────────────────────────────────────────────────────────
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m 2>/dev/null || echo "unknown")
if [[ "$OS" != "darwin" ]]; then
	echo ""
	echo -e "${RED}❌ Currently only macOS is supported.${NC}"
	exit 1
fi
echo ""
echo -e "${GREEN}✓ Detected: macOS on ${ARCH}${NC}"

if [ -d "/Applications/Studio.app" ]; then
	echo ""
	echo -e "${GREEN}🔗 WordPress Studio detected on your machine!${NC}"
	echo "  The MCP server will sync with Studio, so you can work"
	echo "  on both at the same time — your sites and data stay in sync."
fi

# ── Supported agents ──────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}${BOLD}Supported AI agents:${NC}"
echo "  • Codex (app + CLI)"
echo "  • Claude Desktop"
echo "  • Claude Code (CLI)"
echo "  • Cursor"
echo "  • Windsurf"
echo "  • Zed"

# ── Detect installed agents ───────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}Detecting installed AI agents...${NC}"

FOUND_CODEX=false
FOUND_CLAUDE_DESKTOP=false
FOUND_CLAUDE_CODE=false
FOUND_CURSOR=false
FOUND_WINDSURF=false
FOUND_ZED=false
FOUND_AGENTS_COUNT=0

app_installed() {
	[ -d "/Applications/$1" ] || [ -d "$HOME/Applications/$1" ]
}

if command -v codex &>/dev/null || app_installed "Codex.app"; then
	FOUND_CODEX=true
	FOUND_AGENTS_COUNT=$((FOUND_AGENTS_COUNT + 1))
fi
if app_installed "Claude.app"; then
	FOUND_CLAUDE_DESKTOP=true
	FOUND_AGENTS_COUNT=$((FOUND_AGENTS_COUNT + 1))
fi
if command -v claude &>/dev/null; then
	FOUND_CLAUDE_CODE=true
	FOUND_AGENTS_COUNT=$((FOUND_AGENTS_COUNT + 1))
fi
if app_installed "Cursor.app"; then
	FOUND_CURSOR=true
	FOUND_AGENTS_COUNT=$((FOUND_AGENTS_COUNT + 1))
fi
if app_installed "Windsurf.app"; then
	FOUND_WINDSURF=true
	FOUND_AGENTS_COUNT=$((FOUND_AGENTS_COUNT + 1))
fi
if app_installed "Zed.app"; then
	FOUND_ZED=true
	FOUND_AGENTS_COUNT=$((FOUND_AGENTS_COUNT + 1))
fi

echo ""
if [ "$FOUND_AGENTS_COUNT" -eq 0 ]; then
	echo -e "${YELLOW}⚠️  No supported AI agents found on your system.${NC}"
	echo "  The MCP server will still be installed."
	echo "  Install any supported agent and re-run this script."
	echo ""
	echo -e "  Get Codex:          ${BLUE}https://openai.com/codex${NC}"
	echo -e "  Get Claude:         ${BLUE}https://claude.ai/download${NC}"
	echo -e "  Get Cursor:         ${BLUE}https://cursor.com${NC}"
	echo -e "  Get Windsurf:       ${BLUE}https://windsurf.com${NC}"
	echo -e "  Get Zed:            ${BLUE}https://zed.dev${NC}"
else
	echo -e "${GREEN}Found $FOUND_AGENTS_COUNT AI agent(s):${NC}"
	$FOUND_CODEX          && echo -e "  ${GREEN}✓${NC} Codex"
	$FOUND_CLAUDE_DESKTOP && echo -e "  ${GREEN}✓${NC} Claude Desktop"
	$FOUND_CLAUDE_CODE    && echo -e "  ${GREEN}✓${NC} Claude Code (CLI)"
	$FOUND_CURSOR         && echo -e "  ${GREEN}✓${NC} Cursor"
	$FOUND_WINDSURF       && echo -e "  ${GREEN}✓${NC} Windsurf"
	$FOUND_ZED            && echo -e "  ${GREEN}✓${NC} Zed"
	echo ""
	echo "  MCP support will be added to all of them."
fi

mkdir -p "$INSTALL_DIR"/{node,mcp,bin}

# ── Node.js runtime ───────────────────────────────────────────────────────────
NODE_BIN="$INSTALL_DIR/node/bin/node"
NPM_BIN="$INSTALL_DIR/node/bin/npm"

echo ""
echo -e "${YELLOW}Checking runtime environment...${NC}"
CURRENT_NODE_VERSION=$("$NODE_BIN" --version 2>/dev/null | tr -d 'v' || echo "")
if [ "$CURRENT_NODE_VERSION" = "$NODE_VERSION" ]; then
	echo -e "${GREEN}✓ Runtime environment already installed${NC}"
else
	echo -e "${YELLOW}Downloading runtime environment...${NC}"
	rm -rf "$INSTALL_DIR/node"
	mkdir -p "$INSTALL_DIR/node"
	NODE_ARCH=$(echo "$ARCH" | sed 's/x86_64/x64/')
	NODE_URL="https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-darwin-${NODE_ARCH}.tar.gz"
	curl -fsSL "$NODE_URL" | tar -xz -C "$INSTALL_DIR/node" --strip-components=1
	echo -e "${GREEN}✓ Runtime environment installed${NC}"
fi

# ── MCP Server (this repo) ────────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}Checking MCP Server...${NC}"
MCP_LATEST=$(curl -sSL "https://api.github.com/repos/$MCP_REPO/releases/latest" \
	-H "Accept: application/vnd.github.v3+json" \
	| "$NODE_BIN" -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>console.log(JSON.parse(d).tag_name))")
CURRENT_MCP_VERSION=$(cat "$INSTALL_DIR/mcp/.version" 2>/dev/null || echo "")
if [ "$CURRENT_MCP_VERSION" = "$MCP_LATEST" ]; then
	echo -e "${GREEN}✓ MCP Server already up to date${NC}"
else
	echo -e "${YELLOW}Downloading MCP Server...${NC}"
	rm -rf "$INSTALL_DIR/mcp"
	mkdir -p "$INSTALL_DIR/mcp"
	curl -fsSL "https://github.com/$MCP_REPO/releases/download/$MCP_LATEST/wordpress-developer-mcp-server-$MCP_LATEST.tar.gz" | \
		tar -xz -C "$INSTALL_DIR/mcp"
	echo "$MCP_LATEST" > "$INSTALL_DIR/mcp/.version"
	if [ -n "$CURRENT_MCP_VERSION" ]; then
		echo -e "${GREEN}✓ MCP Server updated to $MCP_LATEST${NC}"
	else
		echo -e "${GREEN}✓ MCP Server installed${NC}"
	fi
fi

# ── Studio CLI (wp-studio) ────────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}Checking Studio CLI...${NC}"
STUDIO_LATEST=$(PATH="$INSTALL_DIR/node/bin:$PATH" "$NPM_BIN" view wp-studio version --loglevel=silent 2>/dev/null || echo "")
CURRENT_STUDIO_VERSION=$(PATH="$INSTALL_DIR/node/bin:$PATH" "$NPM_BIN" list -g wp-studio --depth=0 --loglevel=silent 2>/dev/null | grep wp-studio | sed 's/.*wp-studio@//' | tr -d ' ' || echo "")
if [ -n "$CURRENT_STUDIO_VERSION" ] && [ "$CURRENT_STUDIO_VERSION" = "$STUDIO_LATEST" ]; then
	echo -e "${GREEN}✓ Studio CLI already up to date${NC}"
else
	echo -e "${YELLOW}Installing Studio CLI...${NC}"
	PATH="$INSTALL_DIR/node/bin:$PATH" "$NPM_BIN" install -g wp-studio --loglevel=silent 2>&1 | grep -i "error" || true
	if [ -n "$CURRENT_STUDIO_VERSION" ]; then
		echo -e "${GREEN}✓ Studio CLI updated to $STUDIO_LATEST${NC}"
	else
		echo -e "${GREEN}✓ Studio CLI installed${NC}"
	fi
fi

# ── Wrapper scripts (always regenerated) ─────────────────────────────────────
echo ""
echo -e "${YELLOW}Creating wrapper scripts...${NC}"
rm -f "$INSTALL_DIR/bin/studio-mcp" "$INSTALL_DIR/bin/studio-cli"
MCP_COMMAND="$INSTALL_DIR/bin/studio-mcp"

cat > "$INSTALL_DIR/bin/studio-mcp" << EOF
#!/bin/bash
export STUDIO_CLI_PATH="$INSTALL_DIR/bin/studio-cli"
"$INSTALL_DIR/node/bin/node" "$INSTALL_DIR/mcp/index.js" "\$@"
EOF
chmod +x "$INSTALL_DIR/bin/studio-mcp"

cat > "$INSTALL_DIR/bin/studio-cli" << EOF
#!/bin/bash
if command -v studio &>/dev/null; then
  studio "\$@"
else
  "$INSTALL_DIR/node/bin/studio" "\$@"
fi
EOF
chmod +x "$INSTALL_DIR/bin/studio-cli"
echo -e "${GREEN}✓ Wrapper scripts ready${NC}"
