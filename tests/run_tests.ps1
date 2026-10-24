<#
.SYNOPSIS
Runs the GUT suite in several headless Godot processes at once and prints one result.

.DESCRIPTION
Splits the test scripts in .gutconfig.json's dirs into -Processes groups of about equal run
time, longest first, from each script's time in the last run. Each group runs in its own
headless Godot, with a copy of .gutconfig.json that lists the group's scripts in place of the
dirs, all at once. When every process is done, it prints the failing tests, the scripts that
ran no tests, the one-process command that confirms them, and saves each script's time for the
next split.

A test that depends on how long frames take can fail on a busy machine, and several Godot
processes make the machine busy: confirm a failure in one process before acting on it.

Each process's config, output and JUnit file are in .godot/test_runs/, replaced every run. The
scripts' times are kept in the repository's git folder, which every worktree shares.

Exit code: 0 when every test passes, 1 when a test fails or a script runs no tests, 2 when the
run cannot start.
#>
param(
    # How many Godot processes run at once.
    [ValidateRange(1, 32)]
    [int]$Processes = 6,

    # The Godot console executable.
    [string]$Godot = 'C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe'
)

$ErrorActionPreference = 'Stop'
$Utf8 = New-Object System.Text.UTF8Encoding($false)
$Root = Split-Path -Parent $PSScriptRoot
$RunDir = Join-Path $Root '.godot\test_runs'
# What a script with no time yet counts as, when no script has a time.
$DefaultSeconds = 1.0

#-----------------------------------------------------------------------------
# SCRIPTS AND TIMES
#-----------------------------------------------------------------------------

## "1 script", "24 scripts".
function Format-Count([int]$Count, [string]$Noun) {
    if ($Count -eq 1) { return "1 $Noun" }
    return "$Count ${Noun}s"
}

## The test scripts in the config's dirs, as sorted res:// paths.
function Get-TestScripts($Config) {
    $prefix = if ($Config.prefix) { $Config.prefix } else { 'test_' }
    $suffix = if ($Config.suffix) { $Config.suffix } else { '.gd' }
    $scripts = foreach ($dir in $Config.dirs) {
        $folder = Join-Path $Root ($dir -replace '^res://', '')
        Get-ChildItem -LiteralPath $folder -File -Recurse:([bool]$Config.include_subdirs) |
            Where-Object { $_.Name.StartsWith($prefix) -and $_.Name.EndsWith($suffix) } |
            ForEach-Object { 'res://' + $_.FullName.Substring($Root.Length + 1).Replace('\', '/') }
    }
    return @($scripts | Sort-Object)
}

## Where each script's time from the last run is kept: the repository's git folder, which every
## worktree shares, so a new worktree splits well from its first run. Outside a repository,
## .godot/test_runs/.
function Get-TimesPath {
    # Under 'Stop', anything git writes to stderr would throw.
    $ErrorActionPreference = 'Continue'
    $common = @()
    try { $common = @(& git -C $Root rev-parse --git-common-dir 2>$null) } catch { }
    if ($LASTEXITCODE -eq 0 -and $common.Count -gt 0) {
        $dir = $common[0]
        if (-not [System.IO.Path]::IsPathRooted($dir)) { $dir = Join-Path $Root $dir }
        return Join-Path $dir 'gut_test_times.json'
    }
    return Join-Path $RunDir 'test_times.json'
}

## Each script's seconds from the last run: empty on a first run, or when another run was
## writing the file just then.
function Read-Times([string]$Path) {
    $times = @{}
    if (Test-Path -LiteralPath $Path) {
        try {
            $saved = [System.IO.File]::ReadAllText($Path, $Utf8) | ConvertFrom-Json
            foreach ($entry in $saved.PSObject.Properties) { $times[$entry.Name] = [double]$entry.Value }
        } catch {
            $times = @{}
        }
    }
    return $times
}

## Saves the times sorted by script, through a temporary file, so a run starting meanwhile
## never reads half a file.
function Save-Times([hashtable]$Times, [string]$Path) {
    $sorted = [ordered]@{}
    foreach ($script in ($Times.Keys | Sort-Object)) { $sorted[$script] = [math]::Round($Times[$script], 3) }
    $temp = "$Path.$PID.tmp"
    [System.IO.File]::WriteAllText($temp, (ConvertTo-Json -InputObject $sorted), $Utf8)
    Move-Item -LiteralPath $temp -Destination $Path -Force
}

## Splits the scripts into at most $Count groups of about equal time: longest first, each onto
## the group with the least time so far. A script with no time yet counts as the median time.
function Split-Scripts([string[]]$Scripts, [hashtable]$Times, [int]$Count) {
    $known = @($Scripts | Where-Object { $Times.ContainsKey($_) } | ForEach-Object { $Times[$_] } | Sort-Object)
    $guess = if ($known.Count -gt 0) { $known[[int][math]::Floor($known.Count / 2)] } else { $DefaultSeconds }
    $groups = @(for ($i = 0; $i -lt $Count; $i++) {
        [pscustomobject]@{ Number = $i + 1; Seconds = 0.0; Scripts = New-Object System.Collections.Generic.List[string] }
    })
    $weighted = foreach ($script in $Scripts) {
        $seconds = if ($Times.ContainsKey($script)) { $Times[$script] } else { $guess }
        [pscustomobject]@{ Path = $script; Seconds = $seconds }
    }
    foreach ($script in ($weighted | Sort-Object -Property @{ Expression = 'Seconds'; Descending = $true }, 'Path')) {
        $lightest = $groups | Sort-Object -Property Seconds, Number | Select-Object -First 1
        $lightest.Seconds += $script.Seconds
        $lightest.Scripts.Add($script.Path)
    }
    return @($groups | Where-Object { $_.Scripts.Count -gt 0 })
}

#-----------------------------------------------------------------------------
# RESULTS
#-----------------------------------------------------------------------------

## What a process's JUnit file says: its tests, its failures and the time of each script that ran
## a test. $null when it wrote none (it crashed, or never got to the end).
function Read-Results($Run) {
    if (-not (Test-Path -LiteralPath $Run.Junit)) { return $null }
    $xml = New-Object System.Xml.XmlDocument
    try { $xml.Load($Run.Junit) } catch { return $null }
    $results = [pscustomobject]@{
        Tests = 0
        Pending = 0
        NoAsserts = 0
        Failures = New-Object System.Collections.Generic.List[object]
        Times = @{}
    }
    foreach ($suite in $xml.SelectNodes('/testsuites/testsuite')) {
        # GUT lists every script it collected. One that did not load, or that the run stopped
        # before, is there with no test cases.
        $cases = $suite.SelectNodes('testcase')
        if ($cases.Count -eq 0) { continue }
        # An inner test class reports as "<script>.gd.<Class>": it counts toward its script.
        $script = 'res://' + ($suite.GetAttribute('name') -replace '^(.*?\.gd)\..*$', '$1')
        $seconds = [double]::Parse($suite.GetAttribute('time'), [System.Globalization.CultureInfo]::InvariantCulture)
        if ($results.Times.ContainsKey($script)) { $seconds += $results.Times[$script] }
        $results.Times[$script] = $seconds
        foreach ($case in $cases) {
            $results.Tests += 1
            switch ($case.GetAttribute('status')) {
                'fail' {
                    $results.Failures.Add([pscustomobject]@{
                        Script = $script
                        Test = $case.GetAttribute('name')
                        Text = $case.SelectSingleNode('failure').InnerText.Trim()
                    })
                }
                'pending' { $results.Pending += 1 }
                'skipped' { $results.Pending += 1 }
                'no asserts' { $results.NoAsserts += 1 }
            }
        }
    }
    return $results
}

#-----------------------------------------------------------------------------
# RUN
#-----------------------------------------------------------------------------

if (-not (Test-Path -LiteralPath $Godot)) {
    Write-Host "No Godot at $Godot. Pass its console executable with -Godot."
    exit 2
}
if (-not (Test-Path -LiteralPath (Join-Path $Root '.godot'))) {
    Write-Host 'This checkout has not been imported yet. Import it first, from the project root:'
    Write-Host "  `"$Godot`" --headless --import"
    exit 2
}

$gutConfig = [System.IO.File]::ReadAllText((Join-Path $Root '.gutconfig.json'), $Utf8) | ConvertFrom-Json
$scripts = @(Get-TestScripts $gutConfig)
if ($scripts.Count -eq 0) {
    Write-Host "No test scripts in .gutconfig.json's dirs."
    exit 2
}
$timesPath = Get-TimesPath
$groups = Split-Scripts $scripts (Read-Times $timesPath) ([math]::Min($Processes, $scripts.Count))

New-Item -ItemType Directory -Force -Path $RunDir | Out-Null
Get-ChildItem -LiteralPath $RunDir -File -Filter 'process_*' | Remove-Item -Force

$runs = @(foreach ($group in $groups) {
    $base = Join-Path $RunDir "process_$($group.Number)"
    # The project's GUT settings, with this group's scripts in place of the dirs.
    $config = [ordered]@{}
    foreach ($entry in $gutConfig.PSObject.Properties) { $config[$entry.Name] = $entry.Value }
    $config['dirs'] = @()
    $config['tests'] = @($group.Scripts)
    $config['junit_xml_file'] = "$base.xml".Replace('\', '/')
    $config['should_exit'] = $true
    [System.IO.File]::WriteAllText("$base.gutconfig.json", (ConvertTo-Json -InputObject $config), $Utf8)

    $arguments = @('--headless', '--path', $Root, '-s', 'res://addons/gut/gut_cmdln.gd', ('-gconfig=' + "$base.gutconfig.json".Replace('\', '/'))) |
        ForEach-Object { if ($_ -match '\s') { "`"$_`"" } else { $_ } }
    $process = Start-Process -FilePath $Godot -ArgumentList $arguments -WorkingDirectory $Root -NoNewWindow -PassThru `
        -RedirectStandardOutput "$base.log" -RedirectStandardError "$base.errors.log"
    # Without the handle, ExitCode reads empty once the process has ended.
    $null = $process.Handle
    [pscustomobject]@{
        Number = $group.Number
        Process = $process
        Scripts = $group.Scripts
        Junit = "$base.xml"
        Log = "$base.log"
        Errors = "$base.errors.log"
        Results = $null
    }
})

Write-Host ('Running {0} in {1} Godot processes. Output: {2}' -f (Format-Count $scripts.Count 'test script'), $runs.Count, $RunDir)
$clock = [System.Diagnostics.Stopwatch]::StartNew()
$waiting = New-Object System.Collections.Generic.List[object]
foreach ($run in $runs) { $waiting.Add($run) }
try {
    while ($waiting.Count -gt 0) {
        Start-Sleep -Milliseconds 200
        foreach ($run in @($waiting | Where-Object { $_.Process.HasExited })) {
            [void]$waiting.Remove($run)
            $run.Results = Read-Results $run
            $seconds = ($run.Process.ExitTime - $run.Process.StartTime).TotalSeconds
            if ($null -eq $run.Results) {
                $outcome = 'exited with code {0} and wrote no results' -f $run.Process.ExitCode
            } elseif ($run.Results.Failures.Count -gt 0) {
                $outcome = '{0} of {1} failed' -f $run.Results.Failures.Count, (Format-Count $run.Results.Tests 'test')
            } else {
                $outcome = '{0} passed' -f (Format-Count $run.Results.Tests 'test')
            }
            Write-Host ('  process {0} done in {1:N1} s ({2}): {3}' -f $run.Number, $seconds, (Format-Count $run.Scripts.Count 'script'), $outcome)
        }
    }
} finally {
    # Stopped early (Ctrl+C): end the processes still running.
    foreach ($run in $waiting) {
        if (-not $run.Process.HasExited) { $run.Process.Kill() }
    }
}
$clock.Stop()

#-----------------------------------------------------------------------------
# REPORT
#-----------------------------------------------------------------------------

# Read again before saving: another run may have saved times meanwhile.
$times = Read-Times $timesPath
$tests = 0
$pending = 0
$noAsserts = 0
$failures = New-Object System.Collections.Generic.List[object]
$unreported = New-Object System.Collections.Generic.List[string]
$troubled = New-Object System.Collections.Generic.List[object]
foreach ($run in $runs) {
    if ($null -ne $run.Results) {
        $tests += $run.Results.Tests
        $pending += $run.Results.Pending
        $noAsserts += $run.Results.NoAsserts
        foreach ($failure in $run.Results.Failures) { $failures.Add($failure) }
        foreach ($entry in $run.Results.Times.GetEnumerator()) { $times[$entry.Key] = $entry.Value }
    }
    $missing = @($run.Scripts | Where-Object { $null -eq $run.Results -or -not $run.Results.Times.ContainsKey($_) })
    foreach ($script in $missing) { $unreported.Add($script) }
    if ($run.Process.ExitCode -ne 0 -or $missing.Count -gt 0) { $troubled.Add($run) }
}
if ($tests -gt 0) { Save-Times $times $timesPath }

$elapsed = '{0:N1} s' -f $clock.Elapsed.TotalSeconds
$notes = @()
if ($pending -gt 0) { $notes += "$pending pending" }
if ($noAsserts -gt 0) { $notes += "$noAsserts with no asserts" }
$noteText = if ($notes.Count -gt 0) { ' (' + ($notes -join ', ') + ')' } else { '' }

if ($failures.Count -eq 0 -and $troubled.Count -eq 0) {
    Write-Host ('All {0} passed in {1} across {2} processes{3}.' -f (Format-Count $tests 'test'), $elapsed, $runs.Count, $noteText) -ForegroundColor Green
    exit 0
}

if ($failures.Count -gt 0) {
    Write-Host ('{0} of {1} failed in {2}{3}:' -f $failures.Count, (Format-Count $tests 'test'), $elapsed, $noteText) -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host ('  {0} :: {1}' -f $failure.Script, $failure.Test)
        foreach ($line in ($failure.Text -split "`r?`n")) { Write-Host ('      ' + $line.Trim()) }
    }
}
if ($unreported.Count -gt 0) {
    Write-Host ('{0} ran no tests (a crash, a script that did not load, or a run that stopped early):' -f (Format-Count $unreported.Count 'script')) -ForegroundColor Red
    foreach ($script in $unreported) { Write-Host "  $script" }
}
foreach ($run in $troubled) {
    Write-Host ('Output of process {0} (exit code {1}): {2} (errors: {3})' -f $run.Number, $run.Process.ExitCode, $run.Log, $run.Errors)
}

$confirm = @(@($failures | ForEach-Object { $_.Script }) + @($unreported) | Sort-Object -Unique)
if ($confirm.Count -eq 0) { $confirm = @($troubled | ForEach-Object { $_.Scripts } | Sort-Object -Unique) }
Write-Host 'A busy machine can fail a test that depends on frame timing. Confirm in one process before acting on it:'
Write-Host ('  "{0}" --headless -s addons/gut/gut_cmdln.gd -gconfig= -gtest={1} -gexit' -f $Godot, ($confirm -join ','))
exit 1
