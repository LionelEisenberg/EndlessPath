<#
.SYNOPSIS
Tests godot_project_list.ps1's user folders against a throwaway repo.

.DESCRIPTION
Builds a repo with a main checkout and two worktrees in a temp folder, with its own projects.cfg,
links root and user data root, and runs the hook's sync there. Nothing outside the temp folder is
touched. Prints each check and exits 1 when one fails.

  powershell -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/test_godot_project_list.ps1
#>
$ErrorActionPreference = 'Stop'
$Hook = Join-Path $PSScriptRoot 'godot_project_list.ps1'
$Utf8 = New-Object System.Text.UTF8Encoding($false)
$script:Failures = 0

$Root = Join-Path ([System.IO.Path]::GetTempPath()) ('godot_project_list_test_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$Main = Join-Path $Root 'main'
$Alpha = Join-Path $Root 'alpha'
$Beta = Join-Path $Root 'beta'
$Links = Join-Path $Root 'links'
$Cfg = Join-Path $Root 'projects.cfg'
$Users = Join-Path $Root 'app_userdata'
$MainFolder = Join-Path $Users 'EndlessPath'
$MainSave = Join-Path $MainFolder 'save.tres'
$AlphaFolder = Join-Path $Users 'EndlessPath-checkouts\alpha'
$AlphaSave = Join-Path $AlphaFolder 'save.tres'
$Exclude = Join-Path $Main '.git\info\exclude'
$AlphaOverride = "[application]`n`nconfig/use_custom_user_dir=true`nconfig/custom_user_dir_name=`"Godot/app_userdata/EndlessPath-checkouts/alpha`"`n"
# Beta brings an override.cfg of its own, which the hook must leave as it is.
$BetaOverride = "[application]`n`nconfig/use_custom_user_dir=true`nconfig/custom_user_dir_name=`"Mine`"`n"

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

function Assert-True([bool]$Condition, [string]$What) {
    if ($Condition) {
        Write-Host "  ok    $What"
    } else {
        Write-Host "  FAIL  $What"
        $script:Failures++
    }
}

function Invoke-Git([string]$Dir, [string[]]$GitArgs) {
    # Under 'Stop', anything git writes to stderr would throw.
    $ErrorActionPreference = 'Continue'
    $out = @(& git -C $Dir @GitArgs 2>$null)
    if ($LASTEXITCODE -ne 0) { throw "git $($GitArgs -join ' ') failed in $Dir" }
    return $out
}

## The file's text, or $null when it is not there.
function Read-Text([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    return [System.IO.File]::ReadAllText($Path, $Utf8)
}

function Write-Text([string]$Path, [string]$Text) {
    [System.IO.File]::WriteAllText($Path, $Text, $Utf8)
}

## Runs the hook's sync on the throwaway repo, in its own process as the SessionStart hook does.
function Invoke-Sync {
    $ErrorActionPreference = 'Continue'
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Hook sync -RepoDir $Main -LinksRoot $Links -ProjectsCfg $Cfg -UserDataRoot $Users 2>&1
    foreach ($line in $out) { Write-Host "        hook: $line" }
}

#-----------------------------------------------------------------------------
# CHECKS
#-----------------------------------------------------------------------------

try {
    New-Item -ItemType Directory -Path $Main | Out-Null
    Invoke-Git $Main @('init', '-q', '-b', 'main') | Out-Null
    Write-Text (Join-Path $Main 'project.godot') "config_version=5`n`n[application]`n`nconfig/name=`"EndlessPath`"`n"
    Invoke-Git $Main @('add', 'project.godot') | Out-Null
    Invoke-Git $Main @('-c', 'user.name=Test', '-c', 'user.email=test@example.com', 'commit', '-q', '-m', 'init') | Out-Null
    Invoke-Git $Main @('worktree', 'add', '-q', '-b', 'feat/alpha', $Alpha) | Out-Null
    Invoke-Git $Main @('worktree', 'add', '-q', '-b', 'feat/beta', $Beta) | Out-Null
    Write-Text (Join-Path $Beta 'override.cfg') $BetaOverride
    New-Item -ItemType Directory -Path $MainFolder | Out-Null
    Write-Text $MainSave 'the main save'

    Write-Host 'A first sync'
    Invoke-Sync
    Assert-True ((Read-Text (Join-Path $Alpha 'override.cfg')) -ceq $AlphaOverride) 'a worktree gets an override.cfg that names its own user folder'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $Main 'override.cfg'))) 'the main checkout gets none'
    Assert-True ((Read-Text (Join-Path $Beta 'override.cfg')) -ceq $BetaOverride) 'an override.cfg already there is left as it is'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $Users 'EndlessPath-checkouts\beta'))) 'a worktree whose override.cfg is not the hook''s gets no folder'
    Assert-True ((Read-Text $AlphaSave) -ceq 'the main save') "the worktree's folder starts with a copy of the main save"
    Assert-True ((Read-Text $MainSave) -ceq 'the main save') 'the main save is untouched'
    Assert-True (@(Get-ChildItem -LiteralPath $MainFolder -Force).Count -eq 1) "nothing else is written in the main checkout's folder"
    Assert-True (@(Invoke-Git $Alpha @('status', '--porcelain')).Count -eq 0) 'git ignores the worktree''s override.cfg'
    Assert-True (@(Invoke-Git $Beta @('status', '--porcelain')).Count -eq 0) 'and the override.cfg it already had'

    Write-Host 'A second sync'
    Write-Text $AlphaSave 'played in alpha'
    Invoke-Sync
    Assert-True ((Read-Text $AlphaSave) -ceq 'played in alpha') "a worktree's own save is never overwritten"
    Assert-True ((Read-Text (Join-Path $Alpha 'override.cfg')) -ceq $AlphaOverride) 'its override.cfg stays as it is'
    Assert-True (@((Read-Text $Exclude) -split '\r?\n' | Where-Object { $_ -ceq '/override.cfg' }).Count -eq 1) 'info/exclude lists override.cfg once'

    Write-Host 'A sync after the worktree''s save is gone'
    Remove-Item -LiteralPath $AlphaSave
    Write-Text (Join-Path $AlphaFolder 'save.tmp.tres') 'cut short'
    Invoke-Sync
    Assert-True (-not (Test-Path -LiteralPath $AlphaSave)) 'the temp file a cut-short write left counts as its save'
    Remove-Item -LiteralPath (Join-Path $AlphaFolder 'save.tmp.tres')
    Invoke-Sync
    Assert-True ((Read-Text $AlphaSave) -ceq 'the main save') 'with neither, it gets a new copy of the main save'

    Write-Host 'A sync with no main save'
    Remove-Item -LiteralPath $AlphaSave
    Remove-Item -LiteralPath $MainSave
    Invoke-Sync
    Assert-True (-not (Test-Path -LiteralPath $AlphaSave)) 'nothing is copied'
    Assert-True ((Read-Text (Join-Path $Alpha 'override.cfg')) -ceq $AlphaOverride) 'and the override.cfg stays'
} finally {
    # The hook made a junction per worktree under $Links. Delete each as a link: Remove-Item
    # -Recurse would delete the files of the worktree it points to.
    if (Test-Path -LiteralPath $Links) {
        foreach ($item in Get-ChildItem -LiteralPath $Links -Force) {
            if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                [System.IO.Directory]::Delete($item.FullName, $false)
            }
        }
    }
    Remove-Item -LiteralPath $Root -Recurse -Force -ErrorAction SilentlyContinue
}

if ($script:Failures -gt 0) {
    Write-Host "$($script:Failures) check(s) failed"
    exit 1
}
Write-Host 'All checks passed'
