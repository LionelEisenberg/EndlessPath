<#
.SYNOPSIS
Lists this repo's git worktrees in Godot's project manager, each under a one-liner of its feature.

.DESCRIPTION
Godot titles every entry with project.godot's config/name, so each worktree would read
"EndlessPath" over a folder name like determined-yalow-6fc2f7. Instead, each worktree is listed
through a junction in -LinksRoot named after a one-liner of its feature. Godot shows that name on
the path line under the title, and its search box matches it.

  sync          Give every live worktree a junction (named after its branch until a session
                labels it), and remove the junctions and Godot entries of worktrees that are gone
                or merged into main. The SessionStart hook in .claude/settings.json runs this.
  label <text>  Rename the current worktree's entry to <text>, then sync.

Only entries under -LinksRoot are touched: the main checkout's entry and other projects stay as
they are. Godot reads projects.cfg when the project manager starts, so reopen it to see changes.
#>
param(
    [Parameter(Position = 0)]
    [ValidateSet('sync', 'label')]
    [string]$Command = 'sync',

    [Parameter(Position = 1)]
    [string]$Label = '',

    # Any checkout of the repo. Defaults to the session's project dir, else the current dir.
    [string]$RepoDir = '',

    [string]$LinksRoot = 'C:\worktrees\EndlessPath-godot',

    # Defaults to Godot's own list, %APPDATA%\Godot\projects.cfg.
    [string]$ProjectsCfg = ''
)

$ErrorActionPreference = 'Stop'
$Utf8 = New-Object System.Text.UTF8Encoding($false)
$LabelMaxLength = 60
$RenameHint = 'powershell -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/godot_project_list.ps1 label "<one-liner>"'

#-----------------------------------------------------------------------------
# PATHS AND LABELS
#-----------------------------------------------------------------------------

function ConvertTo-FullPath([string]$Path) {
    return [System.IO.Path]::GetFullPath($Path.Replace('/', '\')).TrimEnd('\')
}

## Godot writes project paths with forward slashes.
function ConvertTo-CfgPath([string]$Path) {
    return $Path.Replace('\', '/')
}

## Keeps a label to characters that are safe in a folder name and in projects.cfg.
function ConvertTo-Label([string]$Text) {
    $clean = $Text -replace '\s*[:/\\|\u2013\u2014]\s*', ' - '
    $clean = $clean -replace "[^A-Za-z0-9 ,.()&+'-]", ' '
    $clean = ($clean -replace '\s+', ' ').Trim(' ', '.', '-')
    if ($clean.Length -gt $LabelMaxLength) {
        $clean = $clean.Substring(0, $LabelMaxLength).Trim(' ', '.', '-')
    }
    return $clean
}

## The label a worktree has until a session names it: its branch without the prefix and hash.
function Get-DefaultLabel($Worktree) {
    if ($Worktree.Branch) { $name = $Worktree.Branch -replace '^.*/', '' }
    else { $name = Split-Path $Worktree.Path -Leaf }
    $label = ConvertTo-Label ($name -replace '-[0-9a-f]{6}$', '' -replace '[-_]+', ' ')
    if (-not $label) { return 'Worktree' }
    return $label.Substring(0, 1).ToUpper() + $label.Substring(1)
}

function Get-FreeName([string]$Base, $Taken) {
    $name = $Base
    for ($n = 2; $Taken.Contains($name); $n++) { $name = "$Base $n" }
    return $name
}

#-----------------------------------------------------------------------------
# GIT
#-----------------------------------------------------------------------------

function Invoke-Git([string[]]$GitArgs, [string]$Dir = $script:RepoTop) {
    # Under 'Stop', anything git writes to stderr would throw.
    $ErrorActionPreference = 'Continue'
    $out = @(& git -C $Dir @GitArgs 2>$null)
    return [pscustomobject]@{ Ok = ($LASTEXITCODE -eq 0); Lines = $out }
}

## Every worktree of the repo, the main checkout first.
function Get-Worktrees {
    $worktrees = @()
    $worktree = $null
    foreach ($line in (Invoke-Git @('worktree', 'list', '--porcelain')).Lines) {
        if ($line.StartsWith('worktree ')) {
            $worktree = [pscustomobject]@{
                Path = ConvertTo-FullPath $line.Substring(9); Head = ''; Branch = ''; Bare = $false
            }
            $worktrees += $worktree
        } elseif ($line.StartsWith('HEAD ')) {
            $worktree.Head = $line.Substring(5)
        } elseif ($line.StartsWith('branch refs/heads/')) {
            $worktree.Branch = $line.Substring(18)
        } elseif ($line -eq 'bare') {
            $worktree.Bare = $true
        }
    }
    return $worktrees
}

## origin/main and main, each with the commits on its first-parent line.
function Get-MainLines {
    $mains = @()
    foreach ($ref in 'refs/remotes/origin/main', 'refs/heads/main') {
        if (-not (Invoke-Git @('rev-parse', '--verify', '--quiet', $ref)).Ok) { continue }
        $firstParents = New-Object 'System.Collections.Generic.HashSet[string]'
        foreach ($sha in (Invoke-Git @('rev-list', '--first-parent', $ref)).Lines) {
            [void]$firstParents.Add($sha)
        }
        $mains += [pscustomobject]@{ Ref = $ref; FirstParents = $firstParents }
    }
    return $mains
}

## Merged: main holds the branch tip through a merge and nothing is left uncommitted (but the
## permissions a session adds to settings.local.json). A fresh branch's tip sits on main's
## first-parent line (it was main's tip), so it never counts.
function Test-Merged($Worktree, $Mains) {
    if (-not $Worktree.Branch) { return $false }
    $inMain = $false
    foreach ($main in $Mains) {
        if ($main.FirstParents.Contains($Worktree.Head)) { return $false }
        if ((Invoke-Git @('merge-base', '--is-ancestor', $Worktree.Head, $main.Ref)).Ok) { $inMain = $true }
    }
    if (-not $inMain) { return $false }
    $status = Invoke-Git @('status', '--porcelain', '--', '.', ':(exclude).claude/settings.local.json') $Worktree.Path
    return ($status.Ok -and $status.Lines.Count -eq 0)
}

#-----------------------------------------------------------------------------
# JUNCTIONS
#-----------------------------------------------------------------------------

function New-Link([string]$Path, [string]$Target) {
    return [pscustomobject]@{ Name = Split-Path $Path -Leaf; Path = $Path; Target = $Target }
}

function Get-Links {
    $links = @()
    if (-not (Test-Path -LiteralPath $LinksRoot)) { return $links }
    foreach ($item in Get-ChildItem -LiteralPath $LinksRoot -Directory -Force) {
        if (-not ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) { continue }
        $target = @($item.Target)[0]
        if (-not $target) { continue }
        $links += New-Link $item.FullName (ConvertTo-FullPath $target)
    }
    return $links
}

function Add-Link([string]$Name, [string]$Target) {
    if (-not (Test-Path -LiteralPath $LinksRoot)) {
        New-Item -ItemType Directory -Path $LinksRoot | Out-Null
    }
    $path = Join-Path $LinksRoot $Name
    New-Item -ItemType Junction -Path $path -Value $Target | Out-Null
    return New-Link $path $Target
}

## Removes the junction itself. Never use Remove-Item -Recurse here: on a junction, Windows
## PowerShell deletes the files of the worktree it points to.
function Remove-Link($Link) {
    [System.IO.Directory]::Delete($Link.Path, $false)
}

function Rename-Link($Link, [string]$Name) {
    $path = Join-Path $LinksRoot $Name
    if ($Link.Name -ieq $Name) {
        # Directory.Move refuses a case-only rename, so go through a temporary name.
        [System.IO.Directory]::Move($Link.Path, "$path.renaming")
        [System.IO.Directory]::Move("$path.renaming", $path)
    } else {
        [System.IO.Directory]::Move($Link.Path, $path)
    }
    return New-Link $path $Link.Target
}

#-----------------------------------------------------------------------------
# PROJECTS.CFG
#-----------------------------------------------------------------------------

function Read-Cfg {
    $cfg = [pscustomobject]@{
        Text = ''
        Preamble = New-Object System.Collections.ArrayList
        Sections = New-Object System.Collections.ArrayList
    }
    if (Test-Path -LiteralPath $ProjectsCfg) {
        $cfg.Text = [System.IO.File]::ReadAllText($ProjectsCfg, $Utf8)
    }
    $section = $null
    foreach ($line in ($cfg.Text -split '\r?\n')) {
        if ($line -match '^\[(.+)\]\s*$') {
            $section = [pscustomobject]@{ Name = $Matches[1]; Lines = New-Object System.Collections.ArrayList }
            [void]$cfg.Sections.Add($section)
        } elseif ($line.Trim()) {
            if ($section) { [void]$section.Lines.Add($line) } else { [void]$cfg.Preamble.Add($line) }
        }
    }
    return $cfg
}

## Writes the file the way Godot's ConfigFile does, and only when something changed. It writes
## in place: the Claude app's sandbox would hide a newly created file from Godot.
function Write-Cfg($Cfg, $Sections) {
    $parts = foreach ($section in $Sections) {
        "[$($section.Name)]`n`n" + (($section.Lines | ForEach-Object { "$_`n" }) -join '')
    }
    $text = (($Cfg.Preamble | ForEach-Object { "$_`n" }) -join '') + (@($parts) -join "`n")
    if ($text -ceq ($Cfg.Text -replace '\r\n', "`n")) { return }
    [System.IO.File]::WriteAllText($ProjectsCfg, $text, $Utf8)
}

## Replaces the entries under -LinksRoot with one per link. A renamed entry keeps its keys, such
## as a favorite star.
function Update-Cfg($Links, $Renamed) {
    $prefix = (ConvertTo-CfgPath $LinksRoot).ToLowerInvariant() + '/'
    $listed = @{}
    foreach ($link in $Links) {
        $listed[(ConvertTo-CfgPath $link.Path).ToLowerInvariant()] = ConvertTo-CfgPath $link.Path
    }

    $cfg = Read-Cfg
    $sections = New-Object System.Collections.ArrayList
    $written = @{}
    foreach ($section in $cfg.Sections) {
        $key = $section.Name.ToLowerInvariant()
        if (-not $key.StartsWith($prefix)) {
            [void]$sections.Add($section)
            continue
        }
        if ($Renamed.ContainsKey($key)) { $key = $Renamed[$key].ToLowerInvariant() }
        if ($listed.ContainsKey($key) -and -not $written.ContainsKey($key)) {
            $section.Name = $listed[$key]
            [void]$sections.Add($section)
            $written[$key] = $true
        }
    }
    foreach ($key in ($listed.Keys | Sort-Object)) {
        if ($written.ContainsKey($key)) { continue }
        $lines = New-Object System.Collections.ArrayList
        [void]$lines.Add('favorite=false')
        [void]$sections.Add([pscustomobject]@{ Name = $listed[$key]; Lines = $lines })
    }
    Write-Cfg $cfg $sections
}

#-----------------------------------------------------------------------------
# SYNC
#-----------------------------------------------------------------------------

## Brings the junctions and projects.cfg in line with the live worktrees, renaming the current
## worktree's entry to $NewLabel if given. Returns the current worktree's link and default label
## (no link for the main checkout or a merged worktree).
function Sync-List([string]$NewLabel) {
    $worktrees = @(Get-Worktrees)
    $mains = @(Get-MainLines)

    # The worktrees Godot should list, keyed by lower-case path. The main checkout keeps its own entry.
    $wanted = @{}
    foreach ($worktree in ($worktrees | Select-Object -Skip 1)) {
        if ($worktree.Bare) { continue }
        if (-not (Test-Path -LiteralPath (Join-Path $worktree.Path 'project.godot'))) { continue }
        if (Test-Merged $worktree $mains) { continue }
        $wanted[$worktree.Path.ToLowerInvariant()] = $worktree
    }

    $taken = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    if (Test-Path -LiteralPath $LinksRoot) {
        foreach ($item in Get-ChildItem -LiteralPath $LinksRoot -Force) { [void]$taken.Add($item.Name) }
    }

    # One junction per wanted worktree. The rest point at worktrees that are gone or merged.
    $kept = @{}
    foreach ($link in Get-Links) {
        $key = $link.Target.ToLowerInvariant()
        if ($wanted.ContainsKey($key) -and -not $kept.ContainsKey($key)) {
            $kept[$key] = $link
        } else {
            Remove-Link $link
            [void]$taken.Remove($link.Name)
        }
    }
    foreach ($key in @($wanted.Keys)) {
        if ($kept.ContainsKey($key)) { continue }
        $name = Get-FreeName (Get-DefaultLabel $wanted[$key]) $taken
        $kept[$key] = Add-Link $name $wanted[$key].Path
        [void]$taken.Add($name)
    }

    $hereKey = $script:RepoTop.ToLowerInvariant()
    $here = $kept[$hereKey]
    $renamed = @{}
    if ($NewLabel -and $here -and $here.Name -cne $NewLabel) {
        [void]$taken.Remove($here.Name)
        $old = $here
        $here = Rename-Link $here (Get-FreeName $NewLabel $taken)
        $kept[$hereKey] = $here
        $renamed[(ConvertTo-CfgPath $old.Path).ToLowerInvariant()] = ConvertTo-CfgPath $here.Path
    }

    Update-Cfg @($kept.Values) $renamed

    $defaultLabel = ''
    if ($here) { $defaultLabel = Get-DefaultLabel $wanted[$hereKey] }
    return [pscustomobject]@{ Link = $here; DefaultLabel = $defaultLabel }
}

#-----------------------------------------------------------------------------
# MAIN
#-----------------------------------------------------------------------------

try {
    if (-not $ProjectsCfg) {
        if (-not $env:APPDATA) { exit 0 }
        $ProjectsCfg = Join-Path $env:APPDATA 'Godot\projects.cfg'
    }
    if (-not $RepoDir) {
        $RepoDir = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }
    }
    $top = Invoke-Git @('rev-parse', '--show-toplevel') $RepoDir
    if (-not $top.Ok) { throw "$RepoDir is not a git checkout." }
    $script:RepoTop = ConvertTo-FullPath $top.Lines[0]

    $newLabel = ''
    if ($Command -eq 'label') {
        $newLabel = ConvertTo-Label $Label
        if (-not $newLabel) { throw 'Give the one-liner as text, like: label "Zone view redesign"' }
    }

    # Sessions that start together would otherwise race on projects.cfg.
    $mutex = New-Object System.Threading.Mutex($false, 'Local\EndlessPathGodotProjectList')
    try { $owned = $mutex.WaitOne(20000) } catch [System.Threading.AbandonedMutexException] { $owned = $true }
    try { $result = Sync-List $newLabel }
    finally { if ($owned) { $mutex.ReleaseMutex() } }

    $link = $result.Link
    if ($Command -eq 'label') {
        if (-not $link) { throw 'This checkout has no entry in the list: the main checkout and merged worktrees never get one.' }
        "Godot's project manager now lists this worktree as `"$($link.Name)`" ($(ConvertTo-CfgPath $link.Path)). Reopen the project manager to see it."
    } elseif ($link) {
        if ($link.Name -match ('^' + [regex]::Escape($result.DefaultLabel) + '( \d+)?$')) {
            "Godot's project manager lists this worktree as `"$($link.Name)`", named after its branch. Once you know what this session is building, rename it to a one-liner of the feature (and again if the work changes direction): $RenameHint"
        } else {
            "Godot's project manager lists this worktree as `"$($link.Name)`". If the work changes direction, rename it: $RenameHint"
        }
    }
} catch {
    [Console]::Error.WriteLine("godot_project_list: $($_.Exception.Message)")
    # A failed sync must never get in the way of a session starting.
    if ($Command -eq 'label') { exit 1 }
}
