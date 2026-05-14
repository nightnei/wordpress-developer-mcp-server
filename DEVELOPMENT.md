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

Set the `command` to your local `node` and `args` to the built file. In dev mode the server uses the global `studio` command by default. To use a custom CLI binary, set `STUDIO_CLI_PATH` in `env`:

```json
{
  "mcpServers": {
    "wordpress-developer": {
      "command": "node",
      "args": ["/absolute/path/to/wordpress-developer-mcp-server/dist/index.cjs"],
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

## Testing in Installed AI Apps

If you already ran the normal installer, build directly into the installed MCP location:

```bash
npm run dev:build:watch:macos
```

On Windows:

```powershell
npm run dev:build:watch:windows
```

These are regular esbuild watch commands that write to the installed MCP server entrypoint:

- macOS: `$HOME/.wordpress-developer-mcp/mcp/index.cjs`
- Windows: `%USERPROFILE%\.wordpress-developer-mcp\mcp\index.cjs`

They assume the installer already created the Node runtime, Studio CLI wrapper, MCP wrapper, and AI app configuration.

Restart the AI app after rebuilds. Existing configs that point to `~/.wordpress-developer-mcp/bin/wpdev-mcp` will then use your local branch.

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
5. Users running `install.sh` or `install.ps1` automatically get the latest release.
