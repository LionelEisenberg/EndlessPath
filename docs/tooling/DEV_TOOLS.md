# Developer Tools

## Overview

| Tool | Where | How to use | Purpose |
|------|-------|------------|---------|
| Dev Panel | `scenes/ui/dev_panel/` (in `main_game.tscn`) | Ctrl+Shift+D in game | Change Madra/Gold, CD XP, path points and unlocks; force combat wins; end adventures as a victory or defeat; reveal adventure maps; show the demo and hidden zones on the zone map |
| Save presets | `resources/dev/save_presets/`, `resources/dev/story_route.tres`, `singletons/dev_manager/` (`DevManager`) | `--preset=<id>` after `--`, or a pinned preset | Start the game at a built moment of the story (the Tribulation ready, the Merchant open, Copper) in a session that leaves the user's save alone, and switch between presets and the user's save while the game runs. See [Save Presets](#save-presets) |
| Dev commands | `singletons/dev_manager/dev_commands.gd` (`DevCommands`) | Called from code and tests | One command API over the managers' public functions: complete an action, trigger an event, reach a Core Density level, buy a path node, award an item. See [Dev Commands](#dev-commands) |
| Map Preview | `scenes/tools/map_preview.tscn` + `scripts/tools/map_preview.gd` | Open in the editor and press **Generate** in the Inspector | Preview procedural adventure maps without running the game |
| UID generator | `scripts/tools/generate_uid.gd` | Headless `-s` script | Print fresh `uid://` strings for hand-written `.tscn`/`.tres` |
| Items generator | `scripts/tools/items_md_to_resources.gd`, `items_md_parser.gd` | Headless `-s` script | Generate equipment `.tres` files from `docs/inventory/ITEMS.md`. Documented in [ITEMS.md](../inventory/ITEMS.md). |
| Label testing scene | `tests/label_tests/label_testing_scene.tscn` | Open and run the scene (F6) | Visual comparison of Label theme variants. See [UI_STYLING.md](../UI_STYLING.md#label-testing-scene). |
| GUT test runner | `addons/gut/` | CLI or the GUT editor panel | Unit and integration tests. See [TESTING.md](../testing/TESTING.md). |
| Debug switches | Various exports, and the launch options | Edit in the Inspector or in code, or pass them after `--` | See [Other debug switches](#other-debug-switches) |

## Dev Panel

A floating panel shipped in the game binary, open to anyone who presses the hotkey (no password; exported builds included). It calls existing singleton APIs, so its changes go through the same signals as gameplay and are saved with the rest of the session's save by the autosave when the session has a file ([PERSISTENCE.md](../infrastructure/PERSISTENCE.md); a preset session lives in memory). Reloading does not undo them.

### Opening it

```
Ctrl+Shift+D (MainGame._input)
  └─ panel visible → hide panel
  └─ panel hidden  → DevPanel.open()
```

The hotkey needs no password: an old `user://dev_password.txt` is ignored.

### Scene structure

```
DevPanel (PanelContainer, min width 340, mouse Stop)   dev_panel.gd (class DevPanel)
└── VBoxContainer
    ├── TitleBar (PanelContainer: drag handle) → TitleLabel "Dev Panel", CloseButton "×"
    ├── "RESOURCES"   → MadraRow (MadraSpin, MadraApply), GoldRow (GoldSpin, GoldApply)
    ├── "CULTIVATION" → XpRow (XpSpin, XpApply), PointsRow (PointsSpin, PointsApply)
    ├── "UNLOCKS"     → ConditionRow (ConditionOption, ConditionApply "Trigger"), UnlockCyclingButton
    ├── "COMBAT"      → ForceWinButton
    ├── "ADVENTURE"   → ShowWholeMapCheck (CheckButton), ExitAdventureRow (ExitVictoryButton, ExitDefeatButton)
    └── "ZONES"       → DemoZonesCheck, HiddenZonesCheck (CheckButtons)
```

The panel is a child of `MainView` at z 10. `main_game.tscn` places the panel at (0, 0). Dragging the title bar moves it, and the position survives close/re-open within a session. The × button hides the panel.

### Controls

Every action writes a `[DEV]` line (magenta tag) to the in-game log through `LogManager.log_message()`.

| Section | Control | Calls | Effect on game state |
|---------|---------|-------|----------------------|
| Resources | Madra (`MadraSpin`, 0 to 1,000,000, `allow_greater`) + Apply | `ResourceManager.set_madra(v)` | Sets Madra to `max(0, v)` and emits `madra_changed`. Not clamped to max Madra, so it can exceed orb capacity. Unlock conditions re-evaluate. |
| Resources | Gold (`GoldSpin`, 0 to 1,000,000, `allow_greater`) + Apply | `ResourceManager.set_gold(v)` | Sets gold to `max(0, v)` and emits `gold_changed`, which updates the cultivator cabinet's gold row and re-evaluates unlocks. |
| Cultivation | Add CD XP (`XpSpin`, 0 to 1,000,000, `allow_greater`) + Apply | `CultivationManager.add_core_density_xp(v)` | Normal XP path: loops level-ups, emits `core_density_level_updated` per level, and awards path points every 10 levels, once per stage (1 per milestone at Foundation). The loop stops at the stage's cap (level 100), where XP is lost, so it can fill the core to reveal the Tribulation card. |
| Cultivation | Path Points (`PointsSpin`, 0 to 1000, integer) + Apply | `PathManager.add_points(int(v))` | Adds to the path point balance and emits `points_changed`. |
| Unlocks | Condition (`ConditionOption`) + Trigger | `UnlockManager.force_unlock_condition(id)` | Appends the id to `unlock_progression.unlocked_condition_ids` and emits `condition_unlocked(id)`. Idempotent. The dropdown is filled once in `_ready()` from `UnlockManager.unlock_condition_list.list`, skipping null or empty ids. |
| Unlocks | Unlock All Cycling Techniques | `CyclingManager.unlock_technique(id)` for every entry in `CyclingManager._technique_catalog.cycling_techniques` | Unlocks every catalog technique and emits `technique_unlocked` for newly unlocked ones. Idempotent. |
| Combat | Force-Win Current Combat | `AdventureView.force_win_combat()` | Only shown while `AdventureView.is_in_combat`; `_process()` polls it every frame while the panel is visible. Emits `AdventureCombat.trigger_combat_end(true, 0)`, which ends the fight as a win with 0 gold. |
| Adventure | Show Whole Map (toggle) | `AdventureView.set_show_whole_map(pressed)` → `AdventureTilemap.set_dev_reveal_all()` | Visual only: lifts the fog off every map tile, paints every tile in forest art (no veils) and shows each unvisited encounter tile's glyph coin (the boss its boss coin). The visited/highlight dictionaries, stats and encounter resolution are unchanged, and switching it off puts the normal coins and fog back. The flag stays on `AdventureTilemap` across adventures until toggled off. |
| Adventure | Exit: Victory / Defeat | `AdventureView.force_end_adventure(victory)` | Only shown while an adventure runs (`AdventureView.is_adventure_running()`, polled like Force-Win). Victory takes the boss-win path: `ActionManager.stop_action(true)` with `_pending_victory` set, so the adventure's success effects run, the zone completion counts and the victory end card shows. Defeat calls `stop_action(false)`: failure effects and a "You retreated from the adventure" end card. Works on the map or mid-fight. |
| Zones | Demo zones (locked, uncharted) (toggle) | `ZoneManager.set_demo_zones_visible(pressed)` | Adds the two demo zones in `resources/zones/dev/` to the zone map: a locked Advancement Zone north-east of Spirit Valley and an Uncharted hex due north of Spirit Valley, beyond it, with their plates, glyphs, popovers and routes. They are loaded outside `zone_data_list.tres`, never enter the save, and are gone on the next launch. Emits `map_zones_changed`. |
| Zones | Show hidden zones (Test Zone) (toggle) | `ZoneManager.set_hidden_zones_visible(pressed)` | Draws the zones marked `hidden_on_map` (Test Zone, west of Spirit Valley). Once it is unlocked you can travel there. Emits `map_zones_changed`. The flag is not saved and resets on the next launch; a save standing in Test Zone moves back to Spirit Valley on load (`SaveGameData.migrate()`). |

Caveats:

- **Force-Win skips victory side effects.** It bypasses `AdventureCombat`'s enemy-death handling, so the gold reward and `EventManager.trigger_event("q_first_steps_enemy_defeated")` never run.
- **Exit: Victory skips the boss's own rewards.** The boss encounter's `success_effects` and the fight's gold never run, only the adventure action's. Exiting mid-fight first closes the fight as a loss (a "Combat Defeat..." log line; no encounter has failure effects today).
- **Forced conditions only satisfy some systems.** Zone and zone-action gates check `UnlockManager.are_unlock_conditions_met()`, so they accept forced ids. Quest steps (`QuestManager`), encounter choices and encounter eligibility call `UnlockConditionData.evaluate()` directly and ignore them. The underlying event is not triggered either.

## Save Presets

A **save preset** is a starting point for a dev session: the game starts in it at once, at a built moment of the story. The session lives in memory unless the run names a file, so while a preset runs the user's own save is neither read nor written (a switch from a session on it saves that session once, on the way out). Presets are how a tester, an agent or a test reaches "the Tribulation is ready" without playing there or keeping a copy of a save, which goes stale with every content and format change.

A preset is a `SavePresetData`, one of two kinds:

- **A recipe** names a beat of the [story route](#the-story-route) (`story_through`) and adds steps of its own. Building it plays the route's beats through that one on a fresh save, then the preset's steps, each through [`DevCommands`](#dev-commands). A recipe picks up a quest added in front of its beat and never holds stale save data.
- **A snapshot** embeds a whole save (`snapshot`), for an odd state found by playing that no recipe describes. It usually names no beat: the route is written for a fresh save, and its steps can refuse on a save that is already past them. Building it plays a migrated copy of the embedded save, so a format change needs a migration step as for any save ([PERSISTENCE.md](../infrastructure/PERSISTENCE.md#versioning)).

### Data

All four classes live under `scripts/resource_definitions/dev/`.

| Class | Fields and functions |
|-------|----------------------|
| `SavePresetData` | `preset_id` (unique: what `--preset=`, the pin and the panel name the preset by), `title`, `description`, `story_through` (a beat id, or `""` for none), `steps` (they run after the route's), `snapshot` (a `SaveGameData`, or null for a recipe). `validate(route)` lists everything wrong with the preset, one line each: no id, no title, a `story_through` the route has no beat for, each step's errors, a snapshot a newer build wrote |
| `StoryRouteData` | `beats` (in play order), `optional_quest_ids`, `excluded_action_ids`. `find_beat(beat_id)` (null for `""` and an unknown id), `steps_through(beat_id)` (every step of every beat up to and including it; empty for `""` and an unknown id, never the whole route), `validate()` |
| `StoryBeatData` | `beat_id` (unique in the route), `title`, `steps`, `reached_when` (the id of the event or unlock condition that marks the beat reached in real play, or `""`; it feeds the play stats and the coverage test, and never controls a build) |
| `DevStepData` | `kind`, `target_id`, `amount`. `apply()` runs the step through its `DevCommands` command and returns `""` or the reason the command refused; `describe()` names the step in a few words ("Set gold to 700"); `validate()` lists what is wrong with the step |

A step reads the fields its kind lists and ignores the rest. A level, a slot and a quantity are whole numbers: the part after the point is dropped.

| Kind | `target_id` | `amount` | Command |
|------|-------------|----------|---------|
| `COMPLETE_ACTION` | an action id | | `complete_action()` |
| `TRIGGER_EVENT` | an event id | | `trigger_event()` |
| `REACH_CORE_DENSITY` | | the level | `reach_core_density()` |
| `SET_MADRA`, `SET_GOLD` | | the value | `set_madra()`, `set_gold()` |
| `BUY_PATH_NODE` | a node id of the current path tree | | `buy_path_node()` |
| `UNLOCK_TECHNIQUE`, `EQUIP_TECHNIQUE` | a technique id | | `unlock_technique()`, `equip_technique()` |
| `UNLOCK_ABILITY` | an ability id | | `unlock_ability()` |
| `EQUIP_ABILITY` | an ability id | the slot, 1 to 4 | `equip_ability()` |
| `AWARD_ITEM` | an item resource path | the quantity | `award_item()` |
| `ADVANCE_STAGE` | | | `advance_stage()` |
| `TRAVEL` | a zone id | | `travel_to_zone()` |

`Kind` is stored as an int in `.tres` files: append a kind, never insert or reorder one. Use `TRIGGER_EVENT` for the events that adventure or combat code fires, which no zone action's effects fire (`q_first_steps_enemy_defeated`, `aura_well_discovered`, `merchant_discovered`).

`validate()` reads the managers' catalogs and the current path tree, never the save, so what a step needs the save to hold (an action available now, a node's prerequisite) is checked when the step is applied. It finds a `COMPLETE_ACTION` step's action in any zone; the command finds it in the current zone only.

### The story route

`resources/dev/story_route.tres` is the canonical Foundation playthrough as beats, in the order they play. It only ever runs on a fresh save, beat by beat, so each step meets the state it was written for. A beat uses step kinds only and never edits save fields. The route never travels, so every `COMPLETE_ACTION` runs in the starting zone, Spirit Valley.

| Beat | Title | Steps | `reached_when` |
|------|-------|-------|----------------|
| `beat_1` | Awakening | Complete `celestial_intervener_dialogue_1`; set Madra to 100; complete `celestial_intervener_dialogue_2` | `q_fill_core_completed` |
| `beat_2` | First Steps Out | Trigger `q_first_steps_enemy_defeated`; complete `celestial_intervener_dialogue_3`; buy path node `pure_core_awakening`; equip technique `smooth_flow`; equip ability `empty_palm` in slot 3 | `celestial_intervener_dialogue_3` |
| `beat_3a` | Aura Well | Trigger `aura_well_discovered` | `aura_well_discovered` |
| `beat_3b` | Merchant unlocked | Reach Core Density 10; complete `celestial_intervener_dialogue_4`; trigger `merchant_discovered` | `merchant_discovered` |
| `beat_9_ready` | Tribulation ready | Reach Core Density 100 | `core_density_full` |
| `beat_9` | Copper | Advance to the next stage | none |

`optional_quest_ids` and `excluded_action_ids` name what the route leaves out on purpose. Both are empty today: the route completes every quest of the catalog and makes every zone action available at some point.

**The coverage rule.** A test plays the whole route on a fresh save and fails when story content exists that the route neither reaches nor lists as left out:

- the route validates, so every id its steps and its two lists name exists;
- every step applies in order with no refusal and does what its kind says (a step of a kind the test has no check for fails it, so a step is never left unchecked);
- each beat's `reached_when` has fired right after the beat's last step;
- every quest of `quest_list.tres` ends completed, unless it is in `optional_quest_ids`;
- every action of every zone was available at the start or after some step, unless it is in `excluded_action_ids`. This catches a beat with no quest or NPC, such as the Aura Well;
- every NPC dialogue action with a completion cap (`max_completions` above 0) ends used up, unless it is in `excluded_action_ids`;
- the route ends in Copper.

So a new quest or zone action fails the test until a beat reaches it or a list names it: leaving something out is always a decision on the page ([QUESTS_EVENTS_UNLOCKS_CONVENTIONS.md](../progression/QUESTS_EVENTS_UNLOCKS_CONVENTIONS.md) carries the authoring rule). New beats go in where they play: a beat added before `beat_9_ready` is in "Tribulation ready" with no change to the preset.

### Starting presets

The recipes the game ships, in `resources/dev/save_presets/`:

| `preset_id` | Title | Story through | Steps of its own | For testing |
|-------------|-------|---------------|------------------|-------------|
| `fresh` | Fresh start | none | none | A new game |
| `adventure_open` | Adventure open | `beat_1` | none | The first adventure and fight: the Shallow Woods and foraging are open |
| `path_open` | First keystone | `beat_2` | none | The path tree and the techniques: Pure Core Awakening bought, Smooth Flow and Empty Palm equipped |
| `merchant_open` | Merchant open | `beat_3b` | Set gold to 700 | The shop, with gold for every piece |
| `tribulation_ready` | Tribulation ready | `beat_9_ready` | none | The Tribulation: every quest done, Core Density 100 |
| `copper` | Copper | `beat_9` | none | The first moments of Copper, the Tribulation passed |

### Adding a preset

A preset is a `.tres` file in `resources/dev/save_presets/`: nothing else registers it, since `DevManager.get_presets()` lists every `.tres` in the folder that loads as a `SavePresetData`.

1. In the editor, create a new `SavePresetData` resource in the folder, named `<preset_id>.tres`.
2. Give it a `preset_id` no other preset has, a `title` and a `description`.
3. Set `story_through` to the id of a route beat, and add `steps` for anything the beat does not set up (`merchant_open` adds its gold): each a `DevStepData` with a kind and the fields that kind reads. Written by hand, a step is an embedded sub-resource, as in `merchant_open.tres`.

A preset that fails `validate()` is refused before anything changes, with its first error. A test builds every preset in the folder on a fresh session and fails for one that does not validate or does not build. [Save this game as a preset](#save-this-game-as-a-preset) writes a snapshot into the same folder.

### Launching into a preset

```bash
"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64.exe" --path . scenes/main/main_game/main_game.tscn -- --preset=tribulation_ready
```

- `--preset=<id>` starts a preset session. `PersistenceManager` boots on a fresh save (in memory unless `--save` names a file) and reads no file, and `DevManager` builds the preset in its `_ready()`, after every other autoload is ready and before the main scene's `_ready()`, so no view hears the build. The main scene then comes up as a launch on that save would. A headless run works the same way.
- `--save=<path>` with it plays the built session in that file, which the tick and the close write as for any file session (`--no-autosave` stops them): an agent adds `--save=user://dev/runs/<name>.tres` to keep a run's file. A preset session written over the user's own save is backed up first, under the lock, and still reads nothing from it ([PERSISTENCE.md](../infrastructure/PERSISTENCE.md#sessions-and-launch-options)).
- The player's log starts clean and gets one `[DEV]` line, "Started preset '<title>'", with " (pinned)" after it when the pin chose the preset.
- An id no preset folder has, or a preset that does not build, is logged with `Log.critical`, and the session falls back to the `fresh_fallback` preset ("Fresh start (the preset could not be built)"): a fresh game in memory, never on the user's save, whatever `--save` says. The `[DEV]` line says why the preset did not start.

### The pin

A preset can be pinned for a checkout, so that plain launches (the editor's Play button included) start in it until it is unpinned. `DevManager.pin_preset(preset_id)` writes the pin (`""` unpins), and `get_pinned_preset_id()` reads it.

- It is one preset id in a `ConfigFile` (section `dev`, key `pinned_preset`): `res://.dev_settings.cfg` for a run from the editor binary, in the checkout's own folder, so each worktree has its own pin and `.gitignore` keeps it out of commits; `user://dev_settings.cfg` in an exported build, whose `res://` is read-only.
- Only a plain launch uses it: one with neither `--preset` nor `--save`. A launch with `--preset` starts that preset, and a launch with `--save` is a file session, which the pinned preset would otherwise be built over. `--no-autosave` names no save, so it leaves the pin on.
- A pin whose preset is gone starts the fresh fallback in memory, with the critical log line above.

### Save this game as a preset

`DevManager.save_as_preset(title, description)` writes the running session's save as a snapshot preset, `<id>.tres`, in the folder `get_presets()` reads. A run from the editor binary writes `res://resources/dev/save_presets/`, so the file shows in `git status` and the user decides whether to commit it; an exported build writes `user://dev/save_presets/`.

- The id is the title lowercased, each run of characters outside `a-z` and `0-9` turned into `_`, and `_` trimmed from both ends: "Weird State #2!" is `weird_state_2`.
- The snapshot is a copy of the session's save that shares the item resources the inventory is keyed by and copies everything else. The session is left as it was, and one `[DEV]` line names the file.
- It returns `""` once the file is written, or why it was not: an empty title, a title with no letter or digit, an id some preset already has (an existing preset is never overwritten), or a failed write.

A committed snapshot is built with the other presets, so one that no longer builds fails a test.

## DevManager

`singletons/dev_manager/dev_manager.gd`, the last autoload. It keeps the dev session, builds presets and switches sessions while the game runs. It builds nothing in a test run (its `_ready()` returns), so a test calls its functions itself.

`enum SessionKind { YOUR_SAVE, PRESET, FILE }` names what a session plays: the user's own save, a preset, or a `--save` file.

| Constant | Value |
|----------|-------|
| `ROUTE_PATH` | `res://resources/dev/story_route.tres` |
| `PRESET_DIR` | `res://resources/dev/save_presets/` |
| `EXPORT_PRESET_DIR` | `user://dev/save_presets/`, the presets an exported build keeps |
| `FALLBACK_PRESET_ID` | `fresh_fallback` |

| Signal | Emitted |
|--------|---------|
| `session_changed` | At launch, once the launch options have set the session up, and at the end of each switch in game, a failed one included |
| `session_switch_failed(reason: String)` | When a switch is refused or fails. A refused switch changed nothing; after a failed one the session it left is back, and `session_changed` follows |

| Function | Behaviour |
|----------|-----------|
| `get_session_kind() -> SessionKind` | What the session plays |
| `get_session_preset() -> SavePresetData` | The preset the session was built from, or null outside a preset session. A launch whose preset did not start plays `fresh_fallback`, so a preset session always has one |
| `get_last_switch_failure() -> String` | Why the last switch was refused or failed, `""` once a switch has worked. A failure midway is signalled while the main scene, and the panel in it, is freed, so a panel built next reads the reason here |
| `start_from_launch_options(options)` | Sets the session up from the launch options, as `_ready()` does at launch (see [Launching into a preset](#launching-into-a-preset)): a preset is built, any other session only recorded |
| `get_route() -> StoryRouteData` | The story route |
| `get_presets() -> Array[SavePresetData]` | Every `.tres` in the preset folders that loads as a `SavePresetData`, sorted by title, ignoring case, then by id. A missing folder holds none |
| `find_preset(preset_id) -> SavePresetData` | The preset with this id, or null |
| `build_preset(preset, save_path = "") -> String` | Builds the preset as the session's save, written to `save_path` (`""` keeps it in memory). Returns `""`, or the step's `describe()` text, a colon and the reason for the first step that refused. See [Building a preset](#building-a-preset) |
| `play_preset(preset)` | Plays the preset in memory: a switch |
| `play_story_through(beat_id)` | Plays the route through the beat on a fresh save, as an unnamed preset (`preset_id` `story_through_<beat_id>`, title "Story through <the beat's title>"), so a restart plays it again |
| `restart_preset()` | Builds the session's preset again from the start, written where the session writes: in memory for a preset played in game and for the fallback, the `--save` file for a launch that named one. Does nothing outside a preset session |
| `back_to_my_save()` | Opens the user's own save again from disk |
| `new_game()` | Backs the user's save up, then plays a fresh save as it, written at once |
| `keep_as_my_save()` | Backs the user's save up, then plays a copy of the session's save as it, written at once |
| `restore_backup(backup_path)` | Puts a backup (`PersistenceManager.list_backups()`) back as the user's save, then opens it from disk |
| `save_as_preset(title, description) -> String` | See [Save this game as a preset](#save-this-game-as-a-preset) |
| `pin_preset(preset_id) -> Error`, `get_pinned_preset_id() -> String` | See [The pin](#the-pin) |

`preset_dir_override` is a test-only variable: the one folder to read presets from and to save them to, in place of `PRESET_DIR` and `EXPORT_PRESET_DIR`.

### Building a preset

`build_preset()` runs at launch and in game alike:

1. A preset that `validate()` finds anything wrong with is refused with its first error, before anything changes: a beat the route lacks would otherwise play no route steps at all.
2. The save is a migrated copy of the preset's snapshot, or a fresh save, and its play stats name the preset (`built_from_preset`). The snapshot itself is never changed.
3. `PersistenceManager.use_save()` makes it the session's save, so every manager re-binds.
4. The route's steps through the preset's beat run in order, then the preset's own. The first step that refuses stops the build and leaves its save half-built: the caller decides which session comes next.
5. Every action available in every zone, and every unlocked technique, is marked seen, as on a save played to that point, so no NEW seal shows.

Nothing the build sets off counts as play: the save's play stats stay paused for the whole build.

Restarting a preset in game leaves the managers in the same state as launching with `--preset`: nothing a build sets lives outside the save. A test builds a preset, writes the save, plays the loaded file and compares what the managers hold.

### Switching sessions

`play_preset()`, `play_story_through()`, `restart_preset()`, `back_to_my_save()`, `new_game()`, `keep_as_my_save()` and `restore_backup()` are switches. Each runs on the next frame, because a caller such as a panel button lives in the main scene the switch frees, and the scene is deleted at once. The switch runs in this order:

1. The session it leaves is saved, when autosave is on and the session writes a file.
2. What lives outside the save is torn down, which a launch never starts with: the running action stops, uncounted and with no effects; any dialogue ends (one an adventure encounter started included); the cycle session and the last cycle's result clear; the player's vitals are replaced (`PlayerManager.reset_vitals()`); the engine's time scale goes back to `GameSpeed.base_scale`, the base speed (`scripts/utils/game_speed.gd`), so a slowed moment cannot carry over.
3. The main scene is freed when it is the current scene. It never is under GUT, where the runner is, so a test run unloads and reloads no scene.
4. The new session binds: a build, a file opened again, or the new-game, keep and restore steps. A switch that fails here logs `Log.error` with the reason, brings back the session it left (your save opens again from disk, a preset is built again where it was written, a file opens again; when even that fails, `fresh_fallback` in memory), and emits `session_switch_failed`. A preset session comes back as its preset built again, not as it was played.
5. The player's log is cleared and gets one `[DEV]` line naming the new session ("Started preset 'X'", "Restarted preset 'X'", "Back to your save", ...).
6. The main scene loads again, when step 3 freed it, and `session_changed` is emitted. Views build from manager state, so the game comes up as a launch on that save would.

A switch is refused at call time, before anything changes (`Log.error`, `get_last_switch_failure()`, `session_switch_failed`), when:

- the run has no main save ("This run has no main save"): `back_to_my_save()`, `new_game()`, `keep_as_my_save()` and `restore_backup()`. Every GUT run is one, unless a test points `PersistenceManager.main_save_path` at a temp file;
- another live run holds the lock on the user's save ("Your save is in use by another run (pid N)"): `new_game()`, `keep_as_my_save()` and `restore_backup()`, which write it;
- the backup to restore is not there ("There is no backup at <path>");
- the preset fails `validate()`: `play_preset()`, `play_story_through()` and `restart_preset()` (the first error, such as "story_through no_such_beat is not a beat of the route").

The switches that write the user's save back it up first. A save that cannot be backed up is never overwritten ("Could not back up your save, so it was left as it was"), and the switch fails. `restore_backup()` reads the chosen backup before it backs the user's save up: a backup keeps only the newest `BACKUPS_KEPT` and deletes the oldest, and the chosen one can be the oldest. It then puts the backup's bytes in place through a temp file (`SaveFiles.write_bytes_atomically()`) and opens the file again.

## Dev Commands

`singletons/dev_manager/dev_commands.gd` (`DevCommands`, a class of statics) is the one command API of the dev tools: the story route, the presets and the tests go through it. Each command:

- calls the owning manager's public API, never a private member and never a copy of a game rule (a rule a command needs gets a public function on its manager, which gameplay uses too);
- checks its ids before it calls a manager, since the managers `push_error` on an unknown id;
- pauses the live save's play stats (`PlayStatsData.recording_paused`) while it runs game code, and puts the pause back as it found it, so what it sets off (an event's first time, a count, gold earned) never counts as play;
- returns `""` when it worked or the reason it refused, and logs a `[DEV]` line in the player's log (the same line as a panel action) when it did something.

A command with nothing to do (an action used up, an event already fired, a node already bought, a technique already unlocked, a level already reached) returns `""` and logs nothing.

| Command | What it does | Refuses |
|---------|--------------|---------|
| `complete_action(action_id)` | Counts one completion of an action of the current zone and runs its success effects, without playing it (`ActionManager.complete_without_playing()`) | An id the current zone has no action for; an action not available now |
| `trigger_event(event_id)` | Fires the event, unless it has fired | An id outside `known_event_ids()` |
| `reach_core_density(level)` | Raises Core Density to the level, or to the stage's cap when that is lower, through real XP, one level at a time, so milestones pay and the core fills as in play | A stage whose next level costs no XP |
| `set_madra(value)`, `set_gold(value)` | Sets the resource to exactly the value | A negative value |
| `add_path_points(amount)` | Adds to the Path Point balance | |
| `add_attribute(attribute, amount)` | Adds to the base value of one attribute | A value that is not an attribute |
| `advance_stage()` | Breaks through to the next stage, as a passed Tribulation does | A stage with no next stage |
| `buy_path_node(node_id)` | Buys a node of the current path tree, granting only the Path Points the balance is short of | No path chosen; a node the tree lacks; a stage too low; a prerequisite not bought (named); a node the manager still will not sell |
| `unlock_technique(technique_id)`, `equip_technique(technique_id)` | Unlocks, or equips in place of the equipped one | An unknown id; equip also a locked technique |
| `unlock_ability(ability_id)`, `equip_ability(ability_id, slot)` | Unlocks, or equips in a slot, replacing what is there. `slot` counts from 1, as the player sees the slots | An unknown id; equip also a locked ability and a slot outside 1 to the slot count |
| `unlock_all_techniques()`, `unlock_all_abilities()` | Unlocks every one, and logs how many were new | |
| `award_item(item_path, quantity)` | Awards copies of the item at a `res://` path through `InventoryManager.award_items()` | A path that is not an item; a quantity below 1; equipment with fewer free grid slots than copies ("Equipment is full": the inventory would drop the item and still log "Looted") |
| `grant_equipment_page()` | Grants one more equipment page | |
| `travel_to_zone(zone_id)` | Makes the zone the current one | An unknown zone; travel while anything but foraging or training runs, since travel stops what runs as a success, which counts a completion and runs its effects: right for an action a player leaves by moving on, wrong for a dialogue, a cycle, an adventure, the shop or the Tribulation |
| `refill_vitals()` | Fills Health and Stamina and keeps the Madra the run has left | Unless an adventure runs |
| `known_event_ids() -> PackedStringArray` | The events the content listens to, sorted, each once: the event every `EVENT_TRIGGERED` condition waits for, and every quest step's `completion_event_id`. Firing any other event changes nothing in the game | |
| `list_item_paths() -> PackedStringArray` | The path of every item resource under `res://resources/items/`, nested folders included, sorted | |

## Map Preview

An editor-only `@tool` scene for checking procedural adventure layouts without launching the game. Design: [2026-04-23-map-preview-tool-design.md](../superpowers/specs/2026-04-23-map-preview-tool-design.md).

### How to run

1. Open `scenes/tools/map_preview.tscn` in the Godot editor.
2. Select the `MapPreview` root node. In the Inspector, set `adventure_data` (the scene defaults to `resources/adventure/data/shallow_woods.tres`) and `seed_value`.
3. Press **Generate**, or **Clear** to wipe the preview. Both are `@export_tool_button`s and need Godot 4.4 or later.

**Generate** and **Clear** return immediately outside the editor (`Engine.is_editor_hint()`), so the scene does nothing at runtime or from the CLI.

### What it does

| Step | Detail |
|------|--------|
| Validate | Runs `adventure_data.validate()`. Each error is `push_error`ed and generation aborts. A null `adventure_data` gives a warning. |
| Seed | `seed_value != 0` seeds the global RNG with that value. `0` mints a fresh `randi()` seed and shows it. |
| Generate | Calls `_preview_tile_map._on_tileset_changed()` so the addon's hex conversions work in the editor, then runs `AdventureMapGenerator` (`set_adventure_data()`, `set_tile_map()`, `generate_adventure_map()`). In the editor `AdventureEncounter.is_eligible()` always returns true, so the preview shows the full potential map, not the player-gated subset. |
| Render | Paints each tile with forest atlas source `8`, variant `HexForestAtlas.pick(coord)`. Each non-NoOp encounter whose type is not `NONE` gets an `EncounterIcon` (`configure_for_type()`) and an `encounter_id` label (`scenes/tools/encounter_id_label.tscn`). A yellow "START" marker sits at cube `(0, 0, 0)`. |
| Stats | `StatsLabel` (top-left `CanvasLayer`): `N tiles · combat · elite · boss · rest · treasure · trap · walk · seed`. "combat" counts `COMBAT_REGULAR` + `COMBAT_AMBUSH`; "walk" counts NoOp tiles. |

To keep a layout you like, copy the seed from the stats label into `seed_value`.

Icons and id labels are spawned without an owner, so they are not saved. Painted tiles and the stats text are saved. The committed scene holds a 28-tile Shallow Woods snapshot (8 combat, 4 elite, 1 boss, 2 rest, 13 walk, seed 1216432660), and reopening it shows those tiles without icons until you press Generate.

## UID Generator

`scripts/tools/generate_uid.gd` extends `SceneTree` and prints five fresh UIDs (`ResourceUID.id_to_text(ResourceUID.create_id())`), then quits. Use it when authoring `.tscn`/`.tres` files by hand.

```bash
"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s scripts/tools/generate_uid.gd
```

Output: five lines of the form `uid://...`.

## Items Generator

`scripts/tools/items_md_to_resources.gd` (with the parser `scripts/tools/items_md_parser.gd`, tested by `tests/unit/test_items_md_parser.gd`) turns the equipment tables in `docs/inventory/ITEMS.md` into `.tres` files. Usage and schema are documented in [ITEMS.md](../inventory/ITEMS.md).

## Other debug switches

| Switch | Location | Current value | Effect |
|--------|----------|---------------|--------|
| `--preset=<id>`, `--save=<path>`, `--no-autosave` | The command line, after `--` (`LaunchOptions`) | Not given | Start in a save preset ([Launching into a preset](#launching-into-a-preset)), play another save file instead of `user://save.tres`, and stop the autosave and the save on quit. See [PERSISTENCE.md](../infrastructure/PERSISTENCE.md#sessions-and-launch-options) |
| The pin | `res://.dev_settings.cfg` (`user://dev_settings.cfg` in an exported build) | No preset pinned | The preset a plain launch starts in. See [The pin](#the-pin) |
| `log_print_level` | `MainGame` (`main_game.gd` export, set in `main_game.tscn`) | `0` (`Log.Event.INFO`) | Lowest `Log` event printed to the console. Every event is also written to `user://logs-<YYYY-MM-DD>.log`, which is truncated on each launch. See [LOGGING.md](../infrastructure/LOGGING.md). |
| `is_debug_mode` | Player `CharacterBody2D` (`scenes/characters/main_character/character_body_2d.gd`) | `true` in `character_body_2d.tscn`; overridden to `false` in `zone_tilemap.tscn` and `adventure_tilemap.tscn` | When `true`, left-clicking anywhere walks the character to the cursor |
| `preview_message` | `QuestToast` | `""` | Plays the message once when the scene runs alone (F6); skips `QuestManager` wiring |

## Editor Plugins

| Addon | Version (`plugin.cfg`) | Enabled in `project.godot` | Use |
|-------|------------------------|----------------------------|-----|
| `AsepriteWizard` | 9.6.0 | Yes | Imports `.aseprite` sources |
| `ResourcePlus` | 0.1.0 | Yes | Resource editing helpers |
| `dialogic` | 2.0-Alpha-19 (Godot 4.4+) | Yes | Dialogue; also the `Dialogic` autoload. Carries two local patches, listed in `CLAUDE.md` |
| `godot_context_exporter` | 1.0 | Yes | Exports scripts and scene trees to a single text file |
| `gut` | 9.7.1 | Yes | Test framework ([TESTING.md](../testing/TESTING.md)) |
| `hexagon_tilemaplayer` | 2.5.2 | No | Its runtime classes (`HexagonTileMapLayer`) are used by both maps |
| `script-ide` | 2.0.2 | No (disabled in `39f1817`) | Script editor tabs and outline |

## Mockup Preview Servers

`.claude/launch.json` defines two static servers for design mockups:

| Name | Command | Serves |
|------|---------|--------|
| `zone-mockup` | `npx serve mockups -l 3456 --no-clipboard` | `mockups/`, which is gitignored and absent from a fresh checkout |
| `inventory-redesign` | `python -m http.server 3789 --directory docs/superpowers/mockups/inventory-redesign` | Inventory redesign mockup |

## Integration Points

| System | Connection |
|--------|------------|
| MainGame | Owns the Ctrl+Shift+D gate |
| ResourceManager | `set_madra()`, `set_gold()` |
| CultivationManager | `add_core_density_xp()` |
| PathManager | `add_points()` |
| UnlockManager | `unlock_condition_list` (dropdown), `force_unlock_condition()` (dev-only wrapper) |
| CyclingManager | `_technique_catalog` (private read), `unlock_technique()` |
| AdventureView / AdventureTilemap | `is_in_combat`, `force_win_combat()`, `set_show_whole_map()` → `set_dev_reveal_all()` |
| LogManager | `[DEV]` audit lines; a switch clears the history (`clear_history()`) and writes one `[DEV]` line |
| PersistenceManager | `DevManager` binds a preset's save (`use_save()`), opens a file again (`open_save_file()`), saves the session it leaves (`autosave()`), backs the user's save up (`backup_main_save()`) and writes it (`save_data()`). `LaunchOptions` carries `--preset` and the pin |
| ActionManager | `complete_without_playing()` behind `complete_action()`, `is_idle_action()` behind `travel_to_zone()`, `cancel_current_action()` in a switch's teardown |
| DialogueManager / CyclingManager / PlayerManager | A switch's teardown: `end_dialogue_now()`, `end_cycle_session()` with `clear_last_cycle_result()`, `reset_vitals()` |
| ZoneManager / PathManager / InventoryData | `is_action_used_up()`, `is_stage_reached()` with `get_unmet_prerequisite()`, `free_equipment_slots()`: the rules `DevCommands` shares with the managers |
| AbilityManager / CyclingManager / QuestManager | Catalog lookups behind the commands and `validate()`: `has_ability()`, `get_all_abilities()`, `has_technique()`, `get_all_techniques()`, `get_all_quests()` |
| AdventureMapGenerator / HexForestAtlas / EncounterIcon | Reused by Map Preview |

## Key Files

| File | Purpose |
|------|---------|
| `scenes/main/main_game/main_game.gd` | Ctrl+Shift+D hotkey |
| `scenes/ui/dev_panel/dev_panel.gd` / `.tscn` | `DevPanel` controls and drag |
| `singletons/dev_manager/dev_manager.gd` | `DevManager`: the session, building presets, switching sessions, snapshots and the pin |
| `singletons/dev_manager/dev_commands.gd` | `DevCommands`: the command API |
| `scripts/resource_definitions/dev/` | `DevStepData`, `StoryBeatData`, `StoryRouteData`, `SavePresetData` |
| `resources/dev/story_route.tres`, `resources/dev/save_presets/` | The story route and the shipped presets |
| `scripts/utils/launch_options.gd` | `--preset`, `--save`, `--no-autosave`, the pin and test-run detection |
| `scripts/utils/game_speed.gd` | `GameSpeed`: the base time scale (`base_scale`, `set_base_scale()`) a switch puts the engine back to |
| `.dev_settings.cfg` (gitignored) | A checkout's pinned preset |
| `singletons/unlock_manager/unlock_manager.gd` | `force_unlock_condition()` |
| `scenes/adventure/adventure_view/adventure_view.gd` | `force_win_combat()`, `force_end_adventure()`, `set_show_whole_map()` |
| `scenes/adventure/adventure_tilemap/adventure_tilemap.gd` | `set_dev_reveal_all()`, `_dev_reveal_all` rendering paths |
| `scripts/tools/map_preview.gd`, `scenes/tools/map_preview.tscn`, `scenes/tools/encounter_id_label.tscn` | Map Preview |
| `scripts/tools/generate_uid.gd` | UID generator |
| `scripts/tools/items_md_to_resources.gd`, `scripts/tools/items_md_parser.gd` | Items generator |

Tests: `tests/unit/test_unlock_manager.gd` and `tests/integration/test_dev_panel_*.gd`, among others named after what they check; [TESTING.md](../testing/TESTING.md#coverage-gaps) lists what they do not cover.

## Work Remaining

### Bugs

- `[MEDIUM]` Force-Win can't advance combat-gated quest steps. `AdventureView.force_win_combat()` emits `trigger_combat_end(true, 0)` directly instead of going through `AdventureCombat`'s enemy-death handling. As a result `q_first_steps_enemy_defeated` never fires, so the Foundation Beat 2 step can't be advanced with Force-Win, and the fight awards no gold.
- `[LOW]` Two switches asked in one frame both run: `DevManager` keeps no pending flag. A second `new_game()`, `keep_as_my_save()` or `restore_backup()` takes a second backup, of the session the first one made.
- `[LOW]` A switch that writes the user's save takes no backup when only the save's temp file is there (a write cut short left it, and it may be the only copy), and then writes over it. The boot backup does take it.
- `[LOW]` `StoryRouteData.validate()` and `SavePresetData.validate()` call `validate()` on each step, so an empty slot in `steps` (the Inspector adds one before a resource is chosen) is a script error, not a listed problem.
- `[LOW]` `save_as_preset()` checks the id against the presets it can load but writes `<id>.tres`, so a file of that name holding another id is overwritten. `get_presets()` also reads a stray `<id>.tmp.tres` that a cut-short write left in a preset folder.
- `[LOW]` `LaunchOptions.read_pin()` returns `""` for a pin file that will not load, with no log line.

### Missing Functionality

- `[MEDIUM]` No tests cover the panel's actions or the hotkey gate. The spec's planned `test_dev_panel_actions.gd` integration test was never written; only `force_unlock_condition()` and the two Zones toggles are tested.
- `[LOW]` "Trigger" for a condition does not help with quest steps, encounter choices or encounter eligibility, which evaluate conditions themselves. It also does not trigger the backing event.
- `[LOW]` The spec's v2 list has no panel controls yet. Commands for most of it exist in `DevCommands` and `DevManager`: stage change, item grants, ability and technique unlock and equip, zone travel, new game and back to your save.
- `[LOW]` Map Preview has none of the follow-ups the spec mentions: no batch statistics mode (NG3) and no overlays such as MST edges or distance labels (G5).

### UI

- `[LOW]` The spec's `HSeparator`s between panel sections are missing.
- `[LOW]` "Unlock All Cycling Techniques" logs the catalog size, not the number of newly unlocked techniques.

### Tech Debt

- `[LOW]` `DevPanel` finds the adventure view by the absolute path `MainGame/MainView/AdventureView`, and its Unlock All Cycling Techniques button reads the private `CyclingManager._technique_catalog`.
- `[LOW]` `dev_panel.tscn` has a hand-written placeholder UID (`uid://dev_panel_001`). `main_game.tscn` references it by path only. `generate_uid.gd` can produce real ones.
- `[LOW]` Pressing Generate in Map Preview and then saving rewrites the committed snapshot in `scenes/tools/map_preview.tscn` (`tile_map_data` and stats text), which makes noisy diffs.
- `[LOW]` `generate_uid.gd` has no doc comment and a fixed count of 5.
- `[LOW]` The `zone-mockup` launch configuration serves `mockups/`, which is gitignored and not present in the repository.
