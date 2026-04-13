#Requires -Version 5.1
<#
.SYNOPSIS
  Installs WordPress Developer MCP Server on Windows (parity with install.sh on macOS).
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Write-ColorLine {
	param(
		[string] $Message,
		[string] $ForegroundColor = 'White'
	)
	Write-Host $Message -ForegroundColor $ForegroundColor
}

$InstallDir = Join-Path $env:USERPROFILE '.wordpress-developer-mcp'
$McpRepo = 'nightnei/wordpress-developer-mcp-server'
$NodeVersion = '24.13.1'

$NodeBin = Join-Path $InstallDir 'node\node.exe'
$NpmBin = Join-Path $InstallDir 'node\npm.cmd'
$BinDir = Join-Path $InstallDir 'bin'
$McpCommand = Join-Path $BinDir 'studio-mcp.cmd'

Write-ColorLine "`n🌸 Installing WordPress Developer MCP Server..." Cyan
Write-ColorLine "Turn your AI into a full-stack WordPress developer.`n" Green

# ── OS check ──────────────────────────────────────────────────────────────────
if ($env:OS -ne 'Windows_NT') {
	Write-Host ""
	Write-ColorLine "❌ This installer is for Windows only." Red
	exit 1
}

$procArch = $env:PROCESSOR_ARCHITECTURE
$nodeArch = switch ($procArch) {
	'AMD64' { 'x64' }
	'ARM64' { 'arm64' }
	default { $null }
}
if (-not $nodeArch) {
	Write-Host ""
	Write-ColorLine "❌ Unsupported CPU architecture: $procArch (need AMD64 or ARM64)." Red
	exit 1
}

Write-Host ""
Write-ColorLine "✓ Detected: Windows on $procArch" Green

$studioHints = @(
	(Join-Path $env:LOCALAPPDATA 'Programs\WordPress Studio'),
	(Join-Path ${env:ProgramFiles} 'WordPress Studio'),
	(Join-Path ${env:ProgramFiles(x86)} 'WordPress Studio')
)
$studioFound = $studioHints | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($studioFound) {
	Write-Host ""
	Write-ColorLine "🔗 WordPress Studio detected on your machine!" Green
	Write-Host "  The MCP server will sync with Studio, so you can work"
	Write-Host "  on both at the same time — your sites and data stay in sync."
}

# ── Supported agents ──────────────────────────────────────────────────────────
Write-Host ""
Write-ColorLine "Supported AI agents:" Cyan
Write-Host "  • Codex (app + CLI)"
Write-Host "  • Claude Desktop"
Write-Host "  • Claude Code (CLI)"
Write-Host "  • Cursor"
Write-Host "  • Windsurf"
Write-Host "  • Zed"

# ── Detect installed agents ───────────────────────────────────────────────────
Write-Host ""
Write-ColorLine "Detecting installed AI agents..." Yellow

function Test-AppFolder {
	param([string[]] $RelativePaths)
	foreach ($rel in $RelativePaths) {
		$candidates = @(
			(Join-Path $env:LOCALAPPDATA "Programs\$rel"),
			(Join-Path ${env:ProgramFiles} $rel),
			(Join-Path ${env:ProgramFiles(x86)} $rel)
		)
		foreach ($p in $candidates) {
			if (Test-Path -LiteralPath $p) { return $true }
		}
	}
	return $false
}

function Test-CommandExists {
	param([string] $Name)
	return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

$foundCodex = (Test-CommandExists 'codex') -or (Test-AppFolder @('Codex', 'OpenAI Codex'))
$foundClaudeDesktop = Test-AppFolder @('Claude', 'AnthropicClaude')
$foundClaudeCode = Test-CommandExists 'claude'
$foundCursor = Test-AppFolder @('cursor', 'Cursor')
$foundWindsurf = Test-AppFolder @('Windsurf')
$foundZed = Test-AppFolder @('Zed', 'zed')

$foundAgents = @()
if ($foundCodex) { $foundAgents += 'Codex' }
if ($foundClaudeDesktop) { $foundAgents += 'Claude Desktop' }
if ($foundClaudeCode) { $foundAgents += 'Claude Code' }
if ($foundCursor) { $foundAgents += 'Cursor' }
if ($foundWindsurf) { $foundAgents += 'Windsurf' }
if ($foundZed) { $foundAgents += 'Zed' }
$foundAgentsCount = $foundAgents.Count

Write-Host ""
if ($foundAgentsCount -eq 0) {
	Write-ColorLine "⚠️  No supported AI agents found on your system." Yellow
	Write-Host "  The MCP server will still be installed."
	Write-Host "  Install any supported agent and re-run this script."
	Write-Host ""
	Write-ColorLine "  Get Codex:          https://openai.com/codex" Blue
	Write-ColorLine "  Get Claude:         https://claude.ai/download" Blue
	Write-ColorLine "  Get Cursor:         https://cursor.com" Blue
	Write-ColorLine "  Get Windsurf:       https://windsurf.com" Blue
	Write-ColorLine "  Get Zed:            https://zed.dev" Blue
}
else {
	Write-ColorLine "Found $foundAgentsCount AI agent(s):" Green
	if ($foundCodex) { Write-ColorLine "  ✓ Codex" Green }
	if ($foundClaudeDesktop) { Write-ColorLine "  ✓ Claude Desktop" Green }
	if ($foundClaudeCode) { Write-ColorLine "  ✓ Claude Code (CLI)" Green }
	if ($foundCursor) { Write-ColorLine "  ✓ Cursor" Green }
	if ($foundWindsurf) { Write-ColorLine "  ✓ Windsurf" Green }
	if ($foundZed) { Write-ColorLine "  ✓ Zed" Green }
	Write-Host ""
	Write-Host "  MCP support will be added to all of them."
}

New-Item -ItemType Directory -Force -Path (Join-Path $InstallDir 'node') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $InstallDir 'mcp') | Out-Null
New-Item -ItemType Directory -Force -Path $BinDir | Out-Null

# ── Node.js runtime ───────────────────────────────────────────────────────────
Write-Host ""
Write-ColorLine "Checking runtime environment..." Yellow

$currentNodeVersion = $null
if (Test-Path -LiteralPath $NodeBin) {
	try {
		$v = & $NodeBin --version 2>$null
		if ($v) { $currentNodeVersion = ($v -replace '^v', '').Trim() }
	}
	catch { }
}

if ($currentNodeVersion -eq $NodeVersion) {
	Write-ColorLine "✓ Runtime environment already installed" Green
}
else {
	Write-ColorLine "Downloading runtime environment..." Yellow
	$nodeDir = Join-Path $InstallDir 'node'
	Remove-Item -LiteralPath $nodeDir -Recurse -Force -ErrorAction SilentlyContinue
	New-Item -ItemType Directory -Force -Path $nodeDir | Out-Null

	$nodeZipName = "node-v$NodeVersion-win-$nodeArch.zip"
	$nodeUrl = "https://nodejs.org/dist/v$NodeVersion/$nodeZipName"
	$zipPath = Join-Path $env:TEMP $nodeZipName
	Invoke-WebRequest -Uri $nodeUrl -OutFile $zipPath -UseBasicParsing

	$extractRoot = Join-Path $env:TEMP "node-extract-$([Guid]::NewGuid().ToString('N'))"
	New-Item -ItemType Directory -Force -Path $extractRoot | Out-Null
	try {
		Expand-Archive -LiteralPath $zipPath -DestinationPath $extractRoot -Force
		$inner = Get-ChildItem -LiteralPath $extractRoot -Directory | Select-Object -First 1
		if (-not $inner) { throw "Unexpected Node.js zip layout (no top-level folder)." }
		Copy-Item -Path (Join-Path $inner.FullName '*') -Destination $nodeDir -Recurse -Force
	}
	finally {
		Remove-Item -LiteralPath $extractRoot -Recurse -Force -ErrorAction SilentlyContinue
		Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
	}

	Write-ColorLine "✓ Runtime environment installed" Green
}

# ── MCP Server (release tarball) ─────────────────────────────────────────────
Write-Host ""
Write-ColorLine "Checking MCP Server..." Yellow

$headers = @{ Accept = 'application/vnd.github.v3+json' }
$release = Invoke-RestMethod -Uri "https://api.github.com/repos/$McpRepo/releases/latest" -Headers $headers
$mcpLatest = $release.tag_name

$versionFile = Join-Path $InstallDir 'mcp\.version'
$currentMcpVersion = if (Test-Path -LiteralPath $versionFile) {
	(Get-Content -LiteralPath $versionFile -Raw).Trim()
}
else { '' }

if ($currentMcpVersion -eq $mcpLatest) {
	Write-ColorLine "✓ MCP Server already up to date" Green
}
else {
	Write-ColorLine "Downloading MCP Server..." Yellow
	$mcpDir = Join-Path $InstallDir 'mcp'
	Remove-Item -LiteralPath $mcpDir -Recurse -Force -ErrorAction SilentlyContinue
	New-Item -ItemType Directory -Force -Path $mcpDir | Out-Null

	$tarName = "wordpress-developer-mcp-server-$mcpLatest.tar.gz"
	$tarUrl = "https://github.com/$McpRepo/releases/download/$mcpLatest/$tarName"
	$tarPath = Join-Path $env:TEMP $tarName
	Invoke-WebRequest -Uri $tarUrl -OutFile $tarPath -UseBasicParsing

	$tarExe = Get-Command tar -ErrorAction SilentlyContinue
	if (-not $tarExe) {
		Write-ColorLine "❌ Built-in tar.exe not found. Install Windows 10+ or add tar to PATH." Red
		exit 1
	}
	& tar.exe -xzf $tarPath -C $mcpDir
	Remove-Item -LiteralPath $tarPath -Force -ErrorAction SilentlyContinue

	Set-Content -LiteralPath $versionFile -Value $mcpLatest -NoNewline
	if ($currentMcpVersion) {
		Write-ColorLine "✓ MCP Server updated to $mcpLatest" Green
	}
	else {
		Write-ColorLine "✓ MCP Server installed" Green
	}
}

# ── Studio CLI (wp-studio) ────────────────────────────────────────────────────
Write-Host ""
Write-ColorLine "Checking Studio CLI..." Yellow

$nodeDirForPath = Join-Path $InstallDir 'node'
$env:PATH = "$nodeDirForPath;$env:PATH"

$studioLatest = ''
try {
	$studioLatest = (& $NpmBin view wp-studio version --loglevel=silent 2>$null | Out-String).Trim()
}
catch { }

$currentStudioVersion = ''
try {
	$listOut = & $NpmBin list -g wp-studio --depth=0 --loglevel=silent 2>&1 | Out-String
	if ($listOut -match 'wp-studio@([^\s\r\n]+)') {
		$currentStudioVersion = $Matches[1].Trim()
	}
}
catch { }

if ($currentStudioVersion -and $studioLatest -and ($currentStudioVersion -eq $studioLatest)) {
	Write-ColorLine "✓ Studio CLI already up to date" Green
}
else {
	Write-ColorLine "Installing Studio CLI..." Yellow
	$npmLog = & $NpmBin install -g wp-studio --loglevel=silent 2>&1
	$npmLog | Where-Object { $_ -match 'error' } | ForEach-Object { Write-Host $_ }
	if ($currentStudioVersion) {
		Write-ColorLine "✓ Studio CLI updated to $studioLatest" Green
	}
	else {
		Write-ColorLine "✓ Studio CLI installed" Green
	}
}

# ── Wrapper scripts (always regenerated) ─────────────────────────────────────
Write-Host ""
Write-ColorLine "Creating wrapper scripts..." Yellow

$mcpJs = Join-Path $InstallDir 'mcp\index.js'
$studioCliCmd = Join-Path $BinDir 'studio-cli.cmd'

$studioMcpContent = @"
@echo off
setlocal
set "STUDIO_CLI_PATH=$studioCliCmd"
"$NodeBin" "$mcpJs" %*
"@

$studioCliContent = @"
@echo off
setlocal
set "PATH=$nodeDirForPath;%PATH%"
where studio >nul 2>&1
if %ERRORLEVEL% equ 0 (
  studio %*
) else (
  "$nodeDirForPath\studio.cmd" %*
)
"@

Set-Content -LiteralPath $McpCommand -Value $studioMcpContent -Encoding ASCII
Set-Content -LiteralPath $studioCliCmd -Value $studioCliContent -Encoding ASCII

Write-ColorLine "✓ Wrapper scripts ready" Green

# ── Configure AI agents ───────────────────────────────────────────────────────
$configuredAgents = [System.Collections.Generic.List[string]]::new()
$failedAgents = [System.Collections.Generic.List[string]]::new()

function Invoke-ConfigureMcpServersJson {
	param([string] $ConfigFile)
	$dir = Split-Path -Parent $ConfigFile
	if (-not (Test-Path -LiteralPath $dir)) {
		New-Item -ItemType Directory -Force -Path $dir | Out-Null
	}
	$env:WPMCP_CONFIG_FILE = $ConfigFile
	$env:WPMCP_MCP_COMMAND = $McpCommand
	$script = @'
const fs = require('fs');
const configPath = process.env.WPMCP_CONFIG_FILE;
const mcpCommand = process.env.WPMCP_MCP_COMMAND;
let config = {};
try {
  config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
} catch (e) {
  config = {};
}
if (!config.mcpServers) config.mcpServers = {};
config.mcpServers['wordpress-developer'] = { command: mcpCommand };
fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
'@
	& $NodeBin -e $script
	if ($LASTEXITCODE) { throw "Failed to update MCP config: $ConfigFile" }
}

function Invoke-ConfigureCodexToml {
	$configFile = Join-Path $env:USERPROFILE '.codex\config.toml'
	$dir = Split-Path -Parent $configFile
	if (-not (Test-Path -LiteralPath $dir)) {
		New-Item -ItemType Directory -Force -Path $dir | Out-Null
	}
	$env:WPMCP_CONFIG_FILE = $configFile
	$env:WPMCP_MCP_COMMAND = $McpCommand
	$script = @'
const fs = require('fs');
const configPath = process.env.WPMCP_CONFIG_FILE;
const mcpCommand = process.env.WPMCP_MCP_COMMAND.replace(/\\/g, '/');
let content = '';
try { content = fs.readFileSync(configPath, 'utf8'); } catch (e) { content = ''; }
const newEntry = '[mcp_servers.wordpress-developer]\ncommand = "' + mcpCommand + '"';
const sectionRegex = /\[mcp_servers\.wordpress-developer\][^\[]*/;
if (sectionRegex.test(content)) {
  content = content.replace(sectionRegex, newEntry + '\n\n');
} else {
  content = (content.trimEnd() ? content.trimEnd() + '\n\n' : '') + newEntry + '\n';
}
fs.writeFileSync(configPath, content);
'@
	& $NodeBin -e $script
	if ($LASTEXITCODE) { throw 'Failed to update Codex config.toml' }
}

function Invoke-ConfigureZed {
	$configFile = Join-Path $env:APPDATA 'Zed\settings.json'
	$dir = Split-Path -Parent $configFile
	if (-not (Test-Path -LiteralPath $dir)) {
		New-Item -ItemType Directory -Force -Path $dir | Out-Null
	}
	$env:WPMCP_CONFIG_FILE = $configFile
	$env:WPMCP_MCP_COMMAND = $McpCommand
	$script = @'
const fs = require('fs');
const configPath = process.env.WPMCP_CONFIG_FILE;
const mcpCommand = process.env.WPMCP_MCP_COMMAND;
let config = {};
try {
  config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
} catch (e) {
  config = {};
}
if (!config.context_servers) config.context_servers = {};
config.context_servers['wordpress-developer'] = {
  source: 'custom',
  command: mcpCommand,
  args: []
};
fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
'@
	& $NodeBin -e $script
	if ($LASTEXITCODE) { throw 'Failed to update Zed settings.json' }
}

if ($foundAgentsCount -gt 0) {
	Write-Host ""
	Write-ColorLine "Configuring AI agents..." Yellow

	if ($foundCodex) {
		try {
			if (Test-CommandExists 'codex') {
				& codex mcp remove wordpress-developer 2>$null | Out-Null
				& codex mcp add wordpress-developer -- $McpCommand 2>$null | Out-Null
				if ($LASTEXITCODE) { throw 'codex mcp add failed' }
			}
			else {
				Invoke-ConfigureCodexToml
			}
			$configuredAgents.Add('Codex') | Out-Null
			Write-ColorLine "  ✓ Codex" Green
		}
		catch {
			$failedAgents.Add('Codex') | Out-Null
			Write-ColorLine "  ✗ Codex (failed)" Red
		}
	}

	if ($foundClaudeDesktop) {
		try {
			$claudeCfg = Join-Path $env:APPDATA 'Claude\claude_desktop_config.json'
			Invoke-ConfigureMcpServersJson -ConfigFile $claudeCfg
			$configuredAgents.Add('Claude Desktop') | Out-Null
			Write-ColorLine "  ✓ Claude Desktop" Green
		}
		catch {
			$failedAgents.Add('Claude Desktop') | Out-Null
			Write-ColorLine "  ✗ Claude Desktop (failed)" Red
		}
	}

	if ($foundClaudeCode) {
		try {
			& claude mcp remove wordpress-developer --scope user 2>$null | Out-Null
			& claude mcp add --scope user wordpress-developer -- $McpCommand 2>$null | Out-Null
			if ($LASTEXITCODE) { throw 'claude mcp add failed' }
			$configuredAgents.Add('Claude Code (CLI)') | Out-Null
			Write-ColorLine "  ✓ Claude Code (CLI)" Green
		}
		catch {
			$failedAgents.Add('Claude Code (CLI)') | Out-Null
			Write-ColorLine "  ✗ Claude Code (CLI) (failed)" Red
		}
	}

	if ($foundCursor) {
		try {
			$cursorCfg = Join-Path $env:USERPROFILE '.cursor\mcp.json'
			Invoke-ConfigureMcpServersJson -ConfigFile $cursorCfg
			$configuredAgents.Add('Cursor') | Out-Null
			Write-ColorLine "  ✓ Cursor" Green
		}
		catch {
			$failedAgents.Add('Cursor') | Out-Null
			Write-ColorLine "  ✗ Cursor (failed)" Red
		}
	}

	if ($foundWindsurf) {
		try {
			$windsurfCfg = Join-Path $env:USERPROFILE '.codeium\windsurf\mcp_config.json'
			Invoke-ConfigureMcpServersJson -ConfigFile $windsurfCfg
			$configuredAgents.Add('Windsurf') | Out-Null
			Write-ColorLine "  ✓ Windsurf" Green
		}
		catch {
			$failedAgents.Add('Windsurf') | Out-Null
			Write-ColorLine "  ✗ Windsurf (failed)" Red
		}
	}

	if ($foundZed) {
		try {
			Invoke-ConfigureZed
			$configuredAgents.Add('Zed') | Out-Null
			Write-ColorLine "  ✓ Zed" Green
		}
		catch {
			$failedAgents.Add('Zed') | Out-Null
			Write-ColorLine "  ✗ Zed (failed)" Red
		}
	}
}

Remove-Item Env:WPMCP_CONFIG_FILE -ErrorAction SilentlyContinue
Remove-Item Env:WPMCP_MCP_COMMAND -ErrorAction SilentlyContinue

# ── WordPress.com authentication ──────────────────────────────────────────────
Write-Host ""
Write-ColorLine "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" Blue
Write-Host ""
Write-ColorLine "🔐 Connect to WordPress.com" Yellow
Write-Host ""

$authOutput = ''
try {
	$authOutput = & $studioCliCmd auth status 2>&1 | Out-String
}
catch {
	$authOutput = $_.Exception.Message
}

if ($authOutput -match '(?i)Authenticated') {
	if ($authOutput -match 'as [`'']([^`''']+)[`''']') {
		$wpcomUser = $Matches[1]
	}
	elseif ($authOutput -match 'as\s+(\S+)') {
		$wpcomUser = $Matches[1]
	}
	else {
		$wpcomUser = 'your account'
	}
	if ($studioFound) {
		Write-ColorLine "Connected as $wpcomUser (using your WordPress Studio account)." Green
	}
	else {
		Write-ColorLine "Connected as $wpcomUser." Green
	}
	Write-Host "  Preview sites and other WordPress.com features are available."
}
else {
	Write-Host "This unlocks extra powerful features provided by WordPress.com."
	Write-Host ""
	Write-ColorLine "Connect now? [Y/n]" Green
	$authResponse = Read-Host
	if ($authResponse -match '^[Nn]$') {
		Write-ColorLine "Skipped." Yellow
	}
	else {
		Write-Host ""
		Write-ColorLine "Opening WordPress.com login in your browser..." Yellow
		& $studioCliCmd auth login
		if ($LASTEXITCODE) {
			Write-ColorLine "Connection failed." Red
		}
		else {
			Write-ColorLine "✓ Connected to WordPress.com" Green
		}
	}
}

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-ColorLine "✅ Installation complete!" Green
Write-Host ""

if ($configuredAgents.Count -gt 0) {
	Write-ColorLine "Successfully configured agents:" Green
	foreach ($agent in $configuredAgents) {
		Write-ColorLine "  ✓ $agent" Green
	}
}

if ($failedAgents.Count -gt 0) {
	Write-Host ""
	Write-ColorLine "⚠️  Could not configure automatically:" Yellow
	foreach ($agent in $failedAgents) {
		Write-ColorLine "  • $agent" Yellow
	}
	Write-Host ""
	Write-Host "  Add this to the agent's MCP configuration manually:"
	Write-Host ""
	Write-Host '    "mcpServers": {'
	Write-Host '      "wordpress-developer": {'
	Write-Host "        `"command`": `"$McpCommand`""
	Write-Host '      }'
	Write-Host '    }'
}

# ── Restart reminder ──────────────────────────────────────────────────────────
$needsRestart = [System.Collections.Generic.List[string]]::new()
if ($configuredAgents -contains 'Codex' -and ((Test-CommandExists 'codex') -or (Test-AppFolder @('Codex', 'OpenAI Codex')))) {
	$needsRestart.Add('Codex') | Out-Null
}
if ($configuredAgents -contains 'Claude Desktop') { $needsRestart.Add('Claude Desktop') | Out-Null }
if ($configuredAgents -contains 'Windsurf') { $needsRestart.Add('Windsurf') | Out-Null }
if ($configuredAgents -contains 'Zed') { $needsRestart.Add('Zed') | Out-Null }

if ($needsRestart.Count -gt 0) {
	Write-Host ""
	Write-ColorLine "↺  Please restart these apps to apply MCP configuration:" Yellow
	foreach ($app in $needsRestart) {
		Write-ColorLine "  • $app" Yellow
	}
}

# ── Footer ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-ColorLine "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" Blue
Write-ColorLine "🌸 You're all set!" Green
Write-Host ""
Write-Host "Try asking your AI:"
Write-Host "  `"Create a new WordPress site named 'Flowers Shop'`""
Write-Host "  `"Install the WooCommerce plugin`""
Write-Host "  `"Add one demo product to the shop named 'Sunflower'`""
Write-Host "  `"Create shareable link for the shop`""
Write-Host ""
Write-ColorLine "⭐ Star the repo: https://github.com/$McpRepo — it helps others discover the project." Blue
Write-Host ""
Write-ColorLine "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" Blue
Write-Host ""
