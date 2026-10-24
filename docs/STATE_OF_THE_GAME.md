# Endless Path: State of the Game

Snapshot: 2026-10-18 · `main` @ `21b3cb2` (last commit 2026-06-01) · Godot 4.6

Updated 2026-10-22 for the map-first "Lacquer and brass" zone view (merged as PR #51, Godot 4.7.2), 2026-10-23 for the lacquer cycling view (merged as PR #57), 2026-10-23 for the adventure view's map and frame in the same look, built on `feat/adventure-view-styleguide-1fc223` (not merged), and 2026-10-24 for the Tribulation, the Foundation → Copper breakthrough, built on `feat/gameplay-priorities-c64b38` (not merged). Lines that describe them say so.

## Summary

Endless Path is a cultivation idle/incremental game with active mini-games, inspired by *Cradle*. It is currently a playable **Foundation-stage slice set in one zone**. A four-dialogue questline walks the player through:

- cycling, plus idle foraging and training;
- a procedurally generated adventure with real-time combat;
- inventory and gear, an ability loadout, a character sheet, and a skill tree.

The engineering base is healthy: it is data-driven, has 17 manager singletons, and all 2290 tests pass. However, **progression stops at Foundation's ending**. The Tribulation (on `feat/gameplay-priorities-c64b38`, not merged) breaks through to a thin Copper stage that unlocks nothing yet, there is no content after the third quest, and many numbers the player sees or pays for are never applied.

## Where Each System Stands

| System | State | Reality today |
|---|---|---|
| Cycling | Playable | 3 techniques. The starting technique earns Madra but **no Core Density XP**. A lacquer board in the map gap with the cabinet as its readout, a lit groove, tier-coloured hits and the techniques as drawers in the zone chest |
| Zone map and idle actions | Playable | 1 real zone with 10 actions. A map-first lacquer view (zoom-2 hex map with fog, cultivator cabinet, Goals board, zone chest, dock), and an idle action always resumes after cycling, adventures, dialogue and the shop. Foraging is free, and its materials have no use |
| Adventuring | Playable | 1 procedural adventure with 7 encounter types. On the adventure branch: the map (the wheel zooms it from 1 to 2) and its frame (vitals cabinet, chest with the Here tray and Run ledger, technique dock) are in the lacquer look, and none of their text is cut off; the fight keeps its old look until PR 2. The "boss" is a regular enemy, and a clear records nothing |
| Combat | Playable | Real-time, with 4 player abilities and 4 enemies. No enemy art, VFX or SFX |
| Inventory and items | Playable, thin | 12 items. The Merchant sells six gear pieces and Crude Scales; consumables can't be used in combat on `main` |
| Abilities and loadout | Playable | 4-slot drag-drop loadout; abilities unlock through the path tree |
| Path tree | Partial | 14 nodes, but only 3 have an effect: 19 of 22 points buy nothing |
| Quests and story | Playable, short | 3 quests and 4 dialogues, ending at the Merchant's shop |
| Character sheet | Playable | Attributes only; some tooltip formulas are wrong |
| Persistence | Works | Auto-saves every 5 s. No save versioning, and no save on quit |
| Breakthrough / Copper | Built, not merged | The Tribulation: Core Density stops at 100, then a Spirit Valley action runs the Breath of the Core (about 38 s). A pass reaches a thin Copper stage that unlocks nothing yet; a failure costs 5 levels. Its numbers are starting values, and the user has not played it through |
| Merchant | Playable (v1) | Six gear pieces (once per save) and Crude Scales for gold; prices are untested starting values |
| Scripting, Elixirs, Soulsmithing | Not started | Design notes only |
| Audio, release builds | None | No sound, no export presets, no CI |

Details: [GAMEPLAY_STATE.md](GAMEPLAY_STATE.md) (player view and content) and [CODEBASE_STATE.md](CODEBASE_STATE.md) (architecture).

## Health

- **Size:** about 30k lines of game GDScript plus 35k lines of tests, 135 scenes, 110 data resources, 10 shaders.
- **Tests:** 2290/2290 pass across 147 files in about 240 s (GUT 9.7.1, Godot 4.7.2, run on 2026-10-24). Every suite calls the code it tests, including the ResourceManager, CultivationManager, CharacterManager and InventoryManager suites ([TESTING.md](testing/TESTING.md)).
- **Activity:**
  - 709 commits and 43 merged PRs, mostly in April–May 2026. Nothing since 2026-06-01.
  - One unmerged branch, `feat/infallible-chaum-58f8ad`, adds in-combat consumables (20 commits, no PR).
  - The map-first zone view was merged as PR #51 (built 2026-10-22). See [ZONES.md](zones/ZONES.md).
  - The adventure view's map and frame are on `feat/adventure-view-styleguide-1fc223` (PR 1 of 2, built 2026-10-23, not merged). See [ADVENTURING.md](adventuring/ADVENTURING.md).
  - The Tribulation is on `feat/gameplay-priorities-c64b38` (built 2026-10-23 and 24, not merged). See [breakthrough-tribulation.md](cultivation/breakthrough-tribulation.md).
- **Bugs fixed during this audit,** each reproduced by a failing test first:
  - the trash slot could duplicate items, by two paths;
  - adventure timeouts were reported as "retreated";
  - a boss win ran the combat-end handler twice.
- **Notable open bug** (found in code review): equipping BODY/FOUNDATION gear doesn't raise max vitals.

## Necessary Work

### 1. Make Foundation a complete loop (now)
1. **Wire the inert systems.** Path perks need readers for `PathEffectsSummary`. Vitals must refresh on gear change. The foraging Madra cost and cycling action modifiers need to be applied.
2. **Consumables in combat.** Merge or finish `feat/infallible-chaum-58f8ad`, and give consumables a drop source.
3. **Merchant v1 (Beat 4).** Done 2026-10-19: a gold sink that makes the six gear pieces obtainable. Next: playtest the prices (FOUNDATION_PLAYTHROUGH Q-8).
4. **Beats 5–6:** an elite gear drop and a third keystone. These also need elite-defeated and "adventure cleared" events, so quests can gate on runs.
5. **Work through the open bugs** in each system doc's Work Remaining, e.g. the equipment page-size mismatch and the invisible modal backdrop.
6. **Onboarding:**
   - announce unlocks beyond the static NEW seal on new cards (the zone view already shows unspent Path Points on the dock's Path button);
   - prompt the switch to Smooth Flow;
   - replace placeholder dialogue (`[INTERVENER]`).

   The zone view hides the empty Test Zone on the map.
7. **Save safety:** a version field plus a general migration hook (the zone view added `SaveGameData.migrate()`, which only moves listed zone ids), save on quit, and no full wipe on an unknown zone id.

### 2. Break through to Copper (built, not merged; Copper content next)
1. **Done on `feat/gameplay-priorities-c64b38`:** the Core Density loop is guarded, Core Density is capped per stage, path points are paid once per stage, and Copper has a placeholder `AdvancementStageResource`.
2. **Beat 9, the Tribulation:** a Spirit Valley action at Core Density 100 that runs the Breath of the Core mini-game, then moves the player to Copper. Designed on 2026-10-23 in the [Tribulation spec](superpowers/specs/2026-10-23-tribulation-breath-of-the-core-design.md), which replaced the Guardian and Advancement Zone, and built on 2026-10-23 and 24. Still to do: the user's playtest (the timing windows, the 38 s length and the 5-level penalty are starting values, the copy is placeholder), the Core Density curve retune, and a decision on closing the game mid-trial (it applies nothing).
3. **Copper content (Beat 10 onward):** a second zone and adventure, Tier 2 path nodes, Copper-tier items and enemies.
4. **An out-of-combat buff/modifier system.** Scripting and Elixirs both need it.

### 3. Reach the GDD MVP (later)
1. Scripting and Elixir Making (Copper), and Soulsmithing (Iron). See [docs/planned/](planned/).
2. **Polish and shipping:**
   - an audio pass;
   - enemy and combat art;
   - export presets and CI;
   - rewrite the inventory tests that don't call production code.

## Decisions Needed

Each of these is a place where the built game and the [GDD](../Endless%20Path%20Game%20Design%20Document%20%5Bv0.1%5D.txt) disagree:

- **Gating:** Adventuring and the path tree are live at Foundation. The GDD puts Adventuring at Iron and Paths at Jade or later. Update the GDD, or re-gate?
- **Combat model:** combat uses HP/Madra/Stamina costs and has a basic attack. The GDD specifies a regenerating AP pool, a "Cycle" skill, and no basic attack.
- **Core Density cap:** decided on 2026-10-23 to follow the GDD: 0–100 per stage, with the breakthrough at 100 (the [Tribulation spec](superpowers/specs/2026-10-23-tribulation-breath-of-the-core-design.md)). Built on `feat/gameplay-priorities-c64b38` (not merged): each stage's cap is data (`max_core_density_level`), and XP earned at it is lost.
- **Auto-cycle:** the Auto toggle is available from the start. The GDD makes Auto-Cycle a Copper Scripting reward.
- **Pacing:** the Core Density curve is far faster than the playthrough's pacing targets. CD 100 takes about 25 perfect Smooth Flow cycles.
