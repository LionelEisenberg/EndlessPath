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
  MainZoneTileMapLayer (HexagonTileMapLayer)
  CharacterBody2D                           — player sprite
  PulseNode (Line2D)                        — pulsing ring on selected tile
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

`ZoneActionButton` renders as a card-style panel. Each card has:
- A colored category dot on the left (green=foraging, red=adventure, teal=cycling)
- Action name (26pt) and description (20pt)
- For ADVENTURE actions: a Madra cost badge showing the icon and cost amount; the badge is **gold** when the player has enough Madra to start (≥50% of zone capacity), **red** when below threshold, and plays a shake-reject animation when the player clicks while below the threshold

### Tile Rendering

| Source ID | Variant | Visual |
|-----------|---------|--------|
| Source 0 (UNLOCKED) | 1 | Unlocked, unselected |
| Source 0 (UNLOCKED) | 2 | Currently selected |
| Source 0 (UNLOCKED) | 3 | Ghost neighbor (transparent) |
| Source 1 (LOCKED) | 0 | Locked zone (greyed) |

Camera (`zone_camera_2d.gd`) clamps position to map bounds each frame.

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
| `MERCHANT` | No | No handler |
| `TRAIN_STATS` | No | No handler |
| `ZONE_EVENT` | No | No handler |
| `QUEST_GIVER` | No | No handler |

### Action Subclasses

| Class | Key Fields |
|-------|------------|
| `ForageActionData` | `loot_table`, `madra_cost_per_second`, `foraging_interval_in_sec` |
| `CyclingActionData` | `madra_multiplier`, `cycle_duration_modifier`, `xp_multiplier`, `madra_cost_per_cycle` |
| `AdventureActionData` | `adventure_data`, `time_limit_seconds`, `gold_multiplier`, `stamina_regen_modifier` |
| `NpcDialogueActionData` | `dialogue_timeline_name` |

### ZoneProgressionData (per-zone save data)
| Field | Type | Description |
|-------|------|-------------|
| `action_completion_count` | `Dictionary[String, int]` | action_id -> completions |
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
1. Player clicks "Talk to the Wisened Dirt Eel" (NPC_DIALOGUE, max_completions=1)
2. Dialogic plays "spirit_valley" timeline
3. Dialogue ends → stop_action() → _process_completion_effects(true)
4. TriggerEventEffectData.process() → EventManager.trigger_event("initial_spirit_valley_dialogue_1")
5. EventManager emits event_triggered → UnlockManager._evaluate_all_conditions()
6. "initial_spirit_valley_dialogue_1" condition evaluates true → condition_unlocked signal
7. ZoneTilemap refreshes → Test Zone tile appears (was locked)
8. ZoneInfoPanel rebuilds → "Mountain Top Cycling" and "Spring Forest Foraging" appear
9. AwardItemEffectData gives the player a Dagger
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
- Actions:
  1. **Basic Room Cycling** — CyclingActionData, no conditions
  2. **Wisened Dirt Eel Dialogue** — NpcDialogueActionData, max_completions=1, awards Dagger + triggers unlock event
  3. **Mountain Top Cycling** — CyclingActionData, madra_multiplier=2.0, requires dialogue event
  4. **Spring Forest Foraging** — ForageActionData, loot: Dewdrop Tear (1-5) + Spirit Fern (2-6), requires dialogue event
  5. **Test Adventure** — AdventureActionData, 300s time limit, awards 5 Madra on success

### Test Zone (`zone_id: "TestZone"`)
- Location: `(0, 1)`, no actions
- Requires: `initial_spirit_valley_dialogue_1` event

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
| `scenes/zones/zone_action_button/zone_action_button.gd` | Individual action button (card style, Madra cost badge) |
| `scenes/zones/zone_action_type_section/zone_action_type_section.gd` | Grouped action section |
| `scripts/resource_definitions/zones/zone_data/zone_data.gd` | Zone data class |
| `scripts/resource_definitions/zones/zone_action_data/zone_action_data.gd` | Base action class |
| `singletons/zone_manager/zone_manager.gd` | Zone state management |
| `singletons/action_manager/action_manager.gd` | Action lifecycle |

## Work Remaining

### Bugs

No known bugs in the Zone system.

### Missing Functionality

- `[MEDIUM]` MERCHANT, TRAIN_STATS, ZONE_EVENT, QUEST_GIVER action types have no handler in ActionManager — selecting these actions does nothing
- `[MEDIUM]` `ForageActionData.madra_cost_per_second` is defined but never deducted — foraging is free regardless of this value
- `[LOW]` `ZoneProgressionData.forage_active/forage_start_time` saved but not used on load — no offline foraging resume, progress lost on restart

### Content

- `[HIGH]` Only 2 zones exist (Spirit Valley functional, Test Zone empty) — needs more zones with unique actions, foraging resources, and adventure configs
- `[MEDIUM]` No merchant, training, zone event, or quest giver content authored — action types exist as enums but have no `.tres` data

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
