# WordPress Studio MCP Server

This project connects [WordPress Studio](https://developer.wordpress.com/studio/) with AI tools via the **Model Context Protocol (MCP)**

It enables AI assistants (such as **Claude Desktop**) to:

- inspect local WordPress Studio sites and safely read project files
- manage preview sites (more actions will be added as they become available in the Studio CLI)

Everything runs **locally** and is powered by the official **Studio CLI**.

### Demo tools

**[Watch the demo video](demos/studio_mcp_demo_tools.mp4)**

### Demo prompts

At the moment, the project includes a single demo prompt.
It is provided mainly to demonstrate the MVP and to show basic capabilities such as interacting with Studio and reading the local filesystem.

This prompt is intended purely as a demonstration and will be **expanded, refined, or replaced** with more realistic use cases in the future.
**[Watch the demo video](demos/studio_mcp_demo_prompts.mp4)**

### Demo resources

**[Watch the demo video](demos/studio_mcp_demo_resources.mp4)**

## Setup

To use this MCP server, you need the **WordPress Studio CLI** available on your machine.

1. Download and install **Studio**: https://developer.wordpress.com/studio/
2. Open **Studio**
3. Go to **Settings**
4. Open the **Preferences** tab
5. Enable the checkbox: **“Enable the studio command in the terminal”**

You can verify it works by running: `studio --version`

## Integrate with Claude Desktop

1. Build the MCP server: `npm run build`
2. Open **Claude Desktop** -> **Settings**
3. Go to **Developer** -> **Edit Config**
4. Add the MCP server entry:

```json
"wordpress-studio-mcp-server": {
	"command": "node",
	"args": [ "/ABSOLUTE/PATH/TO/wordpress-studio-mcp-server/build/index.js" ]
}
```

5. Quit and reopen Claude Desktop

After restart, Claude will be able to use the Studio MCP tools.

## Development notes:

1. Inspector
   - When using the MCP Inspector together with `npm run build:watch`, click “Restart” in the Inspector UI after code changes.
   - File rebuilds happen automatically, but the MCP server process must be restarted.
2. Claude Desktop
   - When developing with `npm run build:watch`, you should quit and reopen Claude Desktop after code changes.
   - Restarting the connector alone may sometimes work (I encountered it a few times), but it is not reliable.

## ⚠️ Platform support

This project is currently an **MVP** and officially supports **macOS only**.

> Windows support is **not available yet**, but will be added soon.
