#Requires -Version 5.1
# This file is intentionally pure-ASCII. Unicode glyphs are built at runtime
# via [char]::ConvertFromUtf32 so the script parses correctly regardless of
# whether PowerShell reads .ps1 files as UTF-8 or the legacy ANSI code page.

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding           = [System.Text.Encoding]::UTF8
} catch { }

$InstallDir = Join-Path $env:USERPROFILE '.wordpress-developer-mcp'
$NodeBin    = Join-Path $InstallDir 'node\node.exe'

function _U([int]$cp) { [char]::ConvertFromUtf32($cp) }
$G = @{
    Bin    = (_U 0x1F5D1)                 # wastebasket
    Check  = (_U 0x2705)                  # white heavy check mark
    Tick   = (_U 0x2713)                  # check
    Warn   = ((_U 0x26A0) + (_U 0xFE0F))  # warning
    Bullet = (_U 0x2022)                  # bullet
    Rot    = (_U 0x21BA)                  # anticlockwise open circle arrow
    Info   = (_U 0x2139)                  # information source
}

function Info([string]$m) { Write-Host $m -ForegroundColor Yellow }
function Ok  ([string]$m) { Write-Host $m -ForegroundColor Green }
function Head([string]$m) { Write-Host $m -ForegroundColor Cyan }
function Link([string]$m) { Write-Host $m -ForegroundColor Blue }

Head "$($G.Bin)  Uninstalling WordPress Developer MCP Server..."

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

function Resolve-NativeExecutable {
    param([Parameter(Mandatory)][string]$Name)
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
    $resolved = Resolve-NativeExecutable -Name $Exe
    $savedErrorActionPreference = $ErrorActionPreference
    # Native CLIs can write expected messages to stderr. Do not let the
    # script-wide Stop policy turn those into terminating errors.
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

function Remove-McpServersJson {
    param([Parameter(Mandatory)][string]$ConfigFile)
    if (-not (Test-Path -LiteralPath $ConfigFile)) {
        return $false
    }

    if (Test-Path -LiteralPath $NodeBin) {
        # Prefer Node for JSON rewrites. PowerShell's ConvertTo-Json produces
        # very wide spacing in nested objects, and Claude Desktop has been
        # sensitive to config files rewritten that way.
        $script = @'
const fs = require('fs');
const configPath = process.env.WPMCP_CONFIG_FILE;

let config = {};
try {
  const raw = fs.readFileSync(configPath, 'utf8');
  if (raw && raw.trim()) config = JSON.parse(raw);
} catch (e) {
  process.exit(0);
}

if (!config || typeof config !== 'object' || !config.mcpServers || typeof config.mcpServers !== 'object') {
  process.exit(0);
}

delete config.mcpServers['wordpress-developer'];
if (Object.keys(config.mcpServers).length === 0) {
  delete config.mcpServers;
}

fs.writeFileSync(configPath, JSON.stringify(config, null, 2) + '\n');
'@
        $tempJs = Join-Path $env:TEMP ("wpmcp-uninstall-" + [Guid]::NewGuid().ToString('N') + '.js')
        [System.IO.File]::WriteAllText($tempJs, $script, (New-Object System.Text.UTF8Encoding($false)))
        $savedConfig = [Environment]::GetEnvironmentVariable('WPMCP_CONFIG_FILE', 'Process')
        [Environment]::SetEnvironmentVariable('WPMCP_CONFIG_FILE', $ConfigFile, 'Process')
        try {
            $null = & $NodeBin $tempJs 2>&1
            return ($LASTEXITCODE -eq 0)
        } catch {
            return $false
        } finally {
            Remove-Item -LiteralPath $tempJs -Force -ErrorAction SilentlyContinue
            [Environment]::SetEnvironmentVariable('WPMCP_CONFIG_FILE', $savedConfig, 'Process')
        }
    }

    try {
        $raw = Get-Content -LiteralPath $ConfigFile -Raw
        if (-not $raw.Trim()) { return $false }
        $config = $raw | ConvertFrom-Json
        if (-not $config.mcpServers) { return $false }
        $config.mcpServers.PSObject.Properties.Remove('wordpress-developer')
        if ($config.mcpServers.PSObject.Properties.Count -eq 0) {
            $config.PSObject.Properties.Remove('mcpServers')
        }
        $config | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $ConfigFile -Encoding UTF8
        return $true
    } catch {
        return $false
    }
}

function Remove-ZedSettings {
    param([Parameter(Mandatory)][string]$ConfigFile)
    if (-not (Test-Path -LiteralPath $ConfigFile)) {
        return $false
    }

    if (Test-Path -LiteralPath $NodeBin) {
        # Zed settings allow trailing commas, so plain ConvertFrom-Json can fail.
        # Reuse the small JS parser that strips only structural trailing commas.
        $script = @'
const fs = require('fs');
const configPath = process.env.WPMCP_CONFIG_FILE;
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
let raw = '';
try { raw = fs.readFileSync(configPath, 'utf8'); } catch (e) { process.exit(0); }
let config = {};
try { config = JSON.parse(stripTrailingCommas(raw.trim() || '{}')); } catch (e) { process.exit(1); }
if (!config.context_servers || typeof config.context_servers !== 'object') process.exit(0);
delete config.context_servers['wordpress-developer'];
if (Object.keys(config.context_servers).length === 0) delete config.context_servers;
fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
'@
        $tempJs = Join-Path $env:TEMP ("wpmcp-uninstall-" + [Guid]::NewGuid().ToString('N') + '.js')
        [System.IO.File]::WriteAllText($tempJs, $script, (New-Object System.Text.UTF8Encoding($false)))
        $savedConfig = [Environment]::GetEnvironmentVariable('WPMCP_CONFIG_FILE', 'Process')
        [Environment]::SetEnvironmentVariable('WPMCP_CONFIG_FILE', $ConfigFile, 'Process')
        try {
            $null = & $NodeBin $tempJs 2>&1
            return ($LASTEXITCODE -eq 0)
        } catch {
            return $false
        } finally {
            Remove-Item -LiteralPath $tempJs -Force -ErrorAction SilentlyContinue
            [Environment]::SetEnvironmentVariable('WPMCP_CONFIG_FILE', $savedConfig, 'Process')
        }
    }

    try {
        $raw = Get-Content -LiteralPath $ConfigFile -Raw
        if (-not $raw.Trim()) { return $false }
        $config = $raw | ConvertFrom-Json
        if (-not $config.context_servers) { return $false }
        $config.context_servers.PSObject.Properties.Remove('wordpress-developer')
        if ($config.context_servers.PSObject.Properties.Count -eq 0) {
            $config.PSObject.Properties.Remove('context_servers')
        }
        $config | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $ConfigFile -Encoding UTF8
        return $true
    } catch {
        return $false
    }
}

function Remove-CodexToml {
    $configFile = Join-Path $env:USERPROFILE '.codex\config.toml'
    if (-not (Test-Path -LiteralPath $configFile)) {
        return $false
    }

    try {
        $content = Get-Content -LiteralPath $configFile -Raw
        # Remove the main server section and nested per-tool approval sections,
        # e.g. [mcp_servers.wordpress-developer.tools.studio_site_list].
        $content = $content -replace '(?m)^\[mcp_servers\.wordpress-developer(?:\.[^\]]+)?\](?:\r?\n(?!\[)[^\r\n]*)*', ''
        Set-Content -LiteralPath $configFile -Value ($content.TrimEnd() + "`n") -Encoding UTF8
        return $true
    } catch {
        return $false
    }
}

Write-Host ""
Info "Removing MCP configuration from AI agents..."

if ((Test-Command 'codex') -or (Test-AppxPackage 'OpenAI.Codex')) {
    if (Test-Command 'codex') {
        try { $null = Invoke-ExternalQuiet -Exe 'codex' -Arguments @('mcp','remove','wordpress-developer') } catch { }
    } else {
        $null = Remove-CodexToml
    }
    Ok "  $($G.Tick) Codex"
}

$claudeDesktopFound = Test-AnyPath @(
    (Join-Path $env:LOCALAPPDATA 'AnthropicClaude'),
    (Join-Path $env:LOCALAPPDATA 'Programs\Claude'),
    (Join-Path ${env:ProgramFiles} 'Claude')
)
if ($claudeDesktopFound) {
    $claudeCfg = Join-Path $env:APPDATA 'Claude\claude_desktop_config.json'
    $null = Remove-McpServersJson -ConfigFile $claudeCfg
    Ok "  $($G.Tick) Claude Desktop"
}

if (Test-Command 'claude') {
    try {
        $null = Invoke-ExternalQuiet -Exe 'claude' -Arguments @('mcp','remove','wordpress-developer','--scope','user')
    } catch { }
    Ok "  $($G.Tick) Claude Code"
}

$cursorFound = (Test-Command 'cursor') -or `
    (Test-Path -LiteralPath (Join-Path $env:LOCALAPPDATA 'Programs\cursor\Cursor.exe'))
if ($cursorFound) {
    $cursorCfg = Join-Path $env:USERPROFILE '.cursor\mcp.json'
    $null = Remove-McpServersJson -ConfigFile $cursorCfg
    Ok "  $($G.Tick) Cursor"
}

$windsurfFound = (Test-Command 'windsurf') -or `
    (Test-Path -LiteralPath (Join-Path $env:LOCALAPPDATA 'Programs\Windsurf\Windsurf.exe'))
if ($windsurfFound) {
    $windsurfCfg = Join-Path $env:USERPROFILE '.codeium\windsurf\mcp_config.json'
    $null = Remove-McpServersJson -ConfigFile $windsurfCfg
    Ok "  $($G.Tick) Windsurf"
}

$zedFound = Test-Path -LiteralPath (Join-Path $env:LOCALAPPDATA 'Programs\Zed\Zed.exe')
if ($zedFound) {
    $zedCfg = Join-Path $env:APPDATA 'Zed\settings.json'
    $null = Remove-ZedSettings -ConfigFile $zedCfg
    Ok "  $($G.Tick) Zed"
}

Write-Host ""
Info "Installation directory left in place:"
Write-Host "  $InstallDir"
# The installer directory contains the bundled runtime and helper files. Leave it
# for manual removal so uninstalling MCP config cannot delete useful local state.
Write-Host "  You can remove it manually if you no longer need the bundled runtime and files."

$sitesDir = Join-Path $env:USERPROFILE 'Studio'
if (Test-Path -LiteralPath $sitesDir) {
    Write-Host ""
    Link "$($G.Info)  Your WordPress sites are still available at $sitesDir"
    Write-Host "   If you no longer need them, remove that folder manually."
}

Write-Host ""
Ok "$($G.Check) Uninstall complete!"
Write-Host ""
Info "$($G.Rot)  Restart these apps to apply the changes:"
if ($claudeDesktopFound) { Info "  $($G.Bullet) Claude Desktop" }
if ($windsurfFound) { Info "  $($G.Bullet) Windsurf" }
if ($zedFound) { Info "  $($G.Bullet) Zed" }
if (Test-AppxPackage 'OpenAI.Codex') { Info "  $($G.Bullet) Codex" }
Write-Host ""
