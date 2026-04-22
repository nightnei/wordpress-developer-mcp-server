#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

INSTALL_DIR="$HOME/.wordpress-developer-mcp"
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
export PATH="$INSTALL_DIR/node/bin:\$PATH"
if command -v studio &>/dev/null; then
  studio "\$@"
else
  "$INSTALL_DIR/node/bin/studio" "\$@"
fi
EOF
chmod +x "$INSTALL_DIR/bin/studio-cli"
echo -e "${GREEN}✓ Wrapper scripts ready${NC}"

# ── Configure AI agents ───────────────────────────────────────────────────────
CONFIGURED_AGENTS=()
FAILED_AGENTS=()

# Shared helper: write/merge mcpServers JSON config (Claude Desktop, Cursor, Windsurf)
configure_mcpservers_json() {
	local config_file="$1"
	local config_dir
	config_dir="$(dirname "$config_file")"
	mkdir -p "$config_dir"

	"$NODE_BIN" -e "
const fs = require('fs');
const configPath = '$config_file';
const mcpCommand = '$MCP_COMMAND';

let config = {};
try {
  config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
} catch (e) {
  config = {};
}

if (!config.mcpServers) config.mcpServers = {};
config.mcpServers['wordpress-developer'] = { command: mcpCommand };

fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
"
}

configure_codex() {
	if command -v codex &>/dev/null; then
		codex mcp remove wordpress-developer &>/dev/null || true
		codex mcp add wordpress-developer -- "$MCP_COMMAND" &>/dev/null
	else
		local config_file="$HOME/.codex/config.toml"
		mkdir -p "$HOME/.codex"
		"$NODE_BIN" -e "
const fs = require('fs');
const path = require('path');
const configPath = '$config_file';
const mcpCommand = '$MCP_COMMAND';

let content = '';
try { content = fs.readFileSync(configPath, 'utf8'); } catch (e) { content = ''; }

const newEntry = '[mcp_servers.wordpress-developer]\ncommand = \"' + mcpCommand + '\"';
const sectionRegex = /\[mcp_servers\.wordpress-developer\][^\[]*/;

if (sectionRegex.test(content)) {
  content = content.replace(sectionRegex, newEntry + '\n\n');
} else {
  content = (content.trimEnd() ? content.trimEnd() + '\n\n' : '') + newEntry + '\n';
}

fs.writeFileSync(configPath, content);
"
	fi
}

configure_claude_desktop() {
	configure_mcpservers_json "$HOME/Library/Application Support/Claude/claude_desktop_config.json"
}

configure_claude_code() {
	claude mcp remove wordpress-developer --scope user &>/dev/null || true
	claude mcp add --scope user wordpress-developer -- "$MCP_COMMAND" &>/dev/null
}

configure_cursor() {
	configure_mcpservers_json "$HOME/.cursor/mcp.json"
}

configure_windsurf() {
	configure_mcpservers_json "$HOME/.codeium/windsurf/mcp_config.json"
}

configure_zed() {
	local config_file="$HOME/.config/zed/settings.json"
	mkdir -p "$HOME/.config/zed"

	"$NODE_BIN" -e "
const fs = require('fs');
const configPath = '$config_file';
const mcpCommand = '$MCP_COMMAND';

let config = {};
try {
  config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
} catch (e) {
  config = {};
}

if (!config.context_servers) config.context_servers = {};
config.context_servers['wordpress-developer'] = {
  source: 'custom',
  command: mcpCommand,
  args: []
};

fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
"
}

if [ "$FOUND_AGENTS_COUNT" -gt 0 ]; then
	echo ""
	echo -e "${YELLOW}Configuring AI agents...${NC}"

	if $FOUND_CODEX; then
		if configure_codex 2>/dev/null; then
			CONFIGURED_AGENTS+=("Codex")
			echo -e "  ${GREEN}✓${NC} Codex"
		else
			FAILED_AGENTS+=("Codex")
			echo -e "  ${RED}✗${NC} Codex (failed)"
		fi
	fi

	if $FOUND_CLAUDE_DESKTOP; then
		if configure_claude_desktop 2>/dev/null; then
			CONFIGURED_AGENTS+=("Claude Desktop")
			echo -e "  ${GREEN}✓${NC} Claude Desktop"
		else
			FAILED_AGENTS+=("Claude Desktop")
			echo -e "  ${RED}✗${NC} Claude Desktop (failed)"
		fi
	fi

	if $FOUND_CLAUDE_CODE; then
		if configure_claude_code 2>/dev/null; then
			CONFIGURED_AGENTS+=("Claude Code (CLI)")
			echo -e "  ${GREEN}✓${NC} Claude Code (CLI)"
		else
			FAILED_AGENTS+=("Claude Code (CLI)")
			echo -e "  ${RED}✗${NC} Claude Code (CLI) (failed)"
		fi
	fi

	if $FOUND_CURSOR; then
		if configure_cursor 2>/dev/null; then
			CONFIGURED_AGENTS+=("Cursor")
			echo -e "  ${GREEN}✓${NC} Cursor"
		else
			FAILED_AGENTS+=("Cursor")
			echo -e "  ${RED}✗${NC} Cursor (failed)"
		fi
	fi

	if $FOUND_WINDSURF; then
		if configure_windsurf 2>/dev/null; then
			CONFIGURED_AGENTS+=("Windsurf")
			echo -e "  ${GREEN}✓${NC} Windsurf"
		else
			FAILED_AGENTS+=("Windsurf")
			echo -e "  ${RED}✗${NC} Windsurf (failed)"
		fi
	fi

	if $FOUND_ZED; then
		if configure_zed 2>/dev/null; then
			CONFIGURED_AGENTS+=("Zed")
			echo -e "  ${GREEN}✓${NC} Zed"
		else
			FAILED_AGENTS+=("Zed")
			echo -e "  ${RED}✗${NC} Zed (failed)"
		fi
	fi
fi

# ── WordPress.com authentication ──────────────────────────────────────────────
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}🔐 Connect to WordPress.com${NC}"
echo ""

AUTH_OUTPUT=$("$INSTALL_DIR/bin/studio-cli" auth status 2>&1 || true)
if echo "$AUTH_OUTPUT" | grep -qi "Authenticated"; then
	WPCOM_USER=$(echo "$AUTH_OUTPUT" | sed -n 's/.*as `\(.*\)`.*/\1/p')
	if [ -d "/Applications/Studio.app" ]; then
		echo -e "Connected as ${GREEN}${WPCOM_USER}${NC} (using your WordPress Studio account)."
	else
		echo -e "Connected as ${GREEN}${WPCOM_USER}${NC}."
	fi
	echo "  Preview sites and other WordPress.com features are available."
else
	echo "This unlocks extra powerful features provided by WordPress.com."
	echo ""
	echo -e "${GREEN}Connect now? [Y/n]${NC}"
	read -r auth_response < /dev/tty

	if [[ ! "$auth_response" =~ ^[Nn]$ ]]; then
		echo ""
		echo -e "${YELLOW}Opening WordPress.com login in your browser...${NC}"
		"$INSTALL_DIR/bin/studio-cli" auth login < /dev/tty

		if [ $? -eq 0 ]; then
			echo -e "${GREEN}✓ Connected to WordPress.com${NC}"
		else
			echo -e "${RED}Connection failed.${NC}"
		fi
	else
		echo -e "${YELLOW}Skipped.${NC}"
	fi
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}✅ Installation complete!${NC}"
echo ""

if [ ${#CONFIGURED_AGENTS[@]} -gt 0 ]; then
	echo -e "${GREEN}Successfully configured agents:${NC}"
	for agent in "${CONFIGURED_AGENTS[@]}"; do
		echo -e "  ${GREEN}✓${NC} $agent"
	done
fi

if [ ${#FAILED_AGENTS[@]} -gt 0 ]; then
	echo ""
	echo -e "${YELLOW}⚠️  Could not configure automatically:${NC}"
	for agent in "${FAILED_AGENTS[@]}"; do
		echo -e "  ${YELLOW}•${NC} $agent"
	done
	echo ""
	echo "  Add this to the agent's MCP configuration manually:"
	echo ""
	echo "    \"mcpServers\": {"
	echo "      \"wordpress-developer\": {"
	echo "        \"command\": \"$MCP_COMMAND\""
	echo "      }"
	echo "    }"
fi

# ── Restart reminder ──────────────────────────────────────────────────────────
NEEDS_RESTART=()
[[ " ${CONFIGURED_AGENTS[*]} " =~ " Codex " ]]          && app_installed "Codex.app" && NEEDS_RESTART+=("Codex")
[[ " ${CONFIGURED_AGENTS[*]} " =~ " Claude Desktop " ]] && NEEDS_RESTART+=("Claude Desktop")
[[ " ${CONFIGURED_AGENTS[*]} " =~ " Windsurf " ]]       && NEEDS_RESTART+=("Windsurf")
[[ " ${CONFIGURED_AGENTS[*]} " =~ " Zed " ]]            && NEEDS_RESTART+=("Zed")

if [ ${#NEEDS_RESTART[@]} -gt 0 ]; then
	echo ""
	echo -e "${YELLOW}↺  Please restart these apps to apply MCP configuration:${NC}"
	for app in "${NEEDS_RESTART[@]}"; do
		echo -e "  ${YELLOW}•${NC} $app"
	done
fi


# ── Footer ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🌸 You're all set!${NC}"
echo ""
echo "Try asking your AI:"
echo "  \"Create a new WordPress site named 'Flowers Shop'\""
echo "  \"Install the WooCommerce plugin\""
echo "  \"Add one demo product to the shop named 'Sunflower'\""
echo "  \"Create shareable link for the shop\""
echo ""
echo -e "⭐ Star the repo: ${BLUE}https://github.com/${MCP_REPO}${NC} — it helps others discover the project."
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
