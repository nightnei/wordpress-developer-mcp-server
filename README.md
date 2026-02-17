# WordPress Studio MCP Server

Build, manage, and develop WordPress sites by simply asking AI.

This [MCP server](https://modelcontextprotocol.io/) gives AI assistants full control over your local WordPress sites. See [TOOLS.md](TOOLS.md) for a full list of capabilities.

## Demo

[![Watch the demo](https://img.youtube.com/vi/so5iux5EEqU/maxresdefault.jpg)](https://youtu.be/so5iux5EEqU)

## Setup

### Step 1 — Install an AI assistant

Pick one (or both):

- [Claude Desktop](https://claude.ai/download)
- [Cursor](https://www.cursor.com/)

### Step 2 — Install WordPress Studio

1. Download and install **Studio**: https://developer.wordpress.com/studio/
2. Open **Studio** → **Settings** → **Preferences**
3. Enable **"Enable the studio command in the terminal"**
4. Verify it works:

```bash
studio --version
```

### Step 3 — Connect the MCP server

1. Open your AI assistant's MCP configuration:

   - **Claude Desktop**: Settings → Developer → Edit Config
   - **Cursor**: Settings → Cursor Settings → Tools and MCP → New MCP Server

2. Add the server entry:

```json
{
  "mcpServers": {
    "wordpress-studio-mcp-server": {
      "command": "node",
      "args": ["/ABSOLUTE/PATH/TO/wordpress-studio-mcp-server/dist/index.js"]
    }
  }
}
```

3. **Restart** the app (quit and reopen).

### Step 4 — Try it out!

Ask your AI assistant something like:

- *"Create a new WordPress site called My Blog"*
- *"Change the color palette to dark mode"*
- *"Install the WooCommerce plugin"*
- *"Create a new page called About Us with some placeholder content"*

## ⚠️ Platform support

This project officially supports **macOS only**.

> Windows support is **not available yet**, but will be added soon.
