# Zone View, Map-First (Lacquer and Brass) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the zone view as the approved map-first v2 design in the Lacquer and brass look: a zoom-2 hex map with fog tiers, map plates and popovers, a cultivator cabinet, a Goals board shared with the adventure view, a five-line log, a zone chest with a Now strip and a scrolling activity list, a dock, and the "always in an idle action" rule.

**Architecture:** Bottom-up. Data and save fields first, then pure helpers and getters, then the `ActionManager` resolution rule, then a lacquer theme with three small reusable components, then each panel as its own scene (tested in isolation), then the map in three layers (rendering, markers, interaction), then the swap in `main_game.tscn`. Every panel is a `.tscn` whose script only sets data; textures come from the kit and are placed at the kit's screen positions.

**Tech Stack:** Godot 4.7.2, GDScript, GUT 9.7.1.

**Spec:** [docs/superpowers/specs/2026-10-21-zone-view-map-first-design.md](../specs/2026-10-21-zone-view-map-first-design.md). **Art kit:** [docs/superpowers/specs/2026-10-21-zone-view-lacquer-kit.md](../specs/2026-10-21-zone-view-lacquer-kit.md) (every texture, colour, font size and screen position). Read both before any task. The mock-up [zone-view-map-first-mockup.html](../mockups/zone-view-map-first-mockup.html) is the visual reference; it opens in a browser from the repo.

## Global Constraints

- **Project rules (CLAUDE.md):** UI nodes live in `.tscn` scenes, scripts only set data (memory rule: never create UI nodes in code). Label theme variants before inline overrides. Explicit types everywhere, `->` return types, `##` doc comments on public functions, `_` prefix on private ones, `%UniqueName` node references, `#-----` section headers, `Log.*` for diagnostics, no `print()`.
- **GodotPrompter:** before writing Godot code, invoke the matching `godot-prompter:*` skill (`godot-ui` for panels, `hud-system` for the cabinet/dock/log, `2d-essentials` and `camera-system` for the map, `state-machine` for the popover state, `save-load` and `resource-pattern` for data, `godot-testing` for tests). Follow CLAUDE.md where a skill disagrees.
- **Never modify `addons/`.**
- **Art:** textures come from `assets/ui/lacquer/` (screen space, drawn at 2x, shown at file size), `assets/ui/lacquer/map/` (map space, native size, doubled by the camera's zoom 2) and `assets/ui/lacquer/icons/` (16x16 placeholders, shown at 2x). The kit doc's "Godot build notes" and §0 (revision 2) override older rows. Big pieces and small pieces already carry their hard shadow (4 px `#050707` or 2 px `#150909`) baked into the file, so a file is 2 or 4 px larger than the kit's rect: place it at the kit's top-left. The user's `gold_icon`, `star_icon`, `combat_icon` and `character_icon` (64 px files, 16 art px) show at 32x32; `inventory_icon` (16 px) shows at 32x32. Any new image an agent makes ends in `_ai`. Never edit the user's files (hex tiles, character sheet, icons without `_ai`, fonts).
- **Look:** no glow, halo, blur, gradient, opacity fade, translucent panel, rounded pill or tint. Show and hide outright; animate in whole frames or 2 px steps. Nearest filtering everywhere. Jade only for progress fills.
- **Fonts:** Yatra One (`res://assets/fonts/YatraOne-Regular.ttf`) for painted titles, BM Euljiro (`res://assets/fonts/BMEULJIROTTF.ttf`) for everything else. Nothing under 13 px.
- **Copy (exact):** "Resumed <action name>"; "Travelled to <zone name> · resumed <action name>"; "Travelled to <zone name>"; "Started <action name>"; "Nothing to do here yet."; "Needs <threshold> Madra · you have <madra>"; "ready in ~<n> s"; "train or cycle to fill"; "Ready · carries up to <capacity> Madra · <minutes> min run"; "Open · <n> activities"; "Click to travel"; "Raise Core Density to 100". (The spec's "the" before action names is dropped: action names are proper names.)
- **Tests:** GUT tests call production code (no mirror tests, `docs/testing/TESTING.md`). Never instantiate `main_game.tscn` in a test (its SaveTimer writes `user://save.tres`). Tests that touch zones or actions swap in a fresh save first: `PersistenceManager.save_game_data = SaveGameData.new(); PersistenceManager.save_data_reset.emit()`, and end with `while ActionManager.get_current_action() != null: ActionManager.stop_action()`.
- **Save safety:** GUT and every run load the developer's real `user://save.tres`. Never make `SaveGameData.verify()` stricter (a failed verify wipes the save). Before running the game or a movie capture, copy `%APPDATA%/Godot/app_userdata/EndlessPath/save.tres` aside and compare its sha256 afterwards.
- **Commands** (repo root):
  - Suite: `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit` (618 passing before this plan; a green run still prints 1 warning, 24 orphans, `event_progression on Nil` errors and leak warnings).
  - One file: `... -s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/unit/test_x.gd -gexit`.
  - After adding a `class_name` script or new assets: `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --import`, then check `git diff project.godot` shows no emptied `[dialogic]` keys.
  - Visual check of one scene (safe, no SaveTimer): `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --path . --write-movie <scratch>/shot.png --fixed-fps 30 --quit-after 8 res://<scene>.tscn`, then look at the last frame.
- **Git:** commit each task when its tests pass, staging only that task's files, with a conventional message ending `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never merge, never push.

## Review Focus

1. **A real save with stale data.** A save standing in `TestZone`, a `last_idle_action_id` naming an action that is now locked or gone, and a save from before this change (no new fields) must all load, keep the save, and resolve to an available idle action or none. Tests: Task 1 (migration, old-save defaults) and Task 3 (stale last idle id).
2. **Interrupting a walk.** Clicking a second zone, starting cycling, or an adventure starting while the character walks must leave exactly one current zone and one running action, and the zone changes only on arrival. Test: Task 13 (`test_second_click_during_walk_retargets`).
3. **Zoom and pan away from the default.** At zoom 1.0 and 1.5, and panned to the clamp edge, the fog still covers the screen and plates, glyphs and brackets stay on their hexes. Tests: Task 11 (fog covers the clamp bounds plus the half viewport at zoom 1.0), Task 12 (plate positions at zoom 1.0).
4. **Long text.** A long zone name, action name, quest step or log line must ellipsize inside its slot, never widen a panel. Tests: Task 6 (long step), Task 7 (long log line), Task 9 (long action name).
5. **Dev toggles and save resets mid-session.** Turning the demo zones off while one of their popovers is pinned, or resetting the save while an idle action runs, must leave no orphan popover, plate or timer. Tests: Task 12 and Task 13 (`test_hiding_demo_zones_closes_their_popover`), Task 3 (`test_save_reset_stops_and_resolves_once`).

---

## File map

| Area | Create | Modify | Delete (Task 14) |
|---|---|---|---|
| Data | `resources/zones/dev/*.tres` | `zone_data.gd`, `zone_progression_data.gd`, `save_game_data.gd`, `persistence_manager.gd`, `zone_manager.gd`, `test_zone.tres`, `spirit_valley_zone.tres`, action `.tres` icons | |
| Logic | `scripts/utils/zone_action_groups.gd`, `scripts/utils/zone_map_math.gd`, `scripts/ui/map_popover_state.gd` | `cultivation_manager.gd`, `resource_manager.gd`, `award_resource_effect_data.gd`, `training_action_data.gd`, `unlock_condition_data.gd`, `log_manager.gd`, `action_manager.gd`, `hex_forest_atlas.gd` | |
| Theme | `assets/themes/lacquer/lacquer_theme.tres`, `assets/styleboxes/lacquer/*.tres`, `scenes/common/lacquer/*`, `scripts/utils/lacquer_text.gd` | `theme_constants.gd`, `docs/UI_STYLING.md` | |
| Panels | `scenes/zones/cultivator_plate/`, `scenes/ui/goals_panel/`, `scenes/ui/dock/`, `scenes/zones/zone_panel/` | `scenes/ui/log_window/*`, `scenes/zones/zone_action_button/**` | `zone_resource_panel/` (after moving `system_menu/`), `zone_info_panel/`, `zone_header/`, `zone_action_type_section/`, `scenes/ui/quest_window/`, `scenes/ui/toolbar/` |
| Map | `scenes/tilemaps/fog_tileset.tres`, `scenes/zones/map_markers/*`, `scenes/zones/zone_route/*` | `zone_tilemap.gd/.tscn`, `locked_zone_overlay.*`, `hex_hover_selector.gd` | |
| Wiring | | `main_game.tscn`, `main_view.gd`, view states, `zone_transition.gd`, `dev_panel.*`, `project.godot` (`toggle_log`) | |

---

### Task 1: Zone, save and map-state data

**Files:**
- Modify: `scripts/resource_definitions/zones/zone_data/zone_data.gd`, `singletons/persistence_manager/zone_progression_data.gd`, `singletons/persistence_manager/save_game_data.gd`, `singletons/persistence_manager/persistence_manager.gd`, `singletons/zone_manager/zone_manager.gd`, `resources/zones/test_zone/*.tres` (the TestZone `ZoneData`), `resources/zones/spirit_valley_zone/spirit_valley_zone.tres`, every action `.tres` under `resources/zones/**/zone_actions/`
- Create: `resources/zones/dev/advancement_zone_demo.tres`, `resources/zones/dev/uncharted_zone_demo.tres`, `resources/zones/dev/dev_never_unlocked_condition.tres`
- Test: `tests/unit/test_save_migration.gd`, `tests/unit/test_zone_map_state.gd`, `tests/unit/test_seen_actions.gd`, extend `tests/unit/test_zone_progression_data.gd`

**Interfaces:**
- Produces:
  - `ZoneData`: `@export var hidden_on_map: bool = false`, `@export var chart_conditions: Array[UnlockConditionData] = []`, `@export var blocker_short_text: String = ""`, `@export_multiline var requirement_text: String = ""`, `@export var requirement_action_id: String = ""`.
  - `ZoneProgressionData.last_idle_action_id: String = ""`.
  - `SaveGameData.seen_action_ids: Array[String] = []`, `SaveGameData.seen_actions_initialized: bool = false`, `SaveGameData.migrate() -> void` (moves `current_selected_zone_id` through `const ZONE_ID_MIGRATIONS: Dictionary = {"TestZone": "SpiritValley"}`); `reset()` resets the new fields.
  - `ZoneManager`: `enum ZoneMapState { CURRENT, OPEN, LOCKED, UNCHARTED }`; `signal map_zones_changed()`; `signal action_focus_requested(action_id: String)`; `get_map_zones() -> Array[ZoneData]`; `get_zone_map_state(zone_data: ZoneData) -> ZoneMapState`; `is_zone_charted(zone_data: ZoneData) -> bool`; `set_demo_zones_visible(visible: bool) -> void`; `set_hidden_zones_visible(visible: bool) -> void`; `get_last_idle_action_id(zone_id: String) -> String`; `set_last_idle_action_id(zone_id: String, action_id: String) -> void`; `mark_action_seen(action_id: String) -> void`; `is_action_seen(action_id: String) -> bool`; `request_action_focus(action_id: String) -> void` (emits `action_focus_requested`).

- [ ] **Step 1: Write the failing tests**

`test_save_migration.gd`: `test_test_zone_save_moves_to_spirit_valley` (a `SaveGameData` with `current_selected_zone_id = "TestZone"`, `migrate()`, expect `"SpiritValley"`); `test_other_zone_is_unchanged`; `test_empty_zone_is_unchanged`; `test_old_save_loads_new_field_defaults` (hand-written `.tres` with only `gold = 42.0`, as `test_merchant_data.gd:96` does; expect `seen_action_ids == []`, `seen_actions_initialized == false`).

`test_zone_progression_data.gd`: `test_last_idle_action_id_round_trips` (save/load through `user://`, as lines 12-24 do).

`test_zone_map_state.gd` (fresh-save fixture; zones built in code as `ZoneData.new()` with conditions built as `UnlockConditionData` and latched with `UnlockManager.force_unlock_condition`):
- `test_current_zone_is_current`, `test_unlocked_other_zone_is_open`, `test_charted_but_not_unlocked_zone_is_locked`, `test_unchartered_zone_is_uncharted` (chart condition not latched wins over the unlock conditions);
- `test_map_zones_skip_hidden_test_zone` (`get_map_zones()` ids == `["SpiritValley"]`);
- `test_hidden_zones_toggle_includes_test_zone`;
- `test_demo_toggle_adds_two_zones_and_emits` (`watch_signals(ZoneManager)`; ids gain `AdvancementZoneDemo`, `UnchartedZoneDemo`; `map_zones_changed` emitted once; turning it off removes them);
- `test_demo_zones_states` (Advancement = LOCKED, Uncharted = UNCHARTED);
- `test_last_idle_action_id_is_per_zone`;
- `test_request_action_focus_emits` (parameters `["shallow_woods_adventure_action"]`).

`test_seen_actions.gd`: `test_mark_then_is_seen`; `test_mark_twice_stores_once`; `test_first_init_marks_available_actions_seen` (fresh save + reset: `wilderness_cycling_action` is seen, `seen_actions_initialized` is true); `test_init_runs_once` (unlock foraging after init: foraging is not seen).

- [ ] **Step 2: Run them, expect failures** (missing fields and methods).

- [ ] **Step 3: Implement**
  - Fields as listed. `SaveGameData.migrate()`; `PersistenceManager._ready()` calls `save_game_data.migrate()` after `load_data()` and before `verify()`.
  - `ZoneManager`: demo zones are loaded from `const DEMO_ZONE_PATHS: Array[String]` and never enter `zone_data_list.tres`; `get_map_zones()` keeps list order, skips `hidden_on_map` unless hidden zones are on, then appends demo zones when on. `get_zone_map_state`: not charted (chart conditions not latched, via `UnlockManager.are_unlock_conditions_met`) → UNCHARTED; zone unlock conditions not latched → LOCKED; id == current → CURRENT; else OPEN. On `_initialize_from_save`, when `seen_actions_initialized` is false, mark every action in `get_available_actions(zone.zone_id)` of every zone seen and set the flag.
  - Data: TestZone `hidden_on_map = true`. Spirit Valley `tile_variant_index = 6`. `dev_never_unlocked_condition.tres`: `EVENT_TRIGGERED`, id and target `dev_demo_never_unlocked`, **not** added to `unlock_condition_list.tres`. Advancement demo: id `AdvancementZoneDemo`, name "Advancement Zone", `tilemap_location (0, -1)`, `tile_variant_index 20` (Stones), unlock condition = the never condition, `blocker_short_text "Tribulation Guardian"`, `requirement_text "Defeat the Tribulation Guardian in The Shallow Woods"`, `requirement_action_id "shallow_woods_adventure_action"`. Uncharted demo: id `UnchartedZoneDemo`, name "Uncharted", `tilemap_location (0, -2)`, `tile_variant_index 8` (Mountains2), chart condition = the never condition, `blocker_short_text "After the Tribulation"`, `requirement_text "Revealed after the Tribulation."`.
  - Icons: set `ZoneActionData.icon` on every action: cycling `icons/ic_cycle_ai.png`, foraging `icons/ic_forage_ai.png`, Aura Well `icons/ic_well_ai.png`, merchant `icons/ic_merchant_ai.png`, dialogues `icons/ic_story_ai.png`, adventure the user's `assets/sprites/ui/stat_icons/combat_icon.png`.

- [ ] **Step 4: Run the three new files and the suite; expect all green.**

- [ ] **Step 5: Commit** `feat(zones): add map state, demo zones and save fields for the map-first view`.

---

### Task 2: Getters and helpers the panels read

**Files:**
- Modify: `singletons/cultivation_manager/cultivation_manager.gd`, `singletons/resource_manager/resource_manager.gd`, `scripts/resource_definitions/effects/award_resource_effect_data.gd`, `resources/zones/spirit_valley_zone/zone_actions/aura_well_madra_trickle_effect.tres`, `scripts/resource_definitions/zones/zone_action_data/training_action_data/training_action_data.gd`, `scripts/resource_definitions/unlocks/unlock_condition_data.gd`, `singletons/log_manager/log_manager.gd`, `scenes/cycling/**/cycling_resource_panel.gd` (one call site)
- Create: `scripts/utils/zone_action_groups.gd`
- Test: `tests/unit/test_cultivation_getters.gd`, `tests/unit/test_quiet_madra.gd`, `tests/unit/test_training_action_helpers.gd`, `tests/unit/test_unlock_condition_progress.gd`, `tests/unit/test_zone_action_groups.gd`, `tests/unit/test_log_manager_history.gd`

**Interfaces:**
- Produces:
  - `CultivationManager.BREAKTHROUGH_LEVEL: int = 100`; `get_max_madra() -> float` (replaces every outside call of `_get_current_stage_resource().get_max_madra(...)`).
  - `ResourceManager.add_madra(amount: float, quiet: bool = false) -> void`: logs "Gained N Madra" only when not quiet and the amount actually added (after the cap) is ≥ 1. `award_resource(type, amount, quiet: bool = false)`. `AwardResourceEffectData.quiet: bool = false`, true on the Aura Well trickle.
  - `TrainingActionData.get_madra_per_second() -> float`, `get_ticks_in_level(accumulated_ticks: int) -> int`, `get_ticks_for_next_level(accumulated_ticks: int) -> int`.
  - `UnlockConditionData.is_measurable() -> bool` (RESOURCE_AMOUNT or CULTIVATION_LEVEL), `get_current_value() -> float` (same source as `evaluate()`), `get_target_value() -> float`.
  - `ZoneActionGroups` (no `extends`, statics only): `enum Group { TALK, CULTIVATE, GATHER, VENTURE, VISIT }`; `group_of(action_type: ZoneActionData.ActionType) -> Group` (TALK = NPC_DIALOGUE; CULTIVATE = CYCLING, TRAIN_STATS; GATHER = FORAGE; VENTURE = ADVENTURE; VISIT = MERCHANT, ZONE_EVENT); `label(group: Group) -> String` ("Talk", "Cultivate", "Gather", "Venture", "Visit"); `sort_actions(actions: Array[ZoneActionData]) -> Array[ZoneActionData]` (stable: by group, input order within a group); `mode_tag(action: ZoneActionData) -> String` ("IDLE" for FORAGE/TRAIN_STATS, "ACTIVE" for CYCLING/ADVENTURE, "SHOP" for MERCHANT, "STORY" for NPC_DIALOGUE/ZONE_EVENT).
  - `LogManager.HISTORY_LIMIT: int = 200`; `get_history() -> Array[String]` (oldest first; `log_message` appends and trims).

- [ ] **Step 1: Write the failing tests** (swap the managers' save as the existing unit tests do; call the real methods):
  - `test_max_madra_follows_level` (level 32 → 100 + 5 × 32 = 260.0).
  - `test_quiet_add_logs_nothing`, `test_loud_add_logs_gained_line`, `test_capped_add_logs_nothing` (Madra at max, add 5 → no `message_logged`), `test_quiet_add_still_adds` (Madra rises by the amount).
  - `test_madra_per_second_sums_madra_effects` (effects 1.5 MADRA + 2 GOLD, interval 1.0 → 1.5; interval 0.5 → 3.0), `test_ticks_in_level` and `test_ticks_for_next_level` with `ticks_per_level [3, 5]` at 0, 2, 3, 7 ticks.
  - `test_resource_amount_is_measurable` (current 25, target 100 on a fresh save), `test_cultivation_level_is_measurable`, `test_event_condition_is_not_measurable`.
  - `test_sort_puts_talk_first_and_keeps_order` (input in Spirit Valley's `all_actions` order → cycling, Aura Well before foraging; dialogues first), `test_mode_tags`, `test_labels`.
  - `test_history_keeps_order`, `test_history_trims_to_limit`.

- [ ] **Step 2: Run, expect failures.**
- [ ] **Step 3: Implement** as listed. `test_training_flow.gd` must stay green (the quiet flag must not change what is added).
- [ ] **Step 4: Run the new files and the suite; green.**
- [ ] **Step 5: Commit** `feat(core): add getters, quiet Madra and action groups for the zone view`.

---

### Task 3: Always in an idle action (`ActionManager`)

**Files:**
- Modify: `singletons/action_manager/action_manager.gd`, `tests/integration/test_merchant_shop_flow.gd`, `tests/integration/test_aura_well_discovery_unlock.gd` (add `after_each` that stops actions)
- Test: `tests/integration/test_idle_action_resolution.gd`

**Interfaces:**
- Consumes: Task 1 (`get/set_last_idle_action_id`, `mark_action_seen`), Task 2 (`ZoneActionGroups.sort_actions`, `get_madra_per_second`).
- Produces: `ActionManager.resolve_idle_action(zone_id: String) -> ZoneActionData` (saved last idle action if it is still in `get_available_actions(zone_id)` and is idle; else the first idle action in `ZoneActionGroups.sort_actions(get_available_actions(zone_id))`; else null); `ActionManager.get_current_madra_per_second() -> float` (0 unless a `TrainingActionData` runs).

Rules (spec, Behaviour › Idle action resolution, and Implementation notes › ActionManager):
- Starting an idle action writes it as the zone's last idle action and marks it seen. Selecting any action marks it seen.
- `select_action(adventure)` checks `ResourceManager.can_start_adventure()` **before** stopping anything; when unaffordable it logs nothing new and leaves the current action running.
- After any **non-idle** action stops (cycling, adventure win or loss, dialogue, merchant, zone event), resolve and start the zone's idle action and log "Resumed <name>". Stopping an idle action resumes nothing. This replaces the merchant-only `_idle_action_to_resume`.
- `_on_zone_changed(zone)`: remember the last resolved zone id. Same zone and an idle action of that zone already running → do nothing (the load emits `zone_changed` twice). Otherwise stop the current action and resolve: log "Travelled to <zone> · resumed <name>" or "Travelled to <zone>" when the zone differs from the previous one, else "Resumed <name>" (nothing when nothing resumes).
- On `UnlockManager.condition_unlocked(id)` with a non-empty id and no current action: resolve; if an idle action results, start it and log "Started <name>".

- [ ] **Step 1: Write the failing tests** (fresh-save fixture; unlock foraging with `EventManager.trigger_event("q_fill_core_completed")`, the Aura Well with `EventManager.trigger_event("aura_well_discovered")`):
  - `test_resolve_prefers_saved_last_idle`, `test_resolve_falls_back_to_first_in_group_order` (both unlocked, none saved → Aura Well), `test_resolve_skips_stale_saved_id` (saved id of a locked action → first available), `test_resolve_returns_null_with_nothing_idle`.
  - `test_cycling_stop_resumes_idle`, `test_adventure_stop_win_resumes_idle`, `test_adventure_stop_loss_resumes_idle` (`stop_action(false)`), `test_dialogue_end_resumes_idle` (select a dialogue action, then `DialogueManager.dialogue_ended.emit()` if the timeline cannot run headless), `test_merchant_close_resumes_idle`.
  - `test_stopping_idle_resumes_nothing`.
  - `test_rejected_adventure_keeps_idle_running` (fresh save Madra 25 < 50).
  - `test_zone_change_resolves_destination` and `test_zone_change_with_no_idle_leaves_nothing`; `test_same_zone_change_does_not_restart` (completion count unchanged); `test_travel_logs_merged_line` (`watch_signals(LogManager)`, parameters `["Travelled to Test Zone"]` when Test Zone has nothing; with a fixture zone that has an idle action, the merged line).
  - `test_first_idle_unlock_auto_starts` and `test_empty_condition_id_does_not_start`.
  - `test_save_reset_stops_and_resolves_once` (Review Focus 5: with the Aura Well running, a reset to a fresh save leaves nothing running and `action_timer` stopped).
  - `test_madra_per_second_tracks_current_action` (Aura Well → 1.5; foraging → 0).
  - Update `test_merchant_shop_flow.gd`: `test_shop_resumes_the_idle_action_it_replaced` unlocks foraging in its own body; add `test_zone_change_during_shop_resumes_destination_idle`. Keep lines 72-82 green.

- [ ] **Step 2: Run, expect failures.**
- [ ] **Step 3: Implement.** Keep the side effect noted in the spec (every stop counts a completion).
- [ ] **Step 4: Run the new file, the merchant flow, the training flow, the adventure end flow and the suite; green.**
- [ ] **Step 5: Commit** `feat(actions): resume the zone's idle action after every session action`.

---

### Task 4: Lacquer theme and shared pieces

**Files:**
- Create: `assets/themes/lacquer/lacquer_theme.tres`, `assets/styleboxes/lacquer/frame_brass.tres`, `assets/styleboxes/lacquer/frame_hover.tres`, `assets/styleboxes/lacquer/rail_thumb.tres`, `assets/styleboxes/lacquer/token.tres`, `scenes/common/lacquer/lacquer_strip_rect.gd`, `scenes/common/lacquer/lacquer_rod.tscn` + `.gd`, `scenes/common/lacquer/lacquer_frame_overlay.tscn` + `.gd`, `scripts/utils/lacquer_text.gd`
- Modify: `scripts/utils/theme_constants.gd`, `docs/UI_STYLING.md`
- Test: `tests/unit/test_lacquer_pieces.gd`

**Interfaces:**
- Produces:
  - Theme variants (all `base_type = &"Label"`, colours and sizes from kit §2–3, shadows as `font_shadow_color #150909` with offset 2, 2 where the kit gives one): `LabelLacquerZoneName` (Yatra 30 brass), `LabelLacquerPanelTitle` (Yatra 22 brass), `LabelLacquerSection` (Yatra 20 brass), `LabelLacquerStage` (Yatra 21 cream), `LabelLacquerBig` (30 cream), `LabelLacquerGold` (22 cream), `LabelLacquerName` (17 cream), `LabelLacquerRate` (17 tan), `LabelLacquerNowName` (18 cream), `LabelLacquerNowRate` (16 cream), `LabelLacquerDetail` (15 tan), `LabelLacquerTag` (13 tan), `LabelLacquerSeal` (13 cream), `LabelLacquerLegend` (14 ink), `LabelLacquerDock` (14 cream), `LabelLacquerHotkey` (14 tan), `LabelLacquerLore` (16 cream), `LabelLacquerPlateName` (16 cream), `LabelLacquerPlateLine` (14 cream), `LabelLacquerPopoverTitle` (18 cream), `LabelLacquerPopoverBody` (15 cream), `LabelLacquerFloater` (16 cream, 2 px ink outline). A matching `RichTextLabel` variant `RichTextLacquer` (Euljiro, 15, tan) for the few decimal lines.
  - `ThemeConstants.LACQUER_INK`, `LACQUER_BRASS`, `LACQUER_CREAM`, `LACQUER_TAN`, `LACQUER_DIM`, `LACQUER_MADRA`, `LACQUER_VERMILION` (`Color`, kit §2) for colours set from code.
  - `LacquerStripRect extends TextureRect`: `@export var strip: Texture2D`, `@export var frame_size: Vector2i`; `set_frame(column: int, row: int = 0) -> void`; `get_frame() -> Vector2i`. Draws one frame of a strip through its own `AtlasTexture`.
  - `LacquerRod extends Control`: `@export var empty_texture`, `full_texture`, `end_texture: Texture2D`, `@export var steps: int`; `set_fraction(fraction: float) -> void` (k = round(clamp(f, 0, 1) × steps); full clipped to width 2 + 2k; end cap at x = 2k when k ≥ 2, kit §4.3); `get_step() -> int`.
  - `LacquerFrameOverlay extends Panel` (style `frame_brass` or `frame_hover`, `draw_center = false`, mouse ignored): `flash(times: int) -> void` (300 ms shown, 300 ms hidden, `times` times, outright), `is_flashing() -> bool`.
  - `LacquerText` (statics): `rate(value: float) -> String` ("+1.5", "+2", "+0.5"); `decimal_bbcode(text: String) -> String` (wraps each `.` between digits in `[font=res://assets/fonts/YatraOne-Regular.ttf].[/font]`, kit §3 glyph gaps).

- [ ] **Step 1: Write the failing tests:** `test_strip_rect_selects_frame` (frame (3, 1) of 80x80 → region `Rect2(240, 80, 80, 80)`); `test_rod_steps` (steps 152: f 0 → k 0, clip width 2, end hidden; f 0.5 → k 76, width 154, end at x 152 and shown); `test_rod_clamps`; `test_flash_toggles_and_ends_hidden` (await the tween; hidden at the end); `test_rate_format`; `test_decimal_bbcode_wraps_only_between_digits` ("+1.5 Madra / s" wraps one dot; "Lv 1 → 2." wraps none); `test_theme_has_variants` (load the theme; each variant listed above exists with the expected font size; `LabelLacquerZoneName` uses Yatra One).
- [ ] **Step 2: Run, expect failures.**
- [ ] **Step 3: Implement**; StyleBoxTexture margins: frame_brass 8, frame_hover 4, rail_thumb top/bottom 4 (kit §4.2, §4.4), token 6 left/top and 8 right/bottom (its 2 px shadow is baked in; kit Godot notes). Add a "Lacquer theme" section to `docs/UI_STYLING.md` listing the variants and the rule that zone-view panels set `theme = lacquer_theme.tres` on their root.
- [ ] **Step 4: Run; green. `--import` once for the new class names.**
- [ ] **Step 5: Commit** `feat(ui): add the lacquer theme, strip, rod and frame pieces`.

---

### Task 5: Cultivator cabinet (`CultivatorPlate`)

**Files:**
- Create: `scenes/zones/cultivator_plate/cultivator_plate.tscn` + `.gd`
- Test: `tests/integration/test_cultivator_plate.gd`

**Interfaces:**
- Consumes: Task 2 (`get_max_madra`, `BREAKTHROUGH_LEVEL`), Task 3 (`get_current_madra_per_second`), Task 4.
- Produces: `class_name CultivatorPlate extends Control` (root 440x252 at its parent's (24, 24), `mouse_filter = STOP`, `theme = lacquer_theme`); `get_madra_orb_global_position() -> Vector2` (centre of the Madra orb).

Layout is kit §5.1 (positions relative to the cabinet's top-left = screen − (24, 24)). Madra orb frame = round(Madra / max × 32); core orb column = round(min(level, 100) / 100 × 16), row = swirl phase stepped every 1.5 s by a `Timer` in the scene; beads row = round(xp / need × 18). The rate label shows `LacquerText.rate(rate) + " / s"` only while `get_current_madra_per_second() > 0`. Listens to `madra_changed`, `core_density_xp_updated`, `core_density_level_updated`, `advancement_stage_changed`, `gold_changed`, `ActionManager.current_action_changed`, and reads everything once in `_ready`.

- [ ] **Step 1: Write the failing tests** (fresh-save fixture, scene via `add_child_autofree`): `test_shows_madra_over_max` ("25" and "/ 100" on a fresh save); `test_madra_orb_frame_follows_ratio` (Madra 50 of 100 → frame 16); `test_core_orb_column_follows_level` (level 32 → column 5); `test_beads_follow_xp`; `test_level_and_stage_text` ("Level 0", "Foundation"); `test_gold_text`; `test_rate_hidden_without_madra_action`; `test_rate_shows_while_aura_well_runs` (unlock and select the Aura Well → "+1.5 / s" visible; select cycling → hidden); `test_madra_orb_position_is_orb_centre` (within the orb's rect).
- [ ] **Step 2: Run, expect failures.**
- [ ] **Step 3: Build the scene** from kit textures (`lacquer_cult_ai`, orb and bead strips, `lacquer_line_ai`, the user's `gold_icon` at 32x32). Core Density level 0 shows the dormant-core frame (column 0) and the script.
- [ ] **Step 4: Run; green. Capture the scene alone (movie command) and compare with the mock's cabinet; fix placement.**
- [ ] **Step 5: Commit** `feat(zones): add the lacquer cultivator cabinet`.

---

### Task 6: Goals board (`GoalsPanel`)

**Files:**
- Create: `scenes/ui/goals_panel/goals_panel.tscn` + `.gd`
- Test: `tests/integration/test_goals_panel.gd`

**Interfaces:**
- Consumes: Task 2 (`is_measurable`, `get_current_value`, `get_target_value`, `BREAKTHROUGH_LEVEL`), Task 4.
- Produces: `class_name GoalsPanel extends Control` (440x220 board image, body from y 20, `mouse_filter = STOP`, lacquer theme); `refresh() -> void`.

Layout is kit §5.2 (relative to the board's top-left (24, 272)). Row 1: the first active quest (`QuestManager.get_active_quest_ids()[0]`), its `quest_name` and current step `description`, and `current / target` on the name row only when every completion condition of the step is measurable and there is at least one (use the first). Row 2: "Breakthrough", "Raise Core Density to 100", rod (`steps 138`), `level / 100`. With no active quest, hide row 1 and the divider and move row 2 up 70 px. Listens to `QuestManager.quest_started`, `quest_step_advanced`, `quest_completed`, `PersistenceManager.save_data_reset`, `CultivationManager.core_density_level_updated`, `ResourceManager.madra_changed` (for a Madra figure). Step text ellipsizes in 358 px.

- [ ] **Step 1: Write the failing tests** (swap the save and reload the quest catalog as `test_beat_3b_merchant_unlock.gd:19` does): `test_no_quest_shows_milestone_only` (row 1 hidden, milestone row at its moved-up y); `test_quest_row_shows_current_step` (start `q_fill_core` → its name and "Fill your Madra by cycling"); `test_measurable_step_shows_figure` ("25 / 100"); `test_figure_follows_madra` (set Madra 60 → "60 / 100"); `test_event_step_has_no_figure` (`q_first_steps`); `test_refreshes_on_step_advance`; `test_refreshes_on_save_reset`; `test_milestone_figure_and_rod` (level 32 → "32 / 100", rod step round(0.32 × 138)); `test_long_step_text_does_not_widen_board` (Review Focus 4: a 300-character description leaves the panel 440 wide).
- [ ] **Step 2: Run, expect failures.**
- [ ] **Step 3: Build the scene and script.**
- [ ] **Step 4: Run; green; capture alone and compare with the mock.**
- [ ] **Step 5: Commit** `feat(ui): add the Goals board`.

---

### Task 7: Log board and full log (`LogWindow`, `L`)

**Files:**
- Modify: `scenes/ui/log_window/log_window.tscn` + `.gd`, `project.godot` (`toggle_log` on L: `physical_keycode 76`, `unicode 108`, in the format of `open_character`), `scenes/ui/main_view/main_view.gd` (`_unhandled_input` handles `toggle_log` before delegating, so it works in the zone and adventure views)
- Test: `tests/integration/test_log_board.gd`

**Interfaces:**
- Consumes: Task 2 (`LogManager.get_history`), Task 4.
- Produces: `LogWindow` keeps `class_name LogWindow`; root becomes a `Control` 440 wide whose height follows its line count (`mouse_filter = STOP`). `enum Tone { BRASS, CREAM, MADRA, TAN }`; `static tone_for(bbcode: String) -> Tone` (first `[color=…]`: gold/yellow/orange/`#D4A84A`-like → BRASS; cyan/blue/`#…` blues → MADRA; green/lime/white → CREAM; anything else or none → TAN); `toggle_full_log() -> void`; `is_full_log_open() -> bool`. `LogManager.toggle_window()` opens and closes the full log.

Compact board per kit §5.3 and §0: `lacquer_log<n>_ai` for n lines (74 + 26n px tall, n = 1–5; with no lines yet it shows `log1` empty), bottom-anchored at screen y 1056 so it grows upward (the root's top = 1056 − height); a line of age a has its top at height − 42 − 26a. Up to 5 lines, newest at the bottom, BBCode stripped, line colour by age (ages 0–1 their tone, 2 tan, 3–4 dim `#94806A`) with the matching `lacquer_bullet_*` texture; ellipsis at 384 px. Reads `get_history()` in `_ready` so lines logged before it existed show. The full log is a second, larger board in the same scene (a `StyleBoxTexture` 9-slice of `lacquer_log5_ai`, kit-coloured lines, scrolling, newest at the bottom), hidden by default; `L`, `Esc` while open, or `toggle_window()` toggles it. Drop the old drag title bar and collapse button.

- [ ] **Step 1: Write the failing tests:** `test_shows_last_five_newest_last` (log 7 → 5 lines, last text == message 7); `test_board_grows_upward` (2 lines → height 126 and its bottom edge at y 1056 in a 1920x1080 parent; 5 lines → height 204); `test_tones_fade_with_age` (five gold lines → line colours brass, brass, tan, dim, dim, bullets match); `test_tone_for_mapping` (cyan → MADRA, gold → BRASS, green → CREAM, red → TAN, plain → TAN); `test_strips_bbcode`; `test_reads_history_on_ready`; `test_toggle_window_opens_full_log_with_all_lines`; `test_long_line_ellipsizes` (Review Focus 4: label width stays ≤ 384).
- [ ] **Step 2: Run, expect failures.**
- [ ] **Step 3: Implement.** `test_merchant_view_state.gd` still assigns a plain `Control` to `log_window`: keep `MainView.log_window` typed `Control`.
- [ ] **Step 4: Run; green; capture alone.**
- [ ] **Step 5: Commit** `feat(ui): restyle the log as a five-line board with a full log on L`.

---

### Task 8: Dock (`Dock`, `SystemMenuButton`)

**Files:**
- Move: `scenes/zones/zone_resource_panel/system_menu/` → `scenes/ui/dock/system_menu_button/` (`git mv`, fix every reference and the `.uid`s)
- Create: `scenes/ui/dock/dock.tscn` + `.gd`
- Modify: the moved `system_menu_button.tscn` + `.gd`
- Test: `tests/integration/test_dock.gd`

**Interfaces:**
- Produces: `class_name Dock extends Control` (476x80 at its parent's (722, 976), `mouse_filter = STOP`, lacquer theme); `SystemMenuButton.set_notification(active: bool, count: int = 0) -> void`, `SystemMenuButton.has_notification() -> bool`, `SystemMenuButton.get_notification_count() -> int`. `MenuType` keeps driving label, hotkey, icon and input action; icons become Inventory `inventory_icon.png` at 2x, Abilities `lacquer_ic_abilities_ai`, Character the user's `character_icon.png` and Path the user's `star_icon.png` (both 64 px files at 32x32).

Kit §5.4: buttons 108x64 at x 10, 126, 242, 358 inside the dock (screen x 732, 848, 964, 1080, y 984); `lacquer_btn_ai`, `lacquer_btn_hover_ai` on hover, `lacquer_btn_ring_ai` while notified; the Path count seal (`lacquer_seal_count_ai`) overhangs the top-left corner. Path: `PathManager.get_point_balance()` in `_ready` and `points_changed`; count shown when > 0. Abilities: ring with no count while `AbilityManager.has_unequipped_unlocks()`. Remove the `%Badge` `ColorRect` and the unused `BADGE_PROVIDER`. Gold leaves the bar (it moved to the cabinet).

- [ ] **Step 1: Write the failing tests** (inject `PathManager` state as `test_path_manager.gd:31` does): `test_four_buttons_in_order` (labels Inventory, Abilities, Character, Path; hotkeys I, A, C, P); `test_path_count_follows_points` (add 3 → ring + "3"; spend to 0 → no ring); `test_path_reads_balance_on_ready`; `test_abilities_ring_without_count`; `test_pressing_parses_the_action` (emit the Path button's `pressed`, then `Input.is_action_pressed("open_path")` is true; release it with `Input.action_release` in `after_each`).
- [ ] **Step 2: Run, expect failures.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run; green; capture alone.**
- [ ] **Step 5: Commit** `feat(ui): add the lacquer dock with Path and Abilities notifications`.

---

### Task 9: Activity cards (`ZoneActionButton` and presenters)

**Files:**
- Modify: `scenes/zones/zone_action_button/zone_action_button.tscn` + `.gd`, every presenter under `scenes/zones/zone_action_button/presenters/`
- Create: `presenters/cycling_presenter.tscn` + `.gd`, `presenters/merchant_presenter.tscn` + `.gd`
- Test: `tests/integration/test_zone_action_cards.gd`

**Interfaces:**
- Consumes: Tasks 1–4 (`is_action_seen`, `mark_action_seen`, `ZoneActionGroups.mode_tag`, `get_current_madra_per_second`, `LacquerRod`, `LacquerFrameOverlay`, `LacquerText`).
- Produces (button API for presenters and the list): `enum TagStyle { CARVED, RUNNING, ENTER }`; `set_mode_tag(text: String, style: TagStyle) -> void`; `get_detail_slot() -> HBoxContainer`; `get_footer_slot() -> Control`; `set_tall(tall: bool) -> void` (96 instead of 72); `set_ready_edge(ready: bool) -> void`; `flash() -> void` (brass frame twice); `is_new_shown() -> bool`; signal `card_pressed_while_running` (the list uses it to flash the Now strip). The card root is a fixed 392x72 (or 96) `Control`; a child `Drawer` holds every visual and moves to (−2, −2) with `lacquer_drawer_run_ai` while the card's action runs.

Kit §5.5 › Card internals. Presenter detail lines:
- Cycling: "<equipped technique name> · Madra and Core Density XP" (`CyclingManager`), tag ACTIVE.
- Training: `LacquerText.rate(rate) + " Madra / s · each level +<amount> <Attribute>"` from `effects_on_level`, tag IDLE / RUNNING.
- Foraging: each loot entry's item icon (16 px mini icons when the item has none) and "min–max", then "every <interval> s · free" ("· <n> Madra / s" when `madra_cost_per_second > 0`), tag IDLE / RUNNING.
- Adventure: below the threshold, the tall drawer, `mini_madra` + "Needs <threshold> Madra · you have <madra>", the Madra rod (`steps 74`) and the hint ("ready in ~<ceil(missing / rate)> s" in cream while `get_current_madra_per_second() > 0`, else "train or cycle to fill" in tan); at the threshold, the ready drawer, "Ready · carries up to <capacity> Madra · <time_limit_seconds / 60> min run" in brass and the ENTER tag. Keep the reject shake (in even-px steps, no scale).
- Merchant: "<n> wares · you have <gold> gold", tag SHOP.
- Default (dialogue, zone event): the description, tag STORY.
A non-idle card whose detail line is wider than 316 px at 15 px uses the tall drawer and wraps the detail onto two lines (kit §0; the fresh-save cycling card). The NEW seal shows when `not ZoneManager.is_action_seen(id)`; hover or click marks it seen and hides it. Remove the category colour table, sweep fills and flying particles.

- [ ] **Step 1: Write the failing tests** (fresh save; cards built with `setup_action`): `test_mode_tags_per_type`; `test_running_card_is_pulled_out_and_tagged` (select the Aura Well → tag text "RUNNING", `Drawer.position == Vector2(-2, -2)`; select cycling → back to (0, 0), "IDLE"); `test_new_seal_clears_on_hover` (emit `mouse_entered` on the card → hidden and `is_action_seen` true); `test_adventure_below_threshold_copy` ("Needs 50 Madra · you have 25", "train or cycle to fill"); `test_adventure_hint_with_aura_well` ("ready in ~17 s"); `test_adventure_ready_copy_and_enter` (Madra 60 → "Ready · carries up to 100 Madra · 5 min run", ENTER tag); `test_unaffordable_click_does_not_select`; `test_training_detail` ("+1.5 Madra / s · each level +1 Spirit"); `test_foraging_detail_has_interval_and_cost` (contains "every 5 s · free"); `test_long_action_name_ellipsizes` (Review Focus 4: card stays 392 wide); `test_long_detail_wraps_in_tall_drawer` (a cycling card with a 40-word detail is 96 tall).
- [ ] **Step 2: Run, expect failures.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run; green; capture a card column alone (a scratch test scene under `tests/label_tests/` is fine, not committed) and compare with the mock.**
- [ ] **Step 5: Commit** `feat(zones): turn activity cards into lacquer drawers with mode tags and detail lines`.

---

### Task 10: Zone chest (`ZonePanel`, `NowStrip`, `ActivityList`, `LacquerRail`)

**Files:**
- Create: `scenes/zones/zone_panel/zone_panel.tscn` + `.gd`, `scenes/zones/zone_panel/now_strip/now_strip.tscn` + `.gd`, `scenes/zones/zone_panel/activity_list/activity_list.tscn` + `.gd`, `scenes/zones/zone_panel/activity_list/activity_group_label.tscn`, `scenes/zones/zone_panel/lacquer_rail/lacquer_rail.tscn` + `.gd`
- Test: `tests/integration/test_zone_panel.gd`

**Interfaces:**
- Consumes: Task 9's card API, Task 1 (`action_focus_requested`), Task 2 (`ZoneActionGroups`), Task 3.
- Produces: `class_name ZonePanel extends Control` (440x1032 at its parent's (1456, 24), `mouse_filter = STOP`, lacquer theme); `scroll_to_action(action_id: String) -> void` (scroll until the card is fully visible with 24 px margin, then flash it); `get_card(action_id: String) -> Control`; `is_now_strip_shown() -> bool`. `class_name NowStrip extends Control`: signal `strip_pressed`; `flash() -> void`. `class_name LacquerRail extends Control`: `bind(host: ScrollContainer) -> void`.

Kit §5.5 and §0. The chest hugs its content: `lacquer_chest_top_ai`, a tiled `lacquer_chest_mid_ai` and `lacquer_chest_bot_ai` stacked, height max(176, list top + list height + 24) local; when the list needs more than the space to local 992 it scrolls, folds 8 px under its last whole drawer (no cut drawer, no lone group label), keeps 40 px under the list, and snaps to local 1032 when within 64 px. Header: thumbnail (`lacquer_thumb_ai` for Spirit Valley, `lacquer_thumb_basic_ai` otherwise), zone name, About (`lacquer_about_ai` / `_open_ai`, hidden when the zone has no description) toggling the lore panel (`lacquer_lore_ai`, `ZoneData.description`), which opens inline under the Now tray and pushes the Activities header and list down 276 px; About, `Esc` or a click outside closes it. Now strip: visible only while the current action is FORAGE or TRAIN_STATS; ring frame = floor(progress × 13) clamped to 12 from `ActionManager.action_timer` (1 − time_left / wait_time); Aura Well and foraging variants exactly as kit §5.5's table ("Lv <n> → <n+1> · +<amount> <Attribute>", `<ticks in level> / <ticks for next>`, rod `steps 152`; dewdrop/fern ranges and "haul in <ceil(time_left)> s"). Activities header with "<n> here" and grooves; list viewport and card flow (group label rows 18 + 6, cards 8 apart, groups 14 apart) per kit; `ScrollContainer` with its own scrollbar hidden; `LacquerRail` (caps lit only when the list can scroll that way, thumb height and position formula from kit §5.5); `lip_top` / `lip_bottom` shown at a scrolled edge; "Nothing to do here yet." when empty. When the strip hides, the header moves to y 102 (screen) and the list to 132 with height 908. Rebuild on `ZoneManager.zone_changed`, `ZoneManager.action_completed`, `UnlockManager.condition_unlocked`; listen to `ZoneManager.action_focus_requested` → `scroll_to_action`. Clicking the strip → `scroll_to_action(current id)`; a card's `card_pressed_while_running` → `NowStrip.flash()`.

- [ ] **Step 1: Write the failing tests** (fresh save; panel via `add_child_autofree`; await two frames for layout): `test_header_shows_zone_name`; `test_fresh_save_collapses_strip_and_moves_list` (strip hidden, list top at the collapsed y); `test_strip_shows_for_aura_well` (texts "Aura Well", "+1.5 Madra / s", and "Lv 0 → 1 · +1 Spirit" with no ticks yet); `test_strip_hidden_while_cycling`; `test_groups_in_order_with_labels` (unlock everything: labels Talk…Visit in order, only for non-empty groups); `test_count_label` ("<n> here"); `test_empty_zone_shows_nothing_to_do` (a fixture zone with no actions); `test_scroll_to_action_makes_card_visible` (nine-card fixture: the last card's rect ends inside the viewport after the call, and its frame flashes); `test_rail_hidden_when_content_fits`; `test_focus_request_scrolls` (`ZoneManager.request_action_focus("shallow_woods_adventure_action")`); `test_lore_toggles` (open pushes the header down 276 px); `test_chest_hugs_short_list` (fresh save: chest height under 400); `test_chest_fills_for_nine_cards` (nine-card fixture: chest height 1032, last visible card not cut).
- [ ] **Step 2: Run, expect failures.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run; green; capture the panel alone and compare with the mock (default, foraging, fresh save, 9 cards).**
- [ ] **Step 5: Commit** `feat(zones): add the zone chest with the Now strip and a scrolling activity list`.

---

### Task 11: Map rendering (camera, fog, hex states)

**Files:**
- Create: `scripts/utils/zone_map_math.gd`, `scenes/tilemaps/fog_tileset.tres` (three atlas sources, ids 1–3 for tiers 1–3, tile 164x190, hexagon shape and layout identical to `scenes/tilemaps/tilemap_tileset.tres`, from `assets/ui/lacquer/map/lacquer_fog_t{1,2,3}_atlas_ai.png`), `scenes/zones/zone_hex_marker/zone_hex_marker.tscn` + `.gd` (current rim / open hairline)
- Modify: `scenes/zones/zone_tilemap/zone_tilemap.gd` + `.tscn`, `scenes/zones/locked_zone_overlay/locked_zone_overlay.tscn` + `.gd`, `scripts/utils/hex_forest_atlas.gd`, `scenes/camera/camera_clamp_controller/camera_clamp_controller.gd` (a public `clamp_now()`)
- Test: `tests/unit/test_zone_map_math.gd`, extend `tests/unit/test_hex_forest_atlas.gd`, `tests/integration/test_zone_map_render.gd`

**Interfaces:**
- Consumes: Task 1 (`get_map_zones`, `get_zone_map_state`, `map_zones_changed`).
- Produces:
  - `ZoneMapMath` (statics): `const ZONE_SCREEN_ANCHOR: Vector2 = Vector2(960, 702)`; `const VIEWPORT_SIZE: Vector2 = Vector2(1920, 1080)`; `camera_position_for(zone_world_centre: Vector2, zoom: float) -> Vector2` (= centre − (ANCHOR − VIEWPORT_SIZE / 2) / zoom); `fog_tier(cell_cube: Vector3i, charted_cubes: Array[Vector3i]) -> int` (min cube distance, capped at 3; 3 when the array is empty); `world_to_screen(world: Vector2, camera_position: Vector2, zoom: float) -> Vector2`.
  - `HexForestAtlas.pick_from(coord: Vector3i, pool_size: int) -> int` (deterministic, in [0, pool_size)).
  - `ZoneTilemap`: `get_zone_world_centre(zone_data: ZoneData) -> Vector2`; `frame_zone(zone_data: ZoneData, duration: float = 0.0) -> void`; `get_fog_tier_at(cell: Vector2i) -> int` (−1 for no fog); signal `map_rebuilt`.

Rules: camera zoom range 1.0–2.0, default 2.0, `Camera2D.offset` zero, framed on `_ready` and after travel, clamp boundary = map zones' bounds plus 1.5 hexes and re-clamped after camera tweens. Fog cells fill the clamp bounds plus half a viewport at zoom 1.0 (Review Focus 3), skipping map-zone cells, written with `set_cell` (not the debug-drawing wrapper), tier from `fog_tier` over charted map zones, atlas cell from `pick_from(cube, 9)`. Zone layer only holds map zones. Current zone: `lacquer_hex_current_ai`; open zones: `lacquer_hex_open_ai` (both `map/`, on the cell). Locked: `LockedZoneOverlay` shows `map/lacquer_tile_locked_ai` (hover variant on hover); uncharted: `map/lacquer_tile_uncharted_ai` (hover variant on hover). No glimmer (removed in revision 2). Expose a rim setter on the overlays so Task 13 can swap in `map/lacquer_hex_hover_ai` (open hex hovered), `map/lacquer_hex_hover_in_ai` and `map/lacquer_hex_pinned_in_ai` (veiled hexes hovered or pinned). The overlay's lock icon moves out (Task 12 draws glyphs). `PlayerCharacter.scale = Vector2.ONE`, standing where kit §0 puts it (its 32x48 screen rect's top-left at (960, 740) in Spirit Valley, i.e. the zone centre plus (0, 38) screen px); foraging wanders west only (0 → −24 → −8 → 0 world px over the 5 s haul). Remove `Atmosphere`, the ghost-neighbour polygons and the `GlowingPath`s from the zone map. A full-rect `#090E0E` map ground sits behind the map (a `CanvasLayer` at layer −1 in `zone_tilemap.tscn`). `CHARACTER_MOVE_SPEED = 275.0` (travel itself is Task 13). Rebuild on `map_zones_changed` and `condition_unlocked`.

- [ ] **Step 1: Write the failing tests:** `test_camera_position_frames_anchor` at zooms 1.0, 1.5, 2.0 (`world_to_screen(centre, camera_position_for(centre, z), z)` ≈ (960, 702)); `test_fog_tier_distances` (neighbour 1, two away 2, far 3, empty 3); `test_pick_from_is_deterministic_and_in_range`; integration (instantiate `zone_tilemap.tscn` after the fresh-save fixture; `tile_set.emit_changed()` then await a frame, as `test_adventure_end_flow.gd:13` does): `test_default_zoom_is_two`; `test_spirit_valley_framed`; `test_fog_tiers_around_spirit_valley` (cell (1, 0) tier 1, (2, 0) tier 2, (3, 0) tier 3, (0, 0) no fog); `test_hidden_test_zone_not_drawn`; `test_demo_zones_add_overlays_and_retier_fog` (demo on → Advancement cell gets a locked overlay, uncharted gets the uncharted one, and (1, −2) becomes tier 1); `test_fog_covers_screen_at_zoom_one` (every cell whose rect intersects the clamp bounds plus the half viewport at zoom 1.0 has fog or a zone).
- [ ] **Step 2: Run, expect failures.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run; green; capture `zone_tilemap.tscn` alone (with the demo toggle forced on in a scratch copy, not committed) and compare with the mock's map.**
- [ ] **Step 5: Commit** `feat(zones): render the zone map at zoom 2 with fog tiers and lacquer hex states`.

---

### Task 12: Map markers (plates, glyphs, routes, ring, floaters)

**Files:**
- Create: `scenes/zones/map_markers/map_markers.tscn` + `.gd`, `scenes/zones/map_markers/zone_map_label/zone_map_label.tscn` + `.gd`, `scenes/zones/map_markers/map_action_ring/map_action_ring.tscn` + `.gd`, `scenes/zones/map_markers/map_floater/map_floater.tscn` + `.gd`, `scenes/zones/zone_route/zone_route.gd` (+ `.tscn`)
- Modify: `scenes/zones/zone_tilemap/zone_tilemap.gd` + `.tscn` (instances `MapMarkers` and the routes)
- Test: `tests/integration/test_map_markers.gd`

**Interfaces:**
- Consumes: Tasks 1–4, 11 (`get_zone_world_centre`, `map_rebuilt`).
- Produces: `class_name MapMarkers extends CanvasLayer` (layer 1): `get_plate(zone_id: String) -> ZoneMapLabel`; `get_glyph(zone_id: String) -> Control`; signal `plate_pressed(zone_data: ZoneData)`; `set_hovered_zone(zone_id: String) -> void`; `set_pinned_zone(zone_id: String) -> void` (Task 13 calls these). `class_name ZoneMapLabel extends Control`: `setup(zone_data: ZoneData, state: ZoneManager.ZoneMapState) -> void`, `set_hovered(hovered: bool) -> void`, `set_pinned(pinned: bool) -> void`, `get_line_text() -> String`. `class_name ZoneRoute extends Node2D`: `set_points(from: Vector2, to: Vector2) -> void`, `set_lit(lit: bool) -> void` (draws `map/lacquer_route_dot_ai` every 12 world px in `_draw()`, the lit texture when lit).

Kit §6.3–6.5 and §6.7. Plates (248x52 screen) follow their hex every frame from the SubViewport's canvas transform; the kit's offsets from the hex centre at zoom 2 are current/open (−124, +98), locked (−124, +11), uncharted (−124, +18), and they scale by zoom / 2. Plate lines: current = running idle action ("Aura Well · +1.5 Madra / s" with `mini_well`, "Foraging · a haul every 5 s" with `mini_forage`, name only with nothing running); open = "Open · <n> activities", "Click to travel" in brass on hover; locked = `mini_swords` + `blocker_short_text`; uncharted = `blocker_short_text`. Glyphs: `lacquer_glyph_lock_ai` at centre (−22, −61), `lacquer_glyph_unknown_ai` at centre (−14, −40), and the uncharted twinkle (`lacquer_glyph_twinkle_strip_ai`, 3 frames of 14x14, frame 0 empty) at centre (+12, −48), playing frames 1, 2, 1 for 0.1, 0.2, 0.1 s every 4 s. Routes (kit §0): six dots 24 screen px apart (12 world px), centred on the midpoint between two hex centres, crossing only their shared rim; from the current zone to each charted map zone and on to uncharted zones beyond. The ring (`lacquer_map_ring_strip_ai`, 64x64, 13 frames, same stepping as the Now strip) sits at the zone centre + (38, 4) screen px with the action icon at + (54, 20); it stays with the zone, not the character. The floater rides the lacquer token (`token.tres`, height 28, width even(text width + 28), centred on centre x + 50, top at centre y − 28): `+1.5 Madra` in Madra blue per Aura Well tick, rising 40 px in 1 s in 2 px steps, then hidden; the haul text in cream once per forage. Ring and floater are hidden with no idle action. Hide the whole layer during `ZoneTransition`'s adventure zoom (listen to `ActionManager.adventure_start_requested`; show again when the zone view state re-enters).

- [ ] **Step 1: Write the failing tests** (instance the tilemap as in Task 11): `test_plate_per_map_zone` (one plate, Spirit Valley); `test_current_plate_line_follows_action` (Aura Well → "Aura Well · +1.5 Madra / s"; none → name only); `test_demo_plates_and_glyphs` ("Tribulation Guardian", "After the Tribulation", lock and `?` glyphs); `test_open_plate_counts_activities` (Test Zone shown and unlocked → "Open · <n> activities"); `test_plate_follows_hex_at_zoom_one` (Review Focus 3: plate top-left == world_to_screen(centre) + (−124, 98) × 0.5); `test_ring_hidden_without_idle_action`; `test_floater_on_training_tick`; `test_route_lit_toggles`; `test_hiding_demo_zones_removes_their_plates` (Review Focus 5).
- [ ] **Step 2: Run, expect failures.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run; green; capture and compare with the mock.**
- [ ] **Step 5: Commit** `feat(zones): add map plates, glyphs, routes and the action ring`.

---

### Task 13: Map interaction (hover, popovers, travel)

**Files:**
- Create: `scripts/ui/map_popover_state.gd`, `scenes/zones/map_markers/zone_map_popover/zone_map_popover.tscn` + `.gd`
- Modify: `scenes/zones/zone_tilemap/zone_tilemap.gd` + `.tscn`, `scenes/zones/map_markers/map_markers.gd` + `.tscn`, the hex overlays from Task 11 (rim swaps)
- Test: `tests/unit/test_map_popover_state.gd`, `tests/integration/test_zone_travel.gd`

**Interfaces:**
- Consumes: Tasks 1, 3, 11, 12.
- Produces: `class_name MapPopoverState extends RefCounted`: `enum ClickResult { TRAVEL, PIN, RECENTRE, CLOSE }`; `hover(zone_id: String, state: ZoneManager.ZoneMapState) -> void`; `unhover() -> void`; `click(zone_id: String, state: ZoneManager.ZoneMapState) -> ClickResult` (`""` = fog); `close() -> void`; `get_pinned_zone_id() -> String`; `get_preview_zone_id() -> String` (set by `show_preview()`, which MapMarkers calls after its 150 ms timer); `get_hovered_zone_id() -> String`. `ZoneTilemap.is_travelling() -> bool`.

Spec, Behaviour › Map interaction, and kit §6.6. Hover (rim swaps, no brackets, kit §0): a travelable open hex swaps `hex_open` for `map/lacquer_hex_hover_ai`; a locked or uncharted hex gets `map/lacquer_hex_hover_in_ai` and its hover tile; plate hover state, route lit toward a travelable zone, preview popover after 150 ms for locked/uncharted. Click: open → TRAVEL (close popover, walk at 275 px/s, keep the current action running, on `movement_completed` call `ZoneManager.set_current_zone`, then `frame_zone` with a short ease and re-clamp); locked → shake the lock glyph (0, −8, 8, −6, 4, 0 px over 0.44 s in steps), `map/lacquer_hex_pinned_in_ai` on the pinned hex and the brass frame on its plate, pinned popover with × and "Show me" (`lacquer_showme_ai` + `lacquer_chev_ai`) only when `requirement_action_id` is an action of the current zone; uncharted → pinned popover, never travels; current → recentre and close; fog → close. One popover at a time; Esc, ×, a click outside, another hex, or travel closes it. "Show me" calls `ZoneManager.request_action_focus(requirement_action_id)`. A plate press does what its hex's click does. A second click during a walk retargets the walk; the zone changes only on the final arrival (Review Focus 2).

- [ ] **Step 1: Write the failing tests.** Unit: `test_click_open_travels`, `test_click_locked_pins`, `test_click_uncharted_pins_never_travels`, `test_click_current_recentres_and_closes`, `test_click_fog_closes`, `test_only_one_pinned`, `test_preview_requires_show_preview`, `test_unhover_clears_preview_not_pin`. Integration (fresh save; Test Zone shown with `set_hidden_zones_visible(true)` and unlocked with `UnlockManager.force_unlock_condition("celestial_intervener_dialogue_1")`): `test_travel_changes_zone_on_arrival_only` (right after the click `ZoneManager.get_current_zone()` is still Spirit Valley; after `movement_completed` it is Test Zone); `test_old_action_runs_during_walk` (Aura Well still current mid-walk); `test_second_click_during_walk_retargets` (Review Focus 2); `test_show_me_only_for_action_in_current_zone` (demo Advancement in Spirit Valley → shown; from Test Zone → hidden); `test_show_me_requests_focus`; `test_esc_closes_pinned_popover`; `test_hiding_demo_zones_closes_their_popover` (Review Focus 5).
- [ ] **Step 2: Run, expect failures.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run; green.**
- [ ] **Step 5: Commit** `feat(zones): add map hover, popovers and travel on arrival`.

---

### Task 14: Swap the new view into the game

**Files:**
- Modify: `scenes/main/main_game/main_game.tscn`, `scenes/ui/main_view/main_view.gd`, `scenes/ui/main_view/states/zone_view_state.gd`, `scenes/ui/main_view/states/adventure_view_state.gd`, `scenes/merchant/merchant_view_state.gd`, `scenes/zones/zone_transition/zone_transition.gd`, `scenes/ui/dev_panel/dev_panel.tscn` + `.gd`, `tests/unit/test_merchant_view_state.gd`, `docs/tooling/DEV_TOOLS.md`
- Delete: `scenes/zones/zone_resource_panel/` (its `system_menu/` already moved), `scenes/zones/zone_info_panel/`, `scenes/zones/zone_header/`, `scenes/zones/zone_action_type_section/`, `scenes/ui/quest_window/` (with `quest_entry/`), `scenes/ui/toolbar/`, plus their styleboxes if nothing else uses them (grep first)
- Test: `tests/unit/test_view_state_hud_positions.gd`

**Interfaces:**
- Consumes: every earlier task.
- Produces: `MainView.goals_panel: Control` (replaces `quest_window`); `AdventureViewState` moves Goals to (1456, 24) and back; `ZoneViewState.enter()` puts Goals at (24, 272) and the log at (24, 852).

Steps inside: `ZoneView` drops `ZoneViewBackground`, `ZoneInfoPanel`, `ZoneResourcePanel`, `ZoneHeader` and `Toolbar`, and gains `CultivatorPlate` (24, 24), `ZonePanel` (1456, 24) and `Dock` (722, 976). The zone `SubViewport` gets `canvas_item_default_texture_filter = 0`. `MainView` swaps `QuestWindow` for `GoalsPanel` (`layout_mode = 0`, z 1) and moves `LogWindow` to (24, 852). `ZoneTransition` finds `CultivatorPlate` (typed) instead of `ZoneResourcePanel`. `MerchantViewState._hide_hud_windows` hides `goals_panel`. Dev panel: a `ZonesHeader` label and two `CheckButton`s, "Demo zones (locked, uncharted)" → `ZoneManager.set_demo_zones_visible`, "Show hidden zones (Test Zone)" → `set_hidden_zones_visible`, each logging a `[DEV]` line like the existing toggle; add both rows to DEV_TOOLS.md.

- [ ] **Step 1: Write the failing tests:** `test_adventure_moves_goals_and_restores` and `test_merchant_hides_goals` (built like `test_merchant_view_state.gd`, with `goals_panel`); update `test_merchant_view_state.gd` for the rename.
- [ ] **Step 2: Run, expect failures.**
- [ ] **Step 3: Wire it**; grep for every removed class and scene path (`ZoneResourcePanel`, `ZoneInfoPanel`, `ZoneHeader`, `ZoneActionTypeSection`, `QuestWindow`, `QuestEntry`, `Toolbar`) and leave none; `--import`; check `git diff project.godot`.
- [ ] **Step 4: Run the suite; green. Back up the save, capture `main_game.tscn` (`--write-movie … --quit-after 100`), check the save hash is unchanged, and compare the frame with the mock's default state; fix placement differences. Repeat with the demo toggles forced on in memory only if needed (never commit a forced toggle).**
- [ ] **Step 5: Commit** `feat(zones): swap in the map-first lacquer zone view` (and a separate `refactor(zones): remove the replaced zone view scenes` for the deletions).

---

### Task 15: Docs

**Files:**
- Modify: `docs/zones/ZONES.md`, `docs/infrastructure/MAIN_VIEW.md`, `docs/progression/FOUNDATION_PLAYTHROUGH.md` (Path points now announced by the dock), `docs/STATE_OF_THE_GAME.md`, `docs/CODEBASE_STATE.md`, `CLAUDE.md` (View Architecture: Toolbar → Dock, QuestWindow → GoalsPanel, Atmosphere now only in the adventure view; Reusable UI Components: the lacquer pieces), the spec's Status line ("Built on <date>"), and the plan's checkboxes.

- [ ] **Step 1: Update each doc to the built state** (scene tree, behaviour, placement per view, the dev toggles, Work Remaining items this closes).
- [ ] **Step 2: Commit** `docs(zones): document the map-first lacquer zone view`.
