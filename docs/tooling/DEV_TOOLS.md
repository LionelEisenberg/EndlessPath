# Developer Tools

## Overview

| Tool | Where | How to use | Purpose |
|------|-------|------------|---------|
| Dev Panel | `scenes/ui/dev_panel/` (in `main_game.tscn`) | Ctrl+Shift+D in game; Ctrl+Shift+R restarts the preset | A floating panel of tabs (Saves, Player, Story, Items, Adventure, World): switch between presets and your save, set resources, progress and techniques, jump the story and fire its events, give items, drive an adventure, travel and show hidden zones; set the time speed. See [Dev Panel](#dev-panel) |
| Save presets | `resources/dev/save_presets/`, `resources/dev/story_route.tres`, `singletons/dev_manager/` (`DevManager`) | `--preset=<id>` after `--`, or a pinned preset | Start the game at a built moment of the story (the Tribulation ready, the Merchant open, Copper) in a session that leaves the user's save alone, and switch between presets and the user's save while the game runs, from the dev panel's Saves tab. See [Save Presets](#save-presets) |
| Dev commands | `singletons/dev_manager/dev_commands.gd` (`DevCommands`) | Called from code and tests | One command API over the managers' public functions: complete an action, trigger an event, reach a Core Density level, buy a path node, award an item. See [Dev Commands](#dev-commands) |
| Map Preview | `scenes/tools/map_preview.tscn` + `scripts/tools/map_preview.gd` | Open in the editor and press **Generate** in the Inspector | Preview procedural adventure maps without running the game |
| UID generator | `scripts/tools/generate_uid.gd` | Headless `-s` script | Print fresh `uid://` strings for hand-written `.tscn`/`.tres` |
| Items generator | `scripts/tools/items_md_to_resources.gd`, `items_md_parser.gd` | Headless `-s` script | Generate equipment `.tres` files from `docs/inventory/ITEMS.md`. Documented in [ITEMS.md](../inventory/ITEMS.md). |
| Label testing scene | `tests/label_tests/label_testing_scene.tscn` | Open and run the scene (F6) | Visual comparison of Label theme variants. See [UI_STYLING.md](../UI_STYLING.md#label-testing-scene). |
| GUT test runner | `addons/gut/` | CLI or the GUT editor panel | Unit and integration tests. See [TESTING.md](../testing/TESTING.md). |
| Debug switches | Various exports, and the launch options | Edit in the Inspector or in code, or pass them after `--` | See [Other debug switches](#other-debug-switches) |

## Dev Panel

A floating board of tabs shipped in the game binary, open to anyone who presses the hotkey (no password; exported builds included). Its tabs call the [dev commands](#dev-commands) and the managers' public functions, so their changes go through the same signals as gameplay and are saved with the rest of the session's save by the autosave when the session has a file ([PERSISTENCE.md](../infrastructure/PERSISTENCE.md); a preset session lives in memory). Reloading does not undo them. The panel is exempt from the lacquer look ([STYLE_GUIDE.md](../STYLE_GUIDE.md), G11): it takes `pixel_theme.tres` from `MainView`, and its labels use the `LabelSubheading`, `LabelBody` and `LabelBodySmall` variants.

### Opening it

```
Ctrl+Shift+D (DevPanel._input, whatever view the game is in)
  └─ panel closed → open it
  └─ panel open   → close it
Ctrl+Shift+R (DevPanel._input, with the panel open or closed)
  └─ a preset session   → DevManager.restart_preset(), and the event is marked handled
  └─ any other session  → left alone: the key goes on as plain R, the fourth ability slot
```

The hotkeys need no password: an old `user://dev_password.txt` is ignored. The panel starts closed. Closing it, with the × or the hotkey, hides the body only, so the time-speed badge and the save warning stay.

While saving is blocked (`PersistenceManager.is_save_blocked()`), a warning at the top centre of the screen reads `Not saving: <reason>` (`get_block_reason()`), with the panel open or closed: a save a newer build wrote, or one that would not load or could not be checked ([PERSISTENCE.md](../infrastructure/PERSISTENCE.md#boot-and-load)). So a session that will not save is never silent: without the warning, it would play a whole session that is lost on quit without a word. The warning follows `PersistenceManager.save_block_changed`, and a panel built after a switch shows it at once. A session in memory writes nothing by design and is not blocked, so it shows none; the Saves tab says where the session writes. The warning wraps a long reason, stacks under the time-speed badge when both show, and lets clicks through to the game.

A session switch frees the main scene, and the panel with it, so the panel's open state, the place of its body and its tab live on `DevManager` (`panel_open`, `panel_position` and `panel_tab`): the panel built next comes back as the last one was. Nothing is saved to disk, so a new launch starts with the panel closed, on the first tab, with the body centred at the top of the screen under the badge (`DevManager.PANEL_DEFAULT_POSITION`, (680, 60)). There it covers the map rather than the cabinet, the Goals, the activity chest or the log, which the dev tools change.

### Scene structure

```
DevPanel (Control, covers the screen, mouse Ignore)   dev_panel.gd (class DevPanel)
├── Body (PanelContainer, DevBoard: the lacquer board, min size 560x680, mouse Stop)
│   └── VBoxContainer
│       ├── TitleBar (PanelContainer, DevTitleBar, the drag handle) → TitleLabel "Dev Panel" (LabelLacquerPanelTitle), SpeedOption (OptionButton), CloseButton (TextureButton, the carved ×)
│       └── Tabs (TabContainer)
│           ├── SavesTab      scenes/ui/dev_panel/tabs/saves_tab.tscn      VBoxContainer: the scrolling part, then a status line
│           ├── PlayerTab     tabs/player_tab.tscn                         ScrollContainer
│           ├── StoryTab      tabs/story_tab.tscn                          VBoxContainer: the scrolling part, then a status line (class DevStoryTab)
│           ├── ItemsTab      tabs/items_tab.tscn                          ScrollContainer
│           ├── AdventureTab  tabs/adventure_tab.tscn                      ScrollContainer (class DevAdventureTab)
│           └── WorldTab      tabs/world_tab.tscn                          ScrollContainer
└── Notices (VBoxContainer, top centre, mouse Ignore): what shows stacks, the badge first
    ├── SpeedBadge (PanelContainer, DevToken, mouse Ignore, hidden at ×1) → SpeedBadgeLabel "×10"
    └── SaveWarning (PanelContainer, DevBoard, mouse Ignore, hidden unless saving is blocked) → SaveWarningLabel "Not saving: <reason>"
```

The panel is a child of `MainView` at z 10. Only its body takes the mouse: the rest of the panel, the badge and the save warning let clicks through to the game. The panel is dressed in the game's lacquer and brass ([STYLE_GUIDE.md](../STYLE_GUIDE.md)) by its own theme, `assets/themes/dev_panel_theme.tres` on the root, over the `pixel_theme.tres` it takes from `MainView`. The theme reuses the kit's pieces and adds no art:
- the body and the save warning are a lacquer board (`DevBoard`, `board9.tres`), and the badge sits on a token (`DevToken`, `token.tres`);
- buttons, dropdowns and the open tab are raised drawer faces (`lacquer_drawer9_ai.png`), with cream text, brass on hover;
- text and number fields are carved trays (`lacquer_now_tray_ai.png`);
- scrollbars are the brass rail thumb on its carved track;
- the other tabs and the switches are bare text on the board.

The body also takes `lacquer_theme.tres`, so the title is painted in brass (`LabelLacquerPanelTitle`) on a bar that draws nothing, and the tabs' section headers are `LabelLacquerSection`. Every button, field, dropdown list and tab title reads at 18 px, where the game's theme leaves them at its 14 px default; labels keep their variants' sizes.

Each tab is a scene of its own with one script, which calls the dev tools itself. The shell owns only the frame: the open state, the drag, the tab, the time speed, the save warning and the hotkeys. The one thing it hands a tab is the adventure view: `main_game.tscn` sets the panel's `adventure_view` export to the sibling `AdventureView`, and `DevPanel._ready()` passes it to the Adventure tab. The Saves tab's preset list is made of `DevPresetRow`s (`rows/dev_preset_row.tscn`), the Story tab's action list of `DevActionRow`s (`rows/dev_action_row.tscn`).

Dragging the title bar moves the body, on whole pixels. The title bar shows the move cursor. The body always stays wholly on screen: a wider tab makes it grow from its top-left corner, and it is moved back in when that pushes it past an edge, then shrinks back to its own size on a narrower tab. The place is kept on `DevManager`.

The title bar's picker sets the [time speed](#time-speed), ×1, ×2, ×5 or ×10. The badge at the top centre shows any speed but ×1, with the panel open or closed. The picker and the badge follow `DevManager.time_speed_changed`.

### Controls

A command, a switch or a toggle writes a `[DEV]` line (magenta tag) to the in-game log through `DevCommands.log_dev_line()`. A command that refuses shows its reason in the tab, in a status line that stays until a command works. The tabs, in order:

#### Saves

What the session plays and the saves behind it. From the top: the session line, the story's beats, the two session buttons, the presets, saving this game as a preset, and your save.

| Control | Calls | Effect |
|---------|-------|--------|
| Session line | `DevManager.get_session_kind()`, `PersistenceManager` | `Preset: <title>`, `Your save` or `File`, then ` · ` and where it writes: the session's `save_path`, or `in memory, not saved`. Then `Saving is off: <reason>` when saving is blocked, then `Built from preset '<id>'` when the save's play stats name the preset that built it (your save after a Keep still does), then `Version N · Playtime m:ss · <stage>, Core Density L / cap · G gold` (the clock reads h:mm:ss from an hour on) |
| Beats | `DevManager.get_route()`, the save's play stats | One line per beat of the [story route](#the-story-route), `<title> — <how far>`: the playtime at which the beat's `reached_when` first happened (`2:41`); `reached, no time recorded` when it has happened but the stats keep no time for it (a preset build records no play, and a save from before play stats kept none); `not reached`; or `not tracked (no reached_when)` for a beat with no `reached_when` (Copper) |
| Restart preset (Ctrl+Shift+R) | `DevManager.restart_preset()` | Builds the session's preset again. Off outside a preset session |
| Back to my save | `DevManager.back_to_my_save()` | Backs your save up and opens it again from disk, as a launch on it does. Off in a session on it |
| PRESETS: a `DevPresetRow` for each | `DevManager.play_preset()`, `pin_preset()` | The preset's title and description. Play plays it in memory. Pin pins it for plain launches ([The pin](#the-pin)); on the pinned preset the button reads Unpin and unpins it, and the row says "Pinned · plain launches start here". A pin that cannot be written shows in the status line |
| SAVE THIS GAME AS A PRESET: Title, Description, Save as a preset | `DevManager.save_as_preset()` | Writes the session's save as a snapshot preset ([Save this game as a preset](#save-this-game-as-a-preset)). A refusal shows under the button. On success it says `Saved this game as the preset '<title>'`, clears both fields and lists the new preset |
| New game on my save | `DevManager.new_game()` | Backs your save up, then starts a fresh game on it. Needs a second click |
| Keep as my save | `DevManager.keep_as_my_save()` | Backs your save up, then makes this session your save. Off in a session on it. Needs a second click |
| Save now | `PersistenceManager.save_data()` | Writes the session's save and says what came of it: `Saved to <path>` (with a `[DEV]` line), `Not saved: this session lives in memory, so there is no file to write`, `Not saved. Saving is off: <reason>`, or `Could not write <path>: <error> (error N)` |
| Autosave | `PersistenceManager.autosave_enabled` | Turns the tick's and the close's autosave on or off for the session, with a `[DEV]` line. A switch puts back what the run was launched with |
| Backup picker, Restore | `PersistenceManager.list_backups()`, `DevManager.restore_backup()` | Your save's backups, newest first, each read `<name> · 2026-10-25 11:17:15 (UTC)` (`#2` after the time for the second copy made in that second). A refresh keeps the backup picked. With none, the picker reads "No backups" and Restore is off. Restore needs a second click |
| Open save folder | `OS.shell_open()` | Opens the user data folder (`user://`) in the file manager |

New game, Keep and Restore write over your save, so each needs a second click on the same button within 3 s of real time, whatever the time speed. The first click turns the button into "Click again to start a new game", "Click again to keep" or "Click again to restore". The 3 s running out, a refresh, or a click on another of the three puts its own text back. None of the three takes keyboard focus, so Space (the Tribulation's press, Dialogic's advance) or Enter never confirms an armed one.

The status line stands under the part that scrolls, as the Story tab's does, so it is in view wherever the tab is scrolled to: the tab is taller than the body, and a refusal from the buttons at its top must not pass for a switch that ran. It shows why a switch was refused or failed, a pin that would not write, what Save now did, and a folder that would not open.

The tab refreshes when the session changes (`DevManager.session_changed`: the status line then shows why the switch failed, if it did, and clears once one works), when it is shown, and, for the session line and the beats, once a second while it is in view. A switch that is refused or fails shows its reason (`session_switch_failed`). A switch that fails midway reports while the main scene and the panel in it are freed, so the tab built next shows `DevManager.get_last_switch_failure()`.

#### Player

The player's resources and progress. A refusal shows above the controls.

| Control | Calls | Effect |
|---------|-------|--------|
| Madra (0 to 1,000,000, and more) + Set | `DevCommands.set_madra()` | Sets Madra to the value and emits `madra_changed`. Not clamped to the cap, so it can exceed the orb's capacity. Unlock conditions re-evaluate |
| Gold (0 to 1,000,000, and more) + Set | `DevCommands.set_gold()` | Sets gold and emits `gold_changed`, which updates the cabinet's gold row and re-evaluates unlocks |
| Core Density (0 to 100) + Reach | `DevCommands.reach_core_density()` | Raises Core Density to the level, or to the stage's cap, through real XP: the milestones pay and the core fills as in play. At or above the level nothing happens |
| Stage line | `CultivationManager` | "Stage: Foundation · Core Density 42 / 100". It follows `core_density_level_updated` and `advancement_stage_changed` |
| Advance to the next stage | `DevCommands.advance_stage()` | Breaks through as a passed Tribulation does. Refused at the last stage |
| Path Points (0 to 1000) + Add | `DevCommands.add_path_points()` | Adds to the Path Point balance and emits `points_changed` |
| Attribute picker (the eight), amount (0 to 1000) + Add | `DevCommands.add_attribute()` | Adds the amount to the attribute's base value |
| Technique picker + Unlock, Equip | `DevCommands.unlock_technique()`, `equip_technique()` | Every cycling technique of the catalog. Equip refuses a locked one |
| Unlock all techniques | `DevCommands.unlock_all_techniques()` | Unlocks every technique, and logs how many were new |
| Ability picker + Unlock, Equip; Equip in slot (1 to 4) | `DevCommands.unlock_ability()`, `equip_ability()` | Every combat ability. Equip puts it in the slot picked, replacing what is there, and refuses a locked one |
| Unlock all abilities | `DevCommands.unlock_all_abilities()` | Unlocks every ability, and logs how many were new |

#### Story

Where the story stands, and the controls that move it. The status line stands under the part that scrolls, so a refusal from Jump, Trigger or a row's Complete is in view wherever the tab is scrolled to, and the next command that works clears it.

| Control | Calls | Effect |
|---------|-------|--------|
| JUMP STORY TO: beat picker + Jump | `DevManager.play_story_through()` | Plays the story route through the beat on a fresh save, as a preset session ([Switching sessions](#switching-sessions)). The picker reads `<title> (<beat_id>)`. A refused jump shows its reason |
| QUESTS | `QuestManager` | One line per active quest, `<quest> — step N: <what the step asks>` (N counts from 1), then `Done: <titles>`. "No quests started yet" while there is nothing to show |
| TRIGGER EVENT: picker + Trigger | `DevCommands.trigger_event()` | Fires an event the content listens to (`known_event_ids()`), unless it has fired |
| `ACTIONS · <zone>`: a `DevActionRow` for each action of the current zone, with Complete | `DevCommands.complete_action()` | The action's name and id, and its status: `Available` (the zone manager offers it), `Used up (n/n)`, `Passed` (a Tribulation the player has passed) or `Locked: needs <ids>`, the unlock conditions that are not latched (a locked zone's own come first). Complete is on only while the action is Available, and counts one completion and runs the effects without playing the action |
| EVENTS AND CONDITIONS | `EventManager`, `UnlockManager` | `Events: <ids>` and `Conditions: <ids>`, in the order they fired and latched, or "none" |

The tab refreshes when an event fires, a condition latches, a quest starts, advances or completes, an action is completed, the current zone or the stage changes, or the session does, and when it is shown. It shows `DevManager.get_last_switch_failure()` when it is built, and the reason of any switch that is refused or fails while it lives, as the Saves tab does.

#### Items

| Control | Calls | Effect |
|---------|-------|--------|
| GIVE AN ITEM: item picker, Quantity (1 to 99) + Give | `DevCommands.award_item()` | The picker lists every item resource under `res://resources/items/` by its `item_name`; two items with one name also read their file name (`Crude Scale (crude_scale.tres)`). A refusal, such as "Equipment is full", shows under the Give row |
| EQUIPMENT PAGES: Grant an equipment page | `DevCommands.grant_equipment_page()` | One more equipment page. A refusal shows in the same status line |

#### Adventure

While no adventure runs, the tab says "No adventure running" and shows nothing else. It follows the run through `ActionManager`'s `start_adventure` and `stop_adventure` signals. A refusal shows above the controls.

| Control | Calls | Effect |
|---------|-------|--------|
| FIGHT: Force-win fight | `DevCommands.force_win_fight(view)` | Shown only while the view has a fight on (asked every frame while the tab is in view). Kills the enemy through its Health, so the fight ends as in play: it pays its gold, fires `q_first_steps_enemy_defeated` and resolves its tile ([ADVENTURING.md](../adventuring/ADVENTURING.md#dev-hooks)). Refused without a fight |
| ADVENTURE: Exit as victory, Exit as defeat | `DevCommands.exit_adventure(view, victory)` | Victory takes the boss-win path (`ActionManager.stop_action(true)`), so the adventure's success effects run, the zone completion counts and the victory end card shows. Defeat calls `stop_action(false)`: failure effects and a "You retreated from the adventure" end card. Works on the map or mid-fight. Refused without a run |
| Show whole map | `AdventureView.set_show_whole_map(pressed)` | Lifts the fog off every map tile and shows each unvisited encounter's glyph coin ([ADVENTURING.md](../adventuring/ADVENTURING.md#dev-hooks)). It changes no game state, but the tiles it reveals can be clicked and walked to, as the fog would not allow. The flag stays on the map across adventures until toggled off, so the toggle shows the map's own state each time a run shows |
| Refill Health and Stamina | `DevCommands.refill_vitals()` | Fills Health and Stamina and keeps the Madra the run has left |

Exit as victory skips the boss's own rewards: the boss encounter's `success_effects` and the fight's gold never run, only the adventure action's. Exiting mid-fight first closes the fight as a loss (a "Combat Defeat..." log line; no encounter has failure effects today).

#### World

| Control | Calls | Effect |
|---------|-------|--------|
| TRAVEL: zone picker + Travel | `DevCommands.travel_to_zone()` | Every zone, the hidden ones included. A refusal (travel while anything but foraging or training runs) shows under the picker |
| Demo zones (locked, uncharted) | `ZoneManager.set_demo_zones_visible(pressed)` | Adds the two demo zones in `resources/zones/dev/` to the zone map: a locked Advancement Zone north-east of Spirit Valley and an Uncharted hex due north of Spirit Valley, beyond it, with their plates, glyphs, popovers and routes. They are loaded outside `zone_data_list.tres`, never enter the save, and are gone on the next launch. Emits `map_zones_changed` |
| Show hidden zones (Test Zone) | `ZoneManager.set_hidden_zones_visible(pressed)` | Draws the zones marked `hidden_on_map` (Test Zone, west of Spirit Valley). Once it is unlocked you can travel there. Emits `map_zones_changed`. The flag is not saved and resets on the next launch; a save standing in Test Zone moves back to Spirit Valley on load (`SaveGameData.migrate()`). Both checks start from `ZoneManager`'s own state without toggling it |

## Save Presets

A **save preset** is a starting point for a dev session: the game starts in it at once, at a built moment of the story. The session lives in memory unless the run names a file, so while a preset runs the user's own save is neither read nor written (a switch from a session on it saves that session once, on the way out). Presets are how a tester, an agent or a test reaches "the Tribulation is ready" without playing there or keeping a copy of a save, which goes stale with every content and format change.

A preset is a `SavePresetData`, one of two kinds:

- **A recipe** names a beat of the [story route](#the-story-route) (`story_through`) and adds steps of its own. Building it plays the route's beats through that one on a fresh save, then the preset's steps, each through [`DevCommands`](#dev-commands). A recipe picks up a quest added in front of its beat and never holds stale save data.
- **A snapshot** embeds a whole save (`snapshot`), for an odd state found by playing that no recipe describes. It usually names no beat: the route is written for a fresh save, and its steps can refuse on a save that is already past them. Building it plays a migrated and repaired copy of the embedded save, so a format change needs a migration step as for any save ([PERSISTENCE.md](../infrastructure/PERSISTENCE.md#versioning)), and a snapshot taken in a zone the game has since dropped starts in the first zone.

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

- `--preset=<id>` starts a preset session. `PersistenceManager` boots on a fresh save (in memory unless `--save` names a file) and reads no file, and `DevManager` builds the preset in its `_ready()`, after every other autoload is ready and before the main scene's `_ready()`, so no view hears the build. The main scene then comes up as a launch on that save would, without the title menu, which opens only on the user's own save ([PERSISTENCE.md](../infrastructure/PERSISTENCE.md#the-title-menu)). A headless run works the same way.
- `--save=<path>` with it plays the built session in that file: an agent adds `--save=user://dev/runs/<name>.tres` to keep a run's file. A run of the main scene writes it at each `SaveTimer` tick and when its window closes, as for any file session (`--no-autosave` stops both); a run of another scene has no tick and saves nothing on close, so there the file is written only from the dev panel, when the scene hosts it: by Save now, by a switch that leaves the session while autosave is on, and, when the file is the user's own save, by New game, Keep and Restore, which write it whatever autosave says. A preset session written over the user's own save is backed up first, and still reads nothing from it ([PERSISTENCE.md](../infrastructure/PERSISTENCE.md#sessions-and-launch-options)).
- The player's log starts clean and gets one `[DEV]` line, "Started preset '<title>'", with " (pinned)" after it when the pin chose the preset.
- An id no preset folder has, or a preset that does not build, is logged with `Log.critical`, and the session falls back to the `fresh_fallback` preset ("Fresh start (the preset could not be built)"): a fresh game in memory, never on the user's save, whatever `--save` says. The `[DEV]` line says why the preset did not start.

### The pin

A preset can be pinned for a checkout, so that plain launches (the editor's Play button included) start in it until it is unpinned. `DevManager.pin_preset(preset_id)` writes the pin (`""` unpins), and `get_pinned_preset_id()` reads it.

- It is one preset id in a `ConfigFile` (section `dev`, key `pinned_preset`): `res://.dev_settings.cfg` for a run from the editor binary, in the checkout's own folder, so each worktree has its own pin and `.gitignore` keeps it out of commits; `user://dev_settings.cfg` in an exported build, whose `res://` is read-only.
- Only a plain launch uses it: one with neither `--preset` nor `--save`. A launch with `--preset` starts that preset, and a launch with `--save` is a file session, which the pinned preset would otherwise be built over. `--no-autosave` names no save, so it leaves the pin on.
- A pin whose preset is gone starts the fresh fallback in memory, with the critical log line above.
- From the panel, each preset row of the Saves tab has Pin, and Unpin on the pinned one. The pinned row reads "Pinned · plain launches start here". The pin takes effect at the next plain launch, not in the running game.

### Save this game as a preset

`DevManager.save_as_preset(title, description)` writes the running session's save as a snapshot preset, `<id>.tres`, in the folder `get_presets()` reads. A run from the editor binary writes `res://resources/dev/save_presets/`, so the file shows in `git status` and the user decides whether to commit it; an exported build writes `user://dev/save_presets/`.

- The id is the title lowercased, each run of characters outside `a-z` and `0-9` turned into `_`, and `_` trimmed from both ends: "Weird State #2!" is `weird_state_2`.
- The snapshot is a copy of the session's save that shares the item resources the inventory is keyed by and copies everything else. The session is left as it was, and one `[DEV]` line names the file.
- It returns `""` once the file is written, or why it was not: an empty title, a title with no letter or digit, an id some preset already has (an existing preset is never overwritten), or a failed write.
- From the panel, the Saves tab's SAVE THIS GAME AS A PRESET section has a Title (required), an optional Description and the Save as a preset button. It says which preset it saved and lists it, or shows why it refused.

A committed snapshot is built with the other presets, so one that no longer builds fails a test.

## DevManager

`singletons/dev_manager/dev_manager.gd`, the last autoload. It keeps the dev session, builds presets, switches sessions while the game runs, sets the [time speed](#time-speed), and keeps the dev panel's state across a switch. It builds nothing in a test run (its `_ready()` returns), so a test calls its functions itself.

`enum SessionKind { YOUR_SAVE, PRESET, FILE }` names what a session plays: the user's own save, a preset, or a `--save` file.

| Constant | Value |
|----------|-------|
| `ROUTE_PATH` | `res://resources/dev/story_route.tres` |
| `PRESET_DIR` | `res://resources/dev/save_presets/` |
| `EXPORT_PRESET_DIR` | `user://dev/save_presets/`, the presets an exported build keeps |
| `FALLBACK_PRESET_ID` | `fresh_fallback` |
| `TIME_SPEEDS` | `[1.0, 2.0, 5.0, 10.0]`, the speeds `set_time_speed()` accepts |
| `SWITCH_UNDER_WAY` | `"A session switch is already under way"`, why a switch asked for while another is pending is refused |

| Signal | Emitted |
|--------|---------|
| `session_changed` | At launch, once the launch options have set the session up, and at the end of each switch in game, a failed one included |
| `session_switch_failed(reason: String)` | When a switch is refused or fails. A refused switch changed nothing; after a failed one the session it left is back, and `session_changed` follows |
| `time_speed_changed(speed: float)` | When `set_time_speed()` has set a speed |

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
| `back_to_my_save()` | Backs the user's own save up and opens it again from disk, as a launch on it does |
| `new_game()` | Backs the user's save up, then plays a fresh save as it, written at once |
| `keep_as_my_save()` | Backs the user's save up, then plays a copy of the session's save as it, written at once |
| `restore_backup(backup_path)` | Puts a backup (`PersistenceManager.list_backups()`) back as the user's save, then opens it from disk |
| `save_as_preset(title, description) -> String` | See [Save this game as a preset](#save-this-game-as-a-preset) |
| `pin_preset(preset_id) -> Error`, `get_pinned_preset_id() -> String` | See [The pin](#the-pin) |
| `set_time_speed(speed) -> String`, `get_time_speed() -> float`, `time_speed_label(speed) -> String` | See [Time speed](#time-speed) |

`preset_dir_override` is a test-only variable: the one folder to read presets from and to save them to, in place of `PRESET_DIR` and `EXPORT_PRESET_DIR`.

`panel_open`, `panel_position` and `panel_tab` are the dev panel's open state, the top-left corner of its body and the index of its tab. They live here because the panel is in the main scene, which a switch frees and loads again: the panel writes them as they change and reads them when it is built.

### Building a preset

`build_preset()` runs at launch and in game alike:

1. A preset that `validate()` finds anything wrong with is refused with its first error, before anything changes: a beat the route lacks would otherwise play no route steps at all.
2. The save is a copy of the preset's snapshot, migrated and then repaired as a save file opened is (`SaveGameData.repair()`, which puts an unknown current zone back to the first, with a `Log.warn`; skipped when `PersistenceManager.can_verify()` says the managers it asks did not load), or a fresh save, and its play stats name the preset (`built_from_preset`). The snapshot itself is never changed.
3. `PersistenceManager.use_save()` makes it the session's save, so every manager re-binds.
4. The route's steps through the preset's beat run in order, then the preset's own. The first step that refuses stops the build and leaves its save half-built: the caller decides which session comes next.
5. Every action available in every zone, and every unlocked technique, is marked seen, as on a save played to that point, so no NEW seal shows.

Nothing the build sets off counts as play: the save's play stats stay paused for the whole build.

Restarting a preset in game leaves the managers in the same state as launching with `--preset`: nothing a build sets lives outside the save. A test builds a preset, writes the save, plays the loaded file and compares what the managers hold.

### Time speed

`set_time_speed(speed)` makes the speed the game's base `Engine.time_scale` (`GameSpeed.base_scale`, `scripts/utils/game_speed.gd`). It emits `time_speed_changed`, logs a `[DEV]` line (`Time speed ×5`) and returns `""`. A speed `TIME_SPEEDS` does not list is refused with a reason that names the speeds it does list (`Time speed ×3 is not one of ×1, ×2, ×5, ×10`), and nothing changes, is emitted or is logged. Setting the speed already set sets it again: the signal and the line repeat. `get_time_speed()` reads `GameSpeed.base_scale`, so `DevManager` keeps no second copy of the speed. `time_speed_label(speed)` writes a speed as the `[DEV]` lines, the panel's picker and its badge do (`×5`).

The speed is the base that a moment which slows time comes back to: the boss hit-stop slows the engine to a quarter of it for 0.15 s of real time, then returns to it ([ADVENTURING.md](../adventuring/ADVENTURING.md)). A session switch keeps the speed (its teardown puts the engine back to `GameSpeed.base_scale`, not to 1). The playtime counts the scaled frame time, so ×10 counts ten times as fast ([PERSISTENCE.md](../infrastructure/PERSISTENCE.md)). The speed is not saved: a new launch runs at ×1.

### Switching sessions

`play_preset()`, `play_story_through()`, `restart_preset()`, `back_to_my_save()`, `new_game()`, `keep_as_my_save()` and `restore_backup()` are switches. From the panel, the Saves tab starts them (Play on a preset row, Restart preset, Back to my save, New game on my save, Keep as my save and Restore), Ctrl+Shift+R restarts the preset, and the Story tab's Jump plays the story through a beat. The title menu's New Game calls `new_game()` too. Each runs on the next frame, because a caller such as a panel button lives in the main scene the switch frees, and the scene is deleted at once. One switch runs at a time: while one is pending, from its call until it runs, another is refused. The switch runs in this order:

1. The session it leaves is saved, when autosave is on and the session writes a file. Then autosave goes back to what the run was launched with (`PersistenceManager.restore_launch_autosave()`: off after `--no-autosave`, on otherwise), whatever the Saves tab turned it to, so the next session saves as a launch on it would.
2. What lives outside the save is torn down, which a launch never starts with: the running action stops, uncounted and with no effects; any dialogue ends (one an adventure encounter started included); the cycle session and the last cycle's result clear; the player's vitals are replaced (`PlayerManager.reset_vitals()`); the engine's time scale goes back to `GameSpeed.base_scale`, the base speed (`scripts/utils/game_speed.gd`), so a slowed moment cannot carry over.
3. The main scene is freed when it is the current scene. It never is under GUT, where the runner is, so a test run unloads and reloads no scene.
4. The new session binds: a build, a file opened again, or the new-game, keep and restore steps. A switch that fails here logs `Log.error` with the reason, brings back the session it left (your save opens again from disk, a preset is built again where it was written, a file opens again; when even that fails, `fresh_fallback` in memory), and emits `session_switch_failed`. A preset session comes back as its preset built again, not as it was played.
5. The player's log is cleared and gets one `[DEV]` line naming the new session ("Started preset 'X'", "Restarted preset 'X'", "Back to your save", ...).
6. The main scene loads again, when step 3 freed it, and `session_changed` is emitted. Views build from manager state, so the game comes up as a launch on that save would, except that the title menu, which opens once per run, stays closed.

A switch is refused at call time, before anything changes (`Log.error`, `get_last_switch_failure()`, `session_switch_failed`), when:

- another switch is pending (`SWITCH_UNDER_WAY`): every switch, before any check of its own, so a double click on Keep takes one backup. `restart_preset()` outside a preset session does nothing, even then;
- the run has no main save ("This run has no main save"): `back_to_my_save()`, `new_game()`, `keep_as_my_save()` and `restore_backup()`. Every GUT run is one, unless a test points `PersistenceManager.main_save_path` at a temp file;
- the backup to restore is not there ("There is no backup at <path>");
- the preset fails `validate()`: `play_preset()`, `play_story_through()` and `restart_preset()` (the first error, such as "story_through no_such_beat is not a beat of the route").

Every switch onto the user's save backs it up once, through `PersistenceManager.backup_main_save()`, the one way it is backed up ([PERSISTENCE.md](../infrastructure/PERSISTENCE.md#boot-and-load)). Back to my save, and a failed switch that comes back to your save, back it up as they open it, as a launch does. New game, Keep and Restore back it up before they write over it, the temp file a cut-short write left included when only that is there. A save that cannot be backed up is never overwritten ("Could not back up your save, so it was left as it was"), and the switch fails. `restore_backup()` reads the chosen backup before it backs the user's save up: a backup keeps only the newest `BACKUPS_KEPT` and deletes the oldest, and the chosen one can be the oldest. It then puts the backup's bytes in place through a temp file (`SaveFiles.write_bytes_atomically()`) and opens the file again, with no second backup.

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
| `force_win_fight(view)` | Wins the fight that is on by killing its enemy through its Health, so it pays its gold, fires `q_first_steps_enemy_defeated` and resolves its tile, as a real win does | A view that is not there; no fight on |
| `exit_adventure(view, victory)` | Ends the running adventure as a victory (its success effects, the victory end card) or a defeat (its failure effects, a retreat end card) | A view that is not there; no run |
| `known_event_ids() -> PackedStringArray` | The events the content listens to, sorted, each once: the event every `EVENT_TRIGGERED` condition waits for, and every quest step's `completion_event_id`. Firing any other event changes nothing in the game | |
| `list_item_paths() -> PackedStringArray` | The path of every item resource under `res://resources/items/`, nested folders included, sorted | |

`log_dev_line(what)` is not a command: it writes `what` as a `[DEV]` line in the player's log, the one place that writes the tag. Every command logs its success through it, and so do the dev tools that are not commands (`DevManager`'s session lines, the dev panel's toggles).

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
| MainView / MainGame | `DevPanel` is `MainView`'s last child, and `main_game.tscn` hands it the `AdventureView`. `MainGame._process()` adds the scaled frame time to the playtime, so the time speed counts |
| ResourceManager | `set_madra()`, `set_gold()` |
| CultivationManager | `add_core_density_xp()` (behind `reach_core_density()`), `advance_to_next_stage()` (behind `advance_stage()`). The Player tab's stage line reads the stage, the level and the cap, and follows `core_density_level_updated` and `advancement_stage_changed` |
| PathManager | `add_points()` |
| UnlockManager / EventManager / QuestManager | The Story tab reads `get_unlocked_condition_ids()`, `get_triggered_events()` and the quests' getters, and follows their signals. `unlock_condition_list` feeds `known_event_ids()`. `force_unlock_condition()` is a test fixture: no panel control calls it |
| CyclingManager | `get_all_techniques()`, `unlock_technique()`, `equip_technique()` |
| AdventureView / AdventureTilemap | The Adventure tab asks `is_in_combat` and `is_adventure_running()`, calls `set_show_whole_map()` → `set_dev_reveal_all()` and reads `is_dev_reveal_all()`. `force_win_combat()` and `force_end_adventure()` are behind `force_win_fight()` and `exit_adventure()` |
| LogManager | `[DEV]` audit lines; a switch clears the history (`clear_history()`) and writes one `[DEV]` line |
| PersistenceManager | `DevManager` binds a preset's save (`use_save()`), opens a file again (`open_save_file()`), saves the session it leaves (`autosave()`), puts autosave back to the launch value (`restore_launch_autosave()`), backs the user's save up (`backup_main_save()`) and writes it (`save_data()`). The Saves tab reads the session (`save_path`, `is_in_memory()`, `is_save_blocked()`, `get_block_reason()`), lists `list_backups()`, sets `autosave_enabled` and calls `save_data()`. The shell's save warning reads `is_save_blocked()` and `get_block_reason()` and follows `save_block_changed`. `LaunchOptions` carries `--preset` and the pin |
| ActionManager | `complete_without_playing()` behind `complete_action()`, `is_idle_action()` behind `travel_to_zone()`, `cancel_current_action()` in a switch's teardown |
| DialogueManager / CyclingManager / PlayerManager | A switch's teardown: `end_dialogue_now()`, `end_cycle_session()` with `clear_last_cycle_result()`, `reset_vitals()` |
| ZoneManager / PathManager / InventoryData | `is_action_used_up()`, `is_stage_reached()` with `get_unmet_prerequisite()`, `free_equipment_slots()`: the rules `DevCommands` shares with the managers. The Story tab also reads `ZoneManager.get_available_actions()` and `TribulationActionData.is_passed()` for an action's status, and the World tab `ZoneManager`'s zone list and its two zone-map switches |
| AbilityManager / CyclingManager / QuestManager | Catalog lookups behind the commands and `validate()`: `has_ability()`, `get_all_abilities()`, `has_technique()`, `get_all_techniques()`, `get_all_quests()` |
| AdventureMapGenerator / HexForestAtlas / EncounterIcon | Reused by Map Preview |

## Key Files

| File | Purpose |
|------|---------|
| `scenes/ui/dev_panel/dev_panel.gd` / `.tscn` | `DevPanel`: the shell (open state, drag, tab, time speed, the save warning, the two hotkeys) |
| `scenes/ui/dev_panel/tabs/` | One scene and script per tab: `saves_tab`, `player_tab`, `story_tab` (`DevStoryTab`), `items_tab`, `adventure_tab` (`DevAdventureTab`), `world_tab` |
| `scenes/ui/dev_panel/rows/` | `dev_preset_row` (`DevPresetRow`) and `dev_action_row` (`DevActionRow`) |
| `singletons/dev_manager/dev_manager.gd` | `DevManager`: the session, building presets, switching sessions, snapshots and the pin |
| `singletons/dev_manager/dev_commands.gd` | `DevCommands`: the command API |
| `scripts/resource_definitions/dev/` | `DevStepData`, `StoryBeatData`, `StoryRouteData`, `SavePresetData` |
| `resources/dev/story_route.tres`, `resources/dev/save_presets/` | The story route and the shipped presets |
| `scripts/utils/launch_options.gd` | `--preset`, `--save`, `--no-autosave`, the pin, test-run detection and the main-scene checks (`plays_main_scene()`, `is_main_scene()`, `main_scene_path()`) |
| `scripts/utils/game_speed.gd` | `GameSpeed`: the base time scale (`base_scale`, `set_base_scale()`) a switch puts the engine back to |
| `.dev_settings.cfg` (gitignored) | A checkout's pinned preset |
| `scenes/adventure/adventure_view/adventure_view.gd` | `force_win_combat()`, `force_end_adventure()`, `set_show_whole_map()` |
| `scenes/adventure/adventure_tilemap/adventure_tilemap.gd` | `set_dev_reveal_all()`, `_dev_reveal_all` rendering paths |
| `scripts/tools/map_preview.gd`, `scenes/tools/map_preview.tscn`, `scenes/tools/encounter_id_label.tscn` | Map Preview |
| `scripts/tools/generate_uid.gd` | UID generator |
| `scripts/tools/items_md_to_resources.gd`, `scripts/tools/items_md_parser.gd` | Items generator |

Tests: `tests/unit/test_dev_*.gd` and `tests/integration/test_dev_*.gd`, among others named after what they check; [TESTING.md](../testing/TESTING.md#coverage-gaps) lists what they do not cover.

## Work Remaining

### Bugs

- `[LOW]` `StoryRouteData.validate()` and `SavePresetData.validate()` call `validate()` on each step, so an empty slot in `steps` (the Inspector adds one before a resource is chosen) is a script error, not a listed problem.
- `[LOW]` `save_as_preset()` checks the id against the presets it can load but writes `<id>.tres`, so a file of that name holding another id is overwritten. `get_presets()` also reads a stray `<id>.tmp.tres` that a cut-short write left in a preset folder.
- `[LOW]` `LaunchOptions.read_pin()` returns `""` for a pin file that will not load, with no log line.

### Missing Functionality

- `[LOW]` Map Preview has none of the follow-ups the spec mentions: no batch statistics mode (NG3) and no overlays such as MST edges or distance labels (G5).

### UI

- `[LOW]` The spec's `HSeparator`s between panel sections are missing.
- `[LOW]` The panel's buttons, pickers and spin boxes, apart from the Saves tab's New game, Keep and Restore, keep the default focus mode, so a click gives one keyboard focus, and Space or Enter then reach it instead of the game until the focus moves.

### Tech Debt

- `[LOW]` `UnlockManager.force_unlock_condition()` has no caller outside tests.
- `[LOW]` Pressing Generate in Map Preview and then saving rewrites the committed snapshot in `scenes/tools/map_preview.tscn` (`tile_map_data` and stats text), which makes noisy diffs.
- `[LOW]` `generate_uid.gd` has no doc comment and a fixed count of 5.
- `[LOW]` The `zone-mockup` launch configuration serves `mockups/`, which is gitignored and not present in the repository.
