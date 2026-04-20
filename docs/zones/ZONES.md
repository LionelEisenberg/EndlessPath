# Zone / Map System

## Overview

The Zone system is the game's home base. Players see a hex-grid tilemap where each tile represents a zone. Clicking a zone moves the character sprite to that tile and opens the Zone Info Panel on the right, showing available actions. Actions route through `ActionManager` to trigger cycling, adventure, foraging, or NPC dialogue. Zones are gated by `UnlockConditionData` — completing narrative events or reaching thresholds unlocks new zones and actions.

## Player Experience

1. The zone view is the default view on game start
2. Hex tiles show zones in four states — ghost neighbors (transparent, structural tiles framing the map), locked (greyed), unlocked (normal), selected (highlighted)
3. Clicking an unlocked tile moves the character sprite at 150 px/s
4. The right-side Zone Info Panel rebuilds to show available actions, grouped by type
5. Clicking an action button activates it via `ActionManager.select_action()`
6. Active actions are visually marked; only one action runs at a time
7. Completing narrative events (e.g., NPC dialogue) can unlock new zones and actions in real-time

## Architecture

```
ZoneViewBackground (Node2D)                 — zone_view_background.gd
  Parallax2D × 12                           — depth-sorted forest layers

ZoneTilemap (Node2D)                        — zone_tilemap.gd
  MainZoneTileMapLayer (HexagonTileMapLayer) — tile rendering + click/hover signals
  HoverSelector (AnimatedSprite2D)          — hex_hover_selector.gd, shared ring (PR #23)
  CharacterBody2D                           — player sprite
  Atmosphere                                — vignette + mist + motes (PR #23)
  GlowingPath instances                     — animated lines between unlocked zones (PR #23)
  LockedZoneOverlay instances               — grey hex + lock icon per locked zone (PR #23)
  ZoneTransition (Node)                     — zone_transition.gd

ZoneHeader (Panel)                          — zone_header.gd
  (floating top-left)                       — zone name + description display

ZoneResourcePanel (Panel)                   — zone_resource_panel.gd
  (floating left side)                      — Madra + Core Density orbs with labeled titles
                                              + golden advancement stage name

ZoneInfoPanel (PanelContainer)              — zone_info_panel.gd
  ZoneActionTypeSection (per action type)   — zone_action_type_section.gd
    ZoneActionButton (per action)           — zone_action_button.gd
    (card-style; colored dot per category:
     green=foraging, red=adventure, teal=cycling)
```

### Parallax Background System

`ZoneViewBackground` manages a 12-layer pixel art forest for Spirit Valley. Each layer is a `Parallax2D` node with a `Sprite2D` child; the `scroll_scale` increases from the back layers (near 0) to the front layers (near 1), producing a depth illusion as the camera pans. Layer images live in `assets/sprites/zones/backgrounds/background 1 - Spirit Valley/`.

### Adventure Start Transition (ZoneTransition)

Adventure starts are two-phase to accommodate the Madra drain animation (PR #16):

```
1. ZoneActionButton emits adventure_start_requested (carries madra_budget)
2. ZoneViewState blocks all input via full-screen overlay Control
3. ZoneTransition:
   a. Deducts Madra from ResourceManager
   b. Fires staggered flying particles from Madra orb → player character
   c. After drain completes → camera zooms into player character
4. ZoneTransition emits confirm_adventure_start (carries madra_budget)
5. ActionManager starts adventure with the confirmed budget
```

`ZoneTransition` owns all transition logic: particle spawning, camera zoom, Madra spending. `ZoneResourcePanel` is display-only (orbs + position). On return from adventure, the camera resets to its original zoom.

### Action Buttons

`ZoneActionButton` is a type-agnostic card shell that delegates its visuals to a per-type **presenter** (PR #29). The button owns the panel styling, click routing, hover feedback, and three slots that presenters can fill:

- `OverlaySlot` — full-rect `Control` layered over the card (used for per-tick sweep shaders)
- `InlineSlot` — top-row `HBoxContainer` next to the action name and description (used for inline badges)
- `FooterSlot` — `VBoxContainer` below the top row (used for progress bars and counters)

A presenter scene is selected by `action_type` via `ZoneActionButton.PRESENTER_SCENES: Dictionary[ActionType → PackedScene]`. Presenters extend the abstract `ZoneActionPresenter` base and implement `setup()` / `teardown()` plus optional hooks (`set_is_current`, `can_activate`, `on_activation_rejected`). The button exposes helpers — `get_category_color()`, `get_madra_target_global_position()`, `get_action_card()`, `set_text_dimmed()` — that presenters use without knowing about each other.

| Presenter | Action types | What it renders |
|-----------|--------------|-----------------|
| `ForagingPresenter` | FORAGE | Sweep shader overlay tied to `ActionManager.action_timer`; spawns floating text with rolled loot on `foraging_completed` |
| `AdventurePresenter` | ADVENTURE | Madra cost badge in the inline slot (**gold** when ≥50% of zone capacity, **red** when below); dims text and plays a shake-reject animation on click when unaffordable |
| `TrainingPresenter` | TRAIN_STATS | Sweep overlay + attribute-progress badge inline (e.g. `+ 0 / 4 Spirit`) + graded `TickProgressBar` in the footer showing ticks-within-current-level; spawns a Madra `FlyingParticle` per tick and flashes the footer bar on level-up |
| `DefaultZoneActionPresenter` | CYCLING, NPC_DIALOGUE | No-op fallback; the card stands on its own card styling |

Per-category colors live in `ZoneActionButton.CATEGORY_COLORS` (forage=green, adventure=red, cycling=teal, dialogue=gold, training=purple) and the selected-state border pulls its tint from `get_category_color()`.

### Tile Rendering

Zone tiles are rendered from `scenes/tilemaps/tilemap_tileset.tres`. Each zone
selects a forest tile variant via `ZoneData.tile_variant_index`; each variant
is its own atlas source. All variants share the same texture dimensions
(164×190 PNG, 156×181 visible hex) so grid layout is uniform and future
variants drop in cleanly.

| Source ID | Variant | Visual |
|-----------|---------|--------|
| Source 8 (FOREST variant 0, Hex_Forest_00_Basic) | 1 | Unlocked OR locked, unselected |
| Source 8 (FOREST variant 0) | 2 | Currently selected (player's zone) |
| Source 8 (FOREST variant 0) | 3 | Ghost neighbor (dark/transparent) |

Source 0 (`tile_horizontal.png`, 164×190) is retained for the adventure
tilemap's generic path tiles — it is no longer used by the zone view.

**Locked zones** render the same forest variant as unlocked zones — the
lock state is communicated by a separate overlay node stacked on top
(`scenes/zones/locked_zone_overlay/locked_zone_overlay.tscn`), which is
a hex-shaped semi-transparent grey `Polygon2D` with `assets/lock_icon.png`
centered on it. `ZoneTilemap._refresh_locked_overlays()` manages the
overlay instances — one per locked zone, positioned at each zone's
world coordinates. When `UnlockManager.condition_unlocked` fires, the
overlays are rebuilt and any newly-unlocked zones lose their overlay.
This gives players a "here's what this zone looks like" preview while
still clearly marking it as inaccessible.

Camera (`zone_camera_2d.gd`) clamps position to map bounds each frame.

### Tile Variants

Each zone picks its hex tile artwork via `ZoneData.tile_variant_index`. The
variant index maps to an atlas source id via `ZoneTilemap.ZONE_TILE_VARIANT_SOURCE_IDS`.

**Imported variants (PR #23):**

All 23 forest variants (`Hex_Forest_00` through `Hex_Forest_22`) are imported
at 164×190 and live in `assets/sprites/tilemap/hex_tiles/forest/`. They are
packed into a single `TileSetAtlasSource` (source ID 8) backed by
`hex_forest_atlas.png` — a 6-column grid generated by
`scenes/tilemaps/scripts/pack_hex_atlas.py`. The adventure tilemap also uses
this atlas, selecting a deterministic-random variant per cube coordinate via
`_get_random_forest_atlas_coords()`.

Zone tiles select their variant via `ZoneData.tile_variant_index`, which maps
into `ZONE_TILE_VARIANT_SOURCE_IDS` in `zone_tilemap.gd`. To add new variants,
add the PNG to the forest folder, re-run the atlas packer, and append the
source ID mapping.

## Data Model

### ZoneData
| Field | Type | Description |
|-------|------|-------------|
| `zone_name` | `String` | Display name |
| `zone_id` | `String` | Unique identifier |
| `description` | `String` | Flavor text |
| `tilemap_location` | `Vector2i` | Position on hex grid |
| `zone_unlock_conditions` | `Array[UnlockConditionData]` | Gate conditions |
| `all_actions` | `Array[ZoneActionData]` | Available activities |
| `tile_variant_index` | `int` | Index into `ZONE_TILE_VARIANT_SOURCE_IDS` selecting which forest tile art is drawn for this zone. See **Tile Variants** above |

### ZoneActionData (base class)
| Field | Type | Description |
|-------|------|-------------|
| `action_id` | `String` | Unique identifier |
| `action_name` | `String` | Display name |
| `action_type` | `ActionType` | Category enum |
| `unlock_conditions` | `Array[UnlockConditionData]` | Per-action gate |
| `max_completions` | `int` | 0 = infinite, N = finite |
| `success_effects` / `failure_effects` | `Array[EffectData]` | Post-completion effects |

### ActionType Enum
| Type | Implemented | Handler |
|------|-------------|---------|
| `FORAGE` | Yes | Timer-based loot rolling |
| `ADVENTURE` | Yes | Opens adventure view |
| `CYCLING` | Yes | Opens cycling view |
| `NPC_DIALOGUE` | Yes | Starts Dialogic timeline |
| `TRAIN_STATS` | Yes | Periodic tick timer; `effects_per_tick` fire every tick, `effects_on_level` fire per crossed level. Emits `training_tick_processed` / `training_level_gained` (PR #29) |
| `MERCHANT` | No | No handler |
| `ZONE_EVENT` | No | No handler |

### Action Subclasses

| Class | Key Fields |
|-------|------------|
| `ForageActionData` | `loot_table`, `madra_cost_per_second`, `foraging_interval_in_sec` |
| `CyclingActionData` | `madra_multiplier`, `cycle_duration_modifier`, `xp_multiplier`, `madra_cost_per_cycle` |
| `AdventureActionData` | `adventure_data`, `time_limit_seconds`, `gold_multiplier`, `stamina_regen_modifier` |
| `NpcDialogueActionData` | `dialogue_timeline_name` |
| `TrainingActionData` | `tick_interval_seconds`, `ticks_per_level: Array[int]`, `tail_growth_multiplier`, `effects_per_tick`, `effects_on_level`. Exposes `get_current_level(ticks)`, `get_ticks_required_for_level(level)`, `get_progress_within_level(ticks)` |

### ZoneProgressionData (per-zone save data)
| Field | Type | Description |
|-------|------|-------------|
| `action_completion_count` | `Dictionary[String, int]` | action_id -> completions |
| `training_tick_progress` | `Dictionary[String, int]` | action_id -> accumulated training ticks (PR #29) |
| `forage_active` | `bool` | Saved but not used on load |
| `forage_start_time` | `float` | Saved but not used on load |

## Action Lifecycle (ActionManager)

```
1. select_action(action_data)
2. Stop current action if any:
   → Increment zone progression for completed action
   → Run success_effects or failure_effects
3. Set new current action, emit current_action_changed
4. Execute by type:
   FORAGE   → Start repeating timer → roll loot table on each tick
   CYCLING  → Emit start_cycling signal → view transition
   ADVENTURE → Emit start_adventure signal → view transition
   NPC_DIALOGUE → DialogueManager.start_timeline() → stop on dialogue_ended
   TRAIN_STATS → Start tick timer at `tick_interval_seconds`; each timeout increments ZoneManager training ticks, fires `effects_per_tick`, emits `training_tick_processed`; any levels crossed fire `effects_on_level` + emit `training_level_gained` (PR #29)
5. stop_action(successful)
   → Stop and increment progression
   → Process completion effects
   → Clear current action
```

Changing zones via `ZoneManager.zone_changed` cancels any active action.

## Zone Info Panel Rebuilding

The panel rebuilds on three triggers:
1. `ZoneManager.zone_changed` — rebuild everything for the new zone
2. `ZoneManager.action_completed` — remove exhausted one-time actions
3. `UnlockManager.condition_unlocked` — add newly available actions

Actions are grouped by `ActionType` into `ZoneActionTypeSection` nodes. Each section instantiates `ZoneActionButton` nodes for matching actions.

## Unlock Chain Example (Spirit Valley)

```
1. Player clicks "Talk to the Celestial Intervener" (NPC_DIALOGUE, max_completions=1)
2. Dialogic plays "celestial_intervener_introduction_1" timeline
3. Dialogue ends → stop_action() → _process_completion_effects(true)
4. TriggerEventEffectData.process() → EventManager.trigger_event("celestial_intervener_dialogue_1")
5. EventManager emits event_triggered → UnlockManager._evaluate_all_conditions()
6. "celestial_intervener_dialogue_1" condition evaluates true → condition_unlocked signal
7. ZoneInfoPanel rebuilds → "Wilderness Cycling" and "Spring Forest Foraging" appear
8. AwardItemEffectData gives the player a Dagger
9. StartQuestEffectData starts `q_fill_core`
```

## Integration Points

| System | Connection |
|--------|------------|
| ActionManager | Routes zone action selections to correct handlers |
| UnlockManager | Gates zones and actions via conditions |
| ZoneManager | Tracks zone state, progression, emits zone_changed |
| MainView | Zone view is the default state via ZoneViewState |
| Foraging | Timer-based loot rolling via ForageActionData |
| Cycling | start_cycling signal from CyclingActionData |
| Adventure | start_adventure signal from AdventureActionData |
| Dialogue | NpcDialogueActionData triggers Dialogic timelines |

## Existing Content

### Spirit Valley (`zone_id: "SpiritValley"`)
- Location: `(0, 0)`, no unlock conditions (always available)
- Actions (post PR #32 NPC rename + Foundation Beat 2):
  1. **Celestial Intervener Dialogue (Part 1)** — NpcDialogueActionData, max_completions=1, awards a Dagger + triggers `celestial_intervener_dialogue_1` event, starts `q_fill_core`
  2. **Celestial Intervener Dialogue (Part 2)** — NpcDialogueActionData, max_completions=1, requires `q_fill_core_madra_full`, triggers `celestial_intervener_dialogue_2` event, starts `q_first_steps`
  3. **Celestial Intervener Dialogue (Part 3)** — NpcDialogueActionData, max_completions=1, requires `q_first_steps_enemy_defeated`, triggers `celestial_intervener_dialogue_3` event, starts `q_reach_core_density_10`
  4. **Wilderness Cycling** — CyclingActionData, madra_multiplier=2.0, requires `celestial_intervener_dialogue_1`
  5. **Spring Forest Foraging** — ForageActionData, loot: Dewdrop Tear (1-5) + Spirit Fern (2-6), requires `celestial_intervener_dialogue_1`
  6. **The Shallow Woods** — AdventureActionData (`shallow_woods.tres`), 300s time limit, requires `q_fill_core_completed`
  7. **Spirit Well Training** — TrainingActionData, 1s tick interval, `ticks_per_level = [60, 300, 600, 1200]`, awards Madra per tick + 1 Spirit attribute per level (PR #29)

### Test Zone (`zone_id: "TestZone"`)
- Location: `(0, 1)`, no actions
- Requires: `celestial_intervener_dialogue_1` event

## Key Files

| File | Purpose |
|------|---------|
| `scenes/zones/zone_tilemap/zone_tilemap.gd` | Tilemap rendering, zone selection |
| `scenes/zones/zone_header/zone_header.gd` | Zone name and description display (extracted from ZoneInfoPanel, PR #14) |
| `scenes/zones/zone_header/zone_header.tscn` | Zone header scene |
| `scenes/zones/zone_view_background/zone_view_background.gd` | Parallax forest background (12-layer, PR #14) |
| `scenes/zones/zone_view_background/zone_view_background.tscn` | Parallax background scene |
| `scenes/zones/zone_transition/zone_transition.gd` | Adventure start transition orchestration (PR #16) |
| `scenes/zones/zone_info_panel/zone_info_panel.gd` | Action display and triggering |
| `scenes/zones/zone_action_button/zone_action_button.gd` | Type-agnostic action button shell + presenter factory (PR #29) |
| `scripts/ui/zone_action_presenter.gd` | Abstract presenter base class (PR #29) |
| `scenes/zones/zone_action_button/presenters/foraging_presenter.gd` | Foraging sweep + loot floating text (PR #29) |
| `scenes/zones/zone_action_button/presenters/adventure_presenter.gd` | Adventure Madra badge + affordability gate (PR #29) |
| `scenes/zones/zone_action_button/presenters/training_presenter.gd` | Training sweep + attribute badge + footer tick bar + Madra particles (PR #29) |
| `scenes/zones/zone_action_button/presenters/default_presenter.gd` | No-op fallback for CYCLING / NPC_DIALOGUE (PR #29) |
| `scenes/ui/tick_progress_bar/tick_progress_bar.gd` | Reusable 2px graded progress bar with counter + level-up flash (PR #29) |
| `scenes/zones/zone_action_type_section/zone_action_type_section.gd` | Grouped action section |
| `scenes/zones/glowing_path/glowing_path.gd` | Animated line between unlocked adjacent zones (PR #23) |
| `scenes/zones/locked_zone_overlay/locked_zone_overlay.gd` | Grey hex + lock icon with shake-on-click (PR #23) |
| `scenes/tilemaps/hex_hover_selector.gd` | Animated hex selector ring, shared with adventure map (PR #23) |
| `scenes/atmosphere/atmosphere.gd` | Vignette + mist + motes, shared with adventure map (PR #23) |
| `scripts/resource_definitions/zones/zone_data/zone_data.gd` | Zone data class |
| `scripts/resource_definitions/zones/zone_action_data/zone_action_data.gd` | Base action class |
| `singletons/zone_manager/zone_manager.gd` | Zone state management |
| `singletons/action_manager/action_manager.gd` | Action lifecycle |

## Work Remaining

### Bugs

No known bugs in the Zone system.

### Missing Functionality

- `[MEDIUM]` MERCHANT and ZONE_EVENT action types have no handler in ActionManager — selecting these actions does nothing. (TRAIN_STATS was implemented in PR #29)
- `[MEDIUM]` `ForageActionData.madra_cost_per_second` is defined but never deducted — foraging is free regardless of this value
- `[LOW]` `ZoneProgressionData.forage_active/forage_start_time` saved but not used on load — no offline foraging resume, progress lost on restart

### Content

- `[HIGH]` Only 2 zones exist (Spirit Valley functional, Test Zone empty) — needs more zones with unique actions, foraging resources, and adventure configs
- `[MEDIUM]` No merchant or zone event content authored — action types exist as enums but have no `.tres` data. (Spirit Well training action authored in PR #29; quest system backed by QuestManager in PR #25)
- ~~`[MEDIUM]` Only 1 of 21 forest tile variants is imported~~ _(Done — PR #23: all 23 variants imported and packed into hex_forest_atlas.png)_

### UI

- `[MEDIUM]` No feedback when zones or actions unlock — new zones appear silently on the map. Needs a visual/audio cue to reinforce the unlock chain and make progression feel rewarding
- `[LOW]` Locked zones show no information — clicking a locked tile should show a tooltip with the zone name and unlock requirements, giving the player goals to work toward
- ~~`[LOW]` Unused `PanelContainer` in ZoneView (bottom-left, next to log panel) — no script or children, should be repurposed or removed~~ _(resolved in PR #14)_
- ~~`[LOW]` Zone tilemap viewport may need recentering — currently gets clipped by overlaying UI panels (ZoneInfoPanel, log). Needs evaluation on whether to shift the tilemap view or adjust UI layout~~ _(resolved in PR #14 — SubViewport now fills the full screen with floating UI panels on top)_
- `[LOW]` Add tooltip hint to locked Zones.

### Tech Debt

- `[LOW]` `ZoneCamera2D` map bounds not declared in script — set via scene inspector, not obvious from code
- `[LOW]` `get_unlocked_zones()` in `zone_manager.gd` is a stub returning empty array — never called by anything, can be removed

> **Note:** CyclingActionData modifier fields being unwired is tracked in [CYCLING.md](../cycling/CYCLING.md). AdventureActionData `cooldown_seconds`/`daily_limit` removal is tracked in [ADVENTURING.md](../adventuring/ADVENTURING.md).
