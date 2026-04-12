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
echo "  • Codex / OpenAI CLI"
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

if command -v codex &>/dev/null; then
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
	echo "  Install any supported agent and re-run this script, or configure it manually."
	echo ""
	echo -e "  Get Codex:          ${BLUE}https://github.com/openai/codex${NC}"
	echo -e "  Get Claude:         ${BLUE}https://claude.ai/download${NC}"
	echo -e "  Get Cursor:         ${BLUE}https://cursor.com${NC}"
	echo -e "  Get Windsurf:       ${BLUE}https://windsurf.com${NC}"
	echo -e "  Get Zed:            ${BLUE}https://zed.dev${NC}"
else
	echo -e "${GREEN}Found $FOUND_AGENTS_COUNT AI agent(s):${NC}"
	$FOUND_CODEX          && echo -e "  ${GREEN}✓${NC} Codex (OpenAI CLI)"
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

CURRENT_NODE_VERSION=$("$NODE_BIN" --version 2>/dev/null | tr -d 'v' || echo "")
if [ "$CURRENT_NODE_VERSION" = "$NODE_VERSION" ]; then
	echo ""
	echo -e "${GREEN}✓ Runtime environment ready${NC}"
else
	echo ""
	echo -e "${YELLOW}Downloading runtime environment...${NC}"
	rm -rf "$INSTALL_DIR/node"
	mkdir -p "$INSTALL_DIR/node"
	NODE_ARCH=$(echo "$ARCH" | sed 's/x86_64/x64/')
	NODE_URL="https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-darwin-${NODE_ARCH}.tar.gz"
	curl -fsSL "$NODE_URL" | tar -xz -C "$INSTALL_DIR/node" --strip-components=1
	echo -e "${GREEN}✓ Runtime environment ready${NC}"
fi

# ── MCP Server (this repo) ────────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}Checking MCP Server...${NC}"
MCP_LATEST=$(curl -sSL "https://api.github.com/repos/$MCP_REPO/releases/latest" \
	-H "Accept: application/vnd.github.v3+json" \
	| "$NODE_BIN" -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>console.log(JSON.parse(d).tag_name))")

CURRENT_MCP_VERSION=$(cat "$INSTALL_DIR/mcp/.version" 2>/dev/null || echo "")
if [ "$CURRENT_MCP_VERSION" = "$MCP_LATEST" ]; then
	echo -e "${GREEN}✓ MCP Server already at $MCP_LATEST${NC}"
else
	echo -e "${YELLOW}Downloading MCP Server $MCP_LATEST...${NC}"
	rm -rf "$INSTALL_DIR/mcp"
	mkdir -p "$INSTALL_DIR/mcp"
	curl -fsSL "https://github.com/$MCP_REPO/releases/download/$MCP_LATEST/wordpress-developer-mcp-server-$MCP_LATEST.tar.gz" | \
		tar -xz -C "$INSTALL_DIR/mcp"
	echo "$MCP_LATEST" > "$INSTALL_DIR/mcp/.version"
	echo -e "${GREEN}✓ MCP Server updated to $MCP_LATEST${NC}"
fi

# ── Studio CLI (wp-studio) ────────────────────────────────────────────────────
echo ""
if command -v studio &>/dev/null; then
	echo -e "${GREEN}✓ Studio CLI already available${NC}"
else
	echo -e "${YELLOW}Installing Studio CLI...${NC}"
	"$NPM_BIN" install -g wp-studio 2>&1 | grep -v "^npm warn" | grep -v "^$" || true
	echo -e "${GREEN}✓ Studio CLI installed${NC}"
fi

# ── Wrapper scripts (always regenerated) ─────────────────────────────────────
rm -f "$INSTALL_DIR/bin/studio-mcp" "$INSTALL_DIR/bin/studio-cli"
MCP_COMMAND="$INSTALL_DIR/bin/studio-mcp"

cat > "$INSTALL_DIR/bin/studio-mcp" << EOF
#!/bin/bash
INSTALLER_NODE="$INSTALL_DIR/node/bin/node"

if command -v node &>/dev/null; then
  NODE="node"
elif [ -x "\$INSTALLER_NODE" ]; then
  NODE="\$INSTALLER_NODE"
else
  echo "Node.js not found." >&2
  exit 1
fi

export STUDIO_CLI_PATH="$INSTALL_DIR/bin/studio-cli"
"\$NODE" "$INSTALL_DIR/mcp/index.js" "\$@"
EOF
chmod +x "$INSTALL_DIR/bin/studio-mcp"

cat > "$INSTALL_DIR/bin/studio-cli" << 'EOF'
#!/bin/bash
if ! command -v studio &>/dev/null; then
  echo "Studio CLI not found. Run: npm install -g wp-studio" >&2
  exit 1
fi
studio "$@"
EOF
chmod +x "$INSTALL_DIR/bin/studio-cli"
echo -e "${GREEN}✓ Wrapper scripts created${NC}"


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
delete config.mcpServers['wordpress-developer'];
config.mcpServers['wordpress-studio'] = { command: mcpCommand };

fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
"
}

configure_codex() {
	codex mcp add wordpress-studio -- "$MCP_COMMAND"
}

configure_claude_desktop() {
	configure_mcpservers_json "$HOME/Library/Application Support/Claude/claude_desktop_config.json"
}

configure_claude_code() {
	claude mcp add --scope user wordpress-studio -- "$MCP_COMMAND"
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
config.context_servers['wordpress-studio'] = {
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
		if configure_codex; then
			CONFIGURED_AGENTS+=("Codex (CLI)")
			echo -e "  ${GREEN}✓${NC} Codex (CLI)"
		else
			FAILED_AGENTS+=("Codex (CLI)")
			echo -e "  ${RED}✗${NC} Codex (CLI) (failed)"
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
		if configure_claude_code; then
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
	if $FOUND_CURSOR && [[ " ${CONFIGURED_AGENTS[*]} " =~ " Cursor " ]]; then
		echo ""
		echo -e "  ${BLUE}ℹ${NC}  Cursor picks up MCP changes automatically — no restart needed."
	fi
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
	echo "      \"wordpress-studio\": {"
	echo "        \"command\": \"$MCP_COMMAND\""
	echo "      }"
	echo "    }"
fi

# ── Restart apps that need it to pick up MCP config ───────────────────────────
RESTART_NEEDED=()

if [[ " ${CONFIGURED_AGENTS[*]} " =~ " Claude Desktop " ]] && pgrep -x "Claude" > /dev/null; then
	RESTART_NEEDED+=("claude_desktop")
fi
if [[ " ${CONFIGURED_AGENTS[*]} " =~ " Windsurf " ]] && pgrep -x "Windsurf" > /dev/null; then
	RESTART_NEEDED+=("windsurf")
fi
if [[ " ${CONFIGURED_AGENTS[*]} " =~ " Zed " ]] && pgrep -x "Zed" > /dev/null; then
	RESTART_NEEDED+=("zed")
fi

if [ ${#RESTART_NEEDED[@]} -gt 0 ]; then
	echo ""
	echo -e "${YELLOW}⚠️  The following apps are running and need a restart to apply MCP:${NC}"
	for app_key in "${RESTART_NEEDED[@]}"; do
		case "$app_key" in
			claude_desktop) echo "  • Claude Desktop" ;;
			windsurf)       echo "  • Windsurf" ;;
			zed)            echo "  • Zed" ;;
		esac
	done
	echo ""
	echo -e "${YELLOW}Restart them now? [Y/n]${NC}"
	read -r restart_response < /dev/tty

	if [[ ! "$restart_response" =~ ^[Nn]$ ]]; then
		for app_key in "${RESTART_NEEDED[@]}"; do
			case "$app_key" in
				claude_desktop)
					echo -e "${YELLOW}Restarting Claude Desktop...${NC}"
					osascript -e 'quit app "Claude"'
					for i in $(seq 1 10); do pgrep -x "Claude" > /dev/null || break; sleep 1; done
					open -a "/Applications/Claude.app"
					echo -e "${GREEN}✓ Claude Desktop restarted${NC}"
					;;
				windsurf)
					echo -e "${YELLOW}Restarting Windsurf...${NC}"
					osascript -e 'quit app "Windsurf"'
					for i in $(seq 1 10); do pgrep -x "Windsurf" > /dev/null || break; sleep 1; done
					WINDSURF_APP="/Applications/Windsurf.app"
					[ ! -d "$WINDSURF_APP" ] && WINDSURF_APP="$HOME/Applications/Windsurf.app"
					open -a "$WINDSURF_APP"
					echo -e "${GREEN}✓ Windsurf restarted${NC}"
					;;
				zed)
					echo -e "${YELLOW}Restarting Zed...${NC}"
					osascript -e 'quit app "Zed"'
					for i in $(seq 1 10); do pgrep -x "Zed" > /dev/null || break; sleep 1; done
					ZED_APP="/Applications/Zed.app"
					[ ! -d "$ZED_APP" ] && ZED_APP="$HOME/Applications/Zed.app"
					open -a "$ZED_APP"
					echo -e "${GREEN}✓ Zed restarted${NC}"
					;;
			esac
		done
	else
		echo ""
		echo -e "${YELLOW}⚠️  Please restart the apps manually to apply MCP configuration.${NC}"
	fi
elif [ ${#CONFIGURED_AGENTS[@]} -gt 0 ]; then
	# Some agents were configured but none need a restart (all are CLI tools or Cursor)
	:
fi

# If no agents were configured at all, remind the user how to start
if [ "$FOUND_AGENTS_COUNT" -eq 0 ] || [ ${#CONFIGURED_AGENTS[@]} -eq 0 ]; then
	echo ""
	echo -e "${YELLOW}Install a supported AI agent to get started:${NC}"
	echo -e "  Claude Desktop: ${BLUE}https://claude.ai/download${NC}"
	echo -e "  Cursor:         ${BLUE}https://cursor.com${NC}"
	echo -e "  Windsurf:       ${BLUE}https://windsurf.com${NC}"
	echo "  Then re-run this installer to configure MCP automatically."
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
echo -e "⭐ If you like it, star the repo: ${BLUE}https://github.com/nightnei/wordpress-developer-mcp-server${NC}"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
