#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

INSTALL_DIR="$HOME/.studio-mcp"
NODE_VERSION="24.13.1"
SQLITE_VERSION="v2.2.17"
MCP_REPO="nightnei/wordpress-developer-mcp-server"
CLI_URL="https://github.com/nightnei/tmp_apr/releases/download/v0.0.1/tmp_sol.tar.gz"

STUDIO_APPDATA_DIR="$HOME/Library/Application Support/Studio"
STUDIO_APPDATA_V1_JSON="$STUDIO_APPDATA_DIR/appdata-v1.json"
SERVER_FILES="$STUDIO_APPDATA_DIR/server-files"
WP_LATEST_DIR="$SERVER_FILES/wordpress-versions/latest"
SQLITE_DIR="$SERVER_FILES/sqlite-database-integration"
SQLITE_CMD_DIR="$SERVER_FILES/sqlite-command"
WP_CLI_PHAR="$SERVER_FILES/wp-cli.phar"

echo -e "${BLUE}${BOLD}🌸 Installing WordPress Developer MCP Server...${NC}"
echo -e "${GREEN}${BOLD}Turn your AI into a full-stack WordPress developer.${NC}"

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m 2>/dev/null || echo "unknown")
if [[ "$OS" != "darwin" ]]; then
	echo ""
	echo -e "${RED}❌ Currently only macOS is supported.${NC}"
	exit 1
fi
if [[ "$ARCH" != "arm64" ]]; then
	echo ""
	echo -e "${YELLOW}⚠️  It looks like you're running macOS on ${ARCH}, which is not officially supported.${NC}"
	echo "  Currently only Apple Silicon (arm64) is supported."
	echo ""
	echo "  If this detection seems incorrect, press Enter to continue."
	echo -e "  Otherwise, press ${BOLD}Ctrl+C${NC} to cancel."
	read -r < /dev/tty
else
	echo ""
	echo -e "${GREEN}✓ Detected: macOS on ${ARCH}${NC}"
fi

if [ ! -d "/Applications/Claude.app" ]; then
	echo ""
    echo -e "${RED}❌ Claude Desktop not found.${NC}"
    echo "  It's the only supported AI assistant for now. More coming soon."
    echo ""
    echo "  Download it here and create an account:"
    echo -e "  ${BLUE}https://claude.ai/download${NC}"
    echo ""
    echo "  After installing Claude Desktop, run this script again."
    exit 1
fi

if [ -d "/Applications/Studio.app" ]; then
	echo ""
	echo -e "${GREEN}🔗 WordPress Studio detected on your machine!${NC}"
	echo "  The MCP server will sync with Studio, so you can work"
	echo "  on both at the same time — your sites and data stay in sync."
fi

if [ -d "$INSTALL_DIR" ]; then
	echo ""
	echo -e "${YELLOW}Removing previous installation...${NC}"
	rm -rf "$INSTALL_DIR"
fi

mkdir -p "$INSTALL_DIR"/{node,mcp,cli,bin}

echo ""
echo -e "${YELLOW}Downloading runtime environment...${NC}"
NODE_URL="https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-darwin-arm64.tar.gz"
curl -fsSL "$NODE_URL" | tar -xz -C "$INSTALL_DIR/node" --strip-components=1
echo -e "${GREEN}✓ Runtime environment ready${NC}"

echo ""
echo -e "${YELLOW}Downloading MCP Server (this may take a while)...${NC}"
curl -fsSL "https://github.com/$MCP_REPO/archive/refs/heads/main.tar.gz" | \
	tar -xz -C "$INSTALL_DIR/mcp" --strip-components=1
curl -fsSL "$CLI_URL" | \
	tar -xz -C "$INSTALL_DIR/cli" --strip-components=1

cat > "$INSTALL_DIR/bin/studio-mcp" << EOF
#!/bin/bash
"$INSTALL_DIR/node/bin/node" "$INSTALL_DIR/mcp/dist/index.js" "\$@"
EOF
chmod +x "$INSTALL_DIR/bin/studio-mcp"

cat > "$INSTALL_DIR/bin/studio-cli" << EOF
#!/bin/bash
"$INSTALL_DIR/node/bin/node" "$INSTALL_DIR/cli/main.js" "\$@"
EOF
chmod +x "$INSTALL_DIR/bin/studio-cli"
echo -e "${GREEN}✓ MCP Server installed${NC}"

if [ ! -f "$STUDIO_APPDATA_V1_JSON" ]; then
	echo ""
	echo -e "${YELLOW}Creating data storage...${NC}"
	mkdir -p "$STUDIO_APPDATA_DIR"
	cat > "$STUDIO_APPDATA_V1_JSON" << 'APPDATAEOF'
{
  "version": 1,
  "sites": [],
  "snapshots": [],
  "sentryUserId": "studio_mcp",
  "lastSeenVersion": "1.7.4",
  "onboardingCompleted": true
}
APPDATAEOF
	echo -e "${GREEN}✓ Data storage created${NC}"
fi

if [ ! -d "$WP_LATEST_DIR" ]; then
	echo ""
	echo -e "${YELLOW}Downloading latest WordPress...${NC}"
	TMP_DIR=$(mktemp -d)
	trap 'rm -rf "$TMP_DIR"' EXIT

	curl -sSL "https://wordpress.org/latest.zip" -o "$TMP_DIR/wordpress.zip"
	unzip -q "$TMP_DIR/wordpress.zip" -d "$TMP_DIR"

	mkdir -p "$WP_LATEST_DIR"
	cp -R "$TMP_DIR/wordpress/." "$WP_LATEST_DIR/"

	rm -rf "$TMP_DIR"
	trap - EXIT
	echo -e "${GREEN}✓ WordPress installed${NC}"
fi

if [ ! -d "$SQLITE_DIR" ]; then
	echo ""
	echo -e "${YELLOW}Downloading SQLite files...${NC}"
	TMP_DIR=$(mktemp -d)
	trap 'rm -rf "$TMP_DIR"' EXIT

	SQLITE_URL="https://github.com/WordPress/sqlite-database-integration/archive/refs/tags/${SQLITE_VERSION}.zip"
	curl -sSL "$SQLITE_URL" -o "$TMP_DIR/sqlite.zip"
	unzip -q "$TMP_DIR/sqlite.zip" -d "$TMP_DIR"

	EXTRACTED_NAME="sqlite-database-integration-${SQLITE_VERSION#v}"
	mkdir -p "$SQLITE_DIR"
	cp -R "$TMP_DIR/$EXTRACTED_NAME/." "$SQLITE_DIR/"

	rm -rf "$TMP_DIR"
	trap - EXIT
	echo -e "${GREEN}✓ SQLite files installed${NC}"
fi

if [ ! -d "$SQLITE_CMD_DIR" ]; then
	echo ""
	echo -e "${YELLOW}Downloading SQLite Command...${NC}"
	TMP_DIR=$(mktemp -d)
	trap 'rm -rf "$TMP_DIR"' EXIT

	SQLITE_CMD_URL=$(curl -sSL "https://api.github.com/repos/Automattic/wp-cli-sqlite-command/releases/latest" \
		-H "Accept: application/vnd.github.v3+json" -H "User-Agent: wp-now-cli" \
		| "$INSTALL_DIR/node/bin/node" -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>console.log(JSON.parse(d).assets[0].browser_download_url))")
	curl -sSL "$SQLITE_CMD_URL" -o "$TMP_DIR/sqlite-command.zip"

	mkdir -p "$SQLITE_CMD_DIR"
	unzip -q "$TMP_DIR/sqlite-command.zip" -d "$SQLITE_CMD_DIR"

	rm -rf "$TMP_DIR"
	trap - EXIT
	echo -e "${GREEN}✓ SQLite Command installed${NC}"
fi

if [ ! -f "$WP_CLI_PHAR" ]; then
	echo ""
	echo -e "${YELLOW}Downloading WP-CLI...${NC}"
	mkdir -p "$SERVER_FILES"
	curl -sSL "https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar" \
		-o "$WP_CLI_PHAR"
	echo -e "${GREEN}✓ WP-CLI installed${NC}"
fi

CLAUDE_CONFIG_DIR="$HOME/Library/Application Support/Claude"
CLAUDE_CONFIG="$CLAUDE_CONFIG_DIR/claude_desktop_config.json"
configure_claude() {
	mkdir -p "$CLAUDE_CONFIG_DIR"
	
	MCP_COMMAND="$INSTALL_DIR/bin/studio-mcp"
	
	if [ -f "$CLAUDE_CONFIG" ]; then
		if grep -q "wordpress-developer" "$CLAUDE_CONFIG"; then
			echo -e "${YELLOW}Updating existing Claude Desktop config...${NC}"
		else
			echo -e "${YELLOW}Adding to existing Claude Desktop config...${NC}"
		fi
		
		"$INSTALL_DIR/node/bin/node" -e "
const fs = require('fs');
const configPath = '$CLAUDE_CONFIG';
const mcpCommand = '$MCP_COMMAND';

let config = {};
try {
	config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
} catch (e) {
	config = {};
}

if (!config.mcpServers) {
	config.mcpServers = {};
}

config.mcpServers['wordpress-developer'] = {
	command: mcpCommand
};

fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
"
	else
		echo -e "${YELLOW}Creating Claude Desktop config...${NC}"
		cat > "$CLAUDE_CONFIG" << CONFIGEOF
{
  "mcpServers": {
	"wordpress-developer": {
	  "command": "$MCP_COMMAND"
	}
  }
}
CONFIGEOF
	fi
	
	echo -e "${GREEN}✓ Claude Desktop configured${NC}"
}

echo ""
echo -e "${YELLOW}Configuring Claude Desktop...${NC}"
configure_claude

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

echo ""
echo -e "${GREEN}✅ Installation complete!${NC}"
echo ""

if pgrep -x "Claude" > /dev/null; then
    echo -e "${YELLOW}⚠️  Claude Desktop is running.${NC}"
    echo ""
    echo -e "${YELLOW}Restart now? [Y/n]${NC}"
    read -r restart_response < /dev/tty
    
    if [[ ! "$restart_response" =~ ^[Nn]$ ]]; then
        echo -e "${YELLOW}Restarting Claude Desktop...${NC}"
        osascript -e 'quit app "Claude"'
        for i in $(seq 1 10); do
            pgrep -x "Claude" > /dev/null || break
            sleep 1
        done
        open -a "/Applications/Claude.app"
        echo -e "${GREEN}✓ Claude Desktop restarted${NC}"
    else
        echo ""
        echo -e "${YELLOW}⚠️  Please restart Claude Desktop manually to apply the MCP configuration.${NC}"
    fi
else
    echo "Start Claude Desktop to begin using WordPress Developer MCP! 🚀"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🌸 You're all set!${NC}"
echo ""
echo "Try asking Claude:"
echo "  \"Create a new WordPress site named 'Flowers Shop'\""
echo "  \"Install the WooCommerce plugin\""
echo "  \"Add one demo product to the shop named 'Sunflower'\""
echo "  \"Create shareable link for the shop\""
echo ""
echo -e "⭐ If you like it, star the repo: ${BLUE}https://github.com/nightnei/wordpress-developer-mcp-server${NC}"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""