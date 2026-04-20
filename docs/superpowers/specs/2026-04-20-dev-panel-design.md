# Dev Panel — Design Spec

**Date:** 2026-04-20
**Status:** Design approved, awaiting implementation plan

## Goal

Ship a password-gated developer/playtester panel in the game binary so that gameplay can be tested (resources, progression, combat shortcuts) without mutating the actual game data, recipes, or balance values. The panel is invisible to regular players and opens only when a password file is present in `user://`.

## Non-goals

- Not a "God Mode" or full state editor — v1 covers a focused set of 7 actions.
- Not a debug overlay (FPS, memory, frame graphs) — those remain Godot's built-in tools.
- Not a save-editor — it mutates live state and relies on the existing 5s autosave timer.
- Not hardened against reverse engineering — the threat model is "casual player stumbles across hotkey", not "determined cheater".

## Feature surface (v1)

Seven actions, grouped into four sections:

| Section | Action | Input |
|---|---|---|
| Resources | Set Madra | SpinBox (float) + Apply |
| Resources | Set Gold | SpinBox (float) + Apply |
| Cultivation | Add Core Density XP | SpinBox (float) + Apply |
| Cultivation | Grant Path Points | SpinBox (int) + Apply |
| Unlocks | Force-trigger unlock condition | OptionButton (condition IDs) + Trigger |
| Unlocks | Unlock all cycling techniques | Button |
| Combat | Force-win current combat | Button (hidden unless `AdventureView.is_in_combat`) |

## Authentication model

### File-existence gating

- On every `Ctrl+Shift+D` press, check `FileAccess.file_exists("user://dev_password.txt")`.
- If the file is missing, the hotkey is a **no-op** — no modal, no visual feedback. The feature is genuinely invisible in shipped builds. No check runs at game start; the panel is purely reactive.
- `user://` maps to `%APPDATA%/Godot/app_userdata/EndlessPath/` on Windows, so the file is per-machine and never shipped with the binary.

### Password entry flow

```
[closed, locked]  ← game start
   │
   │ Ctrl+Shift+D pressed
   │ AND user://dev_password.txt exists
   ▼
[password modal open]
   │
   ├── submit correct ──► [panel open, session-UNLOCKED]
   │                         │ close button
   │                         ▼
   │                      [closed, session-UNLOCKED]  ← re-opens without modal
   │                         │ Ctrl+Shift+D
   │                         └──► [panel open]
   │
   └── submit wrong  ──► [closed, locked]  (silent fail — modal closes)
```

- Unlock state lives **in memory only** on `MainGame` — not persisted. New process = re-enter password.
- Password comparison: `entered.strip_edges() == FileAccess.get_file_as_string("user://dev_password.txt").strip_edges()`. Trim both sides to tolerate trailing newlines.
- On wrong password, modal closes silently — no shake, no error label, no retry counter. This obscures whether the hotkey is even bound.

## Architecture

### New files

- `scenes/ui/dev_panel/dev_panel.tscn` — floating draggable panel (PanelContainer). Mirrors the `LogWindow` pattern for drag + close.
- `scenes/ui/dev_panel/dev_panel.gd` — wires input widgets to manager calls.
- `scenes/ui/dev_panel/dev_password_modal.tscn` — CenterContainer with a single LineEdit + Submit button.
- `scenes/ui/dev_panel/dev_password_modal.gd` — reads file, compares, emits `unlocked` signal or closes silently.

### Changes to existing files

- `scenes/main/main_game/main_game.tscn` — add two child nodes under `MainView`: `DevPasswordModal` and `DevPanel` (both `visible = false` at start). Same pattern as `LogWindow`.
- `scenes/main/main_game/main_game.gd` — add `Ctrl+Shift+D` input handler. Track in-memory `_dev_unlocked: bool`. Show modal or panel depending on state + file existence.
- `singletons/unlock_manager/unlock_manager.gd` — expose `force_unlock_condition(id: String)` as a public wrapper around the existing private `_unlock_condition`. Doc-comment it as dev-only.
- `scenes/adventure/adventure_view/adventure_view.gd` — add public `force_win_combat()` method that checks `is_in_combat` and emits `trigger_combat_end(true, 0)` on the child `AdventureCombat` node. No-op if not in combat.

### Scene structure (dev_panel.tscn)

```
DevPanel (PanelContainer, mouse_filter = STOP, script attached)
├── VBoxContainer
│   ├── TitleBar (PanelContainer — drag handle)
│   │   └── HBoxContainer
│   │       ├── Label "Dev Panel" (LabelBody)
│   │       └── CloseButton (Button "×")
│   ├── HSeparator
│   ├── Label "RESOURCES" (LabelSubheading)
│   ├── MadraRow (HBoxContainer: Label + SpinBox + ApplyButton)
│   ├── GoldRow (HBoxContainer: Label + SpinBox + ApplyButton)
│   ├── HSeparator
│   ├── Label "CULTIVATION" (LabelSubheading)
│   ├── CdXpRow (HBoxContainer: Label + SpinBox + ApplyButton)
│   ├── PathPointsRow (HBoxContainer: Label + SpinBox + ApplyButton)
│   ├── HSeparator
│   ├── Label "UNLOCKS" (LabelSubheading)
│   ├── ConditionRow (HBoxContainer: Label + OptionButton + TriggerButton)
│   ├── UnlockAllCyclingButton
│   ├── HSeparator
│   ├── Label "COMBAT" (LabelSubheading)
│   └── ForceWinButton (hidden unless in combat)
```

All nodes authored in `.tscn` per the project's scene-tree-first rule. The `.gd` script only binds signals, reads values, and calls managers — never creates nodes in code.

### Drag behavior

Copy `LogWindow._on_titlebar_input` verbatim: track `_is_dragging` and `_drag_offset`, move `global_position` on mouse motion. Same mouse filter setup.

### Force-Win button visibility

The panel polls `AdventureView.is_in_combat` in `_process` and sets `force_win_button.visible` accordingly. Only runs while the panel is open (early-return if `not visible`). Polling cost is negligible and avoids adding a new signal to `AdventureView`.

## Manager hooks

| Action | Call site |
|---|---|
| Set Madra | `ResourceManager.set_madra(spinbox.value)` |
| Set Gold | `ResourceManager.set_gold(spinbox.value)` |
| Add CD XP | `CultivationManager.add_core_density_xp(spinbox.value)` |
| Grant Path Points | `PathManager.add_points(int(spinbox.value))` |
| Force-trigger condition | `UnlockManager.force_unlock_condition(option_button.get_item_metadata(idx))` |
| Unlock all cycling | `for t in CyclingManager._technique_catalog.cycling_techniques: CyclingManager.unlock_technique(t.id)` |
| Force-win combat | `get_tree().root.get_node("MainGame/MainView/AdventureView").force_win_combat()` (path is stable — authored in `main_game.tscn`) |

Dropdown population for condition IDs:
```gdscript
for c in UnlockManager.unlock_condition_list.list:
    option_button.add_item(c.condition_id)
```

### Required public surface changes

- `UnlockManager.force_unlock_condition(condition_id: String) -> void` — new public wrapper. Calls `_unlock_condition` if not already unlocked. Documented as dev-only.
- `AdventureView.force_win_combat() -> void` — new public method. Emits `trigger_combat_end(true, 0)` on the live combat child when `is_in_combat` is true; no-op otherwise.

No other manager changes. No save schema changes.

## Feedback

Every applied action emits a single log line via the existing `LogManager`:

```gdscript
LogManager.log_message("[color=magenta][DEV][/color] Set Madra to %d" % value)
```

No toasts, no row flashes. The `LogWindow` is the single audit trail.

## Edge cases

| Case | Handling |
|---|---|
| Password file missing | Hotkey is a no-op. No modal. |
| Password file has trailing newline | `strip_edges()` on both sides of comparison. |
| Wrong password | Modal closes silently. No retry counter. |
| Set Madra above cap | `ResourceManager.set_madra` already clamps to `>= 0`. Currently does not clamp to `max_madra` — acceptable for a dev tool (lets us test what happens above cap). |
| Add huge CD XP | `add_core_density_xp` already loops through level-ups and awards path points per milestone. Safe. |
| Force-trigger already-unlocked condition | `_unlock_condition` already checks `if not ... in unlocked_condition_ids`. Idempotent. |
| Unlock all cycling when some already unlocked | `unlock_technique` is idempotent (guards on `if technique_id in unlocked`). |
| Force-win with no active combat | Button is hidden. `force_win_combat()` returns early if `not is_in_combat`. |
| Panel open, player switches view | Panel stays visible (z_index high, not tied to view state). |
| Autosave mid-dev-session | Mutations persist to `user://save.tres` on next 5s tick. Documented behavior — close without relying on reload to "undo". |

## Abuse / threat model

- A playtester who extracts `dev_password.txt` from a shared build folder can cheat. **Acceptable** — password gate is a speed bump, not a lock.
- A player who spams `Ctrl+Shift+D` sees nothing because no file exists. **Acceptable** — feature is genuinely invisible on shipped builds.
- A malicious actor who reverse-engineers and calls manager functions directly bypasses the panel entirely. **Acceptable** — this is a single-player idle game; server-side validation is out of scope.

## Testing plan

| Test | Type | Scope |
|---|---|---|
| `test_dev_panel_password.gd` | Unit (GUT) | File missing → locked; file + matching entry → unlocked; file + wrong entry → locked; whitespace-only diff tolerated by `strip_edges`. |
| `test_dev_panel_actions.gd` | Integration (GUT) | Set Madra to 500 → `ResourceManager.get_madra() == 500.0`. Add 100 CD XP → xp reflects. Force-trigger known condition → `is_condition_unlocked` returns true. |
| Manual smoke | In-editor | Open panel, hit each action once, verify log lines. Verify Force-Win button only appears during combat. |

No visual regression tests — GUT doesn't handle them, and the layout is simple enough to eyeball.

## 5-Component Filter (game-design)

| Component | Evaluation |
|---|---|
| **Clarity** | Strong. Each action is explicitly labeled; Apply buttons prevent accidental mutations. Log line confirms what fired. |
| **Motivation** | N/A — this is a dev tool, not player-facing. |
| **Response** | Strong. Click Apply → manager call → signal fires → UI updates. Same frame. |
| **Satisfaction** | N/A. Dev tool, not meant to feel good. |
| **Fit** | Fits as an invisible maintenance tool, not part of the game's cultivation fiction. Uses existing UI theme (pixel_theme) so it doesn't clash visually when open. |

## Out of scope for v1 (future expansion)

Saved for later based on the user's "must-have v1" choice:

- Unlock game system (CYCLING, ADVENTURING enum)
- Advancement stage change (FOUNDATION → COPPER)
- Inventory grants (specific item IDs)
- Ability unlocks & loadout force-equip
- Cycling technique equip (not just unlock)
- Zone teleport (including locked zones)
- Adventure combat deep controls (heal, set vitals, grant Madra mid-combat)
- Quest advance/complete/reset
- Save wipe, force-save, reload
- Respec path points

Adding these in v2/v3 is additive — no spec-level rework required.

## Implementation order

Bottom-up per CLAUDE.md guidance:

1. `UnlockManager.force_unlock_condition` public wrapper + unit test.
2. `AdventureView.force_win_combat` method.
3. `dev_password_modal.tscn` + script + password unit tests.
4. `dev_panel.tscn` + script with all 7 actions wired to managers.
5. Hotkey handler in `main_game.gd` + scene instances in `main_game.tscn`.
6. Integration test for action routing.
7. Manual smoke test in-editor.
