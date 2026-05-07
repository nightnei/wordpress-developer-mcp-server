# WordPress Developer MCP Server

## Project Overview

This repository builds and ships a standalone MCP server that lets AI assistants manage local WordPress sites. The TypeScript source lives in `src/`, the bundled release entrypoint is `dist/index.js`, and the macOS/Windows installers wire the bundled server into supported AI apps.

Release artifacts contain only the bundled server file from `dist/`, so changes to `src/` must be followed by `npm run build`.

## Common Commands

- Install dependencies: `npm ci`
- Build release bundle: `npm run build`
- Typecheck: `npm run typecheck`
- Inspect MCP server locally: `npm run inspect`
- Shell syntax checks: `bash -n install.sh` and `bash -n uninstall.sh`

If PowerShell is available, parse-check the Windows scripts after editing them:

```powershell
$errors = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile("install.ps1", [ref]$null, [ref]$errors)
if ($errors.Count) { $errors | ForEach-Object { Write-Error $_ }; exit 1 }
$null = [System.Management.Automation.Language.Parser]::ParseFile("uninstall.ps1", [ref]$null, [ref]$errors)
if ($errors.Count) { $errors | ForEach-Object { Write-Error $_ }; exit 1 }
```

## Code Style

- Use TypeScript ESM imports and keep `strict` typechecking clean.
- Match the existing formatting: tabs for indentation, single quotes, semicolons.
- Keep comments short and only where they explain non-obvious platform behavior or workarounds.
- Prefer existing helper patterns over new abstractions.
- Keep installer changes conservative; they run on user machines and should be easy to audit.

## Architecture Notes

- `src/index.ts` creates the MCP server and concatenates always-on server instructions.
- `src/tools/` contains tool registrations grouped by feature area.
- `src/lib/studio-cli.ts` owns Studio CLI process execution. Windows `.cmd` behavior is delicate; do not simplify it without retesting Windows.
- `src/lib/package.ts` derives MCP `serverInfo.version` from `package.json`.
- `install.sh` is macOS-focused. `install.ps1` is Windows-focused and also supports the programmatic `-Update` path used by the MCP update tool.
- Update mode should refresh runtime/server/wrappers only; avoid auth prompts or app configuration during programmatic updates.

## Installer Configuration Rules

- Agent configuration formats differ. Do not reuse one JSON shape for every app.
- Claude Desktop, Cursor, and Windsurf use `mcpServers`.
- VS Code uses `servers` with entries shaped as `{ "type": "stdio", "command": "...", "args": [] }`.
- Zed uses `context_servers`.
- Codex uses TOML when the CLI is unavailable.
- Keep uninstallers symmetric with installers and remove empty wrapper objects where existing code already does so.
- Do not delete the user's sites. Windows uninstall intentionally leaves the install directory for manual removal.

## Verification Expectations

Before finishing code changes, run the narrowest meaningful verification. For most changes in this repo, run:

```bash
npm run build
npm run typecheck
```

For installer changes, also run:

```bash
bash -n install.sh
bash -n uninstall.sh
```

If a check cannot be run in the current environment, say exactly which check was skipped and why.

## Release Flow

Releases are automated with Release Please. Conventional commit prefixes drive version bumps:

- `fix:` for patch releases
- `feat:` for minor releases
- `feat!:` or `BREAKING CHANGE:` for major releases

After Release Please opens and merges a release PR, GitHub Actions builds `dist/index.js`, packages it, and attaches it to the GitHub release.

## Pull Requests

When asked to prepare a PR, do the full PR preparation work unless the user asks only for a summary.

Before opening a PR:

- Keep the PR focused on one logical change.
- Do not include unrelated formatting, dependency, lockfile, or generated-file changes unless required.
- Run the relevant verification commands and include the results in the PR body.
- If a verification step cannot be run, explain why in the PR body.

Use Conventional Commit-style PR titles:

- `fix: ...` for bug fixes.
- `feat: ...` for user-visible behavior or capability.
- `docs: ...` for documentation-only changes.
- `chore: ...` for maintenance that should not trigger a release.
- `refactor: ...` for internal code changes without behavior changes.

Use this PR body structure:

```md
## Summary

- ...

## Verification

- [x] `npm run build`
- [x] `npm run typecheck`

## Platform Notes

- macOS:
- Windows:
```

Because this repo uses Release Please, choose the PR title prefix deliberately:

- Use `fix:` when the PR should create a patch release.
- Use `feat:` when it should create a minor release.
- Use `chore:`, `docs:`, or `refactor:` when it should not force a release by itself.
