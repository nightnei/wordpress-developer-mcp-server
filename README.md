# WordPress Studio MCP Server

This project connects [WordPress Studio](https://developer.wordpress.com/studio/) with AI tools via the **Model Context Protocol (MCP)**.

It enables AI assistants (such as **Claude Desktop**) to manage local WordPress sites with natural language:

### 🛠 Site Management

- List, create, start, stop, and delete WordPress sites
- Configure PHP/WordPress versions, custom domains, HTTPS, Xdebug
- Check site status and authentication

### 📁 File System Operations

- List directories, read, write, and delete files
- Safely sandboxed to site directories only

### 🌐 Preview Sites

- Create, update, list, and delete shareable preview links (\*.wp.build)

### ⚡ WP-CLI Integration

- Full access to WP-CLI commands: plugins, themes, posts, pages, users, options, database, and more
- Install plugins, create content, manage settings — all through natural language

## Demo

[![Watch the demo](https://img.youtube.com/vi/so5iux5EEqU/maxresdefault.jpg)](https://youtu.be/so5iux5EEqU)

## Pre-setup
1. Node.js
Verify your Node.js installation by opening a terminal or command prompt and running:
```bash
node --version
```
If Node.js is not installed, download it from [nodejs.org](https://nodejs.org/).
2. Studio CLI (Note: this will be unnecessary soon, when Studio CLI becomes a standalone npm package, and it will be included in the MCP)

1. Download and install [Studio](https://developer.wordpress.com/studio/):
2. Open **Studio**
3. Go to **Settings** → **Preferences**
4. Enable checkbox: **"Enable the studio command in the terminal"**

Verify it works:

```bash
studio --version
```

## Integrate with Claude Desktop or Cursor

No `npm install` or build step required — `dist/index.js` is a pre-built, self-contained bundle.

1. Open the MCP server configuration:

   - **Claude Desktop**: **Settings** → **Developer** → **Edit Config**
   - **Cursor**: **Settings** → **Cursor Settings** → **Tools and MCP** → **New MCP Server**

2. Add the MCP server entry:

```json
{
	"mcpServers": {
		"wordpress-studio-mcp-server": {
			"command": "node",
			"args": [ "/ABSOLUTE/PATH/TO/wordpress-studio-mcp-server/dist/index.js" ]
		}
	}
}
```

3. Quit and reopen the app

## Available Tools

| Category     | Tools                                                                                                                                            |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Sites**    | `studio_site_list`, `studio_site_status`, `studio_site_start`, `studio_site_stop`, `studio_site_create`, `studio_site_delete`, `studio_site_set` |
| **Files**    | `studio_fs_list_dir`, `studio_fs_read_file`, `studio_fs_write_file`, `studio_fs_delete`                                                          |
| **Previews** | `studio_preview_list`, `studio_preview_create`, `studio_preview_update`, `studio_preview_delete`                                                 |
| **Auth**     | `studio_auth_status`, `studio_auth_logout`                                                                                                       |
| **WP-CLI**   | `studio_wp` — run any WP-CLI command (plugins, themes, posts, users, options, etc.)                                                              |

## Development notes:

1. Inspector
   - When using the MCP Inspector together with `npm run build:watch`, click “Restart” in the Inspector UI after code changes.
   - File rebuilds happen automatically, but the MCP server process must be restarted.
2. Claude Desktop
   - When developing with `npm run build:watch`, you should quit and reopen Claude Desktop after code changes.
   - Restarting the connector alone may sometimes work (I encountered it a few times), but it is not reliable.

## ⚠️ Platform support

This project officially supports **macOS only**.

> Windows support is **not available yet**, but will be added soon.
