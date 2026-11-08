# Prints the Godot option that opens a game window off the screen the user works on:
# the screen the Claude app is on or, when Claude shares the primary screen or isn't
# found, the largest other screen. Prints nothing on a one-screen setup, so Godot
# picks as usual. Godot numbers screens in Windows' order. Use it before "--":
#   godot --path . --audio-driver Dummy $(powershell -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/game_window_args.ps1) scenes/main/main_game/main_game.tscn
Add-Type -AssemblyName System.Windows.Forms
$screens = [System.Windows.Forms.Screen]::AllScreens
$target = $null
$claude = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 -and $_.ProcessName -match '^Claude' } | Select-Object -First 1
if ($null -ne $claude) {
	$target = [System.Windows.Forms.Screen]::FromHandle($claude.MainWindowHandle)
}
if ($null -eq $target -or $target.Primary) {
	$target = $screens | Where-Object { -not $_.Primary } | Sort-Object { $_.Bounds.Width * $_.Bounds.Height } -Descending | Select-Object -First 1
}
if ($null -ne $target) {
	"--screen $([array]::IndexOf($screens, $target))"
}
