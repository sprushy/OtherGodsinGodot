param(
    [Parameter(Mandatory = $true)]
    [string]$Username,

    [Parameter(Mandatory = $true)]
    [string]$LocalProfilePath,

    [string]$ServerDataDir = "C:\OtherGodsServer\server_runtime\server_data",

    [string]$ProfileId = "",

    [switch]$PreviewOnly
)

$ErrorActionPreference = "Stop"

$AccountsPath = Join-Path $ServerDataDir "accounts.json"
$DecksPath = Join-Path $ServerDataDir "account_decks.json"

function Read-JsonObject {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{}
    }

    $raw = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return [pscustomobject]@{}
    }

    return $raw | ConvertFrom-Json
}

function Write-JsonObject {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        $InputObject
    )

    $json = $InputObject | ConvertTo-Json -Depth 100
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $json, $utf8NoBom)
}

function Backup-File {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupPath = "$Path.bak-$timestamp"
    Copy-Item -LiteralPath $Path -Destination $backupPath -Force
    return $backupPath
}

function ConvertTo-OrderedValue {
    param(
        [Parameter(Mandatory = $true)]
        $Value
    )

    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [System.Management.Automation.PSCustomObject]) {
        $ordered = [ordered]@{}
        foreach ($property in ($Value.PSObject.Properties | Sort-Object Name)) {
            $ordered[$property.Name] = ConvertTo-OrderedValue $property.Value
        }
        return $ordered
    }

    if ($Value -is [hashtable]) {
        $ordered = [ordered]@{}
        foreach ($key in ($Value.Keys | Sort-Object)) {
            $ordered[$key] = ConvertTo-OrderedValue $Value[$key]
        }
        return $ordered
    }

    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        $items = @()
        foreach ($item in $Value) {
            $items += ,(ConvertTo-OrderedValue $item)
        }
        return $items
    }

    return $Value
}

function Get-DeckSignature {
    param(
        [Parameter(Mandatory = $true)]
        $Deck
    )

    $normalized = [ordered]@{
        name = ([string]$Deck.name).Trim().ToLowerInvariant()
        cards = ConvertTo-OrderedValue $Deck.cards
        special_setup = ConvertTo-OrderedValue $Deck.special_setup
    }

    return $normalized | ConvertTo-Json -Depth 100 -Compress
}

function Get-DeckPriority {
    param(
        [Parameter(Mandatory = $true)]
        $Deck,

        [string]$PreferredDeckId,
        [string]$SelectedDeckId
    )

    $deckId = ([string]$Deck.deck_id).Trim()
    if ([string]::IsNullOrWhiteSpace($deckId)) {
        return 0
    }
    if ($deckId -eq $SelectedDeckId) {
        return 2
    }
    if ($deckId -eq $PreferredDeckId) {
        return 1
    }
    return 0
}

function Should-ReplaceDeck {
    param(
        [Parameter(Mandatory = $true)]
        $ExistingDeck,

        [Parameter(Mandatory = $true)]
        $CandidateDeck,

        [string]$PreferredDeckId,
        [string]$SelectedDeckId
    )

    $existingPriority = Get-DeckPriority -Deck $ExistingDeck -PreferredDeckId $PreferredDeckId -SelectedDeckId $SelectedDeckId
    $candidatePriority = Get-DeckPriority -Deck $CandidateDeck -PreferredDeckId $PreferredDeckId -SelectedDeckId $SelectedDeckId
    if ($candidatePriority -ne $existingPriority) {
        return $candidatePriority -gt $existingPriority
    }

    $existingUpdated = [int64]($ExistingDeck.updated_unix)
    $candidateUpdated = [int64]($CandidateDeck.updated_unix)
    if ($candidateUpdated -ne $existingUpdated) {
        return $candidateUpdated -gt $existingUpdated
    }

    $existingCreated = [int64]($ExistingDeck.created_unix)
    $candidateCreated = [int64]($CandidateDeck.created_unix)
    if ($candidateCreated -ne $existingCreated) {
        return $candidateCreated -gt $existingCreated
    }

    $existingId = ([string]$ExistingDeck.deck_id).Trim()
    $candidateId = ([string]$CandidateDeck.deck_id).Trim()
    if (($existingId -eq "") -ne ($candidateId -eq "")) {
        return $candidateId -ne ""
    }

    return $false
}

function Deduplicate-Decks {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Decks,

        [string]$PreferredDeckId = "",
        [string]$SelectedDeckId = ""
    )

    $deduped = New-Object System.Collections.ArrayList
    $deckIdToIndex = @{}
    $signatureToIndex = @{}

    foreach ($deck in $Decks) {
        if ($null -eq $deck) {
            continue
        }

        $deckId = ([string]$deck.deck_id).Trim()
        if ($deckId -and $deckIdToIndex.ContainsKey($deckId)) {
            $existingIndex = [int]$deckIdToIndex[$deckId]
            if (Should-ReplaceDeck -ExistingDeck $deduped[$existingIndex] -CandidateDeck $deck -PreferredDeckId $PreferredDeckId -SelectedDeckId $SelectedDeckId) {
                $deduped[$existingIndex] = $deck
            }
            continue
        }

        $signature = Get-DeckSignature -Deck $deck
        if ($signatureToIndex.ContainsKey($signature)) {
            $existingIndex = [int]$signatureToIndex[$signature]
            if (Should-ReplaceDeck -ExistingDeck $deduped[$existingIndex] -CandidateDeck $deck -PreferredDeckId $PreferredDeckId -SelectedDeckId $SelectedDeckId) {
                $deduped[$existingIndex] = $deck
                if ($deckId) {
                    $deckIdToIndex[$deckId] = $existingIndex
                }
            }
            continue
        }

        $nextIndex = $deduped.Count
        [void]$deduped.Add($deck)
        $signatureToIndex[$signature] = $nextIndex
        if ($deckId) {
            $deckIdToIndex[$deckId] = $nextIndex
        }
    }

    return @($deduped)
}

if (-not (Test-Path -LiteralPath $AccountsPath)) {
    throw "accounts.json not found at $AccountsPath"
}

if (-not (Test-Path -LiteralPath $LocalProfilePath)) {
    throw "Local profile file not found at $LocalProfilePath"
}

$accountsRoot = Read-JsonObject -Path $AccountsPath
$decksRoot = Read-JsonObject -Path $DecksPath
$localRoot = Read-JsonObject -Path $LocalProfilePath

if ($null -eq $accountsRoot.accounts_by_id) {
    throw "accounts.json is missing accounts_by_id."
}

if ($null -eq $decksRoot.decks_by_account_id) {
    $decksRoot | Add-Member -NotePropertyName "decks_by_account_id" -NotePropertyValue ([pscustomobject]@{}) -Force
}

$usernameKey = $Username.Trim().ToLowerInvariant()
$accountId = ""
if ($accountsRoot.account_id_by_username -and ($accountsRoot.account_id_by_username.PSObject.Properties.Name -contains $usernameKey)) {
    $accountId = [string]$accountsRoot.account_id_by_username.$usernameKey
}

if ([string]::IsNullOrWhiteSpace($accountId)) {
    foreach ($accountProperty in $accountsRoot.accounts_by_id.PSObject.Properties) {
        $account = $accountProperty.Value
        if ($null -eq $account) {
            continue
        }
        if (([string]$account.username).Trim().ToLowerInvariant() -eq $usernameKey) {
            $accountId = ([string]$account.account_id).Trim()
            break
        }
    }
}

if ([string]::IsNullOrWhiteSpace($accountId)) {
    throw "Could not find account_id for username '$Username' in $AccountsPath"
}

$resolvedProfileId = $ProfileId.Trim()
if ([string]::IsNullOrWhiteSpace($resolvedProfileId)) {
    if ($localRoot.account_profile_id_by_username -and ($localRoot.account_profile_id_by_username.PSObject.Properties.Name -contains $usernameKey)) {
        $resolvedProfileId = [string]$localRoot.account_profile_id_by_username.$usernameKey
    }
}
if ([string]::IsNullOrWhiteSpace($resolvedProfileId)) {
    $resolvedProfileId = [string]$localRoot.current_profile_id
}
if ([string]::IsNullOrWhiteSpace($resolvedProfileId)) {
    throw "Could not determine profile_id from $LocalProfilePath. Pass -ProfileId explicitly."
}

if ($null -eq $localRoot.decks_by_profile -or -not ($localRoot.decks_by_profile.PSObject.Properties.Name -contains $resolvedProfileId)) {
    throw "Profile '$resolvedProfileId' not found in $LocalProfilePath"
}

$localBucket = $localRoot.decks_by_profile.$resolvedProfileId
$localDecks = @($localBucket.PSObject.Properties | ForEach-Object { $_.Value })

$selectedDeckId = ""
if ($localRoot.last_selected_deck_by_profile -and ($localRoot.last_selected_deck_by_profile.PSObject.Properties.Name -contains $resolvedProfileId)) {
    $selectedDeckId = [string]$localRoot.last_selected_deck_by_profile.$resolvedProfileId
}

$existingServerDecks = @()
if ($decksRoot.decks_by_account_id.PSObject.Properties.Name -contains $accountId) {
    $serverBucket = $decksRoot.decks_by_account_id.$accountId
    $existingServerDecks = @($serverBucket.PSObject.Properties | ForEach-Object { $_.Value })
}

$combinedDecks = @($existingServerDecks + $localDecks)
$dedupedDecks = Deduplicate-Decks -Decks $combinedDecks -SelectedDeckId $selectedDeckId

$replacementBucket = [ordered]@{}
foreach ($deck in $dedupedDecks) {
    $deckId = ([string]$deck.deck_id).Trim()
    if ([string]::IsNullOrWhiteSpace($deckId)) {
        continue
    }
    $replacementBucket[$deckId] = $deck
}

Write-Host "Username: $Username"
Write-Host "Account ID: $accountId"
Write-Host "Profile ID: $resolvedProfileId"
Write-Host "Existing server deck count: $($existingServerDecks.Count)"
Write-Host "Recovered local deck count: $($localDecks.Count)"
Write-Host "Merged deduped deck count: $($replacementBucket.Count)"
Write-Host "Decks to keep:"
foreach ($deck in ($replacementBucket.Values | Sort-Object updated_unix -Descending)) {
    Write-Host (" - {0} [{1}] updated={2}" -f $deck.name, $deck.deck_id, $deck.updated_unix)
}

if ($PreviewOnly) {
    Write-Host "Preview only; no files were modified."
    return
}

$accountsBackup = Backup-File -Path $AccountsPath
$decksBackup = Backup-File -Path $DecksPath

$decksRoot.decks_by_account_id | Add-Member -NotePropertyName $accountId -NotePropertyValue ([pscustomobject]$replacementBucket) -Force
Write-JsonObject -Path $DecksPath -InputObject $decksRoot

Write-Host "accounts.json backup: $accountsBackup"
Write-Host "account_decks.json backup: $decksBackup"
Write-Host "Recovered decks written to $DecksPath"
