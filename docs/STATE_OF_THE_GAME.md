# Endless Path: State of the Game

Snapshot: 2026-10-18 · `main` @ `21b3cb2` (last commit 2026-06-01) · Godot 4.6

## Summary

Endless Path is a cultivation idle/incremental game with active mini-games, inspired by *Cradle*. It is currently a playable **Foundation-stage slice set in one zone**. A four-dialogue questline walks the player through:

- cycling, plus idle foraging and training;
- a procedurally generated adventure with real-time combat;
- inventory and gear, an ability loadout, a character sheet, and a skill tree.

The engineering base is healthy: it is data-driven, has 16 manager singletons, and all 533 tests pass. However, **progression stops at Foundation**. There is no breakthrough, no content after the third quest, and many numbers the player sees or pays for are never applied.

## Where Each System Stands

| System | State | Reality today |
|---|---|---|
| Cycling | Playable | 3 techniques. The starting technique earns Madra but **no Core Density XP** |
| Zone map and idle actions | Playable | 1 real zone with 9 actions. Foraging is free, and its materials have no use |
| Adventuring | Playable | 1 procedural adventure with 7 encounter types. The "boss" is a regular enemy, and a clear records nothing |
| Combat | Playable | Real-time, with 4 player abilities and 4 enemies. No enemy art, VFX or SFX |
| Inventory and items | Playable, thin | 12 items. 6 of 7 gear pieces can't be obtained, and consumables can't be used on `main` |
| Abilities and loadout | Playable | 4-slot drag-drop loadout; abilities unlock through the path tree |
| Path tree | Partial | 14 nodes, but only 3 have an effect: 19 of 22 points buy nothing |
| Quests and story | Playable, short | 3 quests and 4 dialogues, ending at a merchant that isn't built |
| Character sheet | Playable | Attributes only; some tooltip formulas are wrong |
| Persistence | Works | Auto-saves every 5 s. No save versioning, and no save on quit |
| Breakthrough / Copper | Missing | Breakthrough is an empty stub. The Tribulation is designed but not built |
| Merchant | Stub | Logs "Shop coming soon" |
| Scripting, Elixirs, Soulsmithing | Not started | Design notes only |
| Audio, release builds | None | No sound, no export presets, no CI |

Details: [GAMEPLAY_STATE.md](GAMEPLAY_STATE.md) (player view and content) and [CODEBASE_STATE.md](CODEBASE_STATE.md) (architecture).

## Health

- **Size:** about 19.5k lines of game GDScript plus 6.4k lines of tests, 112 scenes, 98 data resources, 15 shaders.
- **Tests:** 533/533 pass across 61 files in about 6 s (GUT 9.6.0). Several suites re-implement the logic they test instead of calling it: ResourceManager, CharacterManager, CultivationManager, and parts of inventory and adventure. Real coverage is lower than the count suggests ([TESTING.md](testing/TESTING.md)).
- **Activity:**
  - 709 commits and 43 merged PRs, mostly in April–May 2026. Nothing since 2026-06-01.
  - One unmerged branch, `feat/infallible-chaum-58f8ad`, adds in-combat consumables (20 commits, no PR).
- **Notable bugs** (found in code review, not yet reproduced in-game):
  - The trash slot can duplicate items, by two different paths.
  - Adventure timeouts are reported as "retreated".
  - A boss win runs the combat-end handler twice.
  - Equipping BODY/FOUNDATION gear doesn't raise max vitals.
- **Latent hang:** if the cultivation stage ever changes without stage data, `CultivationManager.add_core_density_xp()` loops forever. This must be fixed before Copper exists.

## Necessary Work

### 1. Make Foundation a complete loop (now)
1. **Wire the inert systems.** Path perks need readers for `PathEffectsSummary`. Vitals must refresh on gear change. The foraging Madra cost and cycling action modifiers need to be applied.
2. **Consumables in combat.** Merge or finish `feat/infallible-chaum-58f8ad`, and give consumables a drop source.
3. **Merchant v1 (Beat 4).** A gold sink that also makes the existing gear obtainable.
4. **Beats 5–6:** an elite gear drop and a third keystone. These also need elite-defeated and "adventure cleared" events, so quests can gate on runs.
5. **Fix the HIGH bugs**, starting with trash duplication.
6. **Onboarding:**
   - announce Path Points and unlocks;
   - prompt the switch to Smooth Flow;
   - replace placeholder dialogue (`[INTERVENER]`);
   - hide the empty Test Zone.
7. **Save safety:** a version field plus a migration hook, save on quit, and no full wipe on an unknown zone id.

### 2. Break through to Copper (next)
1. Guard the Core Density loop, then author the Copper `AdvancementStageResource`.
2. **Beats 7–9:** a real boss (the Tribulation Guardian), the Advancement Zone, and the Tribulation itself, through a working `attempt_breakthrough()`. First reconcile the two conflicting designs: [FOUNDATION_PLAYTHROUGH.md](progression/FOUNDATION_PLAYTHROUGH.md) vs [breakthrough-tribulation.md](cultivation/breakthrough-tribulation.md).
3. **Copper content (Beat 10 onward):** a second zone and adventure, Tier 2 path nodes, Copper-tier items and enemies.
4. **An out-of-combat buff/modifier system.** Scripting and Elixirs both need it.

### 3. Reach the GDD MVP (later)
1. Scripting and Elixir Making (Copper), and Soulsmithing (Iron). See [docs/planned/](planned/).
2. **Polish and shipping:**
   - an audio pass;
   - enemy and combat art;
   - export presets and CI;
   - rewrite the tests that don't call production code.

## Decisions Needed

Each of these is a place where the built game and the [GDD](../Endless%20Path%20Game%20Design%20Document%20%5Bv0.1%5D.txt) disagree:

- **Gating:** Adventuring and the path tree are live at Foundation. The GDD puts Adventuring at Iron and Paths at Jade or later. Update the GDD, or re-gate?
- **Combat model:** combat uses HP/Madra/Stamina costs and has a basic attack. The GDD specifies a regenerating AP pool, a "Cycle" skill, and no basic attack.
- **Core Density cap:** it has no cap and nothing happens at 100. The GDD says 0–100 per stage, with a breakthrough at 100.
- **Auto-cycle:** the Auto toggle is available from the start. The GDD makes Auto-Cycle a Copper Scripting reward.
- **Pacing:** the Core Density curve is far faster than the playthrough's pacing targets. CD 100 takes about 25 perfect Smooth Flow cycles.
