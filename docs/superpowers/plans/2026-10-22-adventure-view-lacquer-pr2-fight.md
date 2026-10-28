# Adventure View in Lacquer and Brass, PR 2: the Fight — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish the adventure view's fight: the opponent page in the chest, the adventure's static combat stage, the Aseprite fighters at 2x with stepped motion and lacquer floaters, and the 2-step dither dissolve into fights; remove the old enemy plate and the rest of the old fight HUD.

**Architecture:** Builds on PR 1 ([its plan](2026-10-22-adventure-view-lacquer-pr1-map-and-frame.md)): the lacquer theme pieces, `BuffTooltip`, `AdventureChest` and `AdventureChestPage`, `TechniqueDock`, `AbilityRow.format_damage()`, `AdventureCombat.gold_reward_for()`, the import script. Art first, then data (`AdventureData.combat_stage`, `CombatantData.shadow_texture`), then the floater moves to a shared piece, then the fighters, the opponent page and the dissolve, then the wiring and the removals.

**Tech Stack:** Godot 4.7.2, GDScript, GUT 9.7.1; Python 3 with Pillow; the aseprite MCP (`.mcp.json`) for the fighters.

**Spec:** [2026-10-22-adventure-view-lacquer-design.md](../specs/2026-10-22-adventure-view-lacquer-design.md) (The right chest › Opponent page, The fight, Transitions and timing, Removed). The mock's combat screen is the visual reference.

**Starts after** PR 1's Task 11. Branch `feat/adventure-view-fight` from PR 1's tip; if the user has merged PR 1, branch from `main` instead. Ask the user which when PR 1 is unmerged and they have not said.

## Global Constraints

- Every Global Constraint of [PR 1's plan](2026-10-22-adventure-view-lacquer-pr1-map-and-frame.md#global-constraints) applies: project rules, GodotPrompter, `addons/`, art and `_ai`, the look, tests, save safety, commands, git (on this plan's branch).
- **Copy (exact):** "Health"; "Casting"; "Gathering its madra"; "Interrupted"; "Buffs"; "Techniques"; "<gold> gold"; "if you win"; technique rows "<t> s cast · about <n> <Type> damage", "Instant · about <n> <Type> damage", and "<t> s cast" or "Instant" for a technique that deals no damage; the Casting tray's detail "About <n> <Type> damage"; floaters "-23" (damage dealt, cream), "-9" (damage taken, `#E8737A`), "+12" (heal, `#E8737A`).
- **Fighter art:** native pixel art drawn through the aseprite MCP (follow its instructions: plan the boxes, silhouette, a palette of 8–16 colours with one ramp per material, shade from the top-left, a dark outline, `view_sprite` and `lint_sprite` after every pass), saved as `.aseprite` sources and exported at 2x nearest. Wuxia spirit. Faces right (the game mirrors enemies). Feet on the canvas's bottom row. Kit outline and ink colours; the clearing's greens for shadows.

## Review Focus

1. **A fight that ends inside the dissolve.** A dev force-win or a one-shot kill within the first 200 ms must bring the map back whole: `dissolve_step` 0, the map visible, the fight hidden. Test: Task 6 `test_fight_ending_mid_dissolve_restores_the_map`.
2. **An enemy with no techniques.** The opponent page shows no technique rows and "Gathering its madra", without errors. Test: Task 5 `test_enemy_without_techniques`.
3. **A new cast right after an interrupt.** The Casting tray shows the new cast at once; no "Interrupted" or shake lingers. Test: Task 5 `test_new_cast_after_an_interrupt`.
4. **Many hits within a second.** A fifth number reuses the oldest floater and still shows. Test: Task 4 `test_fifth_number_takes_the_oldest_floater`.
5. **A buff that ends while its tooltip is open.** The opponent's buff tooltip hides with it. Test: Task 5 `test_tooltip_hides_when_its_buff_expires`.

---

## File map

| Area | Create | Modify | Delete |
|---|---|---|---|
| Art | five fighter `.aseprite` sources and exports, the `_ai` files in Task 1 | `gen/stage.py`, `gen/import_adventure_kit.py` | `aseprite/adv_fighter_spirit_ai.aseprite` and its export (superseded by the Amorphous Spirit) |
| Stage | | `adventure_data.gd`, `shallow_woods.tres`, `adventure_view.gd/.tscn`, `adventure_combat.gd/.tscn` | `scenes/atmosphere/`, `assets/shaders/vignette.gdshader`, `scenes/zones/zone_view_background/` |
| Fighters | `scenes/common/lacquer/lacquer_floater/` (moved) | `combatant_visual.gd/.tscn`, `combatant_node.gd`, `combatant_data.gd`, four enemy `.tres`, `map_markers.gd/.tscn`, `test_map_markers.gd` | `damage_number.gd/.tscn` |
| Opponent | `scenes/adventure/adventure_chest/opponent_page/` | `adventure_chest.gd/.tscn` | |
| Dissolve | `assets/shaders/dither_dissolve.gdshader` | `adventure_view.gd/.tscn` | |
| Wiring | | `adventure_view.gd`, `adventure_combat.gd/.tscn` | `scenes/ui/combat/{enemy_nameplate,cast_bar,resource_bar,buff_bar,buff_icon,combat_buff_tooltip}/`, six styleboxes |

`gen/` and `aseprite/` are under `docs/superpowers/mockups/adventure-view-lacquer/`. Every deleted script goes with its `.uid`.

---

### Task 1: Draw and import the fight art

Skills: `godot-prompter:assets-pipeline`, `godot-prompter:2d-essentials`.

**Files:**
- Create (Aseprite, in `aseprite/`): `adv_fighter_player_ai.aseprite` (redrawn), `adv_fighter_starving_dreadbeast_ai.aseprite`, `adv_fighter_ravenous_dreadbeast_ai.aseprite`, `adv_fighter_amorphous_spirit_ai.aseprite`, `adv_fighter_coalescing_spirit_ai.aseprite`, each exported at 2x to the mock folder as `adv_fighter_<name>_ai.png`
- Modify: `gen/stage.py` (`shadow(name: str, art_width: int)` for every fighter), `gen/import_adventure_kit.py` (this task's destinations)
- Delete: `aseprite/adv_fighter_spirit_ai.aseprite`, `adv_fighter_spirit_ai.png`, `adv_shadow_spirit_ai.png` (the mock's combat screen points at the Amorphous Spirit instead)
- Create (by the import): `assets/sprites/combat/stages/shallow_woods_stage_ai.png` (from `adv_stage_bamboo_ai.png`); `assets/sprites/combat/fighter_player_ai.png` and `fighter_player_shadow_ai.png`; `assets/sprites/combat/enemies/fighter_{starving_dreadbeast,ravenous_dreadbeast,amorphous_spirit,coalescing_spirit}_ai.png` and `_shadow_ai.png`; `assets/ui/lacquer/lacquer_rod_{health,intent}_{empty,full,end}_ai.png`; `assets/ui/lacquer/lacquer_plate_casting_ai.png`
- Modify: `docs/superpowers/mockups/adventure-view-lacquer-mockup.html` (the combat screen shows the new player and Amorphous Spirit exports)
- Test: extend `tests/unit/test_adventure_kit_assets.gd`

**Interfaces:**
- Produces (2x sizes): player 112x208 (art 56x104), Starving Dreadbeast 192x144 (96x72), Amorphous Spirit 144x144 (72x72), Ravenous Dreadbeast 224x168 (112x84, elite), Coalescing Spirit 176x176 (88x88, elite); shadows 12 tall, width the even number nearest 0.75 × the fighter's 2x width; stage 1920x1080; health rod 260x10, intent rod 256x10, end caps 2x10; Casting plate 90x24 (2 px shadow baked).

Start from the mock's placeholders (`adv_fighter_player_ai.aseprite` sets the player's look, `adv_fighter_spirit_ai.aseprite` the Amorphous Spirit's). The Dreadbeasts are lean, hungry four-legged spirit beasts (the Ravenous one bigger, with more teeth); the Coalescing Spirit is the Amorphous Spirit grown denser, with a core.

- [ ] **Step 1: Write the failing tests:** `test_fighters_have_their_sizes`; `test_fighters_sit_on_the_2x_grid` (every 2x2 block one colour); `test_fighters_stand_on_their_bottom_row` (each export has an opaque pixel in its last row); `test_fighter_shadows` (12 tall, widths as above); `test_stage_is_full_screen_on_the_grid`; `test_fight_ui_pieces_have_their_sizes` (rods and the Casting plate).
- [ ] **Step 2: Run; expect failures.**
- [ ] **Step 3: Draw the five fighters in Aseprite** (one pass per stage of the MCP's checklist; view each at 1x and 2x beside the stage export before moving on), export them, extend `stage.py` and the import script.
- [ ] **Step 4: Run `build_all.py`, the import script, `--import`.**
- [ ] **Step 5: Run the file; green. Open the mock's combat screen and check the new fighters on the stage.**
- [ ] **Step 6: Commit** `feat(combat): draw the lacquer fighters and import the fight art`. List every new `_ai` file in the task report.

---

### Task 2: The adventure's stage

Skills: `godot-prompter:resource-pattern`, `godot-prompter:2d-essentials`, `godot-prompter:godot-testing`.

**Files:**
- Modify: `scripts/resource_definitions/adventure/adventure_data.gd`, `resources/adventure/data/shallow_woods.tres`, `scenes/adventure/adventure_view/adventure_view.tscn` + `.gd`, `scenes/combat/adventure_combat/adventure_combat.gd` + `.tscn`
- Delete: `scenes/atmosphere/` (script, scene, uid), `assets/shaders/vignette.gdshader`, `scenes/zones/zone_view_background/` (grep each for other users first; the merchant's own `MerchantAtmosphere` keeps the mist and mote sprites). The five `assets/sprites/zones/backgrounds/spirit_valley/layer_*.png` are the user's: leave them for the user to delete.
- Test: `tests/integration/test_combat_stage.gd`

**Interfaces:**
- Produces: `AdventureData`: `@export var combat_stage: Texture2D` (in the Adventure Information category); `AdventureView` node `%CombatStage` (`TextureRect`, 1920x1080, the first child of `CombatView`, which becomes full rect; the `SubViewportContainer` follows it, full rect). `AdventureCombat`: `PlayerSpot` at (700, 840), `EnemySpot` at (1220, 840) (the fighters' feet).

Rules: `start_adventure` sets `CombatStage.texture` from `action_data.adventure_data.combat_stage` (empty when null). `ZoneViewBackground` leaves `AdventureView` (the map has its own ground since PR 1). `AdventureCombat` drops `atmosphere_scene`, `_atmosphere` and `_setup_atmosphere()`.

- [ ] **Step 1: Write the failing tests:** `test_stage_shows_the_adventures_stage`; `test_stage_is_behind_the_fight` (first child of `CombatView`); `test_no_atmosphere_in_the_fight` (no `Atmosphere` under `AdventureCombat` after `start()`); `test_spots_put_the_feet_on_840`; `test_shallow_woods_has_its_stage` (1920x1080); `test_no_painted_forest_left` (no `ZoneViewBackground` node).
- [ ] **Step 2: Run; expect failures.**
- [ ] **Step 3: Implement; delete; `--import`; grep `atmosphere.tscn`, `vignette`, `zone_view_background` (none left outside docs).**
- [ ] **Step 4: Run the new file, `test_adventure_combat_victory_event.gd`, `test_adventure_end_flow.gd`, `test_merchant_shop_flow.gd`; green.**
- [ ] **Step 5: Commit** `feat(adventure): give the Shallow Woods its own combat stage`.

---

### Task 3: Move the zone map's floater into the shared lacquer pieces

Skills: `godot-prompter:scene-organization`, `godot-prompter:godot-testing`.

**Files:**
- Move: `scenes/zones/map_markers/map_floater/` → `scenes/common/lacquer/lacquer_floater/` (`git mv`, files renamed `lacquer_floater.*`, `class_name LacquerFloater`; fix the `.uid` and every reference)
- Modify: `scenes/zones/map_markers/map_markers.gd` + `.tscn`, `tests/integration/test_map_markers.gd` (the rename only)
- Test: `tests/unit/test_lacquer_floater.gd`

**Interfaces:**
- Produces: `LacquerFloater` with `MapFloater`'s API unchanged: `pop(text: String, color: Color) -> void`, `stop() -> void`, `get_text() -> String`, `get_color() -> Color`, `get_rise() -> int`, `get_token_width() -> int`, `static rise_at(elapsed: float) -> int`, `RISE_PX` 40, `RISE_SECONDS` 1.0, `RISE_STEPS` 20. Visible while it rises, hidden after (the owner places it each frame at its base position minus `get_rise()`, as `MapMarkers` does).

- [ ] **Step 1: Write the failing test:** `test_rise_steps` (0 → 0, 0.05 → 2, 0.5 → 20, 1.0 → 40); `test_pop_sets_text_and_colour`; `test_token_width_is_even`; `test_hidden_after_its_rise`.
- [ ] **Step 2: Run; expect failures** (no `LacquerFloater`).
- [ ] **Step 3: Move and rename; `--import`; grep `MapFloater` and `map_floater` (none left outside docs and git history).**
- [ ] **Step 4: Run the new file and `test_map_markers.gd`; green.**
- [ ] **Step 5: Commit** `refactor(ui): move the map floater into the shared lacquer pieces`.

---

### Task 4: Fighters at 2x with stepped motion and lacquer floaters

Skills: `godot-prompter:animation-system`, `godot-prompter:tween-animation`, `godot-prompter:2d-essentials`, `godot-prompter:godot-testing`.

**Files:**
- Modify: `scenes/combat/combatant/combatant_visual/combatant_visual.gd` + `.tscn`, `scenes/combat/combatant/combatant_node.gd`, `scripts/resource_definitions/combat/combatant_data.gd`, `resources/combat/combatant_data/{amorphous_spirit,coalescing_spirit,ravenous_dreadbeast,starving_dreadbeast}.tres`, `scenes/combat/adventure_combat/adventure_combat.gd`, `scenes/adventure/adventure_view/adventure_view.tscn` (combat `SubViewport` `canvas_item_default_texture_filter = 0`)
- Delete: `scenes/combat/combatant/combatant_visual/damage_number.gd` + `.tscn`. `test_character_sprite.png` and `test_enemy_sprite.png` become unused; they are third-party art the user imported, so they stay for the user to delete.
- Test: `tests/unit/test_combatant_visual_motion.gd`, `tests/integration/test_combatant_visual.gd`

**Interfaces:**
- Consumes: Task 1 (fighters, shadows), Task 3 (`LacquerFloater`).
- Produces:
  - `CombatantData`: `scale` removed; `@export var shadow_texture: Texture2D` in the Visuals group.
  - `CombatantVisual`: `setup(texture: Texture2D, shadow: Texture2D, sprite_offset: Vector2, face_left: bool, is_player: bool) -> void`; `get_visual_height() -> float` (texture height × 2); `play_enter() -> void`; `play_attack() -> void`; `play_hit(amount: float) -> void`; `play_heal(amount: float) -> void`; `get_visible_floater_count() -> int`. `play_buff()` goes (the buff's socket flashes instead) and `CombatantNode._on_ability_executed` only calls `play_attack()` for an ability with target effects. Constants: `ART_SCALE: int = 2`; `ENTER_DISTANCE: int = 420`; `ENTER_SECONDS: float = 0.4`; `ATTACK_KEYFRAMES: Array[int] = [-8, 40, 40, 0]`; `HIT_KEYFRAMES: Array[int] = [-12, -12, 0]`; `MOTION_STEP_SECONDS: float = 0.06`; `BOB_KEYFRAMES: Array[int] = [0, -2, -4, -2]`; `BOB_STEP_SECONDS: float = 0.6`; `FLASH_SECONDS: float = 0.066`; `FLOATER_COUNT: int = 4`; `NUMBER_GAP: int = 40`. `enum FloaterKind { DAMAGE_DEALT, DAMAGE_TAKEN, HEAL }`. Statics: `enter_offset_at(elapsed: float) -> int` (the distance still to go: the even number nearest `ENTER_DISTANCE × (1 − clamp(elapsed / ENTER_SECONDS, 0, 1))`); `attack_offset_at(elapsed: float) -> int` and `hit_offset_at(elapsed: float) -> int` (the keyframe at `floori(elapsed / MOTION_STEP_SECONDS + 1e-4)`, the last one after); `bob_offset_at(elapsed: float) -> int` (looping); `floater_colour(kind: FloaterKind) -> Color` (cream, `LACQUER_HEALTH`, `LACQUER_HEALTH`); `floater_text(kind: FloaterKind, amount: float) -> String` ("-%d" / "+%d" of `roundi(amount)`).

Rules: one body motion at a time, driven from `_process` by elapsed time (or `tween_method` over a static, as `MapGlyph` shakes): the body's x is `−facing × enter_offset_at(t)` while entering, `facing × attack_offset_at(t)` while attacking, `facing × hit_offset_at(t)` after a hit; the sprite's y follows `bob_offset_at()` always. The sprite is shown outright (no alpha) at scale 2 with its offset putting the feet at the origin, flipped for enemies; the shadow sprite (`shadow`, scale 2, centred on the feet, nearest: drop the `texture_filter = 2` and the gradient texture). A hit sets `hit_flash.gdshader`'s `flash_color` to `ThemeConstants.LACQUER_CREAM` and `flash_amount` to 1.0 for `FLASH_SECONDS`, then 0. Damage on the player pops DAMAGE_TAKEN, on the enemy DAMAGE_DEALT; a heal pops HEAL with no flash. Madra and Stamina pop nothing on the fighters (the cabinet shows them), so the spec's Madra-blue and bamboo floater colours wait for a piece that pops them. `%Floaters` holds `FLOATER_COUNT` `LacquerFloater`s in the scene: a number takes the first hidden one, else the one risen furthest; each visible floater sits centred on x 0, its token's top `NUMBER_GAP` above the sprite's top, minus its `get_rise()`, every frame. `CombatantNode._update_visuals()` passes `combatant_data.shadow_texture`. The player's data in `AdventureCombat` uses `fighter_player_ai.png` and `fighter_player_shadow_ai.png` (preloaded constants). The four enemy `.tres` point at their fighter and shadow and lose `scale`.

- [ ] **Step 1: Write the failing tests.** Unit: `test_enter_steps` (0 → 420, 0.2 → 210, 0.4 and after → 0; every value even); `test_attack_keyframes` (0, 0.07, 0.13, 0.19, 0.3 → −8, 40, 40, 0, 0); `test_hit_keyframes`; `test_bob_loops` (0, 0.6, 1.2, 1.8, 2.4 → 0, −2, −4, −2, 0); `test_floater_colours_and_text`. Integration (a `combatant_node.tscn` set up with `amorphous_spirit.tres`, and a player one as in `test_adventure_combat_victory_event.gd`):
  - `test_sprite_is_drawn_at_2x` (scale 2, the fighter texture, feet at the origin).
  - `test_shadow_comes_from_the_data`.
  - `test_enter_moves_in_even_steps` (sampled each frame for 0.4 s).
  - `test_hit_flashes_for_two_frames` (`flash_amount` 1.0 right after, 0 after 0.1 s).
  - `test_hit_pops_a_signed_number` (player: "-9" in `#E8737A`; enemy: "-9" in cream); `test_heal_pops_a_plus_number`.
  - `test_fifth_number_takes_the_oldest_floater` (Review Focus 4: five hits in a row → four visible floaters, the newest text among them).
  - `test_every_enemy_has_art_and_a_shadow` (the four `.tres`: texture and shadow set; `CombatantData` has no `scale` property).
- [ ] **Step 2: Run; expect failures.**
- [ ] **Step 3: Implement; `--import`; grep `DamageNumber`, `display_height`, `.scale` on combatant data (none left).**
- [ ] **Step 4: Run the new files and every `test_combat_*`, `test_adventure_combat_*`, `test_empty_palm_interrupt.gd`, `test_power_font_buff_strip.gd`; green.**
- [ ] **Step 5: Commit** `feat(combat): draw fighters at 2x with stepped motion and lacquer floaters`.

---

### Task 5: The opponent page

Skills: `godot-prompter:hud-system`, `godot-prompter:godot-ui`, `godot-prompter:godot-testing`.

**Files:**
- Create: `scenes/adventure/adventure_chest/opponent_page/opponent_page.tscn` + `.gd`
- Modify: `scenes/adventure/adventure_chest/adventure_chest.tscn` + `.gd`
- Test: `tests/integration/test_opponent_page.gd`, extend `tests/integration/test_adventure_chest.gd`

**Interfaces:**
- Consumes: Task 1 (health and intent rods, Casting plate), PR 1 (`AdventureChestPage`, `BuffTooltip`, `AbilityRow.format_damage()`, `format_seconds()`, `AdventureCombat.gold_reward_for()`).
- Produces:
  - `AdventureChest`: `enum Page { EXPEDITION, OPPONENT }`; `show_page(page: Page) -> void` (shows one page, hides the other, relayouts); `get_page() -> Page`; `get_opponent_page() -> OpponentPage`.
  - `class_name OpponentPage extends AdventureChestPage`: `bind(enemy: CombatantNode, choice: CombatChoice, adventure_action: AdventureActionData) -> void`; `unbind() -> void`; `const INTERRUPTED_SECONDS: float = 0.6`, `MAX_TECHNIQUE_ROWS: int = 4`, `MAX_BUFF_SOCKETS: int = 3`; statics `technique_line(ability: AbilityData, attributes: CharacterAttributesData) -> String` and `cast_detail(ability: AbilityData, attributes: CharacterAttributesData) -> String` (`format_damage()` with its first letter upper-cased; "" for no damage).

Layout (page-local; screen = local + (1472, 106)): "Health" (`LabelLacquerDetail`) at (0, 2); a `LacquerRod` (health rod, steps 129) at (68, 6); the value (`LabelLacquerName`, `ceili(current)` and " / max" in tan) right-aligned in (328, −2, 80, 20). The Casting plate (`lacquer_plate_casting_ai.png` with "Casting" in `LabelLacquerLegend`) at (12, 29); the tray (`lacquer_now_tray_ai.png`) at (0, 40), holding the cast's name (`LabelLacquerNowName`) at (18, 16), the time left (`RichTextLacquer`, `LacquerText.decimal_bbcode("%.1f s")`) right-aligned to x 390 at y 16, `cast_detail` (`LabelLacquerDetail`) at (18, 40), a `LacquerRod` (intent rod, steps 127) at (18, 64); "Gathering its madra" (`LabelLacquerDetail`) at (18, 34); "Interrupted" (`LabelLacquerNowName` in brass) at (18, 32). A 408-wide `VBoxContainer` from (0, 148): the Buffs row (48 tall: "Buffs" in `LabelLacquerDetail` at (0, 14), three `socket_buff` sockets at x 48 + 46·i, y 4, built like `VitalsPlate`'s, with their `frame_brass` flash), the Techniques section ("Techniques" in `LabelLacquerSection` with a groove, then four rows 26 apart from y 32: the name in `LabelLacquerName` left, `technique_line` in `LabelLacquerDetail` right-aligned), a divider (8 above), the reward row (10 above: `gold_icon.png` at 32, "<gold> gold" in `LabelLacquerName`, "if you win" in `LabelLacquerDetail`, in a row). A `BuffTooltip` child opens with its top-right 8 px left of the chest (screen x 1448) at the hovered socket's y.

Rules: Health follows the enemy's `health_changed` (rod fraction current / max). The tray follows every enemy instance's cast signals: `cast_started` shows the name, the time, `cast_detail` and the rod (fraction 1 − time_left / duration, stepped on `cast_updated`); `cast_finished` shows the gathering line; `cast_cancelled` shows "Interrupted", shaking with `MapGlyph.shake_offset_at()`, for `INTERRUPTED_SECONDS`, then the gathering line; a `cast_started` meanwhile replaces it at once. The Buffs row shows only while the enemy has a buff; sockets fill from the left and flash once when their buff lands. Technique rows come from `enemy.ability_manager.abilities` with `enemy.combatant_data.attributes`; `technique_line`: "<cast> s cast" (`AbilityRow.format_seconds(cast_time)`) or "Instant", then " · " and the damage line when there is one. The reward is `AdventureCombat.gold_reward_for(choice, adventure_action)`. Any change of height emits `content_resized`. `unbind()` disconnects everything and hides the tooltip.

- [ ] **Step 1: Write the failing tests** (an enemy `combatant_node.tscn` set up with a `CombatantData`, as the combat tests do; casts driven through the instance's `start_cast()` and `cancel_cast()`):
  - `test_health_follows_the_enemy`.
  - `test_cast_shows_name_time_detail_and_rod`; `test_cast_finished_goes_back_to_gathering`.
  - `test_interrupt_shows_interrupted_then_gathering` (gone after 0.6 s); `test_new_cast_after_an_interrupt` (Review Focus 3).
  - `test_buffs_row_only_with_a_buff` (and `content_resized` fires both ways); `test_tooltip_hides_when_its_buff_expires` (Review Focus 5).
  - `test_techniques_list_one_row_per_ability` (Coalescing Spirit: two rows; Madra Lash's row "2 s cast · about <n> Spirit damage").
  - `test_enemy_without_techniques` (Review Focus 2).
  - `test_reward_matches_the_fight_rule`; `test_unbind_disconnects`.
  - Chest: `test_show_page_switches_and_hugs` (OPPONENT shows the opponent page only and the chest hugs it; back to EXPEDITION).
- [ ] **Step 2: Run; expect failures.**
- [ ] **Step 3: Build; `--import`.**
- [ ] **Step 4: Run the new files and `test_adventure_chest.gd`; green. Capture the chest with the page beside the mock's combat screen.**
- [ ] **Step 5: Commit** `feat(adventure): show the opponent in the chest`.

---

### Task 6: The dither dissolve into fights

Skills: `godot-prompter:shader-basics`, `godot-prompter:godot-testing`.

**Files:**
- Create: `assets/shaders/dither_dissolve.gdshader`
- Modify: `scenes/adventure/adventure_view/adventure_view.tscn` + `.gd`
- Test: `tests/integration/test_combat_dissolve.gd`

**Interfaces:**
- Note (2026-10-27): `assets/shaders/dither_dissolve.gdshader` already exists, built for `ViewDissolve` (the zone view ↔ adventure dissolve, MAIN_VIEW.md). Reuse it rather than creating it. It has `dissolve_step` as below, works on `floor(VERTEX / 2)` cells per the style guide's shader pattern, and adds `invert` (off by default). Its step 2 discards cells where `x % 2 == 1 && y % 2 == 0`, not `x % 2 == 1 && y % 2 == 1` as written below: the (odd, odd) cells are among those step 1 shows, so discarding them at step 2 would make cells blink back out, while step 2 must show a superset of step 1's cells.
- Produces: `dither_dissolve.gdshader` (canvas_item): `uniform int dissolve_step : hint_range(0, 2) = 0;` the cell `ivec2(FRAGCOORD.xy) / 2`; step 1 discards cells where `(x + y) % 2 == 1` (half); step 2 discards cells where `x % 2 == 1 && y % 2 == 1` (a quarter); step 0 draws everything; colour untouched otherwise (no alpha). `AdventureView`: `const DISSOLVE_STEP_SECONDS: float = 0.1`; `is_dissolving() -> bool`. `CombatView` carries a `ShaderMaterial` on the shader in the scene (`dissolve_step` 0); `CombatStage` and the combat `SubViewportContainer` set `use_parent_material = true`.

Rules: `_on_start_combat` shows `CombatView` with `dissolve_step` 1 over the still-visible map, sets 2 after 0.1 s, and after 0.2 s sets 0 and hides `TilemapView` (a `Tween` of `tween_interval`/`tween_callback` steps; nothing interpolated). This replaces `_fade_in_combat_view()`, which goes. `_on_stop_combat` during a dissolve kills it, sets 0, shows `TilemapView` and hides `CombatView`.

- [ ] **Step 1: Write the failing tests** (the view instanced as in `test_adventure_end_flow.gd`, a fight started with `_on_start_combat`):
  - `test_dissolve_runs_two_steps_then_shows_the_fight` (right after: step 1, map visible; at 0.15 s: step 2; at 0.25 s: step 0, map hidden).
  - `test_fight_ending_mid_dissolve_restores_the_map` (Review Focus 1: end at 0.05 s → step 0, map visible, fight hidden, `is_dissolving()` false).
  - `test_no_alpha_fade` (`CombatView.modulate.a` stays 1.0 through the dissolve).
  - `test_dissolve_shader_has_its_step` (the material's shader lists `dissolve_step`).
- [ ] **Step 2: Run; expect failures.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the new file and `test_adventure_end_flow.gd`; green.**
- [ ] **Step 5: Commit** `feat(adventure): dissolve into fights in two dither steps`.

---

### Task 7: Wire the fight and remove the old fight HUD

Skills: `godot-prompter:scene-organization`, `godot-prompter:godot-testing`.

**Files:**
- Modify: `scenes/adventure/adventure_view/adventure_view.gd`, `scenes/combat/adventure_combat/adventure_combat.gd` + `.tscn`
- Delete: `scenes/ui/combat/enemy_nameplate/`, `scenes/ui/combat/cast_bar/` (`cast_bar.*` and `intent_bar.tscn`), `scenes/ui/combat/resource_bar/`, `scenes/ui/combat/buff_bar/`, `scenes/ui/combat/buff_icon/`, `scenes/ui/combat/combat_buff_tooltip/`, and the styleboxes `combat/panel_nameplate`, `combat/panel_intent`, `combat/cast_bar_fill`, `combat/cast_bar_fill_enemy`, `combat/bar_fill_health`, `combat/bar_track` (grep each for other users first). `FloatingText` stays (cycling uses it). The user's `buff_icon_border.png` and `buff_icon_overlay.png` stay for the user to delete.
- Test: extend `tests/integration/test_adventure_view_frame.gd`

**Interfaces:**
- Consumes: Tasks 2, 4–6.

Rules: `_on_start_combat`: `adventure_chest.set_title(enemy.combatant_data.character_name)`, `show_page(Page.OPPONENT)`, `get_opponent_page().bind(combat.enemy_combatant, choice, current_action_data)`. `_on_stop_combat` and `stop_adventure`: `unbind()`, `show_page(Page.EXPEDITION)`, the title back to the action's name. `AdventureCombat` drops `HudLayer`, `EnemyNameplate`, `enemy_nameplate`, `NAMEPLATE_GAP` and `_place_nameplate()`.

- [ ] **Step 1: Write the failing tests:** `test_fight_shows_the_opponent_page` (title the enemy's name, page OPPONENT); `test_fight_end_returns_to_the_expedition_page`; `test_second_fight_rebinds` (two fights in a row: the page shows the second enemy's health); `test_no_enemy_nameplate` (no `%EnemyNameplate` in `AdventureCombat`).
- [ ] **Step 2: Run; expect failures.**
- [ ] **Step 3: Wire it; delete; grep `EnemyNameplate`, `CastBar`, `IntentBar`, `ResourceBar`, `BuffBar`, `BuffIcon`, `CombatBuffTooltip` (none left); `--import`; check `git diff project.godot`.**
- [ ] **Step 4: Run the suite; green. Back up the save; capture a fight in a scratch scene (not committed) that starts the Shallow Woods on a fresh save and opens a fight; check the save hash; compare with the mock's combat screen and fix placement.**
- [ ] **Step 5: Commit** `feat(adventure): show the fight in the lacquer frame`, then `refactor(combat): remove the old fight HUD` for the deletions.

---

### Task 8: Docs

**Files:**
- Modify: `docs/combat/COMBAT.md` (fighters, floaters, the opponent page), `docs/adventuring/ADVENTURING.md` (the stage, the dissolve), `docs/STYLE_GUIDE.md` (delete the done rows B4–B7, B9 and S1–S3; F6 progress; the cascade's suggested order), `CLAUDE.md` (Reusable UI Components: `LacquerFloater` joins the lacquer pieces, `Atmosphere` and `DamageNumber` go; Shaders: `lacquer_cooldown_sweep` and `dither_dissolve` in, `fog_of_war` and `vignette` out; Game Systems: adventuring and combat lines), `docs/README.md`, `docs/STATE_OF_THE_GAME.md`, the spec's Status line ("built"), both plans' checkboxes and an "As built" section in this plan.
- [ ] **Step 1: Update each doc to the built state.**
- [ ] **Step 2: Commit** `docs(adventure): document the lacquer fight`.
