# Cycling System

Last updated: 2026-10-22

## Overview

Cycling is the Foundation-stage active mini-game and the main source of Madra. The player clicks the Madra Ball to send it once around a technique's path on a body outline. Keeping the cursor inside the ball generates Madra continuously. Techniques that define **cycling zones** (inflection points) also award Core Density XP when the player clicks a zone while the ball passes over it. Rewards depend on timing: PERFECT, GOOD or OK.

`CyclingManager` (autoload) owns which techniques are unlocked and which one is equipped. Techniques are unlocked by purchasing Path Tree nodes. A new save starts with the **Foundational Technique**. It has no zones, so it generates Madra but no Core Density XP. XP starts once the player buys the Pure Core Awakening keystone, which unlocks Smooth Flow. Leveling, the Madra cap and breakthrough are covered in [CULTIVATION.md](../cultivation/CULTIVATION.md).

## Player Experience

1. In Spirit Valley, the **Wilderness Cycling** action card appears after the first Celestial Intervener dialogue (event `celestial_intervener_dialogue_1`). Clicking it calls `ActionManager.select_action()`. That stops any running action, such as foraging, and emits `start_cycling`. `CyclingViewState` is pushed, and the cycling overlay opens over a grey background.
2. The overlay shows the body outline with the equipped technique's glowing, pulsing path. The Madra Ball rests at the path start with an idle "breathing" pulse. The right panel has **Resources** and **Techniques** tabs.
3. **Left-click the Madra Ball** to start a cycle. There is no Start button. The ball travels the path once over `cycle_duration` seconds, using a sine ease-in-out tween, so it moves slower at the ends.
4. While the cursor is inside the ball (about 29.5 px radius), a Madra particle spawns every 0.08 s and flies to the Madra orb. Each particle immediately adds `base_madra_per_cycle × 0.08 / cycle_duration` Madra, clamped to the stage Madra cap.
5. If the technique has zones, they appear when the cycle starts. A zone brightens while the ball overlaps it. Left-clicking the zone in that window scores **PERFECT / GOOD / OK** based on how close the ball is to the zone center, and adds that zone's XP to Core Density. The player also sees floating text at the cursor (e.g. `PERFECT +25 XP`) and an XP particle burst from the cursor to the Core Density orb, and the zone greys out. Each zone scores once per cycle. Clicks while the ball is not over the zone are ignored.
6. When the ball reaches the end, the zones hide and a stats summary goes to the debug log. If the **Auto** toggle (`Auto: OFF` / `Auto: ON`) is on, the next cycle starts immediately. Otherwise the player clicks the ball again. Auto Cycle only chains cycles: nothing is earned unless the cursor is in the ball. There is no idle or offline cycling.
7. The **Techniques** tab lists unlocked techniques in unlock order. Each entry shows name, Madra/cycle, duration and zone count. Clicking one equips it, saves it and switches back to the Resources tab. The equipped technique's name is gold.
8. **Esc** or the **X ESC** button closes the view through `ActionManager.stop_action()`. A cycle in progress is cancelled. Madra and XP already awarded during that cycle are kept, because both are paid out incrementally.

## Architecture

```
MainView (Control)                                   — main_view.gd
  MainViewStateMachine/CyclingViewState (Node)       — cycling_view_state.gd (push on start_cycling, pop on stop_cycling)
  GreyBackground (Panel)                             — shown/hidden by CyclingViewState
  CyclingView (Control, z_index 3, hidden by default) — cycling_view.gd (no class_name)
    MarginContainer (margins 150/100/150/100)
      Panel (PanelAccent, panel_cycling_view.tres)
        HBoxContainer
          CyclingTechniqueOutline (Sprite2D)         — body outline art, absolutely positioned
          CyclingBackground (TextureRect, no texture, stretch 0.66)
            CyclingTechnique (Node2D)                — cycling_technique.tscn / cycling_technique.gd
          InfoPanelArea (MarginContainer, stretch 0.33)
            CyclingTabPanel (TabContainer)           — cycling_tab_panel.gd, CyclingTabContainer variant
              CyclingResourcePanel  (tab 0 "Resources")  — cycling_resource_panel.tscn
              TechniquesScrollContainer (tab 1 "Techniques")
                TechniqueListContainer (VBoxContainer)   — CyclingTechniqueSlot × N, created at runtime
        CloseButton (Button "X ESC")                 — fires the close_cycling_view input action
```

```
CyclingTechnique (Node2D)                            — cycling_technique.gd
  PathLine (Line2D)                                  — baked from the curve; width 5, path_pulse shader
  PathGlowLine (Line2D)                              — width 20 glow; path_pulse shader
  AutoCycleToggle (Button, toggle_mode)
  CyclingPath2D (Path2D)                             — curve = technique.path_curve
    PathFollow2D (rotates = false, loop = false)
      MadraBall (Area2D)                             — left-click starts a cycle
        CollisionShape2D (CircleShape2D r ≈ 29.55)
        MadraBallSprite (Sprite2D, Madra-Ball.png × 0.125, madra_ball.gdshader)
    CyclingZone1..N (Area2D)                         — cycling_zone.tscn, created by _create_cycling_zones()

CyclingZone (Area2D)                                 — cycling_zone.gd
  CollisionShape2D (CircleShape2D; 26 in .tscn, set to 20 in setup())
  Sprite2D (Madra-Ball.png × 0.15 as a quad; cycling_zone.gdshader material built in setup())

CyclingResourcePanel (MarginContainer)               — cycling_resource_panel.gd
  MadraSection:        MadraCircle (ProgressShaderRect + liquid_wave), MadraAmountLabel, MadraGenerationRateLabel
  CoreDensitySection:  CoreDensityRect (ProgressShaderRect + core_density_fill), CoreDensityLevelLabel,
                       CoreDensityXPProgressBar, CoreDensityXPLabel, StageLabel
  TechniqueSummarySection: TechniqueNameLabel, TechniqueStatsLabel (RichTextLabel, BBCode)

CyclingTechniqueSlot (Control, min height 80)        — cycling_technique_slot.gd (no class_name)
  MarginContainer/CyclingTechniquePanelContainer (panel_default.tres)
    CyclingTechniqueIcon (TextureRect, placeholder res://icon.svg)
    TechniqueNameLabel, TechniqueStatsLabel
```

`CyclingView` is instanced in `main_game.tscn` for the whole session. It is only hidden and shown, so its `_ready()` wiring runs once at startup. `CyclingTechnique` exports `technique_data_input`. `cycling_view.tscn` sets it to the Foundational Technique, and `CyclingView._ready()` immediately replaces it with `CyclingManager.get_equipped_technique()`.

## Data Model

### CyclingTechniqueData (`scripts/resource_definitions/cycling/cycling_technique/cycling_technique_data.gd`)
| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `id` | `String` | `""` | Unique snake_case key. Used by `CyclingManager`, `SaveGameData` and path-node effects |
| `technique_name` | `String` | `"Basic Cycling"` | Display name |
| `path_curve` | `Curve2D` | — | Path the ball follows, in `CyclingPath2D` local space |
| `cycle_duration` | `float` | `10.0` | Seconds for one full pass |
| `base_madra_per_cycle` | `float` | `25.0` | Madra for a cycle with the cursor in the ball the whole time |
| `cycling_zones` | `Array[CyclingZoneData]` | `[]` | Click zones. Empty means no Core Density XP |

### CyclingZoneData (`.../cycling_technique/cycling_zone_data.gd`)
| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `position` | `Vector2` | `(0, 0)` | Zone center in `CyclingPath2D` local space |
| `timing_window_ratio` | `float` | `0.05` | **Never read.** Zone radius is hardcoded to 20 |
| `perfect_xp` | `int` | `15` | XP for PERFECT |
| `good_xp` | `int` | `10` | XP for GOOD |
| `ok_xp` | `int` | `5` | XP for OK |

### CyclingTechniqueList (`.../cycling_technique/cycling_technique_list.gd`)
| Field | Type | Description |
|-------|------|-------------|
| `cycling_techniques` | `Array[CyclingTechniqueData]` | Full catalog. `CyclingManager` preloads `resources/cycling/cycling_techniques/cycling_technique_list.tres` |

### CyclingActionData (extends `ZoneActionData`)
| Field | Type | Default | Status |
|-------|------|---------|--------|
| `madra_multiplier` | `float` | `1.0` | Never applied |
| `cycle_duration_modifier` | `float` | `1.0` | Never applied |
| `xp_multiplier` | `float` | `1.0` | Never applied |
| `madra_cost_per_cycle` | `float` | `0.0` | Never applied |

The action resource never reaches the view. `CyclingViewState._on_start_cycling(_data)` ignores its argument, and `CyclingView.initialize_cycling_action_data()` has no callers.

### SaveGameData (cycling fields)
| Field | Type | Default |
|-------|------|---------|
| `unlocked_cycling_technique_ids` | `Array[String]` | `["foundation_technique"]` |
| `equipped_cycling_technique_id` | `String` | `"foundation_technique"` |

Madra lives in `SaveGameData.madra`, owned by `ResourceManager`. Core Density lives in `core_density_xp`, `core_density_level` and `current_advancement_stage`, owned by `CultivationManager`.

## Core Systems

### Cycle Lifecycle (`CyclingTechnique`)
`CycleState` is `IDLE`, `CYCLING` or `COMPLETE`. `COMPLETE` is only held briefly inside `_on_cycle_finished()`.

```
MadraBall.input_event (left click) → _start_cycle()          [only from IDLE]
  → reset time_mouse_in_ball / elapsed_cycle_time / click_timings
  → each zone: reset_for_new_cycle() + show_zone()
  → cycling_started.emit()
  → tween PathFollow2D.progress_ratio 0 → 1 over cycle_duration (EASE_IN_OUT, TRANS_SINE)
_process(delta) while CYCLING → mouse tracking + Madra particles (below)
tween.finished → _on_cycle_finished()
  → cycle_completed.emit(base_madra_per_cycle × mouse_tracking_accuracy, mouse_tracking_accuracy)
  → zones hide_zone(); _print_cycle_stats() → Log.info
  → IDLE; if AutoCycleToggle.button_pressed → _start_cycle()
ActionManager.stop_cycling → CyclingView._on_stop_cycling() → CyclingTechnique.stop_cycling()
  → kill tween, IDLE, ball back to progress 0 (zones are not hidden)
```

### Madra Generation
- Each frame, `is_mouse_in_madra_ball()` checks the cursor against the MadraBall `CircleShape2D` (r ≈ 29.55).
- `mouse_tracking_accuracy = time_mouse_in_ball / elapsed_cycle_time`. It is reported in `cycle_completed` and the log, but does not drive rewards.
- While the cursor is inside the ball, `_madra_particle_timer` accumulates. Every `MADRA_PARTICLE_INTERVAL` (0.08 s) it resets to 0, emits `madra_particle_requested(ball_pos)`, and calls `ResourceManager.add_madra(base_madra_per_cycle × 0.08 / cycle_duration)`.
- `ResourceManager.add_madra()` clamps the pool to the stage cap (`100 + 5 × Core Density level` at Foundation; see [CULTIVATION.md](../cultivation/CULTIVATION.md#madra-cap)). Particles keep flying when the pool is full.
- Because the timer resets to 0 instead of carrying the remainder, real income is about 0.96 × the nominal rate at 60, 120 or 144 FPS and 0.8 × at 30 FPS.

### Zone Clicks and Accuracy Tiers
- A zone becomes the `active_zone` when the MadraBall's `Area2D` overlaps it (`area_entered`). With radii of 29.55 + 20, that happens when the centers are within about 49.5 px.
- The click must land on the zone's own 20 px collision circle. `CyclingZone._on_input_event()` emits `zone_clicked` and marks the input as handled. `CyclingTechnique._on_zone_clicked()` accepts it only when `zone == active_zone`, the zone is unused and the state is `CYCLING`.
- `_handle_zone_click()` computes `timing_ratio = clamp(ball_to_zone_distance / 20, 0, 1)`:

| Tier | Condition | Max distance | XP | Colour | XP particles |
|------|-----------|--------------|----|--------|--------------|
| PERFECT | `timing_ratio < 0.3` (`TIMING_PERFECT_THRESHOLD`) | < 6 px | `perfect_xp` | gold | 8 |
| GOOD | `timing_ratio < 0.7` (`TIMING_GOOD_THRESHOLD`) | < 14 px | `good_xp` | green | 5 |
| OK | otherwise, while overlapping | ≈ 49.5 px | `ok_xp` | white | 3 |

- After scoring, `CultivationManager.add_core_density_xp(xp_reward)` is called and the zone runs `mark_as_used()` (shader state −1, no longer pickable).

### Technique Unlock and Equip (`CyclingManager`)
| Method | Returns | Behaviour |
|--------|---------|-----------|
| `get_unlocked_techniques()` | `Array[CyclingTechniqueData]` | Resolves saved IDs against the catalog in unlock order and skips unknown IDs |
| `get_equipped_technique()` | `CyclingTechniqueData` | `null` if none or unknown |
| `unlock_technique(technique_id)` | `void` | Idempotent. Calls `push_error` for an unknown ID. Otherwise appends to save data and emits `technique_unlocked` |
| `equip_technique(technique_id)` | `void` | Calls `push_error` if the ID is unknown or locked. Otherwise sets save data and emits `equipped_technique_changed` |
| `is_technique_unlocked(technique_id)` | `bool` | — |
| `has_unequipped_unlocks()` | `bool` | True if any unlocked ID differs from the equipped one. No production caller yet |

- The catalog index (`_techniques_by_id`) is built in `_ready()` from `cycling_technique_list.tres`. Entries with an empty `id` are skipped. `_live_save_data` re-points on `PersistenceManager.save_data_reset`.
- **Unlock path:** `PathManager.purchase_node()` loops over the node's effects and calls `CyclingManager.unlock_technique(effect.string_value)` for each `UNLOCK_CYCLING_TECHNIQUE`. `CyclingView` listens to `technique_unlocked` and rebuilds the Techniques list. Locked techniques are never shown.
- **Equip path:** `CyclingTechniqueSlot.slot_selected` → `CyclingTabPanel.technique_change_request` → `CyclingView.set_current_technique()`. That emits `current_technique_changed` to the technique, resource panel and tab panel, then calls `CyclingManager.equip_technique(id)`.
- **On load:** `CyclingView._load_equipped_technique()` uses the equipped technique. If there is none, it equips the first unlocked one.

### Path Tree Hook Points
Path perks are authored and priced in [PATH_PROGRESSION.md](../progression/PATH_PROGRESSION.md). Only the technique unlock is live. `PathManager.get_effects()` aggregates the other effects into `PathEffectsSummary`, but nothing outside tests reads it.

| `PathNodeEffectData.EffectType` | Intended effect | Where it would plug in | Status |
|--------------------------------|-----------------|------------------------|--------|
| `UNLOCK_CYCLING_TECHNIQUE` | Unlock technique `string_value` | `PathManager.purchase_node()` → `CyclingManager.unlock_technique()` | Live |
| `MADRA_GENERATION_MULT` | Multiply Madra per cycle | Madra-per-particle amount in `CyclingTechnique._process()` | Not applied |
| `CYCLING_ACCURACY_BONUS` | Add px to the zone radius | `CyclingZone.setup()` (radius hardcoded 20) and the divisor in `_handle_zone_click()` | Not applied |
| `CORE_DENSITY_XP_MULT` | Multiply Core Density XP | `_handle_zone_click()` or `CultivationManager.add_core_density_xp()` | Not applied |
| `MADRA_CAPACITY_BONUS`, `MADRA_ON_LEVEL_UP` | Madra cap and level-up Madra | See [CULTIVATION.md](../cultivation/CULTIVATION.md) | Not applied |

### Visual Feedback
| Element | Implementation |
|---------|----------------|
| Path | `_update_path_line()` samples the curve every 10 px (minimum 50 points) into `PathLine` (width 5, colour `(0.75, 0.88, 1.0, 0.9)`) and `PathGlowLine` (width 20, colour `(0.5, 0.72, 0.95, 0.3)`). Both get a `path_pulse.gdshader` alpha-breathing material (speed 1.5 / 1.2, min alpha 0.65 / 0.4) |
| Madra Ball | `madra_ball.gdshader`: UV rotation, idle pulse (±12%) that becomes a subtle pulse while moving, and an inner glow. `_update_madra_ball_shader()` sets `movement_state` from progress speed and `spin_speed` from 3 to 15 |
| Zones | `cycling_zone.gdshader` draws procedurally: an inner circle, a ring and a glow from UV only, so the texture is just a quad. `state`: 0 = idle, 1 = active, −1 = used. `flash_zone(colour)` sets `active_color` and state 1 for 0.4 s, but `mark_as_used()` sets state −1 in the same frame, so the flash never shows (see Bugs) |
| Madra particles | `FlyingParticle` (bezier, trail): colour `(0.5, 0.78, 1.0, 0.85)`, size 4, 0.5 s flight. Each arrival triggers `pulse_madra_orb()`, a scale of 1.08 over 0.06 s then back over 0.12 s |
| XP particles | `int(8 × quality)` particles (quality 1.0 / 0.7 / 0.4), ±15 px spread, 0.4–0.7 s flight, size 3–5, tier colour. The last particle pulses the Core Density orb |
| Floating text | `FloatingText` at the cursor: `"<TIER> +<xp> XP"` |

### Resources Tab (`CyclingResourcePanel`)
| Element | Source |
|---------|--------|
| `MadraCircle` (`liquid_wave.gdshader`) | `current / stage.get_max_madra(level)`. A bottom-up liquid fill with wave, foam and swirl, lerped by `ProgressShaderRect` (`SPEED_LERP` 10) |
| `Madra: X / Y` | Refreshed on `ResourceManager.madra_changed` only |
| Rate label | Idle: `"<base>/cycle"`. After the first `cycling_started`: `"+<m/s>/s  <m>/cycle"` from the last `cycle_completed` |
| `CoreDensityRect` (`core_density_fill.gdshader`) | `level / MAX_CORE_DENSITY_LEVEL` (100). A radial fill with an edge ring and pulse |
| Level, XP bar, `XP: x / y`, `Stage: <name>` | `CultivationManager` getters, refreshed on `core_density_xp_updated` and `advancement_stage_changed` |
| Technique summary | BBCode name (gold `#D4A84A`) and a table of Madra/cycle, duration and zone count |

## Signals

| Signal | Source | Listeners |
|--------|--------|-----------|
| `cycling_started` | `CyclingTechnique` | `CyclingResourcePanel.on_cycling_started` |
| `cycle_completed(madra_earned, mouse_accuracy)` | `CyclingTechnique` | `CyclingResourcePanel.on_cycle_completed` |
| `madra_particle_requested(from_pos)` | `CyclingTechnique` | `CyclingView._on_madra_particle_requested` |
| `xp_particle_requested(from_pos, color, quality)` | `CyclingTechnique` | `CyclingView._on_xp_particle_requested` |
| `zone_clicked(zone, zone_data)` | `CyclingZone` | `CyclingTechnique._on_zone_clicked` |
| `current_technique_changed(technique_data)` | `CyclingView` | `CyclingTechnique.set_technique_data`, `CyclingResourcePanel.set_technique_data`, `CyclingTabPanel.set_current_technique` |
| `slot_selected(data)` | `CyclingTechniqueSlot` | `CyclingTabPanel` |
| `technique_change_request(data)` | `CyclingTabPanel` | `CyclingView._on_technique_change_request` |
| `technique_unlocked(technique)` | `CyclingManager` | `CyclingView._on_technique_unlocked` |
| `equipped_technique_changed(technique)` | `CyclingManager` | None |
| `start_cycling(action_data)` / `stop_cycling()` | `ActionManager` | `CyclingViewState` (push/pop); `CyclingView` (stop only) |

## Integration Points

| System | Connection |
|--------|------------|
| `ActionManager` | Selecting a `CYCLING` zone action stops the current action and emits `start_cycling`. `stop_action()` emits `stop_cycling`, increments zone progression for the action, runs its `success_effects` (none authored), and resumes the zone's idle action ("Resumed <name>") |
| `MainView` / `CyclingViewState` | Push/pop modal state. `handle_input()` maps `close_cycling_view` (Esc) to `ActionManager.stop_action()` |
| `ResourceManager` | `add_madra()` per particle. `madra_changed` refreshes the panel |
| `CultivationManager` | `add_core_density_xp()` per scored zone. The panel reads level, XP, the XP needed and the stage name. Madra cap via `get_max_madra()` |
| `CyclingManager` | Unlocked/equipped state. Queried by `CyclingView` |
| `PathManager` | `purchase_node()` → `CyclingManager.unlock_technique()` |
| `PersistenceManager` | Technique IDs, Madra and Core Density persist in `SaveGameData` |
| `UnlockManager` / `QuestManager` | Every `madra_changed` (about 12/s while tracking) re-evaluates unlock conditions. `q_fill_core` step 1 completes at Madra ≥ 100 (`q_fill_core_madra_full`) |
| `DevPanel` (Ctrl+Shift+D, needs `user://dev_password.txt`) | "Unlock All Cycling Techniques" iterates `CyclingManager._technique_catalog`. The panel also has "Madra" and "Add CD XP" fields |
| Zones | Spirit Valley's Wilderness Cycling card uses the default action-button presenter. The Aura Well training action is a second, passive Madra source (+1.5 per tick); see [ZONES.md](../zones/ZONES.md) |

## Existing Content

### Techniques (`resources/cycling/cycling_techniques/`)
| `id` | Name | Duration | Madra/cycle | Madra/s at 100% tracking | Madra per particle | Zones | Max XP/cycle | Curve | How unlocked |
|------|------|----------|-------------|--------------------------|--------------------|-------|--------------|-------|--------------|
| `foundation_technique` | Foundational Technique | 8 s | 50 | 6.25 | 0.5 | 0 | 0 | `foundation_path.tres` (5 points, vertical loop) | Default in `SaveGameData` |
| `smooth_flow` | Smooth Flow Technique | 15 s | 200 | 13.3 | 1.07 | 4 | 125 | `smooth_path.tres` (13 points) | Path node `pure_core_awakening` (keystone, 1 point, no prerequisite) |
| `torrential_flow` | Torrential Flow | 8 s | 250 | 31.25 | 2.5 | 1 | 30 | `torrential_curve.tres` (12 points) | Path node `torrential_flow` (major, 1 point, requires `pure_core_awakening`) |

Catalog order in `cycling_technique_list.tres` is Foundational, Smooth Flow, Torrential Flow. `cycling_technique.tscn` defaults `technique_data_input` to Torrential Flow, and `cycling_view.tscn` overrides it to Foundational.

### Cycling Zones
| Technique | Resource | Position | PERFECT | GOOD | OK |
|-----------|----------|----------|---------|------|----|
| Smooth Flow | `smooth_flow/cycling_zone_data/zone_1.tres` | (464, 416) | 25 | 15 | 5 (default) |
| Smooth Flow | `zone_2.tres` | (110, 430) | 25 | 15 | 5 (default) |
| Smooth Flow | `zone_3.tres` | (320, 180) | 50 | 25 | 10 |
| Smooth Flow | `zone_4.tres` | (530, 430) | 25 | 15 | 5 (default) |
| Torrential Flow | inline sub-resource in `torrential_flow.tres` | (322, 256) | 30 | 25 | 20 |

Every zone sits on its technique's curve, and the ball passes Smooth Flow's zones in order 1 → 4. All zones leave `timing_window_ratio` at 0.05, which is unused. Smooth Flow per-cycle XP is 125 when every click is PERFECT, 70 when every click is GOOD and 25 when every click is OK.

### Cycling Actions
| Action | `action_id` | Zone | Unlock condition | Modifiers |
|--------|-------------|------|------------------|-----------|
| Wilderness Cycling | `wilderness_cycling_action` | Spirit Valley | `celestial_intervener_dialogue_1` (`EVENT_TRIGGERED`) | All defaults, unused |

### Art and Shaders
| Asset | Used by |
|-------|---------|
| `assets/sprites/cycling/cycling_technique_outline.png` | `CyclingTechniqueOutline`, embedded as a `CompressedTexture2D` that points into `.godot/imported/` |
| `assets/sprites/cycling/Madra-Ball.png` | Madra Ball sprite and the zone sprite quad |
| `assets/sprites/cycling/madra_circle.png` | Madra and Core Density orbs (cycling and zone resource panels) |
| `Cycling_Technique_Background.webp`, `background.png`, `backgrounds/cycling_background_with_border.png`, `border.png`, `fill.png` | Not referenced by any scene or script |
| `madra_ball`, `cycling_zone`, `path_pulse`, `liquid_wave`, `core_density_fill` (`assets/shaders/`) | See Visual Feedback and Resources Tab |

## Key Files

| File | Purpose |
|------|---------|
| `scenes/cycling/cycling_view/cycling_view.gd` / `.tscn` | View orchestrator: technique propagation, particles, close button |
| `scenes/cycling/cycling_technique/cycling_technique.gd` / `.tscn` | Cycle state, path rendering, mouse tracking, Madra payout, zone scoring |
| `scenes/cycling/cycling_technique/cycling_zone.gd` / `.tscn` | Single click zone (state, flash, input) |
| `scenes/cycling/cycling_tab_panel/cycling_tab_panel.gd` | Resources/Techniques `TabContainer` and slot list |
| `scenes/cycling/cycling_technique_slot/cycling_technique_slot.gd` / `.tscn` | Technique list entry |
| `scenes/cycling/cycling_resource_panel/cycling_resource_panel.gd` / `.tscn` | Madra, Core Density and technique summary |
| `scenes/cycling/cycling_resource_panel/progress_shader_rect.gd` | `ProgressShaderRect`: lerps a shader `progress` uniform (only the cycling panel uses it since the zone view's cabinet switched to texture strips) |
| `scenes/ui/main_view/states/cycling_view_state.gd` | Modal state: show/hide, Esc handling |
| `singletons/cycling_manager/cycling_manager.gd` | Unlocked/equipped technique state and catalog |
| `scripts/resource_definitions/cycling/cycling_technique/*.gd` | `CyclingTechniqueData`, `CyclingZoneData`, `CyclingTechniqueList` |
| `scripts/resource_definitions/zones/zone_action_data/cycling_action_data/cycling_action_data.gd` | `CyclingActionData` (unused modifiers) |
| `resources/cycling/cycling_techniques/` | Technique, curve and zone content |
| `scenes/ui/flying_particle/flying_particle.gd`, `scenes/ui/floating_text/floating_text.gd` | Shared feedback effects |
| `assets/shaders/madra_ball.gdshader`, `cycling_zone.gdshader`, `path_pulse.gdshader`, `liquid_wave.gdshader`, `core_density_fill.gdshader` | Cycling visuals |
| `tests/unit/test_cycling_manager.gd` | 20 `CyclingManager` tests (defaults, unlock, equip, errors, `has_unequipped_unlocks`) |

## Work Remaining

### Bugs

- `[MEDIUM]` Log flood while cycling. `CyclingTechnique._process()` calls `ResourceManager.add_madra()` every 0.08 s, and `add_madra()` writes `"Gained N Madra"` to the in-game log whenever `amount >= 1.0`. Smooth Flow (1.07 per particle) and Torrential Flow (2.5) produce about 12 log lines per second, even when Madra is already capped.
- `[LOW]` Switching technique mid-cycle leaves the old tween running. `CyclingTechnique.setup()` sets `IDLE` and resets the ball but never kills `movement_tween`. The ball keeps sliding along the new path untracked, and `_on_cycle_finished()` later emits a phantom `cycle_completed` (and auto-restarts if Auto is on).
- `[LOW]` Madra income depends on frame rate and is below the nominal rate. `_madra_particle_timer` resets to 0 instead of subtracting the interval, giving about 0.96 × base at 60 FPS and 0.8 × at 30 FPS. `cycle_completed` reports `base_madra_per_cycle × accuracy`, which matches neither the amount actually paid nor the cap.
- `[LOW]` The zone hit flash is invisible. `_handle_zone_click()` calls `zone.flash_zone(colour)` (state 1 with the tier colour) and then `zone.mark_as_used()` (state −1) in the same frame. The used state wins, so the gold, green or white flash never renders.
- `[LOW]` `CyclingTechnique.stop_cycling()` (closing mid-cycle) does not hide or reset zones or clear `active_zone`, so the interrupted cycle's zones are still visible when the view reopens.
- `[LOW]` `CyclingResourcePanel._is_cycling` is set on `cycling_started` and never cleared. The rate label shows `+0.0/s  0.0/cycle` during the first cycle and never returns to the idle `"<base>/cycle"` text.
- `[LOW]` `_update_madra_ball_shader()` derives speed from `abs(progress delta) × 60.0` and ignores `delta`, which assumes 60 FPS.

### Missing Functionality

- `[HIGH]` Path perks that target cycling do nothing. `MADRA_GENERATION_MULT`, `CYCLING_ACCURACY_BONUS` and `CORE_DENSITY_XP_MULT` are sold in the Pure Madra tree but never applied (see Path Tree Hook Points).
- `[HIGH]` `CyclingActionData` modifiers (`madra_multiplier`, `cycle_duration_modifier`, `xp_multiplier`, `madra_cost_per_cycle`) are never applied. The action data is also dropped: `CyclingViewState._on_start_cycling()` ignores it and `CyclingView.initialize_cycling_action_data()` is never called. Every cycling action behaves identically.
- `[MEDIUM]` `CyclingZoneData.timing_window_ratio` is never read. `CyclingZone.setup()` hardcodes the radius to 20 (the `.tscn` says 26), so zone difficulty cannot vary. When this is wired up, make the zone's `CircleShape2D` local to scene: the sub-resource in `cycling_zone.tscn` is shared by every instance and `setup()` mutates it.
- `[MEDIUM]` No combo or streak reward for consecutive PERFECT/GOOD clicks.
- `[MEDIUM]` No "new technique" signal to the player. `CyclingManager.has_unequipped_unlocks()` has no caller (only the dock's Abilities button gets a notification ring), and an unlock from the Path Tree shows no notification.
- `[LOW]` No penalty for mis-timed clicks. Clicks while the ball is not over a zone are ignored, so spam-clicking a zone guarantees at least OK.
- `[LOW]` Auto Cycle is free from the start and only chains cycles. The GDD frames auto-cycling as a Copper Scripting reward, and there is no idle or offline cycling.

### Content

- `[HIGH]` No audio. There are no `AudioStreamPlayer` nodes under `scenes/cycling/`: nothing for ball movement, zone clicks, PERFECT hits or cycle completion.
- `[MEDIUM]` Techniques differ only in curve, zones and numbers. All share one body outline, pose and background, and `CyclingTechniqueData` has no fields for art, background or icon.
- `[MEDIUM]` Only 3 techniques and 5 zones exist, all Foundation-tier. Torrential Flow has a single zone.
- `[LOW]` Placeholder art: technique slot icons use `res://icon.svg`, and zone sprites reuse `Madra-Ball.png` as a quad.

### UI

- `[MEDIUM]` Static scene layout. `CyclingBackground` has no texture, the body outline is a hard-positioned `Sprite2D` (position (537, 452), scale (1, 1.387)), and there is no per-technique or per-location background. Five cycling sprites are unused (see Art and Shaders).
- `[LOW]` The view does not explain that the starting Foundational Technique has no zones and earns no Core Density XP. The summary just says `Zones 0`.
- `[LOW]` The `Madra: X / Y` label refreshes only on `madra_changed`, so the cap lags after a Core Density level-up until Madra changes again.
- `[LOW]` Slot doc comment says "gold border", but equipped state is shown with a gold name colour only. Locked techniques are hidden by design, so players cannot see what is still unlockable.

### Tech Debt

- `[MEDIUM]` Test gap: only `CyclingManager` is tested. Untested: zone tier thresholds, the Madra-per-particle formula, accuracy tracking, and content integrity (unique non-empty technique IDs; path-node `UNLOCK_CYCLING_TECHNIQUE` values matching catalog IDs). `test_path_manager.gd` checks `PathManager.get_unlocked_cycling_techniques()` but not that `CyclingManager` actually unlocked the technique.
- `[LOW]` `cycling_technique_slot.tscn` points its script at the deleted `scenes/cycling/cycling_technique_selector/cycling_technique_slot.gd`. It still loads because the UID (`uid://behnplj43lkoe`) resolves.
- `[LOW]` `cycling_view.tscn` embeds the outline as a `CompressedTexture2D` with `load_path` into `.godot/imported/…ctex` instead of an `ext_resource` to `cycling_technique_outline.png` (`uid://b0ulqvd4yyp07`).
- `[LOW]` `cycling_technique.tscn` defaults `technique_data_input` to `torrential_flow.tres`. That value is always overridden, so the default is misleading.
- `[LOW]` Private access across classes. `DevPanel` reads `CyclingManager._technique_catalog`.
- `[LOW]` Coding-standard gaps in `cycling_technique.gd`:
  - untyped constants and locals;
  - `is_mouse_in_madra_ball()` uses `get_node("CollisionShape2D")` and `_handle_zone_click()` uses `zone.get_child(0).shape.radius` instead of `%` references;
  - `set_technique_data()` duplicates `setup()`, and `click_timings` exists only to feed the per-cycle `Log.info` dump;
  - stale comments in `cycling_technique_data.gd` ("This is the key change");
  - `cycling_view.gd` and `cycling_technique_slot.gd` have no `class_name`.
- `[LOW]` `CyclingResourcePanel._update_technique_display()` builds BBCode with hardcoded font sizes and colours instead of theme variants (see [UI_STYLING.md](../UI_STYLING.md)).
- `[LOW]` `CyclingTechnique._process()` and both `ProgressShaderRect` orbs run every frame even while the view is hidden.

## Related Docs

- [CULTIVATION.md](../cultivation/CULTIVATION.md): Core Density, Madra cap, stages, breakthrough
- [breakthrough-tribulation.md](../cultivation/breakthrough-tribulation.md): Tribulation design (reuses cycling components; not implemented)
- [PATH_PROGRESSION.md](../progression/PATH_PROGRESSION.md): path nodes that unlock techniques and the cycling perks
- [FOUNDATION_PLAYTHROUGH.md](../progression/FOUNDATION_PLAYTHROUGH.md): intended cycling pacing (Beat 1 Madra fill, Keystone #1)
- [RESOURCES.md](../infrastructure/RESOURCES.md): Madra pool and adventure budget
- Historical: [CYCLING_UI_REDESIGN.md](CYCLING_UI_REDESIGN.md), [CYCLING_UI_IMPLEMENTATION_PLAN.md](CYCLING_UI_IMPLEMENTATION_PLAN.md), [technique unlock spec](../superpowers/specs/2026-04-12-cycling-technique-unlock-design.md)
