# Dev Tools, Save Presets and Save Safety — Design

> **Status:** brainstormed with the user on 2026-10-24. The user confirmed the preset model (recipes built through the game's own systems, a restart that never touches their save, presets kept in the repo, presets that start in the zone view) and approved the save-system list. They handed the dev panel to the designer ("make things better"); every panel choice below is the designer's call. Not built.
>
> **Scope:** three stages that build on each other: (1) save safety and per-run save control, (2) save presets with a one-key restart, and (3) a reworked dev panel over both. Out of scope: the AI-driven gameplay checks (bot playthroughs, a signposting check, an AI playtester), which get their own brainstorm once this lands. This design lays their groundwork: launching into a preset, one dev command API, and play stats in the save.

## Goal

The last time the user tested the Tribulation, they had to reach Core Density 100 by hand (dev panel XP, then the quests), copy `save.tres` somewhere safe, and keep a terminal command that copied it back into the save folder. Every retry meant quitting, running the copy and relaunching, because the 5 s autosave had already written over the copy. Later stages will put quests and actions in front of the Tribulation, so reaching it by hand will only get slower, and a copied save made today will not have done those quests.

Presets end that loop: pick "Tribulation ready", play the trial, press Ctrl+Shift+R, and play it again, as many times as needed, while the user's real save stays untouched. A preset is a recipe ("story through the last beat before the Tribulation, then Core Density 100") applied through the real game systems, so it picks up new quests and survives save-format changes. The save system gains what presets need (choosing the save per run, loading without relaunching) and what keeps saves from breaking (a version number with migrations, safe writes, backups). The dev panel becomes the place to drive all of it.

Four findings from the code shaped the design:

- **Every run shares one save.** `config/name` is `EndlessPath` and no custom user folder is set, so the editor, every worktree, every agent and the GUT runner all point at `%APPDATA%\Godot\app_userdata\EndlessPath\save.tres`. Tests load it at boot; any game run writes it every 5 s.
- **Saves have no version number.** Schema changes broke saves twice (`1ce7ecd`, `0652b49`, see [PERSISTENCE.md](../../infrastructure/PERSISTENCE.md#versioning)). A copied save would break the same way.
- **Each test reaches a beat its own way.** For example, `test_beat_3b_merchant_unlock.gd` writes `core_density_level = 10.0` straight into the save and emits the level signal by hand.
- **The gameplay checks already have a spec.** [FOUNDATION_PLAYTHROUGH.md](../../progression/FOUNDATION_PLAYTHROUGH.md#loop-economy) lists pacing targets per beat and economy targets with fail signals. Play stats in the save make them measurable.

## Decisions

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Main preset form | **Recipes**: a point on a story route plus a few steps, applied to a fresh save through the managers' public APIs | Confirmed by the user. A recipe picks up a quest added in front of the Tribulation and never holds stale save data. Rejected as the main form: copied saves ("snapshots"), which go stale with every content and format change | — |
| Snapshots | Kept as a second kind: "Save this game as a preset" embeds the current save in a preset file | For odd states found by playing, which no recipe describes. The version number and a load test keep them working | — |
| How story progress is applied | An explicit **story route**: an ordered list of beats, each a list of steps, written as data and run only on a fresh save. A coverage test fails when story content exists that the route neither reaches nor lists as left out | Simple, readable and loud when it drifts. Running it only on a fresh save means every step meets the state it was written for; a save already under way can be past a step in ways the step can't see (a later technique equipped, a later stage). Rejected: a generic solver that works out how to satisfy any quest step. It is the story half of a bot player and belongs to the gameplay-checks project | The bot project builds a solver; the route can then be generated or checked against it |
| Step format | One resource class, `DevStepData`, with a `kind` enum, an id and an amount, in the style of `UnlockConditionData` | Inspector-friendly (a dropdown per step), consistent with the codebase, one file. Rejected: a class per step kind (many files for one-line steps) and command strings (a parser, and typos caught only at runtime) | Steps need more than an id and an amount |
| Where a preset session's save lives | **In memory.** Nothing is written unless the run was given `--save=<path>` | No collisions on the shared `user://` folder between worktrees and agents, and nothing to clean up. A restart rebuilds the preset anyway | Someone needs a preset session to survive a crash |
| Restart mechanics | Tear down the main scene, rebuild the save from the preset, then load the main scene again, so the game comes up exactly as a launch on that save would | Views rebuild from manager state with no per-view reset code. Rejected: swapping the save under live views (every view would need its own reset), and restarting the process (slower, and a run started from the editor loses its debugger and output) | — |
| Dev logic home | A new autoload, **`DevManager`**, last in the autoload order | It needs a lifecycle (build a preset after every manager is ready and before the main scene loads; reload the scene) and session state (current preset, time speed, panel position). The panel, presets, launch options and tests all call its functions | — |
| Newer and shared saves | A save written by a newer build, or one another run is already writing, runs in memory with a visible warning and is never written | The rule `PersistenceManager` already follows for unreadable saves: never overwrite a save it can't trust. Every checkout and agent shares one `save.tres`, so both will happen. Rejected: writing anyway, which drops whatever the older build doesn't know | Older checkouts not saving gets in the way |
| Save format | Stay on `.tres` | The save is built around resources (inventory dictionaries are keyed by item `.tres` files). JSON is safer once players share saves, because loading a `.tres` can run code, but switching is a large rewrite that pays off only at release | Before builds go to players |
| Dev panel | The existing in-game floating panel, reworked into tabs | Works in any run, editor or not. Exempt from the lacquer look ([STYLE_GUIDE.md](../../STYLE_GUIDE.md), G11) | — |
| Gameplay checks | Not in this design. Groundwork only | The user was unsure about them; they need this groundwork first and deserve their own brainstorm | This lands |

## Goals, non-goals, anti-goals

**Goals**
- Reach any built story moment (Tribulation ready, Merchant open, Copper, …) in one click or one launch option, and restart it with one key.
- Presets that keep working when quests are added and when the save format changes, and that fail a test loudly when they can't.
- Agents and tests run the full game in a known state without reading or writing the user's save.
- Saves survive format changes, crashes mid-write and bad builds.
- One dev command API under the panel, presets, launch options and tests.
- Play stats (playtime, when each beat was reached, a few counts) recorded in every save.

**Non-goals**
- Player-facing save slots, a title screen or a New Game menu. There are no players yet.
- Saving mid-adventure, mid-fight or mid-action. Presets always start in the zone view.
- Moving off `.tres`.
- The gameplay checks themselves.
- Restyling the dev panel in the lacquer look.

**Anti-goals** (failures even if everything technically works)
- The user's real save is overwritten, wiped or edited by a preset, a test, an agent or a dev button without a backup.
- Dev code re-implements game logic. Every dev command calls the same public functions gameplay calls; a game rule lives in one place.
- A preset silently builds the wrong state after content changes.
- Dev tools change how normal play behaves.

## How the user works with it

**Retrying a moment.** Open the panel (Ctrl+Shift+D), Saves tab, pick "Tribulation ready", Play. The game reloads in Spirit Valley at Core Density 100 with every earlier quest done. Play the trial, pass or fail, press Ctrl+Shift+R: the game is back at the start of the preset. The user's save was written once on the way out and is not touched while the preset runs.

**Starting every launch in a preset.** Pin a preset in the Saves tab. Every launch from that checkout (the editor's Play button included) then starts in it, until unpinned. The pin is stored per checkout, so other worktrees and agents are unaffected. A log line and the panel say when a launch started in a pinned preset.

**Keeping an odd state.** "Save this game as a preset" asks for a title and writes a snapshot preset into the repo's preset folder, ready to commit.

**Jumping to a beat.** The Story tab's "Jump story to" starts a fresh preset session through the chosen beat, as an unnamed preset that Ctrl+Shift+R restarts. The route never runs on a save that is already under way, the user's own included.

**Agents and scripted runs.** Launch the main scene with user arguments after `--`:

```
<godot> --path . scenes/main/main_game/main_game.tscn -- --preset=tribulation_ready
```

The session lives in memory. Add `--save=user://dev/runs/<name>.tres` to keep its file. Headless runs work the same way, which is what the gameplay-checks project will build on.

## Save system

### Sessions

Every run plays one **session**, one of:

| Session | Started by | Reads | Writes |
|---|---|---|---|
| Your save | A normal launch | `user://save.tres` | `user://save.tres` (autosave, save on quit, "Save now") |
| Preset | `--preset=<id>`, a pinned preset, or Play in the panel | Nothing from disk except the preset file | Nothing, unless `--save=<path>` was given |
| File | `--save=<path>` without `--preset` | That file (created if missing) | That file |

`--no-autosave` turns off the timer and the save on quit for any session; "Save now" still writes. The panel shows which session is running and where it writes.

Switching session in game (Play a preset, Back to my save, Restart) uses the restart mechanics under [Building a preset](#building-a-preset): the main scene is freed, the new save is bound, the main scene loads again. Leaving a session that writes a file saves it first, unless `--no-autosave` is on.

### Launch options

A small static helper (for example `LaunchOptions` in `scripts/utils/`) parses `OS.get_cmdline_user_args()` once and merges the checkout's pinned preset. A command-line option beats the pin. `PersistenceManager` reads it at boot to decide what to load; `DevManager` reads it to decide what to build.

| Option | Effect |
|---|---|
| `--preset=<id>` | Start a preset session built from preset `<id>` |
| `--save=<path>` | Use this save file; with `--preset`, write the built session there |
| `--no-autosave` | No timer saves and no save on quit |

A preset id that does not exist, or a preset that fails to build, logs `Log.critical` with the reason and falls back to an in-memory fresh save. It never falls back to the user's save, so an agent run can't touch it by mistake.

### Test isolation

GUT runs (the command line, `tests/run_tests.ps1` and the editor panel) never read or write the real save. `PersistenceManager` boots them on an in-memory default save with saving off. How a test run is detected is the builder's call. Tests that today depend on whatever the developer's save holds will surface and get fixed. Once a run can't write the real save, instancing `main_game.tscn` in a test becomes safe; nothing has to use that yet.

### Versioning and migrations

- `SaveGameData` gains `save_version: int`, defaulting to **0**, and a constant for the current version.
- **The default trap:** Godot builds a loaded resource with `new()` and then sets only the keys the file holds. If `_init()` or the field default stamped the current version, every old file would look current. So the default stays 0 ("unversioned"), and the current version is stamped when a save is created fresh, after a migration, and on every write.
- `migrate()` runs ordered steps from the loaded version up to the current one. Version 1 holds today's zone-id move. Whether v1 also moves accessories saved under `equipped_gear` keys 4 and 5 into `equipped_accessories` (the gap [PERSISTENCE.md](../../infrastructure/PERSISTENCE.md#versioning) records) is the builder's call.
- Saves from before 2026-05-23 (`1ce7ecd`) stay unsupported: they load, but their attributes come back as defaults, and no step will convert them.
- Every save that loads goes through `migrate()`: the user's save, `--save` files and snapshot presets.

### Safe writes, backups, repair

- **Safe writes.** Every write goes to a temporary file next to the target, which then replaces the target. A crash mid-write leaves the old file intact.
- **Boot backup.** Before anything writes in a "Your save" session, the save as it was at launch is copied to `user://backups/` with a timestamp. The newest 10 are kept.
- **Backups before dev overwrites.** New game, Restore and "Keep as my save" back up the user's save first.
- **Save on quit.** `NOTIFICATION_WM_CLOSE_REQUEST` saves the session (unless `--no-autosave`). The editor's Stop button kills the process, so it still loses up to 5 s.
- **Repair, not wipe.** When `verify()` finds an unknown `current_selected_zone_id`, only that field is cleared (`ZoneManager` then picks the first zone), with a warning. The rest of the save stays.
- **Newer saves are never written.** A save whose `save_version` is newer than the build knows (a branch added a migration step, then another checkout launched) runs in memory with saving off, as an unreadable save does today. The log and the Saves tab say why. Writing it would drop what the older build doesn't know, the loss `1ce7ecd` caused.
- **One writer per save.** A "Your save" or file session holds a lock file next to its save, refreshed on every write. A second run that finds a live lock (the user's editor plus an agent launched without `--preset`, say) runs in memory with a warning instead of overwriting the first run's progress every 5 s. A lock whose process is gone, or that hasn't been refreshed for a while, is stale and taken over.
- **`reset_save_data` goes.** New game in the panel and `--preset=fresh` replace the script edit, which is easy to commit by accident.
- **Defaults declared once.** `reset()` copies every stored field from a fresh `SaveGameData.new()` instead of repeating each default by hand.
- **Saves always come from disk.** Every load of a save or preset uses `ResourceLoader.CACHE_MODE_IGNORE`, so a second restart never gets the instance the first one mutated. Never `CACHE_MODE_IGNORE_DEEP`: inventory dictionaries are keyed by the shared item resources, so item files must come from the cache.
- **Errors surface.** A failed timer save is logged instead of dropped.

### Play stats

`SaveGameData` gains a stats sub-resource:

- **Playtime:** seconds of game time while the main scene runs (scaled by the dev time speed, so ×10 counts ten times as fast).
- **First times:** for each event and each unlock condition, the playtime at which it first fired or latched. Story route beats name the event or condition that marks them reached, so the panel can show "Beat 2 reached at 4:12".
- **Counts:** cycles finished, adventures started, won, lost and timed out, fights won, and gold earned. Each is recorded by the system that owns the moment. Dev commands never count as earned. The exact list is the builder's call.
- **`built_from_preset`:** the preset id a save was built from, empty for real play, so a preset session's stats are never mistaken for a playtest.

## Presets

### Data model

All under `scripts/resource_definitions/dev/`; instances under `resources/dev/`.

| Class | Fields | Notes |
|---|---|---|
| `DevStepData` | `kind` (enum), `target_id: String`, `amount: float` | One step. `apply() -> bool` calls the matching `DevManager` command; `describe() -> String` for the panel; `validate() -> Array[String]` returns errors (an unknown id, a missing amount) |
| `StoryBeatData` | `beat_id`, `title`, `steps: Array[DevStepData]`, `reached_when: String` (the event or condition id that marks the beat reached in real play) | One point on the story route. `reached_when` feeds play stats and the coverage test; it never controls a build |
| `StoryRouteData` | `beats: Array[StoryBeatData]`, `optional_quest_ids: Array[String]`, `excluded_action_ids: Array[String]` | The canonical playthrough, in order, plus the content it deliberately leaves out (see the coverage test). One file, `resources/dev/story_route.tres` |
| `SavePresetData` | `preset_id`, `title`, `description`, `story_through: String` (a beat id, or empty), `steps: Array[DevStepData]`, `snapshot: SaveGameData` (optional, embedded) | A recipe preset leaves `snapshot` empty; a snapshot preset embeds one and usually leaves `story_through` empty. Files in `resources/dev/save_presets/` |

**Step kinds** (each calls one `DevManager` command; see [DevManager](#devmanager-the-command-api)):

| Kind | Target | Amount | Effect |
|---|---|---|---|
| `COMPLETE_ACTION` | action id | — | Counts one completion and runs the success effects, as if played. Skipped when the action has reached `max_completions`. Fails when the action is not available now: a route step out of order is a bug, so it fails the build and its test |
| `TRIGGER_EVENT` | event id | — | Fires the event; skipped once fired. For the events the adventure or combat fires: `q_first_steps_enemy_defeated`, `aura_well_discovered`, `merchant_discovered` |
| `REACH_CORE_DENSITY` | — | level | Raises Core Density to at least that level in the current stage, adding the XP through `add_core_density_xp()` (milestone path points pay, `core_filled` fires). Does nothing at or above it |
| `SET_MADRA`, `SET_GOLD` | — | value | Sets the resource to exactly the value |
| `BUY_PATH_NODE` | node id | — | Buys the node through `PathManager.purchase_node()`, granting path points only when the balance is short. Skipped once bought |
| `UNLOCK_TECHNIQUE`, `UNLOCK_ABILITY` | technique or ability id | — | Unlocks it; skipped once unlocked |
| `EQUIP_TECHNIQUE` | technique id | — | Equips it, replacing the equipped technique |
| `EQUIP_ABILITY` | ability id | slot, 1–4 | Equips it in that slot, replacing what is there. Fails without a valid slot |
| `AWARD_ITEM` | item path or id | quantity | Awards that many through `InventoryManager.award_items()` |
| `ADVANCE_STAGE` | — | — | Moves to the next stage, as a Tribulation pass does (`advance_to_next_stage()`). Fails when there is none |
| `TRAVEL` | zone id | — | Makes it the current zone |

The route only ever runs on a fresh save, beat by beat in order, so each step meets the state it was written for. A preset's own steps run after the route, or on top of a snapshot, with the effects above.

### The story route

A starting point the builder verifies against the content (ids from [FOUNDATION_PLAYTHROUGH.md](../../progression/FOUNDATION_PLAYTHROUGH.md#beat-chain-at-a-glance)):

| Beat id | Steps | Reached when |
|---|---|---|
| `beat_1` Awakening | complete `celestial_intervener_dialogue_1`; set Madra 100; complete `celestial_intervener_dialogue_2` | event `q_fill_core_completed` |
| `beat_2` First Steps Out | trigger `q_first_steps_enemy_defeated`; complete `celestial_intervener_dialogue_3`; buy `pure_core_awakening`; equip technique `smooth_flow`; equip ability `empty_palm` in slot 3 | event `celestial_intervener_dialogue_3` |
| `beat_3a` Aura Well | trigger `aura_well_discovered` | event `aura_well_discovered` |
| `beat_3b` Merchant unlocked | reach Core Density 10; complete `celestial_intervener_dialogue_4`; trigger `merchant_discovered` | event `merchant_discovered` |
| `beat_9_ready` Tribulation ready | reach Core Density 100 | condition `core_density_full` |
| `beat_9` Copper | advance stage | the stage change (the builder picks the marker) |

New beats go in where they play. Beats 5 and 6 will sit before `beat_9_ready`, so "Tribulation ready" (story through `beat_9_ready`) includes them with no change to the preset.

**Rules**
- A beat only uses step kinds; it never edits save fields directly.
- **Coverage test.** The whole route applies to a fresh save, step by step, without a failure, and:
  - every quest in the catalog ends completed, except those in the route's `optional_quest_ids`;
  - every action in the zones of `zone_data_list.tres` was available after some step, except those in the route's `excluded_action_ids`. This catches beats with no quest or NPC, such as the Aura Well;
  - every NPC dialogue action with a completion cap ends used up;
  - every beat's `reached_when` fired.

  New story content without a route step fails it, so leaving something out is always a listed decision. [QUESTS_EVENTS_UNLOCKS_CONVENTIONS.md](../../progression/QUESTS_EVENTS_UNLOCKS_CONVENTIONS.md) gains that authoring rule.
- Optional player choices (Power Font, merchant purchases) stay out of the route; presets add them. An optional quest goes in `optional_quest_ids` unless a beat completes it.

### Starting presets

| Preset id | Title | Story through | Extra steps |
|---|---|---|---|
| `fresh` | Fresh start | — | — |
| `adventure_open` | Adventure open | `beat_1` | — |
| `path_open` | First keystone | `beat_2` | — |
| `merchant_open` | Merchant open | `beat_3b` | gold 700 (every piece affordable) |
| `tribulation_ready` | Tribulation ready | `beat_9_ready` | — |
| `copper` | Copper | `beat_9` | — |

A test builds every preset in `resources/dev/save_presets/` on a fresh session: each must build without errors and pass its steps' `validate()`, and each snapshot must load and migrate.

### Building a preset

The same build runs at boot and in game:

1. **Nothing is listening.** At boot, `DevManager` builds in its `_ready()`, after every other autoload and before the main scene loads. In game, the main scene is freed first. Either way no view exists, so no toast, dialogue or board reacts mid-build.
2. **Runtime state is cleared.** The current action stops without completion effects, and the cycling session and other runtime state outside the save reset.
3. **A save is bound.** A fresh `SaveGameData` (stamped with the current version), or the preset's snapshot loaded from disk and migrated, becomes the live save, and `save_data_reset` re-binds every manager.
4. **The recipe applies.** The route's beats run in order up to `story_through`, then the preset's own steps. The first failing step stops the build and reports which step and why.
5. **The log starts clean.** The player log is cleared (`LogManager` gains a way to clear its history) and gets one `[DEV]` line naming the preset.
6. **The main scene loads.** It comes up exactly as a launch on that save would: the idle action resumes through the normal flow and every view reads manager state.

**Boot equivalence** is the rule that keeps this honest: restarting a preset in game must leave the game in the same state as launching with `--preset=<id>`. A test checks it at manager level.

If the build fails in game, the panel shows the error and the game returns to the session it was in.

### Snapshots

"Save this game as a preset" writes a `SavePresetData` with the current save embedded into `res://resources/dev/save_presets/<slug>.tres` (an editor run can write into the project folder; an exported build writes to `user://dev/save_presets/` instead). The new file shows in `git status`, so the user decides whether to commit it. A committed snapshot is covered by the preset build test, so a format change without a migration step fails a test instead of breaking the preset.

## DevManager: the command API

`singletons/dev_manager/dev_manager.gd`, the last autoload.

**It owns**
- The session: its kind, the running preset id, the pin, and switching (play a preset, restart, back to your save, new game, keep as my save).
- Building presets ([Building a preset](#building-a-preset)), the route and the preset catalog (loaded from `resources/dev/`).
- Time speed, and the panel's position, open state and tab across scene reloads.
- The commands below.

**Commands** (names indicative). Each calls the owning manager's public API and logs a `[DEV]` line:
complete action, trigger event, reach Core Density, set Madra, set gold, add path points, buy path node, unlock and equip technique, unlock and equip ability, award item, grant an equipment page, add to a base attribute, advance stage, travel to zone, refill vitals, set time speed, save now, and start a fresh session from a preset or through a route beat.

**Rules**
- **No mirrored logic.** A command that needs behaviour a manager keeps private gets a public function on that manager, used by gameplay and dev alike. Example: `ActionManager` gains one public way to complete an action without playing it (count the completion, run the success effects), and its own stop path uses it too.
- Commands return success or a reason, so the panel, the route and tests can report failures.
- Dev-only toggles that already live on managers stay there (`ZoneManager`'s demo and hidden zones).

## Dev panel

### Shell

- A floating, draggable panel, wider than today's 340 px, with a title bar (title, time-speed picker, close) and a `TabContainer`. Each tab scrolls on its own.
- Ctrl+Shift+D toggles it. Position, open state and tab survive restarts (held by `DevManager`).
- **UI rules** (the project's): every node is in a `.tscn`. Dynamic lists either fill built-in list controls with data (`ItemList`, `Tree`, `OptionButton`) or instance a row `.tscn`; no `Node.new()` UI and no styling in code. No text is cut off: long text wraps and the panel grows or scrolls. Exempt from the lacquer look; the dev panel title stops overriding its font size inline.
- `dev_panel.tscn` gets a real UID in place of `uid://dev_panel_001`.

### Tabs

| Tab | Contents |
|---|---|
| **Saves** | The running session: kind, where it writes (or "in memory, not saved"), version, playtime, stage and Core Density, gold, and each route beat with the minute it was reached. **Restart preset** (Ctrl+Shift+R; preset sessions only). **Back to my save.** The preset list (title and description) with **Play** and **Pin / Unpin**. **Save this game as a preset** (title, optional description). **New game on my save** (confirm; backs up first). **Keep as my save** (preset or file sessions; backs up first). **Save now.** Autosave on / off. Backups with **Restore** (backs up first). **Open save folder** |
| **Player** | Madra and gold (set). Core Density level (reach; through real XP). Stage (shown; advance). Path points (add). Base attributes (add). Abilities and techniques: unlock all, or unlock and equip from a picker |
| **Story** | **Jump story to** a route beat (a fresh preset session through it). Active quests with their current step and its description; completed quests. **Trigger event** (a picker of every event id the content uses). **Action inspector:** the current zone's actions, each shown as available, used up, or locked with the unmet conditions listed, and **Complete** on available ones. Triggered events and latched conditions |
| **Items** | Item picker over `res://resources/items/`, quantity, **Give**. **Grant equipment page** |
| **Adventure** | Shown while an adventure runs: **Force-win fight** (fixed, see below), **Exit as victory / defeat**, **Show whole map**, **Refill vitals** |
| **World** | **Travel to** a zone (hidden ones included). Demo zones and hidden zones toggles |

**Time speed** (title bar): ×1, ×2, ×5, ×10, for waiting on idle actions, training and timers. Real-time mini-games (cycling, combat, the Tribulation) are not meant to be played above ×1. When the speed is not ×1, a small badge stays on screen even with the panel closed. The adventure hit-stop (`adventure_tilemap.gd`, which sets `Engine.time_scale` to 0.25 and back to 1.0) restores the dev speed instead of 1.0; `DevManager` owns the base time scale.

### Changes to today's controls

- **Force-win** kills the enemy through its normal death path (its health reaches 0, so `AdventureCombat._on_enemy_health_changed()` runs), so the fight's gold and `q_first_steps_enemy_defeated` fire. This fixes the open bug in [DEV_TOOLS.md](../../tooling/DEV_TOOLS.md#bugs).
- **Force condition** is dropped. A forced condition doesn't satisfy quest steps, encounter choices or encounter eligibility ([DEV_TOOLS.md](../../tooling/DEV_TOOLS.md#controls), caveats), so it misleads. Trigger event, Complete action and Jump story to replace it. Whether `UnlockManager.force_unlock_condition()` stays is the builder's call (delete it if nothing uses it).
- The panel stops finding the adventure view by the absolute path `MainGame/MainView/AdventureView` and stops reading the private `CyclingManager._technique_catalog`.

## Tests

- `SaveGameData` round trip: a save with every field set (resource-keyed inventory dictionaries, equipped accessories, enums, stats) saves, reloads and compares equal.
- Versioning: an unversioned save migrates and is stamped; a loaded old file is not mistaken for current; each migration step.
- Safe writes, the boot backup and its rotation, repair instead of wipe, save on quit.
- A newer save runs in memory and is never written; a second run on a locked save runs in memory; a stale lock is taken over.
- Launch options parsing, and that a bad preset never falls back to the user's save.
- Test isolation: a GUT run's save path is not the real save, and nothing writes.
- Each step kind: applies with the effect in its table, skips where its table says, validates.
- The route coverage test and the preset build test (above).
- Boot equivalence for a preset at manager level.
- `DevManager` commands, each against the real managers.
- Panel wiring: one light integration test per tab that a control reaches its command.

Every test calls production code ([TESTING.md](../../testing/TESTING.md#avoid-mirror-tests)). New tests that need a story state use `DevManager` and the route instead of setting fields; existing tests move over when they are next touched.

## Docs to update

Each fact goes to its one home ([Keeping Docs Current](../../README.md#keeping-docs-current)):

- [PERSISTENCE.md](../../infrastructure/PERSISTENCE.md): sessions, launch options, versioning, safe writes, backups, repair, play stats; Work Remaining items this closes.
- [DEV_TOOLS.md](../../tooling/DEV_TOOLS.md): the panel, presets, the route, `DevManager`, time speed.
- [TESTING.md](../../testing/TESTING.md): test isolation, and presets and the route as the way to set up story state.
- [MAIN_VIEW.md](../../infrastructure/MAIN_VIEW.md) keybindings: Ctrl+Shift+R.
- [QUESTS_EVENTS_UNLOCKS_CONVENTIONS.md](../../progression/QUESTS_EVENTS_UNLOCKS_CONVENTIONS.md): a new quest or zone action needs a route step, or a listing in the route's `optional_quest_ids` or `excluded_action_ids`.
- `CLAUDE.md`: launching into a preset, and the singleton count it states.

## Stages

Each stage leaves the game working, updates the docs for what it changes, and can be its own PR.

1. **Save safety and control.** Launch options (`--save`, `--no-autosave`), test isolation, versioning and migrations, newer-save handling and the save lock, safe writes, backups, save on quit, repair, defaults declared once, the round-trip test, play stats, removing `reset_save_data`.
2. **Presets.** `DevManager` with its commands and session switching, the step, beat, route and preset classes, the route and starting presets, `--preset` and the pin, the restart, `ActionManager`'s public complete, the coverage, build and boot-equivalence tests.
3. **Dev panel.** The tabbed panel, the Saves tab and the rest, Ctrl+Shift+R, time speed and its badge, the Force-win fix, dropping Force condition.

## Left to the builder

- The exact panel layout and the control type behind each list.
- How a GUT run is detected.
- How the save lock is kept, and when it counts as stale.
- File names, and where the per-checkout pin lives (a gitignored file in the project folder fits).
- The exact play-stats counts and where each is recorded.
- Whether migration v1 also moves the old accessory keys.
- The final route steps, verified against the content, and the marker for `beat_9`.
- The teardown details of a restart, as long as boot equivalence holds.

## Later

- **Gameplay checks**, next: bot playthroughs against the pacing targets, the signposting check, an AI playtester. This design gives them `--preset` with a private `--save`, the `DevManager` API and play stats.
- A generic quest solver, if the bot project builds one.
- Player-facing save slots, a title screen, and JSON saves before release.
- Saving mid-adventure.
