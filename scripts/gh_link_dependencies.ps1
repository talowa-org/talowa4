Param(
  [Parameter(Mandatory=$true)][string]$Repo,
  [Parameter(Mandatory=$false)][ValidateSet("Auto", "CommentsOnly")][string]$LinksMode = "Auto",
  [Parameter(Mandatory=$false)][switch]$DryRun
)

# Link dependencies between issues created from project_issues/*.md
# Strategy:
# 1) Build a map of issue Title -> Number from the GitHub repo
# 2) Parse dependency hints from local markdown files (Dependencies / Related sections)
# 3) Create bidirectional relations using gh issue link if available, else comments fallback
#
# Parameters:
# -Repo: GitHub repository in format "owner/repo"
# -LinksMode: "Auto" (default) tries gh issue link then falls back to comments; "CommentsOnly" skips link attempts
# -DryRun: Preview mode - shows what would be done without making changes

function Get-IssueMap {
  param([string]$Repo)
  $json = gh issue list --repo $Repo --state all --limit 200 --json title,number,state 2>$null
  if (-not $json) { return @{} }
  $items = $json | ConvertFrom-Json
  $map = @{}
  $stateMap = @{}
  foreach ($it in $items) {
    if (-not $map.ContainsKey($it.title)) {
      $map[$it.title] = [int]$it.number
      $stateMap[$it.title] = $it.state
    } else {
      # Prefer OPEN over CLOSED for the same title
      if ($stateMap[$it.title] -ne 'OPEN' -and $it.state -eq 'OPEN') {
        $map[$it.title] = [int]$it.number
        $stateMap[$it.title] = $it.state
      }
    }
  }
  return $map
}

function Get-AliasMap {
  param([hashtable]$IssueMap)
  $alias = @{}
  foreach ($title in $IssueMap.Keys) {
    # Title format: "NN Name ..." -> alias: remove leading index and space
    if ($title -match '^[0-9]{2}\s+(?<name>.+)$') {
      $name = $Matches['name']
    } else { $name = $title }
    $alias[$name.ToLower()] = $title
  }
  return $alias
}

function Test-GhIssueLinkAvailable {
  if ($LinksMode -eq 'CommentsOnly') { return $false }
  $help = gh issue link --help 2>&1
  return ($help -notmatch 'unknown command')
}

function Invoke-CommentLink {
  param(
    [string]$Repo,
    [int]$fromNumber,
    [int]$toNumber,
    [string]$relation # 'blocked_by' | 'blocks' | 'relates'
  )
  switch ($relation) {
    'blocked_by' { $marker = "Blocked by #$toNumber" }
    'blocks'     { $marker = "Blocks #$toNumber" }
    default      { $marker = "Related to #$toNumber" }
  }
  $view = gh issue view $fromNumber --repo $Repo --json comments 2>$null | ConvertFrom-Json
  $exists = $false
  if ($view -and $view.comments) {
    foreach ($c in $view.comments) { if ($c.body -match [regex]::Escape($marker)) { $exists = $true; break } }
  }
  if (-not $exists) {
    if (-not $DryRun) { gh issue comment $fromNumber --repo $Repo --body $marker | Out-Null }
    Write-Host "Linked via comment: #$fromNumber -> $marker"
  } else { Write-Host "Already linked via comment: #$fromNumber -> $marker" }
}

function Try-Link {
  param(
    [string]$Repo,
    [hashtable]$IssueMap,
    [string]$fromTitle,
    [string]$toTitle,
    [string]$type # 'blocks' or 'relates'
  )
  if (-not $IssueMap.ContainsKey($fromTitle)) { Write-Warning "Skip: source issue not found '$fromTitle'"; return }
  if (-not $IssueMap.ContainsKey($toTitle))   { Write-Warning "Skip: target issue not found '$toTitle'"; return }
  $fromNum = $IssueMap[$fromTitle]
  $toNum = $IssueMap[$toTitle]

  $canLink = $false; try { $canLink = Test-GhIssueLinkAvailable } catch { $canLink = $false }
  if ($canLink) {
    try {
      if ($type -eq 'blocks') {
        gh issue link $fromNum $toNum --repo $Repo --type "blocked_by" | Out-Null
        gh issue link $toNum $fromNum --repo $Repo --type "blocks" | Out-Null
        Write-Host "Linked (blocks): '$fromTitle' (#$fromNum) blocked by '$toTitle' (#$toNum)"
      } else {
        gh issue link $fromNum $toNum --repo $Repo --type "relates_to" | Out-Null
        gh issue link $toNum $fromNum --repo $Repo --type "relates_to" | Out-Null
        Write-Host "Linked (relates): '$fromTitle' <-> '$toTitle'"
      }
      return
    } catch { Write-Warning "gh issue link failed, falling back to comments: $_" }
  }
  if ($type -eq 'blocks') {
    Invoke-CommentLink -Repo $Repo -fromNumber $fromNum -toNumber $toNum -relation 'blocked_by'
    Invoke-CommentLink -Repo $Repo -fromNumber $toNum -toNumber $fromNum -relation 'blocks'
  } else {
    Invoke-CommentLink -Repo $Repo -fromNumber $fromNum -toNumber $toNum -relation 'relates'
    Invoke-CommentLink -Repo $Repo -fromNumber $toNum -toNumber $fromNum -relation 'relates'
  }
}

function Parse-DependenciesFromFile {
  param(
    [string]$FilePath,
    [hashtable]$AliasMap
  )
  $content = Get-Content -Raw -Path $FilePath
  $deps = @()
  # Capture sections containing Dependencies or Related
  $sections = @()
  if ($content -match "(?s)Dependencies\s*(?<block>.*?)(\n\n|\r\n\r\n|Acceptance Criteria|Files to Modify|Labels)") { $sections += $Matches['block'] }
  if ($content -match "(?s)Related\s*/?\s*Dependencies\s*(?<block2>.*?)(\n\n|\r\n\r\n|Acceptance Criteria|Files to Modify|Labels)") { $sections += $Matches['block2'] }
  foreach ($sec in $sections) {
    # Look for lines like: "- Something" and match known alias names
    $lines = $sec -split "\r?\n"
    foreach ($ln in $lines) {
      if ($ln -match "^-\\s*(.+)$") {
        $item = $Matches[1].Trim()
        # Normalize by removing punctuation and file suffixes
        $item2 = ($item -replace "\(.+?\)", "") -replace "\.md", ""
        # Try to find alias match by contains
        foreach ($ak in $AliasMap.Keys) {
          if ($item2.ToLower().Contains($ak)) { $deps += $AliasMap[$ak]; break }
        }
      }
    }
  }
  # De-dup
  $deps = $deps | Select-Object -Unique
  return $deps
}

# MAIN
Write-Host "Building issue map from $Repo ..."
$issueMap = Get-IssueMap -Repo $Repo
if ($issueMap.Count -eq 0) { Write-Error "No issues found in $Repo."; exit 1 }
$aliasMap = Get-AliasMap -IssueMap $issueMap

# Track relationships for summary comments
$DependsOn = @{}
$Blocks = @{}
$Relates = @{}
function Add-Rel($dict, $from, $to) { if (-not $dict.ContainsKey($from)) { $dict[$from] = [System.Collections.Generic.HashSet[string]]::new() }; $null = $dict[$from].Add($to) }

# Wrap Try-Link to also record relationships
function Invoke-Link {
  param([string]$fromTitle,[string]$toTitle,[string]$type)
  if ($type -eq 'blocks') {
    Add-Rel -dict $DependsOn -from $fromTitle -to $toTitle
    Add-Rel -dict $Blocks -from $toTitle -to $fromTitle
  } else {
    Add-Rel -dict $Relates -from $fromTitle -to $toTitle
    Add-Rel -dict $Relates -from $toTitle -to $fromTitle
  }
  Try-Link -Repo $Repo -IssueMap $issueMap -fromTitle $fromTitle -toTitle $toTitle -type $type
}

# Iterate over local project_issues files and link based on parsed dependencies
$files = Get-ChildItem -Path "project_issues" -Filter "*.md" | Where-Object { $_.Name -ne 'README.md' }
foreach ($f in $files) {
  $title = (Get-Item $f.FullName).BaseName.Replace('_',' ')
  $deps = Parse-DependenciesFromFile -FilePath $f.FullName -AliasMap $aliasMap
  foreach ($depTitle in $deps) {
    if ($depTitle -ne $title) {
      Write-Host "Parsed dependency: '$title' -> '$depTitle'"
      Invoke-Link -fromTitle $title -toTitle $depTitle -type 'blocks'
    }
  }
}

# Cross-feature explicit relationships
Invoke-Link -fromTitle '10 Knowledge Center' -toTitle '01 AI Assistant Core' -type 'relates'
Invoke-Link -fromTitle '09 Safety Moderation' -toTitle '06 Messaging Enhancements' -type 'relates'
Invoke-Link -fromTitle '08 Network Referrals' -toTitle '02 Land Records CRUD' -type 'relates'

# Campaign Management depends on Messaging Enhancements
Invoke-Link -fromTitle '07 Campaign Management' -toTitle '06 Messaging Enhancements' -type 'blocks'

# Emergency depends on Notifications -> create infra issue if missing
function Get-Or-CreateIssue {
  param([string]$title,[string]$body,[string[]]$labels)
  # Try to find by exact title (open or closed)
  $existing = gh issue list --repo $Repo --state all --limit 200 --json title,number 2>$null | ConvertFrom-Json
  if ($existing) {
    foreach ($e in $existing) { if ($e.title -eq $title) { return [int]$e.number } }
  }
  # Create new issue
  $args = @('--repo', $Repo, '--title', $title, '--body', $body)
  foreach ($l in $labels) { $args += @('--label', $l) }
  $out = gh issue create @args
  Write-Host "Created infrastructure issue: $title"
  # Refresh and fetch number
  $existing2 = gh issue list --repo $Repo --state all --limit 200 --json title,number 2>$null | ConvertFrom-Json
  if ($existing2) { foreach ($e in $existing2) { if ($e.title -eq $title) { return [int]$e.number } } }
  return $null
}

$notifTitle = 'Notification Infrastructure'
$notifBody = @"
# Notification Infrastructure
Push topics, SMS backup, and messaging pipeline for alerts and broadcasts.

- Files: lib/services/notifications/notification_service.dart; Cloud Functions (SMS)
- Supports: Emergency System, Campaigns, Messaging
"@
$notifNum = Get-Or-CreateIssue -title $notifTitle -body $notifBody -labels @('type: enhancement','priority: high','complexity: medium')
if ($notifNum) { Invoke-Link -fromTitle '03 Emergency System' -toTitle $notifTitle -type 'blocks' }
else { Write-Warning "Failed to ensure Notification Infrastructure issue" }

# Create Firestore Rules & Indexes and Testing Infrastructure
$rulesTitle = 'Firestore Rules & Indexes'
$rulesBody = @"
# Firestore Rules & Indexes
Harden security rules and ensure required composite indexes from Tasks_List.md.
"@
$rulesNum = Get-Or-CreateIssue -title $rulesTitle -body $rulesBody -labels @('type: enhancement','priority: high','complexity: easy')

$testsTitle = 'Testing Infrastructure'
$testsBody = @"
# Testing Infrastructure
Unit test scaffolding and CI per Validation checklist.
"@
$testsNum = Get-Or-CreateIssue -title $testsTitle -body $testsBody -labels @('type: enhancement','priority: medium','complexity: medium')

# Link all feature issues to Rules & Indexes (blocks) and Testing (relates)
$allFeatures = @('01 AI Assistant Core','02 Land Records CRUD','03 Emergency System','04 Legal Cases','05 Analytics Dashboard','06 Messaging Enhancements','07 Campaign Management','08 Network Referrals','09 Safety Moderation','10 Knowledge Center')
foreach ($t in $allFeatures) {
  if ($rulesNum) { Invoke-Link -fromTitle $t -toTitle $rulesTitle -type 'blocks' }
  if ($testsNum) { Invoke-Link -fromTitle $t -toTitle $testsTitle -type 'relates' }
}

# Analytics relates to multiple features (telemetry)
$relTargets = @('01 AI Assistant Core','06 Messaging Enhancements','07 Campaign Management','03 Emergency System')
foreach ($t in $relTargets) { Invoke-Link -fromTitle '05 Analytics Dashboard' -toTitle $t -type 'relates' }

# Parse Tasks_List.md for additional dependencies
if (Test-Path 'Tasks_List.md') {
  $tasksContent = Get-Content -Raw -Path 'Tasks_List.md'
  # Example: detect mentions of modules and add relates
  foreach ($t in $allFeatures) {
    $alias = ($t -replace '^[0-9]{2}\s+','').ToLower()
    foreach ($u in $allFeatures) {
      if ($t -ne $u) {
        $aliasU = ($u -replace '^[0-9]{2}\s+','').ToLower()
        if ($tasksContent.ToLower().Contains("$alias")) {
          if ($tasksContent.ToLower().Contains("$aliasU")) {
            # Soft relate if both terms appear in proximity (coarse heuristic)
            Invoke-Link -fromTitle $t -toTitle $u -type 'relates'
          }
        }
      }
    }
  }
}

# Summarize dependencies per issue and maintain a single up-to-date summary comment
function UpdateOrCreate-Summary {
  param([string]$title)
  if (-not $issueMap.ContainsKey($title)) { return }
  $num = $issueMap[$title]
  $status = 'error'

  $deps = @(); if ($DependsOn.ContainsKey($title)) { $deps = $DependsOn[$title] | ForEach-Object { "#" + $issueMap[$_] + " (" + $_ + ")" } }
  $blks = @(); if ($Blocks.ContainsKey($title))   { $blks = $Blocks[$title]   | ForEach-Object { "#" + $issueMap[$_] + " (" + $_ + ")" } }
  $rels = @(); if ($Relates.ContainsKey($title))  { $rels = $Relates[$title]  | ForEach-Object { "#" + $issueMap[$_] + " (" + $_ + ")" } }

  $ts = (Get-Date).ToUniversalTime().ToString('s') + 'Z'
  $summary = "## Dependencies Summary (auto)`n" +
    "**Depends on:** " + ($(if ($deps.Count -gt 0) { $deps -join ', ' } else { 'None' })) + "`n" +
    "**Blocks:** " + ($(if ($blks.Count -gt 0) { $blks -join ', ' } else { 'None' })) + "`n" +
    "**Related to:** " + ($(if ($rels.Count -gt 0) { $rels -join ', ' } else { 'None' })) + "`n" +
    "_Last updated: $ts_"

  $view = gh issue view $num --repo $Repo --json comments | ConvertFrom-Json
  $summaryComments = @()
  if ($view -and $view.comments) {
    foreach ($c in $view.comments) {
      if ($c.body -like '## Dependencies Summary (auto)*') { $summaryComments += $c }
    }
  }

  # Helper to update a comment by ID via GraphQL (if owned by current user)
  function Set-CommentBody([string]$commentId, [string]$body) {
    try {
      $mutation = @'
mutation($id:ID!, $body:String!){
  updateIssueComment(input:{id:$id, body:$body}){ issueComment{ id } }
}
'@
      gh api graphql -f query=$mutation -f id=$commentId -f body=$body | Out-Null
      return $true
    } catch {
      Write-Warning ("Failed to edit comment " + $commentId + " on #" + $num + ": " + $_)
      return $false
    }
  }

  # If there are summary comments, try to edit the latest and demote older ones
  if ($summaryComments.Count -ge 1) {
    $sorted = $summaryComments | Sort-Object { $_.createdAt }
    $latest = $sorted[-1]
    $edited = Set-CommentBody -commentId $latest.id -body $summary
    if ($edited) {
      Write-Host "Updated summary on #$num ($title)"
      $status = 'updated'
    } else {
      # Fallback: post new summary
      try {
        gh issue comment $num --repo $Repo --body $summary | Out-Null
        Write-Host "Posted new summary on #$num ($title) after edit failure"
        $status = 'created_fallback'
      } catch { Write-Warning ("Failed to post summary on #" + $num + ": " + $_) }
    }
    # Demote older summaries so header no longer matches exact header
    if ($sorted.Count -gt 1) {
      $outdated = $sorted[0..($sorted.Count-2)]
      foreach ($oc in $outdated) {
        $demotedBody = "## Superseded Dependencies Summary (auto)`nThis summary has been superseded by the latest summary in this thread."
        $ok = Set-CommentBody -commentId $oc.id -body $demotedBody
        if ($ok) { Write-Host "Demoted old summary on #$num ($title) -> $($oc.id)" }
        else {
          # As fallback, reply note if edit failed (e.g., insufficient perms)
          try { gh issue comment $num --repo $Repo --body "⚠️ **Superseded by latest summary** - Please refer to the most recent Dependencies Summary comment below for current information." | Out-Null } catch {}
        }
      }
    }
  } else {
    # No existing summary: create new
    try {
      gh issue comment $num --repo $Repo --body $summary | Out-Null
      Write-Host "Created summary on #$num ($title)"
      $status = 'created'
      return $status
    } catch { Write-Warning ("Failed to post summary on #" + $num + ": " + $_) }
  }
}

foreach ($t in $allFeatures) { UpdateOrCreate-Summary -title $t }
UpdateOrCreate-Summary -title $rulesTitle
UpdateOrCreate-Summary -title $testsTitle
UpdateOrCreate-Summary -title $notifTitle

Write-Host "Dependency linking complete."
