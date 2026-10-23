# Adventure View in Lacquer and Brass, PR 1: the Map and the Frame — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the adventure map and the frame around it in the Lacquer and brass look: a zoom-1 hex map with the zone map's fog tiers, veiled revealed tiles, rims, route dots and lacquer encounter coins; the vitals cabinet on the left; the chest on the right with the run clock, the Here tray, the encounter's choices and a Run ledger; the technique dock with the radial cooldown sweep.

**Architecture:** Bottom-up. Art first (the mock's generators plus an import script), then the theme pieces, then `AdventureTilemap`'s new events (the signals the boards listen to), then the map in two layers (rendering, coins), then each board as its own scene tested in isolation (cabinet, chest, expedition page, dock), then the swap in `AdventureView`. The fight itself (opponent page, stage, fighters, dissolve) is [PR 2's plan](2026-10-22-adventure-view-lacquer-pr2-fight.md); between the two PRs, fights keep today's floating enemy plate, fighters, painted forest and fade-in.

**Tech Stack:** Godot 4.7.2, GDScript, GUT 9.7.1; Python 3 with Pillow for the art generators.

**Spec:** [2026-10-22-adventure-view-lacquer-design.md](../specs/2026-10-22-adventure-view-lacquer-design.md). Read it, Decisions table first, before any task. The mock-up [adventure-view-lacquer-mockup.html](../mockups/adventure-view-lacquer-mockup.html) is the visual reference (serve the repo root: `.claude/launch.json`, `adventure-mockup`); where the spec and the mock differ, the spec wins. Every piece follows [STYLE_GUIDE.md](../../STYLE_GUIDE.md) and the zone view's [lacquer kit](../specs/2026-10-21-zone-view-lacquer-kit.md).

## As built (2026-10-23)

All 11 tasks are built on `feat/adventure-view-styleguide-1fc223` (not merged); the suite ends at 123 scripts and 1632 tests, all passing (1621 before the pre-merge touch-up below; Task 1 ended at 109 and 1300). This is PR 1 only: the fight is [PR 2's plan](2026-10-22-adventure-view-lacquer-pr2-fight.md) and is not built. The living docs ([ADVENTURING.md](../../adventuring/ADVENTURING.md), [COMBAT.md](../../combat/COMBAT.md), [MAIN_VIEW.md](../../infrastructure/MAIN_VIEW.md), [STYLE_GUIDE.md](../../STYLE_GUIDE.md)) describe the result. Deviations from the task text that matter (`git log 0054dfb8..HEAD` has the rest):

- **Before building (`5ed5f99`).** Five task details were corrected in this plan first: `import_kit.py`'s argument parsing and `main()` move under `if __name__ == "__main__":` so `bake_shadow()` imports cleanly; `AdventureChest.get_expedition_page()` is Task 8's; the orb-default test reads the shader's declarations, because headless Godot returns no parameter defaults from `RenderingServer`; Task 4's route test walks to (0,1,-1) before it hovers (1,-1,0), because the original target is fogged at the start; Task 9's key tests push an `InputEventAction` through `get_viewport().push_input()`, because `Input.action_press()` sends nothing to `_unhandled_input`.
- **Art (Task 1, `b29c5a7`).** 27 new `_ai` PNGs under `assets/`: 20 screen pieces (the boards, sockets, minis, coin tokens and Health orb, plus the six rod files), six spent glyphs and the veil atlas. Three more `build_all.py` outputs (the veil atlas and the two new spent glyphs) are tracked in the mock folder, as every other output is.
- **Theme and shader (Task 2, `10d611a`).** `LabelLacquerCooldown` sets no `line_spacing` (it is one line, so the spec's 28 pitch has nothing to apply to). The orb's three colour uniforms replaced the Madra constants, and a GPU capture shows the old and new shaders draw the Madra orb pixel for pixel.
- **Map events (Task 3, `f83ee96`).** `start_adventure_on_map()` plays on a copy of the encounter dictionary, so stopping a run leaves a fixture alone. The stamina-stop test walks to (0,1,-1) first (the brief's (0,2,-2) is fogged), and the dialogue test calls `_on_dialogue_ended()` directly, because a second real Dialogic timeline in one run breaks `test_idle_action_resolution`. The fixture moved to `tests/integration/adventure_map_fixture.gd` for Tasks 4, 5 and 10.
- **Map (Task 4, `db481f3`, `517510f`, `2a6f9e8`).** The coin over the player's tile rises 56 px, not 40: the game's character stands on its tile centre with its head 16 px above it, higher than the mock's (`2a6f9e8` amends the spec and Task 5). The boss reveal's camera push tweens `Camera2D.offset` toward the boss and back instead of the camera's position, so the camera stays on the character when the walk goes on (`517510f`; the old push left it offset). Under Show Whole Map, unvisited tiles draw on the forest source, not the veil. `CharacterBody2D.walk_snap_px` (default 1, 2 here) puts the adventure's walk on the 2 px grid.
- **Coins (Task 5, `2e8c14e`).** The whole boss coin shakes on the reveal, token and glyph, not the glyph alone (it would slide 8 px across a 52 px coin). Coins are placed in `_process` and again on `RenderingServer.frame_pre_draw`, because the push is a tween that steps after `_process` and the coins trailed the tiles by a frame. `_animate_reveal_stagger()` became `_check_boss_reveal()`, since nothing staggers any more.
- **Cabinet (Task 6, `df0c10b`).** The two big figure rows sit at y 44 and 132, not 43 and 131 (measured against the mock; the zone cabinet carries the same +1). The plate keeps its own list of buffs from the manager's signals, because `clear_all_buffs()` announces each removal before it empties its list, and it is the plate that closes a buff's tooltip when the buff ends.
- **Chest (Task 7, `5e2a818`).** The title sits at (16, 17), not (16, 18), as the zone chest's name sits at 15 for the kit's 16. The height rounds to the nearest even number, as the mock's `fitChest()` does. The chest also relays out when a page is shown or hidden, and defers the first layout of a page that joins.
- **Expedition page (Task 8, `dcf2c03`).** The Here tray's name is 224 px wide beside the BOSS seal (236 beside a tag), because at 236 the boss's name ran under the seal. The Run ledger always shows six loot sockets (the mock shows two). A completed choice outranks a locked one (the Aura Well's "Mark down the location" fails its own requirement once done), and the LOCKED seal carries the kit's lock icon. The lore and hint rows are padded so every row of the flow sits on an even y. The text rules are statics (`kind_word`, `kind_tag`, `here_line`, `choice_detail`, `walk_hint`) that the tests call.
- **Dock (Task 9, `3bb1caa`, `6023445`, `0b1eac9`).** `TechniqueDock.get_technique_tooltip()` replaces the plan's `get_tooltip()`, which `Control` already defines. The tooltip's description wraps at 268, not 272, so the board stays 304 wide, and its height rounds up to an even number so its top stays on the 2 px grid (`6023445`). The cost line's box is 81 px wide, so one-digit costs land where the mock puts them. The shader rounds to the nearest step, `floor(progress * STEPS + 0.5)` (`0b1eac9`; this plan and the spec said `floor(progress * STEPS)`): the slot only sends k / 24, and for k = 7 and 14 the product lands exactly halfway between float32 values, which a bare `floor` leaves to the GPU's rounding. A 0.0001 rad bias keeps a cell whose centre sits on a step's edge veiled whatever `atan()` returns. On a GPU, 0 of 409,600 pixels differ from the mock's cooldown strips. A refused press still makes `can_cast_ability_instance()` write its own `Log.warn`; the player's log stays silent.
- **Wiring (Task 10, `17a6d1b`, `cef48b8`).** The boards sit after the map with mouse STOP: the map's `SubViewport` hears the pointer only through its container, so a press on a board never clicks a hex (`test_press_on_a_board_does_not_reach_the_map` moves the real pointer, because `push_input()` alone never moves the pointer the hex layer reads). `select_choice()` ignores a pick while a fight or a talk is under way or the tile is resolved (the chest stays up through a fight), and `start_adventure_on_map()` clears an in-flight choice so a boss win cannot block the next run's picks. `stop_adventure()` clears the walk queue and releases the committed destination before `stop_moving()`, so a hop cannot restart during the teardown. `AdventureView` clears `current_action_data` before the tilemap stops, so the teardown changes no run figure and the Run ledger keeps its last numbers under the end card. Deleted with their `.uid` files: `PlayerHud`, `AbilitiesPanel`, `AbilityButton`, `CombatAbilityTooltip`, `ResourceOrb`, `TimerPanel`, `EncounterInfoPanel`, `EncounterChoiceButton` and eleven styleboxes. During the boss reveal's push the boss coin stays on its hex in every captured frame.
- **Docs (Task 11, `585a2d0`, `b0137d1`, `b37c0f3`, `796303a`, `5a16649`, `6a3f61c`, `56ed41d`, `5ad1609`, and the review fix `2f79ab8`).** Split into `docs(adventure)`, `docs(testing)`, `docs(style)`, `docs(state)` and plain `docs:` commits for the system docs that named the removed pieces (ability, character, dialogue, effects, resources, unlocks, breakthrough, `combat_architecture.md`), CLAUDE.md and this record. The style guide deleted rows A1–A9 and B1–B3, narrowed B4, B6, B7, S1 and S2 to the enemy and the fight, and answered G2, G7 and G9 for the adventure. The map-first zone view had been merged as PR #51 while several docs still called it unmerged; the docs touched here now say so.
- **Pre-merge touch-up (`6789dbc`, `8ffb21d`, `5742079`, `c76ea5f`, then `8d2e070` and `fb76de2`; docs `3a83f0c`, `1581d21`, `333acdb`, `9f32013`, `50e9610`, `da17382`).** Six of the final review's seven minor findings, fixed before the merge, and two follow-ups. `stop_adventure()` clears the run before it stops the character, and a hop that ends with no run on arrives nowhere, so the teardown no longer visits a tile, reveals the boss or repaints the chest (`6789dbc`). The map listens to its `SubViewportContainer`, so the hover clears when the pointer goes onto a board (a committed walk's rim and route stay), and a walk stopped for Stamina lays the hover again for the tile under the pointer instead of leaving the rim on the unreached destination (`8ffb21d`). `BuffTooltip` rounds its height up to even (`5742079`). `RunClock.bind_timer()` paints at once, so a new run's first frame no longer shows a timed-out run's `0:00` on the seal (`c76ea5f`). The docs fixed the ledger's "fights won" (it counts every fight that ends), the clock's start (`4:59`), `LabelLacquerCooldown`'s shadow and the Task 11 review's leftovers. **Follow-ups.** Every run in `test_adventure_view_frame.gd` now plays on a fixed map (`8d2e070`): `_start_run()` hands the tilemap a `FixedMapGenerator` that returns the fixture map (or the map a test sets), because a random Shallow Woods map now and then fails its critical-path check five times and logs an error that fails the test it lands in (about 1 map in 36 in two runs of that file). `test_adventure_end_flow.gd` predates this branch and keeps its random maps. One rule now holds after any walk ends (`fb76de2`, ledger L102): `_on_character_movement_completed()` lays the hover again for the cell the pointer rests over once no hop is left (the destination reached, an encounter that stops the trip, the Stamina stop, which no longer calls it itself), so the camera that followed the character does not leave a stale or empty hover under a still pointer. Eleven tests were added in all (1632 in the suite).
- **Open.** The fight keeps its old look until PR 2: the enemy's plate (its right end runs under the chest), the painted fighters, the parallax forest, `Atmosphere` and the 0.25 s fade-in. BM Euljiro has no ✓ (U+2713), so the Aura Well's "✓ Location noted" draws through a system-font fallback and shows a hex-code box where none exists; the data is unedited, and the choice is to drop the ✓ from `aura_well_encounter.tres` or draw the tick as a kit glyph. `AbilityStatsDisplay`, `StatLabel`, `StatTooltip` and `GoalsPanel.set_cords_visible()` lost their last users and stay in place. The final review triaged the minor findings the task reviews deferred: what the touch-up above leaves is follow-ups, and the encounter's drawers that look pressable during a fight (they ignore the press until PR 2's opponent page replaces them).

## Global Constraints

- **Project rules (CLAUDE.md, memory):** UI nodes live in `.tscn` scenes; scripts set text, textures, frames, visibility, shader parameters and state colours (`add_theme_color_override(&"font_color", ThemeConstants.LACQUER_*)`, as `ZoneActionButton` and `LogWindow` do). Fixed counts (slots, sockets, drawers, rows, tooltips) are built in the scene and shown or hidden; the only scene instanced from code is the map's coin, whose count depends on the generated map (as `MapMarkers` does for plates and glyphs). Label theme variants before overrides. Explicit types, `->` return types, `##` docs on the class and public functions, `_` on private ones, `%UniqueName` node references, `#-----` section headers, `Log.*` for diagnostics, `LogManager.log_message()` for the player's log, no `print()`.
- **GodotPrompter:** before writing Godot code, invoke the skills each task names. Follow CLAUDE.md where a skill disagrees.
- **Never modify `addons/`.**
- **Art:** every image an agent makes ends in `_ai`; never edit the user's files (forest tiles and atlas, glyphs, icons, ability icons, character sheet, fonts). `assets/ui/lacquer/*_ai.png` are screen space, drawn at 2x, shown at file size, with their hard shadow (4 px `#050707` or 2 px `#150909`) baked in, so a file is 2 or 4 px larger than its kit rect: place it at the rect's top-left. `assets/ui/lacquer/map/` files are map space (1x at the adventure's zoom 1). The user's 64 px icons and glyphs show at 32x32 (style guide §9). Stage each new PNG with its tracked `.png.import`; never `.godot/`.
- **Look:** no glow, halo, blur, gradient, opacity fade, translucent panel, rounded pill, tint, alpha or scale for state. Show and hide outright; animate in whole frames or even-px steps. Every shake uses `MapGlyph.SHAKE_KEYFRAMES` (0, −8, 8, −6, 4, 0 px, `SHAKE_STEP_SECONDS` 0.088 each) through `MapGlyph.shake_offset_at()`. Nearest filtering. Even positions and sizes (odd hex rows sit at half px, as on the zone map). No text under 13 px. Jade only for progress fills. Health crimson `#FFD9D2 #E8737A #B8304A #5A1626 #3A0E18` (text `#E8737A`); Stamina bamboo `#EEF5C8 #C9DB86 #8FAE3E #3E5418 #1E2A0C` (text `#C9DB86`).
- **Copy (exact):** "Too tired to walk · 5 Stamina a step"; "Choose what to do here first"; "Here"; "Open ground"; "Click a hex to walk · 5 Stamina a step"; "Click a hex to walk · 5 Stamina a step · <n> steps left"; "<Kind> · <enemy> · <health> Health" (Kind: "Fight", "Ambush", "Elite", "Boss"); kind words "Rest", "Treasure", "Trap"; "Uses <technique>, <technique> · <gold> gold if you win"; "Won · <gold> gold" ("Won" when it paid nothing); "Done"; "Encounter completed."; tags FIGHT, ELITE, BOSS, REST, TREASURE, TRAP, CLEARED, TALK; seal LOCKED; "Run", "fights", "gold", "explored", "Loot"; "Cast <t> s · Cooldown <c> s", "Instant · Cooldown <c> s"; "about <n> Physical damage" (Physical, Spirit, True, Mixed). The 5 is `AdventureTilemap.MOVEMENT_STAMINA_COST`.
- **Tests:** GUT tests call production code, never a copy (`docs/testing/TESTING.md`). Swap in a fresh save first (`PersistenceManager.save_game_data = SaveGameData.new(); PersistenceManager.save_data_reset.emit()`) and stop what you started (`while ActionManager.get_current_action() != null: ActionManager.stop_action()`). Scenes with hex layers: `tile_set.emit_changed()` on one layer after `add_child_autofree()`, then await a frame. Free `adventure_map_generator` in `after_each` (as `test_adventure_end_flow.gd` does). Never instance `main_game.tscn`. Walks are real: await `character_body.movement_completed` (`wait_for_signal(..., 3.0)`).
- **Save safety:** GUT and every run load the developer's real `user://save.tres`. Before running the game or a capture, copy `%APPDATA%/Godot/app_userdata/EndlessPath/save.tres` aside and compare its sha256 afterwards.
- **Commands** (repo root; `GODOT` = `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe"`):
  - Suite: `GODOT --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit`
  - One file: `GODOT --headless -s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/<dir>/test_x.gd -gexit`
  - After a new `class_name`, scene or asset: `GODOT --headless --import`; then `git diff project.godot` must show no emptied `[dialogic]` keys.
  - Art: from `docs/superpowers/mockups/adventure-view-lacquer/gen/`: `python build_all.py`, then `python import_adventure_kit.py`.
  - One scene on screen: `GODOT --path . --write-movie <scratchpad>/shot.png --fixed-fps 30 --quit-after 8 res://<scene>.tscn`; look at the last frame.
- **Git:** work on `feat/adventure-view-styleguide-1fc223`. Commit each task when its tests pass, staging only its files, with a conventional message ending `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never merge, never push.

## Review Focus

1. **A second run after a messy end.** A run that ends by timeout or defeat mid-walk or mid-fight, then a new run, must start with the dock in preview, no cast tray, the chest on the new start tile, the clock reset and only the new map's coins. Test: Task 10 `test_second_run_starts_clean`.
2. **Show Whole Map toggled mid-run.** The dev toggle on, then off, puts coins and fog back to exactly the normal set. Test: Task 5 `test_dev_reveal_toggle_round_trip`.
3. **Long names.** A long adventure name, encounter name, choice label or choice tooltip ellipsizes in its slot; the chest stays 440 wide. Tests: Task 7 `test_title_ellipsizes`, Task 8 `test_long_texts_do_not_widen_the_chest`.
4. **Keys outside a fight.** Q, W, E, R on the map, or after a fight, do nothing: no emit, no shake. Test: Task 9 `test_keys_do_nothing_outside_a_fight`.
5. **Revisiting a resolved tile.** Walking back onto a resolved tile shows its summary under CLEARED, no drawers, and leaves movement free. Tests: Task 3 `test_revisit_carries_the_summary`, Task 8 `test_revisit_resolved_tile_shows_summary_and_no_drawers`.

---

## File map

| Area | Create | Modify | Delete |
|---|---|---|---|
| Art | `gen/import_adventure_kit.py`, `gen/veil_atlas.py`, Task 1's `_ai` files | `gen/map_render.py`, `gen/build_all.py` | |
| Theme | `assets/styleboxes/lacquer/board9.tres` | `lacquer_theme.tres`, `theme_constants.gd`, `lacquer_madra_orb.gdshader`, `docs/UI_STYLING.md` | |
| Map | `scenes/adventure/adventure_route/`, `scenes/adventure/adventure_map_markers/` (with `encounter_coin/`) | `adventure_tilemap.gd/.tscn`, `tilemap_tileset.tres`, `character_body_2d.gd` | `scenes/adventure/path_preview/`, `scenes/adventure/fog_veil_sprite.*`, `scenes/tilemaps/hex_hover_selector.*`, `assets/shaders/fog_of_war.gdshader`, `scenes/adventure/adventure_marker/` |
| Boards | `scenes/adventure/vitals_plate/`, `scenes/ui/combat/buff_tooltip/`, `scenes/adventure/run_clock/`, `scenes/adventure/adventure_chest/` (with `expedition_page/`, `choice_drawer/`), `scenes/ui/combat/technique_dock/` (with `technique_slot/`, `cast_tray/`, `technique_tooltip/`), `assets/shaders/lacquer_cooldown_sweep.gdshader` | `buff_effect_data.gd`, `combat_buff_tooltip.gd`, `vitals_manager.gd`, `adventure_combat.gd`, `ability_row.gd` | |
| Wiring | | `adventure_view.gd/.tscn`, `adventure_view_state.gd`, `test_view_state_hud_positions.gd` | `scenes/ui/combat/{player_hud,abilities_panel,ability_button,combat_ability_tooltip,resource_orb}/`, `timer_panel.gd`, `encounter_info_panel.*`, `encounter_choice_button.*`, 11 styleboxes |

`gen/` is `docs/superpowers/mockups/adventure-view-lacquer/gen/`. Every deleted script goes with its `.uid`.

---

### Task 1: Import the PR 1 textures

Skills: `godot-prompter:assets-pipeline`.

**Files:**
- Create: `gen/import_adventure_kit.py`, `gen/veil_atlas.py`
- Modify: `gen/map_render.py` (`GLYPHS` gains `treasure` and `trap`), `gen/build_all.py` (runs `veil_atlas.run()`), `docs/superpowers/mockups/zone-view-lacquer/gen/import_kit.py` (its argument parsing and `main()` move under `if __name__ == "__main__":`, so `bake_shadow()` can be imported; it behaves the same when run)
- Create (by the scripts): `assets/ui/lacquer/lacquer_{tdock,slot,keycap,cast_tray,timer,timer_low,board9,socket_buff,socket_glyph,mini_health,mini_stamina,mini_hourglass,orb_health,marker_tokens}_ai.png`, `assets/ui/lacquer/lacquer_rod_{stamina,cast}_{empty,full,end}_ai.png`, `assets/sprites/adventure/encounter_glyphs/adv_glyph_{combat,elite,rest,boss,treasure,trap}_spent_light_ai.png`, `assets/sprites/tilemap/hex_tiles/forest/hex_forest_veil_atlas_ai.png`
- Test: `tests/unit/test_adventure_kit_assets.gd`

**Interfaces:**
- Produces (sizes with baked shadows): tdock 480x140 (4 px); slot 82x82, keycap 24x24 (2 px); board9 28x28 (4 px; Task 2's 9-slice margins 8 left and top, 12 right and bottom); marker tokens 216x54 (four 54x54 frames: a 52x52 coin plus its own 2 px shadow; frame 0 glyph coin, 1 carved `?`, 2 carved cleared, 3 boss); cast tray 476x44; timer and timer_low 88x36; socket_buff 40x40; socket_glyph 48x48; minis 16x16; orb_health 80x80 (frame 0 of the mock's health strip); stamina and cast rods 240x10 with 2x10 end caps; spent glyphs 64x64 (trap 32x32); veil atlas 984x760.

Rules. The import script copies from the mock folder and bakes shadows with the zone kit's `import_kit.bake_shadow()` (import it from `docs/superpowers/mockups/zone-view-lacquer/gen/`; do not copy it), crops frame 0 of `lacquer_orb_health_strip_ai.png`, and shadows each coin frame on its own. It stops with an error on a missing source. The veil atlas maps every opaque pixel of the user's `hex_forest_atlas.png` onto the uncharted veil ramp with `map_render.veil()` (luminance thresholds 40/100/150/170 on 0–255) and lays `map_render.rim_dots()` over each 164x190 cell, keeping the layout so `HexForestAtlas.pick()` coords work on both. Spent glyphs are `map_render.spent_light()` of frame 0 (a strip's first 64x64; `trap.png` at its file size).

- [x] **Step 1: Write the failing tests:** `test_screen_pieces_have_their_sizes` (each `assets/ui/lacquer/` file above, by the size list); `test_screen_pieces_sit_on_the_2x_grid` (every 2x2 block of each screen piece is one colour); `test_veil_atlas_matches_the_forest_atlas` (same size as `hex_forest_atlas.png`); `test_veil_atlas_uses_only_veil_colours` (every opaque pixel is one of `#0B1211 #16211F #1C2927 #243431 #2D3F3B #A89070 #7A654C`); `test_spent_glyphs_exist` (six files, 64x64, trap 32x32).
- [x] **Step 2: Run the file; expect failures** (files missing).
- [x] **Step 3: Write `veil_atlas.py`** (`run() -> None`, `save_as(atlas, 'hex_forest_veil_atlas_ai.png', s=1)`), extend `GLYPHS` and `build_all.py`, and write `import_adventure_kit.py`.
- [x] **Step 4: Run `build_all.py`, then `import_adventure_kit.py`, then `--import`.**
- [x] **Step 5: Run the file; expect green.**
- [x] **Step 6: Commit** `feat(adventure): import the lacquer textures for the map and the frame` (scripts, test, the new PNGs and their `.import` files). List every new `_ai` file in the task report.

---

### Task 2: Cooldown label, plain board, vitals colours, orb colours

Skills: `godot-prompter:godot-ui`, `godot-prompter:shader-basics`.

**Files:**
- Create: `assets/styleboxes/lacquer/board9.tres`
- Modify: `assets/themes/lacquer/lacquer_theme.tres`, `scripts/utils/theme_constants.gd`, `assets/shaders/lacquer_madra_orb.gdshader`, `docs/UI_STYLING.md` (the new variant and stylebox in the lacquer section)
- Test: extend `tests/unit/test_lacquer_pieces.gd`

**Interfaces:**
- Consumes: Task 1 (`lacquer_board9_ai.png`).
- Produces:
  - Theme variant `LabelLacquerCooldown` (`base_type` Label): BM Euljiro, size 22, colour `#F0E8D8`, `font_shadow_color` `#150909`, `shadow_offset_x`/`_y` 2, `shadow_outline_size` 0 (the painted titles' shadow).
  - `board9.tres`: `StyleBoxTexture` on `lacquer_board9_ai.png`, texture margins 8 left and top, 12 right and bottom, content margins 16 left, 14 top, 20 right, 18 bottom, `draw_center` true.
  - `ThemeConstants.LACQUER_HEALTH: Color = Color("#E8737A")`, `ThemeConstants.LACQUER_STAMINA: Color = Color("#C9DB86")`.
  - `lacquer_madra_orb.gdshader`: `uniform vec4 light : source_color`, `pale`, `blue`, defaulting to today's `MADRA_LIGHT` `#E8F6FD`, `MADRA_PALE` `#BBD5E7`, `MADRA_BLUE` `#849BE4` (the constants become these uniforms). `progress` stays the only uniform scripts set; the cultivator cabinet looks exactly as before.

- [x] **Step 1: Write the failing tests:** `test_cooldown_variant` (size 22, Euljiro, cream, shadow colour and 2/2 offsets); `test_board9_margins`; `test_vitals_colours`; `test_orb_colours_default_to_madra` (`get_shader_uniform_list()` holds `light`, `pale` and `blue` as colours, and the defaults declared in the shader's `code` parse to the three Madra colours: headless Godot returns no parameter defaults from `RenderingServer`, so read the declarations).
- [x] **Step 2: Run; expect failures.**
- [x] **Step 3: Implement.**
- [x] **Step 4: Run the file and `test_cultivator_plate.gd`; green.**
- [x] **Step 5: Commit** `feat(ui): add the cooldown label, plain board and vitals colours`.

---

### Task 3: Adventure map events the boards listen to

Skills: `godot-prompter:event-bus` (signals up, calls down), `godot-prompter:godot-testing`.

**Files:**
- Modify: `scenes/adventure/adventure_tilemap/adventure_tilemap.gd`
- Test: `tests/integration/test_adventure_tilemap_events.gd`

**Interfaces:**
- Produces on `AdventureTilemap`:
  - Signals: `tile_entered(coord: Vector3i, encounter: AdventureEncounter, first_visit: bool, summary: String)`; `encounter_resolved(coord: Vector3i, summary: String)`; `map_changed`; `walk_refused(reason: StringName)`; `boss_revealed(coord: Vector3i)`.
  - `const REFUSED_STAMINA: StringName = &"stamina"`, `const REFUSED_ENCOUNTER: StringName = &"encounter"`.
  - `start_adventure_on_map(action_data: AdventureActionData, encounters: Dictionary[Vector3i, AdventureEncounter]) -> void` (what `start_adventure()` does after generating; `start_adventure()` calls it).
  - `select_choice(choice: EncounterChoice) -> void` (today's `_on_choice_selected`; the encounter panel's signal calls it until Task 10 removes the panel).
  - `get_current_tile() -> Vector3i`; `get_encounter_at(coord: Vector3i) -> AdventureEncounter` (null off the map); `is_tile_visited(coord: Vector3i) -> bool`; `is_tile_revealed(coord: Vector3i) -> bool`; `is_tile_completed(coord: Vector3i) -> bool`; `get_tile_summary(coord: Vector3i) -> String`; `get_seen_tiles() -> Array[Vector3i]` (visited and revealed; every map tile under dev reveal); `is_dev_reveal_all() -> bool`; `get_tile_world_centre(coord: Vector3i) -> Vector2` (`full_map.cube_to_local(coord) + full_map.position`).
  - `static func summary_for(choice: EncounterChoice, gold_earned: int) -> String`.

Rules:
- `tile_entered` fires on every arrival, the start tile and NoOp tiles included, after the tile is marked visited: `first_visit` is whether it was unvisited, `summary` the stored summary or `""`.
- `map_changed` fires at the end of every `_update_visible_map()` and after `stop_adventure()` clears the map.
- Summaries live in `_tile_summaries: Dictionary[Vector3i, String]` (cleared on stop). `_complete_current_tile(summary: String)` stores one and emits `encounter_resolved`. A won fight passes `summary_for(_current_combat_choice, gold_earned)`; a dialogue passes its choice's after `dialogue_ended`; any other choice passes its own.
- `summary_for`: a `CombatChoice` gives "Won · <gold> gold", or "Won" when `gold_earned` is 0; any other choice joins with " · " the `describe()` of each success effect, skipping one that is empty or equals `str(effect)` (the debug fallback), and gives "Done" when none is left.
- `walk_refused`: in `_on_tile_clicked`, the movement-locked check stays first and emits `REFUSED_ENCOUNTER` with the log line "Choose what to do here first"; too little Stamina emits `REFUSED_STAMINA` with "Too tired to walk · %d Stamina a step" % int(MOVEMENT_STAMINA_COST). In `_process_next_visitation`, running out mid-walk emits `REFUSED_STAMINA` and the same line. Clicks during a walk stay silent.
- `boss_revealed(coord)` fires where `_play_boss_reveal()` runs (first reveal only).

Fixture for this file and Tasks 4–5 (cube coords; `ADVENTURE_ACTION` = `spirit_valley_adventure_action.tres`): `(0,0,0)` NoOp (start); `(1,-1,0)` a COMBAT_REGULAR encounter with one `CombatChoice` (enemy `amorphous_spirit.tres`); `(0,1,-1)` and `(0,2,-2)` NoOp; `(-1,1,0)` a REST_SITE encounter with one `EncounterChoice` whose success effect is a `ChangeVitalsEffectData` with `health_change = 10`; `(2,-2,0)` a COMBAT_BOSS encounter (revealed only once `(1,-1,0)` is visited). Click a tile with `visible_map.tile_clicked.emit(visible_map.cube_to_map(coord))`.

- [x] **Step 1: Write the failing tests** (an `adventure_tilemap.tscn` instance, `start_adventure_on_map(ADVENTURE_ACTION, fixture)`, `watch_signals`):
  - `test_start_enters_the_start_tile` (`tile_entered` with `[Vector3i.ZERO, <start NoOp>, true, ""]`).
  - `test_arrival_emits_tile_entered_and_map_changed` (click `(0,1,-1)`, await the walk).
  - `test_low_stamina_click_is_refused` (Stamina 0: `walk_refused` `[&"stamina"]`, `LogManager.message_logged` with "Too tired to walk · 5 Stamina a step", the character does not move).
  - `test_walk_stopped_by_stamina_is_refused` (Stamina 5, click `(0,2,-2)`: refused after the first arrival).
  - `test_click_while_a_choice_waits_is_refused` (walk to `(1,-1,0)`, click `(0,1,-1)`: `[&"encounter"]` and "Choose what to do here first").
  - `test_rest_choice_resolves_with_its_effects` (`encounter_resolved` `[(-1,1,0), "+10 Health"]`, `is_tile_completed`, `get_tile_summary`).
  - `test_won_fight_summary` (select the combat choice, `handle_combat_result(true, 15)` → "Won · 15 gold").
  - `test_revisit_carries_the_summary` (resolve the rest, walk to `(0,0,0)` and back: `tile_entered` `[(-1,1,0), <rest>, false, "+10 Health"]`; a click right after is not refused).
  - `test_boss_reveal_emits_once` (walking to `(1,-1,0)` emits `boss_revealed` `[(2,-2,0)]` once).
  - `test_seen_tiles_and_dev_reveal` (start: the start tile plus its three map neighbours; dev reveal on: all six tiles; off: back).
  - `test_summary_for` (combat 15 and 0; ChangeVitals +10; a `TriggerEventEffectData` alone → "Done"; no effects → "Done").
  - `test_stop_clears_summaries_and_emits_map_changed`.
- [x] **Step 2: Run; expect failures.**
- [x] **Step 3: Implement.** `test_adventure_end_flow.gd` and `test_adventure_combat_count.gd` stay green.
- [x] **Step 4: Run the new file and both of those; green.**
- [x] **Step 5: Commit** `feat(adventure): emit the map's arrivals, refusals and resolutions`.

---

### Task 4: The map at zoom 1 (fog, veils, rims, route, character)

Skills: `godot-prompter:2d-essentials`, `godot-prompter:camera-system`, `godot-prompter:godot-testing`.

**Files:**
- Modify: `scenes/adventure/adventure_tilemap/adventure_tilemap.gd` + `.tscn`, `scenes/tilemaps/tilemap_tileset.tres` (source 9 `forest_veil_atlas`: `hex_forest_veil_atlas_ai.png`, region 164x190, the same 23 cells as source 8), `scenes/characters/main_character/character_body_2d.gd`
- Create: `scenes/adventure/adventure_route/adventure_route.gd` + `.tscn`
- Delete: `scenes/adventure/path_preview/`, `scenes/adventure/fog_veil_sprite.gd` + `.tscn`, `scenes/tilemaps/hex_hover_selector.gd` + `.tscn`, `assets/shaders/fog_of_war.gdshader` (nothing else uses them; grep again first)
- Test: `tests/integration/test_adventure_map_render.gd`, `tests/unit/test_adventure_route.gd`

**Interfaces:**
- Consumes: Task 1 (veil atlas), Task 3 (getters, `map_changed`).
- Produces:
  - `AdventureTilemap`: `const VEIL_ATLAS_SOURCE_ID: int = 9`; `const FOG_MARGIN: int = 8`; `const CAMERA_OFFSET: Vector2 = Vector2(0, 70)` (the current hex's centre at screen (960, 470)); `get_fog_tier_at(coord: Vector3i) -> int` (−1 for no fog). Nodes: `MapGround` (CanvasLayer −1) with `GroundRect` `#090E0E`, copied from `zone_tilemap.tscn`; `%AdventureFogMap` (a `hexagon_tile_map_layer.tscn` instance at (−82, −95) on `fog_tileset.tres`, under the visible map); `%CurrentRim` and `%HoverRim` (centred `Sprite2D`s over the tiles); `%AdventureRoute`; `%CharacterShadow`.
  - `class_name AdventureRoute extends Node2D`: `@export var dot_texture: Texture2D` (`map/lacquer_route_dot_lit_ai.png`); `set_route(centres: Array[Vector2]) -> void` (every hop's dots from `ZoneRoute.dot_positions(a, b)`); `clear() -> void`; `hide_passed(character_position: Vector2) -> void` (a dot of the first hop hides once the character's projection on that hop has passed it; later hops keep theirs); `get_dot_positions() -> PackedVector2Array`; `get_visible_dot_count() -> int`. Draws in `_draw()` as `ZoneRoute` does.
  - `character_body_2d.gd`: `@export var walk_snap_px: float = 1.0`; the whole-px walk stands the character on `(_exact_position / walk_snap_px).round() * walk_snap_px` (1.0 keeps the zone map as it is).

Rules:
- Fog: on start, each map change and stop, clear the fog layer and fill every cell within cube distance `adventure_data.max_distance_from_start + FOG_MARGIN` of the origin that is not in `get_seen_tiles()`: source `ZoneMapMath.fog_tier(cube, seen)`, atlas `Vector2i(ZoneMapMath.fog_art_index(cell), 0)`, written with `set_cell` (as `ZoneTilemap._draw_fog` does). Stop leaves it empty.
- Tiles: visited and dev-revealed tiles on source 8 at `HexForestAtlas.pick(cube)`; revealed tiles on source 9 at the same coords. `AdventureHighlightMap` and the grey overlay go (a cleared tile is marked by its coin, Task 5).
- Rims: `CurrentRim` (`map/lacquer_hex_current_ai.png`) on the current tile's centre, moved on each arrival. `HoverRim`: `map/lacquer_hex_hover_ai.png` over a hovered visited tile, `map/lacquer_hex_hover_in_ai.png` over a hovered revealed one; hidden over fog, over the current tile and while movement is locked; it stays on the destination during a committed walk, as the selector did.
- Route: hovering a seen tile shows the route from the current tile (`visible_map.cube_pathfind`); a click commits it until arrival, `hide_passed()` runs each frame, and each intermediate arrival resets it from the new current tile; arrival at the destination, an encounter hijack, a Stamina stop or stop clears it.
- Character: scale 2, `snap_walk_to_whole_px = true`, `walk_snap_px = 2.0`; `CharacterShadow` as in `zone_tilemap.tscn` (`map/lacquer_char_shadow_ai.png`, position (−6, 8), `centered = false`, z −1).
- Camera: zoom 1, `offset = CAMERA_OFFSET`; `CameraZoomController` comes off; `CameraClampController` stays (it is inert without boundaries).
- Boss reveal keeps the hit-stop (`Engine.time_scale` 0.25 for 0.15 s real time) and the camera push; `BossFlashLayer` and `BossFlashRect` go.
- `Atmosphere`, `FogLayer`/`FogOfWarRect`, `FogVeilContainer`, `HoverSelector`, `PathPreview`, `_update_fog_uniforms()` and the fog constants go. `EncounterIconContainer` and `AdventureMarker` stay until Task 5.

- [x] **Step 1: Write the failing tests.** Unit (`test_adventure_route.gd`): `test_route_dots_follow_each_hop` (two hops → `dot_positions(a, b) + dot_positions(b, c)`); `test_hide_passed_hides_first_hop_dots_one_at_a_time` (character at the hop's midpoint → three dots of the first hop hidden, the next hop's all visible); `test_clear_empties_the_route`. Integration (Task 3's fixture, `start_adventure_on_map`):
  - `test_camera_is_fixed_at_zoom_one` (zoom `Vector2.ONE`, offset (0, 70), no `CameraZoomController` child).
  - `test_fog_tiers_around_seen_tiles` (a cell next to a revealed tile is tier 1, two away tier 2, far tier 3; seen cells have none).
  - `test_fog_reaches_past_the_map` (a cell at distance `max_distance_from_start + 8` has fog; one at + 9 has none).
  - `test_revealed_tile_uses_the_veil_source` (source 9 at `HexForestAtlas.pick(cube)`); `test_visited_tile_uses_the_forest_source` (source 8).
  - `test_current_rim_follows_the_player` (after a walk, at `get_tile_world_centre(current)`).
  - `test_hover_rims` (visited → hover texture; revealed → hover_in; fog → hidden).
  - `test_hover_shows_the_route` (walk to `(0,1,-1)`, then hover `(1,-1,0)`: the route runs through the start, two hops' dots).
  - `test_character_is_drawn_at_2x_with_the_kit_shadow`.
  - `test_walk_moves_in_even_px` (sampled each physics frame mid-walk, x and y are even).
  - `test_old_map_layers_are_gone` (no `FogLayer`, `FogVeilContainer`, `HoverSelector`, `PathPreview`, `Atmosphere`, `BossFlashLayer`, `AdventureHighlightMap`).
  - `test_boss_reveal_keeps_the_hit_stop` (`Engine.time_scale` 0.25 right after the reveal, 1.0 after 0.3 s).
- [x] **Step 2: Run; expect failures.**
- [x] **Step 3: Implement; `--import`.** Task 3's file stays green; `test_zone_travel.gd` stays green (the walk default is unchanged).
- [x] **Step 4: Run the new files, Task 3's, `test_zone_travel.gd` and `test_adventure_end_flow.gd`; green. Capture `adventure_tilemap.tscn` in a scratch scene that starts the fixture (not committed) and compare with the mock's walk screen.**
- [x] **Step 5: Commit** `feat(adventure): draw the map at zoom 1 with fog tiers, veils, rims and route dots`.

---

### Task 5: Encounter coins

Skills: `godot-prompter:hud-system`, `godot-prompter:2d-essentials`, `godot-prompter:godot-testing`.

**Files:**
- Create: `scenes/adventure/adventure_map_markers/adventure_map_markers.tscn` + `.gd`, `scenes/adventure/adventure_map_markers/encounter_coin/encounter_coin.tscn` + `.gd`
- Modify: `scenes/adventure/adventure_tilemap/adventure_tilemap.gd` + `.tscn`
- Delete: `scenes/adventure/adventure_marker/`
- Test: `tests/unit/test_encounter_coin.gd`, `tests/integration/test_adventure_map_markers.gd`

**Interfaces:**
- Consumes: Task 1 (tokens, spent glyphs), Task 3 (getters and signals).
- Produces:
  - `class_name EncounterCoin extends Control` (54x54, mouse ignored): `enum Face { GLYPH, UNKNOWN, CLEARED, BOSS }` (frames 0–3); `setup(face: Face, glyph: Texture2D, glyph_frame_size: Vector2i, glyph_frames: int, frame_seconds: float) -> void`; `get_face() -> Face`; `get_glyph_texture() -> Texture2D`; `shake() -> void`; `is_shaking() -> bool`. Statics: `needs_coin(encounter: AdventureEncounter, visited: bool, dev_revealed: bool) -> bool` (false when the tile is visited or dev revealed and its encounter is null or a `NoOpEncounter`: a revealed empty tile keeps its `?`); `face_for(encounter: AdventureEncounter, visited: bool, completed: bool, dev_revealed: bool) -> Face` (in order: visited and completed CLEARED; visited GLYPH; the boss BOSS; dev revealed GLYPH; else UNKNOWN); `glyph_for(type: AdventureEncounter.EncounterType, cleared: bool) -> Texture2D` (regular and ambush `combat_icon.png`, elite `elite.png`, rest `rest-sheet.png`, boss `boss_spritesheet.png`, treasure, trap; cleared: `adv_glyph_<kind>_spent_light_ai.png`); `glyph_frame_size_for(type) -> Vector2i` (trap 32x32, else 64x64); `glyph_frames_for(type: AdventureEncounter.EncounterType, cleared: bool) -> int` (rest 5, boss 7, cleared or other 1); `frame_seconds_for(type) -> float` (boss 0.2, rest 0.4, else 0.0). Nodes: `Token` (`LacquerStripRect`, the tokens strip, frame 54x54), `Glyph` (`LacquerStripRect` shown at 32x32, at (10, 10)). Frames step in `_process`.
  - `class_name AdventureMapMarkers extends CanvasLayer` (layer 1): `@export var map: AdventureTilemap`; `rebuild() -> void`; `get_coin(coord: Vector3i) -> EncounterCoin` (null when none); `get_coin_count() -> int`; `const COIN_RISE: float = 8.0`; `const COIN_RISE_HERE: float = 56.0` (the game's character stands on its tile centre with its head 16 px above it, higher than the mock's, so the coin rises 56 to keep 14 px clear of the head).

Rules: a coin for each tile in `map.get_seen_tiles()` that `needs_coin()` (dev revealed = `map.is_dev_reveal_all()` and not visited); its face from `face_for()`. Each frame every coin sits at `((canvas * map.get_tile_world_centre(coord)) - Vector2(26, 26 + rise)).round()` with `canvas = map.get_global_transform_with_canvas()` and rise `COIN_RISE_HERE` on the current tile, else `COIN_RISE`. Rebuild on `map_changed` and `encounter_resolved`; `boss_revealed(coord)` shakes that coin. Coins appear and go outright. `AdventureTilemap` instances the layer in its `.tscn` (`map` = its root) and drops `EncounterIconContainer`, `_encounter_icons`, `_update_cell_highlight()`, `_despawn_encounter_icon()`, the pop-in tweens of `_animate_reveal_stagger()` (its boss check stays) and `AdventureMarker`.

- [x] **Step 1: Write the failing tests.** Unit: `test_needs_coin`; `test_face_for_each_state`; `test_glyph_for_each_type`; `test_animated_glyphs` (boss 7 frames at 0.2 s, rest 5 at 0.4 s); `test_shake_steps` (after `shake()`, the coin's offset follows `MapGlyph.shake_offset_at()` at 0.1 and 0.2 s and is 0 after 0.44 s). Integration (Task 3's fixture):
  - `test_start_coins_are_unknown` (`(1,-1,0)`, `(0,1,-1)`, `(-1,1,0)` UNKNOWN; no coin on the start tile).
  - `test_visited_fight_shows_its_glyph`; `test_visited_noop_has_no_coin`; `test_resolved_tile_turns_carved`.
  - `test_boss_coin_appears_once_revealed_and_shakes`.
  - `test_coin_rides_above_the_character_here` (top-left y = screen centre y − 56 − 26, and the coin's bottom stays above the character's drawn top).
  - `test_coins_follow_the_camera` (moving the character 100 px right moves every coin 100 px left).
  - `test_dev_reveal_toggle_round_trip` (Review Focus 2: on → every unvisited encounter tile has a GLYPH coin, the boss its BOSS coin, NoOp tiles none; off → the normal set).
  - `test_stop_removes_every_coin`.
- [x] **Step 2: Run; expect failures.**
- [x] **Step 3: Implement; `--import`.**
- [x] **Step 4: Run the new files and Tasks 3–4's; green. Capture against the mock's walk and encounter screens.**
- [x] **Step 5: Commit** `feat(adventure): mark encounters with lacquer coins`.

---

### Task 6: The vitals cabinet

Skills: `godot-prompter:hud-system`, `godot-prompter:godot-ui`, `godot-prompter:godot-testing`.

**Files:**
- Create: `scenes/adventure/vitals_plate/vitals_plate.tscn` + `.gd`, `scenes/ui/combat/buff_tooltip/buff_tooltip.tscn` + `.gd`
- Modify: `scripts/resource_definitions/combat/buff_effect_data.gd`, `scenes/ui/combat/combat_buff_tooltip/combat_buff_tooltip.gd` (calls `describe()`; deleted in PR 2)
- Test: `tests/integration/test_vitals_plate.gd`, `tests/unit/test_buff_effect_describe.gd`

**Interfaces:**
- Consumes: Tasks 1–2.
- Produces:
  - `class_name VitalsPlate extends Control` (at (24, 24), 440x252, lacquer theme, mouse STOP): `setup_vitals(vitals_manager: VitalsManager) -> void` (disconnects any previous manager, connects the three vitals signals, reads everything; called at every run's start); `bind_buffs(buff_manager: CombatBuffManager) -> void`; `unbind_buffs() -> void`; `shake_stamina() -> void`; `is_stamina_shaking() -> bool`; `const MAX_BUFF_SOCKETS: int = 3`.
  - `class_name BuffTooltip extends PanelContainer` (`board9.tres`, 304 wide, hugs its height): `show_for_buff(buff: ActiveBuff, top_left: Vector2) -> void`; `hide_tooltip() -> void`. Content: the name (`buff_id.capitalize()`, `LabelLacquerPopoverTitle`); "<n> s left" with " · ×<stacks>" when stacked (`LabelLacquerDetail`, whole seconds rounded up, refreshed while shown); a `lacquer_line_ai.png` divider; `describe()` (`LabelLacquerPopoverBody`). It hides when its buff ends.
  - `BuffEffectData.describe() -> String`: today's `CombatBuffTooltip._build_description()` text, moved ("Strength x1.5", "2.0 damage per second", "Outgoing damage x1.5", "Incoming damage x0.8").

Layout (cabinet-local; screen = local + (24, 24)): board `lacquer_cult_ai.png` at (0, 0); `HealthOrb` 80x80 at (18, 16) (`lacquer_orb_health_ai.png`, a local-to-scene `ShaderMaterial` on `lacquer_madra_orb.gdshader` with light `#FFD9D2`, pale `#E8737A`, blue `#B8304A`); "Health" (`LabelLacquerDetail`) at (114, 22); a value row at (114, 43) built like `CultivatorPlate`'s Madra row (value `LabelLacquerBig` cream, " / max" tan); buff sockets at (294, 52), (338, 52), (382, 52) (`socket_buff`, icon 32x32 at +4, a `lacquer_seal_count_ai.png` count seal with `LabelLacquerSeal` at the socket's top right, a `frame_brass` `LacquerFrameOverlay` that flashes once when the buff lands), filled from the left; `MadraOrb` at (18, 108) (the zone's Madra strip, frame 0, default orb colours); "Madra" at (114, 110); value row at (114, 131); divider at (16, 198); `StaminaRow` at (0, 214): `lacquer_mini_stamina_ai.png` at (18, 5), "Stamina" at (40, 3), a `LacquerRod` (stamina rod, steps 119) at (112, 7), the value (`LabelLacquerName`, " / max" tan) right-aligned in (342, 0, 80, 20). Health shows `ceili(current)`, Madra and Stamina `floori(current)`, max `floori(max)`; orbs fill to `clamp(current / max)`. The buff tooltip opens with its top-left at screen (472, socket y). The sockets show only while bound.

- [x] **Step 1: Write the failing tests** (the plate with `PlayerManager.vitals_manager` on a fresh save; buffs on a `combatant_node.tscn` player set up as `test_adventure_combat_victory_event.gd` sets up its fight):
  - `test_shows_the_runs_vitals` (142 / 160, 80 / 120, 80 / 80).
  - `test_orbs_fill_to_the_fraction` (80 of 160 → health `progress` 0.5; 30 of 120 → Madra 0.25).
  - `test_health_orb_uses_the_crimson_ramp` (its material's light, pale and blue).
  - `test_follows_the_vitals_signals` (`apply_vitals_change(-20)` → "122").
  - `test_stamina_rod_steps` (40 of 80 → `get_step()` 60).
  - `test_buffs_fill_from_the_left_and_clear`; `test_a_new_buff_flashes_its_socket`; `test_stacks_show_a_count_seal`; `test_more_than_three_buffs_show_three`; `test_unbind_hides_every_socket`.
  - `test_hovering_a_buff_shows_its_tooltip` (name and "<n> s left"); `test_tooltip_hides_when_its_buff_ends`.
  - `test_stamina_shake_runs_in_even_steps` (x offset −8 at 0.1 s, 0 and not shaking after 0.5 s).
  - Unit: `test_describe_attribute_modifier`, `test_describe_damage_over_time`, `test_describe_outgoing_and_incoming`.
- [x] **Step 2: Run; expect failures.**
- [x] **Step 3: Build the scenes and scripts; `--import`.**
- [x] **Step 4: Run; green. Capture the cabinet alone and compare with the mock's left column.**
- [x] **Step 5: Commit** `feat(adventure): add the vitals cabinet and the lacquer buff tooltip`.

---

### Task 7: The chest and the run clock

Skills: `godot-prompter:godot-ui`, `godot-prompter:hud-system`, `godot-prompter:godot-testing`.

**Files:**
- Create: `scenes/adventure/adventure_chest/adventure_chest.tscn` + `.gd`, `scenes/adventure/adventure_chest/adventure_chest_page.gd`, `scenes/adventure/run_clock/run_clock.tscn` + `.gd`
- Test: `tests/unit/test_run_clock.gd`, `tests/integration/test_adventure_chest.gd`

**Interfaces:**
- Consumes: Task 1 (timer textures, hourglass).
- Produces:
  - `class_name AdventureChestPage extends Control`: `signal content_resized`; `get_content_height() -> float` (default `size.y`).
  - `class_name AdventureChest extends Control` (at (1456, 24), 440 wide, lacquer theme, mouse STOP): `set_title(text: String) -> void`; `get_run_clock() -> RunClock`; `relayout() -> void`; `const CHEST_TOP_HEIGHT: float = 128.0`, `CHEST_BOTTOM_HEIGHT: float = 48.0`, `MIN_CHEST_HEIGHT: float = 176.0`, `PAGE_TOP: float = 82.0`, `GAP_UNDER_PAGE: float = 24.0`. `%PageSlot` (408 wide at (16, 82)) holds the pages; height = max(176, 82 + page.get_content_height() + 24), relaid on the visible page's `content_resized`; `ChestTop`, tiled `ChestMid`, `ChestBottom` sized as `ZonePanel._relayout()` does. Title `LabelLacquerZoneName` at (16, 18), 312 wide, ellipsis.
  - `class_name RunClock extends Control` (88x36 at chest-local (336, 22)): `bind_timer(timer: Timer) -> void`; `is_low_shown() -> bool`; `const LOW_SECONDS: float = 30.0`; static `format_time(seconds_left: float) -> String` ("%d:%02d" of `floori(seconds_left / 60.0)` and `int(seconds_left) % 60`, as `TimerPanel` today); static `is_low(seconds_left: float) -> bool` (≤ `LOW_SECONDS`). Nodes: `Recess` (`lacquer_timer_ai.png`, `lacquer_timer_low_ai.png` when low), the hourglass mini at (12, 10), `TimeLabel` (`LabelLacquerNowName`, centred in (32, 7, 46, 22)), updated in `_process` while the timer runs. Nothing flashes.

- [x] **Step 1: Write the failing tests.** Unit: `test_format_time` (125.9 → "2:05", 59.9 → "0:59", 0 → "0:00", 600 → "10:00"); `test_low_at_thirty_not_thirty_one` (30.0 and 0 low; 30.4 and 31 not). Integration: `test_clock_follows_its_timer` (90 s → "1:30"); `test_clock_turns_to_the_seal_when_low`; `test_title_ellipsizes` (Review Focus 3: a 60-character title keeps its label within 312 px and the chest 440 wide); `test_hugs_its_page` (a plain `AdventureChestPage` 300 tall → chest 406, `ChestMid` 230, `ChestBottom` at 358); `test_never_shorter_than_176`; `test_relayouts_on_content_resized`.
- [x] **Step 2: Run; expect failures.**
- [x] **Step 3: Build; `--import`.**
- [x] **Step 4: Run; green.**
- [x] **Step 5: Commit** `feat(adventure): add the adventure chest and its run clock`.

---

### Task 8: The expedition page and the fight rules

Skills: `godot-prompter:godot-ui`, `godot-prompter:hud-system`, `godot-prompter:godot-testing`.

**Files:**
- Create: `scenes/adventure/adventure_chest/expedition_page/expedition_page.tscn` + `.gd`, `scenes/adventure/adventure_chest/choice_drawer/choice_drawer.tscn` + `.gd`
- Modify: `scenes/adventure/adventure_chest/adventure_chest.tscn` (instances the page in `%PageSlot`) + `.gd` (`get_expedition_page()`), `scenes/combat/combatant/vitals_manager/vitals_manager.gd`, `scenes/combat/adventure_combat/adventure_combat.gd`
- Test: `tests/unit/test_fight_rules.gd`, `tests/integration/test_expedition_page.gd`

**Interfaces:**
- Consumes: Task 5 (`EncounterCoin.glyph_for()`, `glyph_frame_size_for()`), Task 7.
- Produces:
  - `static func VitalsManager.max_health_for(attributes: CharacterAttributesData) -> float` (Body × 10); `_get_max_health()` returns it.
  - `static func AdventureCombat.gold_reward_for(choice: CombatChoice, adventure_action: AdventureActionData) -> int` (floor of `enemy_pool[0].base_gold_drop` × `choice.gold_multiplier` × the action's `gold_multiplier`, or 1 with no action, × `CharacterManager.get_gold_multiplier()`; 0 for an empty pool); `_calculate_gold_reward()` returns it and keeps its log line.
  - `class_name ExpeditionPage extends AdventureChestPage`: `signal choice_selected(choice: EncounterChoice)`; `show_tile(encounter: AdventureEncounter, summary: String, adventure_action: AdventureActionData) -> void`; `show_resolved(summary: String) -> void`; `set_run_stats(fights: int, fights_total: int, gold: int, explored: int, explored_total: int, loot: Array[ItemDefinitionData]) -> void`; `shake_here() -> void`; `is_here_shaking() -> bool`; `get_drawer(index: int) -> ChoiceDrawer`; `const MAX_DRAWERS: int = 3`, `MAX_LOOT: int = 6`; statics `kind_word(type: AdventureEncounter.EncounterType) -> String`, `kind_tag(type: AdventureEncounter.EncounterType) -> String` (FIGHT for regular and ambush, ELITE, BOSS, REST, TREASURE, TRAP), `here_line(encounter: AdventureEncounter) -> String`, `choice_detail(choice: EncounterChoice, adventure_action: AdventureActionData) -> String`, `walk_hint(stamina: float) -> String`.
  - `class_name ChoiceDrawer extends Control` (392x72): `signal pressed`; `setup(choice: EncounterChoice, glyph: Texture2D, glyph_frame_size: Vector2i, detail: String) -> void`; `is_available() -> bool`.
  - `AdventureChest.get_expedition_page() -> ExpeditionPage`.

Layout (page-local; screen = local + (1472, 106)): `lacquer_now_plate_ai.png` at (12, −11) with "Here" (`LabelLacquerLegend`); `lacquer_now_tray_ai.png` at (0, 0); `lacquer_socket_glyph_ai.png` at (16, 20); the glyph 32x32 at (24, 28); the name (`LabelLacquerNowName`) at (78, 18), 236 wide, ellipsis; the tag (`lacquer_tag_ai.png` + `LabelLacquerTag`) at (320, 17), or the BOSS seal (`lacquer_seal_locked_ai.png` + `LabelLacquerSeal`) at (308, 17); the line (`LabelLacquerDetail`) at (78, 48), 316 wide, ellipsis. A 408-wide `VBoxContainer` at (0, 104): lore (`LabelLacquerLore`, wrapping), walk hint (`LabelLacquerDetail`), divider (`lacquer_line_ai.png`, 14 above), three `ChoiceDrawer`s (12 above, 8 apart), 28 px, then the Run ledger (408x128): "Run" (`LabelLacquerSection`) and a groove (`lacquer_groove_ai.png` tiled, `lacquer_groove_end_ai.png`); figures at y 36: `combat_icon.png` 32x32 at (0, 36) with the value (`LabelLacquerName`) at (40, 34) and "fights" (`LabelLacquerDetail`) at (40, 54); `gold_icon.png` at (140, 36), (180, 34), "gold"; `map_icon.png` at (280, 36), (320, 34), "explored"; "Loot" at (0, 96); six `socket_buff`s at x 48 + 46·i, y 86, item `icon` 32x32 at +4. Content height = the VBox's bottom. The drawer copies `ZoneActionButton`'s face, offsets and frames: face `lacquer_drawer_ai.png`, glyph 32x32 at (16, 20), title (`LabelLacquerName`) at (64, 14) 232 wide, tag at (304, 13), LOCKED seal (`lacquer_seal_locked_ai.png`) at (292, 13), detail (`LabelLacquerDetail`) at (64, 38) 316 wide, a `frame_hover` overlay on hover when available.

Rules:
- `show_tile` with a NoOp, or an encounter without choices: name "Open ground" in tan, no glyph or tag, line "Click a hex to walk · 5 Stamina a step"; lore, hint, divider and drawers hidden.
- Unresolved (`summary` empty): name `encounter_name`; tag `kind_tag` (the BOSS seal for a boss); line `here_line`; glyph `glyph_for(type, false)` frame 0; lore `description`; one drawer per choice (glyph `ic_story_ai.png` for a `DialogueChoice`, else the encounter's; tag FIGHT for a `CombatChoice`, TALK for a `DialogueChoice`, none otherwise; detail `choice_detail`); hint hidden.
- Resolved (`summary` set, or `show_resolved`): tag CLEARED, line = the summary, lore `text_description_completed` or "Encounter completed.", walk hint shown, drawers hidden.
- `here_line`: for a fight, "<kind_word> · <enemy_pool[0].character_name> · <max_health_for(attributes) as a whole number> Health" from the first `CombatChoice`; otherwise `kind_word` (Fight, Ambush, Elite, Boss, Rest, Trap, Treasure).
- `choice_detail`: the choice's `tooltip` when set; else for a `CombatChoice` "Uses <enemy_pool[0] ability names joined with ", "> · <gold_reward_for(choice, action)> gold if you win"; else "".
- `walk_hint(stamina)`: "Click a hex to walk · 5 Stamina a step · %d steps left" % floori(stamina / MOVEMENT_STAMINA_COST); refreshed on `PlayerManager.vitals_manager.stamina_changed`.
- A drawer: available, or locked (`not evaluate_requirements()`: tan title, LOCKED seal, no press), or completed (`is_completed()`: `completed_label` in tan, no press). Only an available drawer's press emits `choice_selected`. Every content change emits `content_resized`.

- [x] **Step 1: Write the failing tests.** Unit (`test_fight_rules.gd`): `test_max_health_is_body_times_ten` (Body 12 → 120.0, equal to a `VitalsManager`'s `max_health` with those attributes after `_ready`); `test_gold_reward_multiplies_every_factor`; `test_gold_reward_without_an_action`; `test_gold_reward_empty_pool_is_zero`; `test_fight_pays_the_rule` (an `AdventureCombat` fight as in `test_adventure_combat_victory_event.gd`: the win reports `gold_reward_for(choice, null)`). Integration (the page alone, fresh save, encounters built in code or loaded from `resources/adventure/encounters/shallow_woods/`):
  - `test_fight_tile_here_tray` (Amorphous Spirit encounter: name, FIGHT, "Fight · Amorphous Spirit · <n> Health").
  - `test_boss_tag_is_a_seal`; `test_rest_tile_line_is_its_kind`; `test_noop_tile`.
  - `test_drawer_detail_uses_the_tooltip` (the Aura Well's "Rest": "Draw on the well's aura to restore yourself.").
  - `test_combat_drawer_lists_techniques_and_gold` ("Uses Madra Lash · <gold> gold if you win").
  - `test_locked_choice`; `test_completed_choice_shows_its_completed_label`; `test_pressing_an_available_drawer_emits_choice_selected`.
  - `test_resolved_tile_shows_summary_and_no_drawers` (`show_resolved("+10 Health")` with Stamina 80: CLEARED, "+10 Health", the completed text, "… · 16 steps left").
  - `test_revisit_resolved_tile_shows_summary_and_no_drawers` (Review Focus 5); `test_completed_text_falls_back`.
  - `test_run_ledger_values` ("1 / 13", "20", "3 / 23", the first loot socket shows the item's icon); `test_ledger_keeps_the_latest_six`.
  - `test_long_texts_do_not_widen_the_chest` (Review Focus 3: 80-character name, label and tooltip; the page stays 408 wide).
  - `test_here_shake_runs_in_even_steps`; `test_content_height_follows_the_tile` (two drawers vs none: heights differ and `content_resized` fires).
- [x] **Step 2: Run; expect failures.**
- [x] **Step 3: Implement; `--import`.**
- [x] **Step 4: Run the new files, `test_adventure_combat_victory_event.gd` and the combat suites; green. Capture the chest with the page against the mock's encounter screen, and the Aura Well with its "Mark down the location" choice completed: if BM Euljiro draws a missing-glyph box for the ✓ in "✓ Location noted", tell the user (spec, Risks) instead of editing the data.**
- [x] **Step 5: Commit** `feat(adventure): show the tile, its choices and the run in the chest`.

---

### Task 9: The technique dock

Skills: `godot-prompter:hud-system`, `godot-prompter:godot-ui`, `godot-prompter:shader-basics`, `godot-prompter:input-handling`, `godot-prompter:godot-testing`.

**Files:**
- Create: `scenes/ui/combat/technique_dock/technique_dock.tscn` + `.gd`, `scenes/ui/combat/technique_dock/technique_slot/technique_slot.tscn` + `.gd`, `scenes/ui/combat/technique_dock/cast_tray/cast_tray.tscn` + `.gd`, `scenes/ui/combat/technique_dock/technique_tooltip/technique_tooltip.tscn` + `.gd`, `assets/shaders/lacquer_cooldown_sweep.gdshader`
- Modify: `scenes/abilities/ability_row/ability_row.gd`
- Test: `tests/unit/test_technique_slot_math.gd`, `tests/integration/test_technique_dock.gd`

**Interfaces:**
- Consumes: Tasks 1–2.
- Produces:
  - `static func AbilityRow.format_damage(ability_data: AbilityData, caster_attributes: CharacterAttributesData) -> String`: "about <roundi(effects_on_target[0].calculate_value(attributes))> <DamageType name capitalised> damage" when the first target effect is DAMAGE, else "".
  - `class_name TechniqueSlot extends Control` (80x80, mouse STOP): `enum SlotState { EMPTY, PREVIEW, ACTIVE }`; signals `pressed`, `hovered(ability_data: AbilityData)`, `unhovered`; `show_empty(slot_index: int) -> void`; `show_preview(data: AbilityData, slot_index: int) -> void`; `bind(instance: CombatAbilityInstance, slot_index: int, vitals_manager: VitalsManager) -> void`; `refuse() -> void` (shake); `is_shaking() -> bool`; `get_state() -> SlotState`; `get_ability_instance() -> CombatAbilityInstance`; `get_sweep_step() -> int`; `const SWEEP_STEPS: int = 24`; statics `sweep_step(time_left: float, duration: float) -> int` (`clampi(floori((1.0 - time_left / duration) * SWEEP_STEPS + 1e-6), 0, SWEEP_STEPS)`; `SWEEP_STEPS` when `time_left <= 0` or `duration <= 0`), `seconds_text(time_left: float) -> String` (`str(ceili(time_left))`, "" at 0).
  - `class_name CastTray extends Control` (476x44 at dock-local (0, −52)): `bind(ability_manager: CombatAbilityManager) -> void`; `unbind() -> void`.
  - `class_name TechniqueTooltip extends PanelContainer` (`board9.tres`, 304 wide, hugs its height): `show_for_ability(data: AbilityData, slot: Control, cast_tray_shown: bool) -> void`; `hide_tooltip() -> void`.
  - `class_name TechniqueDock extends Control` (at (722, 920), 476x136, lacquer theme, mouse STOP): `signal ability_selected(instance: CombatAbilityInstance)`; `show_loadout() -> void`; `bind(ability_manager: CombatAbilityManager, vitals_manager: VitalsManager) -> void`; `reset() -> void`; `is_active() -> bool`; `get_slot(index: int) -> TechniqueSlot`; `get_cast_tray() -> CastTray`; `get_tooltip() -> TechniqueTooltip`.
  - `lacquer_cooldown_sweep.gdshader` (canvas_item): `uniform float progress : hint_range(0.0, 1.0) = 1.0`. Per 2 px cell of the 64x64 icon, the angle of the cell's centre around (32, 32), from 12 o'clock clockwise (`mod(atan(cx - 32.0, -(cy - 32.0)), TAU)`); a cell at or past `floor(progress * 24.0 + 0.5) / 24.0 * TAU` takes the colour of its luminance band (`0.2126 R + 0.7152 G + 0.0722 B` in 0–1: below 60/255 `#151A18`, 140/255 `#39423E`, 200/255 `#4B5550`, else `#5F6A65`), keeping its alpha; other cells keep the icon. No alpha blending, no `smoothstep`, no `TIME`. The mock's `adv_ability_*_cd_strip_ai.png` frames are its reference output.

Layout (dock-local; screen = local + (722, 920)): board `lacquer_tdock_ai.png` at (0, 0); slots at (30, 18), (142, 18), (254, 18), (366, 18). A slot: `lacquer_slot_ai.png` at (0, 0); the icon 64x64 at (8, 8) with a local-to-scene `ShaderMaterial` on the sweep shader; the seconds (`LabelLacquerCooldown`) centred in (8, 26, 64, 28); `lacquer_keycap_ai.png` at (−6, −6) with the key (`LabelLacquerHotkey`, "Q" "W" "E" "R" from the input map as `AbilityButton._get_key_label()` reads it); the cost line centred under the slot at y 90 (`lacquer_mini_madra_ai.png`, `lacquer_mini_stamina_ai.png` or `lacquer_mini_health_ai.png` at 16, the cost in `LabelLacquerDetail`); `CastFrame` and `ReadyFlash` (`frame_brass` `LacquerFrameOverlay`s) and `HoverFrame` (`frame_hover`). The cast tray: `lacquer_cast_tray_ai.png`, the name (`LabelLacquerName`) at (16, 12), a `LacquerRod` (cast rod, steps 119) at (170, 17), the time (`RichTextLacquer`, `LacquerText.decimal_bbcode("%.1f s")`) right-aligned in (300, 12, 160, 20). The tooltip: the name (`LabelLacquerPopoverTitle`); the timing ("Cast <t> s · Cooldown <c> s" or "Instant · Cooldown <c> s", with `AbilityRow.format_seconds()` and `decimal_bbcode`, `RichTextLacquer`); the cost row (mini icon + `AbilityRow.format_cost()` in cream); the damage line (`format_damage()` with `CharacterManager.get_total_attributes_data()`, hidden when empty); a divider; the description (`LabelLacquerPopoverBody`, wrapping at 272). Its bottom sits at screen y 912 (860 while the cast tray shows), its left at the slot's x − 8, kept on screen.

Rules:
- Slot states: EMPTY shows the socket and the key cap only; PREVIEW shows the icon, the cost, a tan key; ACTIVE shows a cream key and the cost in cream, tan while unaffordable (checked each frame while not cooling or casting, as `AbilityButton._process` does). Cooling: on bind and on `cooldown_started`/`cooldown_updated`, `progress` = `sweep_step(time_left, cooldown_timer.wait_time) / 24.0` and the seconds show (abilities start on a 1.5 s cooldown before the dock binds, so `bind` reads the timer); `cooldown_ready` → `progress` 1, seconds hidden, `ReadyFlash.flash(1)`. Casting: `CastFrame` shown from `cast_started` to `cast_finished`/`cast_cancelled`. Hover → `HoverFrame` and the tooltip.
- The dock ports `AbilitiesPanel`: the loadout preview (`AbilityManager.get_equipped_abilities()` placed by `get_ability_at_slot()`), binding instances to their equip slots (first free slot otherwise), Q/W/E/R (`ability_slot_1`–`_4`) in `_unhandled_input` only while active and visible, and clicks. A press asks `ability_manager.can_cast_ability_instance(instance, null)`: refused → `slot.refuse()` and nothing else (no log line); accepted → `ability_selected`.
- The cast tray shows outright on any bound instance's `cast_started` (name, rod at 1 − time_left / duration, time), steps on `cast_updated`, hides on `cast_finished` and `cast_cancelled`.

- [x] **Step 1: Write the failing tests.** Unit: `test_sweep_step_counts_24_steps` (3 of 3 → 0; 1.5 of 3 → 12; 0.01 of 3 → 23; 0 → 24; duration 0 → 24); `test_seconds_round_up` (2.1 → "3", 3.0 → "3", 0 → ""); `test_format_damage` (Basic Strike → "about <n> Physical damage" with `calculate_value`; Enforce → ""). Integration (the dock alone; fresh save; a player `combatant_node.tscn` set up with the equipped abilities and `PlayerManager.vitals_manager`):
  - `test_preview_shows_the_equipped_loadout` (equipped slots PREVIEW with tan keys, the rest EMPTY).
  - `test_bind_activates_the_slots`; `test_initial_cooldown_shows_the_sweep` (right after bind: step < 24 and "2").
  - `test_cooldown_ready_flashes_the_slot`; `test_casting_shows_the_brass_frame_and_the_cast_tray` (Basic Strike's 0.5 s cast; hidden after).
  - `test_refused_press_shakes_and_does_not_emit`; `test_ready_press_emits_ability_selected` (an `InputEventAction` for `ability_slot_1`, pressed, sent with `get_viewport().push_input()` so it reaches `_unhandled_input`; `Input.action_press()` sends no event).
  - `test_unaffordable_cost_turns_tan`.
  - `test_keys_do_nothing_outside_a_fight` (Review Focus 4).
  - `test_tooltip_sits_above_the_dock` (bottom 912, left slot x − 8; 860 with the cast tray shown); `test_tooltip_content` (Empty Palm: "Instant · Cooldown 3 s", "8 Madra", its damage line, its description).
  - `test_reset_returns_to_preview` (and the cast tray hides).
- [x] **Step 2: Run; expect failures.**
- [x] **Step 3: Implement; `--import`.**
- [x] **Step 4: Run; green. Capture the dock alone mid-cooldown and compare with the mock (`demo=cd`).**
- [x] **Step 5: Commit** `feat(combat): add the technique dock with the radial cooldown sweep`.

---

### Task 10: Put the frame into the adventure view

Skills: `godot-prompter:scene-organization`, `godot-prompter:state-machine`, `godot-prompter:godot-testing`.

**Files:**
- Modify: `scenes/adventure/adventure_view/adventure_view.tscn` + `.gd`, `scenes/adventure/adventure_tilemap/adventure_tilemap.gd` + `.tscn` (drop `EncounterInfoPanel` and its `CanvasLayer`), `scenes/ui/main_view/states/adventure_view_state.gd`, `tests/unit/test_view_state_hud_positions.gd`
- Delete: `scenes/ui/combat/player_hud/`, `scenes/ui/combat/abilities_panel/`, `scenes/ui/combat/ability_button/`, `scenes/ui/combat/combat_ability_tooltip/`, `scenes/ui/combat/resource_orb/`, `scenes/adventure/adventure_view/timer_panel.gd`, `scenes/adventure/adventure_tilemap/encounter_info_panel.gd` + `.tscn`, `encounter_choice_button.gd` + `.tscn`, and the styleboxes `combat/panel_dock`, `combat/bar_fill_stamina`, `combat/cost_line`, `combat/orb_ring`, `combat/orb_shine`, `combat/slot_cast_glow`, `combat/panel_keyhint`, `adventure/panel_timer`, `adventure/panel_encounter`, `zones/action_card_normal`, `zones/action_card_hover` (each `.tres`; grep every one for other users first). The art they leave unused (`ability_button_border.png`, `ability_button_overlay.png`, `time_icon.png` is still used by the end card) stays: user art is deleted only on the user's word (spec, Removed).
- Test: `tests/integration/test_adventure_view_frame.gd`, rewrite the adventure tests in `tests/unit/test_view_state_hud_positions.gd`

**Interfaces:**
- Consumes: Tasks 3–9.
- Produces: `AdventureView` nodes `%VitalsPlate` (at (24, 24)), `%AdventureChest` (1456, 24), `%TechniqueDock` (722, 920) after `CombatView`, and `%RunTimer` (one-shot `Timer`, replacing `TimerPanel`'s); `signal run_stats_changed`; `get_run_timer() -> Timer`. `AdventureViewState` no longer moves the Log or Goals or hides the cords.

Wiring in `AdventureView`:
- `start_adventure`: `vitals_plate.setup_vitals(PlayerManager.vitals_manager)` (where `player_hud.setup_vitals` was); `technique_dock.show_loadout()`; `adventure_chest.set_title(action_data.action_name)`; start `%RunTimer` (the time limit as today) and `get_run_clock().bind_timer(%RunTimer)`; reset the run stats.
- Tilemap → chest: `tile_entered` → `expedition_page.show_tile(encounter, summary, current_action_data)`; `encounter_resolved(coord, summary)` → `show_resolved(summary)` when `coord` is the current tile; `walk_refused` → `vitals_plate.shake_stamina()` (`REFUSED_STAMINA`) or `expedition_page.shake_here()` (`REFUSED_ENCOUNTER`); `expedition_page.choice_selected` → `adventure_tilemap.select_choice`.
- `run_stats_changed` fires after `map_changed`, a fight's end and an item award; its handler calls `set_run_stats(_combats_fought, get_total_combat_count(), _gold_earned, get_visited_tile_count(), get_total_tile_count(), <the run's items, newest last>)`.
- `_on_start_combat`: `technique_dock.bind(player ability_manager, PlayerManager.vitals_manager)`, `vitals_plate.bind_buffs(player buff_manager)`, connect `technique_dock.ability_selected` → `combat.on_player_ability_selected` (where `player_hud` did).
- `_on_stop_combat` and `stop_adventure`: disconnect, `technique_dock.reset()`, `vitals_plate.unbind_buffs()`; `stop_adventure` stops `%RunTimer` and reads it where it read `timer_panel.timer`.
- The tilemap `SubViewport` gets `canvas_item_default_texture_filter = 0` (nearest). The combat `SubViewport` keeps today's filter until PR 2 draws the fighters at 2x. `_fade_in_combat_view()` and `ZoneViewBackground` stay until PR 2.

- [x] **Step 1: Write the failing tests** (`test_adventure_view_frame.gd`, the view instanced as in `test_adventure_end_flow.gd`; signal wiring tested by emitting the tilemap's signals; tile state through `start_adventure_on_map` with Task 3's fixture):
  - `test_start_fills_the_frame` (title "The Shallow Woods", clock running, the run's Madra budget in the cabinet, the dock in preview).
  - `test_arrival_fills_the_here_tray`; `test_resolution_shows_cleared`.
  - `test_walk_refused_shakes_the_right_board`.
  - `test_choice_from_the_chest_reaches_the_tilemap` (pressing the rest drawer resolves the tile).
  - `test_fight_binds_the_dock_and_buffs` and back to preview after `_on_stop_combat`.
  - `test_run_stats_follow_the_run` (a won fight paying 15 → "1 / <n>" and "15").
  - `test_map_viewport_filters_nearest`; `test_old_hud_is_gone` (no `%PlayerHud`, `%TimerPanel`, `%EncounterInfoPanel`).
  - `test_second_run_starts_clean` (Review Focus 1: start, enter a fight, `ActionManager.stop_action(false)`, start again: dock in preview, cast tray hidden, chest on the new start tile, clock reset, and the coin count equals the new map's seen tiles that pass `EncounterCoin.needs_coin()`).
  - `test_view_state_hud_positions.gd`: replace the four adventure tests with `test_adventure_leaves_goals_and_the_log_in_place` (positions unchanged on enter and exit) and `test_adventure_keeps_the_goals_cords`; keep `test_back_from_an_adventure_the_zone_view_places_both_boards`.
- [x] **Step 2: Run; expect failures.**
- [x] **Step 3: Wire it; delete the old scenes and styleboxes (grep each class and path: `PlayerHud`, `AbilitiesPanel`, `AbilityButton`, `CombatAbilityTooltip`, `ResourceOrb`, `TimerPanel`, `EncounterInfoPanel`, `EncounterChoiceButton`; none may remain); `--import`; check `git diff project.godot`.**
- [x] **Step 4: Run the suite; green. Back up the save; capture the adventure in a scratch scene (not committed) that instances `AdventureView`, starts the Shallow Woods on a fresh save and walks to a fight tile; check the save hash is unchanged; compare with the mock's walk and encounter screens and fix placement.**
- [x] **Step 5: Commit** `feat(adventure): put the lacquer frame into the adventure view`, then `refactor(adventure): remove the replaced adventure HUD` for the deletions.

---

### Task 11: Docs

**Files:**
- Modify: `docs/adventuring/ADVENTURING.md` (the map, coins, chest, signals, flows), `docs/combat/COMBAT.md` (the dock, the sweep, the buff tooltip), `docs/infrastructure/MAIN_VIEW.md` (the adventure keeps Goals and the Log in place), `docs/STYLE_GUIDE.md` (delete the done rows A1–A9, B1, B2 and B3; note B4, B6 and B7 as done for the player and left for the enemy in PR 2, and S1 as done on the map; B8 stays for the Abilities book; F1 and F4 progress; the Health and Stamina ramps in §4; G2, G7 and G9 answered for the adventure), `docs/UI_STYLING.md` (if Task 2 left anything), `CLAUDE.md` (Reusable UI Components: the new pieces, `HexHoverSelector` and `PathPreview` gone; Hex Grid: the adventure map at zoom 1 with fog tiers and coins; Shaders), `docs/README.md`, the spec's Status line, this plan's checkboxes and an "As built" section.
- [x] **Step 1: Update each doc to the built state.**
- [x] **Step 2: Commit** `docs(adventure): document the lacquer map and frame`.
