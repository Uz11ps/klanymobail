param(
  [Parameter(Mandatory = $true)]
  [string]$Server,

  [Parameter(Mandatory = $false)]
  [string]$User = "root",

  [Parameter(Mandatory = $false)]
  [string]$AppDir = "/opt/klany",

  [Parameter(Mandatory = $false)]
  [string]$EnvFile = ".env.server",

  [Parameter(Mandatory = $false)]
  [string]$ComposeFile = "docker-compose.yml",

  [Parameter(Mandatory = $false)]
  [switch]$AllowDirty,

  # Optional SSH private key path (recommended; avoids password prompts).
  [Parameter(Mandatory = $false)]
  [string]$IdentityFile = "",

  [Parameter(Mandatory = $false)]
  [int]$KeepReleases = 5
)

$ErrorActionPreference = "Stop"

function Run([string]$Exe, [string[]]$ArgList) {
  $rendered = ($ArgList | ForEach-Object { if ($_ -match '\s') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ } }) -join " "
  Write-Host ">" $Exe $rendered
  & $Exe @ArgList
  if ($LASTEXITCODE -ne 0) { throw "Command failed: $Exe $rendered" }
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$envPath = Join-Path $repoRoot $EnvFile
$composePath = Join-Path $repoRoot $ComposeFile

$archivePath = $null
$releaseName = $null

if (!(Test-Path $composePath)) {
  throw "Compose file not found: $composePath"
}
if (!(Test-Path $envPath)) {
  throw "Env file not found: $envPath (create it from .env.server.example)"
}

Push-Location $repoRoot
try {
  $hasGitDir = Test-Path (Join-Path $repoRoot ".git")
  $hasGitExe = $null -ne (Get-Command "git" -ErrorAction SilentlyContinue)

  $dirty = ""
  $commit = ""

  if ($hasGitDir -and $hasGitExe) {
    $dirty = (git status --porcelain) -join ""
    if ($dirty -and -not $AllowDirty) {
      throw "Worktree is dirty. Commit changes first or rerun with -AllowDirty."
    }

    $commit = (git rev-parse --short HEAD).Trim()
  } else {
    # Repo isn't a git worktree (or git not installed). We can still deploy,
    # but only from the current working tree with -AllowDirty.
    if (-not $AllowDirty) {
      throw "Not a git repository. Rerun with -AllowDirty so deploy can archive the working tree."
    }
    $dirty = "nogit"
    $commit = "nogit"
  }

  $ts = (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss")
  $releaseName = "$ts-$commit"

  $tmpBase = [System.IO.Path]::GetTempFileName()
  Remove-Item -Force $tmpBase
  $archivePath = "$tmpBase.tgz"

  if ($dirty -and $AllowDirty) {
    Write-Host "Creating archive from working tree (AllowDirty)..."
    # Pack the current workspace so changes are included without requiring a commit.
    # Exclude typical local artifacts and secret env files.
    $excludes = @(
      "--exclude=.git",
      "--exclude=.dart_tool",
      "--exclude=**/.dart_tool",
      "--exclude=**/build",
      "--exclude=**/node_modules",
      "--exclude=**/dist",
      "--exclude=.env",
      "--exclude=**/.env",
      "--exclude=.env.server",
      "--exclude=**/.env.server",
      "--exclude=.env.deploy",
      "--exclude=**/.env.deploy"
    )
    $tarArgs = @("-c", "-z", "-f", $archivePath, "-C", $repoRoot) + $excludes + @(".")
    Run "tar" $tarArgs
  } else {
    Write-Host "Creating archive from git HEAD ($commit)..."
    # Only tracked files, so we don't ship local artifacts/secrets.
    Run "git" @("archive", "--format=tar.gz", "-o", $archivePath, "HEAD")
  }

  $sshTarget = "$User@$Server"
  $sshCommon = @(
    "-o", "ConnectTimeout=12",
    "-o", "ServerAliveInterval=10",
    "-o", "ServerAliveCountMax=2",
    "-o", "StrictHostKeyChecking=accept-new"
  )
  if (-not [string]::IsNullOrWhiteSpace($IdentityFile)) {
    $sshCommon += @("-i", $IdentityFile)
  }
  $remoteTgz = "/tmp/klany-$releaseName.tgz"
  $remoteEnv = "$AppDir/shared/.env.server"
  $remoteReleaseDir = "$AppDir/releases/$releaseName"

  Write-Host "Uploading archive..."
  Run "scp" ($sshCommon + @($archivePath, "${sshTarget}:$remoteTgz"))

  Write-Host "Uploading env file..."
  Run "ssh" ($sshCommon + @($sshTarget, "mkdir -p '$AppDir/shared'"))
  Run "scp" ($sshCommon + @($envPath, "${sshTarget}:$remoteEnv"))

  $keepFrom = [Math]::Max($KeepReleases, 1) + 1
  $remoteScript = @'
set -e
set -u
# pipefail is bash-specific; don't fail if shell doesn't support it.
set -o pipefail 2>/dev/null || true

APP_DIR="__APP_DIR__"
REL_DIR="__REL_DIR__"
TGZ="__TGZ__"
ENV_FILE="__ENV_FILE__"
COMPOSE_FILE="__COMPOSE_FILE__"
KEEP_FROM="__KEEP_FROM__"

mkdir -p "$APP_DIR/releases" "$APP_DIR/shared"
mkdir -p "$REL_DIR"

tar -xzf "$TGZ" -C "$REL_DIR"
rm -f "$TGZ"

ln -sfn "$REL_DIR" "$APP_DIR/current"
cd "$APP_DIR/current"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is not installed; installing..."
  if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y ca-certificates curl gnupg
    curl -fsSL https://get.docker.com | sh
  else
    echo "Unsupported OS (no apt-get). Install docker manually and rerun."
    exit 1
  fi
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "docker compose plugin is missing; installing..."
  if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y docker-compose-plugin
  else
    echo "Unsupported OS (no apt-get). Install docker compose plugin manually and rerun."
    exit 1
  fi
fi

chmod +x scripts/server/stack-up.sh
./scripts/server/stack-up.sh "$(pwd)" "$ENV_FILE"
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" ps

if [ -d "$APP_DIR/releases" ]; then
  cd "$APP_DIR/releases"
  # Keep latest releases by release-name timestamp, not by filesystem mtime.
  # mtime can be overwritten by tar and accidentally delete the active release.
  ls -1d */ 2>/dev/null | sed 's:/$::' | sort -r | tail -n +"$KEEP_FROM" | xargs -r rm -rf --
fi
'@

  $remoteScript = $remoteScript.
    Replace("__APP_DIR__", $AppDir).
    Replace("__REL_DIR__", $remoteReleaseDir).
    Replace("__TGZ__", $remoteTgz).
    Replace("__ENV_FILE__", $remoteEnv).
    Replace("__COMPOSE_FILE__", $ComposeFile).
    Replace("__KEEP_FROM__", $keepFrom.ToString())

  Write-Host "Deploying on server..."
  # Important on Windows: ensure the remote script is LF-only (no CRLF),
  # otherwise bash on the server will see stray '\r' and fail.
  #
  # Also: piping large scripts into `ssh ... bash -s` sometimes results in a
  # truncated stream on some Windows/PowerShell setups, causing:
  #   "bash: line N: syntax error: unexpected end of file"
  # To make this reliable, we upload the script as a file and execute it.
  $remoteScriptLf = $remoteScript -replace "`r", ""
  $localScriptPath = [System.IO.Path]::GetTempFileName()
  $remoteScriptPath = "/tmp/klany-deploy-$releaseName.sh"
  try {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($localScriptPath, $remoteScriptLf, $utf8NoBom)
    Run "scp" ($sshCommon + @($localScriptPath, "${sshTarget}:$remoteScriptPath"))
    Run "ssh" ($sshCommon + @($sshTarget, "bash '$remoteScriptPath'; rm -f '$remoteScriptPath'"))
  } finally {
    if (Test-Path -LiteralPath $localScriptPath) { Remove-Item -Force -LiteralPath $localScriptPath }
  }

  Write-Host ""
  Write-Host "OK: deployed $releaseName"
  Write-Host "App dir: $AppDir/current"
} finally {
  Pop-Location
  if (![string]::IsNullOrWhiteSpace($archivePath) -and (Test-Path -LiteralPath $archivePath)) {
    Remove-Item -Force -LiteralPath $archivePath
  }
}

