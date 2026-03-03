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