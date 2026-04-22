#Requires -Version 5.1
<#
.SYNOPSIS
  Installs WordPress Developer MCP Server on Windows (parity with install.sh).

.NOTES
  This file is intentionally pure-ASCII. Unicode glyphs are built at runtime
  via [char]::ConvertFromUtf32 so the script parses correctly regardless of
  whether PowerShell reads .ps1 files as UTF-8 or the legacy ANSI code page.
#>

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
$NodeBin      = Join-Path $NodeDir   'node.exe'
$NpmBin       = Join-Path $NodeDir   'npm.cmd'
$McpJs        = Join-Path $McpDir    'index.js'
$VersionFile  = Join-Path $McpDir    '.version'
$McpCommand   = Join-Path $BinDir    'studio-mcp.cmd'
$StudioCliCmd = Join-Path $BinDir    'studio-cli.cmd'

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
Head "$($G.Rose) Installing WordPress Developer MCP Server..."
Ok   "Turn your AI into a full-stack WordPress developer."

# == OS / arch check ==---------------------------------------------------------
if ($env:OS -ne 'Windows_NT') {
    Write-Host ""
    Err "$($G.Cross) This installer is for Windows only."
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
    Err "$($G.Cross) Unsupported CPU architecture: $procArch (need AMD64 or ARM64)."
    exit 1
}

Write-Host ""
Ok "  $($G.Tick) Detected: Windows on $procArch"

# == WordPress Studio detection ==----------------------------------------------
$studioExe = Join-Path $env:LOCALAPPDATA 'studio_app\Studio.exe'
$studioFound = Test-Path -LiteralPath $studioExe
if ($studioFound) {
    Write-Host ""
    Ok "$($G.Link) WordPress Studio detected on your machine!"
    Write-Host "  The MCP server will sync with Studio, so you can work"
    Write-Host "  on both at the same time $($G.EmDash) your sites and data stay in sync."
}

# == Detect installed agents ==-------------------------------------------------
Write-Host ""
Info "Detecting installed AI agents..."

function Test-Command([string]$name) {
    [bool](Get-Command $name -ErrorAction SilentlyContinue)
}

function Test-AnyPath([string[]]$paths) {
    foreach ($p in $paths) {
        if ($p -and (Test-Path -LiteralPath $p)) { return $true }
    }
    return $false
}

# Codex: CLI on PATH (npm CLI or MSIX app execution alias), or the Microsoft
# Store desktop app (distributed only as MSIX package "OpenAI.Codex").
$foundCodex = (Test-Command 'codex') -or `
    [bool](Get-AppxPackage -Name 'OpenAI.Codex' -ErrorAction SilentlyContinue)

# Claude Desktop installs to %LOCALAPPDATA%\AnthropicClaude via Squirrel.
$foundClaudeDesktop = Test-AnyPath @(
    (Join-Path $env:LOCALAPPDATA 'AnthropicClaude'),
    (Join-Path $env:LOCALAPPDATA 'Programs\Claude'),
    (Join-Path ${env:ProgramFiles} 'Claude')
)

$foundClaudeCode = Test-Command 'claude'

$foundCursor = (Test-Command 'cursor') -or `
    (Test-Path -LiteralPath (Join-Path $env:LOCALAPPDATA 'Programs\cursor\Cursor.exe'))

$foundWindsurf = (Test-Command 'windsurf') -or `
    (Test-Path -LiteralPath (Join-Path $env:LOCALAPPDATA 'Programs\Windsurf\Windsurf.exe'))

# Zed's Windows installer doesn't register a PATH entry, so only probe the install dir.
$foundZed = Test-Path -LiteralPath (Join-Path $env:LOCALAPPDATA 'Programs\Zed\Zed.exe')

$foundAgentsCount = 0
foreach ($f in @($foundCodex, $foundClaudeDesktop, $foundClaudeCode, $foundCursor, $foundWindsurf, $foundZed)) {
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
    Link "  Get Windsurf:       https://windsurf.com"
    Link "  Get Zed:            https://zed.dev"
} else {
    Ok "Found $foundAgentsCount AI agent(s):"
    if ($foundCodex)         { Ok "  $($G.Tick) Codex" }
    if ($foundClaudeDesktop) { Ok "  $($G.Tick) Claude Desktop" }
    if ($foundClaudeCode)    { Ok "  $($G.Tick) Claude Code (CLI)" }
    if ($foundCursor)        { Ok "  $($G.Tick) Cursor" }
    if ($foundWindsurf)      { Ok "  $($G.Tick) Windsurf" }
    if ($foundZed)           { Ok "  $($G.Tick) Zed" }
    Write-Host "  MCP support will be added to all of them."
}

# == Prepare install directory ==-----------------------------------------------
foreach ($d in @($InstallDir, $NodeDir, $McpDir, $BinDir)) {
    if (-not (Test-Path -LiteralPath $d)) {
        New-Item -ItemType Directory -Force -Path $d | Out-Null
    }
}
