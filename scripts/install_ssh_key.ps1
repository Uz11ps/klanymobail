param(
  [Parameter(Mandatory = $true)]
  [string]$Server,

  [Parameter(Mandatory = $false)]
  [string]$User = "root",

  [Parameter(Mandatory = $false)]
  [string]$PubKeyPath = "$env:USERPROFILE\.ssh\klanymobail_ed25519.pub"
)

$ErrorActionPreference = "Stop"

function RunNative([string]$Exe, [string[]]$ArgList) {
  $rendered = ($ArgList | ForEach-Object { if ($_ -match '\s') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ } }) -join " "
  Write-Host ">" $Exe $rendered
  & $Exe @ArgList
  if ($LASTEXITCODE -ne 0) { throw "Command failed: $Exe $rendered" }
}

if (-not (Test-Path -LiteralPath $PubKeyPath)) {
  Write-Host "Не найден публичный ключ: $PubKeyPath" -ForegroundColor Red
  exit 1
}

# На случай если у IP уже был другой host-key.
ssh-keygen -R $Server | Out-Host
ssh-keygen -R "[$Server]:22" | Out-Host

$sshTarget = "$User@$Server"

Write-Host "Сейчас будет запрос пароля root (введи пароль сервера)." -ForegroundColor Yellow

# Важно: убираем \r из Windows-строки ключа, иначе authorized_keys может не принять ключ.
$pubKey = (Get-Content -Raw -LiteralPath $PubKeyPath) -replace "`r", ""
if ([string]::IsNullOrWhiteSpace($pubKey) -or $pubKey.Trim().Length -lt 20) {
  throw "Public key content looks empty: $PubKeyPath"
}

# Используем tr -d '\r' + нормализуем уже существующий authorized_keys (убираем CR).
$remoteCmd = "mkdir -p ~/.ssh && chmod 700 ~/.ssh && if [ -f ~/.ssh/authorized_keys ]; then sed -i 's/\\r$//' ~/.ssh/authorized_keys; fi && tr -d '\\r' >> ~/.ssh/authorized_keys && sed -i 's/\\r$//' ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"

# Передаем ключ в stdin ssh через cmd, чтобы пайп работал предсказуемо на Windows.
cmd /c "type ""$PubKeyPath"" | ssh -o StrictHostKeyChecking=accept-new $sshTarget ""$remoteCmd"""
if ($LASTEXITCODE -ne 0) { throw "Failed to append key to authorized_keys" }

Write-Host "OK: ключ добавлен. Проверка..." -ForegroundColor Green
RunNative "ssh" @(
  "-o", "BatchMode=yes",
  "-o", "PreferredAuthentications=publickey",
  "-o", "PasswordAuthentication=no",
  "-i", "$env:USERPROFILE\.ssh\klanymobail_ed25519",
  $sshTarget,
  "echo ok"
)

