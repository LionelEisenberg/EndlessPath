# Enemy waits for the opening cooldown (#140)

Playtest polish issue #140, tracked in #85. A fight opens on an even start: the enemy's first cast waits out the player's 1.5 s opening cooldown, then starts the frame the player's techniques come ready.

No mock-up step: nothing on screen changes its look. No save change, no data change, no enum.

## Where the wait lives

Two places could hold it:

1. **`CombatAbilityInstance` (rejected).** Let every technique take the opening, those with no cooldown of their own included. The enemy's Madra Lash and Famishing Bite would then sit out 1.5 s through the cooldown check the AI already makes. But the instance is shared by both sides and by the unit tests that cast a no-cooldown technique the moment it is built (`test_control_cuts.gd`, `test_combat_ability_instance_cancel.gd`, `test_combat_dodge.gd`, `test_combat_effect_types.gd`), and the AI would ask the manager every frame of the opening, which logs "is on cooldown" each time.
2. **`SimpleEnemyAI` (chosen).** The AI holds the opening itself: `setup()` starts it at `CombatAbilityInstance.INITIAL_COOLDOWN`, and `_process()` counts it down and casts nothing until it ends. `AdventureCombat._create_enemy_combatant()` calls `setup()` in the frame the player's technique instances enter the tree, so both openings start together, run on the same frame delta as the player's cooldown `Timer`s, and end in the same frame. Only the first cast moves: after the opening, the AI picks and casts as it does now.

`AdventureCombat` needs no change: it already builds both fighters and sets the AI going in one frame. If #138 moves the fight's start, both openings move with it.

The 1.5 s stays, and Control never cuts it: the enemy reads the same constant the player's opening does, and an enemy has no Control cut anyway.

## Steps

1. `SimpleEnemyAI`: an `_opening_left` the opening counts down, set in `setup()`; `_process()` returns while it runs. A public `is_in_opening()` for the tests and anyone who wants to read it.
2. New test `tests/unit/test_simple_enemy_ai.gd`, on a real `AdventureCombat` fight against each regular enemy (Amorphous Spirit's Madra Lash, Starving Dreadbeast's Famishing Bite), driving the AI's `_process()` with `gut.simulate()`:
   - no cast during the opening, whatever the enemy;
   - the first cast starts as the opening ends;
   - after the first cast lands, the next starts at once, as before;
   - the opening lasts `INITIAL_COOLDOWN` for every fighter set up.
   And one real-time check: the enemy's first cast starts no earlier than the player's first technique comes ready, and within a frame of it.
3. Existing tests stay green: `test_control_cuts.gd`, `test_fight_rules.gd`, `test_adventure_combat_victory_event.gd`, and the helpers that end the player's opening early (`_cast_the_first_technique()`, `_finish_cooldown()`, the dock test's shortcut). They change only if the suite says so.
4. Run `tests/run_tests.ps1`, then the issue's "Done when" checks on `-- --preset=adventure_open --save=user://dev/runs/enemy-opening-cooldown.tres`.

## Docs to update

As the issue lists: `docs/combat/COMBAT.md`, `docs/abilities/ABILITIES_MATRIX.md`, `docs/abilities/ABILITIES.md`, `scenes/combat/combat_architecture.md`, `docs/testing/TESTING.md`.
