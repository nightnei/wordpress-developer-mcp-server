# Development

## Setup

1. Clone the repo and install dependencies:

```bash
npm install
```

2. Point your AI assistant to your local build. For Claude Desktop, open:

```
~/Library/Application Support/Claude/claude_desktop_config.json
```

For other MCP-compatible assistants, add the same entry to their MCP configuration.

Set the `command` to your local `node` and `args` to the built file. In dev mode the server uses the global `studio` command by default. To use a custom CLI binary, set `STUDIO_CLI_PATH` in `env`:

```json
{
  "mcpServers": {
    "wordpress-studio": {
      "command": "node",
      "args": ["/absolute/path/to/wordpress-developer-mcp-server/dist/index.js"],
      "env": {
        "STUDIO_CLI_PATH": "/path/to/custom/studio-cli"
      }
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
- **AI Assistants** — After code changes, restart your AI assistant. For Claude Desktop, quit and reopen it — restarting the connector alone is not reliable.

## Releasing

Releases are automated with [Release Please](https://github.com/googleapis/release-please) and [Conventional Commits](https://www.conventionalcommits.org/).

### Commit message format

Use conventional commit prefixes to control version bumps:

| Prefix | Version bump | Example |
|---|---|---|
| `fix:` | Patch (1.0.0 → 1.0.1) | `fix: crash on empty site list` |
| `feat:` | Minor (1.0.0 → 1.1.0) | `feat: add theme management tools` |
| `feat!:` or `BREAKING CHANGE:` | Major (1.0.0 → 2.0.0) | `feat!: rename all tool IDs` |

Commits without a conventional prefix (e.g. `chore:`, `docs:`, `refactor:`) don't trigger a version bump but will still appear in the changelog if included in a release.

### How it works

1. Push commits to `main` (directly or via merged PRs).
2. A release PR is automatically opened with a version bump and changelog. New commits update the same PR.
3. Merge the release PR when you're ready to release.
4. A GitHub Release is created.
5. Users running `install.sh` automatically get the latest release.