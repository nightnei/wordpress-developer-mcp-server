#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

INSTALL_DIR="$HOME/.wordpress-developer-mcp"
NODE_BIN="$INSTALL_DIR/node/bin/node"

echo -e "${BLUE}${BOLD}🗑️  Uninstalling WordPress Developer MCP Server...${NC}"

app_installed() {
	[ -d "/Applications/$1" ] || [ -d "$HOME/Applications/$1" ]
}

# ── Remove MCP from all agents ────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}Removing MCP configuration from AI agents...${NC}"

remove_mcpservers_json() {
	local config_file="$1"
	[ -f "$config_file" ] || return 0
	"$NODE_BIN" -e "
const fs = require('fs');
const configPath = '$config_file';
let config = {};
try { config = JSON.parse(fs.readFileSync(configPath, 'utf8')); } catch (e) { process.exit(0); }
if (config.mcpServers) {
	delete config.mcpServers['wordpress-developer'];
	fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
}
" 2>/dev/null
}

if app_installed "Codex.app" || command -v codex &>/dev/null; then
	if command -v codex &>/dev/null; then
		codex mcp remove wordpress-developer &>/dev/null || true
	else
		"$NODE_BIN" -e "
const fs = require('fs');
const configPath = process.env.HOME + '/.codex/config.toml';
let content = '';
try { content = fs.readFileSync(configPath, 'utf8'); } catch (e) { process.exit(0); }
content = content.replace(/\[mcp_servers\.wordpress-developer\][^\[]*/, '');
fs.writeFileSync(configPath, content.trimEnd() + '\n');
" 2>/dev/null
	fi
	echo -e "  ${GREEN}✓${NC} Codex"
fi

if app_installed "Claude.app"; then
	remove_mcpservers_json "$HOME/Library/Application Support/Claude/claude_desktop_config.json"
	echo -e "  ${GREEN}✓${NC} Claude Desktop"
fi

if command -v claude &>/dev/null; then
	claude mcp remove wordpress-developer --scope user &>/dev/null || true
	echo -e "  ${GREEN}✓${NC} Claude Code (CLI)"
fi

if app_installed "Cursor.app"; then
	remove_mcpservers_json "$HOME/.cursor/mcp.json"
	echo -e "  ${GREEN}✓${NC} Cursor"
fi

if app_installed "Windsurf.app"; then
	remove_mcpservers_json "$HOME/.codeium/windsurf/mcp_config.json"
	echo -e "  ${GREEN}✓${NC} Windsurf"
fi

if app_installed "Zed.app" && [ -f "$HOME/.config/zed/settings.json" ]; then
	"$NODE_BIN" -e "
const fs = require('fs');
const configPath = process.env.HOME + '/.config/zed/settings.json';
let config = {};
try { config = JSON.parse(fs.readFileSync(configPath, 'utf8')); } catch (e) { process.exit(0); }
if (config.context_servers) {
	delete config.context_servers['wordpress-developer'];
	fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
}
" 2>/dev/null
	echo -e "  ${GREEN}✓${NC} Zed"
fi

# ── Remove install directory ──────────────────────────────────────────────────
echo ""
if [ -d "$INSTALL_DIR" ]; then
	echo -e "${YELLOW}Removing installation directory...${NC}"
	rm -rf "$INSTALL_DIR"
	echo -e "  ${GREEN}✓ $INSTALL_DIR removed${NC}"
else
	echo -e "  ${YELLOW}Installation directory not found. Skipping.${NC}"
fi

# ── Sites notice ──────────────────────────────────────────────────────────────
SITES_DIR="$HOME/Studio"
if [ -d "$SITES_DIR" ]; then
	echo ""
	echo -e "${BLUE}ℹ${NC}  Your WordPress sites are still available at ${BOLD}$SITES_DIR${NC}"
	echo "   If you no longer need them, you can remove them with:"
	echo -e "   ${YELLOW}rm -rf \"$SITES_DIR\"${NC}"
fi

# ── Restart reminder ──────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}✅ Uninstall complete!${NC}"
echo ""
echo -e "${YELLOW}↺  Restart these apps to apply the changes:${NC}"
app_installed "Claude.app"   && echo -e "  ${YELLOW}•${NC} Claude Desktop"
app_installed "Windsurf.app" && echo -e "  ${YELLOW}•${NC} Windsurf"
app_installed "Zed.app"      && echo -e "  ${YELLOW}•${NC} Zed"
app_installed "Codex.app"    && echo -e "  ${YELLOW}•${NC} Codex"
echo ""
