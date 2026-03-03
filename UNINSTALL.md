# Uninstalling WordPress Developer MCP Server

We recommend manual uninstallation to avoid any edge cases. The steps are straightforward and listed below. That said, the automated script is tested and should work well if you prefer a one-liner.

## Automated uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/nightnei/wordpress-developer-mcp-server/main/uninstall.sh | bash
```

## Manual uninstall

### 1. Remove the MCP entry from Claude Desktop config

Open the config file:

```
~/Library/Application Support/Claude/claude_desktop_config.json
```

Find and delete the `"wordpress-developer"` entry from the `"mcpServers"` object:

```json
{
  "mcpServers": {
    "wordpress-developer": {   ← remove this entire block
      "command": "..."
    }
  }
}
```

### 2. Remove the installation directory

```bash
rm -rf ~/.wordpress-studio-mcp
```

This contains the bundled Node.js runtime, MCP server, CLI, and bin scripts.

### 3. Remove the sites directory

```bash
rm -rf ~/Studio
```

This is where WordPress sites created by the MCP server are stored.

### 4. (Optional) Remove the Studio data directory

> **Note:** This folder is also used by the [WordPress Studio](https://developer.wordpress.com/studio/) desktop app. Only remove it if you do **not** have WordPress Studio installed.

```bash
rm -rf ~/Library/Application\ Support/Studio
```

This contains `appdata-v1.json`, WordPress core files, SQLite integration, and WP-CLI.

### 5. Restart Claude Desktop

Restart Claude Desktop so it picks up the config change. You can do this from the menu bar or by running:

```bash
osascript -e 'quit app "Claude"' && open -a "/Applications/Claude.app"
```
