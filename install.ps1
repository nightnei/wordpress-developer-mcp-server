#Requires -Version 5.1
# This file is intentionally pure-ASCII. Unicode glyphs are built at runtime
# via [char]::ConvertFromUtf32 so the script parses correctly regardless of
# whether PowerShell reads .ps1 files as UTF-8 or the legacy ANSI code page.

param(
    # The MCP update tool invokes the downloaded script as a scriptblock and
    # passes -Update. Keep this as a real PowerShell switch so update mode is
    # bound before any install-only detection/configuration runs.
    [switch]$Update
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

# Force console I/O to UTF-8 so emoji + box-drawing glyphs render.
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding           = [System.Text.Encoding]::UTF8
} catch { }

# GitHub + nodejs.org require modern TLS on older Windows.
try {
    [Net.ServicePointManager]::SecurityProtocol = `
        [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch { }

# == Constants ==---------------------------------------------------------------
$InstallDir   = Join-Path $env:USERPROFILE '.wordpress-developer-mcp'
$McpRepo      = 'nightnei/wordpress-developer-mcp-server'
$NodeVersion  = '24.13.1'

$NodeDir      = Join-Path $InstallDir 'node'
$McpDir       = Join-Path $InstallDir 'mcp'
$BinDir       = Join-Path $InstallDir 'bin'

$McpCommand   = Join-Path $BinDir    'studio-mcp.cmd'
$StudioCliCmd = Join-Path $BinDir    'studio-cli.cmd'
$NodeBin      = Join-Path $NodeDir   'node.exe'
$NpmBin       = Join-Path $NodeDir   'npm.cmd'
$McpJs        = Join-Path $McpDir    'index.js'
$VersionFile  = Join-Path $McpDir    '.version'
$StudioShim   = Join-Path $NodeDir   'studio.cmd'

# == Unicode glyphs (ASCII-safe source) ==--------------------------------------
function _U([int]$cp) { [char]::ConvertFromUtf32($cp) }
$G = @{
    Rose   = (_U 0x1F338)                 # sakura
    Link   = (_U 0x1F517)                 # link
    Lock   = (_U 0x1F510)                 # closed lock with key
    Check  = (_U 0x2705)                  # white heavy check mark
    Warn   = ((_U 0x26A0) + (_U 0xFE0F))  # warning
    Star   = (_U 0x2B50)                  # star
    Cross  = (_U 0x274C)                  # cross mark
    Tick   = (_U 0x2713)                  # check
    Xmark  = (_U 0x2717)                  # ballot x
    Bullet = (_U 0x2022)                  # bullet
    Rot    = (_U 0x21BA)                  # anticlockwise open circle arrow
    EmDash = (_U 0x2014)                  # em dash
}
$HR = ([string][char]0x2500) * 56  # horizontal rule

# == Pretty printing ==---------------------------------------------------------
function Info([string]$m) { Write-Host $m -ForegroundColor Yellow }
function Ok  ([string]$m) { Write-Host $m -ForegroundColor Green }
function Err ([string]$m) { Write-Host $m -ForegroundColor Red }
function Head([string]$m) { Write-Host $m -ForegroundColor Cyan }
function Link([string]$m) { Write-Host $m -ForegroundColor Blue }

Head ""
if ($Update) {
    Head "$($G.Rose) Updating WordPress Developer MCP Server..."
} else {
    Head "$($G.Rose) Installing WordPress Developer MCP Server..."
    Ok   "Turn your AI into a full-stack WordPress developer."
    Write-Host ""
    Write-Host "This script will detect your locally installed AI agents"
    Write-Host "(Codex, Claude, Cursor, VS Code, Windsurf, Zed) and configure them"
    Write-Host "for WordPress development, so you can build sites with"
    Write-Host "natural language instead of code."
}

# == OS / arch check ==---------------------------------------------------------
$isWindows = $false
try {
    # $env:OS fails during -Update flow (install.ps1 is invoked as a scriptblock).
    $isWindows = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform(
        [System.Runtime.InteropServices.OSPlatform]::Windows
    )
} catch {
    $isWindows = ($env:OS -eq 'Windows_NT')
}
if (-not $isWindows) {
    Write-Host ""
    Err "$($G.Cross) This installer is for Windows only."
    exit 1
}

function Get-NativeProcessorArchitecture {
    try {
        # $env:PROCESSOR_ARCHITECTURE reports the current process architecture.
        # Git Bash / emulated shells on Windows ARM64 can report AMD64 there, so
        # prefer the native CPU architecture before choosing the Node.js archive.
        $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Select-Object -First 1
        switch ([int]$cpu.Architecture) {
            9  { return 'AMD64' }
            12 { return 'ARM64' }
        }
    } catch { }

    foreach ($candidate in @($env:PROCESSOR_ARCHITEW6432, $env:PROCESSOR_ARCHITECTURE)) {
        switch ($candidate) {
            'AMD64' { return 'AMD64' }
            'ARM64' { return 'ARM64' }
        }
    }

    return $null
}

$processorArch = Get-NativeProcessorArchitecture
$nodeArch = switch ($processorArch) {
    'AMD64' { 'x64' }
    'ARM64' { 'arm64' }
    default { $null }
}
if (-not $nodeArch) {
    Write-Host ""
    Err "$($G.Cross) Unsupported CPU architecture: $processorArch (need AMD64 or ARM64)."
    exit 1
}

Write-Host ""
Ok "  $($G.Tick) Detected: Windows on $processorArch"

# == WordPress Studio detection ==----------------------------------------------
$studioExe = Join-Path $env:LOCALAPPDATA 'studio_app\Studio.exe'
$studioFound = Test-Path -LiteralPath $studioExe
if ($studioFound) {
    Write-Host ""
    Ok "$($G.Link) WordPress Studio detected on your machine!"
    Write-Host "  The MCP server will sync with Studio, so you can work"
    Write-Host "  on both at the same time $($G.EmDash) your sites and data stay in sync."
}

function Test-Command([string]$name) {
    [bool](Get-Command $name -ErrorAction SilentlyContinue)
}

function Test-AppxPackage([string]$name) {
    if (-not (Get-Command Get-AppxPackage -ErrorAction SilentlyContinue)) {
        return $false
    }
    try {
        return [bool](Get-AppxPackage -Name $name -ErrorAction SilentlyContinue)
    } catch {
        return $false
    }
}

function Test-AnyPath([string[]]$paths) {
    foreach ($p in $paths) {
        if ($p -and (Test-Path -LiteralPath $p)) { return $true }
    }
    return $false
}

$foundCodex = $false
$foundClaudeDesktop = $false
$foundClaudeCode = $false
$foundCursor = $false
$foundVsCode = $false
$foundWindsurf = $false
$foundZed = $false
$foundAgentsCount = 0

if (-not $Update) {
    # == Detect installed agents ==---------------------------------------------
    Write-Host ""
    Info "Detecting installed AI agents..."

    # Codex: CLI on PATH (npm CLI or MSIX app execution alias), or the Microsoft
    # Store desktop app (distributed only as MSIX package "OpenAI.Codex").
    $foundCodex = (Test-Command 'codex') -or (Test-AppxPackage 'OpenAI.Codex')

    # Claude Desktop installs to %LOCALAPPDATA%\AnthropicClaude via Squirrel.
    $foundClaudeDesktop = Test-AnyPath @(
        (Join-Path $env:LOCALAPPDATA 'AnthropicClaude'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Claude'),
        (Join-Path ${env:ProgramFiles} 'Claude')
    )

    $foundClaudeCode = Test-Command 'claude'

    $foundCursor = (Test-Command 'cursor') -or `
        (Test-Path -LiteralPath (Join-Path $env:LOCALAPPDATA 'Programs\cursor\Cursor.exe'))

    $foundVsCode = (Test-Command 'code') -or (Test-AnyPath @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code\Code.exe'),
        (Join-Path ${env:ProgramFiles} 'Microsoft VS Code\Code.exe')
    ))

    $foundWindsurf = (Test-Command 'windsurf') -or `
        (Test-Path -LiteralPath (Join-Path $env:LOCALAPPDATA 'Programs\Windsurf\Windsurf.exe'))

    # Zed's Windows installer doesn't register a PATH entry, so only probe the install dir.
    $foundZed = Test-Path -LiteralPath (Join-Path $env:LOCALAPPDATA 'Programs\Zed\Zed.exe')

    foreach ($f in @($foundCodex, $foundClaudeDesktop, $foundClaudeCode, $foundCursor, $foundVsCode, $foundWindsurf, $foundZed)) {
        if ($f) { $foundAgentsCount++ }
    }

    if ($foundAgentsCount -eq 0) {
        Info "$($G.Warn)  No supported AI agents found on your system."
        Write-Host "  The MCP server will still be installed."
        Write-Host "  Install any supported agent and re-run this script."
        Write-Host ""
        Link "  Get Codex:          https://openai.com/codex"
        Link "  Get Claude:         https://claude.ai/download"
        Link "  Get Cursor:         https://cursor.com"
        Link "  Get VS Code:        https://code.visualstudio.com"
        Link "  Get Windsurf:       https://windsurf.com"
        Link "  Get Zed:            https://zed.dev"
    } else {
        Ok "Found $foundAgentsCount AI agent(s):"
        if ($foundCodex)         { Ok "  $($G.Tick) Codex" }
        if ($foundClaudeDesktop) { Ok "  $($G.Tick) Claude Desktop" }
        if ($foundClaudeCode)    { Ok "  $($G.Tick) Claude Code" }
        if ($foundCursor)        { Ok "  $($G.Tick) Cursor" }
        if ($foundVsCode)        { Ok "  $($G.Tick) VS Code" }
        if ($foundWindsurf)      { Ok "  $($G.Tick) Windsurf" }
        if ($foundZed)           { Ok "  $($G.Tick) Zed" }
        Write-Host "  MCP support will be added to all of them."
    }
}

# == Prepare install directory ==-----------------------------------------------
foreach ($d in @($InstallDir, $NodeDir, $McpDir, $BinDir)) {
    if (-not (Test-Path -LiteralPath $d)) {
        New-Item -ItemType Directory -Force -Path $d | Out-Null
    }
}

# == Node.js runtime ==---------------------------------------------------------
Write-Host ""
Info "Checking runtime environment..."

$currentNodeVersion = ''
if (Test-Path -LiteralPath $NodeBin) {
    try {
        $v = & $NodeBin --version 2>$null
        if ($LASTEXITCODE -eq 0 -and $v) {
            $currentNodeVersion = ($v -replace '^v', '').Trim()
        }
    } catch { $currentNodeVersion = '' }
}

if (($currentNodeVersion -eq $NodeVersion) -and (Test-Path -LiteralPath $NpmBin)) {
    Ok "  $($G.Tick) Runtime environment already up to date"
} else {
    Info "Downloading runtime environment..."
    if (Test-Path -LiteralPath $NodeDir) {
        Remove-Item -LiteralPath $NodeDir -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $NodeDir | Out-Null

    $nodeZipName = "node-v$NodeVersion-win-$nodeArch.zip"
    $nodeUrl     = "https://nodejs.org/dist/v$NodeVersion/$nodeZipName"
    $zipPath     = Join-Path $env:TEMP $nodeZipName
    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }

    try {
        Invoke-WebRequest -Uri $nodeUrl -OutFile $zipPath -UseBasicParsing
    } catch {
        Err "$($G.Cross) Failed to download Node.js: $($_.Exception.Message)"
        exit 1
    }

    $extractRoot = Join-Path $env:TEMP ("wpmcp-node-" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $extractRoot | Out-Null
    try {
        Expand-Archive -LiteralPath $zipPath -DestinationPath $extractRoot -Force
        $inner = Get-ChildItem -LiteralPath $extractRoot -Directory | Select-Object -First 1
        if (-not $inner) { throw 'Unexpected Node.js archive layout (no top-level folder).' }
        # Move (not copy) every child, including hidden, into $NodeDir.
        Get-ChildItem -LiteralPath $inner.FullName -Force | ForEach-Object {
            Move-Item -LiteralPath $_.FullName -Destination $NodeDir -Force
        }
    } catch {
        Err "$($G.Cross) Failed to extract Node.js: $($_.Exception.Message)"
        exit 1
    } finally {
        Remove-Item -LiteralPath $extractRoot -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $zipPath     -Force          -ErrorAction SilentlyContinue
    }

    if (-not (Test-Path -LiteralPath $NodeBin) -or -not (Test-Path -LiteralPath $NpmBin)) {
        Err "$($G.Cross) Node.js installation failed (node.exe or npm.cmd missing)."
        exit 1
    }
    Ok "  $($G.Tick) Runtime environment installed"
}

# == MCP Server release ==------------------------------------------------------
Write-Host ""
Info "Checking server..."

$mcpLatest = $null
try {
    $release = Invoke-RestMethod `
        -Uri "https://api.github.com/repos/$McpRepo/releases/latest" `
        -Headers @{
            Accept       = 'application/vnd.github.v3+json'
            'User-Agent' = 'wordpress-developer-mcp-installer'
        } `
        -UseBasicParsing
    $mcpLatest = $release.tag_name
} catch {
    Err "$($G.Cross) Failed to query latest MCP release: $($_.Exception.Message)"
    exit 1
}
if (-not $mcpLatest) {
    Err "$($G.Cross) Could not determine latest MCP release."
    exit 1
}

$currentMcpVersion = ''
if (Test-Path -LiteralPath $VersionFile) {
    try {
        $currentMcpVersion = (Get-Content -LiteralPath $VersionFile -Raw).Trim()
    } catch { $currentMcpVersion = '' }
}

if ($currentMcpVersion -and ($currentMcpVersion -eq $mcpLatest)) {
    Ok "  $($G.Tick) Server already up to date"
} else {
    Info "Downloading server..."
    if (Test-Path -LiteralPath $McpDir) {
        Remove-Item -LiteralPath $McpDir -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $McpDir | Out-Null

    $tarName = "wordpress-developer-mcp-server-$mcpLatest.tar.gz"
    $tarUrl  = "https://github.com/$McpRepo/releases/download/$mcpLatest/$tarName"
    $tarPath = Join-Path $env:TEMP $tarName
    if (Test-Path -LiteralPath $tarPath) {
        Remove-Item -LiteralPath $tarPath -Force
    }

    try {
        Invoke-WebRequest -Uri $tarUrl -OutFile $tarPath -UseBasicParsing
    } catch {
        Err "$($G.Cross) Failed to download server: $($_.Exception.Message)"
        exit 1
    }

    # Pin to Windows' built-in bsdtar at System32. PATH lookup is unreliable
    # here: if PowerShell was launched from Git Bash, MSYS's GNU tar at
    # C:\Program Files\Git\usr\bin\tar.exe wins the lookup, and GNU tar treats
    # arguments containing ':' as 'host:path' (rsh syntax), so `-C C:\...`
    # fails with "Cannot connect to C: resolve failed".
    $tarExe = Join-Path $env:SystemRoot 'System32\tar.exe'
    if (-not (Test-Path -LiteralPath $tarExe)) {
        Err "$($G.Cross) tar.exe not found at $tarExe. Windows 10 build 17063 or later is required."
        exit 1
    }

    # -C avoids relying on the current directory.
    & $tarExe -xzf $tarPath -C $McpDir
    $tarRc = $LASTEXITCODE
    Remove-Item -LiteralPath $tarPath -Force -ErrorAction SilentlyContinue
    if ($tarRc -ne 0) {
        Err "$($G.Cross) Failed to extract server (tar exit $tarRc)."
        exit 1
    }
    if (-not (Test-Path -LiteralPath $McpJs)) {
        Err "$($G.Cross) Server installation failed (index.js missing)."
        exit 1
    }

    Set-Content -LiteralPath $VersionFile -Value $mcpLatest -NoNewline -Encoding ASCII

    if ($currentMcpVersion) {
        Ok "  $($G.Tick) Server updated to $mcpLatest"
    } else {
        Ok "  $($G.Tick) Server installed"
    }
}

# == Studio CLI (wp-studio) ==--------------------------------------------------
Write-Host ""
Info "Checking CLI..."

# Pin wp-studio explicitly: bump $studioLatest when you intentionally ship a new CLI.
# Resolving "latest" from npm was removed so upstream releases cannot break installs unexpectedly.
$studioLatest = '1.8.2'

# Keep PATH scoped to npm's work. npm.cmd is called by absolute path, but its
# generated shims and child commands still expect the bundled node directory to
# be first on PATH in plain PowerShell.
$savedPath = $env:PATH
$env:PATH = "$NodeDir;$savedPath"

$currentStudioVersion = ''
try {
    $listOut = (& $NpmBin list -g wp-studio --depth=0 --loglevel=silent --prefix $NodeDir 2>&1 | Out-String)
    if ($listOut -match 'wp-studio@([^\s\r\n]+)') {
        $currentStudioVersion = $Matches[1].Trim()
    }
} catch { $currentStudioVersion = '' }

try {
    $studioShimExists = Test-Path -LiteralPath $StudioShim
    # npm metadata alone is not enough: the wrapper below directly calls
    # studio.cmd, so a missing shim must force reinstall instead of "up to date".
    if ($currentStudioVersion -and ($currentStudioVersion -eq $studioLatest) -and $studioShimExists) {
        Ok "  $($G.Tick) CLI already up to date"
    } else {
        Info "Installing CLI..."
        $npmOutput = (& $NpmBin install -g "wp-studio@$studioLatest" --loglevel=silent --prefix $NodeDir 2>&1 | Out-String)
        $npmExitCode = $LASTEXITCODE
        foreach ($line in ($npmOutput -split "`r?`n")) {
            if ($line -match '(?i)error') { Write-Host $line }
        }
        if ($npmExitCode -ne 0) {
            if ($npmOutput.Trim()) { Write-Host $npmOutput.Trim() }
            Err "$($G.Cross) Failed to install CLI (npm exit $npmExitCode)."
            exit 1
        }
        if (-not (Test-Path -LiteralPath $StudioShim)) {
            Err "$($G.Cross) CLI installation failed (studio.cmd missing)."
            exit 1
        }
        if ($currentStudioVersion) {
            Ok "  $($G.Tick) CLI updated to $studioLatest"
        } else {
            Ok "  $($G.Tick) CLI installed"
        }
    }
} finally {
    $env:PATH = $savedPath
}

# == Wrapper scripts (always regenerated) ==-----------------------------------
Write-Host ""
Info "Creating wrapper scripts..."

# STUDIO_CLI_PATH points at studio-cli.cmd. The MCP server invokes it through
# cmd.exe so Windows can run the npm .cmd shim without Node's direct-spawn EINVAL.
# The `call "exe" "args" %*` form avoids cmd.exe's quote-stripping rule that
# triggers when a line starts with `"` and ends with `"`.
$studioMcpContent = @"
@echo off
setlocal
set "STUDIO_CLI_PATH=$StudioCliCmd"
call "$NodeBin" "$McpJs" %*
exit /b %ERRORLEVEL%
"@

$studioCliContent = @"
@echo off
setlocal
set "PATH=$NodeDir;%PATH%"
call "$StudioShim" %*
exit /b %ERRORLEVEL%
"@

foreach ($pair in @(
    @{ Path = $McpCommand;   Content = $studioMcpContent },
    @{ Path = $StudioCliCmd; Content = $studioCliContent }
)) {
    if (Test-Path -LiteralPath $pair.Path) {
        Remove-Item -LiteralPath $pair.Path -Force
    }
    # Normalize to CRLF and write as system ANSI so non-ASCII profile paths
    # (e.g., Latin-1 usernames) survive cmd.exe's default code page.
    $text = ($pair.Content -replace "`r?`n", "`r`n")
    [System.IO.File]::WriteAllText($pair.Path, $text, [System.Text.Encoding]::Default)
}

Ok "  $($G.Tick) Wrapper scripts ready"

if ($Update) {
    # Programmatic updates should refresh runtime/server/wrappers only. Agent
    # config and WordPress.com auth are install-time work and can block an AI run.
    Write-Host ""
    Ok "$($G.Check) Update complete!"
    Info "$($G.Rot)  Restart your AI assistant to apply the new version."
    Write-Host ""
    exit 0
}
# == Node-driven config helpers ==----------------------------------------------
$mcpServersJsScript = @'
const fs = require('fs');
const path = require('path');
const configPath = process.env.WPMCP_CONFIG_FILE;
const mcpCommand = process.env.WPMCP_MCP_COMMAND;

fs.mkdirSync(path.dirname(configPath), { recursive: true });

let config = {};
try {
  const raw = fs.readFileSync(configPath, 'utf8');
  if (raw && raw.trim()) config = JSON.parse(raw);
} catch (e) {
  config = {};
}
if (!config || typeof config !== 'object') config = {};
if (!config.mcpServers || typeof config.mcpServers !== 'object') {
  config.mcpServers = {};
}
config.mcpServers['wordpress-developer'] = {
  command: mcpCommand,
  args: []
};

fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
'@

$vsCodeMcpJsScript = @'
const fs = require('fs');
const path = require('path');
const configPath = process.env.WPMCP_CONFIG_FILE;
const mcpCommand = process.env.WPMCP_MCP_COMMAND;

fs.mkdirSync(path.dirname(configPath), { recursive: true });

let config = {};
try {
  const raw = fs.readFileSync(configPath, 'utf8');
  if (raw && raw.trim()) config = JSON.parse(raw);
} catch (e) {
  config = {};
}
if (!config || typeof config !== 'object') config = {};
if (!config.servers || typeof config.servers !== 'object') {
  config.servers = {};
}
config.servers['wordpress-developer'] = {
  type: 'stdio',
  command: mcpCommand,
  args: []
};

fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
'@

$zedJsScript = @'
const fs = require('fs');
const path = require('path');
const configPath = process.env.WPMCP_CONFIG_FILE;
const mcpCommand = process.env.WPMCP_MCP_COMMAND;

function stripTrailingCommas(input) {
  let output = '';
  let inString = false;
  for (let i = 0; i < input.length; i++) {
    const c = input[i];
    if (inString) {
      output += c;
      if (c === '"') {
        let bs = 0;
        for (let j = i - 1; j >= 0 && input[j] === '\\'; j--) bs++;
        if (bs % 2 === 0) inString = false;
      }
      continue;
    }
    if (c === '"') {
      inString = true;
      output += c;
      continue;
    }
    if (c === ',') {
      let j = i + 1;
      while (j < input.length && /[\s\n\r\t]/.test(input[j])) j++;
      if (j < input.length && (input[j] === '}' || input[j] === ']')) continue;
    }
    output += c;
  }
  return output;
}

function parseZedSettingsJson(raw) {
  const s = raw.trim() === '' ? '{}' : raw;
  return JSON.parse(stripTrailingCommas(s));
}

fs.mkdirSync(path.dirname(configPath), { recursive: true });

let raw = '';
try {
  raw = fs.readFileSync(configPath, 'utf8');
} catch (e) {
  raw = '';
}
let config = {};
try {
  config = parseZedSettingsJson(raw);
} catch (e) {
  console.error(e.message);
  process.exit(1);
}
if (!config || typeof config !== 'object') config = {};
if (!config.context_servers || typeof config.context_servers !== 'object') {
  config.context_servers = {};
}
config.context_servers['wordpress-developer'] = {
  command: mcpCommand,
  args: []
};

fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
'@

$codexTomlJsScript = @'
const fs = require('fs');
const path = require('path');
const configPath = process.env.WPMCP_CONFIG_FILE;
const mcpCommand = process.env.WPMCP_MCP_COMMAND;

function tomlString(value) {
  return '"' + value.replace(/\\/g, '\\\\').replace(/"/g, '\\"') + '"';
}

fs.mkdirSync(path.dirname(configPath), { recursive: true });

let content = '';
try { content = fs.readFileSync(configPath, 'utf8'); } catch (e) { content = ''; }

const newEntry =
  '[mcp_servers.wordpress-developer]\n' +
  'command = ' + tomlString(mcpCommand) + '\n' +
  'args = []\n' +
  'enabled = true';
// Match by TOML lines, not "until next [". The entry itself contains
// args = [], and an older regex treated that array as a new section.
const sectionRegex = /^\[mcp_servers\.wordpress-developer\](?:\r?\n(?!\[)[^\r\n]*)*/m;

if (sectionRegex.test(content)) {
  content = content.replace(sectionRegex, newEntry + '\n\n');
} else {
  content = (content.trimEnd() ? content.trimEnd() + '\n\n' : '') + newEntry + '\n';
}

fs.writeFileSync(configPath, content);
'@

function Invoke-NodeHelper {
    param(
        [Parameter(Mandatory)][string]$Script,
        [Parameter(Mandatory)][string]$ConfigFile
    )
    $tempJs = Join-Path $env:TEMP ("wpmcp-" + [Guid]::NewGuid().ToString('N') + '.js')
    [System.IO.File]::WriteAllText(
        $tempJs,
        $Script,
        (New-Object System.Text.UTF8Encoding($false))
    )

    $savedConfig = [Environment]::GetEnvironmentVariable('WPMCP_CONFIG_FILE', 'Process')
    $savedCmd    = [Environment]::GetEnvironmentVariable('WPMCP_MCP_COMMAND', 'Process')
    [Environment]::SetEnvironmentVariable('WPMCP_CONFIG_FILE', $ConfigFile, 'Process')
    [Environment]::SetEnvironmentVariable('WPMCP_MCP_COMMAND', $McpCommand, 'Process')
    try {
        $output = & $NodeBin $tempJs 2>&1
        if ($LASTEXITCODE -ne 0) {
            $detail = if ($output) { ($output | Out-String).Trim() } else { '(no output)' }
            throw "Node helper exited with code $LASTEXITCODE`n$detail"
        }
    } finally {
        Remove-Item -LiteralPath $tempJs -Force -ErrorAction SilentlyContinue
        [Environment]::SetEnvironmentVariable('WPMCP_CONFIG_FILE', $savedConfig, 'Process')
        [Environment]::SetEnvironmentVariable('WPMCP_MCP_COMMAND', $savedCmd,    'Process')
    }
}

function Set-McpServersJson { param([string]$ConfigFile)
    Invoke-NodeHelper -Script $mcpServersJsScript -ConfigFile $ConfigFile
}
function Set-VsCodeMcpJson { param([string]$ConfigFile)
    Invoke-NodeHelper -Script $vsCodeMcpJsScript -ConfigFile $ConfigFile
}
function Set-ZedSettingsJson { param([string]$ConfigFile)
    Invoke-NodeHelper -Script $zedJsScript -ConfigFile $ConfigFile
}
function Set-CodexTomlConfig { param([string]$ConfigFile)
    Invoke-NodeHelper -Script $codexTomlJsScript -ConfigFile $ConfigFile
}

function Resolve-NativeExecutable {
    param([Parameter(Mandatory)][string]$Name)
    # Absolute path or name with its own extension: trust the caller.
    if ([System.IO.Path]::IsPathRooted($Name) -or $Name.Contains('.')) {
        return $Name
    }
    # Skip .ps1 shims: those require matching PowerShell execution policy and
    # fail opaquely (e.g. fnm installs claude.ps1 + claude.cmd side-by-side).
    # Prefer native executables that don't depend on script execution policy.
    $native = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue |
              Where-Object { $_.Extension -in '.exe','.cmd','.bat','.com' } |
              Select-Object -First 1
    if ($native) { return $native.Source }
    return $Name
}

function Invoke-ExternalQuiet {
    param(
        [Parameter(Mandatory)][string]$Exe,
        [Parameter(Mandatory)][string[]]$Arguments
    )
    # Splat the array; PowerShell forwards each element verbatim to the child
    # process, so values containing spaces or `--` pass through unmodified.
    # Capture (don't discard) the output: piping to Out-Null closes the child's
    # stdout and some npm-shim CLIs (e.g. Claude Code) exit non-zero on a
    # broken pipe. Returning the output also lets callers surface real errors
    # instead of just "(failed)".
    $resolved = Resolve-NativeExecutable -Name $Exe
    $savedErrorActionPreference = $ErrorActionPreference
    # Native CLIs may write normal progress to stderr. With the script-wide
    # Stop policy, PowerShell can promote that to NativeCommandError.
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $resolved @Arguments 2>&1
        return [pscustomobject]@{
            ExitCode = $LASTEXITCODE
            Output   = ($output | Out-String).TrimEnd()
        }
    } finally {
        $ErrorActionPreference = $savedErrorActionPreference
    }
}


# == Configure AI agents ==-----------------------------------------------------
$configuredAgents = [System.Collections.Generic.List[string]]::new()
$failedAgents     = [System.Collections.Generic.List[string]]::new()

if ($foundAgentsCount -gt 0) {
    Write-Host ""
    Info "Configuring AI agents..."

    if ($foundCodex) {
        try {
            if (Test-Command 'codex') {
                $null = Invoke-ExternalQuiet -Exe 'codex' `
                    -Arguments @('mcp','remove','wordpress-developer')
                $res = Invoke-ExternalQuiet -Exe 'codex' `
                    -Arguments @('mcp','add','wordpress-developer','--',$McpCommand)
                if ($res.ExitCode -ne 0) {
                    throw "codex mcp add exited with $($res.ExitCode)$(if ($res.Output) { ": $($res.Output)" })"
                }
            } else {
                Set-CodexTomlConfig -ConfigFile (Join-Path $env:USERPROFILE '.codex\config.toml')
            }
            $configuredAgents.Add('Codex') | Out-Null
            Ok "  $($G.Tick) Codex"
        } catch {
            $failedAgents.Add('Codex') | Out-Null
            Err "  $($G.Xmark) Codex (failed)"
            if ($_.Exception.Message) {
                Write-Host "      $($_.Exception.Message)" -ForegroundColor DarkGray
            }
        }
    }

    if ($foundClaudeDesktop) {
        try {
            $claudeCfg = Join-Path $env:APPDATA 'Claude\claude_desktop_config.json'
            Set-McpServersJson -ConfigFile $claudeCfg
            $configuredAgents.Add('Claude Desktop') | Out-Null
            Ok "  $($G.Tick) Claude Desktop"
        } catch {
            $failedAgents.Add('Claude Desktop') | Out-Null
            Err "  $($G.Xmark) Claude Desktop (failed)"
            if ($_.Exception.Message) {
                Write-Host "      $($_.Exception.Message)" -ForegroundColor DarkGray
            }
        }
    }

    if ($foundClaudeCode) {
        try {
            # Claude reports "not found" on first install. Removing is only a
            # cleanup step; the following add is the operation that must succeed.
            try {
                $null = Invoke-ExternalQuiet -Exe 'claude' `
                    -Arguments @('mcp','remove','wordpress-developer','--scope','user')
            } catch { }
            $res = Invoke-ExternalQuiet -Exe 'claude' `
                -Arguments @('mcp','add','--scope','user','wordpress-developer','--',$McpCommand)
            if ($res.ExitCode -ne 0) {
                throw "claude mcp add exited with $($res.ExitCode)$(if ($res.Output) { ": $($res.Output)" })"
            }
            $configuredAgents.Add('Claude Code') | Out-Null
            Ok "  $($G.Tick) Claude Code"
        } catch {
            $failedAgents.Add('Claude Code') | Out-Null
            Err "  $($G.Xmark) Claude Code (failed)"
            if ($_.Exception.Message) {
                Write-Host "      $($_.Exception.Message)" -ForegroundColor DarkGray
            }
        }
    }

    if ($foundCursor) {
        try {
            $cursorCfg = Join-Path $env:USERPROFILE '.cursor\mcp.json'
            Set-McpServersJson -ConfigFile $cursorCfg
            $configuredAgents.Add('Cursor') | Out-Null
            Ok "  $($G.Tick) Cursor"
        } catch {
            $failedAgents.Add('Cursor') | Out-Null
            Err "  $($G.Xmark) Cursor (failed)"
            if ($_.Exception.Message) {
                Write-Host "      $($_.Exception.Message)" -ForegroundColor DarkGray
            }
        }
    }

    if ($foundVsCode) {
        try {
            $vsCodeCfg = Join-Path $env:APPDATA 'Code\User\mcp.json'
            Set-VsCodeMcpJson -ConfigFile $vsCodeCfg
            $configuredAgents.Add('VS Code') | Out-Null
            Ok "  $($G.Tick) VS Code"
        } catch {
            $failedAgents.Add('VS Code') | Out-Null
            Err "  $($G.Xmark) VS Code (failed)"
            if ($_.Exception.Message) {
                Write-Host "      $($_.Exception.Message)" -ForegroundColor DarkGray
            }
        }
    }

    if ($foundWindsurf) {
        try {
            $windsurfCfg = Join-Path $env:USERPROFILE '.codeium\windsurf\mcp_config.json'
            Set-McpServersJson -ConfigFile $windsurfCfg
            $configuredAgents.Add('Windsurf') | Out-Null
            Ok "  $($G.Tick) Windsurf"
        } catch {
            $failedAgents.Add('Windsurf') | Out-Null
            Err "  $($G.Xmark) Windsurf (failed)"
            if ($_.Exception.Message) {
                Write-Host "      $($_.Exception.Message)" -ForegroundColor DarkGray
            }
        }
    }

    if ($foundZed) {
        try {
            $zedCfg = Join-Path $env:APPDATA 'Zed\settings.json'
            Set-ZedSettingsJson -ConfigFile $zedCfg
            $configuredAgents.Add('Zed') | Out-Null
            Ok "  $($G.Tick) Zed"
        } catch {
            $failedAgents.Add('Zed') | Out-Null
            Err "  $($G.Xmark) Zed (failed)"
            if ($_.Exception.Message) {
                Write-Host "      $($_.Exception.Message)" -ForegroundColor DarkGray
            }
        }
    }
}


# == WordPress.com authentication ==--------------------------------------------
Write-Host ""
Link $HR
Write-Host ""
Info "$($G.Lock) Connect to WordPress.com"
Write-Host ""

$authOutput = ''
$authStatus = Invoke-ExternalQuiet -Exe $StudioCliCmd -Arguments @('auth','status')
$authOutput = $authStatus.Output
$authExitCode = $authStatus.ExitCode

# CLI output is localized, so match on two locale-independent signals instead
# of an English phrase:
#   1) mentions "WordPress.com" (the error path "Authentication token invalid"
#      does not)
#   2) contains a backtick-quoted username
# The status command also writes localized progress to stderr, so it must run
# through Invoke-ExternalQuiet rather than direct PowerShell invocation.
$wpcomUser = if ($authOutput -match '`([^`]+)`') { $Matches[1] } else { '' }
if ($authOutput -match 'WordPress\.com' -and $wpcomUser) {
    if ($studioFound) {
        Ok "Connected as $wpcomUser (using your WordPress Studio account)."
    } else {
        Ok "Connected as $wpcomUser."
    }
    Write-Host "  Preview sites and other WordPress.com features are available."
} else {
    Write-Host "This unlocks extra powerful features provided by WordPress.com."
    Write-Host ""
    Ok "Connect now? [Y/n]"
    $authResponse = Read-Host
    if ($authResponse -match '^[Nn]$') {
        Info "Skipped."
    } else {
        Write-Host ""
        Info "Opening WordPress.com login in your browser..."
        & $StudioCliCmd auth login
        if ($LASTEXITCODE -eq 0) {
            Ok "$($G.Tick) Connected to WordPress.com"
        } else {
            Err "Connection failed."
        }
    }
}

# == Summary ==-----------------------------------------------------------------
Write-Host ""
Ok "$($G.Check) Installation complete!"
Write-Host ""

if ($configuredAgents.Count -gt 0) {
    Ok "Successfully configured agents:"
    foreach ($agent in $configuredAgents) {
        Ok "  $($G.Tick) $agent"
    }
}

if ($failedAgents.Count -gt 0) {
    Write-Host ""
    Info "$($G.Warn)  Could not configure automatically:"
    foreach ($agent in $failedAgents) {
        Info "  $($G.Bullet) $agent"
    }
    Write-Host ""
    Write-Host "  Add this to the agent's MCP configuration manually:"
    Write-Host ""
    $manualCommand = $McpCommand | ConvertTo-Json -Compress
    Write-Host '    "mcpServers": {'
    Write-Host '      "wordpress-developer": {'
    Write-Host "        `"command`": $manualCommand,"
    Write-Host '        "args": []'
    Write-Host '      }'
    Write-Host '    }'
}

# == Restart reminder ==--------------------------------------------------------
$needsRestart = [System.Collections.Generic.List[string]]::new()

if ($configuredAgents.Contains('Codex')) {
    # Only suggest restart when the desktop app is present, not just the CLI.
    # Codex for Windows ships as an MSIX (Microsoft Store) package, so probe
    # via Test-AppxPackage, matching the detection at the top of the script.
    if (Test-AppxPackage 'OpenAI.Codex') {
        $needsRestart.Add('Codex') | Out-Null
    }
}
if ($configuredAgents.Contains('Claude Desktop')) { $needsRestart.Add('Claude Desktop') | Out-Null }
if ($configuredAgents.Contains('VS Code'))        { $needsRestart.Add('VS Code')        | Out-Null }
if ($configuredAgents.Contains('Windsurf'))       { $needsRestart.Add('Windsurf')       | Out-Null }
if ($configuredAgents.Contains('Zed'))            { $needsRestart.Add('Zed')            | Out-Null }

if ($needsRestart.Count -gt 0) {
    Write-Host ""
    Info "$($G.Rot)  Please restart these apps to apply MCP configuration:"
    foreach ($app in $needsRestart) {
        Info "  $($G.Bullet) $app"
    }
}

# == Footer ==------------------------------------------------------------------
Write-Host ""
Link $HR
Ok "$($G.Rose) You're all set!"
Write-Host ""
Write-Host "Try asking your AI:"
Write-Host '  "Create a new WordPress site named ''Flowers Shop''"'
Write-Host '  "Install the WooCommerce plugin"'
Write-Host '  "Add one demo product to the shop named ''Sunflower''"'
Write-Host '  "Create shareable link for the shop"'
Write-Host ""
Link "$($G.Star) Star the repo: https://github.com/$McpRepo $($G.EmDash) it helps others discover the project."
Write-Host ""
Link $HR
Write-Host ""
