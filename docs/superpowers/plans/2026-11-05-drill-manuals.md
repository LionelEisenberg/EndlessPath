# Drill Manuals Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Shallow Woods manuals teach drills (stats rework chunk #105, tracked in #85). Three manuals drop from Shallow Woods foes; each teaches its drill the moment it arrives, as loot, as a quest reward or from the dev panel, through `BodyRefiningManager.unlock_drill`, so Riverbank Training shows NEW. A manual is read and gone. A known drill's manual stops dropping, and a copy that still arrives teaches nothing.

**Architecture:** `DrillManualDefinitionData extends ItemDefinitionData` names the drill it teaches (`drill_id`) and owns the teaching: `teach() -> bool`, `is_known()`, its tooltip line and its log line. Its `_init()` sets a new `ItemType.DRILL_MANUAL`, appended to the enum. `InventoryManager.award_items()` gets a DRILL_MANUAL branch that calls `teach()` and logs, storing nothing. `ItemDefinitionData.can_drop() -> bool` (true) lets an item refuse to drop; the manual returns false once its drill is known, and `LootTable.roll_loot()` skips such entries. The manuals are hand-authored `.tres` files under `resources/items/drill_manuals/`, each dropped by a `LootTableEntry` on one Shallow Woods encounter.

**Tech Stack:** Godot 4.7.2, GDScript, GUT 9.7.1.

**Design:** issue #105's Decided list and the approved "Drill manuals" canvas (https://claude.ai/artifact/NVLmzY1kTLZWfDU131AKHB). The master plan's Task 5.18 for shape only.

**Save:** none. A manual isn't kept, and learning writes #97's saved `unlocked_drill_ids`, which needs no step. Old saves load unchanged.

**Enum claims at merge:** `ItemDefinitionData.ItemType.DRILL_MANUAL = 4` (after `QUEST_ITEM = 3`). If another chunk takes 4 first, renumber while merging `main`. No `.tres` stores the number: the manual's `_init()` sets it.

**Pattern:** the resource pattern with behaviour on the item (godot-prompter `inventory-system`, `resource-pattern`): a typed item subclass whose type routes `award_items`, and which carries its own teaching so every way in teaches alike. Rejected: teaching in the encounter's effects (a quest reward or the dev panel wouldn't teach), and a quest-item subclass kept in the Journal (the canvas's alternative, not approved).

## The canvas's answers (approved by Lionel on 2026-11-05, as drawn; recorded on #105)

- **Which drills:** every drill but the starting one: Horse Stance Manual, Falling Leaf Manual, Waterfall Tempering Manual. Stone Lifting has none.
- **Where and how often:** Ravenous Dreadbeast 25% a win (Horse Stance, rolled apart from its necklace), Coalescing Spirit 25% (Falling Leaf), Manifested Spirit, the boss, 35% (Waterfall Tempering).
- **When it teaches:** on pickup, however it arrives.
- **Kept or not:** read and gone, a new item type that `award_items` doesn't store. No save version, no inventory page, ITEMS.md's Quest items section unchanged.
- **Where it shows:** the Run ledger's loot, the end card's loot row as it stands, the item tooltip ("Drill Manual", "Teaches Horse Stance"), the log. The fight tile's line is unchanged; no non-fight tile awards a manual, so `AdventureTilemap.summary_for` doesn't change.
- **Log:** "Learned Horse Stance from its manual", in brass; a known drill: "You know Horse Stance already". One line each (RL-05).
- **A second copy:** stops dropping once known; a copy that still arrives teaches nothing, logs its line, isn't kept, and lights no NEW.
- **Not generated:** hand-authored, so the generator's DM-09 check isn't part of this chunk.
- **Art:** three 64 px `_ai` icons under `assets/sprites/items/drill_manuals/`.

## Global Constraints

The master plan's Global Constraints hold: explicit types, `##` docs on public functions, no `print()`, tests call production code with the save swap (restored in `after_each()`), no GUT doubles. One test file: `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gconfig= -gtest=<res path> -gexit`. Full suite: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_tests.ps1`.

---

### Task 1: The manual item and its type

**Files:**
- Modify: `scripts/resource_definitions/items/item_definition_data.gd` (`DRILL_MANUAL` appended; "Drill Manual" in `_get_item_type()`; `can_drop()`)
- Create: `scripts/resource_definitions/items/drill_manual_definition_data.gd` (`DrillManualDefinitionData`: `drill_id`, `get_drill()`, `is_known()`, `teach() -> bool`, `log_line(taught) -> String`, `can_drop()`, `_get_item_effects()`)
- Test: `tests/unit/test_drill_manual_definition_data.gd`: the type, the tooltip line, teaching once, the log lines, `can_drop()` before and after

- [x] Steps: failing tests, see them fail, implement, PASS.

### Task 2: award_items teaches a manual

**Files:**
- Modify: `singletons/inventory_manager/inventory_manager.gd` (the DRILL_MANUAL branch)
- Test: `tests/unit/test_inventory_manager.gd`: a manual teaches, is announced, and stores nothing; a non-manual item claiming the type logs an error and teaches nothing

- [x] Steps as Task 1.

### Task 3: A known drill's manual stops dropping

**Files:**
- Modify: `scripts/resource_definitions/loot/loot_table.gd` (`roll_loot()` skips an entry whose item can't drop)
- Test: `tests/unit/test_loot_table.gd` (new, or the existing loot test): a sure entry for a known manual rolls nothing, for an unknown one rolls it

- [x] Steps as Task 1.

### Task 4: The manuals and their drops

**Files:**
- Create: `resources/items/drill_manuals/{horse_stance,falling_leaf,waterfall_tempering}_manual.tres`, with `assets/sprites/items/drill_manuals/<drill>_manual_ai.png`
- Modify: `resources/adventure/encounters/shallow_woods/combat_encounters/elite/ravenous_dreadbeast_encounter.tres` (an entry beside the necklace), `.../elite/coalescing_spirit_encounter.tres` and `.../manifested_spirit_encounter.tres` (an `AwardLootTableEffectData` in the combat choice's `success_effects`)
- Test: `tests/integration/test_drill_manuals.gd`: `test_every_manual_drops_in_the_shallow_woods` (each manual under the folder has an entry on an encounter of `shallow_woods.tres`, at the approved chance), `test_each_drill_but_the_starting_one_has_a_manual`, `test_a_looted_manual_teaches_its_drill` (the encounter's own success effects, with the manual's entry made sure, unlock the drill, emit `drill_unlocked`, light the card and log the line), `test_a_second_copy_teaches_nothing`, `test_a_manual_from_the_dev_panel_teaches` (`DevCommands.award_item()`)

- [x] Steps as Task 1.

### Task 5: Wrap

- [x] The full suite passes.
- [x] The issue's Done-when checks, on `-- --save=user://dev/runs/drill-manuals.tres` and the `adventure_open` preset, and on a copy of a save from before the chunk.
- [x] PR closing #105 with `## Docs to update`.

## What was built differently

- **No save round-trip test.** Learning writes #97's `unlocked_drill_ids`, which its save tests already cover; the Done-when check reloads the chunk's save file in the game instead.
- **`test_dev_commands.gd::test_every_listed_item_can_be_awarded`** expected every Items-tab item to land in the bag. A manual isn't kept, so for a manual it now checks that its drill was taught.
- **`test_drill_manuals.gd`** also checks each manual has an icon and a description, and that a known drill's manual stops dropping through the encounter's own effect.
- **The manuals' descriptions**, which the canvas didn't settle: "A drill book, gnawed at the corners. Sink low and hold until the legs burn.", "Loose pages bound with spirit thread. Catch what falls before it lands.", "A water-stained drill book. Strike in time with the falls, and the body hardens." They show in the loot tooltip.
- **Done-when checks** ran in the real main scene through a scratch driver (gitignored `mockups/drill_manuals_canvas/`): a Ravenous Dreadbeast dropped the Horse Stance Manual on the first run of the `adventure_open` preset (saved to `user://dev/runs/drill-manuals.tres`); the old-save check used a version-1 save with a bag of materials.
