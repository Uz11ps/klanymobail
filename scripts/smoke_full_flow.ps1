[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '', Justification = 'Smoke script uses disposable test password only')]
param(
  [string]$BaseUrl = "https://klanymobail.ru/api",
  [string]$Password = "Test12345!"
)

$ErrorActionPreference = "Stop"

function PostJson([string]$Url, $Body, $Headers = @{}) {
  return Invoke-RestMethod -Method Post -Uri $Url -Headers $Headers -ContentType "application/json" -Body ($Body | ConvertTo-Json -Depth 10)
}

$ts = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$parentPhone = "79" + (Get-Random -Minimum 100000000 -Maximum 999999999)
$joinPhone = "79" + (Get-Random -Minimum 100000000 -Maximum 999999999)
$recoveryEmail = "smoke_recovery_$ts@mail.ru"
$deviceId = "smoke-device-$ts"
$deviceKey = "smoke-key-$ts"

# Parent phone-first sign-up (email is optional only for recovery)
$signup = PostJson "$BaseUrl/auth/sign-up" @{ phone = $parentPhone; password = $Password; recoveryEmail = $recoveryEmail; displayName = "Smoke Parent" }
$invite = $signup.family.familyCode
$parentToken = $signup.accessToken
$parentHeaders = @{ Authorization = "Bearer $parentToken" }

# Register push token (real token comes from device; in smoke we store a pseudo token)
PostJson "$BaseUrl/notifications/devices/register" @{ platform = "smoke"; pushToken = "smoke-$ts-parent" } $parentHeaders | Out-Null

# Recovery request should succeed and not leak existence
PostJson "$BaseUrl/auth/recover" @{ phone = $parentPhone } | Out-Null

# Optional: integration health (requires CRON_SECRET; loaded from local .env if present)
try {
  $envLocal = if (Test-Path ".env") { ".env" } elseif (Test-Path ".env.server") { ".env.server" } else { $null }
  if ($envLocal) {
    $cron = (Get-Content $envLocal | Where-Object { $_ -match '^CRON_SECRET=' } | Select-Object -First 1)
    if ($cron) {
      $secret = $cron.Split("=", 2)[1].Trim()
      if ($secret) {
        Invoke-RestMethod -Method Post -Uri "$BaseUrl/internal/integrations-health" -Headers @{ "x-cron-secret" = $secret } | Out-Null
      }
    }
  }
} catch { }

# Child access request with minimal data (no familyCode): childName + family last name + parent phone
$accessReq = PostJson "$BaseUrl/child/access-request" @{
  firstName  = "Smoke"
  familyLastName = "SmokeFamily"
  parentPhone = $parentPhone
  deviceId   = $deviceId
  deviceKey  = $deviceKey
}

PostJson "$BaseUrl/parent/access-requests/$($accessReq.requestId)/approve" @{} $parentHeaders | Out-Null

$childPoll = Invoke-RestMethod -Method Get -Uri "$BaseUrl/child/access-request/$($accessReq.requestId)/poll?deviceId=$deviceId&deviceKey=$deviceKey"
$childToken = $childPoll.accessToken
$childHeaders = @{ Authorization = "Bearer $childToken" }
$childId = @(
  $childPoll.childId,
  $childPoll.child.id
) | Where-Object { $_ } | Select-Object -First 1

PostJson "$BaseUrl/wallet/adjust" @{
  childId = $childId
  amount = 200
  note = "smoke topup"
} $parentHeaders | Out-Null

$product = PostJson "$BaseUrl/shop/products" @{
  title = "Smoke Product $ts"
  description = "autotest"
  price = 100
} $parentHeaders
$productId = @(
  $product.product.id,
  $product.id
) | Where-Object { $_ } | Select-Object -First 1

$purchase = PostJson "$BaseUrl/shop/purchases/request" @{
  productId = $productId
  quantity = 1
} $childHeaders
$purchaseId = @(
  $purchase.purchaseId,
  $purchase.purchase.id
) | Where-Object { $_ } | Select-Object -First 1

PostJson "$BaseUrl/shop/purchases/$purchaseId/decide" @{ approve = $true } $parentHeaders | Out-Null

$quest = PostJson "$BaseUrl/quests" @{
  title = "Smoke Quest $ts"
  description = "autotest"
  rewardAmount = 50
  questType = "one_time"
  childIds = @($childId)
} $parentHeaders
$questId = @(
  $quest.questId,
  $quest.quest.id
) | Where-Object { $_ } | Select-Object -First 1

PostJson "$BaseUrl/quests/child/submit" @{ questId = $questId } $childHeaders | Out-Null
PostJson "$BaseUrl/quests/review" @{
  questId = $questId
  childId = $childId
  approve = $true
  comment = "smoke ok"
} $parentHeaders | Out-Null

# Second parent joins by invite, also phone-first
PostJson "$BaseUrl/auth/sign-up" @{ phone = $joinPhone; password = $Password; displayName = "Smoke Join" } | Out-Null
$joinSignIn = PostJson "$BaseUrl/auth/sign-in" @{ login = $joinPhone; password = $Password }
$joinHeaders = @{ Authorization = "Bearer $($joinSignIn.accessToken)" }
PostJson "$BaseUrl/auth/accept-invite" @{ inviteToken = $invite } $joinHeaders | Out-Null

$context = Invoke-RestMethod -Method Get -Uri "$BaseUrl/family/context" -Headers $joinHeaders

@{
  ok = $true
  inviteToken = $invite
  parentUserId = $signup.user.id
  childId = $childId
  productId = $productId
  purchaseId = $purchaseId
  questId = $questId
  joinFamilyCode = $context.familyCode
  parentPhone = $parentPhone
} | ConvertTo-Json -Compress
