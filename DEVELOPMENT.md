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
      "args": ["/absolute/path/to/wordpress-studio-mcp-server/dist/index.js"]
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

## Production build

The production build sets `__STUDIO_CLI_PRODUCTION__=true`, which switches the CLI path to `~/.studio-mcp/bin/studio-cli` (the bundled binary installed by `install.sh`). During development, the CLI falls back to the `studio` command on your PATH.

```bash
npm run build
```
