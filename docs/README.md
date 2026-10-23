# EndlessPath Documentation

Last updated: 2026-10-23

Start here. All docs below were audited against the code on `main` (`21b3cb2`) on 2026-10-18. The zone view, UI shell, logging, quest UI and related docs were updated on 2026-10-22 for the map-first zone view (merged as PR #51). The cycling, style guide, zones, UI shell, resources, logging, persistence, testing and related docs were updated on 2026-10-23 for the lacquer cycling view (merged as PR #57). The adventuring and combat docs, the style guide and the testing docs were updated on 2026-10-23 for the adventure view's map and frame on `feat/adventure-view-styleguide-1fc223` (PR 1 of 2, not merged).

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
| Cultivation | [cultivation/CULTIVATION.md](cultivation/CULTIVATION.md) | Core Density levels, advancement stages, breakthrough status |
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
| UI shell and navigation | [infrastructure/MAIN_VIEW.md](infrastructure/MAIN_VIEW.md) | `main_game.tscn` tree, MainView state machine, HUD boards, cycling mode, input routing, keybindings, dock |
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
| [testing/TESTING.md](testing/TESTING.md) | Running GUT (including the first-run `--import` gotcha), conventions, coverage map, gaps |
| [tooling/DEV_TOOLS.md](tooling/DEV_TOOLS.md) | Dev panel (Ctrl+Shift+D), map preview, UID generator, debug switches |
| [../resources/loot_tables/README.md](../resources/loot_tables/README.md) | Authoring loot tables |
| [../scenes/combat/combat_architecture.md](../scenes/combat/combat_architecture.md) | Short orientation to the combat scene code (points to COMBAT.md) |

## Planned Systems (no code yet)

| System | Doc | Unlocks at | Blocked on |
|---|---|---|---|
| Scripting | [planned/SCRIPTING.md](planned/SCRIPTING.md) | Copper | Breakthrough; out-of-combat buff system |
| Elixir Making | [planned/ELIXIR_MAKING.md](planned/ELIXIR_MAKING.md) | Copper | Breakthrough; out-of-combat buff system; a way to spend materials |
| Soulsmithing | [planned/SOULSMITHING.md](planned/SOULSMITHING.md) | Iron | Breakthrough; Sacred Resources |
| Breakthrough / Tribulation | [cultivation/breakthrough-tribulation.md](cultivation/breakthrough-tribulation.md) | Foundation → Copper | Not started; design conflicts with FOUNDATION_PLAYTHROUGH Beats 7–9 |

## Design Records (historical)

Point-in-time design and plan documents. Each carries a status banner. For current behaviour, read the living doc instead.

| Doc | Status |
|---|---|
| [superpowers/README.md](superpowers/README.md) | Index of the feature specs and plans (2026-04 onward, including the 2026-10 Merchant v1, map-first zone view and lacquer cycling view), with each one's shipped status |
| [cycling/CYCLING_UI_REDESIGN.md](cycling/CYCLING_UI_REDESIGN.md), [cycling/CYCLING_UI_IMPLEMENTATION_PLAN.md](cycling/CYCLING_UI_IMPLEMENTATION_PLAN.md) | Implemented (PR #12), then superseded by the lacquer cycling view (2026-10-23) |
| [inventory/EQUIPMENT_DESIGN.md](inventory/EQUIPMENT_DESIGN.md), [inventory/EQUIPMENT_IMPLEMENTATION_PLAN.md](inventory/EQUIPMENT_IMPLEMENTATION_PLAN.md) | Phase 1 implemented (PR #9); later phases partial or not started |
| [infrastructure/MADRA_UNIFICATION_DESIGN.md](infrastructure/MADRA_UNIFICATION_DESIGN.md), [infrastructure/MADRA_UNIFICATION_PLAN.md](infrastructure/MADRA_UNIFICATION_PLAN.md) | Implemented (PR #16) |
| [testing/TEST_SUITE_PROMPT.md](testing/TEST_SUITE_PROMPT.md) | Historical one-shot prompt that bootstrapped the test suite |

## Keeping Docs Current

- When a change alters behaviour, update the matching living doc in the same PR: its tables, its flows, and its **Work Remaining** list (delete fixed items rather than striking them through).
- Bump `Last updated:` at the top of each doc you touch.
- New specs and plans go in `superpowers/specs/` and `superpowers/plans/`. Add a row to [superpowers/README.md](superpowers/README.md) and update its status when the work ships.
- Refresh [STATE_OF_THE_GAME.md](STATE_OF_THE_GAME.md) and [GAMEPLAY_STATE.md](GAMEPLAY_STATE.md) at milestones.
