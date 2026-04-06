# deploy-windows.ps1 — Intune / Windows MDM deployment for claude-hub
# Installs the claude-hub plugin, deploys org CLAUDE.md to the managed policy
# path, and configures team membership.
#
# Claude Code reads the managed policy CLAUDE.md from:
#   C:\Program Files\ClaudeCode\CLAUDE.md
# This file cannot be excluded by individual users and is always loaded.
#
# Parameters (set via Intune script arguments or environment variables):
#   CLAUDE_HUB_TEAM     — Team name (e.g., "platform")
#   CLAUDE_HUB_REPO_URL — Repo URL  (e.g., "https://github.com/myorg/claude-hub.git")

param(
    [string]$Team = $env:CLAUDE_HUB_TEAM,
    [string]$RepoUrl = $env:CLAUDE_HUB_REPO_URL
)

$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Output "[$timestamp] $Message"
    # Also write to Windows Event Log if available
    try {
        if (-not [System.Diagnostics.EventLog]::SourceExists("claude-hub")) {
            New-EventSource -LogName Application -Source "claude-hub" -ErrorAction SilentlyContinue
        }
        Write-EventLog -LogName Application -Source "claude-hub" -EventId 1000 -EntryType Information -Message $Message -ErrorAction SilentlyContinue
    } catch {
        # Event log writing is best-effort
    }
}

function Write-LogError {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Error "[$timestamp] ERROR: $Message"
}

# --- Validate parameters ---
if ([string]::IsNullOrWhiteSpace($Team)) {
    Write-LogError "Team name is required (param -Team or CLAUDE_HUB_TEAM env var)"
    exit 1
}
if ([string]::IsNullOrWhiteSpace($RepoUrl)) {
    Write-LogError "Repo URL is required (param -RepoUrl or CLAUDE_HUB_REPO_URL env var)"
    exit 1
}

# --- Detect user home directory ---
$UserHome = $env:USERPROFILE
if ([string]::IsNullOrWhiteSpace($UserHome)) {
    # Fallback: find logged-in user profile
    $loggedInUser = (Get-CimInstance -ClassName Win32_ComputerSystem).UserName
    if ($loggedInUser) {
        $username = $loggedInUser.Split('\')[-1]
        $UserHome = "C:\Users\$username"
    }
}

if (-not (Test-Path $UserHome)) {
    Write-LogError "User home directory not found: $UserHome"
    exit 1
}

Write-Log "Deploying claude-hub for home=$UserHome team=$Team"

# --- Directory structure ---
$ClaudeDir = Join-Path $UserHome ".claude"
$HubDir = Join-Path $ClaudeDir "claude-hub"
$PluginDest = Join-Path $ClaudeDir "plugins\local\claude-hub"
$InstalledJson = Join-Path $ClaudeDir "plugins\installed_plugins.json"

New-Item -ItemType Directory -Path $HubDir -Force | Out-Null
New-Item -ItemType Directory -Path $PluginDest -Force | Out-Null
New-Item -ItemType Directory -Path (Split-Path $InstalledJson) -Force | Out-Null

# --- Write config files ---
Set-Content -Path (Join-Path $HubDir "team") -Value $Team -NoNewline
Set-Content -Path (Join-Path $HubDir "repo_url") -Value $RepoUrl -NoNewline
Write-Log "Wrote team=$Team and repo_url to $HubDir"

# --- Clone or update central repo ---
$RepoCloneDir = Join-Path $HubDir "repo"

# Check if git is available
$gitPath = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitPath) {
    Write-LogError "git is not installed or not in PATH"
    exit 1
}

if (Test-Path (Join-Path $RepoCloneDir ".git")) {
    Write-Log "Repo already cloned, pulling latest..."
    & git -C $RepoCloneDir fetch --depth=1 origin 2>&1 | ForEach-Object { Write-Log "git: $_" }
    & git -C $RepoCloneDir reset --hard origin/HEAD 2>&1 | ForEach-Object { Write-Log "git: $_" }
} else {
    Write-Log "Cloning repo $RepoUrl..."
    if (Test-Path $RepoCloneDir) {
        Remove-Item -Recurse -Force $RepoCloneDir
    }
    & git clone --depth=1 $RepoUrl $RepoCloneDir 2>&1 | ForEach-Object { Write-Log "git: $_" }
}

if ($LASTEXITCODE -ne 0) {
    Write-LogError "Git operation failed with exit code $LASTEXITCODE"
    exit 1
}

# --- Deploy org files to managed policy path ---
$ManagedPolicyDir = "C:\Program Files\ClaudeCode"
New-Item -ItemType Directory -Path $ManagedPolicyDir -Force | Out-Null

$OrgClaudeMd = Join-Path $RepoCloneDir "org\CLAUDE.md"
if (Test-Path $OrgClaudeMd) {
    Copy-Item -Path $OrgClaudeMd -Destination (Join-Path $ManagedPolicyDir "CLAUDE.md") -Force
    Write-Log "Deployed org CLAUDE.md to $ManagedPolicyDir\CLAUDE.md"
} else {
    Write-Log "Warning: org/CLAUDE.md not found in repo, skipping managed policy CLAUDE.md"
}

$OrgSettings = Join-Path $RepoCloneDir "org\settings.json"
if (Test-Path $OrgSettings) {
    Copy-Item -Path $OrgSettings -Destination (Join-Path $ManagedPolicyDir "managed-settings.json") -Force
    Write-Log "Deployed org settings.json to $ManagedPolicyDir\managed-settings.json (MCP servers, marketplaces, plugins)"
} else {
    Write-Log "Warning: org/settings.json not found in repo, skipping managed policy settings"
}

# --- Copy plugin files ---
$PluginSrc = Join-Path $RepoCloneDir "plugin"
if (Test-Path $PluginSrc) {
    Write-Log "Copying plugin files from $PluginSrc to $PluginDest"
    # Mirror the source directory
    Get-ChildItem -Path $PluginDest -Recurse | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Copy-Item -Path "$PluginSrc\*" -Destination $PluginDest -Recurse -Force
} else {
    Write-LogError "Plugin source directory not found at $PluginSrc"
    exit 1
}

# --- Patch installed_plugins.json ---
$PluginEntry = Join-Path $PluginDest ".claude-plugin"
$pluginObj = @{ name = "claude-hub"; path = $PluginEntry }

if (Test-Path $InstalledJson) {
    $rawJson = Get-Content -Path $InstalledJson -Raw
    $data = $rawJson | ConvertFrom-Json

    # Normalize to array
    if ($data -is [System.Array]) {
        $plugins = [System.Collections.ArrayList]@($data)
    } elseif ($data.plugins) {
        $plugins = [System.Collections.ArrayList]@($data.plugins)
    } else {
        $plugins = [System.Collections.ArrayList]::new()
    }

    # Check if already registered
    $alreadyRegistered = $false
    foreach ($p in $plugins) {
        if ($p.path -eq $PluginEntry -or $p.name -eq "claude-hub") {
            $alreadyRegistered = $true
            break
        }
    }

    if ($alreadyRegistered) {
        Write-Log "Plugin already registered in installed_plugins.json"
    } else {
        Write-Log "Adding plugin entry to existing installed_plugins.json"
        $plugins.Add($pluginObj) | Out-Null

        if ($data -is [System.Array]) {
            $outputData = $plugins.ToArray()
        } else {
            $data.plugins = $plugins.ToArray()
            $outputData = $data
        }
        $outputData | ConvertTo-Json -Depth 10 | Set-Content -Path $InstalledJson
    }
} else {
    Write-Log "Creating installed_plugins.json"
    @($pluginObj) | ConvertTo-Json -Depth 10 | Set-Content -Path $InstalledJson
}

# --- Run initial sync ---
$SyncScript = Join-Path $PluginDest "scripts\sync.sh"
$bashPath = Get-Command bash -ErrorAction SilentlyContinue
if ($bashPath -and (Test-Path $SyncScript)) {
    Write-Log "Running initial sync..."
    $env:CLAUDE_PLUGIN_ROOT = $PluginDest
    & bash $SyncScript 2>&1 | ForEach-Object { Write-Log "sync: $_" }
    Write-Log "Initial sync completed"
} else {
    Write-Log "Warning: bash or sync script not found, skipping initial sync"
}

Write-Log "claude-hub deployment completed successfully"
exit 0
