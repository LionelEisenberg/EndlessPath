# Combat Consumables in the Lacquer Dock: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The player can use the hotbar's four consumables in a fight, from a row of sockets along the top of the technique dock. Each is used by keys 1 to 4 or a click, and each socket has its own cooldown.

**Architecture:** The runtime is a `CombatConsumableManager` on each `CombatantNode` (player only), holding one `CombatConsumableInstance` per filled hotbar slot. It mirrors `CombatAbilityManager`/`CombatAbilityInstance`. A new `ConsumableSlot` scene shows each socket. `TechniqueDock` previews the hotbar on the map and binds the sockets in a fight, and its press goes through `AdventureCombat`, as a technique's does.

**Tech Stack:** Godot 4.7.2, GDScript, GUT 9.7.1; Python 3 with Pillow for the art.

**Spec:** [docs/superpowers/specs/2026-10-25-combat-consumables-lacquer-design.md](../specs/2026-10-25-combat-consumables-lacquer-design.md)

## Global Constraints

- Style guide: every position and size is even and filtering is nearest. State shows through art (a texture, a frame, a palette), never through alpha, tint or scale. Shows and hides are outright. Shakes step through `MapGlyph.shake_offset_at()`.
- No text is cut off: no `clip_text` and no `text_overrun_behavior`. A long count grows its seal.
- UI nodes live in `.tscn` files. Scripts set text, textures, visibility, `ThemeConstants` colours and the sweep's `progress`, and nothing else.
- GDScript conventions (CLAUDE.md):
  - explicit types;
  - a `##` doc comment on every public function and class;
  - private names start with `_`;
  - `%Unique` node references;
  - `#---` section headers;
  - `Log`, never `print()`.
- Agent art ends in `_ai`. The user's files are never edited, and nothing in `addons/` is either.
- Commits use conventional commits and end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Test command for files: `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gconfig= -gtest=<res:// files, comma-separated> -gexit`. The full suite: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_tests.ps1`.

## Review Focus

1. **The last one used mid-fight.** The socket turns to none left at once, a second press is refused, and back on the map the preview shows `0`. Tested in Task 4 (`test_using_the_last_one_leaves_it_veiled_at_zero`) and Task 5 (`test_the_map_shows_zero_after_the_last_one`, `test_the_last_one_used_refuses_the_next_press`).
2. **A fight that opens with an equipped consumable at 0.** The socket is none left from the start and refuses. Tested in Task 2 (`test_setup_builds_an_instance_for_a_slot_with_none_left`) and Task 5 (`test_a_fight_that_opens_with_none_left_refuses`).
3. **1 to 4 on the map.** No `consumable_selected`, no shake and no error. Tested in Task 5 (`test_keys_and_clicks_do_nothing_on_the_map`).
4. **The cast tray coming or going under an open consumable tooltip.** It moves the tooltip as it does for a technique, rather than redrawing it as a technique. Tested in Task 5 (`test_the_consumable_tooltip_moves_over_the_cast_tray`).
5. **A fight that ends while a socket recharges.** The dock lets go of the instance before it is freed, and nothing errors in the frames after. Tested in Task 6 (`test_a_fight_ending_mid_cooldown_lets_the_row_go`).

---

### Task 1: The count helper and `CombatConsumableInstance`

**Files:**
- Modify: `singletons/inventory_manager/inventory_manager.gd` (after `use_consumable()`)
- Create: `scenes/combat/combatant/combat_consumable_manager/combat_consumable_instance.gd`
- Test: `tests/unit/test_inventory_manager_consumables.gd` (extend), `tests/unit/test_combat_consumable_instance.gd` (new)

**Interfaces:**
- Produces:
  - `InventoryManager.get_consumable_count(def: ConsumableDefinitionData) -> int`
  - `class_name CombatConsumableInstance extends Node`, with signals `cooldown_started(duration: float)`, `cooldown_updated(time_left: float)` and `cooldown_ready()`;
  - fields `consumable_data: ConsumableDefinitionData`, `slot_index: int`, `cooldown_timer: Timer` (one-shot, child, made in `_ready()`) and `use_count: int`;
  - methods `_init(data: ConsumableDefinitionData, p_slot_index: int)`, `is_ready() -> bool`, `get_count() -> int` and `use() -> bool`.

- [ ] **Step 1: Write the failing tests.**
  - `test_get_consumable_count_returns_the_stack`: award 4 of a consumable, then `get_consumable_count(def) == 4`.
  - `test_get_consumable_count_is_zero_for_unowned_and_null`: `0` for a def never awarded, and `0` for `null` with no error.
  - In `test_combat_consumable_instance.gd`, on a fresh save restored in `after_each`, use an inner `CountingEffect extends EffectData` whose `process()` counts calls:
    - `test_ready_as_the_fight_opens`: no opening cooldown, so `is_ready()` and `cooldown_timer.is_stopped()`.
    - `test_use_fires_the_effects_and_takes_one`: with 3 held, `use()` is true, the effect ran once, `get_count() == 2` and `use_count == 1`.
    - `test_use_starts_the_cooldown`: `cooldown_seconds` 10, then `use()` → not ready, `cooldown_timer.wait_time == 10.0` and `cooldown_started` is emitted with `10.0`.
    - `test_use_is_refused_while_recharging`: the second `use()` is false, the effect ran once and the count drops once.
    - `test_use_is_refused_with_none_left`: none held → `use()` false, the effect never ran, no cooldown.
    - `test_no_cooldown_means_ready_at_once`: `cooldown_seconds` 0 → after `use()` it is still ready, and two uses take two.
    - `test_cooldown_ready_fires_when_it_ends`: `cooldown_seconds` 0.05, then `await wait_for_signal(cooldown_ready, 1.0)` is true and `is_ready()`.

- [ ] **Step 2: Run them; they fail** (no `get_consumable_count`, no class).

- [ ] **Step 3: Implement.**
  - `get_consumable_count()` returns `get_inventory().consumables.get(def, 0)`, or 0 for null.
  - The instance follows `CombatAbilityInstance`:
    - `name` is `ConsumableInstance_<slot_index>`;
    - `_ready()` makes the timer with no opening cooldown;
    - `_process()` emits `cooldown_updated` while the timer runs;
    - `use()` gates on `is_ready()` and `get_count() > 0`, then calls `InventoryManager.use_consumable(consumable_data)`, and on success adds to `use_count` and starts the cooldown when `cooldown_seconds > 0`.

- [ ] **Step 4: Run them; they pass.**

- [ ] **Step 5: Commit** `feat(combat): add CombatConsumableInstance and a consumable count`.

### Task 2: `CombatConsumableManager` on the combatant, and the fight's route

**Files:**
- Create: `scenes/combat/combatant/combat_consumable_manager/combat_consumable_manager.gd`, `.../combat_consumable_manager.tscn` (a `Node` with the script)
- Modify: `scenes/combat/combatant/combatant_node.tscn` (add `%CombatConsumableManager`), `scenes/combat/combatant/combatant_node.gd` (`@onready var consumable_manager`; `setup()` calls `consumable_manager.setup(self)` after `ability_manager.setup(self)`), `scenes/combat/adventure_combat/adventure_combat.gd` (UI HANDLERS)
- Test: `tests/unit/test_combat_consumable_manager.gd` (new)

**Interfaces:**
- Consumes: `CombatConsumableInstance` (Task 1).
- Produces:
  - `class_name CombatConsumableManager extends Node`, with signal `consumable_used(instance: CombatConsumableInstance)`;
  - fields `owner_combatant: CombatantNode` and `consumables: Array[CombatConsumableInstance]` (in slot order);
  - methods `setup(p_owner: CombatantNode) -> void`, `can_use_consumable_instance(instance: CombatConsumableInstance) -> bool`, `use_consumable_instance(instance: CombatConsumableInstance) -> bool` and `get_instance_at_slot(slot_index: int) -> CombatConsumableInstance`;
  - `CombatantNode.consumable_manager: CombatConsumableManager`;
  - `AdventureCombat.on_player_consumable_selected(instance: CombatConsumableInstance) -> void`.

- [ ] **Step 1: Write the failing tests.** Use a fresh save, a bare `CombatantNode.new()` owner (autofree) with `is_player` set, and the manager scene instanced:
  - `test_setup_builds_one_instance_per_filled_slot`: hotbar slots 0 and 2 filled → two instances with `slot_index` 0 and 2, in that order, each the manager's child.
  - `test_setup_builds_none_for_an_enemy`: `is_player` false → `consumables` is empty.
  - `test_setup_builds_an_instance_for_a_slot_with_none_left`: equipped with 0 held → one instance; `can_use_consumable_instance()` is false.
  - `test_setup_again_replaces_the_instances`: after two `setup()` calls the instance count is unchanged.
  - `test_use_goes_through_the_gate_and_emits`: `watch_signals`, then `use_consumable_instance()` is true and `consumable_used` is emitted with the instance; on a recharging instance it is false and nothing is emitted.
  - `test_an_instance_from_elsewhere_is_refused`: another manager's instance gives false.
  - `test_get_instance_at_slot`: the right instance, or null for an empty slot and for 7.
  - `test_casting_does_not_block_a_consumable`: in the combatant scene (`combatant_node.tscn` set up as the player, with a technique mid-cast through `ability_manager.use_ability_instance()`), `can_use_consumable_instance()` is still true.
  - `test_the_combatant_mounts_the_manager`: after `combatant_node.tscn` `setup(..., true)` with a filled hotbar, `consumable_manager.consumables.size() == 1`.

- [ ] **Step 2: Run them; they fail.**

- [ ] **Step 3: Implement.**
  - `setup()` clears any old instances (`queue_free`) and returns for a non-player. Otherwise it walks hotbar slots 0 to 3 in order and makes an instance for each non-null def, logging one `Log.info` line per instance as the ability manager does.
  - `can_use_consumable_instance()` checks that the instance is in `consumables`, `is_ready()` and `get_count() > 0`. It never consults casting.
  - `on_player_consumable_selected()` calls `player_combatant.consumable_manager.use_consumable_instance(instance)`, with a `Log.warn` when there is no player combatant.

- [ ] **Step 4: Run them, plus `tests/integration/test_technique_dock.gd` (the combatant scene changed); they pass.**

- [ ] **Step 5: Commit** `feat(combat): mount a consumable manager on each combatant`.

### Task 3: The art and the sweep's icon size

**Files:**
- Modify: `docs/superpowers/mockups/adventure-view-lacquer/gen/kit_adventure.py`. Add `consumable_pieces()` and call it from `run()`:
  - `bezel_socket('slot_consumable', 24)`;
  - `seal('seal_count9', 12, 12, [(2, 0), (11, 7), (0, 8), (1, 11)], [(2, 1), (10, 7), (1, 8)])`;
  - `board_base(238, 100)` with grain streaks and two gloss dashes of its own, saved as `tdock_consumables`.
- Modify: `docs/superpowers/mockups/adventure-view-lacquer/gen/import_adventure_kit.py`. In `SHADOWED`, `'tdock'` becomes `'tdock_consumables'` (big shadow) and `'slot_consumable'` is added (small shadow). In `PLAIN`, `'seal_count9'` is added.
- Create (generated, with their `.import` files from `--import`): `assets/ui/lacquer/lacquer_slot_consumable_ai.png` (50x50), `lacquer_tdock_consumables_ai.png` (480x204), `lacquer_seal_count9_ai.png` (24x24).
- Delete: `assets/ui/lacquer/lacquer_tdock_ai.png` and its `.import`, after Task 5 switches the dock. That is done in Task 5's commit.
- Modify: `assets/shaders/lacquer_cooldown_sweep.gdshader`: `uniform float icon_size = 64.0;`, and the centre is `vec2(icon_size * 0.5)` in place of `CENTRE`.

- [ ] **Step 1: Generate only the three pieces.** Run a scratch driver that imports `kit_adventure` and runs `consumable_pieces()` into the mock folder. It then bakes the two shadowed pieces with `import_kit.bake_shadow` and copies the seal into `assets/ui/lacquer/`. Do not run `build_all.py`, which would rewrite every mock texture.
- [ ] **Step 2: Check the files.**
  - The sizes are 50x50, 480x204 and 24x24.
  - Every 2x2 block of the unshadowed art is uniform.
  - The seal's columns 6 to 17 (2x px) are all one vermilion, so its middle can stretch.
  - `git status` shows no other asset changed.
- [ ] **Step 3: Edit the shader, then run `--import`.** The `.import` files appear, and the technique dock tests still pass with the default `icon_size`.
- [ ] **Step 4: Commit** `feat(ui): draw the consumable socket, its seal and the taller dock` (the generator, the import script, the PNGs and `.import` files, the shader).

### Task 4: `ConsumableSlot`

**Files:**
- Create: `scenes/ui/combat/technique_dock/consumable_slot/consumable_slot.tscn`, `consumable_slot.gd`
- Modify: `scenes/ui/combat/technique_dock/technique_slot/technique_slot.gd`. Lift the input-map lookup out of `_key_text()` into `static func key_label(action: StringName, fallback: String) -> String`, which both slots call.
- Test: `tests/integration/test_consumable_slot.gd` (new)

**Interfaces:**
- Consumes: `CombatConsumableInstance` (Task 1); `TechniqueSlot.SWEEP_STEPS`, `sweep_step()`, `seconds_text()` and `key_label()`; `MapGlyph.SOFT_SHAKE_KEYFRAMES`, `shake_offset_at()` and `SHAKE_SECONDS`; `LacquerFrameOverlay.flash()`.
- Produces:
  - `class_name ConsumableSlot extends Control`, with signals `pressed`, `hovered(consumable_data: ConsumableDefinitionData)` and `unhovered`, and `enum SlotState { EMPTY, PREVIEW, ACTIVE }`;
  - constants `SEAL_MIN_WIDTH := 24.0`, `SEAL_PADDING := 8.0` and `SEAL_RIGHT := 52.0`;
  - methods:
    - `show_empty(slot_index: int) -> void`, `show_preview(data: ConsumableDefinitionData, slot_index: int) -> void` and `bind(instance: CombatConsumableInstance, slot_index: int) -> void`;
    - `refresh_count() -> void`, `refuse() -> void` and `is_shaking() -> bool`;
    - the getters `get_state() -> SlotState`, `get_consumable_instance() -> CombatConsumableInstance`, `get_consumable_data() -> ConsumableDefinitionData`, `get_count() -> int` and `get_sweep_step() -> int`;
    - `static seal_width(text_width: float) -> float`.

The scene follows the spec's Layout rows:
- root 48x48 with the lacquer theme;
- `%Body` (it shakes), holding:
  - the socket texture at file size;
  - `%Icon` 32x32 at (8, 8), with a `resource_local_to_scene` sweep material set to `icon_size = 32`;
  - `%SecondsLabel` (`LabelLacquerCooldown` at a 15 px size override, as built after the first capture), centred on the icon and wider than it so three digits fit;
  - `%HoverFrame` (`frame_hover.tres`) and `%ReadyFlash` (`LacquerFrameOverlay`, brass);
- `%KeyCap` at (−6, −6) with `%KeyLabel`;
- `%CountSeal` (a `Control`, right edge at 52, top at +30: off the socket's bottom right corner, as built after the first capture; the plan had the top right, at −6), holding the `NinePatchRect` seal (margins 6 and 6) and `%CountLabel` (`LabelLacquerSeal`, 15 px, centred, `offset_top` 3, 18 tall).

Every child ignores the mouse.

- [ ] **Step 1: Write the failing tests.** Use a fresh save and the slot scene instanced alone, with instances made from `CombatConsumableInstance.new(...)` and added to the tree:
  - `test_empty_shows_the_socket_and_key`: no icon, no seal, key `1` for slot 0, in tan.
  - `test_preview_shows_icon_count_and_a_tan_key`: Crude Scale with 3 held → icon texture, seal `3`, tan key, `get_state() == PREVIEW`, sweep step 24.
  - `test_preview_with_none_left_is_veiled_at_zero`: step 0, seal `0`, no seconds.
  - `test_bind_shows_a_cream_key`: state ACTIVE.
  - `test_the_sweep_follows_the_cooldown`: after `use()` (10 s), step 0 and `"10"`. After `cooldown_updated.emit(5.0)`, step 12 and `"5"`. After it ends: step 24, no seconds, `%ReadyFlash` showing.
  - `test_using_the_last_one_leaves_it_veiled_at_zero`: 1 held → `use()` → `refresh_count()` → step 0 and `0`. When its cooldown ends, there is no flash and the step is still 0.
  - `test_a_left_press_emits_pressed_only_when_active`.
  - `test_hover_emits_with_the_data_and_shows_the_frame`: an empty slot emits nothing.
  - `test_refuse_shakes_the_body_and_not_the_key_or_seal`: the body is off 0 during the shake and back after `MapGlyph.SHAKE_SECONDS`, while the key cap and seal positions never change.
  - `test_seal_width`: `seal_width(10) == 24`, `seal_width(30) == 38`, and every result is even.
  - `test_a_long_count_grows_the_seal_leftward`: 1234 held → the seal is wider than 24 and even, its right edge stays at 52, and the label's minimum width fits inside it.
  - `test_scene_uses_the_kit`: the socket, keycap and seal textures; the seal's margins; the shader with `icon_size` 32; the theme variants; children that ignore the mouse; no `clip_text` or overrun trimming.

- [ ] **Step 2: Run them; they fail.**

- [ ] **Step 3: Implement the scene and script.**
  - `_refresh()` puts the state on the nodes.
  - The count is read through `InventoryManager.get_consumable_count()`.
  - The sweep step is 0 when the count is 0, `TechniqueSlot.sweep_step(time_left, timer.wait_time)` while recharging, and 24 otherwise.
  - The seconds show only while recharging with some left.
  - `cooldown_ready` flashes once when some are left.
  - The seal width is `seal_width(%CountLabel minimum width)`, set as the minimum and as the size, with the left at `SEAL_RIGHT - width`.
  - `_unbind_instance()` disconnects the three cooldown signals, as `TechniqueSlot` does.
  - `TechniqueSlot._key_text()` now calls `key_label("ability_slot_%d", FALLBACK_KEY_LABELS[i])`, and its tests still pass.

- [ ] **Step 4: Run `test_consumable_slot.gd` and `test_technique_dock.gd`; they pass.**

- [ ] **Step 5: Commit** `feat(ui): add the consumable slot`.

### Task 5: The dock's consumable row, keys 1 to 4 and the tooltip

**Files:**
- Modify: `project.godot` (`[input]`). Add `consumable_slot_1` to `consumable_slot_4`, with `deadzone` 0.2, each one `InputEventKey` with `physical_keycode` 49 to 52, after `ability_slot_4`.
- Modify: `scenes/ui/combat/technique_dock/technique_dock.tscn`:
  - the root at offsets (722, 856) to (1198, 1056);
  - the board texture is `lacquer_tdock_consumables_ai.png`, 480x204;
  - `ConsumableSlot1..4` (unique) at (46, 18), (158, 18), (270, 18) and (382, 18);
  - `Slot1..4` at y 82;
  - the cast tray unchanged.
- Modify: `scenes/ui/combat/technique_dock/technique_dock.gd`.
- Modify: `scenes/ui/combat/technique_dock/technique_tooltip/technique_tooltip.gd` and `.tscn`:
  - `BOTTOM_Y` becomes 848 and `CAST_TRAY_TOP_Y` becomes 804, with their comments;
  - add `%EffectsLabel` (`LabelLacquerDetail` in cream, `autowrap_mode` word, minimum width 268) after `TimingText`.
- Delete: `assets/ui/lacquer/lacquer_tdock_ai.png` and `.import`.
- Test: `tests/integration/test_technique_dock_consumables.gd` (new). Also modify the geometry in `tests/integration/test_technique_dock.gd`:
  - `DOCK_HOME` becomes (722, 856), and the technique `SLOT_POSITIONS` y becomes 82;
  - 912 becomes 848 and 860 becomes 796;
  - the tray comment's screen y becomes 804.

**Interfaces:**
- Consumes: Tasks 1, 2 and 4.
- Produces:
  - `TechniqueDock.consumable_selected(instance: CombatConsumableInstance)` and `const CONSUMABLE_ACTIONS: Array[StringName]`;
  - `bind(ability_manager: CombatAbilityManager, vitals_manager: VitalsManager, consumable_manager: CombatConsumableManager = null) -> void` and `get_consumable_slot(index: int) -> ConsumableSlot`;
  - `TechniqueTooltip.show_for_consumable(data: ConsumableDefinitionData, slot: Control, cast_tray_shown: bool, cast_tray_top: float = CAST_TRAY_TOP_Y) -> void` and `static effect_lines(data: ConsumableDefinitionData) -> String`.

- [ ] **Step 1: Write the failing tests** in `test_technique_dock_consumables.gd`. Copy the setup of `test_technique_dock.gd`: a fresh save, the player's vitals restored, and a real player combatant from `combatant_node.tscn`. The fight is `_dock.bind(_player.ability_manager, _vitals, _player.consumable_manager)`, and keys go in through `get_viewport().push_input(InputEventAction)`.
  - `test_layout_matches_the_spec`: the dock's position (722, 856) and size (476, 200); the board's texture and size; the consumable slots at the spec's points, 48x48; the technique slots at y 82; the cast tray at (0, −52, 476, 44).
  - `test_the_map_previews_the_hotbar`: hotbar slot 1 holds Crude Scale (3 held) → socket 1 PREVIEW with seal `3`, and the others EMPTY.
  - `test_keys_show_one_to_four`.
  - `test_a_fight_binds_each_socket_to_its_hotbar_slot`: slots 0 and 2 → instances from `get_instance_at_slot()`, and 1 and 3 EMPTY.
  - `test_a_key_presses_its_socket_in_a_fight`: `consumable_slot_3` emits `consumable_selected` with slot 2's instance.
  - `test_a_click_presses_its_socket_in_a_fight`.
  - `test_keys_and_clicks_do_nothing_on_the_map`: no signal, no shake, no error.
  - `test_a_refused_press_shakes_and_emits_nothing`: one used (recharging) → pressed again → no signal and `is_shaking()`.
  - `test_a_fight_that_opens_with_none_left_refuses`.
  - `test_counts_follow_the_inventory`: on the map an award of 2 turns `3` into `5`; in a fight a use turns `3` into `2`.
  - `test_the_map_shows_zero_after_the_last_one`: use the last one in a fight, then `reset()` → the preview shows `0`, veiled.
  - `test_a_consumable_can_be_pressed_while_a_technique_casts`.
  - `test_the_tooltip_describes_a_consumable`: the name, `Instant · Cooldown 10 s`, `+20 Madra`; the cost row and damage are hidden; the bottom is at 848 and the left at the socket's x − 8.
  - `test_the_consumable_tooltip_moves_over_the_cast_tray`: it stays a consumable's tooltip (the `EffectsLabel` shows `+20 Madra`) with its bottom at 796, then goes back to 848 when the tray hides.
  - `test_a_technique_tooltip_hides_the_effects_line`.
  - `test_reset_lets_the_fight_go`: after `reset()`, the sockets are PREVIEW and hold no instance.

- [ ] **Step 2: Run them; they fail.**

- [ ] **Step 3: Implement.**
  - `show_loadout()` previews hotbar slots 0 to 3 from `InventoryManager.get_inventory().equipped_consumables`.
  - `bind()` binds `get_instance_at_slot(i)` or shows the socket empty.
  - `_unhandled_input()` adds `CONSUMABLE_ACTIONS`, which also apply only while active and visible.
  - `_press_consumable(index)` asks `can_use_consumable_instance()` and either emits or refuses.
  - Hover keeps `_hovered_slot: Control` and `_hovered_data: Resource`. A helper re-shows the tooltip with `show_for_ability()` or `show_for_consumable()` by the data's type, and the cast-tray handler calls it.
  - `_ready()` connects `InventoryManager.inventory_changed`. In a fight it calls each socket's `refresh_count()`; on the map it reads the hotbar preview again, without touching the techniques or the tooltip.
  - `show_for_ability()` hides `%EffectsLabel`. `show_for_consumable()`:
    - shows the timing line `Instant · Cooldown <AbilityRow.format_seconds()>`, or `Instant`;
    - shows `effect_lines()`, which is each effect's `describe()` joined by newlines;
    - hides the cost row and damage;
    - shows the description.
  - Delete the old board PNG once nothing references it (grep).

- [ ] **Step 4: Run both dock test files, `test_adventure_view_layout.gd` and `test_adventure_view_frame.gd`, with the dock's place updated to (722, 856) in their tables. They pass.**

- [ ] **Step 5: Commit** `feat(ui): put the hotbar's consumables on the technique dock`.

### Task 6: The fight's wiring in `AdventureView`

**Files:**
- Modify: `scenes/adventure/adventure_view/adventure_view.gd`. In `_on_start_combat()`, pass `combat.player_combatant.consumable_manager` to `technique_dock.bind()` and connect `consumable_selected` to `combat.on_player_consumable_selected`. In `_release_fight_boards()`, disconnect it.
- Test: `tests/integration/test_adventure_view_frame.gd` (two tests).

- [ ] **Step 1: Write the failing tests.**
  - `test_a_key_uses_a_consumable_in_a_real_fight`: Crude Scale goes on hotbar slot 0 with 3 held. Start the run, walk to `FIGHT` and pick the fight. Then:
    - the socket holds the instance and `consumable_selected` reaches the fight;
    - pressing `consumable_slot_1` leaves 2 held and raises the player's Madra by 20, or to its max;
    - after `trigger_combat_end.emit(true, 15)` the signal is disconnected and the socket previews `2`.
  - `test_a_fight_ending_mid_cooldown_lets_the_row_go`: use one, end the fight, `await wait_process_frames(3)`; the socket holds no instance and no error is logged.
- [ ] **Step 2: Run them; they fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run `test_adventure_view_frame.gd`; it passes.**
- [ ] **Step 5: Commit** `feat(adventure): use consumables in a fight`.

### Task 7: Docs

**Files:**
- `docs/combat/COMBAT.md`: a "Consumables in a fight" section with the manager, the instance, the gate, the flow and the per-fight reset. Remove the `[LOW]` item about the unmerged branch.
- `docs/adventuring/ADVENTURING.md`: in the technique dock section, the consumable row (layout, states, keys, tooltip) and the new signal row.
- `docs/inventory/INVENTORY.md`: the combat hook row. The `[HIGH]` item becomes "no drop source: the merchant's Crude Scales are the only way to get one".
- `docs/infrastructure/MAIN_VIEW.md`: a keybindings row for `consumable_slot_1` to `consumable_slot_4`.
- `docs/STYLE_GUIDE.md`:
  - §6 gets the consumable socket, the growing count seal and the dock board's new size;
  - §8 says the sweep shader takes `icon_size`;
  - §10's Dock row gets the new rect.
- `docs/planned/SCRIPTING.md`: the "Using consumables" line.
- `docs/superpowers/README.md`: the Consumables row (in-combat use built), a new row for this spec and plan, and the "Not on `main`" line removed.

Leave `STATE_OF_THE_GAME.md`, `GAMEPLAY_STATE.md` and `CODEBASE_STATE.md` alone; they are refreshed at milestones. Write no counts, test lists or private helper names.

- [ ] **Step 1: Edit the docs. Then grep for `infallible-chaum`, `912`, `920` and `476x136` to find statements that are now stale.**
- [ ] **Step 2: Commit** `docs(combat): describe consumables in a fight`.

### Task 8: Verify

- [ ] **Step 1: Run the full suite.** It passes, and every script runs tests. Rerun any failure in one process before investigating.
- [ ] **Step 2: Capture the adventure view at 1920x1080** with a scratch capture scene (outside the commit): the map with a filled hotbar, then a fight with a socket recharging and one at `0`. Check the capture against the spec's Layout and the style guide's §12 checklist, and fix what is off.
- [ ] **Step 3: Request a whole-branch review** (superpowers:requesting-code-review), then fix what it finds.
