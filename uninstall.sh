#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

INSTALL_DIR="$HOME/.wordpress-studio-mcp"
OLD_INSTALL_DIR="$HOME/.studio-mcp"
CLAUDE_CONFIG_DIR="$HOME/Library/Application Support/Claude"
CLAUDE_CONFIG="$CLAUDE_CONFIG_DIR/claude_desktop_config.json"
STUDIO_APPDATA_DIR="$HOME/Library/Application Support/Studio"
STUDIO_SITES_DIR="$HOME/Studio"
NODE_BIN="$INSTALL_DIR/node/bin/node"
STUDIO_CLI="$INSTALL_DIR/bin/studio-cli"

echo -e "${BLUE}${BOLD}🗑️ Uninstalling WordPress Developer MCP Server...${NC}"

delete_all_sites() {
	SITES_JSON=$("$STUDIO_CLI" site list --format=json 2>/dev/null || echo "[]")

	"$NODE_BIN" -e "
const { execSync } = require('child_process');
const cli = process.argv[1];
let sites = [];
try { sites = JSON.parse(process.argv[2]); } catch {}
if (!Array.isArray(sites) || sites.length === 0) {
	console.log('  No sites found. Skipping.');
	process.exit(0);
}
console.log('  Found ' + sites.length + ' site(s). Deleting...');
for (const site of sites) {
	try {
		console.log('  Deleting: ' + site.path);
		execSync(cli + ' site delete --path ' + JSON.stringify(site.path) + ' --files', { stdio: 'pipe' });
	} catch (e) {
		console.error('  Failed to delete: ' + site.path);
	}
}
" "$STUDIO_CLI" "$SITES_JSON"

	echo -e "${GREEN}✓ All sites deleted${NC}"
}

remove_mcp_from_claude_config() {
	if [ ! -f "$CLAUDE_CONFIG" ]; then
		echo -e "${YELLOW}Claude Desktop config not found. Skipping.${NC}"
		return
	fi

	if ! grep -qE "wordpress-(developer|studio)" "$CLAUDE_CONFIG"; then
		echo -e "${YELLOW}No MCP entry found in Claude Desktop config. Skipping.${NC}"
		return
	fi

	echo -e "${YELLOW}Removing MCP from Claude Desktop config...${NC}"

	"$NODE_BIN" -e "
const fs = require('fs');
const configPath = '$CLAUDE_CONFIG';
let config = {};
try {
	config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
} catch (e) {
	process.exit(0);
}
if (config.mcpServers) {
	delete config.mcpServers['wordpress-developer'];
	delete config.mcpServers['wordpress-studio'];
	fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
}
"

	echo -e "${GREEN}✓ MCP removed from Claude Desktop config${NC}"
}

if [ -x "$NODE_BIN" ] && [ ! -d "/Applications/Studio.app" ]; then
	SITES_COUNT=$("$NODE_BIN" -e "
let sites = [];
try { sites = JSON.parse(process.argv[1]); } catch {}
console.log(Array.isArray(sites) ? sites.length : 0);
" "$("$STUDIO_CLI" site list --format=json 2>/dev/null || echo "[]")")

	if [ "$SITES_COUNT" -gt 0 ] 2>/dev/null; then
		echo ""
		echo -e "${YELLOW}Found ${BOLD}${SITES_COUNT}${NC}${YELLOW} WordPress site(s) on your machine.${NC}"
		echo ""
		echo -e "  Delete them? If you choose to keep them, the site files"
		echo -e "  will remain in ${BOLD}${STUDIO_SITES_DIR}${NC}."
		echo ""
		echo -e "${GREEN}Delete sites? [y/N]${NC}"
		read -r delete_response < /dev/tty

		if [[ "$delete_response" =~ ^[Yy]$ ]]; then
			echo ""
			echo -e "${YELLOW}Deleting WordPress sites...${NC}"
			delete_all_sites
			if [ -d "$STUDIO_SITES_DIR" ]; then
				echo -e "${YELLOW}Removing sites directory...${NC}"
				rm -rf "$STUDIO_SITES_DIR"
				echo -e "${GREEN}✓ Sites directory removed ($STUDIO_SITES_DIR)${NC}"
			fi
		else
			echo -e "${YELLOW}Keeping sites.${NC}"
		fi
	fi
elif [ -d "/Applications/Studio.app" ]; then
	echo ""
	echo -e "${GREEN}🔗 WordPress Studio detected — sites created with Claude remain usable with the Studio app.${NC}"
fi

if [ -x "$NODE_BIN" ]; then
	echo ""
	remove_mcp_from_claude_config
fi

# Migration: clean up old install path (~/.studio-mcp -> ~/.wordpress-studio-mcp)
if [ -d "$OLD_INSTALL_DIR" ]; then
	rm -rf "$OLD_INSTALL_DIR"
fi

if [ -d "$INSTALL_DIR" ]; then
	echo ""
	echo -e "${YELLOW}Removing installation directory...${NC}"
	rm -rf "$INSTALL_DIR"
	echo -e "${GREEN}✓ Installation directory removed ($INSTALL_DIR)${NC}"
else
	echo ""
	echo -e "${YELLOW}Installation directory not found. Skipping.${NC}"
fi

if [ ! -d "/Applications/Studio.app" ] && [ -d "$STUDIO_APPDATA_DIR" ]; then
	echo ""
	echo -e "${YELLOW}⚠️  The folder ${BOLD}$STUDIO_APPDATA_DIR${NC}"
	echo -e "${YELLOW}   is also used by the WordPress ecosystem, specifically the${NC}"
	echo -e "${YELLOW}   WordPress Studio app (${BLUE}https://developer.wordpress.com/studio/${YELLOW}).${NC}"
	echo ""
	echo -e "${YELLOW}   WordPress Studio was not found on your system, so this folder${NC}"
	echo -e "${YELLOW}   can be safely removed.${NC}"
	echo ""
	echo -e "   If you confirm that you don't use the WordPress Studio app,"
	echo -e "   this folder will be cleaned up from your system."
	echo ""
	echo -e "${GREEN}Remove it? [y/N]${NC}"
	read -r remove_response < /dev/tty

	if [[ "$remove_response" =~ ^[Yy]$ ]]; then
		rm -rf "$STUDIO_APPDATA_DIR"
		echo -e "${GREEN}✓ Studio data directory removed${NC}"
	else
		echo -e "${YELLOW}Kept Studio data directory.${NC}"
	fi
fi

echo ""
echo -e "${GREEN}✅ Uninstall complete!${NC}"

if pgrep -x "Claude" > /dev/null; then
	echo ""
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
		echo -e "${YELLOW}⚠️  Please restart Claude Desktop manually to apply the changes.${NC}"
	fi
fi

echo ""
