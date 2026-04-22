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

if ($currentNodeVersion -eq $NodeVersion) {
    Ok "  $($G.Tick) Runtime environment already installed"
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

    if (-not (Test-Path -LiteralPath $NodeBin)) {
        Err "$($G.Cross) Node.js installation failed (node.exe missing)."
        exit 1
    }
    Ok "  $($G.Tick) Runtime environment installed"
}

# == MCP Server release ==------------------------------------------------------
Write-Host ""
Info "Checking MCP Server..."

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
    Ok "  $($G.Tick) MCP Server already up to date"
} else {
    Info "Downloading MCP Server..."
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
        Err "$($G.Cross) Failed to download MCP Server: $($_.Exception.Message)"
        exit 1
    }

    # Prefer Windows' built-in bsdtar at System32. GNU tar (e.g. from Git for
    # Windows on PATH) treats arguments containing ':' as 'host:path' (rsh
    # syntax), so `-C C:\...` fails with "Cannot connect to C: resolve failed".
    $tarExtraArgs = @()
    $tarExe = Join-Path $env:SystemRoot 'System32\tar.exe'
    if (-not (Test-Path -LiteralPath $tarExe)) {
        $tarCmd = Get-Command tar.exe -ErrorAction SilentlyContinue
        if (-not $tarCmd) {
            Err "$($G.Cross) tar.exe not found. Windows 10 build 17063 or later is required."
            exit 1
        }
        $tarExe = $tarCmd.Source
        # Fallback tar might be GNU (e.g. Git for Windows); --force-local
        # disables host:path parsing so drive letters work.
        $tarExtraArgs += '--force-local'
    }

    # -C avoids relying on the current directory.
    & $tarExe @tarExtraArgs -xzf $tarPath -C $McpDir
    $tarRc = $LASTEXITCODE
    Remove-Item -LiteralPath $tarPath -Force -ErrorAction SilentlyContinue
    if ($tarRc -ne 0) {
        Err "$($G.Cross) Failed to extract MCP Server (tar exit $tarRc)."
        exit 1
    }

    Set-Content -LiteralPath $VersionFile -Value $mcpLatest -NoNewline -Encoding ASCII

    if ($currentMcpVersion) {
        Ok "  $($G.Tick) MCP Server updated to $mcpLatest"
    } else {
        Ok "  $($G.Tick) MCP Server installed"
    }
}

# == Studio CLI (wp-studio) ==--------------------------------------------------
Write-Host ""
Info "Checking Studio CLI..."

# Put our bundled node first on PATH so npm.cmd finds its own node.exe.
$env:PATH = "$NodeDir;$env:PATH"

$studioLatest = ''
try {
    $viewOut = & $NpmBin view wp-studio version --loglevel=silent 2>$null
    if ($LASTEXITCODE -eq 0 -and $viewOut) {
        $studioLatest = ($viewOut | Out-String).Trim()
    }
} catch { $studioLatest = '' }

$currentStudioVersion = ''
try {
    $listOut = (& $NpmBin list -g wp-studio --depth=0 --loglevel=silent 2>&1 | Out-String)
    if ($listOut -match 'wp-studio@([^\s\r\n]+)') {
        $currentStudioVersion = $Matches[1].Trim()
    }
} catch { $currentStudioVersion = '' }

if ($currentStudioVersion -and $studioLatest -and ($currentStudioVersion -eq $studioLatest)) {
    Ok "  $($G.Tick) Studio CLI already up to date"
} else {
    Info "Installing Studio CLI..."
    $npmOutput = (& $NpmBin install -g wp-studio --loglevel=silent 2>&1 | Out-String)
    foreach ($line in ($npmOutput -split "`r?`n")) {
        if ($line -match '(?i)error') { Write-Host $line }
    }
    if ($currentStudioVersion) {
        Ok "  $($G.Tick) Studio CLI updated to $studioLatest"
    } else {
        Ok "  $($G.Tick) Studio CLI installed"
    }
}

$studioMjsPath = $null
try {
    $npmRootG = (& $NpmBin root -g --loglevel=silent 2>$null | Out-String).Trim()
    if ($npmRootG) {
        $studioPkgJson = Join-Path $npmRootG 'wp-studio\package.json'
        if (Test-Path -LiteralPath $studioPkgJson) {
            $studioPkg = Get-Content -LiteralPath $studioPkgJson -Raw | ConvertFrom-Json
            $binRel = $null
            if ($studioPkg.bin -is [string]) {
                $binRel = $studioPkg.bin
            } elseif ($studioPkg.bin -and $studioPkg.bin.studio) {
                $binRel = [string]$studioPkg.bin.studio
            }
            if ($binRel) {
                $candidate = Join-Path (Join-Path $npmRootG 'wp-studio') ($binRel -replace '/', '\')
                if (Test-Path -LiteralPath $candidate) {
                    $studioMjsPath = $candidate
                }
            }
        }
    }
} catch { $studioMjsPath = $null }

if (-not $studioMjsPath) {
    Err "$($G.Cross) Could not locate wp-studio's entry script. MCP spawning will fail."
    exit 1
}
