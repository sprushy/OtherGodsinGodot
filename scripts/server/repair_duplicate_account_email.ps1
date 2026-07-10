param(
    [Parameter(Mandatory = $true)]
    [string]$Email,

    [Parameter(Mandatory = $true)]
    [string]$KeepUsername,

    [Parameter(Mandatory = $true)]
    [string]$DeleteUsername,

    [string]$ServerDataDir = "C:\OtherGodsServer\server_runtime\server_data",

    [switch]$PreviewOnly
)

$ErrorActionPreference = "Stop"

$AccountsPath = Join-Path $ServerDataDir "accounts.json"
$DecksPath = Join-Path $ServerDataDir "account_decks.json"
$FriendsPath = Join-Path $ServerDataDir "friends.json"
$ProfilesPath = Join-Path $ServerDataDir "profiles.json"

function Normalize-Key {
    param([string]$Value)
    return $Value.Trim().ToLowerInvariant()
}

function ConvertTo-PlainValue {
    param($Value)

    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [System.Management.Automation.PSCustomObject]) {
        $result = [ordered]@{}
        foreach ($property in $Value.PSObject.Properties) {
            $result[$property.Name] = ConvertTo-PlainValue $property.Value
        }
        return $result
    }

    if ($Value -is [System.Collections.IDictionary]) {
        $result = [ordered]@{}
        foreach ($key in $Value.Keys) {
            $result[[string]$key] = ConvertTo-PlainValue $Value[$key]
        }
        return $result
    }

    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        $items = @()
        foreach ($item in $Value) {
            $items += ,(ConvertTo-PlainValue $item)
        }
        return $items
    }

    return $Value
}

function Read-JsonMap {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return [ordered]@{}
    }
    $raw = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return [ordered]@{}
    }
    return ConvertTo-PlainValue ($raw | ConvertFrom-Json)
}

function Write-JsonMap {
    param(
        [string]$Path,
        $Value
    )

    $json = $Value | ConvertTo-Json -Depth 100
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, $utf8NoBom)
}

function Ensure-Map {
    param($Value)
    if ($Value -is [System.Collections.IDictionary]) {
        return $Value
    }
    return [ordered]@{}
}

function Get-MapValue {
    param(
        $Map,
        [string]$Key,
        $Default = $null
    )
    if ($Map -is [System.Collections.IDictionary] -and $Map.Contains($Key)) {
        return $Map[$Key]
    }
    return $Default
}

function Remove-MapKey {
    param(
        $Map,
        [string]$Key
    )
    if ($Map -is [System.Collections.IDictionary] -and $Map.Contains($Key)) {
        [void]$Map.Remove($Key)
    }
}

function Backup-File {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return ""
    }
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupPath = "$Path.bak-$timestamp"
    Copy-Item -LiteralPath $Path -Destination $backupPath -Force
    return $backupPath
}

function Get-AccountEmailKey {
    param($Account)
    $emailKey = Normalize-Key ([string](Get-MapValue $Account "email_key" ""))
    if (-not $emailKey) {
        $emailKey = Normalize-Key ([string](Get-MapValue $Account "email" ""))
    }
    return $emailKey
}

function Get-AccountUsernameKey {
    param($Account)
    $usernameKey = Normalize-Key ([string](Get-MapValue $Account "username_key" ""))
    if (-not $usernameKey) {
        $usernameKey = Normalize-Key ([string](Get-MapValue $Account "username" ""))
    }
    return $usernameKey
}

function Rebuild-AccountIndexes {
    param($AccountsRoot)

    $accountsById = Ensure-Map (Get-MapValue $AccountsRoot "accounts_by_id" ([ordered]@{}))
    $emailIndex = [ordered]@{}
    $usernameIndex = [ordered]@{}

    foreach ($accountId in @($accountsById.Keys)) {
        $account = Ensure-Map $accountsById[$accountId]
        $emailKey = Get-AccountEmailKey $account
        if ($emailKey -and -not $emailIndex.Contains($emailKey)) {
            $emailIndex[$emailKey] = [string]$accountId
        }
        $usernameKey = Get-AccountUsernameKey $account
        if ($usernameKey -and -not $usernameIndex.Contains($usernameKey)) {
            $usernameIndex[$usernameKey] = [string]$accountId
        }
    }

    $AccountsRoot["account_id_by_email"] = $emailIndex
    $AccountsRoot["account_id_by_username"] = $usernameIndex
}

function Replace-DeletedAccountId {
    param(
        [string]$AccountId,
        [string]$KeepAccountId,
        $DeletedLookup
    )

    if ($DeletedLookup.Contains($AccountId)) {
        return $KeepAccountId
    }
    return $AccountId
}

function Repair-FriendsFile {
    param(
        [string]$Path,
        [string]$KeepAccountId,
        [string[]]$DeleteAccountIds
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return @()
    }
    $root = Read-JsonMap $Path
    $friendsByAccountId = Ensure-Map (Get-MapValue $root "friends_by_account_id" ([ordered]@{}))
    $friendRequestsById = Ensure-Map (Get-MapValue $root "friend_requests_by_id" ([ordered]@{}))
    $deckSharesById = Ensure-Map (Get-MapValue $root "deck_shares_by_id" ([ordered]@{}))
    $deletedLookup = @{}
    foreach ($accountId in $DeleteAccountIds) {
        $deletedLookup[$accountId] = $true
    }

    $keepFriends = Ensure-Map (Get-MapValue $friendsByAccountId $KeepAccountId ([ordered]@{}))
    foreach ($deletedId in $DeleteAccountIds) {
        $deletedFriends = Ensure-Map (Get-MapValue $friendsByAccountId $deletedId ([ordered]@{}))
        foreach ($friendId in @($deletedFriends.Keys)) {
            $resolvedFriendId = Replace-DeletedAccountId ([string]$friendId) $KeepAccountId $deletedLookup
            if ($resolvedFriendId -and $resolvedFriendId -ne $KeepAccountId) {
                $keepFriends[$resolvedFriendId] = $true
            }
        }
        Remove-MapKey $friendsByAccountId $deletedId
    }

    foreach ($accountId in @($friendsByAccountId.Keys)) {
        if ($deletedLookup.Contains([string]$accountId)) {
            Remove-MapKey $friendsByAccountId ([string]$accountId)
            continue
        }
        $friendLookup = Ensure-Map $friendsByAccountId[$accountId]
        $rewrittenLookup = [ordered]@{}
        foreach ($friendId in @($friendLookup.Keys)) {
            $resolvedFriendId = Replace-DeletedAccountId ([string]$friendId) $KeepAccountId $deletedLookup
            if ($resolvedFriendId -and $resolvedFriendId -ne [string]$accountId) {
                $rewrittenLookup[$resolvedFriendId] = $true
            }
        }
        $friendsByAccountId[$accountId] = $rewrittenLookup
    }

    $friendsByAccountId[$KeepAccountId] = $keepFriends
    foreach ($friendId in @($keepFriends.Keys)) {
        $friendLookup = Ensure-Map (Get-MapValue $friendsByAccountId ([string]$friendId) ([ordered]@{}))
        $friendLookup[$KeepAccountId] = $true
        foreach ($deletedId in $DeleteAccountIds) {
            Remove-MapKey $friendLookup $deletedId
        }
        $friendsByAccountId[[string]$friendId] = $friendLookup
    }

    foreach ($requestId in @($friendRequestsById.Keys)) {
        $request = Ensure-Map $friendRequestsById[$requestId]
        $requesterId = Replace-DeletedAccountId ([string](Get-MapValue $request "requester_account_id" "")) $KeepAccountId $deletedLookup
        $recipientId = Replace-DeletedAccountId ([string](Get-MapValue $request "recipient_account_id" "")) $KeepAccountId $deletedLookup
        if ($requesterId -and $requesterId -eq $recipientId) {
            Remove-MapKey $friendRequestsById ([string]$requestId)
            continue
        }
        $request["requester_account_id"] = $requesterId
        $request["recipient_account_id"] = $recipientId
        $friendRequestsById[$requestId] = $request
    }

    foreach ($shareId in @($deckSharesById.Keys)) {
        $share = Ensure-Map $deckSharesById[$shareId]
        $senderId = Replace-DeletedAccountId ([string](Get-MapValue $share "sender_account_id" "")) $KeepAccountId $deletedLookup
        $recipientId = Replace-DeletedAccountId ([string](Get-MapValue $share "recipient_account_id" "")) $KeepAccountId $deletedLookup
        if ($senderId -and $senderId -eq $recipientId) {
            Remove-MapKey $deckSharesById ([string]$shareId)
            continue
        }
        $share["sender_account_id"] = $senderId
        $share["recipient_account_id"] = $recipientId
        $deckSharesById[$shareId] = $share
    }

    $root["friends_by_account_id"] = $friendsByAccountId
    $root["friend_requests_by_id"] = $friendRequestsById
    $root["deck_shares_by_id"] = $deckSharesById

    if ($PreviewOnly) {
        return @("preview: would repair $Path")
    }
    $backup = Backup-File $Path
    Write-JsonMap $Path $root
    return @("repaired $Path", "backup $backup")
}

function Repair-DecksFile {
    param(
        [string]$Path,
        [string]$KeepAccountId,
        [string[]]$DeleteAccountIds
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return @()
    }
    $root = Read-JsonMap $Path
    $decksByAccountId = Ensure-Map (Get-MapValue $root "decks_by_account_id" ([ordered]@{}))
    $keepDecks = Ensure-Map (Get-MapValue $decksByAccountId $KeepAccountId ([ordered]@{}))

    foreach ($deletedId in $DeleteAccountIds) {
        $deletedDecks = Ensure-Map (Get-MapValue $decksByAccountId $deletedId ([ordered]@{}))
        foreach ($deckId in @($deletedDecks.Keys)) {
            $newDeckId = [string]$deckId
            $suffix = 1
            while ($keepDecks.Contains($newDeckId)) {
                $newDeckId = "{0}_migrated_{1}" -f $deckId, $suffix
                $suffix += 1
            }
            $deck = Ensure-Map $deletedDecks[$deckId]
            $deck["deck_id"] = $newDeckId
            $keepDecks[$newDeckId] = $deck
        }
        Remove-MapKey $decksByAccountId $deletedId
    }

    $decksByAccountId[$KeepAccountId] = $keepDecks
    $root["decks_by_account_id"] = $decksByAccountId
    if ($PreviewOnly) {
        return @("preview: would repair $Path")
    }
    $backup = Backup-File $Path
    Write-JsonMap $Path $root
    return @("repaired $Path", "backup $backup")
}

function Repair-ProfilesFile {
    param(
        [string]$Path,
        [string]$KeepAccountId,
        [string]$KeepUsername,
        [string[]]$DeleteAccountIds
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return @()
    }
    $profilesById = Read-JsonMap $Path
    $deletedLookup = @{}
    foreach ($accountId in $DeleteAccountIds) {
        $deletedLookup[$accountId] = $true
    }

    $hasKeepProfile = $false
    foreach ($profileId in @($profilesById.Keys)) {
        $profile = Ensure-Map $profilesById[$profileId]
        if ([string](Get-MapValue $profile "account_id" "") -eq $KeepAccountId) {
            $profile["account_username"] = $KeepUsername
            $profilesById[$profileId] = $profile
            $hasKeepProfile = $true
        }
    }

    $promotedDeletedProfile = $false
    foreach ($profileId in @($profilesById.Keys)) {
        $profile = Ensure-Map $profilesById[$profileId]
        $accountId = [string](Get-MapValue $profile "account_id" "")
        if (-not $deletedLookup.Contains($accountId)) {
            continue
        }
        if ($hasKeepProfile -or $promotedDeletedProfile) {
            Remove-MapKey $profilesById ([string]$profileId)
            continue
        }
        $profile["account_id"] = $KeepAccountId
        $profile["account_username"] = $KeepUsername
        $profile["display_name"] = $KeepUsername
        $profilesById[$profileId] = $profile
        $promotedDeletedProfile = $true
    }

    if ($PreviewOnly) {
        return @("preview: would repair $Path")
    }
    $backup = Backup-File $Path
    Write-JsonMap $Path $profilesById
    return @("repaired $Path", "backup $backup")
}

$emailKey = Normalize-Key $Email
$keepUsernameKey = Normalize-Key $KeepUsername
$deleteUsernameKey = Normalize-Key $DeleteUsername

if (-not (Test-Path -LiteralPath $AccountsPath)) {
    throw "accounts.json not found at $AccountsPath"
}

$accountsRoot = Read-JsonMap $AccountsPath
$accountsById = Ensure-Map (Get-MapValue $accountsRoot "accounts_by_id" ([ordered]@{}))
if ($accountsById.Count -eq 0) {
    throw "accounts.json did not contain accounts_by_id."
}

$matchingAccountIds = @()
$keepAccountIds = @()
$deleteAccountIds = @()
foreach ($accountId in @($accountsById.Keys)) {
    $account = Ensure-Map $accountsById[$accountId]
    if ((Get-AccountEmailKey $account) -ne $emailKey) {
        continue
    }
    $matchingAccountIds += [string]$accountId
    $usernameKey = Get-AccountUsernameKey $account
    if ($usernameKey -eq $keepUsernameKey) {
        $keepAccountIds += [string]$accountId
    } elseif ($usernameKey -eq $deleteUsernameKey) {
        $deleteAccountIds += [string]$accountId
    }
}

if ($keepAccountIds.Count -ne 1) {
    throw "Expected exactly one keep account for '$KeepUsername' and '$Email'; found $($keepAccountIds.Count)."
}
if ($deleteAccountIds.Count -eq 0) {
    Write-Host "No '$DeleteUsername' account exists for '$Email'. Rebuilding account indexes only."
}

$keepAccountId = $keepAccountIds[0]
$remainingUnexpectedMatches = @($matchingAccountIds | Where-Object {
    $_ -ne $keepAccountId -and $deleteAccountIds -notcontains $_
})
if ($remainingUnexpectedMatches.Count -gt 0) {
    Write-Warning "Leaving unexpected account id(s) for this email untouched: $($remainingUnexpectedMatches -join ', ')"
}

Write-Host "Email: $emailKey"
Write-Host "Keeping account: $keepAccountId ($KeepUsername)"
Write-Host "Deleting account(s): $($deleteAccountIds -join ', ')"

$keepAccount = Ensure-Map $accountsById[$keepAccountId]
$keepAccount["email"] = $emailKey
$keepAccount["email_key"] = $emailKey
$keepAccount["username"] = $KeepUsername
$keepAccount["username_key"] = $keepUsernameKey
$accountsById[$keepAccountId] = $keepAccount
foreach ($deleteAccountId in $deleteAccountIds) {
    Remove-MapKey $accountsById $deleteAccountId
}
$accountsRoot["accounts_by_id"] = $accountsById
Rebuild-AccountIndexes $accountsRoot

$messages = @()
if ($PreviewOnly) {
    $messages += "preview: would repair $AccountsPath"
} else {
    $messages += "backup $(Backup-File $AccountsPath)"
    Write-JsonMap $AccountsPath $accountsRoot
    $messages += "repaired $AccountsPath"
}

if ($deleteAccountIds.Count -gt 0) {
    $messages += Repair-FriendsFile $FriendsPath $keepAccountId $deleteAccountIds
    $messages += Repair-DecksFile $DecksPath $keepAccountId $deleteAccountIds
    $messages += Repair-ProfilesFile $ProfilesPath $keepAccountId $KeepUsername $deleteAccountIds
}

$messages | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object {
    Write-Host $_
}
