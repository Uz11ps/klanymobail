$ErrorActionPreference = "Stop"

# Запуск Flutter приложения apps/klany_mobile из корня репозитория.
# Зачем: чтобы не нужно было вручную cd в папку проекта (pubspec.yaml там).

$proj = Join-Path $PSScriptRoot "apps\klany_mobile"
$pubspec = Join-Path $proj "pubspec.yaml"

if (-not (Test-Path $pubspec)) {
  Write-Host "Не найден pubspec.yaml: $pubspec" -ForegroundColor Red
  exit 1
}

Push-Location $proj
try {
  # Важно: .env загружается как asset, поэтому при изменениях нужен clean,
  # иначе может остаться старый конфиг и включится демо-режим.
  flutter clean | Out-Host
  flutter pub get | Out-Host
  flutter run -d windows
} finally {
  Pop-Location
}

