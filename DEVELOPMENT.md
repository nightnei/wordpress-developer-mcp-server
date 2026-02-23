# Development

## Setup

1. Clone the repo and install dependencies:

```bash
npm install
```

2. Point Claude Desktop to your local build. Open the config file:

```
~/Library/Application Support/Claude/claude_desktop_config.json
```

Set the `command` to your local `node` and `args` to the built file:

```json
{
  "mcpServers": {
    "wordpress-developer": {
      "command": "node",
      "args": ["/absolute/path/to/wordpress-developer-mcp-server/dist/index.js"]
    }
  }
}
```

3. Start the watch build:

```bash
npm run build:watch
```

## Workflow

- **Inspector** — When using the MCP Inspector (`npm run inspect`) with `npm run build:watch`, click "Restart" in the Inspector UI after code changes. File rebuilds happen automatically, but the MCP server process must be restarted.
- **Claude Desktop** — After code changes, quit and reopen Claude Desktop. Restarting the connector alone is not reliable.
