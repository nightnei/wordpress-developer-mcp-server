#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

INSTALL_DIR="$HOME/.studio-mcp"
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

	if ! grep -q "wordpress-developer" "$CLAUDE_CONFIG"; then
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
if (config.mcpServers && config.mcpServers['wordpress-developer']) {
	delete config.mcpServers['wordpress-developer'];
	fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
}
"

	echo -e "${GREEN}✓ MCP removed from Claude Desktop config${NC}"
}

if [ -x "$NODE_BIN" ]; then
	echo ""
	echo -e "${YELLOW}Cleaning up WordPress sites...${NC}"
	delete_all_sites
fi

if [ -d "$STUDIO_SITES_DIR" ]; then
	echo ""
	echo -e "${YELLOW}Removing sites directory...${NC}"
	rm -rf "$STUDIO_SITES_DIR"
	echo -e "${GREEN}✓ Sites directory removed ($STUDIO_SITES_DIR)${NC}"
fi

if [ -x "$NODE_BIN" ]; then
	echo ""
	remove_mcp_from_claude_config
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

