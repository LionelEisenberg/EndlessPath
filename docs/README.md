# EndlessPath Documentation

Start here. The living docs below describe the code on `main`, and the rules for keeping them that way are under [Keeping Docs Current](#keeping-docs-current).

## Start Here

| Doc | What it answers |
|---|---|
| [STATE_OF_THE_GAME.md](STATE_OF_THE_GAME.md) | One page: where the game stands, what's broken, what to build next, which design decisions are open |
| [GAMEPLAY_STATE.md](GAMEPLAY_STATE.md) | What a player can do today, the full content inventory, what blocks progression |
| [CODEBASE_STATE.md](CODEBASE_STATE.md) | Architecture: scene tree, state machine, the 17 autoloads, data-driven content, cross-cutting concerns |
| [Game Design Document](../Endless%20Path%20Game%20Design%20Document%20%5Bv0.1%5D.txt) | The original design vision (v0.1, 2025-10-26) |
| [CLAUDE.md](../CLAUDE.md) | Coding standards, testing rules, git workflow for contributors and agents |

## Game Systems

These living docs follow the same structure: Overview, Player Experience, Architecture, Data Model, Flows, Integration Points, Existing Content, Key Files, Work Remaining. Each ends with a tagged `[HIGH]`/`[MEDIUM]`/`[LOW]` backlog.

| System | Doc | Summary |
|---|---|---|
| Cycling | [cycling/CYCLING.md](cycling/CYCLING.md) | The lacquer cycling board: the Madra ball on its lit groove, zones scored by pressing the ball, technique drawers and the last cycle's line in the zone chest; Madra and Core Density XP |
| Cultivation | [cultivation/CULTIVATION.md](cultivation/CULTIVATION.md) | Core Density levels and cap, advancement stages (Foundation, Copper), the breakthrough |
| Tribulation | [cultivation/breakthrough-tribulation.md](cultivation/breakthrough-tribulation.md) | The Foundation → Copper breakthrough: a Spirit Valley action at a full core that runs the Breath of the Core mini-game, and where its code lives. Designed in the [spec](superpowers/specs/2026-10-23-tribulation-breath-of-the-core-design.md) |
| Zones and actions | [zones/ZONES.md](zones/ZONES.md) | The map-first lacquer zone view (map, cabinet, zone chest and its techniques mode, cards), ZoneManager/ActionManager, idle-action resolution, foraging, training, NPC and merchant actions |
| Adventuring | [adventuring/ADVENTURING.md](adventuring/ADVENTURING.md) | Procedural hex maps in the lacquer look (fog tiers, coins, rims, route dots), the vitals cabinet, chest and run clock, movement and stamina, encounters, end card |
| Combat | [combat/COMBAT.md](combat/COMBAT.md) | Real-time combat: combatants, vitals, casts, buffs, damage formula, enemy AI, enemies, the technique dock |
| Abilities | [abilities/ABILITIES.md](abilities/ABILITIES.md) | Ability data model, AbilityManager, 4-slot loadout, Abilities view |
| Ability stats | [abilities/ABILITIES_MATRIX.md](abilities/ABILITIES_MATRIX.md) | Exact values for every player and enemy ability |
| Inventory | [inventory/INVENTORY.md](inventory/INVENTORY.md) | Book UI (Equipment, Consumables, Materials, Journal), InventoryManager, loot |
| Items catalog | [inventory/ITEMS.md](inventory/ITEMS.md) | Source-of-truth item tables, parsed by the equipment `.tres` generator |
| Path progression | [progression/PATH_PROGRESSION.md](progression/PATH_PROGRESSION.md) | Pure Madra skill tree, Path Points, perk effects (and which ones are inert) |
| Quests | [progression/QUESTS.md](progression/QUESTS.md) | Quest data model, QuestManager, quest UI, authored quests |
| Foundation playthrough | [progression/FOUNDATION_PLAYTHROUGH.md](progression/FOUNDATION_PLAYTHROUGH.md) | Beat-by-beat walkthrough of current content, and the designed but unbuilt beats |

## Infrastructure

| Topic | Doc | Summary |
|---|---|---|
| UI shell and navigation | [infrastructure/MAIN_VIEW.md](infrastructure/MAIN_VIEW.md) | `main_game.tscn` tree, MainView state machine, HUD boards, cycling mode, the Tribulation board, input routing, keybindings, dock |
| Persistence | [infrastructure/PERSISTENCE.md](infrastructure/PERSISTENCE.md) | SaveGameData schema and owners, load/save/reset, auto-save, versioning |
| Resources | [infrastructure/RESOURCES.md](infrastructure/RESOURCES.md) | Madra and Gold, the two Madra caps, sources and sinks |
| Character | [infrastructure/CHARACTER.md](infrastructure/CHARACTER.md) | Attributes, derived stats, player vitals, the Character view |
| Unlocks | [infrastructure/UNLOCKS.md](infrastructure/UNLOCKS.md) | Unlock condition types, latching, every registered condition |
| Events | [infrastructure/EVENTS.md](infrastructure/EVENTS.md) | One-shot event flags and every event id |
| Effects | [infrastructure/EFFECTS.md](infrastructure/EFFECTS.md) | The `EffectData` hierarchy and where each effect is used |
| Dialogue | [infrastructure/DIALOGUE.md](infrastructure/DIALOGUE.md) | DialogueManager, Dialogic setup, characters and timelines |
| Logging | [infrastructure/LOGGING.md](infrastructure/LOGGING.md) | `Log` (diagnostics) vs `LogManager` (player-facing log), the log board and full log |
| UI styling | [UI_STYLING.md](UI_STYLING.md) | Label theme-variant type scale, the lacquer theme and pieces, theme and asset files |
| Style guide | [STYLE_GUIDE.md](STYLE_GUIDE.md) | The "Lacquer and brass" look: rules, palette, type, components, states, motion, Godot recipes, a review checklist, and the backlog of screens still to rework |
| Authoring conventions | [progression/QUESTS_EVENTS_UNLOCKS_CONVENTIONS.md](progression/QUESTS_EVENTS_UNLOCKS_CONVENTIONS.md) | When to use an event, an unlock condition, or a quest step |

## Tooling and Testing

| Doc | Summary |
|---|---|
| [testing/TESTING.md](testing/TESTING.md) | Running GUT (including the first-run `--import` gotcha), the noise a passing run prints, conventions, coverage gaps |
| [tooling/DEV_TOOLS.md](tooling/DEV_TOOLS.md) | Dev panel (Ctrl+Shift+D), map preview, UID generator, debug switches |
| [../resources/loot_tables/README.md](../resources/loot_tables/README.md) | Authoring loot tables |
| [../scenes/combat/combat_architecture.md](../scenes/combat/combat_architecture.md) | Short orientation to the combat scene code (points to COMBAT.md) |

## Planned Systems (no code yet)

| System | Doc | Unlocks at | Blocked on |
|---|---|---|---|
| Scripting | [planned/SCRIPTING.md](planned/SCRIPTING.md) | Copper | Copper gates nothing yet (the Tribulation reaches it); out-of-combat buff system |
| Elixir Making | [planned/ELIXIR_MAKING.md](planned/ELIXIR_MAKING.md) | Copper | Copper gates nothing yet; out-of-combat buff system; a way to spend materials |
| Soulsmithing | [planned/SOULSMITHING.md](planned/SOULSMITHING.md) | Iron | A Copper → Iron breakthrough and an Iron stage; Sacred Resources |

## Design Records (historical)

Point-in-time design and plan documents. Each carries a status banner. For current behaviour, read the living doc instead.

| Doc | Status |
|---|---|
| [superpowers/README.md](superpowers/README.md) | Index of the feature specs and plans (2026-04 onward, including the 2026-10 Merchant v1, map-first zone view, lacquer cycling view and Tribulation), with each one's shipped status |
| [cycling/CYCLING_UI_REDESIGN.md](cycling/CYCLING_UI_REDESIGN.md), [cycling/CYCLING_UI_IMPLEMENTATION_PLAN.md](cycling/CYCLING_UI_IMPLEMENTATION_PLAN.md) | Implemented (PR #12), then superseded by the lacquer cycling view (2026-10-23) |
| [inventory/EQUIPMENT_DESIGN.md](inventory/EQUIPMENT_DESIGN.md), [inventory/EQUIPMENT_IMPLEMENTATION_PLAN.md](inventory/EQUIPMENT_IMPLEMENTATION_PLAN.md) | Phase 1 implemented (PR #9); later phases partial or not started |
| [infrastructure/MADRA_UNIFICATION_DESIGN.md](infrastructure/MADRA_UNIFICATION_DESIGN.md), [infrastructure/MADRA_UNIFICATION_PLAN.md](infrastructure/MADRA_UNIFICATION_PLAN.md) | Implemented (PR #16) |
| [testing/TEST_SUITE_PROMPT.md](testing/TEST_SUITE_PROMPT.md) | Historical one-shot prompt that bootstrapped the test suite |

## Keeping Docs Current

Several branches are usually open at once, and every doc line that two of them edit is a merge conflict someone resolves by hand, after which the doc is often rewritten against the merged code anyway. So a feature PR leaves the living docs alone, and a small docs PR describes the change once it has merged, against the code as it landed. The living docs are the ones indexed above, apart from the Design Records.

### When docs are written

- **A feature PR does not edit living docs.** It carries its code, its tests, and its spec, plan and mock-ups in `superpowers/` (new files, which never conflict). The exceptions:
  - a doc the code reads, such as [ITEMS.md](inventory/ITEMS.md), which the equipment generator parses;
  - a command or coding rule in [CLAUDE.md](../CLAUDE.md) that work on the change needs at once;
  - a PR whose subject is the docs themselves, such as a change to these rules.
- **The feature PR lists what its docs PR will write.** Its description ends with a `## Docs to update` section: one line per living doc that owns a changed behaviour, saying what changed, and the bugs and gaps the work found for that doc's Work Remaining. The list stays in the PR description, because a notes file in the repo would conflict like the docs do. A PR that changes no documented behaviour says "None".
- **The docs PR follows the merge.** Once the user merges the feature PR, the session that built it (or whoever picks it up) cuts a `docs/<topic>` branch from the new `main` and works through the list:
  - the owning doc's tables, flows and **Work Remaining** list (delete fixed items rather than striking them through);
  - the spec's or plan's row in [superpowers/README.md](superpowers/README.md), added or set to its new status;
  - a row in the indexes above for a new doc.

  It links the feature PR and opens the same day, so `main`'s docs trail its code by hours, not days. If another docs PR merges first, merge `main` into it before its last push.
- [STATE_OF_THE_GAME.md](STATE_OF_THE_GAME.md), [GAMEPLAY_STATE.md](GAMEPLAY_STATE.md) and [CODEBASE_STATE.md](CODEBASE_STATE.md) are refreshed at milestones, in a docs PR of their own.
- A sweep across many docs (a rename, a reformat, a cleanup) goes in a PR of its own, opened while no other PR edits those docs.
- Merge `main` into your branch when you need its code, and once right before your PR merges, not after every merge to `main`. A doc conflict is resolved by keeping both sides' facts.

### What a living doc holds

A system doc says what the player gets and why, and where to start reading the code. The code and its `##` comments own the rest, so that most code changes touch no doc line.

- **Keep** what the player sees and does, and the design reasons behind it; the tuning values a designer changes (costs, rates, timings, caps); and the entry points: the class or scene that owns each piece, the public functions and signals other systems call, the Data Model field tables and the Key Files table.
- **Cut** line numbers (`main_view.gd:139`), layout geometry (positions, widths, px gaps, sizing formulas), unique node names (`%LastCycleLabel`) and constants, call-by-call chains ("X calls Y, which calls Z"), lists of a class's methods that repeat its script, and private `_helpers()` (Godot's own callbacks, such as `_ready()` and `_gui_input()`, are fine). [STYLE_GUIDE.md](STYLE_GUIDE.md) and [UI_STYLING.md](UI_STYLING.md) keep their sizes, because there the sizes are the spec.
- **One home per fact.** Each behaviour, API or rule is described in one doc, the system doc that owns it. Other docs link to it instead of restating it, so a change edits one doc, not five. [CLAUDE.md](../CLAUDE.md) holds rules, commands and pointers, not system detail.
- **Nothing a command can tell you.** No counts of tests, scripts, scenes, resources, shaders or lines, and no test run results or times: the test runner prints those. No `Last updated:` line and no record of which PR changed a doc: `git log -- <doc>` has both. No "Used by" lists or columns for shared widgets, components, theme variants or constants: a search finds their users, and such a list changes whenever one of them does. A data field's or method's "Used by" can stay when it says whether anything reads it at all.
- **No test lists or review history.** A system doc does not list its test files: their names say what they check, and [TESTING.md](testing/TESTING.md#coverage-gaps) lists what they miss. Describe behaviour as it is now, not the review or the date that changed it: that history belongs in the spec's or plan's "As built" section.
- **Describe `main`.** No branch names, no "not merged", no "in flight" entries: work in progress belongs in the PR description and in its spec or plan. The one exception is a dormant branch that holds unfinished work, which the Work Remaining item that would pick it up may name.
- A spec or plan is a point-in-time record, so these rules do not apply to it.
