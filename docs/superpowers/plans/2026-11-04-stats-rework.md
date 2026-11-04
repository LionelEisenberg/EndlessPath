# Stats Rework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rework EndlessPath's stats into six trained stats with levels, XP and a per-stage cap, give home and runs one Madra pool and one Health pool, move Core Density to fights, and rebuild cycling, body refining, Core Density's look and the quest line around that loop, in six phases of one PR each.

**Architecture:** `CharacterAttributesData` becomes the combat stat block shared by the player's fight snapshot and every enemy. The player's progress moves to a new saved `StatTrainingData` (a level and XP per stat) owned by `CharacterManager`, with the cap read live from the current `AdvancementStageResource`. Bonuses keep flowing through `StatModifierStack`: gear as floored percents plus armor and Ward. `ResourceManager` becomes the single owner of the saved Madra pool (and, in phase 5, of Health), and the player's `VitalsManager` becomes a façade over it.

**Tech Stack:** Godot 4.7.2, GDScript, GUT 9.7.1, Dialogic 2 (story), Design canvases for the mock-ups.

**Spec:** `docs/superpowers/specs/2026-11-04-stats-rework-design.md` (who decided what: `docs/superpowers/specs/2026-11-04-stats-rework-decisions.md`).

## Global Constraints

- Godot 4.7.2, GDScript. Console binary for tests: `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe"`.
- Explicit return types and typed class variables. Public functions have a `##` doc comment and no leading `_`; private helpers and signal handlers start with `_`. Node references use `%UniqueName`. Use `#----` section headers like the neighbouring files.
- No `print()`. Use `Log.info/warn/error` for diagnostics and `LogManager.log_message()` only for lines the player reads.
- Never modify `addons/`.
- Data-driven: classes live in `scripts/resource_definitions/` and instances in `resources/`; change both together. Write values explicitly in `.tres`. Godot's text saver omits values equal to the script default, so a later default change would silently rewrite them.
- Enums stored as ints in `.tres` files or saves only grow at the end, with a comment saying so and a test pinning their numbers.
- UI:
  - Never create UI nodes in code. Build scenes with theme variants, scripts set data, and lists instance PackedScenes.
  - No text is ever cut off. A Label that can run long wraps, and its board grows. No ellipsis, `clip_text`, `text_overrun_behavior` or `max_lines_visible` cut-offs (`tests/integration/test_boards_never_trim_text.gd`).
  - Read `docs/UI_STYLING.md` before adding label overrides and `docs/STYLE_GUIDE.md` before building a screen.
  - Screens build what the phase's approved mock-ups show.
- Any new art file gets an `_ai` suffix. Never edit an art file without the suffix: it is Lionel's.
- Tests:
  - GUT 9.7.1, `extends GutTest`, `func test_<behaviour>() -> void`, a `##` header, and table tests as `Array[Dictionary]` cases with an assert message naming the case.
  - Tests call production code, never re-implement it.
  - Don't test how a screen looks. Test rules, state, saves, migrations and what each control does.
  - Swap and restore global state (`PersistenceManager.save_game_data = SaveGameData.new_current(); PersistenceManager.save_data_reset.emit()` in `before_each`, restored in `after_each`). Never null an autoload's state, and remove any modifier source a test sets.
  - No GUT doubles. Use injectable Callables (the `TribulationView.clock_usec` pattern) and hand-written fakes.
- Commands:
  - One test file: `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/unit/test_<name>.gd -gexit` (integration files under `res://tests/integration/`).
  - Full suite: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_tests.ps1`. It also fails scripts that don't parse or run no tests.
  - Agent game runs add `-- --save=user://dev/runs/<name>.tres`.
- Before implementing a system, invoke the matching `godot-prompter:*` skill: `resource-pattern`, `save-load`, `godot-ui`, `hud-system`, `godot-testing`. The project's versioned Resource `.tres` save stays; CLAUDE.md wins over the save-load skill's JSON advice.
- Git:
  - Each phase is one PR on its own feature branch. Commit after each task with a conventional message (`feat(stats): …`), staging specific files and ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
  - Never merge. Feature PRs don't edit living docs; each PR description ends with `## Docs to update`.
- Copy:
  - The stats are Strength, Body and Agility (Physical) and Spirit, Mind and Control (Spiritual). Magic resist shows as "Ward". Screens never print "minor".
  - The level-up log line reads "[b]Spirit[/b] reached Lv 6".

## Review Focus

1. **A version-1 save** with Aura Well Spirit (`spirit = 13.0`), dev-raised stats and worn gear loads and migrates to the right levels. Nothing else is lost, and the save is never set aside as unreadable (Task 1.4).
2. **Training at the cap:** XP or an Aura Well level that arrives at the cap is lost, and the level never passes the cap. The breakthrough reads trained levels, never totals that include gear (Tasks 1.3 and 1.13).
3. **Gear's "+N now"** always equals the bonus actually applied: at Lv 1 (the floor), past the cap, and after a level-up while the inventory is open (Tasks 1.6 and 1.8).
4. **A dodged hit** lands no target effect, including riders such as CANCEL_CAST. The attacker's own self effects still apply, and enemies never dodge (Task 1.10).
5. **The one Madra pool** behaves when its max drops (Mind gear removed), when a run is quit midway, and when a run starts at exactly half Madra (Tasks 2.1 to 2.3).

## How this plan is organised

- **Six phases, six PRs:** 1 Stats, 2 One Madra pool, 3 Cycling, 4 Core Density, 5 Body refining and Health, 6 Quests and story. Each phase is one focused unit on its own branch. `main` may be broken between phases (Lionel). No itch build until phase 5 lands.
- **A mock-up gate opens every phase** (Task N.0). A new Design canvas for that phase's screens is shown to Lionel and approved before any of the phase's UI is built. Phase 1's mock-ups come right after this plan; phase N+1's come after phase N lands.
- **How detailed each phase is:** phases 1 and 2 are written as full tasks. Phases 3 to 6 are outlines, because their designs settle at their mock-up step. After each of those phases' mock-ups are approved, its outline is replaced in this file by full tasks in the same format.
- **Task numbering:** tasks are numbered `N.M` within phase `N`. Each task ends with a commit, and each phase ends with a wrap task: the full suite green, a dev run of the game, and the PR.

---

## File structure

Phases 1 and 2 mostly change existing files. Each task's **Files** list is exact; this map shows where each responsibility lives.

**New files**

| File | Responsibility | Task |
|---|---|---|
| `scripts/resource_definitions/character/stat_training_data.gd` | `StatTrainingData`: the player's saved level and XP per stat | 1.2 |
| `scripts/resource_definitions/character/stat_progression_data.gd`, `resources/character/stat_progression.tres` | `StatProgressionData`: the level curve (XP to the next level, a level's value), held only by `CharacterManager.stat_progression` | 1.2 |
| `scripts/utils/stat_display.gd` | `StatDisplay`: each stat's name, icon and side on screen | 1.15 |
| `assets/sprites/ui/attribute_icons/mind_icon_ai.png`, pressed XP bar textures in `assets/sprites/ui/book/pressed/` | Art, only if the phase 1 mock-ups ask for it | 1.15, 1.16 |
| `tests/unit/test_stat_training_data.gd`, `tests/unit/test_stat_progression_data.gd` | The training record and the level curve | 1.2 |
| `tests/integration/test_item_description_panel.gd` | The item tooltip's gear lines | 1.8 |
| `tests/unit/test_combat_content.gd` | The shipped techniques' and enemies' Lv 1 numbers | 1.9 |
| `tests/unit/test_combat_dodge.gd` | Dodge | 1.10 |
| `tests/unit/test_ability_data.gd`, `tests/unit/test_control_cuts.gd` | Control's Madra cost and cooldown cuts | 1.11 |
| `tests/unit/test_stat_display.gd` | `StatDisplay` | 1.15 |
| `tests/integration/test_adventure_end_card.gd`, `tests/integration/test_character_book_madra.gd` | The end card's and the Character book's Madra lines | 2.3, 2.4 |

**Deleted:** `scenes/abilities/ability_stats_display/`, `scenes/abilities/stat_label/` and `scenes/abilities/stat_tooltip/`, which nothing uses (Task 1.1).

**Where the existing responsibilities go**

| Area | Files | Tasks |
|---|---|---|
| Stat identity and the combat stat block | `character_attributes_data.gd` (six stats, armor, Ward, the derived values), `stat_modifier_data.gd` | 1.1 |
| Training, the cap and the save | `character_manager.gd`, `save_game_data.gd`, `advancement_stage.gd` and both stage `.tres`, `cultivation_manager.gd` | 1.2–1.5 |
| Gear | `equipment_definition_data.gd`; `docs/inventory/ITEMS.md` with `items_md_parser.gd`, `items_md_to_resources.gd` and the regenerated Spirit Valley items; `book_text.gd`, `equipment_details`, `bonus_row`, `item_description_panel.gd`, `merchant_stock_row.gd` | 1.6–1.8 |
| Combat | `combat_effect_data.gd` and the technique and enemy `.tres`; `combat_effect_manager.gd`, `combatant_visual.gd`; `ability_data.gd`, `combat_ability_instance.gd`, `combat_ability_manager.gd`, the dock's slot and tooltip, `ability_row.gd`; `adventure_view.gd` | 1.9–1.12 |
| The breakthrough | `tribulation_action_data.gd`, `tribulation_presenter`, `goals_panel.gd`, `action_manager.gd`, the Tribulation's copy | 1.13 |
| Dev tools | `dev_commands.gd`, `dev_step_data.gd`, the dev panel's Player tab, `story_route.tres` | 1.14 |
| Stat screens | `abilities_view.gd`; `character_view` and `attribute_tile` | 1.15, 1.16 |
| One Madra pool | `resource_manager.gd` (the pool and its max); `vitals_manager.gd` and `player_manager.gd` (the player's façade); `action_manager.gd`, `adventure_view.gd`, `zone_transition.gd`, `adventure_result_data.gd`, `adventure_end_card` (runs); `cultivator_plate.gd`, `adventure_presenter.gd`, `character_view.gd` and cycling's two callers (readouts) | 2.1–2.4 |

**Phases 3 to 6:** each outline lists its files. The new code is phase 5's: `BodyRefiningActionData`, `DrillData` and `DrillList`, the `BodyRefiningManager` autoload, the drill scenes, and `BodyRefiningView` with its view state. Phase 6 adds quest, unlock and preset `.tres` files.

---

## Shared interfaces

These names and signatures cross tasks and phases. Every task uses them as written here.

**Stat identity** (`scripts/resource_definitions/character/character_attributes_data.gd`)
- `enum AttributeType { STRENGTH = 0, BODY = 1, AGILITY = 2, SPIRIT = 3, MIND = 4, CONTROL = 5 }`. FOUNDATION is renamed MIND in place (int 4); RESILIENCE (6) and WILLPOWER (7) are removed. The enum only grows at the end from now on.
- `static func stat_key(stat: AttributeType) -> StringName` returns `&"strength"`, `&"body"`, `&"agility"`, `&"spirit"`, `&"mind"` or `&"control"`. `static func stat_from_key(key: StringName) -> int` returns the stat, or -1 for an unknown key.

**The combat stat block: `CharacterAttributesData`** (same path and class name, because old saves and the enemy files reference it by path)
- `strength`, `body`, `agility`, `spirit`, `mind`, `control: float = 10.0`; `armor: float = 0.0`; `ward: float = 0.0`. There is no positional constructor; `static func make(values: Dictionary = {}) -> CharacterAttributesData` takes stat keys plus `&"armor"` and `&"ward"`.
- Derived values, the one home every caller uses:
  - `get_max_health()` (Body × 10), `get_max_stamina()` (Agility × 5), `get_max_madra()` (Mind × 10) and `get_stamina_regen()` (Agility × 0.1 per second).
  - `get_dodge_chance()`, `get_madra_cost_cut()` and `get_cooldown_cut()`, all from `static func flattening_curve(points_above_baseline: float, ceiling: float, half_point: float) -> float`. That function returns `ceiling * x / (x + half_point)` with `x = maxf(0.0, points_above_baseline)`, and each of the three is 0 at Lv 1.
  - Starting constants: `STAT_BASELINE = 10.0`, `DODGE_CEILING = 0.35`, `DODGE_HALF_POINT = 15.0`, `MADRA_COST_CUT_CEILING = 0.5`, `MADRA_COST_CUT_HALF_POINT = 20.0`, `COOLDOWN_CUT_CEILING = 0.4`, `COOLDOWN_CUT_HALF_POINT = 20.0`.

**Player progress**
- `StatTrainingData` (`scripts/resource_definitions/character/stat_training_data.gd`): `levels: Dictionary[StringName, int]` and `xp: Dictionary[StringName, float]`, keyed by stat key. Functions: `new_default()`, `get_level(stat)` (1 when missing), `set_level(stat, level)`, `get_xp(stat)` and `set_xp(stat, value)`.
- `StatProgressionData` (`scripts/resource_definitions/character/stat_progression_data.gd`, instance `resources/character/stat_progression.tres`): `xp_to_level_two = 100.0`, `xp_growth = 1.25` and `value_per_level = 1.0`. Functions: `get_xp_to_next(level) -> float` and `get_value_for_level(level) -> float` (Lv 1 gives 10.0).
- `AdvancementStageResource.stat_level_cap: int` (Foundation 10, Copper 20), read live through `CultivationManager.get_stat_level_cap() -> int`.
- `SaveGameData.stat_training: StatTrainingData`, never null: `SaveGameData.new()` carries an empty record (every read gives Lv 1 and 0 XP; the first write adds the key), and `new_current()` seeds `StatTrainingData.new_default()`. `CURRENT_VERSION = 2`. `character_attributes` stays as the legacy version-1 field, read once by `_migrate_to_v2()`.

**`CharacterManager`**
- Signals: `stats_changed`, `stat_xp_changed(stat, xp: float, xp_to_next: float)` and `stat_level_changed(stat, level: int)`. `base_attribute_changed` is removed.
- Level and XP: `get_stat_level(stat) -> int`, `get_stat_xp(stat) -> float`, `get_stat_xp_to_next(stat) -> float`, `get_stat_level_cap() -> int`, `is_stat_capped(stat) -> bool`, `add_stat_xp(stat, amount: float) -> void`, `add_stat_levels(stat, count: int) -> void`, and `set_stat_level(stat, level: int, xp: float = 0.0) -> void` (dev).
- Signals, as Task 1.3 fires them: `add_stat_xp()` and `add_stat_levels()` emit one `stat_level_changed` and one player log line per level gained, `stat_xp_changed` once per call, and `stats_changed` once per call only when a level changed. `set_stat_level()` emits each signal once and logs nothing. A save reset emits `stats_changed` only.
- `@export var stat_progression: StatProgressionData` (preloads `res://resources/character/stat_progression.tres`) is the level curve's one holder: a level's value is `CharacterManager.stat_progression.get_value_for_level(level)`, and no other script preloads the curve.
- Values and totals: `get_trained_value(stat) -> float`, `get_trained_values() -> Dictionary`, `get_gear_bonus(stat) -> float`, `get_stat(stat: StatModifierData.Stat) -> float`, and `get_total_attributes_data() -> CharacterAttributesData` (which also carries armor and Ward).
- `StatModifierData.Stat` (runtime only): `STRENGTH, BODY, AGILITY, SPIRIT, MIND, CONTROL, MAX_HEALTH, MAX_STAMINA, MAX_MADRA, ARMOR, WARD, STAMINA_REGEN, DODGE_CHANCE, MADRA_COST_CUT, COOLDOWN_CUT`.

**Gear** (`EquipmentDefinitionData`)
- Fields: `stat_percent_bonuses: Dictionary[StringName, float]` (0.10 is +10%), `stat_bonus_floor: int = 1`, `armor: float` and `ward: float`.
- `get_stat_bonus(stat, trained_value: float) -> float` returns `maxf(stat_bonus_floor, floorf(trained_value * percent))`, or 0 when the item has no percent for that stat. `get_stat_modifiers(trained_values: Dictionary) -> Array[StatModifierData]` returns FLAT modifiers.
- Text: `BookText.gear_bonus_lines(def, trained_values) -> Array[String]` gives "+10% Strength · +1 now", then "Armor 6", then "Ward 4".

**Combat**
- `CombatEffectData` keeps only `strength_scaling` and `spirit_scaling`.
- Defence: PHYSICAL uses the target's armor, SPIRIT its Ward, MIXED their average, and TRUE nothing. Damage is multiplied by `100 / (100 + defence)`.
- Dodge: `CombatEffectManager.try_dodge() -> bool` (player only, with an injectable `dodge_roll: Callable`, by default `func() -> float: return randf()`), plus `CombatantVisual.play_dodge()`.
- Control: `AbilityData.get_madra_cost(cost_cut := 0.0) -> float` (rounded), `get_cooldown(cooldown_cut := 0.0) -> float`, and `can_afford(vitals, cost_cut := 0.0)` / `consume_costs(vitals, cost_cut := 0.0)`. `CombatAbilityInstance.get_cost_cut()` and `get_cooldown_cut()` return the player's cuts, or 0 for anyone else.

**Display and the breakthrough**
- `StatDisplay` (`scripts/utils/stat_display.gd`): `PHYSICAL`, `SPIRITUAL`, `name_of(stat)`, `icon_of(stat)` and `side_name(stat)`.
- `TribulationActionData.can_attempt()` requires a full core plus Strength and Spirit at the cap, comparing trained levels. `static func get_missing_requirements(include_core: bool = true) -> Array[String]` lists what is still missing, in the order Core Density, Strength, Spirit ("Core Density 95 / 100", "Strength Lv 3 / 10"); `false` leaves the core out for screens whose rod already shows it.

**Dev tools**
- `DevCommands.set_stat_level(stat_key: StringName, level: int, xp: float = 0.0) -> String` and `DevCommands.raise_stat_to_cap(stat_key: StringName) -> String`, each returning "" or the refusal.
- `DevStepData.Kind.RAISE_STAT_TO_CAP = 13`.

**Phase 2**
- `ResourceManager.get_max_madra() -> float` replaces `get_adventure_madra_capacity()` and `get_adventure_madra_budget()`.
- The player's `VitalsManager` is a façade for Madra over `ResourceManager`.
- `ActionManager.start_adventure(action)` and `confirm_adventure_start(action)` lose the budget parameter.
- `AdventureResultData.madra_left` and `madra_max` replace `madra_spent`.

---

## Phase 1: Stats

**Goal:** six trained stats with levels, XP and the stage cap; what each stat does in a fight; armor and Ward; gear as floored percents; enemy values; the breakthrough's stat requirement; the version-2 save migration; dev tools; the stat screens (design, "Phase 1: Stats").

**Branch and PR:** `feat/game-stats-rework-e6a4b4`, this worktree's branch, which already holds the spec and this plan; one PR, opened in Task 1.17.

**Order:** tasks run in number order. Task 1.0's approval gates Tasks 1.8, 1.10, 1.13, 1.15 and 1.16; Tasks 1.1 to 1.7 need no approval and can start while the canvas is in review.

**Shared notes:** The `-s` test command imports nothing (TESTING.md). After a `class_name` script is added or deleted, `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --import` refreshes the class cache (Tasks 1.1 and 1.2 run it). It writes a `.gd.uid` beside each new script, committed with it, and `git status --short project.godot` must then print nothing (CLAUDE.md, the Dialogic patch). Tasks 1.1 to 1.5 give their tests as name, setup and assertions with their exact values and messages; the other tasks give them as GDScript. Table tests are `Array[Dictionary]` cases named in the assert message.

---

### Task 1.0: Phase 1 mock-ups

A design gate, not a TDD task: done when Lionel approves the canvas. Tasks 1.8, 1.10, 1.13, 1.15 and 1.16 build what it shows and start only after the approval; they fix the binding and the behaviour, the canvas the look and the copy.

**Files:**
- Create: the Design canvas "Stats rework · Phase 1" (a claude.ai artifact, not a repository file)
- Modify: `docs/superpowers/plans/2026-11-04-stats-rework.md` (this task's `Approved canvas:` line and the answers under it)

**Interfaces:**
- Consumes: the design's "Phase 1: Stats" Screens list, the starting numbers (Shared interfaces), the gear values Task 1.7 ships.
- Produces: the approved canvas link, an answer to each Step 4 question and the approved wording of board 10, recorded under this task.

Approved canvas: *(recorded in Step 6)*

- [ ] **Step 1: Read the rules and find the old pieces.** `docs/STYLE_GUIDE.md`: rule 14, "Pressed paper (the books)", K-Q1, rows K1, K10 and K11. `docs/UI_STYLING.md`: the book theme's pressed variants (`LabelBookCaps`, `LabelBookSeal`, `RichTextBookValue`, `PanelPressed`). Find the "Cultivator Stats" canvas (`Artifact` `action: "list"`, `type: "Design"`) and reuse its pieces (stat cells, XP beads, the Character book spread), not its eight stats or its numbers.
- [ ] **Step 2: Start a new canvas.** `Artifact` `action: "quickstart"` with `intent: "design"`, then publish from the Design type's `type_url` with `title: "Stats rework · Phase 1"`. Never add boards to "Cultivator Stats" or "Body Refining" (one canvas per topic). Expected: an empty private canvas and its link.
- [ ] **Step 3: Draw one board per screen, in these states.** The numbers: Lv 1 is 10 points and each level adds 1; Lv 2 costs 100 XP and each later level 1.25× the last; the cap is 10 in Foundation, 20 in Copper. Health = Body × 10, Stamina = Agility × 5 (regen Agility × 0.1 a second), Madra = Mind × 10: 100 / 50 / 1.0 / 100 at Lv 1. Dodge is 8.8% at Agility Lv 6; at Control Lv 6 techniques cost 10% less Madra and cooldowns are 8% shorter. Basic Strike 25, Empty Palm 28, Power Font 50. Task 1.7's gear at Lv 1: Iron Shortsword "+50% Strength · +5 now", "+10% Agility · +2 now"; Reinforced Robes "+40% Body · +4 now", "Armor 6"; Cultivator's Cowl "+15% Spirit · +1 now", "Ward 4".
  1. **Character book, left page** (`CharacterView`, `AttributeTile`): Physical (Strength, Body, Agility), Spiritual (Spirit, Mind, Control); a tile shows an icon, the name, "Lv N", an XP bar and the total. States: a new character (all Lv 1); Spirit Lv 6, bar part-filled; Spirit at the cap; Strength at the cap with the Iron Shortsword lifting its total past it (Lv 10, total 28); the selected tile and the hover.
  2. **A stat's detail page:** Lv N / cap, the XP figure, a description, what it does now → next, where it comes from, what trains it. States: Body (Max Health 100 → 110); Agility (Max Stamina, Stamina regen, Dodge chance); Control (Technique cost cut, Cooldown cut); Spirit Lv 6 wearing the cowl (Trained (Lv 6) 15, Gear +2), trained by the Aura Well; Strength ("Nothing trains this yet"); a capped stat (no next column); a long description wrapping.
  3. **The "In a fight" block:** Health, Madra, Stamina, Dodge chance, Technique cost cut, Cooldown cut, Armor, Ward; for a new character, and wearing the robes and the cowl (Health 140, Armor 6, Ward 4).
  4. **Gear text** in `EquipmentDetails`, `ItemDescriptionPanel` (the item tooltip's fixed 424×264 panel must hold the longest item uncut) and `MerchantStockRow` (its separators between bonuses): the three items, a long line wrapping, and the robes' slot word (BODY in the book, Armor in the tooltip and the shop) beside "Armor 6".
  5. **Goals board milestone** (`GoalsPanel`): "Raise Core Density to 100" over "Strength Lv 1 / 10" and "Spirit Lv 4 / 10"; a full core with Strength short; everything met, "Face the Tribulation".
  6. **Tribulation card** (`TribulationPresenter`): core 95 with the stats short (TRIAL); core 100 with Strength short (TRIAL, with a second line); ready (ENTER); and the refusal log line, naming every missing requirement.
  7. **Abilities book breakdown:** Basic Strike "25" = "10 base" plus one Strength part, "+15".
  8. **Zone view:** the cultivator cabinet with and without the six stats.
  9. **"Dodged" floater** over the player in a fight (`CombatantVisual.play_dodge()`, Task 1.10; its colour defaults to `ThemeConstants.LACQUER_STAMINA`) and its log line "[b]Player[/b] dodged <ability name>".
  10. **Breakthrough copy** the stat requirement makes false, today's text beside Claude's proposal:
      - `CultivationManager.CORE_FULL_LOG`: "Your core is full. With Strength and Spirit at the cap, the Tribulation waits in Spirit Valley."
      - `foundation_tribulation.tres` `intro_text`: "Your core is full, your Strength and Spirit at their peak. Breathe with the aura as it gathers, and let it pour into you."
      - `tribulation_action.tres` `description`: "With a full core and Strength and Spirit at the cap, face the Tribulation and break through to Copper."
      - the `tribulation_ready` preset's `description`: "Every quest done, the core full, Strength and Spirit at the cap. The Tribulation waits."
- [ ] **Step 4: Put the open look questions on a board of their own,** each with Claude's recommendation:
  - The Character book's pages: pressed paper (K-Q1) or today's book cards? Recommend pressed paper: `TableRow` rows, a `LabelBookSeal` seal.
  - Stats on the zone view too? The cabinet is a fixed 444×256 board: new `_ai` art, and the Goals board moves (`ZoneViewState.GOALS_POSITION`). Recommend not in phase 1; revisit in phase 3, when cycling's stat XP pellets need a target. If Lionel wants them in phase 1, add a task between Tasks 1.16 and 1.17 that builds them (`CultivatorPlate` and its scene, new `_ai` board art, `ZoneViewState.GOALS_POSITION`, and a test in `test_cultivator_plate.gd`); otherwise Task 3.0 asks again.
  - How the cap shows (a word seal, a full bar, or both), and the seal's word (never "minor")? Recommend both.
  - A stat's detail on the right page (pointing, as today) or a page of its own (`BookFrame.turn_page()`, as in the Path and Inventory books)? Recommend the right page, if it fits uncut.
  - Mind's icon: today's `foundation_icon.png` or a new `mind_icon_ai.png`? Recommend `foundation_icon.png`.
  - The tile's big number: the level, the total, or both? Recommend the level big, the total small.
  - "In a fight": under the two sides on the left page, or on the right page before a stat is pointed at? Recommend under the sides.
  - The XP bar on paper: a `LacquerRod` with new pressed `_ai` textures, or the lacquer jade rod? Recommend new pressed `_ai` textures.
  - Trainers the player hasn't found yet: `trainer_names()` lists every training action in the content, so the Aura Well shows under Spirit before the player reaches it. Recommend listing it anyway, as a pointer to what to look for. Hiding it means Task 1.16 keeps only actions that some zone's `ZoneManager.get_available_actions()` returns.
  - The next-level preview adds one level's value to today's total and keeps every bonus as it is, so where a floored gear percent would step up at the next level it reads one point low. Recommend accepting that in phase 1: exact figures need a "total at a given level" read in `CharacterManager`.
- [ ] **Step 5: Show Lionel and iterate until he approves.** Send the link and the questions, read his canvas comments (`ArtifactComments`) and replies, revise and show again. Expected: in chat, Lionel approves the canvas, answers every question and approves board 10's wording. Only his own message counts.
- [ ] **Step 6: Record the approval and commit.** Replace the `Approved canvas:` line with `Approved canvas: <link> (Lionel, <date>)`, then add a line per question with its answer and a line per board 10 item with its approved wording. `git add docs/superpowers/plans/2026-11-04-stats-rework.md`, then `git commit -m "docs(stats): record the approved phase 1 mock-ups"` (+ Co-Authored-By line).

---

### Task 1.1: The six-stat combat block

Before Step 1, invoke `godot-prompter:resource-pattern` and `godot-prompter:godot-testing`.

**Files:**
- Modify: `scripts/resource_definitions/character/character_attributes_data.gd`, `scripts/resource_definitions/character/stat_modifier_data.gd`, `scripts/resource_definitions/combat/combat_effect_data.gd`, `scripts/resource_definitions/effects/change_vitals_effect_data.gd`.
- Modify (renamed keys, stale int keys): `resources/abilities/power_font.tres`, `resources/adventure/encounters/shallow_woods/special_encounters/aura_well_encounter.tres`, `resources/combat/combatant_data/starving_dreadbeast.tres`, `resources/combat/combatant_data/ravenous_dreadbeast.tres`, `resources/items/equipment/spirit_valley/cultivators_cowl.tres`, `resources/items/equipment/spirit_valley/reinforced_robes.tres`.
- Modify (interim, until Tasks 1.15 and 1.16): `scenes/abilities/abilities_view.gd`, `scenes/character/character_view.gd`, `scenes/character/character_view.tscn`.
- Delete (unused, and they stop parsing once the old fields go): `scenes/abilities/ability_stats_display/`, `scenes/abilities/stat_label/`, `scenes/abilities/stat_tooltip/`.
- Test: `tests/unit/test_character_attributes_data.gd` (rewritten), `tests/unit/test_combat_damage.gd`, `tests/unit/test_stat_modifier_stack.gd`, and the 20 files of Step 7.
- Checked, no edit (they read `AttributeType` through `values()`, `keys()` or `find_key()`, or store only ints 0–5): `character_manager.gd`, `dev_commands.gd`, `player_tab.gd`, `unlock_condition_data.gd` (its content file stores 1, BODY), `award_attribute_effect_data.gd` (the Aura Well stores 3, SPIRIT), `buff_effect_data.gd`, `combat_buff_manager.gd`, `combat_ability_instance.gd` (its `_get_modified_attributes()` copy is only the caster's offence, so it needs no armor or Ward), `path_node_effect_data.gd` and `path_details_card.gd` (no `.tres` stores `attribute_type`), `equipment_definition_data.gd`, `book_text.gd`, `items_md_parser.gd`, `attribute_tile.gd` (its STRENGTH default stays for StrengthTile).
- Never run `scripts/tools/items_md_to_resources.gd` before Task 1.7 rewrites the stat words in `docs/inventory/ITEMS.md`.

**Interfaces:**
- Consumes: none.
- Produces:
  - `CharacterAttributesData`: `AttributeType { STRENGTH = 0, BODY = 1, AGILITY = 2, SPIRIT = 3, MIND = 4, CONTROL = 5 }`; `strength/body/agility/spirit/mind/control: float = 10.0`, `armor: float = 0.0`, `ward: float = 0.0`; `static func make(values: Dictionary = {}) -> CharacterAttributesData`; `static func stat_key(stat: AttributeType) -> StringName`; `static func stat_from_key(key: StringName) -> int`; `get_attribute(stat: AttributeType) -> float`; `set_attribute(stat: AttributeType, value: float) -> void`; `get_max_health()`, `get_max_stamina()`, `get_max_madra()`, `get_stamina_regen()`, `get_dodge_chance()`, `get_madra_cost_cut()`, `get_cooldown_cut()`, each `-> float`; `static func flattening_curve(points_above_baseline: float, ceiling: float, half_point: float) -> float`.
  - Its `float` constants (starting values): `STAT_BASELINE = 10.0` (Lv 1), `HEALTH_PER_BODY = 10.0`, `STAMINA_PER_AGILITY = 5.0`, `MADRA_PER_MIND = 10.0`, `STAMINA_REGEN_PER_AGILITY = 0.1`, `DODGE_CEILING = 0.35`, `DODGE_HALF_POINT = 15.0`, `MADRA_COST_CUT_CEILING = 0.5`, `MADRA_COST_CUT_HALF_POINT = 20.0`, `COOLDOWN_CUT_CEILING = 0.4`, `COOLDOWN_CUT_HALF_POINT = 20.0`.
  - `StatModifierData.Stat { STRENGTH, BODY, AGILITY, SPIRIT, MIND, CONTROL, MAX_HEALTH, MAX_STAMINA, MAX_MADRA, ARMOR, WARD, STAMINA_REGEN, DODGE_CHANCE, MADRA_COST_CUT, COOLDOWN_CUT }`.
  - `CombatEffectData.calculate_damage()` defended by armor or Ward; `CombatEffectData.mind_scaling` (Task 1.9 removes it); `ChangeVitalsEffectData.mind_madra_multiplier`.

- [ ] **Step 1: Write the failing tests.**
  `tests/unit/test_character_attributes_data.gd`, a whole new file. Header doc: "Unit tests for CharacterAttributesData, a combatant's stat block: the ints AttributeType is stored as, the stat keys, make(), and the derived formulas (Health, Stamina, regen, Madra, dodge, Control's cuts) the game reads." It has `const AttributeType = CharacterAttributesData.AttributeType`, `const KEYS: Array[StringName] = [&"strength", &"body", &"agility", &"spirit", &"mind", &"control"]`, and `_derived(block) -> Dictionary`, the seven derived values under `max_health`, `max_stamina`, `stamina_regen`, `max_madra`, `dodge_chance`, `madra_cost_cut` and `cooldown_cut`.
  - `test_attribute_type_ints_never_change`: `AttributeType` equals `{"STRENGTH": 0, "BODY": 1, "AGILITY": 2, "SPIRIT": 3, "MIND": 4, "CONTROL": 5}`, "a stat is stored as an int: append only".
  - `test_each_stat_has_a_key`: for each stat, `stat_key(stat) == KEYS[stat]` and `stat_from_key(KEYS[stat]) == stat`; `stat_from_key()` of `&"foundation"`, `&"armor"` and `&""` is -1.
  - `test_make_sets_each_named_stat`: for each stat, `make({KEYS[stat]: 15.0})` reads 15.0 there and `STAT_BASELINE` in the other five.
  - `test_armor_and_ward_start_at_zero_and_make_sets_them`: `make()` has armor and Ward 0.0; `make({&"armor": 6.0, &"ward": 4.0})` has 6.0 and 4.0.
  - `test_make_skips_an_unknown_key`: `make({&"foundation": 50.0}).mind == STAT_BASELINE`.
  - `test_set_attribute_writes_the_stat`: `set_attribute(AttributeType.MIND, 14.0)` makes `mind` 14.0.
  - `test_a_level_one_block_keeps_todays_numbers`: `_derived(make())` is max_health 100.0, max_stamina 50.0, stamina_regen 1.0, max_madra 100.0, and 0.0 for dodge_chance and both cuts.
  - `test_each_derived_value_reads_only_its_stat`: against `_derived(make())`, `make({key: 15.0})` raises (`assert_gt`) exactly these and leaves (`assert_eq`) the rest: body → max_health; agility → max_stamina, stamina_regen, dodge_chance; mind → max_madra; control → madra_cost_cut, cooldown_cut; strength and spirit → none.
  - `test_flattening_curve`, within 0.000001, (points, ceiling, half_point) → expected: "no points" (0.0, 0.35, 15.0) → 0.0; "below the baseline" (-5.0, 0.35, 15.0) → 0.0; "a third of the half point" (5.0, 0.35, 15.0) → 0.0875; "the half point gives half" (15.0, 0.35, 15.0) → 0.175; "far past it, just under" (1000000.0, 0.4, 20.0) → 0.399992.
  - `test_curves_stay_under_their_ceilings`: in `make({&"agility": 100000.0, &"control": 100000.0})`, dodge, the Madra cost cut and the cooldown cut each stay below their ceiling constant ("%s stays under its ceiling") and above 0.99 × it ("%s comes close").

  In `tests/unit/test_combat_damage.gd`:
  - Add `const DamageType = CombatEffectData.DamageType`. `test_damage_type_picks_its_defense` becomes a table over the fixture's `_effect` (base 50) and `_caster`, each case's target `CharacterAttributesData.make(case.target)`, within 0.01, with the doc "calculate_damage() cuts the value by 100 / (100 + defence): Physical reads the target's armor, Spirit its Ward, Mixed their average, True neither. The target's own Spirit no longer defends.": "physical, armor 10" → 50 × 100 / 110; "physical, armor 100 halves" (and Ward 30) → 25.0; "physical ignores Ward" (Ward 100) → 50.0; "spirit, Ward 10" → 50 × 100 / 110; "spirit ignores armor and the target's Spirit" (armor 100, Spirit 200) → 50.0; "mixed, armor 20 and Ward 40" → 50 × 100 / 130; "true ignores both" (armor and Ward 100) → 50.0.
  - `before_each` builds `_caster` and `_target` with `make()`. `test_value_adds_each_attribute_times_its_scaling` drops "resilience" and "willpower", its "foundation" case becomes `{"name": "mind", "base": 50.0, "scaling": {"mind_scaling": 1.0}, "expected": 60.0}`, "strength at 50" takes the caster `make({&"strength": 50.0})`, and its doc says "six". `test_high_defense_doesnt_go_negative` uses `make({&"armor": 10000.0})`.

  In `tests/unit/test_stat_modifier_stack.gd`, `test_derived_vitals_are_not_attributes` becomes `test_derived_stats_are_not_attributes`: `attribute_of()` is -1 ("%s is not an attribute") for MAX_HEALTH, MAX_STAMINA, MAX_MADRA, ARMOR, WARD, STAMINA_REGEN, DODGE_CHANCE, MADRA_COST_CUT and COOLDOWN_CUT.

- [ ] **Step 2: Run them and see them fail.**
  `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/unit/test_character_attributes_data.gd,res://tests/unit/test_combat_damage.gd,res://tests/unit/test_stat_modifier_stack.gd -gexit`
  Expected: FAIL: the three scripts don't parse (no `make`, `AttributeType.MIND` or `Stat.ARMOR`), so GUT runs none of their tests and can still exit 0.

- [ ] **Step 3: Rewrite `CharacterAttributesData`.**
  - Class doc: "The stat block of one combatant: an enemy's authored block, or the player's fight snapshot from `CharacterManager.get_total_attributes_data()`. It is not the player's saved progress. Old saves and the enemy `.tres` files name this script by path, so never move or rename it."
  - Delete the 8-argument `_init()`, `foundation`, `resilience`, `willpower`, `STAMINA_PER_BODY` and `MADRA_PER_FOUNDATION`. `add_to_attribute()` stays until Task 1.3.
  - The enum's comment: "stored as ints: append only (MIND was FOUNDATION, int 4)". Value docs: STRENGTH "Physical technique damage", BODY "Max Health", AGILITY "Max Stamina, Stamina regen and dodge", SPIRIT "Spirit technique damage", MIND "Max Madra", CONTROL "Cheaper techniques and shorter cooldowns". `armor`: "Cuts physical damage taken." `ward`: "Cuts Spirit damage taken."
  - Max Health = body × `HEALTH_PER_BODY`, max Stamina = agility × `STAMINA_PER_AGILITY`, regen = agility × `STAMINA_REGEN_PER_AGILITY` a second, max Madra = mind × `MADRA_PER_MIND`. Dodge = `flattening_curve(agility - STAT_BASELINE, DODGE_CEILING, DODGE_HALF_POINT)`; each cut is the same curve over `control - STAT_BASELINE` with its own ceiling and half point. `flattening_curve()` = `ceiling * x / (x + half_point)`, `x = maxf(0.0, points_above_baseline)`.
  - `make()` starts from `new()`, sets `&"armor"` and `&"ward"` directly and each stat key through `set_attribute(stat_from_key(key), value)`; an unknown key logs `Log.error` and is skipped. `stat_key()` is the enum key in lower case (`&""` and a `Log.error` for no stat); `stat_from_key()` returns the stat with that key, else -1. `get_attribute()` and `set_attribute()` keep six match arms. `_to_string()` prints the six stats, armor and Ward.

- [ ] **Step 4: Reshape `StatModifierData.Stat`** to the Interfaces' list (runtime only, so its ints are free). Enum doc: "the six stats (named as in AttributeType and mapped to it by name), then the derived stats". New members' docs: armor and Ward come from gear, regen is per second, dodge and the cuts are fractions 0..1. `for_attribute()` and `attribute_of()` stay.

- [ ] **Step 5: Switch `CombatEffectData` to armor and Ward.**
  - Delete `resilience_scaling` and `willpower_scaling`. Rename `foundation_scaling` to `mind_scaling` ("Scales with caster's Mind"); in `power_font.tres` (`Resource_damage`), `foundation_scaling = 0.5` becomes `mind_scaling = 0.5`. `get_scaling()` has six arms.
  - `calculate_damage()`'s defence: PHYSICAL `target_attributes.armor`, SPIRIT `target_attributes.ward`, MIXED `(armor + ward) / 2.0`, TRUE none. The `damage * (100.0 / (100.0 + defence))` line and the null-target branch stay; the log names become "Armor", "Ward" and "Mixed (Armor+Ward)/2".
  - `DamageType` docs: PHYSICAL "Cut by the target's armor", SPIRIT "Cut by the target's Ward", MIXED "Cut by the average of armor and Ward".

- [ ] **Step 6: Update the other references and delete the dead scripts.**

  | File | Change |
  |---|---|
  | `change_vitals_effect_data.gd` | `foundation_madra_multiplier` becomes `mind_madra_multiplier` ("Multiplies the character's MIND"); `get_final_madra_change()` reads `AttributeType.MIND`, `describe()` prints `"%s%% Mind as Madra"`, `_to_string()` `MindMadraMul`. |
  | `aura_well_encounter.tres` | In `Resource_rest_effect`, `foundation_madra_multiplier = 2.0` becomes `mind_madra_multiplier = 2.0`. |
  | `starving_dreadbeast.tres`, `ravenous_dreadbeast.tres` | `foundation = 12.0` becomes `mind = 12.0` (the loader would silently drop the old key). Task 1.9 writes the other stats, armor and Ward. |
  | `cultivators_cowl.tres` | `attribute_bonuses = { 3: 1.0 }`, dropping `7: 3.0`, which would index past the enum. |
  | `reinforced_robes.tres` | `attribute_bonuses = { 1: 4.0 }`, dropping `6: 2.0`. `leeching_ring.tres` keeps `4: 2.0`, now Mind. |
  | `abilities_view.gd` | `_ATTRIBUTE_ICONS` loses RESILIENCE and WILLPOWER; FOUNDATION becomes MIND, keeping `foundation_icon.png`. |
  | `character_view.gd` | `ATTRIBUTE_DETAILS` loses RESILIENCE and WILLPOWER. BODY: "Physical constitution. Determines your Health.", `["Max Health = Body × %d" % CharacterAttributesData.HEALTH_PER_BODY]`. AGILITY: "Speed and footwork. Determines your Stamina.", `["Max Stamina = Agility × %d" % CharacterAttributesData.STAMINA_PER_AGILITY]`. SPIRIT: "Spiritual awareness and power. Scales Madra-based abilities.", `[]`. FOUNDATION becomes MIND, keeping its description, with `["Max Madra = Mind × %d" % CharacterAttributesData.MADRA_PER_MIND]`. The class doc says "six". |
  | `character_view.tscn` | Delete `ResilienceTile`, `WillpowerTile` and their ext_resources `7_res` and `11_wil`. `FoundationTile` becomes `MindTile`, `attribute_name = "Mind"`, keeping `attribute_type = 4` and `icon_texture = ExtResource("9_fnd")`. Both grids keep `columns = 4` until Task 1.16. |
  | Dead scripts | `git rm -r scenes/abilities/ability_stats_display scenes/abilities/stat_label scenes/abilities/stat_tooltip` |

- [ ] **Step 7: Move the remaining tests to `make()` and the new names.**
  `CharacterAttributesData.new()` with all eight positional values at 10.0 becomes `make()` at `test_combat_effect_types.gd:37`, `test_award_attribute_effect_data.gd:9`, `test_player_vitals_manager.gd:29`, `test_resource_manager.gd:35`, `test_training_flow.gd:23`, `test_adventure_flow.gd:36`, `test_power_font_buff_strip.gd:30` and `test_empty_palm_interrupt.gd:43`. Then:

  | Test file | Change |
  |---|---|
  | `test_combat_effect_data.gd` | The field list sets `strength_scaling` 1, body 2, agility 3, spirit 4, `mind_scaling` 5 and `control_scaling` 6 (no resilience or willpower), so each stat still reads `attribute + 1`; the unset case reads CONTROL; the breakdown test uses `mind_scaling = 0.5` and `make({&"strength": 17.0, &"body": 16.0, &"agility": 14.0, &"spirit": 11.0, &"mind": 12.0, &"control": 12.0})`. |
  | `test_character_manager.gd` | The fixture's `_attributes` and `_save.character_attributes` use `make()`. Delete `test_custom_attribute_values` and `test_attribute_count`. `test_totals_equal_base_with_nothing_equipped` uses `make({&"strength": 5.0, &"body": 15.0, &"agility": 20.0, &"spirit": 8.0, &"mind": 12.0, &"control": 3.0})` and expects those values. `test_each_attribute_receives_its_own_bonus` keeps six entries (MIND 5.0 gives 15.0); `test_equip_and_unequip_accessory_updates_totals` uses MIND. |
  | `test_change_vitals_effect_data.gd` | Foundation becomes Mind: `attrs.mind`, `mind_madra_multiplier`, the keys `"mind"` and `"mind_mult"`, the case names. |
  | `test_player_vitals_manager.gd` | `test_equipping_body_gear_raises_max_health_and_stamina` becomes `test_equipping_body_gear_raises_max_health`, without `max_stamina`. New `test_equipping_agility_gear_raises_max_stamina`: `{AttributeType.AGILITY: 4.0}` gives `_vitals.max_stamina == 70.0`, "14 Agility x 5". The Foundation accessory test becomes `test_equipping_a_mind_accessory_raises_max_madra`: `{AttributeType.MIND: 2.0}` gives 120.0, "12 Mind x 10". |
  | `test_resource_manager.gd` | Line 324: `_save.character_attributes.mind = 12.0`, in the test renamed `test_adventure_capacity_follows_mind_not_stage_cap`. |
  | `test_save_round_trip.gd` | Line 52: `make({&"strength": 12.0, &"body": 13.0, &"agility": 14.0, &"spirit": 15.0, &"mind": 16.0, &"control": 17.0, &"armor": 18.0, &"ward": 19.0})`, no field at its default. |
  | `test_technique_slot_math.gd` | Line 105: `make({&"strength": 13.0, &"agility": 7.0})`; the precondition of 27 holds. |
  | `test_fight_rules.gd` | Line 102: `make({&"strength": 99.0, &"body": 7.5, &"agility": 99.0, &"spirit": 99.0, &"mind": 99.0, &"control": 99.0})`. |
  | `test_equipment.gd` | Line 67 expects 6, "all six stats"; line 105 uses MIND; lines 146 and 154 use SPIRIT for RESILIENCE (`Stat.SPIRIT` is 2.0). |
  | `test_book_text.gd` | WILLPOWER 1.5 becomes CONTROL 1.5: `["+4 Strength", "-2 Body", "+1.5 Control"]`, comment "Strength, Body, Control". |
  | `test_items_md_parser.gd` | The negative case is `"CONTROL-2"` → `{AT.CONTROL: -2.0}`; the section markdown's `WILLPOWER+1` becomes `MIND+1`. |
  | `test_adventure_flow.gd` | The stat Foundation becomes Mind (the stage keeps its name): `MIND_BONUS`, `_set_mind()`, `_equip_mind_helmet()`, `test_higher_mind_raises_threshold`, `test_higher_mind_raises_budget_ceiling`, `test_equipment_mind_bonus_raises_capacity`, the header doc, the section header and the messages. Lines 184–185: `var total := CharacterAttributesData.make({&"mind": _save.character_attributes.mind + MIND_BONUS})`. |
  | `test_power_font_buff_strip.gd` | Line 36: `make({&"mind": 20.0})`; line 52 uses BODY for RESILIENCE. |
  | `test_empty_palm_interrupt.gd` | Line 49: `make({&"mind": 15.0})`. |
  | `test_character_book.gd` | `"WillpowerTile"` becomes `"MindTile"` and WILLPOWER becomes MIND (`test_values_come_from_character_manager`, `test_opening_shows_strength`). |
  | `test_vitals_plate.gd` | Line 388 uses MIND. |
  | `test_zone_action_cards.gd` | `_equip_foundation_ring(foundation)` becomes `_equip_mind_ring(mind)` with MIND; the comments at lines 100 and 313–314 say Mind. |

- [ ] **Step 8: Refresh the class cache** with the shared notes' `--import`. Expected: no parse errors; `git status --short project.godot` prints nothing.

- [ ] **Step 9: Run the Step 2 command, then `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_tests.ps1`.** Expected: PASS for both, with no script running zero tests.

- [ ] **Step 10: Commit** the Modify files and the 23 test files by name (`git rm` staged the deletions): `git commit -m "refactor(stats): six stats with armor and Ward"`. Body: "Mind replaces Foundation in place (int 4); Resilience and Willpower leave the end of the enum. The stat block gains armor, Ward and the derived formulas: Stamina comes from Agility, armor cuts physical damage, Ward cuts Spirit damage and Mixed takes their average. The unused stat-pill scripts no longer parse, so they go." (+ Co-Authored-By line)

---

### Task 1.2: The training record, the level curve and the stage cap

Before Step 1, invoke `godot-prompter:resource-pattern` and `godot-prompter:godot-testing`.

**Files:**
- Create: `scripts/resource_definitions/character/stat_training_data.gd`, `scripts/resource_definitions/character/stat_progression_data.gd`, `resources/character/stat_progression.tres` (a new folder).
- Modify: `scripts/resource_definitions/cycling/advancement_stage/advancement_stage.gd`, `resources/cycling/advancement_stages/foundation_advancement_stage/foundation_advancement_stage.tres`, `resources/cycling/advancement_stages/copper_advancement_stage/copper_advancement_stage.tres`, `singletons/cultivation_manager/cultivation_manager.gd`.
- Test: `tests/unit/test_stat_training_data.gd` (new), `tests/unit/test_stat_progression_data.gd` (new), `tests/unit/test_cultivation_manager.gd`, `tests/unit/test_foundation_tribulation_data.gd`.

**Interfaces:**
- Consumes: `CharacterAttributesData.stat_key()`, `AttributeType`, `STAT_BASELINE` (Task 1.1).
- Produces:
  - `StatTrainingData`: `levels: Dictionary[StringName, int]`, `xp: Dictionary[StringName, float]`, `static func new_default() -> StatTrainingData`, `get_level(stat: CharacterAttributesData.AttributeType) -> int`, `set_level(stat, level: int) -> void`, `get_xp(stat) -> float`, `set_xp(stat, value: float) -> void`.
  - `StatProgressionData`: `xp_to_level_two`, `xp_growth`, `value_per_level` (`float`), `get_xp_to_next(level: int) -> float`, `get_value_for_level(level: int) -> float`.
  - `AdvancementStageResource.stat_level_cap: int`; `CultivationManager.get_stat_level_cap() -> int`.

- [ ] **Step 1: Write the failing tests.**
  `tests/unit/test_stat_training_data.gd`, new, header doc "Unit tests for StatTrainingData, the player's saved training record: a level and the XP toward the next one for each stat, keyed by stat key.":
  - `test_new_default_writes_every_stat_at_level_one`: `new_default()` holds six levels and six XP entries ("one level and one XP per stat"), each stat key at level 1 ("%s starts at Lv 1") and XP 0.0 ("%s starts with no XP").
  - `test_a_missing_stat_reads_as_level_one_with_no_xp`: on `StatTrainingData.new()`, `get_level(SPIRIT)` is 1 and `get_xp(SPIRIT)` 0.0.
  - `test_set_level_and_xp_store_under_the_stat_key`: `set_level(MIND, 4)` and `set_xp(MIND, 12.5)` store 4 and 12.5 under `&"mind"`, and the getters read them back.

  `tests/unit/test_stat_progression_data.gd`, new, header doc "Unit tests for StatProgressionData: the XP each stat level costs and the value each level gives, on curves built here and on the shipped one.", with `_curve(xp_to_level_two: float, growth: float, value_per_level: float) -> StatProgressionData`:
  - `test_each_level_costs_more_than_the_last`: on `_curve(100.0, 1.25, 1.0)`, `get_xp_to_next()` of levels 1, 2 and 3 is 100.0, 125.0 and 156.25, within 0.0001 ("Lv %d to %d").
  - `test_value_for_level`, on `_curve(100.0, 1.25, per_level)`: "Lv 1 is the baseline" (1.0 a level, Lv 1) → `STAT_BASELINE`; "Lv 6 at 1 a level" → `STAT_BASELINE + 5.0`; "Lv 3 at 2 a level" → `STAT_BASELINE + 4.0`.
  - `test_the_shipped_curve_starts_at_the_baseline_and_grows`: `res://resources/character/stat_progression.tres` loads as a StatProgressionData ("%s loads as a StatProgressionData"; return if not), `get_value_for_level(1) == STAT_BASELINE`, and `get_xp_to_next(2) > get_xp_to_next(1)` ("each level costs more").

  In `tests/unit/test_cultivation_manager.gd`, a `# STAT LEVEL CAP` section:
  - `test_stat_level_cap_follows_the_current_stage` (doc: "The cap is read from the current stage each time, so the breakthrough raises it."): with `_stage_resource.stat_level_cap = 4` and `_with_copper()`'s stage at 9, the cap is 4 ("the stage's own cap"); `advance_to_next_stage()` is true ("precondition: the breakthrough lands"); then the cap is 9 ("Copper's cap once reached").
  - `test_no_stage_resource_means_no_stat_cap`: after `_use_stages()` with an empty typed array, the cap is 0.

  In `tests/unit/test_foundation_tribulation_data.gd`, under FOUNDATION TO COPPER (and "the breakthrough raising the stats' cap" in the header doc), `test_the_breakthrough_raises_the_stat_cap`: with `_load_stage(FOUNDATION_PATH)` and `_load_stage(COPPER_PATH)` (return if either is null), Foundation's cap is above 1 ("Foundation lets the stats grow past Lv 1") and Copper's above Foundation's ("Copper's cap is above Foundation's").

- [ ] **Step 2: Run them and see them fail.**
  `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/unit/test_stat_training_data.gd,res://tests/unit/test_stat_progression_data.gd,res://tests/unit/test_cultivation_manager.gd,res://tests/unit/test_foundation_tribulation_data.gd -gexit`
  Expected: FAIL: the scripts don't parse (no `StatTrainingData`, `StatProgressionData`, `stat_level_cap` or `get_stat_level_cap`).

- [ ] **Step 3: Create `StatTrainingData`** (`class_name StatTrainingData extends Resource`).
  - Doc: "The player's training record: a level and the XP toward the next level for each of the six stats, keyed by `CharacterAttributesData.stat_key()`. Saved as `SaveGameData.stat_training`; CharacterManager is its only reader and writer."
  - `@export var levels: Dictionary[StringName, int] = {}` and `@export var xp: Dictionary[StringName, float] = {}`. `get_level()` returns `levels.get(key, 1)`, `get_xp()` `xp.get(key, 0.0)`; the setters write under the key without clamping (CharacterManager enforces the rules); `new_default()` writes level 1 and XP 0.0 for every stat through them.

- [ ] **Step 4: Create `StatProgressionData`** (`class_name StatProgressionData extends Resource`) **and its instance.**
  - Doc: "How stat levels grow: the XP each level costs and the value each level gives. Lv 1 is `CharacterAttributesData.STAT_BASELINE`."
  - Exports `xp_to_level_two: float = 100.0`, `xp_growth: float = 1.25` and `value_per_level: float = 1.0` (starting values). `get_xp_to_next(level)` = `xp_to_level_two * pow(xp_growth, level - 1)`; `get_value_for_level(level)` = `CharacterAttributesData.STAT_BASELINE + (level - 1) * value_per_level`.
  - `resources/character/stat_progression.tres`, every value explicit:
  ```
  [gd_resource type="Resource" script_class="StatProgressionData" format=3]

  [ext_resource type="Script" path="res://scripts/resource_definitions/character/stat_progression_data.gd" id="1_curve"]

  [resource]
  script = ExtResource("1_curve")
  xp_to_level_two = 100.0
  xp_growth = 1.25
  value_per_level = 1.0
  ```

- [ ] **Step 5: Add the cap to the stages.** In `advancement_stage.gd`, after `max_core_density_level`: `## The highest level each of the six stats can be trained to in this stage. Training past it is lost; gear can still lift a total above it.` and `@export var stat_level_cap: int = 10`. Write `stat_level_cap = 10` in `foundation_advancement_stage.tres` after `core_xp_scaling_factor`, and `stat_level_cap = 20` in `copper_advancement_stage.tres` after `max_core_density_level` (starting values).

- [ ] **Step 6: Add `func get_stat_level_cap() -> int` to `cultivation_manager.gd`**, in PUBLIC LOGIC FUNCTIONS after `get_core_density_cap()`: `_get_current_stage_resource().stat_level_cap`, or 0 with no stage resource, read live like `get_core_density_cap()`. Doc: "The highest level the six stats can be trained to in the current stage. It is read from the stage each time, so the breakthrough raises it. 0 when there is no save or no stage resource."

- [ ] **Step 7: Register the class names** with the `--import`. Expected: `.gd.uid` files beside the two new scripts and the two new tests; `git status --short project.godot` prints nothing.

- [ ] **Step 8: Run the Step 2 command, then `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_tests.ps1`.** Expected: PASS for both.

- [ ] **Step 9: Commit** the files above and the four `.gd.uid` files by name: `git commit -m "feat(stats): add the training record and stage cap"`. Body: "Levels and XP get a saved record keyed by stat name, the level curve becomes data, and each stage gets a stat cap, read live so the breakthrough raises it with nothing stored." (+ Co-Authored-By line)

---

### Task 1.3: Train stats by level and XP up to the cap

Before Step 1, invoke `godot-prompter:save-load` (the versioned `.tres` save stays; CLAUDE.md overrides the skill's JSON advice) and `godot-prompter:godot-testing`.

**Files:**
- Modify: `singletons/persistence_manager/save_game_data.gd`, `singletons/character_manager/character_manager.gd`, `scripts/resource_definitions/character/character_attributes_data.gd`, `scripts/resource_definitions/effects/award_attribute_effect_data.gd`, `singletons/dev_manager/dev_commands.gd`, `scenes/abilities/abilities_view.gd`.
- Test: `tests/unit/test_character_manager.gd`, `tests/unit/test_award_attribute_effect_data.gd`, `tests/integration/test_dev_commands.gd`, `tests/integration/test_abilities_book.gd`, `tests/unit/test_save_migration.gd`, `tests/unit/test_save_round_trip.gd`; Step 6 moves `tests/unit/test_player_vitals_manager.gd`, `tests/unit/test_change_vitals_effect_data.gd`, `tests/unit/test_resource_manager.gd`, `tests/integration/test_training_flow.gd`, `tests/integration/test_adventure_flow.gd` to levels.

**Interfaces:**
- Consumes: `StatTrainingData`, `StatProgressionData`, `stat_progression.tres`, `CultivationManager.get_stat_level_cap()` (Task 1.2); `CharacterAttributesData.STAT_BASELINE` (Task 1.1).
- Produces:
  - `SaveGameData.stat_training: StatTrainingData`. `SaveGameData.new()` holds an empty record (never null) that reads Lv 1 and 0 XP everywhere and gains a key on its first write; `new_current()` holds `StatTrainingData.new_default()`.
  - `CharacterManager.stat_progression: StatProgressionData`, the curve's one holder: anything needing a level's value reads `CharacterManager.stat_progression.get_value_for_level(level)`.
  - Signals `stat_xp_changed(stat: AttributeType, xp: float, xp_to_next: float)` and `stat_level_changed(stat: AttributeType, level: int)`. `add_stat_xp()` and `add_stat_levels()` emit one `stat_level_changed` and one log line per level gained, `stat_xp_changed` once per call, and `stats_changed` once per call only when a level changed. `set_stat_level()` emits each signal once and logs nothing. A save reset emits `stats_changed` only.
  - `get_stat_level(stat) -> int`, `get_stat_xp(stat) -> float`, `get_stat_xp_to_next(stat) -> float`, `get_stat_level_cap() -> int`, `is_stat_capped(stat) -> bool`, `get_trained_value(stat) -> float`, `get_trained_values() -> Dictionary` (AttributeType → float), `add_stat_xp(stat, amount: float) -> void`, `add_stat_levels(stat, count: int) -> void`, `set_stat_level(stat, level: int, xp: float = 0.0) -> void`.
  - Removed: `base_attribute_changed`, `add_base_attribute()`, `CharacterAttributesData.add_to_attribute()`.

- [ ] **Step 1: Write the failing tests.**
  `tests/unit/test_character_manager.gd`'s fixture gains `const TEST_CAP: int = 5` and the vars `_original_stages` and `_original_progression`: `before_each` saves `CultivationManager.advancement_stage_resources` and `CharacterManager.stat_progression` (`after_each` restores both), installs one `AdvancementStageResource.new()` with `stat_level_cap = TEST_CAP` and the curve `StatProgressionData.new()` with `xp_to_level_two = 10.0`, `xp_growth = 2.0`, `value_per_level = 1.0` (levels cost 10, 20, 40, 80), and binds `SaveGameData.new_current()` with `save_data_reset`. Drop `_attributes` and the `_save.character_attributes` line; copy `_logged_lines_with(text)` from `test_cultivation_manager.gd`. New tests:
  - `test_a_new_save_starts_every_stat_at_level_one`: every stat is Lv 1 with 0.0 XP, a trained value of `STAT_BASELINE`, and not capped.
  - `test_levels_come_from_the_bound_save`: binding a `new_current()` save whose Spirit is Lv 6 (`save_data_reset`) gives `get_stat_level(SPIRIT) == 6` and `get_stat(Stat.SPIRIT) == 15.0` ("Lv 6 on the test curve").
  - `test_trained_values_list_every_stat`: with Strength Lv 3 and Mind Lv 2, `get_trained_values()` is `{STRENGTH: 12.0, BODY: 10.0, AGILITY: 10.0, SPIRIT: 10.0, MIND: 11.0, CONTROL: 10.0}`.
  - `test_capped_reads_the_trained_level_not_the_total` (doc: "The cap counts trained levels only: gear can lift the total past it."): Strength at `TEST_CAP - 1` with a FLAT +10 Strength under `TEST_SOURCE` is not capped ("gear does not cap it"); at `TEST_CAP` it is, and `get_stat_level_cap() == TEST_CAP`.
  - `test_stat_xp_buys_levels_and_keeps_the_remainder`, each case from Spirit Lv 1, XP → level, XP left: "5 of 10, short of Lv 2" 5.0 → 1, 5.0; "the exact cost of Lv 2" 10.0 → 2, 0.0; "Lv 2 and 3 over" 13.0 → 2, 3.0; "Lv 3 and 5 over" 35.0 → 3, 5.0.
  - `test_the_level_that_reaches_the_cap_drops_the_leftover`: 1000.0 Spirit XP gives Lv `TEST_CAP` with 0.0 XP.
  - `test_xp_at_the_cap_is_lost`: Spirit at `TEST_CAP` holding 3.0 XP gets 50.0 more; XP is 0.0 ("the 3 held and the 50 earned are both lost"), no `stat_level_changed`, and `stat_xp_changed` carries `[SPIRIT, 0.0, get_stat_xp_to_next(SPIRIT)]`.
  - `test_each_level_gained_signals_and_logs_once`: 35.0 Spirit XP emits `stat_level_changed` twice, `[SPIRIT, 2]` then `[SPIRIT, 3]`, and `stats_changed` once, and logs two lines containing "reached Lv" ("one log line a level").
  - `test_xp_alone_leaves_the_stats_alone`: 5.0 Spirit XP emits no `stats_changed`, and `stat_xp_changed` with `[SPIRIT, 5.0, 10.0]`.
  - `test_a_free_level_does_not_level`: with `CharacterManager.stat_progression.xp_to_level_two = 0.0`, 5.0 XP leaves Spirit at Lv 1.
  - `test_add_stat_levels_stops_at_the_cap`, Body from → plus → level: "two from Lv 1" 1, 2 → 3; "three from Lv 4 stop at the cap" 4, 3 → `TEST_CAP`; "none at the cap" `TEST_CAP`, 1 → `TEST_CAP`; "none past the cap" `TEST_CAP + 2`, 1 → `TEST_CAP + 2`.
  - `test_add_stat_levels_keeps_the_xp_until_the_cap`: Body Lv 2 holding 7.0 XP keeps 7.0 after one level, and has 0.0 after five more ("reaching the cap drops it").
  - `test_add_stat_levels_signals_each_level`: two Body levels emit `stat_level_changed` twice, `stat_xp_changed` once and `stats_changed` once.
  - `test_set_stat_level_sets_level_and_xp` (doc: "The dev setter: any level from 1, past the cap too, with its XP held inside the level, at most one point short of the next level's cost."), Agility (level, xp) → stored: "a level and XP" (3, 15.0) → (3, 15.0); "past the cap" (`TEST_CAP + 2`, 0.0) → unchanged; "below Lv 1" (0, 0.0) → (1, 0.0); "negative XP" (2, -4.0) → (2, 0.0); "XP at the cost of Lv 3 (20)" (2, 20.0) → (2, 19.0).
  - `test_set_stat_level_signals_once_and_logs_nothing`: `set_stat_level(AGILITY, 4, 5.0)` emits `stat_level_changed` `[AGILITY, 4]`, `stat_xp_changed` `[AGILITY, 5.0, 80.0]` and `stats_changed` once, and no `LogManager.message_logged` ("a dev set is no level reached").

  `tests/unit/test_award_attribute_effect_data.gd`: header doc "process() raises a stat by whole levels, up to the stage's cap". `before_each` swaps `CharacterManager.live_save_data` to `SaveGameData.new_current()` (no `character_attributes` line) and `CultivationManager.advancement_stage_resources` to one stage with `stat_level_cap = 5`; `after_each` restores both. `test_process_sets_effect_type` stays; `test_process_adds_amount_to_the_attribute` gives way to:
  - `test_process_raises_the_stat_by_whole_levels`: "the Aura Well's +1 Spirit" (SPIRIT, amount 1.0) → Lv 2; "+2 Body" (BODY, 2.0) → Lv 3.
  - `test_a_level_past_the_cap_is_lost`: with Spirit at Lv 5, a Spirit award at its default amount leaves Lv 5.

  `tests/integration/test_dev_commands.gd`: `test_add_attribute_adds_to_the_base_value` gives way to two tests, which Task 1.14 deletes with `add_attribute()`:
  - `test_add_attribute_adds_levels`: `DevCommands.add_attribute(STRENGTH, 5.0)` returns "" and Strength is Lv `mini(6, CharacterManager.get_stat_level_cap())`.
  - `test_add_attribute_does_nothing_at_the_cap`: with Strength at the cap, `add_attribute(STRENGTH, 1.0)` returns "" ("a capped stat is no failure"), the level stays at the cap, and `_dev_lines()` is empty ("nothing was done, so nothing is logged").

  `tests/integration/test_abilities_book.gd`, `test_a_stat_change_previews_damage_again` (a level can be gained while the book is open): `_add_counting_ability()`, `_view.select_ability(EXTRA_ID)`, `CharacterManager.stats_changed.emit()`, `_hover("enforce")`, `_hover(EXTRA_ID)`; then `effect.calls == 2` ("the preview is worked out again after a stat change").

  `tests/unit/test_save_migration.gd`: `test_reset_matches_a_fresh_save` also asserts the reset leaves a new `stat_training` (`assert_not_same` with the old one); new `test_a_new_save_holds_every_stat_at_level_one`: every stat key of `SaveGameData.new_current().stat_training` holds level 1 ("%s is written at Lv 1") and XP 0.0 ("%s is written with no XP").

  `tests/unit/test_save_round_trip.gd`'s `_full_save()`, after `character_attributes` (its "no field left at its default" guard fails as soon as the field exists):
  ```gdscript
  save.stat_training = StatTrainingData.new_default()
  save.stat_training.set_level(CharacterAttributesData.AttributeType.SPIRIT, 6)
  save.stat_training.set_xp(CharacterAttributesData.AttributeType.SPIRIT, 37.5)
  save.stat_training.set_level(CharacterAttributesData.AttributeType.STRENGTH, 3)
  ```

- [ ] **Step 2: Run them and see them fail.**
  `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/unit/test_character_manager.gd,res://tests/unit/test_award_attribute_effect_data.gd,res://tests/integration/test_dev_commands.gd,res://tests/integration/test_abilities_book.gd,res://tests/unit/test_save_migration.gd,res://tests/unit/test_save_round_trip.gd -gexit`
  Expected: FAIL. All but `test_abilities_book.gd` fail to parse (no `get_stat_level`, `set_stat_level`, `stat_progression` or `stat_training`); `test_a_stat_change_previews_damage_again` sees `calls` at 1, because the book still listens to `base_attribute_changed`.

- [ ] **Step 3: Add the record to `SaveGameData`.** In CHARACTER MANAGER, above `character_attributes`: `## The player's trained stats: a level and XP for each of the six. A stat missing from it reads as Lv 1.` and `@export var stat_training: StatTrainingData = StatTrainingData.new()`. `new_current()` also sets `save.stat_training = StatTrainingData.new_default()`, so every new save writes all six.

- [ ] **Step 4: Build the training API in `CharacterManager`.** It emits the signals as the Interfaces say.
  - `## The level curve: the XP each level costs and the value each level gives.` `@export var stat_progression: StatProgressionData = preload("res://resources/character/stat_progression.tres")`, and the two signals with `##` docs. Delete `base_attribute_changed` and `add_base_attribute()`. `_update_resources()` re-binds `live_save_data` and emits `stats_changed` once, with no per-attribute loop. The class doc and the `stats_changed` doc say "trained levels" for "base attributes".
  - Readers: `get_stat_level()` and `get_stat_xp()` read `live_save_data.stat_training`; `get_stat_xp_to_next(stat)` = `stat_progression.get_xp_to_next(get_stat_level(stat))`; `get_stat_level_cap()` = `CultivationManager.get_stat_level_cap()`; `is_stat_capped(stat)` = `get_stat_level(stat) >= get_stat_level_cap()`; `get_trained_value(stat)` = `stat_progression.get_value_for_level(get_stat_level(stat))`, and `get_trained_values()` maps the six stats to it. Those two never call `get_stat()`: Task 1.6's gear source calls them from inside it. `_get_base_stat()` keeps its three `MAX_*` arms; any other stat returns `get_trained_value(StatModifierData.attribute_of(stat))`.
  - `add_stat_xp(stat, amount)` follows `CultivationManager.add_core_density_xp()`: no save logs `Log.error`; a capped stat's XP becomes 0.0; otherwise the amount is added and each level the XP covers is paid for and raised, a cost of 0.0 or less logs `Log.error` and stops, and the level-up that reaches the cap sets the XP to 0.0 and stops.
  - `add_stat_levels(stat, count)` raises one level at a time to `maxi(level, mini(level + count, cap))` (levels past the cap are lost) and keeps the XP inside the level, unless the call reaches the cap, which sets it to 0.0.
  - One private helper raises a level for both: it writes the level, emits `stat_level_changed(stat, level)` and logs `LogManager.log_message("[b]%s[/b] reached Lv %d" % [get_attribute_display_name(stat), level])`.
  - `set_stat_level(stat, level, xp = 0.0)`, the dev setter, stores `maxi(level, 1)` (it may exceed the cap) and `minf(maxf(xp, 0.0), maxf(cost - 1.0, 0.0))`, `cost` being the new level's `get_xp_to_next()`.
  - Delete `add_to_attribute()` from `character_attributes_data.gd`; nothing calls it now.

- [ ] **Step 5: Point the callers at the new API.**
  - `award_attribute_effect_data.gd`: `process()` calls `CharacterManager.add_stat_levels(attribute_type, roundi(amount))` and its `Log.info` says "levels". Class doc: "Raises one stat by `amount` whole levels (the Aura Well's +1 Spirit per training level), up to the stage's cap; levels past the cap are lost." The field names stay: `aura_well_spirit_award_effect.tres` stores `attribute_type = 3`.
  - `dev_commands.gd`, until Task 1.14: `add_attribute()` keeps its stat check, returns `""` when `CharacterManager.is_stat_capped(attribute)`, else runs `_while_paused(CharacterManager.add_stat_levels.bind(attribute, roundi(amount)))` and returns `_succeed("Raised %s to Lv %d" % [CharacterManager.get_attribute_display_name(attribute), CharacterManager.get_stat_level(attribute)])`. Doc: "Adds whole levels to one stat, up to the stage's cap. Returns "" with nothing done at the cap. Refuses a value that is not a stat."
  - `abilities_view.gd`: `_ready()` connects `CharacterManager.stats_changed` to `_on_stats_changed() -> void`, the renamed `_on_base_attribute_changed` (same body; doc "A stat can change while the book is open."). The `_value_previews` doc says "whenever a stat changes".

- [ ] **Step 6: Move the tests that set base values through `save.character_attributes` to levels.**

  | Test file | Change |
  |---|---|
  | `test_character_manager.gd` | Delete `test_add_to_attribute_increases_value`, `test_add_to_multiple_attributes`, the three `test_add_base_attribute_*` tests and the section headers they empty. `test_totals_equal_base_with_nothing_equipped` sets STRENGTH 3, BODY 6, AGILITY 11, SPIRIT 1, MIND 4, CONTROL 2 with `set_stat_level()` and expects `STAT_BASELINE + level - 1` each. `test_equip_and_unequip_gear_updates_totals` checks `CharacterManager.get_trained_value(AttributeType.BODY) == 10.0` as the base. `test_a_listener_during_save_reset_sees_the_new_saves_gear` drops `next_save.character_attributes`. The header doc names the training API for `add_base_attribute()`. |
  | `test_player_vitals_manager.gd` | Drop line 29. `test_base_attribute_change_still_moves_the_maxima` becomes `test_a_level_gained_moves_the_maxima`: after `add_stat_levels(AttributeType.BODY, 2)`, `_vitals.max_health == CharacterManager.get_stat(Stat.MAX_HEALTH)` and `> 100.0`. `test_gear_and_base_add_up` becomes `test_gear_and_levels_add_up`: the same equality and `> 140.0`. |
  | `test_change_vitals_effect_data.gd` | `_set_attrs(body, mind)` becomes `_set_totals(body, mind)`: the source `&"test"` holds FLAT `body - STAT_BASELINE` on `Stat.BODY` and FLAT `mind - STAT_BASELINE` on `Stat.MIND`, removed in `after_each`. The table stays. |
  | `test_resource_manager.gd` | Drop line 35. `_adventure_capacity()` returns `CharacterManager.get_total_attributes_data().get_max_madra()`; the Mind test calls `CharacterManager.set_stat_level(CharacterAttributesData.AttributeType.MIND, 3)` instead of writing `.mind`. |
  | `test_training_flow.gd` | Drop line 23. `_get_spirit()` becomes `_spirit_level() -> int` (`CharacterManager.get_stat_level(CharacterAttributesData.AttributeType.SPIRIT)`); the asserts expect 2, "Lv 1 + one level", then 3. |
  | `test_adventure_flow.gd` | Drop line 36. `_base_capacity()` returns `CharacterAttributesData.make({&"mind": CharacterManager.get_trained_value(CharacterAttributesData.AttributeType.MIND)}).get_max_madra()`. `_set_mind(value)` becomes `_set_mind_level(level)` (`CharacterManager.set_stat_level(MIND, level)`); the two "higher Mind" tests use level 11. The helmet test's `total` is `make({&"mind": CharacterManager.get_trained_value(MIND) + MIND_BONUS})`. |

- [ ] **Step 7: Run the Step 2 command with the five Step 6 files added to `-gtest` (`res://tests/unit/test_player_vitals_manager.gd,res://tests/unit/test_change_vitals_effect_data.gd,res://tests/unit/test_resource_manager.gd,res://tests/integration/test_training_flow.gd,res://tests/integration/test_adventure_flow.gd`), then `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_tests.ps1`.** Expected: PASS for both.

- [ ] **Step 8: Commit** the six Modify files and the 11 test files by name: `git commit -m "feat(stats): train stats by level and XP to the cap"`. Body: "The player's stats become levels with XP in a saved record, capped by the stage. XP and levels past the cap are lost, each level is logged, and the Aura Well and the dev command add levels." (+ Co-Authored-By line)

---

### Task 1.4: The version-2 save migration

Before Step 1, invoke `godot-prompter:save-load` (CLAUDE.md's versioned `.tres` wins) and `godot-prompter:godot-testing`.

**Files:**
- Modify: `singletons/persistence_manager/save_game_data.gd`.
- Test: `tests/unit/test_save_migration.gd`; `tests/integration/test_dev_panel_saves_tab.gd` (line 304 pins "Version 1").

**Interfaces:**
- Consumes: `StatTrainingData` (Task 1.2), `AdvancementStageResource.stat_level_cap`, `CultivationManager.advancement_stage_resources`, `CharacterAttributesData.STAT_BASELINE`, `AttributeType`, `get_attribute()`.
- Produces: `SaveGameData.CURRENT_VERSION == 2`. Every v1 save loads with a complete `stat_training` and `character_attributes == null`. For a record missing a stat, `verify()` is false and `repair()` returns `"stat_training"`.

- [ ] **Step 1: Write the failing tests in `tests/unit/test_save_migration.gd`.**
  - Add `const AttributeType = CharacterAttributesData.AttributeType`, `const Stage := CultivationManager.AdvancementStage`, and `var _original_stages: Array[AdvancementStageResource]`, saved in a new `before_each` and restored in `after_each` before the temp-file cleanup; the header doc names version 2's stat levels.
  - Helpers: `_use_stat_caps(caps: Dictionary) -> void` installs one `AdvancementStageResource.new()` per entry (`stage_id` the key, `stat_level_cap` the value); `_levels(data: SaveGameData) -> Dictionary` returns `{stat: data.stat_training.get_level(stat)}` for the six.
  - `test_repair_clears_an_unknown_zone` and `test_repair_keeps_a_known_zone` build `new_current()` (a bare `new()` now holds an incomplete record). `test_reset_matches_a_fresh_save` loses its two `character_attributes` lines; both values are now null.
  - `test_v2_turns_old_stat_values_into_levels` (doc: "A v1 save's stat values become levels: one per point above the Lv 1 value, rounded down, from Lv 1, up to the cap of the save's own stage (no cap for a stage with no resource), with no XP. The old values are cleared."): `_use_stat_caps({Stage.FOUNDATION: 5, Stage.COPPER: 8})`. Each case is a `SaveGameData.new()` with `save_version = 1`, `current_advancement_stage` the case's stage and `character_attributes = make(values)`, then `migrate()`; every stat holds the case's level (1 when unlisted) and 0.0 XP, and `character_attributes` is null ("the old values are cleared"), each message naming the case. Cases, stage and values → levels: "Aura Well Spirit 13 is Lv 4" Foundation, Spirit 13.0 → Spirit 4; "Spirit past the cap stops at it" Foundation, Spirit 25.0 → 5; "the save's own stage's cap" Copper, Spirit 25.0 → 8; "a fraction rounds down" Foundation, Strength 12.5 → Strength 3; "below the Lv 1 value is Lv 1" Foundation, Body 8.0 → none above 1; "no stage resource, no cap" `Stage.IRON`, Spirit 25.0 → 16.
  - `test_v2_with_no_old_stats_writes_every_stat_at_level_one`: a v1 `SaveGameData.new()`, migrated, holds level 1 under every stat key and passes `verify()` ("the record is whole").
  - `test_v2_skips_a_current_save`: a `new_current()` save with Spirit Lv 3 and `character_attributes = make({&"spirit": 20.0})` still has Lv 3 after `migrate()` ("a version 2 step, which this save has had") and keeps `character_attributes`.
  - `test_repair_fills_a_missing_stat`: a `new_current()` record with Spirit Lv 4 and `&"mind"` erased from `levels` fails `verify()` ("a record missing a stat is invalid"); `repair()` returns `PackedStringArray(["stat_training"])` ("repair() names what it changed"), writes `&"mind"` ("written out at Lv 1, not left to the default") and keeps Spirit Lv 4 ("the rest is kept"); `verify()` then passes.
  - `test_repair_makes_a_missing_record`: with `stat_training = null`, `verify()` fails, `repair()` returns `PackedStringArray(["stat_training"])`, and `verify()` passes ("every stat is written at Lv 1").
  - And this file as an older build wrote it:
  ```gdscript
  ## A v1 file as an older build wrote it. The Aura Well's Spirit becomes levels, and
  ## the loader drops the stats this build no longer has (Foundation, Resilience,
  ## Willpower).
  func test_an_old_file_keeps_its_aura_well_spirit() -> void:
  	_use_stat_caps({Stage.FOUNDATION: 5})
  	var loaded := _load_hand_written_save("""[gd_resource type="Resource" script_class="SaveGameData" load_steps=3 format=3]

  [ext_resource type="Script" path="res://singletons/persistence_manager/save_game_data.gd" id="1_save"]
  [ext_resource type="Script" path="res://scripts/resource_definitions/character/character_attributes_data.gd" id="2_attrs"]

  [sub_resource type="Resource" id="Resource_attrs"]
  script = ExtResource("2_attrs")
  strength = 12.5
  spirit = 13.0
  foundation = 15.0
  resilience = 12.0
  willpower = 11.0

  [resource]
  script = ExtResource("1_save")
  save_version = 1
  character_attributes = SubResource("Resource_attrs")
  """)
  	assert_not_null(loaded)
  	if loaded == null:
  		return
  	loaded.migrate()
  	assert_eq(loaded.save_version, SaveGameData.CURRENT_VERSION)
  	assert_eq(_levels(loaded), {AttributeType.STRENGTH: 3, AttributeType.BODY: 1, AttributeType.AGILITY: 1,
  		AttributeType.SPIRIT: 4, AttributeType.MIND: 1, AttributeType.CONTROL: 1})
  	assert_null(loaded.character_attributes)
  ```

- [ ] **Step 2: Run it and see it fail.**
  `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/unit/test_save_migration.gd -gexit`
  Expected: FAIL: with no version 2 step, the levels stay at 1, `character_attributes` stays set and `verify()` ignores the record.

- [ ] **Step 3: Implement the step in `save_game_data.gd`.**
  - `CURRENT_VERSION = 2`. `@export var character_attributes: CharacterAttributesData = null`, doc "Legacy (version 1): the stats as values, before levels. Read only by `_migrate_to_v2()`, which clears it." `migrate()` runs `if save_version < 2: _migrate_to_v2()` after the v1 line.
  - `_migrate_to_v2() -> void`, a version step in place like `_migrate_to_v1()`: create `stat_training` if null; for each stat, `level = maxi(1, 1 + floori(old - CharacterAttributesData.STAT_BASELINE))`, `old` being `character_attributes.get_attribute(stat)` (or `STAT_BASELINE` with no legacy block), then `mini(level, cap)` when `cap > 0`; write the level and XP 0.0 for every stat; set `character_attributes = null`. Its doc: the step keeps the Aura Well's Spirit, and the loader has already dropped `foundation`, `resilience` and `willpower`.
  - `_stat_level_cap_of_save_stage() -> int`: the `stat_level_cap` of the `CultivationManager.advancement_stage_resources` entry whose `stage_id == current_advancement_stage`, or 0. The managers haven't bound when `migrate()` runs, but their preloaded member defaults are set.
  - `_verify_stat_training() -> bool`: `stat_training` is not null and `levels` and `xp` both hold every stat key. `verify()` returns `_verify_current_selected_zone_id() and _verify_stat_training()`. `repair()`, when that fails, creates a missing record, writes level 1 for each missing level key and XP 0.0 for each missing XP key, and appends `"stat_training"`.
  - `test_dev_panel_saves_tab.gd` line 304 expects `"Your save · %s\nVersion %d · Playtime 12:34 · Foundation, Core Density 42 / 100 · 120 gold" % [MAIN_SAVE_PATH, SaveGameData.CURRENT_VERSION]` (the v1 temp save is migrated when it opens).

- [ ] **Step 4: Run the Step 2 command with `-gtest=res://tests/unit/test_save_migration.gd,res://tests/integration/test_dev_panel_saves_tab.gd`, then `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_tests.ps1`** (every save path migrates now). Expected: PASS for both.

- [ ] **Step 5: Commit:** `git add singletons/persistence_manager/save_game_data.gd tests/unit/test_save_migration.gd tests/integration/test_dev_panel_saves_tab.gd`, then `git commit -m "feat(save): migrate v1 stat values to trained levels"`. Body: "Version 2 turns the stats a v1 save kept as values into levels, capped by the save's own stage, so the Aura Well's Spirit carries over. Every stat is written explicitly, and repair() refills a record missing one." (+ Co-Authored-By line)

---

### Task 1.5: Derived stats in CharacterManager

Before Step 1, invoke `godot-prompter:godot-testing`.

**Files:**
- Modify: `singletons/character_manager/character_manager.gd`.
- Test: `tests/unit/test_character_manager.gd`.
- Checked, no edit: `scenes/combat/combatant/vitals_manager/vitals_manager.gd`, whose `_on_stats_changed()` already reads the three maxima through `CharacterManager.get_stat()` (`test_player_vitals_manager.gd` covers it).

**Interfaces:**
- Consumes: the block's derived functions (Task 1.1); `get_trained_value()`, `set_stat_level()` (Task 1.3).
- Produces:
  - `CharacterManager.get_stat(Stat.ARMOR / WARD)`: base 0, raised by flat modifiers (gear from Task 1.6).
  - `get_stat(Stat.STAMINA_REGEN / DODGE_CHANCE / MADRA_COST_CUT / COOLDOWN_CUT)`: the block's formula over the total stats (trained levels plus modifiers, so a test may raise Agility or Control with a FLAT modifier source), then the stat's own modifiers.
  - `get_total_attributes_data()` carrying `armor` and `ward`: the fight snapshot Tasks 1.9 and 1.10 read for defence and dodge.

- [ ] **Step 1: Write the failing tests** in a `# DERIVED STATS` section of `tests/unit/test_character_manager.gd`:
  - `test_derived_stats_at_level_one` (doc: "At Lv 1: today's regen, no dodge, no cuts, no armor or Ward."): `get_stat()` is 1.0 for STAMINA_REGEN and 0.0 for DODGE_CHANCE, MADRA_COST_CUT, COOLDOWN_CUT, ARMOR and WARD.
  - `test_derived_stats_follow_the_trained_totals` (doc: "Each derived stat is its CharacterAttributesData formula over the trained totals."): with Agility Lv 6 and Control Lv 11, `get_stat()` of MAX_STAMINA, STAMINA_REGEN, DODGE_CHANCE, MADRA_COST_CUT and COOLDOWN_CUT equals, within 0.000001, the matching function of `make({&"agility": 15.0, &"control": 20.0})`, and exceeds that of `make()` ("%s moved with its stat").
  - `test_derived_stats_count_stat_modifiers` (doc: "The formulas read the total stats, so a stat modifier moves them too."): a FLAT +5 Agility under `TEST_SOURCE` makes `get_stat(Stat.DODGE_CHANCE)` equal `make({&"agility": 15.0}).get_dodge_chance()` within 0.000001.
  - `test_armor_and_ward_come_from_modifiers_into_the_snapshot`: FLAT ARMOR 6.0 and WARD 4.0 under `TEST_SOURCE` give `get_stat()` 6.0 and 4.0, and `get_total_attributes_data()` holds armor 6.0 and Ward 4.0 ("the snapshot a fight starts with").
  - `test_a_derived_stat_takes_its_own_modifiers`: a FLAT +0.5 STAMINA_REGEN under `TEST_SOURCE` gives 1.5.

- [ ] **Step 2: Run it and see it fail.**
  `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/unit/test_character_manager.gd -gexit`
  Expected: FAIL: the derived stats, ARMOR and WARD fall through to a stat level and read 10.0, and the snapshot's armor is 0.0.

- [ ] **Step 3: Implement it in `character_manager.gd`.**
  - `_get_base_stat()` gets arms reading `get_total_attributes_data()`'s `get_stamina_regen()`, `get_dodge_chance()`, `get_madra_cost_cut()` and `get_cooldown_cut()` for the matching stats; `Stat.ARMOR, Stat.WARD` return 0.0. Its doc gains "armor and Ward start at 0".
  - `get_total_attributes_data()` also sets `totals.armor = get_stat(Stat.ARMOR)` and `totals.ward = get_stat(Stat.WARD)`. Doc: "the six stats, armor and Ward (base + modifiers) as one block, a snapshot that does not follow later changes".

- [ ] **Step 4: Run the Step 2 command with `-gtest=res://tests/unit/test_character_manager.gd,res://tests/unit/test_player_vitals_manager.gd`, then `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_tests.ps1`.** Expected: PASS for both.

- [ ] **Step 5: Commit:** `git add singletons/character_manager/character_manager.gd tests/unit/test_character_manager.gd`, then `git commit -m "feat(stats): derive armor, Ward, regen, dodge, cuts"`. Body: "CharacterManager answers every derived stat through the stat block's formulas, so the UI and combat read one number. Armor and Ward start at 0 for gear to raise, and the fight snapshot carries them." (+ Co-Authored-By line)

---

### Task 1.6: Gear bonuses as floored percents, armor and Ward

Before Step 1, invoke `godot-prompter:resource-pattern` and `godot-prompter:godot-testing`.

**Files:**
- Modify: `scripts/resource_definitions/items/equipment/equipment_definition_data.gd`, `singletons/character_manager/character_manager.gd`
- Modify (gear fixtures): `tests/unit/test_player_vitals_manager.gd`, `tests/integration/test_adventure_flow.gd`, `tests/integration/test_zone_action_cards.gd`, `tests/integration/test_adventure_view_frame.gd`
- Test: `tests/unit/test_equipment.gd`, `tests/unit/test_character_manager.gd`

**Interfaces:**
- Consumes: Task 1.1's `CharacterAttributesData.stat_key()`, `stat_from_key()`, `STAT_BASELINE`, `armor`, `ward` and `StatModifierData.Stat.ARMOR` / `WARD`. Task 1.3's `CharacterManager.get_trained_value()`, `get_trained_values()` (from the training record, never `get_stat()`), `set_stat_level()`, `get_stat_level()`, `get_stat_level_cap()`, `is_stat_capped()`, and `test_character_manager.gd`'s fixture (`TEST_CAP` 5; Lv 1 is 10, +1 a level). Task 1.5's 0 base for ARMOR and WARD, copied by `get_total_attributes_data()`.
- Produces: `EquipmentDefinitionData.stat_percent_bonuses: Dictionary[StringName, float]`, `stat_bonus_floor: int`, `armor: float`, `ward: float`, `get_stat_bonus(stat: CharacterAttributesData.AttributeType, trained_value: float) -> float`, `get_stat_modifiers(trained_values: Dictionary) -> Array[StatModifierData]`; `CharacterManager.get_gear_bonus(stat: CharacterAttributesData.AttributeType) -> float`.

`attribute_bonuses` stays declared but reaches no stat: the ITEMS.md tools read it until Task 1.7, and the gear text until Task 1.8 deletes it. Until Task 1.7 regenerates the Spirit Valley files, the shipped gear raises no stat. Don't run `items_md_to_resources.gd` in this task.

- [ ] **Step 1: Write the failing tests**

In `tests/unit/test_equipment.gd`, add `const AttributeType = CharacterAttributesData.AttributeType` and `_item(percents: Dictionary, bonus_floor: int = 1, armor: float = 0.0, ward: float = 0.0) -> EquipmentDefinitionData`, a new item with those fields (`percents`, stat key → fraction, copied key by key: the typed Dictionary refuses an untyped one). Replace `test_get_stat_modifiers_turns_bonuses_into_flat_modifiers` and `test_get_stat_modifiers_without_bonuses_is_empty` with:

```gdscript
func test_stat_bonus_is_the_rounded_down_percent_with_the_item_floor() -> void:
	var cases: Array[Dictionary] = [
		{"name": "the floor at a low value", "percent": 0.1, "floor": 2, "trained": 10.0, "expected": 2.0},
		{"name": "the percent above the floor", "percent": 0.25, "floor": 2, "trained": 20.0, "expected": 5.0},
		{"name": "rounded down", "percent": 0.25, "floor": 1, "trained": 18.0, "expected": 4.0},
		{"name": "a floor of 1 under a small percent", "percent": 0.05, "floor": 1, "trained": 10.0, "expected": 1.0},
	]
	for case: Dictionary in cases:
		var item := _item({&"strength": case.percent}, case.floor)
		assert_eq(item.get_stat_bonus(AttributeType.STRENGTH, case.trained), case.expected, case.name)

func test_stat_bonus_without_a_percent_is_zero() -> void:
	var cases: Array[Dictionary] = [
		{"name": "another stat's percent", "percents": {&"agility": 0.5}},
		{"name": "a 0% entry", "percents": {&"strength": 0.0}},
	]
	for case: Dictionary in cases:
		assert_eq(_item(case.percents, 3).get_stat_bonus(AttributeType.STRENGTH, 10.0), 0.0, case.name)

func test_stat_modifiers_are_flat_bonuses_with_armor_and_ward() -> void:
	var item := _item({&"strength": 0.5, &"mind": 0.25}, 1, 6.0, 4.0)
	var trained: Dictionary = {AttributeType.STRENGTH: 10.0, AttributeType.MIND: 20.0}
	var values: Dictionary = {}
	for modifier: StatModifierData in item.get_stat_modifiers(trained):
		assert_eq(modifier.kind, StatModifierData.Kind.FLAT, "%s is flat" % StatModifierData.Stat.keys()[modifier.stat])
		values[modifier.stat] = modifier.value
	assert_eq(values, {StatModifierData.Stat.STRENGTH: 5.0, StatModifierData.Stat.MIND: 5.0,
		StatModifierData.Stat.ARMOR: 6.0, StatModifierData.Stat.WARD: 4.0})

func test_a_bare_item_gives_no_modifiers() -> void:
	assert_eq(EquipmentDefinitionData.new().get_stat_modifiers({}).size(), 0)
```

In `tests/unit/test_character_manager.gd`:
- `_make_gear(slot: EquipmentSlot, percents: Dictionary, bonus_floor: int = 1, armor: float = 0.0, ward: float = 0.0) -> ItemInstanceData` replaces `_make_gear()`: an instance of an item built as `test_equipment.gd`'s `_item()` builds one, with `item_id = "test_gear_%d" % slot` and `slot_type = slot`.
- Every other gear fixture, `_robes()` included, goes from `{AttributeType.X: N}` to `{&"x": N / 10.0}` (`{AttributeType.STRENGTH: 5.0}` becomes `{&"strength": 0.5}`): the same +N at Lv 1, so their expected totals stand.
- Delete `test_negative_bonus_lowers_total` (percents are never negative), `test_gear_bonus_adds_to_matching_attributes_only` and `test_equip_and_unequip_gear_updates_totals` (covered below). The `##` header says gear adds floored percents of the trained value, armor and Ward.
- Add:

```gdscript
const BASELINE: float = CharacterAttributesData.STAT_BASELINE

#-----------------------------------------------------------------------------
# GEAR: FLOORED PERCENTS OF THE TRAINED VALUE, ARMOR AND WARD
#-----------------------------------------------------------------------------

func test_worn_gear_adds_its_floored_bonus_to_the_trained_value() -> void:
	_inventory().equipped_gear[EquipmentSlot.MAIN_HAND] = _make_gear(EquipmentSlot.MAIN_HAND, {&"strength": 0.1}, 3)
	assert_eq(CharacterManager.get_gear_bonus(AttributeType.STRENGTH), 3.0, "the floor beats 10% of 10")
	assert_eq(CharacterManager.get_stat(Stat.STRENGTH), BASELINE + 3.0)
	assert_eq(CharacterManager.get_gear_bonus(AttributeType.AGILITY), 0.0, "no Agility percent")
	assert_eq(CharacterManager.get_stat(Stat.AGILITY), BASELINE)

## Each percent counts the trained value, never a total that holds another
## item's bonus (a gear source reading get_stat() would also recurse).
func test_gear_percents_count_the_trained_value_not_the_total() -> void:
	_inventory().equipped_gear[EquipmentSlot.MAIN_HAND] = _make_gear(EquipmentSlot.MAIN_HAND, {&"strength": 0.5})
	_inventory().equipped_accessories[0] = _make_gear(EquipmentSlot.ACCESSORY, {&"strength": 0.5})
	assert_eq(CharacterManager.get_stat(Stat.STRENGTH), BASELINE * 2.0, "10 + 5 + 5, not 10 + 5 + 7")

func test_gear_lifts_a_capped_stat_past_the_cap() -> void:
	CharacterManager.set_stat_level(AttributeType.STRENGTH, TEST_CAP)
	_inventory().equipped_gear[EquipmentSlot.MAIN_HAND] = _make_gear(EquipmentSlot.MAIN_HAND, {&"strength": 0.5})
	assert_eq(CharacterManager.get_gear_bonus(AttributeType.STRENGTH), 7.0, "50% of 14, the value at the test cap")
	assert_eq(CharacterManager.get_stat(Stat.STRENGTH), 21.0, "the total passes the capped value")
	assert_eq(CharacterManager.get_stat_level(AttributeType.STRENGTH), TEST_CAP, "training stays at the cap")
	assert_true(CharacterManager.is_stat_capped(AttributeType.STRENGTH))

func test_unequipping_gear_removes_its_bonus_and_armor() -> void:
	var robes: ItemInstanceData = _make_gear(EquipmentSlot.ARMOR, {&"body": 0.4}, 1, 6.0)
	_inventory().equipment[0] = robes
	InventoryManager.equip_item(robes, EquipmentSlot.ARMOR, 0)
	assert_eq(CharacterManager.get_stat(Stat.BODY), BASELINE + 4.0, "precondition: worn")
	assert_eq(CharacterManager.get_stat(Stat.ARMOR), 6.0, "precondition: worn")
	InventoryManager.unequip_item(EquipmentSlot.ARMOR)
	assert_eq(CharacterManager.get_stat(Stat.BODY), BASELINE)
	assert_eq(CharacterManager.get_stat(Stat.ARMOR), 0.0)

func test_armor_and_ward_come_from_gear_into_the_fight_block() -> void:
	assert_eq(CharacterManager.get_stat(Stat.ARMOR), 0.0, "no armor without gear")
	assert_eq(CharacterManager.get_stat(Stat.WARD), 0.0, "no Ward without gear")
	_inventory().equipped_gear[EquipmentSlot.ARMOR] = _make_gear(EquipmentSlot.ARMOR, {}, 1, 6.0)
	_inventory().equipped_gear[EquipmentSlot.HEAD] = _make_gear(EquipmentSlot.HEAD, {}, 1, 0.0, 4.0)
	var block: CharacterAttributesData = CharacterManager.get_total_attributes_data()
	assert_eq(block.armor, 6.0, "armor reaches the fight snapshot")
	assert_eq(block.ward, 4.0, "Ward reaches the fight snapshot")
```

- [ ] **Step 2: Run them and see them fail.** `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/unit/test_equipment.gd,res://tests/unit/test_character_manager.gd -gexit`
  Expected: FAIL: neither script parses (no `stat_percent_bonuses`, `get_stat_bonus()` or `get_gear_bonus()` yet).

- [ ] **Step 3: Implement the gear rule and the gear source, and move the other gear fixtures**
  - EXPORTS in `equipment_definition_data.gd`: the four fields above, defaulting to `{}`, `1`, `0.0` and `0.0`, with `##` docs (stat key → fraction of the trained value; the least each percent gives, in whole points; flat, cuts physical damage; flat, cuts Spirit damage). `attribute_bonuses`' doc: "Legacy: reaches no stat; read only by the gear text and the ITEMS.md tools until Task 1.8 deletes it." Class doc: "The slot decides where the item is worn; its stat percents (never below the floor), armor and Ward decide what it gives."
  - `get_stat_bonus()`: 0.0 when the percent under `CharacterAttributesData.stat_key(stat)` is missing or not above 0, else `maxf(stat_bonus_floor, floorf(trained_value * percent))`. No clamp to the cap: the cap limits training only.
  - `get_stat_modifiers()`: each key of `stat_percent_bonuses` goes through `CharacterAttributesData.stat_from_key()`; a -1 gets a `Log.error` naming `item_id` and the key, and is skipped. A known stat adds a FLAT modifier on `StatModifierData.for_attribute(stat)` worth `get_stat_bonus(stat, trained_values.get(stat, CharacterAttributesData.STAT_BASELINE))` when above 0, then FLAT `Stat.ARMOR` and `Stat.WARD` modifiers, each when above 0.
  - `CharacterManager._equipped_gear() -> Array[EquipmentDefinitionData]`: the definitions `_gear_modifiers()` walks today, with its guards (this manager's own save; no save or inventory gives `[]`; nulls and non-equipment skipped).
  - `_gear_modifiers()`: each `_equipped_gear()` item's `get_stat_modifiers(get_trained_values())`. Its doc says why it reads the training record: `get_stat()` asks this source, so calling `get_stat()` here would recurse.
  - `get_gear_bonus(stat)`: the sum of `get_stat_bonus(stat, get_trained_value(stat))` over `_equipped_gear()`. Doc: exactly what `get_stat()` adds for gear.
  - The other gear fixtures keep today's numbers at Lv 1:
    - `test_player_vitals_manager.gd`: `_make_gear(slot, percents: Dictionary)` copies `percents` key by key into `stat_percent_bonuses`; its calls follow the ÷ 10 rule (`{&"body": 0.4}`, `{&"agility": 0.4}`, `{&"mind": 0.2}`).
    - `test_adventure_flow.gd`'s `_equip_mind_helmet()` (Task 1.1's name): `helmet.stat_percent_bonuses[&"mind"] = MIND_BONUS / 10.0` replaces the `attribute_bonuses` line; `test_zone_action_cards.gd`'s `_equip_mind_ring(mind)` likewise sets `mind / 10.0`.
    - `test_adventure_view_frame.gd`, `test_gear_equipped_before_the_run_raises_the_cabinets_max_health`: the two lines that rebuild the maximum from `attribute_bonuses` become `var max_health: int = floori(CharacterManager.get_stat(StatModifierData.Stat.MAX_HEALTH))`. Task 1.7 adds the precondition that the robes raise Body.

- [ ] **Step 4: Run them and see them pass.** The Step 2 command with `res://tests/unit/test_player_vitals_manager.gd`, `res://tests/integration/test_adventure_flow.gd`, `res://tests/integration/test_zone_action_cards.gd` and `res://tests/integration/test_adventure_view_frame.gd` added to `-gtest`.
  Expected: PASS.

- [ ] **Step 5: Commit.** Stage the eight files under **Files**, then `git commit -m "feat(stats): make gear bonuses floored percents"`. Body: "Gear adds a percent of the trained value, never below the item's floor, so a first sword matters at Lv 1 and keeps up as stats climb. Armor and Ward come only from gear. The gear source reads the training record: get_stat() would recurse." (+ Co-Authored-By line)

---

### Task 1.7: ITEMS.md gear stats and the regenerated Spirit Valley items

Before Step 1, invoke `godot-prompter:godot-testing`.

**Files:**
- Modify: `scripts/tools/items_md_parser.gd`, `scripts/tools/items_md_to_resources.gd`
- Modify: `docs/inventory/ITEMS.md`. Code reads this doc, so it changes in this PR.
- Modify (written by the generator, never by hand): the seven `resources/items/equipment/spirit_valley/*.tres`
- Modify: `tests/integration/test_adventure_view_frame.gd` (one precondition)
- Test: `tests/unit/test_items_md_parser.gd`

**Interfaces:**
- Consumes: the four gear fields and `CharacterManager.get_gear_bonus()` (Task 1.6); `CharacterAttributesData.stat_key()` / `stat_from_key()` (Task 1.1).
- Produces: `ItemsMdParser.parse_stats(s: String) -> EquipmentDefinitionData` (only the four stat fields set; null after a `push_error` for a bad token); `ItemsMdParser.build_equipment(row: Dictionary) -> EquipmentDefinitionData` (null for a bad stats cell); `ItemsMdParser.GENERATED_FIELDS: Array[StringName]`; `ItemsMdParser.generated_fields_equal(a: EquipmentDefinitionData, b: EquipmentDefinitionData) -> bool`; the seven items in the new fields, with these starting values:

| # | Item | stats cell | Gives at Lv 1 |
|---|---|---|---|
| E1 | Makeshift Dagger | `STRENGTH+30%, AGILITY+10%, FLOOR+2` | +3 Strength, +2 Agility |
| E2 | Iron Shortsword | `STRENGTH+50%, AGILITY+10%, FLOOR+2` | +5 Strength, +2 Agility |
| E3 | Cultivator's Cowl | `SPIRIT+15%, WARD+4` | +1 Spirit (+2 from Spirit Lv 5), Ward 4 |
| E4 | Reinforced Robes | `BODY+40%, ARMOR+6` | +4 Body, Armor 6 |
| E5 | Dreadbeast Tooth Necklace | `STRENGTH+20%, AGILITY+20%` | +2 Strength, +2 Agility |
| E6 | Leeching Ring | `MIND+20%, CONTROL+20%` | +2 Mind, +2 Control |
| E7 | Scripted Bark | `BODY+20%` | +2 Body |

Why: each percent is today's flat bonus ÷ 10 (the ring's Foundation now Mind), so Lv 1 numbers and the Lv 1 combat retune hold. `FLOOR+2` keeps the blades' Agility at +2 under a secondary 10%. The cowl's 15% gives +2 from Spirit Lv 5, so Aura Well training visibly lifts gear inside Foundation. Armor 6 and Ward 4 (the design's examples) replace the robes' Resilience+2 and the cowl's Willpower+3. Retune the Physical percents in phase 5, when those stats first train (at the Foundation cap the sword gives +9).

- [ ] **Step 1: Write the failing tests**

In `tests/unit/test_items_md_parser.gd`, delete `const AT`; `test_build_equipment_populates_all_fields` gets `"stats": "STRENGTH+30%, AGILITY+10%, FLOOR+2"` and, for its two `attribute_bonuses` asserts, `assert_eq(eq.stat_percent_bonuses, {&"strength": 0.3, &"agility": 0.1})` and `assert_eq(eq.stat_bonus_floor, 2)`; `test_build_equipment_empty_stats_yields_empty_bonuses` asserts `eq.stat_percent_bonuses.size() == 0` and `eq.stat_bonus_floor == 1`. `test_parse_equipment_sections_groups_by_zone` never parses its stats cells: leave it. The first two tests below replace `test_parse_stats_reads_each_pair` and `test_parse_stats_unknown_attr_returns_empty`:

```gdscript
## STAT+N% is a fraction, ARMOR+N and WARD+N flat, FLOOR+N the floor. A case
## leaves out a field at its default (floor 1, armor 0, Ward 0).
func test_parse_stats_reads_each_token() -> void:
	var cases: Array[Dictionary] = [
		{"name": "one percent", "text": "STRENGTH+30%", "percents": {&"strength": 0.3}},
		{"name": "two percents and a floor", "text": "STRENGTH+30%, AGILITY+10%, FLOOR+2",
			"percents": {&"strength": 0.3, &"agility": 0.1}, "floor": 2},
		{"name": "a percent and armor", "text": "BODY+40%, ARMOR+6", "percents": {&"body": 0.4}, "armor": 6.0},
		{"name": "a percent and Ward", "text": "SPIRIT+15%, WARD+4", "percents": {&"spirit": 0.15}, "ward": 4.0},
		{"name": "Mind and Control", "text": "MIND+20%, CONTROL+20%", "percents": {&"mind": 0.2, &"control": 0.2}},
		{"name": "a fractional percent", "text": "SPIRIT+12.5%", "percents": {&"spirit": 0.125}},
		{"name": "empty", "text": "", "percents": {}},
		{"name": "spaces only", "text": "   ", "percents": {}},
	]
	for case: Dictionary in cases:
		var stats: EquipmentDefinitionData = ItemsMdParser.parse_stats(case.text)
		assert_not_null(stats, case.name)
		if stats == null:
			continue
		assert_eq(stats.stat_percent_bonuses, case.percents, "%s: percents" % case.name)
		assert_eq(stats.stat_bonus_floor, case.get("floor", 1), "%s: floor" % case.name)
		assert_eq(stats.armor, case.get("armor", 0.0), "%s: armor" % case.name)
		assert_eq(stats.ward, case.get("ward", 0.0), "%s: Ward" % case.name)

func test_parse_stats_refuses_a_bad_token() -> void:
	var cases: Array[Dictionary] = [
		{"name": "unknown word", "text": "BOGUS+5%", "error": "unknown stat word 'BOGUS'"},
		{"name": "no sign", "text": "STRENGTH30%", "error": "missing + in 'STRENGTH30%'"},
		{"name": "a negative bonus", "text": "AGILITY-10%", "error": "no negative bonuses: 'AGILITY-10%'"},
		{"name": "a stat without %", "text": "STRENGTH+3", "error": "'STRENGTH+3' needs a %"},
		{"name": "armor with %", "text": "ARMOR+6%", "error": "'ARMOR+6%' is flat"},
		{"name": "not a number", "text": "SPIRIT+ten%", "error": "'SPIRIT+ten%' has no number"},
		{"name": "a zero percent", "text": "SPIRIT+0%", "error": "'SPIRIT+0%' must be above 0"},
		{"name": "a floor below 1", "text": "BODY+20%, FLOOR+0", "error": "'FLOOR+0' must be a whole number of at least 1"},
		{"name": "a fractional floor", "text": "BODY+20%, FLOOR+1.5", "error": "'FLOOR+1.5' must be a whole number of at least 1"},
		{"name": "a word twice", "text": "BODY+20%, BODY+10%", "error": "'BODY' appears twice"},
	]
	for case: Dictionary in cases:
		assert_null(ItemsMdParser.parse_stats(case.text), case.name)
		assert_push_error(case.error, case.name)

func test_build_equipment_refuses_a_bad_stats_cell() -> void:
	var row: Dictionary = {
		"id": "flat_dagger", "name": "Flat Dagger", "slot": "MAIN_HAND",
		"stats": "STRENGTH+3", "cost": "0", "description": "Old notation.",
	}
	assert_null(ItemsMdParser.build_equipment(row))
	assert_push_error("needs a %")

## The generator rewrites a file only when a generated field differs.
func test_generated_fields_equal_notices_each_stat_field() -> void:
	var base_cell: String = "STRENGTH+30%, ARMOR+6, WARD+4, FLOOR+2"
	var base: EquipmentDefinitionData = ItemsMdParser.parse_stats(base_cell)
	assert_true(ItemsMdParser.generated_fields_equal(base, ItemsMdParser.parse_stats(base_cell)), "the same cell")
	var cases: Array[Dictionary] = [
		{"name": "a percent", "text": "STRENGTH+50%, ARMOR+6, WARD+4, FLOOR+2"},
		{"name": "the floor", "text": "STRENGTH+30%, ARMOR+6, WARD+4, FLOOR+3"},
		{"name": "armor", "text": "STRENGTH+30%, ARMOR+5, WARD+4, FLOOR+2"},
		{"name": "Ward", "text": "STRENGTH+30%, ARMOR+6, WARD+5, FLOOR+2"},
	]
	for case: Dictionary in cases:
		assert_false(ItemsMdParser.generated_fields_equal(base, ItemsMdParser.parse_stats(case.text)), case.name)

#-----------------------------------------------------------------------------
# THE SHIPPED GEAR
#-----------------------------------------------------------------------------

## Catches a row edited without a generator run, and a class default changing
## under a value the saver left out of a file.
func test_the_shipped_gear_matches_items_md() -> void:
	var sections: Dictionary = ItemsMdParser.parse_equipment_sections(FileAccess.get_file_as_string("res://docs/inventory/ITEMS.md"))
	var rows: Array = sections.get("Spirit Valley", [])
	assert_gt(rows.size(), 0, "precondition: ITEMS.md lists Spirit Valley gear")
	for row: Dictionary in rows:
		var built: EquipmentDefinitionData = ItemsMdParser.build_equipment(row)
		var shipped := load("res://resources/items/equipment/spirit_valley/%s.tres" % row["id"]) as EquipmentDefinitionData
		assert_not_null(built, "%s builds" % row["id"])
		assert_not_null(shipped, "%s has a file" % row["id"])
		if built == null or shipped == null:
			continue
		built.icon = shipped.icon  # the generator takes the icon from the PNG, not from the row
		assert_true(ItemsMdParser.generated_fields_equal(built, shipped), "%s matches its row" % row["id"])
```

- [ ] **Step 2: Run it and see it fail.** `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/unit/test_items_md_parser.gd -gexit`
  Expected: FAIL: the script doesn't parse (no `generated_fields_equal()`, and `parse_stats()` still returns a Dictionary).

- [ ] **Step 3: Implement the parser, the generator and the doc, then regenerate**
  - `parse_stats()` starts from `EquipmentDefinitionData.new()` and sets `stat_bonus_floor = 1`, `armor = 0.0` and `ward = 0.0` itself, so a later class-default change shows up in the shipped-gear test. It splits on commas, skips blank tokens, and checks each token in this order; a failure is `push_error("ItemsMdParser.parse_stats: " + message)` and `return null`:
    1. No `+` or `-` (`_find_sign_index()`): `missing + in '<token>'`.
    2. A `-`: `no negative bonuses: '<token>'`.
    3. A repeated word: `'<WORD>' appears twice`.
    4. `FLOOR` with a `%`, or a number that fails `is_valid_int()` or is below 1: `'<token>' must be a whole number of at least 1`.
    5. `ARMOR` or `WARD` with a `%`: `'<token>' is flat: drop the %`.
    6. Another word that `CharacterAttributesData.stat_from_key(StringName(word.to_lower()))` doesn't know: `unknown stat word '<WORD>'`.
    7. A stat without `%`: `'<token>' needs a %: stat bonuses are percents`.
    8. The number (`%` trimmed) fails `is_valid_float()`: `'<token>' has no number`.
    9. The number is not above 0: `'<token>' must be above 0`.

    A stat stores `number / 100.0` under `stat_key(stat)`; `ARMOR` and `WARD` store the number; `FLOOR` stores `to_int()`.
  - `build_equipment()` keeps its required-field and slot checks, returns null when `parse_stats(row["stats"])` does (adding no second error), and otherwise sets `item_id`, `item_name`, `description`, `slot_type` and `base_value` on that result. It no longer touches `attribute_bonuses`.
  - `const GENERATED_FIELDS: Array[StringName] = [&"item_id", &"item_name", &"description", &"slot_type", &"stat_percent_bonuses", &"stat_bonus_floor", &"armor", &"ward", &"base_value", &"icon"]`; `generated_fields_equal(a, b)` is true when `a.get(field) == b.get(field)` for each.
  - `items_md_to_resources.gd`: after the icon pre-flight, `run()` builds every row with `ItemsMdParser.build_equipment()`; on the first null it calls `push_error("ItemsMdGenerator: row '%s' is invalid; nothing written" % row.get("id", "?"))` and returns 1. `_write_one()` replaces its seven copy lines with `for field: StringName in ItemsMdParser.GENERATED_FIELDS: existing.set(field, eq.get(field))` and skips the file when `ItemsMdParser.generated_fields_equal(existing as EquipmentDefinitionData, eq)`. Delete `_resources_equal()`.
  - `docs/inventory/ITEMS.md`:
    - The generated-field lists, in the intro and in the sentence after the Behavior table, become the `GENERATED_FIELDS` names.
    - The Schema `stats` row maps to "`stat_percent_bonuses` (Dictionary[StringName, float]), `stat_bonus_floor`, `armor`, `ward`".
    - "### Stats DSL" up to "### Spirit Valley" becomes the block below.
    - Each Spirit Valley row's `stats` cell becomes its "stats cell" above; no other cell changes.
    - In the Behavior table, delete the "Invalid stats DSL" row; the slot row reads "| Unknown `slot` literal, an empty `id` / `name` / `slot` / `description`, or a bad stats token | Run aborts before anything is written, naming the row |".

```markdown
### Stats DSL

Format: `<WORD>+<N>[%], ...`, comma-separated, each word at most once.

| Word | Gives | Field |
|---|---|---|
| `STRENGTH`, `BODY`, `AGILITY`, `SPIRIT`, `MIND`, `CONTROL` | A percent of the player's trained value of that stat, always with `%` (`STRENGTH+30%`), rounded down and never below the item's floor | `stat_percent_bonuses`, a fraction under the stat's key (`&"strength": 0.3`) |
| `ARMOR` | Flat armor, which cuts physical damage. No `%` | `armor` |
| `WARD` | Flat Ward, which cuts Spirit damage. No `%` | `ward` |
| `FLOOR` | The least each stat percent gives, a whole number of at least 1 (1 when absent) | `stat_bonus_floor` |

- Every number is above 0. An empty stats cell is an item with no bonuses.
- A bad token stops the generator before it writes anything, naming the token, and the run exits with 1: an unknown word, a missing `+`, a `-`, a stat without `%`, a `%` on `ARMOR`, `WARD` or `FLOOR`, a number that isn't one or isn't above 0, or a word written twice.

**Foundation tier authoring guidelines** (per [EQUIPMENT_DESIGN.md](EQUIPMENT_DESIGN.md)):
- 1-2 stat percents per item. Body and head pieces may add `ARMOR` or `WARD`.
- Every stat is 10 at Lv 1, where a percent gives `max(FLOOR, percent of 10, rounded down)`: `STRENGTH+30%` gives +3. Strength, Body and Agility stay at Lv 1 until body refining exists, so that is all Physical gear gives for now. Pick the percent for what the item should give at Lv 1; `FLOOR` lifts a second stat with a smaller percent (`AGILITY+10%, FLOOR+2` gives +2).
- Simple, clear identity: a sword gives `STRENGTH`, a cowl gives `SPIRIT` and `WARD`.
```

  - Regenerate: `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s scripts/tools/items_md_to_resources.gd`. Expected: `ItemsMdGenerator: created=0 updated=7 skipped=0 orphans=0`, exit code 0. `git diff resources/items/equipment/spirit_valley/` shows only a `stat_percent_bonuses` line per file, `stat_bonus_floor = 2` on both blades, `armor = 6.0` on the robes, `ward = 4.0` on the cowl, and maybe a `uid=` on the cowl's header (it has none) or on `ext_resource` lines. `attribute_bonuses` stays until Task 1.8.
  - In `test_gear_equipped_before_the_run_raises_the_cabinets_max_health`, add after `_start_run()`: `assert_gt(CharacterManager.get_gear_bonus(CharacterAttributesData.AttributeType.BODY), 0.0, "precondition: the robes raise Body")`.

- [ ] **Step 4: Run it and see it pass.** The Step 2 command with `res://tests/integration/test_adventure_view_frame.gd`, `res://tests/integration/test_equipment_page.gd` and `res://tests/integration/test_merchant_shop_flow.gd` added to `-gtest`.
  Expected: PASS. `test_equipment_page.gd` still prints the legacy flat text, which Task 1.8 replaces.

- [ ] **Step 5: Commit.** Stage the files under **Files** (git expands the `*.tres` pathspec itself), then `git commit -m "feat(items): convert Spirit Valley gear to percents"`. Body: "ITEMS.md writes stat bonuses as percents (STRENGTH+30%) with flat ARMOR and WARD and a per-item FLOOR; a bad token stops the generator before it writes anything. Each percent is today's flat bonus / 10, so Lv 1 numbers don't change. A test locks the generated files to their rows." (+ Co-Authored-By line)

---

### Task 1.8: Gear text with what it gives now, reprinted on level-up

Before Step 1, invoke `godot-prompter:godot-ui` and `godot-prompter:godot-testing`.

**Files:**
- Modify: `scripts/utils/book_text.gd`, `scripts/resource_definitions/items/equipment/equipment_definition_data.gd`
- Modify, in `scenes/inventory/inventory_view/equipment_tab/equipment_details/`: `equipment_details.gd`, `bonus_row.gd`, `bonus_row.tscn`, and `equipment_details.tscn` only if the approved layout needs it
- Modify: `scenes/common/item_description_panel/item_description_panel.gd`, `scenes/merchant/merchant_stock_row/merchant_stock_row.gd` and `.tscn`
- Modify: the seven `resources/items/equipment/spirit_valley/*.tres` (the dead `attribute_bonuses` block)
- Create: `tests/integration/test_item_description_panel.gd` and its `.gd.uid`
- Test: `tests/unit/test_book_text.gd`, `tests/unit/test_equipment.gd`, `tests/integration/test_equipment_page.gd`, `tests/integration/test_merchant_shop_flow.gd`, `tests/integration/test_boards_never_trim_text.gd`

**Interfaces:**
- Consumes: Task 1.6's gear fields, `get_stat_bonus()` and `CharacterManager.get_gear_bonus()`; Task 1.3's `CharacterManager.get_trained_values()` and `set_stat_level()` (emits `stats_changed`); `CharacterManager.get_attribute_display_name()`; Task 1.1's `stat_key()` and `STAT_BASELINE`; Task 1.0's approved gear-text board.
- Produces: `BookText.gear_bonus_lines(def: EquipmentDefinitionData, trained_values: Dictionary) -> Array[String]`, printed by EquipmentDetails, ItemDescriptionPanel and MerchantStockRow, which reprint gear on `CharacterManager.stats_changed`. Gone: `attribute_bonuses`, `BookText.bonus_lines()` and the `EquipmentDefinitionData._get_item_effects()` override, so equipment gets the base class's `[]`.

- [ ] **Step 1: Write the failing tests**

In `tests/unit/test_book_text.gd`, add `const AttributeType = CharacterAttributesData.AttributeType` and a copy of Task 1.6's `_item()` helper, and replace `test_bonus_lines_skip_zero_and_set_fractions_to_one_decimal` with:

```gdscript
func test_gear_bonus_lines_word_each_bonus_with_its_value_now() -> void:
	var cases: Array[Dictionary] = [
		{"name": "a stat at its floor", "item": _item({&"strength": 0.1}, 2),
			"trained": {AttributeType.STRENGTH: 10.0}, "lines": ["+10% Strength · +2 now"]},
		{"name": "stats in stat order, then armor, then Ward",
			"item": _item({&"control": 0.2, &"strength": 0.5}, 1, 6.0, 4.0),
			"trained": {AttributeType.STRENGTH: 10.0, AttributeType.CONTROL: 15.0},
			"lines": ["+50% Strength · +5 now", "+20% Control · +3 now", "Armor 6", "Ward 4"]},
		{"name": "a fractional percent", "item": _item({&"spirit": 0.125}),
			"trained": {AttributeType.SPIRIT: 16.0}, "lines": ["+12.5% Spirit · +2 now"]},
		{"name": "no bonuses", "item": _item({}), "trained": {}, "lines": []},
	]
	for case: Dictionary in cases:
		var expected: Array[String] = []
		expected.assign(case.lines)
		assert_eq(BookText.gear_bonus_lines(case.item, case.trained), expected, case.name)
```

In `tests/unit/test_equipment.gd`, delete `test_init_empty_bonuses`, `test_attribute_bonuses_stores_values`, `test_attribute_bonuses_supports_all_types`, `test_get_item_effects_one_line_per_nonzero_bonus` and `test_get_item_effects_formats_each_bonus`, and the "ATTRIBUTE BONUSES DICTIONARY" and "_get_item_effects() BBCode FORMATTING" headers; the `##` header names the slot enum and its ints, initialization, and the gear rule.

The three files below each get `_spirit_charm() -> EquipmentDefinitionData`: `item_id = "test_spirit_charm"`, `item_name = "Spirit Charm"`, HEAD slot, `stat_percent_bonuses[&"spirit"] = 0.5` (the Aura Well levels Spirit while a book or the shop is open).

In `tests/integration/test_equipment_page.gd`, the fixture also stashes `PersistenceManager.save_game_data.stat_training` in `var _saved_training: StatTrainingData`, installs `StatTrainingData.new_default()` in `before_each()`, and restores it after the frame wait in `after_each()`. Add `_spirit_charm()` and `_bonus_texts(details: EquipmentDetails) -> Array[String]` (each `%Bonuses` row's `%LeftBonus` text, then its `%RightBonus` text when visible), replace `test_details_print_the_slot_and_the_bonuses`, and add the reprint test:

```gdscript
func test_details_print_the_slot_and_the_bonuses() -> void:
	var tab: Control = _tab()
	InventoryManager.award_items(DAGGER, 1)
	tab.open_page()
	var details: EquipmentDetails = _details(tab)
	assert_eq((details.get_node("%SlotLabel") as Label).text, "MAIN HAND")
	assert_eq((details.get_node("%Icon") as TextureRect).texture, DAGGER.icon)
	var lines: Array[String] = BookText.gear_bonus_lines(DAGGER, CharacterManager.get_trained_values())
	assert_gt(lines.size(), 0, "precondition: the dagger has bonuses")
	assert_eq(_bonus_texts(details), lines, "every bonus line, in order")
	assert_eq((details.get_node("%Description") as Label).text, DAGGER.description)

## The details reprint the item they already show, and the "now" they print is
## the bonus the total gets.
func test_details_reprint_when_a_stat_levels() -> void:
	var tab: Control = _tab()
	var charm: EquipmentDefinitionData = _spirit_charm()
	InventoryManager.award_items(charm, 1)
	InventoryManager.equip_item(InventoryManager.get_inventory().equipment[0], charm.slot_type, 0)
	tab.open_page()
	var details: EquipmentDetails = _details(tab)
	var before: Array[String] = _bonus_texts(details)
	CharacterManager.set_stat_level(CharacterAttributesData.AttributeType.SPIRIT, 5)
	var after: Array[String] = _bonus_texts(details)
	assert_ne(after, before, "the Spirit line moved")
	assert_eq(after, BookText.gear_bonus_lines(charm, CharacterManager.get_trained_values()))
	var now: String = "+%d now" % roundi(CharacterManager.get_gear_bonus(CharacterAttributesData.AttributeType.SPIRIT))
	assert_true(after.size() == 1 and after[0].ends_with(now), "the now printed is the bonus applied: %s" % [after])
```

Create `tests/integration/test_item_description_panel.gd` (`extends GutTest`; header: "ItemDescriptionPanel, ItemDisplaySlot's hover tooltip: its gear lines, reprinted when a stat levels.") with the save swap from Global Constraints in `before_each()` / `after_each()`, `_spirit_charm()`, `_panel() -> ItemDescriptionPanel` (instances `res://scenes/common/item_description_panel/item_description_panel.tscn` with `add_child_autofree()`, then awaits one process frame), `_effects(panel) -> String` (the `%EffectsLabel` text), and:

```gdscript
func test_gear_prints_each_bonus_line() -> void:
	var panel: ItemDescriptionPanel = await _panel()
	var charm: EquipmentDefinitionData = _spirit_charm()
	charm.ward = 4.0
	panel.setup_from_definition(charm)
	for line: String in BookText.gear_bonus_lines(charm, CharacterManager.get_trained_values()):
		assert_string_contains(_effects(panel), line)

func test_gear_reprints_when_a_stat_levels() -> void:
	var panel: ItemDescriptionPanel = await _panel()
	var charm: EquipmentDefinitionData = _spirit_charm()
	panel.setup_from_definition(charm)
	var before: String = _effects(panel)
	CharacterManager.set_stat_level(CharacterAttributesData.AttributeType.SPIRIT, 5)
	assert_ne(_effects(panel), before, "the Spirit line moved")
	assert_string_contains(_effects(panel), BookText.gear_bonus_lines(charm, CharacterManager.get_trained_values())[0])
```

In `tests/integration/test_merchant_shop_flow.gd`, under `# SHOP VIEW`, add `_spirit_charm()`, `_selling(item: EquipmentDefinitionData) -> MerchantActionData` (`_action_selling()` over a typed `Array[MerchantStockEntry]` holding one new entry with `entry_id = item.item_id` and `item = item`), and:

```gdscript
func test_gear_rows_reprint_their_detail_when_a_stat_levels() -> void:
	var charm: EquipmentDefinitionData = _spirit_charm()
	var view := await _make_view()
	view.setup(_selling(charm))
	var detail: RichTextLabel = _visible_rows(view)[0].get_node("%DetailLabel")
	var before: String = detail.text
	CharacterManager.set_stat_level(CharacterAttributesData.AttributeType.SPIRIT, 5)
	assert_ne(detail.text, before, "the Spirit line moved")
	assert_string_contains(detail.text, BookText.gear_bonus_lines(charm, CharacterManager.get_trained_values())[0])

func test_a_long_gear_detail_wraps() -> void:
	var charm: EquipmentDefinitionData = _spirit_charm()
	for key: StringName in [&"strength", &"body", &"agility", &"mind", &"control"]:
		charm.stat_percent_bonuses[key] = 0.5
	charm.armor = 6.0
	charm.ward = 4.0
	var view := await _make_view()
	view.setup(_selling(charm))
	view.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	var detail: RichTextLabel = _visible_rows(view)[0].get_node("%DetailLabel")
	assert_gt(detail.get_line_count(), 1, "a long detail wraps instead of widening the row")
```

In `tests/integration/test_boards_never_trim_text.gd`, add `"res://scenes/inventory/inventory_view/equipment_tab/equipment_details/bonus_row.tscn": ["LeftBonus", "RightBonus"],` to the `wrapping` dictionary in `test_the_labels_that_can_run_long_wrap`.

- [ ] **Step 2: Run them and see them fail.** `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/unit/test_book_text.gd,res://tests/integration/test_equipment_page.gd,res://tests/integration/test_item_description_panel.gd,res://tests/integration/test_merchant_shop_flow.gd,res://tests/integration/test_boards_never_trim_text.gd -gexit`
  Expected: FAIL: the first four scripts don't parse (no `BookText.gear_bonus_lines()`), and `test_the_labels_that_can_run_long_wrap` fails because LeftBonus doesn't wrap.

- [ ] **Step 3: Implement `gear_bonus_lines()` and the three readers**
  - `BookText.gear_bonus_lines()` walks `CharacterAttributesData.AttributeType.values()` in order. Each stat with a percent above 0 under `stat_key(stat)` gives `"%s%% %s%s%s now" % [_signed(percent * 100.0), CharacterManager.get_attribute_display_name(stat), _EFFECT_SEPARATOR, _signed(bonus)]`, where `bonus` is `def.get_stat_bonus(stat, trained_values.get(stat, CharacterAttributesData.STAT_BASELINE))`. Then `"Armor %s"` and `"Ward %s"`, each when above 0, through a new `_plain(value: float) -> String` ("6", "6.5"). Its doc: the now comes from `get_stat_bonus()`, as the totals' bonus does, so card and total can't disagree. Delete `bonus_lines()`; the class doc says "gear bonus lines".
  - `EquipmentDefinitionData`: delete `attribute_bonuses` with its legacy doc, and the `_get_item_effects()` override.
  - `EquipmentDetails`: `_ready()` connects `CharacterManager.stats_changed` to `_on_stats_changed()`, which calls `_print_item(_item.item_definition)` while `_item` is set, deliberately bypassing `show_item()`'s same-item return and `EquipmentTab._show_slot()`'s same-slot return. `_print_item()` takes its bonuses from `BookText.gear_bonus_lines(equipment, CharacterManager.get_trained_values())`. Its class doc and `BonusRow`'s say "+10% Strength · +1 now" for "+2 Strength", and `BonusRow.setup()`'s doc names `gear_bonus_lines()`.
  - Layout per the approved gear-text board: `_BONUSES_PER_ROW`, BonusRow's label widths, and `equipment_details.tscn` if the panel must grow with its rows. Either way `%LeftBonus` and `%RightBonus` get `autowrap_mode = 3`, and `test_long_names_wrap_inside_the_panel` stays green.
  - `ItemDescriptionPanel`: `var _item: ItemInstanceData = null`, set by `setup()`, cleared by `reset()`. For equipment, `setup()` prints the gear lines (with `CharacterManager.get_trained_values()`), each as `"[color=#a89070]%s[/color]"` (today's effect ink), joined by `"\n"`; other items keep `def._get_item_effects()`. `_ready()` connects `CharacterManager.stats_changed` to `_on_stats_changed()`, which calls `setup(_item)` while `_item` holds equipment. The class doc says gear lines reprint when a stat changes.
  - `MerchantStockRow`: for equipment, `_format_detail()` keeps today's slot word and joins the same coloured gear lines with `", "` (doc example: "Main Hand: +30% Strength · +3 now, +10% Agility · +2 now"). `_ready()` also connects `stats_changed` to `_on_stats_changed()`, which sets `_detail_label.text = _format_detail(_entry.item)` while `_entry` sells equipment. In `merchant_stock_row.tscn`, delete `%DetailLabel`'s `autowrap_mode = 0` (a RichTextLabel wraps by word by default, growing the row down).
  - Delete the `attribute_bonuses = { … }` block from the seven Spirit Valley `.tres` files (the loader would skip the undeclared property silently), then rerun Task 1.7's generator command. Expected: `ItemsMdGenerator: created=0 updated=0 skipped=7 orphans=0`.
  - Run `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --import` to write `tests/integration/test_item_description_panel.gd.uid` (test runs import nothing). Expected: `git status --short project.godot` prints nothing.

- [ ] **Step 4: Run them and see them pass.** The Step 2 command with `res://tests/unit/test_equipment.gd` and `res://tests/unit/test_items_md_parser.gd` added to `-gtest`.
  Expected: PASS.

- [ ] **Step 5: Commit.** Stage the files under **Files** (`equipment_details.tscn` only if the layout step changed it), then `git commit -m "feat(inventory): print gear percents and their now"`. Body: "The book, the item tooltip and the shop print '+30% Strength · +3 now', 'Armor 6' and 'Ward 4' from one builder that uses the stat totals' own per-item bonus. Each reader reprints on stats_changed, so a Spirit level gained with the book open shows at once. attribute_bonuses and its dead file entries go." (+ Co-Authored-By line)

---

### Task 1.9: Main-stat-only technique scaling and enemy defences

Before Step 1, invoke `godot-prompter:resource-pattern` and `godot-prompter:godot-testing`.

**Files:**
- Modify: `scripts/resource_definitions/combat/combat_effect_data.gd` (the scaling exports, `get_scaling()`, `calculate_value()`)
- Modify: `resources/abilities/basic_strike.tres`, `resources/abilities/empty_palm.tres`, `resources/abilities/power_font.tres`, `resources/combat/combatant_data/enemy_abilities/famishing_bite.tres`, `resources/combat/combatant_data/enemy_abilities/madra_lash.tres`, `resources/combat/combatant_data/amorphous_spirit.tres`, `resources/combat/combatant_data/coalescing_spirit.tres`, `resources/combat/combatant_data/starving_dreadbeast.tres`, `resources/combat/combatant_data/ravenous_dreadbeast.tres`
- Modify: `scenes/abilities/abilities_view.gd` (the doc of `_show_value_breakdown()`)
- Create: `tests/unit/test_combat_content.gd`
- Test: `tests/unit/test_combat_effect_data.gd`, `tests/unit/test_combat_damage.gd`, `tests/unit/test_technique_slot_math.gd`, `tests/integration/test_abilities_book.gd`, `tests/integration/test_character_book.gd`

**Interfaces:**
- Consumes (Task 1.1): `CharacterAttributesData.make()` with its `armor` and `ward` fields; `CombatEffectData.calculate_damage()` defended by armor and Ward; the export `CombatEffectData.mind_scaling` (removed here).
- Produces: `CombatEffectData` scales through `strength_scaling` and `spirit_scaling` only. `get_scaling(attribute: CharacterAttributesData.AttributeType) -> float` is 0.0 for Body, Agility, Mind and Control. `calculate_value(caster_attributes: CharacterAttributesData) -> float` = `base_value + strength_scaling * caster_attributes.strength + spirit_scaling * caster_attributes.spirit`. The four enemy stat blocks carry armor and Ward, every value written out.

- [ ] **Step 1: Write the content lock.** Create `tests/unit/test_combat_content.gd`, under `#----` CONSTANTS, HELPERS and TESTS headers:

```gdscript
extends GutTest

## Content lock: a Lv 1 fight (every stat 10, no gear) keeps its numbers. The
## techniques, the enemy blocks with armor and Ward, and the hits after defence.

const BASIC_STRIKE: AbilityData = preload("res://resources/abilities/basic_strike.tres")
const EMPTY_PALM: AbilityData = preload("res://resources/abilities/empty_palm.tres")
const POWER_FONT: AbilityData = preload("res://resources/abilities/power_font.tres")
const FAMISHING_BITE: AbilityData = preload("res://resources/combat/combatant_data/enemy_abilities/famishing_bite.tres")
const MADRA_LASH: AbilityData = preload("res://resources/combat/combatant_data/enemy_abilities/madra_lash.tres")
const COALESCE: AbilityData = preload("res://resources/combat/combatant_data/enemy_abilities/coalesce.tres")
const AMORPHOUS_SPIRIT: CombatantData = preload("res://resources/combat/combatant_data/amorphous_spirit.tres")
const COALESCING_SPIRIT: CombatantData = preload("res://resources/combat/combatant_data/coalescing_spirit.tres")
const STARVING_DREADBEAST: CombatantData = preload("res://resources/combat/combatant_data/starving_dreadbeast.tres")
const RAVENOUS_DREADBEAST: CombatantData = preload("res://resources/combat/combatant_data/ravenous_dreadbeast.tres")

## The damage effect of an ability: its first effect on the target.
func _damage_of(ability: AbilityData) -> CombatEffectData:
	return ability.effects_on_target[0]

## Armor 10 and Ward 10 cut the player's hits as Resilience 10 and Spirit 10
## did; Ward 25 as the Coalescing Spirit's Spirit 25 did.
func test_enemy_stat_blocks() -> void:
	var cases: Array[Dictionary] = [
		{"name": "Amorphous Spirit", "enemy": AMORPHOUS_SPIRIT, "block": {&"strength": 10.0, &"body": 10.0, &"agility": 10.0,
			&"spirit": 10.0, &"mind": 10.0, &"control": 10.0, &"armor": 10.0, &"ward": 10.0}},
		{"name": "Coalescing Spirit", "enemy": COALESCING_SPIRIT, "block": {&"strength": 10.0, &"body": 20.0, &"agility": 10.0,
			&"spirit": 25.0, &"mind": 10.0, &"control": 10.0, &"armor": 10.0, &"ward": 25.0}},
		{"name": "Starving Dreadbeast", "enemy": STARVING_DREADBEAST, "block": {&"strength": 10.0, &"body": 8.5, &"agility": 10.0,
			&"spirit": 10.0, &"mind": 12.0, &"control": 10.0, &"armor": 10.0, &"ward": 10.0}},
		{"name": "Ravenous Dreadbeast", "enemy": RAVENOUS_DREADBEAST, "block": {&"strength": 15.0, &"body": 8.5, &"agility": 10.0,
			&"spirit": 10.0, &"mind": 12.0, &"control": 10.0, &"armor": 10.0, &"ward": 10.0}},
	]
	for case: Dictionary in cases:
		var attributes: CharacterAttributesData = (case["enemy"] as CombatantData).attributes
		for key: StringName in case["block"]:
			assert_eq(attributes.get(key), case["block"][key], "%s: %s" % [case["name"], key])

## Each technique scales from its side's main stat only and keeps its Lv 1 hit.
func test_player_techniques_at_lv_1() -> void:
	var cases: Array[Dictionary] = [
		{"name": "Basic Strike", "ability": BASIC_STRIKE, "type": CombatEffectData.DamageType.PHYSICAL, "strength": 1.5, "spirit": 0.0, "value": 25.0},
		{"name": "Empty Palm", "ability": EMPTY_PALM, "type": CombatEffectData.DamageType.SPIRIT, "strength": 0.0, "spirit": 1.3, "value": 28.0},
		{"name": "Power Font", "ability": POWER_FONT, "type": CombatEffectData.DamageType.SPIRIT, "strength": 0.0, "spirit": 2.0, "value": 50.0},
	]
	for case: Dictionary in cases:
		var effect: CombatEffectData = _damage_of(case["ability"])
		assert_eq(effect.damage_type, case["type"], "%s: damage type" % case["name"])
		assert_almost_eq(effect.strength_scaling, case["strength"], 0.0001, "%s: per Strength" % case["name"])
		assert_almost_eq(effect.spirit_scaling, case["spirit"], 0.0001, "%s: per Spirit" % case["name"])
		assert_almost_eq(effect.calculate_value(CharacterAttributesData.make()), case["value"], 0.001, "%s: at Lv 1" % case["name"])

## Lv 1 hits after defence: x 100 / (100 + armor), with Ward for Spirit damage.
func test_player_hits_after_enemy_defence() -> void:
	var cases: Array[Dictionary] = [
		{"name": "Basic Strike on the Amorphous Spirit", "ability": BASIC_STRIKE, "enemy": AMORPHOUS_SPIRIT, "damage": 25.0 * 100.0 / 110.0},
		{"name": "Basic Strike on the Coalescing Spirit", "ability": BASIC_STRIKE, "enemy": COALESCING_SPIRIT, "damage": 25.0 * 100.0 / 110.0},
		{"name": "Basic Strike on a Ravenous Dreadbeast", "ability": BASIC_STRIKE, "enemy": RAVENOUS_DREADBEAST, "damage": 25.0 * 100.0 / 110.0},
		{"name": "Empty Palm on a Starving Dreadbeast", "ability": EMPTY_PALM, "enemy": STARVING_DREADBEAST, "damage": 28.0 * 100.0 / 110.0},
		{"name": "Empty Palm on the Coalescing Spirit", "ability": EMPTY_PALM, "enemy": COALESCING_SPIRIT, "damage": 22.4},
		{"name": "Power Font on the Amorphous Spirit", "ability": POWER_FONT, "enemy": AMORPHOUS_SPIRIT, "damage": 50.0 * 100.0 / 110.0},
		{"name": "Power Font on the Coalescing Spirit", "ability": POWER_FONT, "enemy": COALESCING_SPIRIT, "damage": 40.0},
	]
	for case: Dictionary in cases:
		var enemy: CombatantData = case["enemy"]
		assert_almost_eq(_damage_of(case["ability"]).calculate_damage(CharacterAttributesData.make(), enemy.attributes),
			case["damage"], 0.001, case["name"])

## At 0.91 per point, enemy hits on a Lv 1 player (no armor or Ward) land what
## Resilience 10 and Spirit 10 let through before.
func test_enemy_techniques_on_a_lv_1_player() -> void:
	var cases: Array[Dictionary] = [
		{"name": "Famishing Bite from a Starving Dreadbeast", "ability": FAMISHING_BITE, "enemy": STARVING_DREADBEAST, "damage": 9.1},
		{"name": "Famishing Bite from a Ravenous Dreadbeast", "ability": FAMISHING_BITE, "enemy": RAVENOUS_DREADBEAST, "damage": 13.65},
		{"name": "Madra Lash from the Amorphous Spirit", "ability": MADRA_LASH, "enemy": AMORPHOUS_SPIRIT, "damage": 9.1},
		{"name": "Madra Lash from the Coalescing Spirit", "ability": MADRA_LASH, "enemy": COALESCING_SPIRIT, "damage": 22.75},
	]
	for case: Dictionary in cases:
		var enemy: CombatantData = case["enemy"]
		assert_almost_eq(_damage_of(case["ability"]).calculate_damage(enemy.attributes, CharacterAttributesData.make()),
			case["damage"], 0.001, case["name"])

## Coalesce heals 3 per Spirit: 75 for the Coalescing Spirit, with no defence.
func test_coalesce_heals_from_spirit() -> void:
	assert_almost_eq(COALESCE.get_total_self_heal(COALESCING_SPIRIT.attributes), 75.0, 0.001)
```

- [ ] **Step 2: Move the scaling unit tests to the main stats.**
  - **`tests/unit/test_combat_effect_data.gd`:** replace `test_get_scaling_reads_each_attribute_field` and `test_get_scaling_is_zero_when_unset` with the three tests below, keep `test_contribution_is_the_attribute_times_its_scaling`, and delete the `mind_scaling = 0.5` line of `test_base_plus_contributions_is_the_calculated_value`.

```gdscript
## No other stat has a scaling field, so no technique file can set one.
func test_only_the_main_stats_have_a_scaling() -> void:
	var effect := CombatEffectData.new()
	for property: String in ["body_scaling", "agility_scaling", "mind_scaling", "control_scaling"]:
		assert_false(property in effect, "%s is gone" % property)
	assert_true("strength_scaling" in effect, "Strength scales Physical techniques")
	assert_true("spirit_scaling" in effect, "Spirit scales Spirit techniques")

## get_scaling() reads Strength's and Spirit's scaling. Every other stat scales nothing.
func test_get_scaling_reads_strength_and_spirit_only() -> void:
	var effect := CombatEffectData.new()
	effect.strength_scaling = 1.5
	effect.spirit_scaling = 2.0
	var cases: Array[Dictionary] = [
		{"stat": CharacterAttributesData.AttributeType.STRENGTH, "scaling": 1.5},
		{"stat": CharacterAttributesData.AttributeType.BODY, "scaling": 0.0},
		{"stat": CharacterAttributesData.AttributeType.AGILITY, "scaling": 0.0},
		{"stat": CharacterAttributesData.AttributeType.SPIRIT, "scaling": 2.0},
		{"stat": CharacterAttributesData.AttributeType.MIND, "scaling": 0.0},
		{"stat": CharacterAttributesData.AttributeType.CONTROL, "scaling": 0.0},
	]
	for case: Dictionary in cases:
		assert_eq(effect.get_scaling(case["stat"]), case["scaling"], CharacterAttributesData.AttributeType.keys()[case["stat"]])

## calculate_value() counts Strength and Spirit only, however high the other four are.
func test_value_ignores_the_other_stats() -> void:
	var effect := CombatEffectData.new()
	effect.base_value = 10.0
	effect.strength_scaling = 1.5
	effect.spirit_scaling = 2.0
	var mains := CharacterAttributesData.make({&"strength": 12.0, &"spirit": 14.0})
	var all_high := CharacterAttributesData.make({&"strength": 12.0, &"spirit": 14.0,
		&"body": 99.0, &"agility": 99.0, &"mind": 99.0, &"control": 99.0})
	assert_eq(effect.calculate_value(mains), 56.0, "10 + 12 x 1.5 + 14 x 2")
	assert_eq(effect.calculate_value(all_high), 56.0, "Body, Agility, Mind and Control add nothing")
```

  - **`tests/unit/test_combat_damage.gd`, `test_value_adds_each_attribute_times_its_scaling`:** delete the body, agility, mind and control cases. Its doc becomes `## calculate_value() is base_value plus Strength and Spirit times their scalings: no scaling, a zero base, each main stat on its own (caster at 10 in everything), both together, and a high Strength.`

- [ ] **Step 3: Move three screen tests to main-stat scaling.**
  - **`tests/unit/test_technique_slot_math.gd`, `test_format_damage`:** the precondition becomes `assert_eq(amount, 30, "precondition: 10 + 13 x 1.5 = 29.5, rounded")`. `strong` stays as Task 1.1 left it; its Agility no longer counts.
  - **`tests/integration/test_abilities_book.gd`, `test_damage_shows_the_total_and_each_attributes_part`:** delete `agility_part` and the two asserts that read it, make the visibility assert `assert_true(strength_part.visible)`, and point the hidden-part assert at `ScalingPart2` with the message "Basic Strike scales with Strength alone". It keeps its name, and the file keeps `AGILITY_ICON`: Task 1.15 replaces the test and deletes both icon consts.
  - **`tests/integration/test_character_book.gd`** (Task 1.16 later rewrites the file): `test_effects_list_unlocked_abilities_that_scale_with_it` (doc `## A technique scales from its side's main stat only.`) asserts, after each `_view.select_attribute(CharacterAttributesData.AttributeType.X)`, that `EffectsLabel` contains `_scaling_line("res://resources/abilities/basic_strike.tres", X)` for X = STRENGTH, `_scaling_line("res://resources/abilities/empty_palm.tres", X)` for X = SPIRIT, and no "Basic Strike" for X = AGILITY (message "Agility scales no technique").

- [ ] **Step 4: Run them and see them fail.**
  - Command: `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/unit/test_combat_content.gd,res://tests/unit/test_combat_effect_data.gd,res://tests/unit/test_combat_damage.gd,res://tests/unit/test_technique_slot_math.gd,res://tests/integration/test_abilities_book.gd,res://tests/integration/test_character_book.gd -gexit`
  - Expected: FAIL: `test_combat_content.gd` (Basic Strike's `strength_scaling` is 1.0, enemy armor and Ward are 0.0, Famishing Bite hits for 10), `test_combat_effect_data.gd` ("body_scaling is gone"), `test_technique_slot_math.gd` (27), `test_abilities_book.gd` (ScalingPart2 shows Agility), `test_character_book.gd` (Agility lists Basic Strike). `test_combat_damage.gd` passes, having only lost cases.

- [ ] **Step 5: Implement main-stat scaling in `scripts/resource_definitions/combat/combat_effect_data.gd`.**
  - **Exports:** delete `body_scaling`, `agility_scaling`, `mind_scaling` and `control_scaling`. The Attribute Scaling group keeps `strength_scaling` (doc `## Scales with the caster's Strength: Physical techniques.`) and `spirit_scaling` (doc `## Scales with the caster's Spirit: Spirit techniques and heals.`).
  - **`get_scaling()`:** two match arms, STRENGTH and SPIRIT. Any other stat returns 0.0, without the `Log.error`.
  - **`calculate_value()`:** the AttributeType loop and its per-stat `Log.info` lines become the two-term sum in Interfaces. The null-caster guard and the other `Log.info` lines stay.
  - **`get_scaling_contribution()`:** the body stays; its doc adds "0 for any stat but Strength and Spirit".
  - **`scenes/abilities/abilities_view.gd`:** the example in the doc of `_show_value_breakdown()` becomes `"10 base" then Strength "+15"`.

- [ ] **Step 6: Retune the five technique files.** Set or delete these lines in each damage sub-resource; every other line stays.

| File | Sub-resource | Set | Delete |
|---|---|---|---|
| `resources/abilities/basic_strike.tres` | `Resource_dx6op` | `strength_scaling = 1.5` | `agility_scaling = 0.5` |
| `resources/abilities/empty_palm.tres` | `Resource_damage` | `spirit_scaling = 1.3` | `agility_scaling = 0.3` |
| `resources/abilities/power_font.tres` | `Resource_damage` | `spirit_scaling = 2.0` | `mind_scaling = 0.5` |
| `resources/combat/combatant_data/enemy_abilities/famishing_bite.tres` | `Resource_8emjg` | `strength_scaling = 0.91` | |
| `resources/combat/combatant_data/enemy_abilities/madra_lash.tres` | `Resource_m6bjc` | `spirit_scaling = 0.91` | |

- [ ] **Step 7: Write out the four enemy stat blocks.** The `attributes` sub-resources are `Resource_wrvmu` (`amorphous_spirit.tres`), `Resource_ygc7y` (`coalescing_spirit.tres`) and `Resource_xwkgh` (`starving_dreadbeast.tres`, `ravenous_dreadbeast.tres`). In each, the lines between `script = ExtResource(...)` and `metadata/_custom_type_script = ...` become eight lines, `strength` to `ward` in the order `test_enemy_stat_blocks` lists them, with its values. Default values are written too, so a later default change can't rewrite them. The dreadbeasts' `mind = 12.0` (Task 1.1's rename of `foundation`) is their `mind` line.

- [ ] **Step 8: Check that nothing names a removed scaling or a deleted display script.**
  - Command: `git grep -n -E "(body|agility|mind|control|foundation)_scaling|AbilityStatsDisplay|StatLabel|StatTooltip" -- . ":!addons" ":!docs" ":!tests/unit/test_combat_effect_data.gd"`
  - Expected: no output. `test_combat_effect_data.gd` is left out because `test_only_the_main_stats_have_a_scaling` names the four removed scalings on purpose; Task 1.1 deleted AbilityStatsDisplay, StatLabel and StatTooltip, the last other readers.

- [ ] **Step 9: Run them and see them pass.** Run the Step 4 command, then the full suite: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_tests.ps1`. Expected: PASS for both.

- [ ] **Step 10: Commit.**
  - Stage the Files list above and `tests/unit/test_combat_content.gd.uid`, which Godot writes for a new script. If it is missing, run `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --import` once and check that `git status --short project.godot` prints nothing.
  - Commit: `git commit -m "feat(combat): scale techniques from main stats only" -m "A technique scales from Strength or Spirit alone, and enemies defend with armor and Ward. The retune keeps every Lv 1 hit, the player's and the enemies'." -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"`

---

### Task 1.10: Dodge

Before Step 1, invoke `godot-prompter:hud-system` and `godot-prompter:godot-testing`.

**Files:**
- Modify: `scenes/combat/combatant/combat_effect_manager/combat_effect_manager.gd` (new DODGE section)
- Modify: `scenes/combat/combatant/combatant_visual/combatant_visual.gd` (`play_dodge()`)
- Modify: `scenes/combat/combatant/combat_ability_manager/combat_ability_instance.gd` (`execute_ability()`, new `_dodged_by()`, the class doc)
- Create: `tests/unit/test_combat_dodge.gd`

**Interfaces:**
- Consumes: `CharacterAttributesData.get_dodge_chance() -> float` (Task 1.1; 0 at Agility 10).
- Produces: `CombatEffectManager.dodge_roll: Callable` (returns a float in [0, 1)) and `CombatEffectManager.try_dodge() -> bool`; `CombatantVisual.play_dodge() -> void`; `CombatAbilityInstance.execute_ability(target: CombatantNode) -> void` asks the target before its effects land.

- [ ] **Step 1: Write the failing test.** Create `tests/unit/test_combat_dodge.gd` (`#----` CONSTANTS, HELPERS and TESTS headers). Helpers:
  - `_combatant(character_name: String, is_player: bool, attributes: CharacterAttributesData) -> CombatantNode`: an autofreed `CombatantNode.new()`, never in the tree, with `is_player` and a `CombatantData` (the name, `attributes`). Its `vitals_manager` is a `VitalsManager` with `character_attributes_data = attributes` and `initialize_current_values()`; its `ability_manager`, `buff_manager` and `effect_manager` are new managers, each `setup(fighter)`. All four go in with `add_child_autofree()`.
  - `_fix_roll(fighter: CombatantNode, roll: float) -> void` sets `fighter.effect_manager.dodge_roll = func() -> float: return roll`.
  - `_instance(ability: AbilityData, caster: CombatantNode) -> CombatAbilityInstance`: `CombatAbilityInstance.new(ability, caster)`, a child of `caster.ability_manager`.
  - `_start_casting(fighter: CombatantNode) -> CombatAbilityInstance`, as `test_empty_palm_interrupt.gd` does: an `_instance()` of `test_long_cast` ("Test Long Cast", cast 3 s, cooldown 5 s) appended to `fighter.ability_manager.abilities`, `is_casting = true`, `cast_timer.start(3.0)`.
  - `_bite() -> AbilityData`: `test_bite` ("Test Bite"): on the target a DAMAGE effect of base 10 (Physical), then a CANCEL_CAST effect; on itself a `BuffEffectData` `test_hunger`, OUTGOING_DAMAGE_MODIFIER, `damage_multiplier = 1.5`.
  - `_self_heal() -> AbilityData`: `test_coalesce` ("Test Coalesce"), one HEAL effect of base 5 on itself and none on the target.

  The rest of the file:

```gdscript
extends GutTest

## Dodge: only the player dodges, at its Agility's chance. A dodge skips every
## effect on the target, riders too; the caster's self effects still apply.

## Agility 25: 15 points above Lv 1, so the player can dodge.
const NIMBLE: float = 25.0

## Only the player dodges, on a roll under its chance. Lv 1 Agility has none.
func test_only_the_player_dodges_under_its_chance() -> void:
	var chance: float = CharacterAttributesData.make({&"agility": NIMBLE}).get_dodge_chance()
	assert_gt(chance, 0.0, "precondition: Agility 25 can dodge")
	var cases: Array[Dictionary] = [
		{"name": "the player, a roll just under its chance", "is_player": true, "agility": NIMBLE, "roll": chance - 0.001, "dodges": true},
		{"name": "the player, a roll at its chance", "is_player": true, "agility": NIMBLE, "roll": chance, "dodges": false},
		{"name": "the player at Lv 1 Agility, the lowest roll", "is_player": true, "agility": 10.0, "roll": 0.0, "dodges": false},
		{"name": "an enemy, however nimble", "is_player": false, "agility": 100.0, "roll": 0.0, "dodges": false},
	]
	for case: Dictionary in cases:
		var fighter: CombatantNode = _combatant("Fighter", case["is_player"], CharacterAttributesData.make({&"agility": case["agility"]}))
		_fix_roll(fighter, case["roll"])
		assert_eq(fighter.effect_manager.try_dodge(), case["dodges"], case["name"])

## A manager with no owner, or with an owner that has no data, never dodges.
func test_a_bare_node_never_dodges() -> void:
	var manager := CombatEffectManager.new()
	add_child_autofree(manager)
	manager.dodge_roll = func() -> float: return 0.0
	assert_false(manager.try_dodge(), "no owner")
	var fighter := CombatantNode.new()
	autofree(fighter)
	fighter.is_player = true
	manager.setup(fighter)
	assert_false(manager.try_dodge(), "an owner with no data")

## A dodge stops the damage and the interrupt riding on it, and is logged. The
## biter's Hunger still applies.
func test_a_dodge_skips_every_target_effect_but_not_the_casters_own() -> void:
	var player: CombatantNode = _combatant("Player", true, CharacterAttributesData.make({&"agility": NIMBLE}))
	_fix_roll(player, 0.0)
	var cast: CombatAbilityInstance = _start_casting(player)
	var beast: CombatantNode = _combatant("Dreadbeast", false, CharacterAttributesData.make())
	watch_signals(LogManager)
	_instance(_bite(), beast).execute_ability(player)
	assert_eq(player.vitals_manager.current_health, player.vitals_manager.max_health, "the damage never lands")
	assert_true(cast.is_casting, "nor does the interrupt")
	assert_eq(beast.buff_manager.active_buffs.size(), 1, "the biter's Hunger still applies")
	assert_signal_emitted_with_parameters(LogManager, "message_logged", ["[b]Player[/b] dodged Test Bite"])

## A roll over the chance lands the whole hit: the damage and the interrupt.
func test_a_missed_dodge_lands_the_hit() -> void:
	var player: CombatantNode = _combatant("Player", true, CharacterAttributesData.make({&"agility": NIMBLE}))
	_fix_roll(player, 0.99)
	var cast: CombatAbilityInstance = _start_casting(player)
	_instance(_bite(), _combatant("Dreadbeast", false, CharacterAttributesData.make())).execute_ability(player)
	assert_eq(player.vitals_manager.current_health, 90.0, "the bite's 10 damage lands (no armor)")
	assert_false(cast.is_casting, "and so does its interrupt")

## A cast with no effect on its target never rolls a dodge, though SimpleEnemyAI
## aims every cast at the player (Coalesce heals only its caster).
func test_a_cast_without_target_effects_never_rolls() -> void:
	var player: CombatantNode = _combatant("Player", true, CharacterAttributesData.make({&"agility": NIMBLE}))
	var rolls: Array[int] = [0]
	player.effect_manager.dodge_roll = func() -> float:
		rolls[0] += 1
		return 0.0
	_instance(_self_heal(), _combatant("Spirit", false, CharacterAttributesData.make())).execute_ability(player)
	assert_eq(rolls[0], 0, "no dodge is rolled for a self-heal aimed at the player")
```

- [ ] **Step 2: Run it and see it fail.**
  - Command: `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/unit/test_combat_dodge.gd -gexit`
  - Expected: FAIL: the script does not parse (`CombatEffectManager` has no `dodge_roll` or `try_dodge()`), so GUT runs none of its tests.

- [ ] **Step 3: Implement the roll in `scenes/combat/combatant/combat_effect_manager/combat_effect_manager.gd`.** After PUBLIC API, add a `#----` DODGE section with:
  - `var dodge_roll: Callable = func() -> float: return randf()`, doc `## The roll a dodge is checked against, a float in [0, 1). Tests swap in a fixed one (the TribulationView.clock_usec pattern).` A lambda, because GDScript can't use the utility function `randf` as a value.
  - `func try_dodge() -> bool` (`##` doc): false when `owner_combatant`, its `combatant_data` or their `attributes` is null, or `owner_combatant.is_player` is false. Otherwise `chance > 0.0 and float(dodge_roll.call()) < chance`, with `chance = owner_combatant.combatant_data.attributes.get_dodge_chance()`, so no roll is drawn at a chance of 0.

- [ ] **Step 4: Implement the floater in `scenes/combat/combatant/combatant_visual/combatant_visual.gd`.** Add `const DODGED_TEXT: String = "Dodged"`, `const COLOR_DODGE: Color` set to the colour of the approved Task 1.0 "Dodged" floater (it starts as `ThemeConstants.LACQUER_STAMINA`, Agility's Stamina green), and a `##`-documented `func play_dodge() -> void` that only calls `_spawn_number(DODGED_TEXT, COLOR_DODGE)`: no flash, no recoil.

- [ ] **Step 5: Ask the target in `execute_ability()`** (`scenes/combat/combatant/combat_ability_manager/combat_ability_instance.gd`).
  - The target-effects block runs only when `target` is set and has `receive_effect`, `ability_data.effects_on_target` is not empty, and `not _dodged_by(target)`, checked in that order so a cast with no target effect never rolls. The self-effects block stays outside that condition.
  - New `func _dodged_by(target: CombatantNode) -> bool` (`##` doc) under INTERNAL LOGIC: false when `target.effect_manager` is null or its `try_dodge()` is false. Otherwise it calls `target.visual.play_dodge()` when `target.visual` is set, logs `LogManager.log_message("[b]%s[/b] dodged %s" % [target.combatant_data.character_name, ability_data.ability_name])` and returns true.
  - The class doc's EXECUTION list gains "- The target may dodge: its effects are skipped, the caster's own still apply".

- [ ] **Step 6: Run them and see them pass.** Run the Step 2 command with `,res://tests/unit/test_combat_effect_types.gd,res://tests/integration/test_technique_dock.gd` added to `-gtest`, then the full suite (`tests/run_tests.ps1`, as in Task 1.9). Expected: PASS for both.

- [ ] **Step 7: Commit.** Stage the Files list above and `tests/unit/test_combat_dodge.gd.uid` (as in Task 1.9), then `git commit -m "feat(combat): let the player dodge hits with Agility" -m "Agility's third job. Only the player dodges, so the player's own hits never miss for a reason the player can't see." -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"`

---

### Task 1.11: Control's Madra cost and cooldown cuts

Before Step 1, invoke `godot-prompter:ability-system` and `godot-prompter:godot-testing`.

**Files:**
- Modify: `scripts/resource_definitions/abilities/ability_data.gd`, `scenes/combat/combatant/combat_ability_manager/combat_ability_instance.gd`, `scenes/combat/combatant/combat_ability_manager/combat_ability_manager.gd`
- Modify: `scenes/ui/combat/technique_dock/technique_slot/technique_slot.gd`, `scenes/ui/combat/technique_dock/technique_tooltip/technique_tooltip.gd`, `scenes/abilities/ability_row/ability_row.gd`, `scenes/abilities/abilities_view.gd` (`_show_details()`)
- Create: `tests/unit/test_ability_data.gd`, `tests/unit/test_control_cuts.gd`
- Test: `tests/unit/test_technique_slot_math.gd`, `tests/integration/test_technique_dock.gd`, `tests/integration/test_abilities_book.gd`

**Interfaces:**
- Consumes: `CharacterAttributesData.get_madra_cost_cut()` and `get_cooldown_cut()` (Task 1.1; 0 at Control 10); `CharacterManager.get_stat(StatModifierData.Stat.MADRA_COST_CUT)` and `get_stat(StatModifierData.Stat.COOLDOWN_CUT)` (Task 1.5); `execute_ability()` as Task 1.10 left it.
- Produces:
  - `AbilityData.get_madra_cost(cost_cut: float = 0.0) -> float` = `roundf(madra_cost * (1.0 - cost_cut))` and `get_cooldown(cooldown_cut: float = 0.0) -> float` = `base_cooldown * (1.0 - cooldown_cut)`; `can_afford()` and `consume_costs()` gain `cost_cut: float = 0.0`.
  - `CombatAbilityInstance.get_cost_cut() -> float` and `get_cooldown_cut() -> float`: the player's cuts, 0.0 for an enemy or no owner. `cooldown_started(duration)` carries the duration actually started.
  - `AbilityRow.format_cost(ability_data: AbilityData, cost_cut: float = 0.0) -> String` and `format_costs(ability_data: AbilityData, cost_cut: float = 0.0, cooldown_cut: float = 0.0) -> String`.
  - `TechniqueSlot.is_cost_affordable() -> bool`.

- [ ] **Step 1: Write the failing AbilityData tests.** Create `tests/unit/test_ability_data.gd`:

```gdscript
extends GutTest

## AbilityData's Madra cost and cooldown under Control's cuts. Stamina and
## Health costs are never cut.

## The Madra a cast costs after a cut, rounded to whole Madra (a half rounds up).
func test_madra_cost_is_cut_and_rounded() -> void:
	var cases: Array[Dictionary] = [
		{"name": "no cut", "cost": 10.0, "cut": 0.0, "paid": 10.0},
		{"name": "a quarter off 8 Madra", "cost": 8.0, "cut": 0.25, "paid": 6.0},
		{"name": "a half rounds up: 10 less a quarter is 7.5, paid as 8", "cost": 10.0, "cut": 0.25, "paid": 8.0},
		{"name": "under a half rounds down: 29.28 is paid as 29", "cost": 30.0, "cut": 0.024, "paid": 29.0},
		{"name": "a free technique stays free", "cost": 0.0, "cut": 0.25, "paid": 0.0},
	]
	for case: Dictionary in cases:
		var ability := AbilityData.new()
		ability.madra_cost = case["cost"]
		assert_eq(ability.get_madra_cost(case["cut"]), case["paid"], case["name"])

## The cooldown after a cut, not rounded. A technique with no cooldown keeps none.
func test_cooldown_is_cut() -> void:
	var cases: Array[Dictionary] = [
		{"name": "no cut", "cooldown": 2.0, "cut": 0.0, "expected": 2.0},
		{"name": "a fifth off 2 s", "cooldown": 2.0, "cut": 0.2, "expected": 1.6},
		{"name": "a fifth off 15 s", "cooldown": 15.0, "cut": 0.2, "expected": 12.0},
		{"name": "no cooldown stays none", "cooldown": 0.0, "cut": 0.2, "expected": 0.0},
	]
	for case: Dictionary in cases:
		var ability := AbilityData.new()
		ability.base_cooldown = case["cooldown"]
		assert_almost_eq(ability.get_cooldown(case["cut"]), case["expected"], 0.0001, case["name"])

## The check and the payment use the cut Madra cost; Stamina is paid in full.
func test_costs_are_checked_and_paid_after_the_cut() -> void:
	var ability := AbilityData.new()
	ability.madra_cost = 8.0
	ability.stamina_cost = 3.0
	var vitals := VitalsManager.new()
	add_child_autofree(vitals)
	vitals.current_madra = 6.0
	vitals.current_stamina = 3.0
	assert_false(ability.can_afford(vitals), "6 Madra can't pay the full 8")
	assert_true(ability.can_afford(vitals, 0.25), "but can pay 8 cut by a quarter")
	assert_true(ability.consume_costs(vitals, 0.25), "the payment goes through")
	assert_eq(vitals.current_madra, 0.0, "6 Madra paid, not 8")
	assert_eq(vitals.current_stamina, 0.0, "the Stamina cost is paid in full")
```

- [ ] **Step 2: Write the failing fight tests.** Create `tests/unit/test_control_cuts.gd` (`#----` CONSTANTS, HELPERS and TESTS headers). Helpers:
  - `_technique(madra_cost: float, base_cooldown: float, cast_time: float = 0.0) -> AbilityData`: `test_technique` ("Test Technique"), those fields, no effects.
  - `_fighter(is_player: bool, control: float) -> CombatantNode`: an autofreed `CombatantNode.new()`, never in the tree, with `is_player` and a `CombatantData` named "Player" or "Enemy" holding `CharacterAttributesData.make({&"control": control})`.
  - `_instance(ability: AbilityData, fighter: CombatantNode) -> CombatAbilityInstance`: `CombatAbilityInstance.new(ability, fighter)` added with `add_child_autofree()` (its opening cooldown runs).

  The rest of the file:

```gdscript
extends GutTest

## Control's cuts in a fight, the player's only. A cast, a cancelled cast and the
## cast gate use them; the opening cooldown does not.

## Control 30: 20 points above Lv 1, so both cuts are well above 0.
const CONTROL: float = 30.0

## The cuts come from the player's snapshot; an enemy or an unowned instance has none.
func test_only_the_player_has_cuts() -> void:
	var snapshot := CharacterAttributesData.make({&"control": CONTROL})
	assert_gt(snapshot.get_cooldown_cut(), 0.0, "precondition: Control 30 cuts")
	var player: CombatAbilityInstance = _instance(_technique(8.0, 3.0), _fighter(true, CONTROL))
	assert_eq(player.get_cost_cut(), snapshot.get_madra_cost_cut(), "the player's Madra cost cut")
	assert_eq(player.get_cooldown_cut(), snapshot.get_cooldown_cut(), "the player's cooldown cut")
	var enemy: CombatAbilityInstance = _instance(_technique(8.0, 3.0), _fighter(false, CONTROL))
	assert_eq(enemy.get_cost_cut(), 0.0, "an enemy's Madra costs are never cut")
	assert_eq(enemy.get_cooldown_cut(), 0.0, "nor are its cooldowns")
	var unowned: CombatAbilityInstance = _instance(_technique(8.0, 3.0), null)
	assert_eq(unowned.get_cost_cut(), 0.0, "no owner: no Madra cost cut")
	assert_eq(unowned.get_cooldown_cut(), 0.0, "no owner: no cooldown cut")

## A cast starts the cut cooldown and reports it on cooldown_started.
func test_a_cast_starts_the_cut_cooldown() -> void:
	var technique: AbilityData = _technique(0.0, 2.0)
	var instance: CombatAbilityInstance = _instance(technique, _fighter(true, CONTROL))
	var cooldown: float = technique.get_cooldown(instance.get_cooldown_cut())
	assert_lt(cooldown, 2.0, "precondition: Control 30 shortens a 2 s cooldown")
	watch_signals(instance)
	instance.execute_ability(null)
	assert_almost_eq(instance.cooldown_timer.wait_time, cooldown, 0.0001, "the timer runs the cut cooldown")
	assert_signal_emitted_with_parameters(instance, "cooldown_started", [cooldown])

## A cancelled cast starts the cut cooldown too.
func test_a_cancelled_cast_starts_the_cut_cooldown() -> void:
	var technique: AbilityData = _technique(0.0, 5.0, 2.0)
	var instance: CombatAbilityInstance = _instance(technique, _fighter(true, CONTROL))
	instance.is_casting = true
	instance.cast_timer.start(2.0)
	instance.cancel_cast()
	assert_almost_eq(instance.cooldown_timer.wait_time, technique.get_cooldown(instance.get_cooldown_cut()), 0.0001)
	assert_lt(instance.cooldown_timer.wait_time, 5.0, "shorter than the full 5 s")

## Every fight still opens on the full 1.5 s, whatever the player's Control.
func test_the_opening_cooldown_is_never_cut() -> void:
	var instance: CombatAbilityInstance = _instance(_technique(0.0, 3.0), _fighter(true, CONTROL))
	assert_eq(instance.cooldown_timer.wait_time, CombatAbilityInstance.INITIAL_COOLDOWN)

## A technique with no cooldown stays ready after a cast, cut or not.
func test_a_technique_with_no_cooldown_stays_ready() -> void:
	var instance: CombatAbilityInstance = _instance(_technique(0.0, 0.0), _fighter(true, CONTROL))
	watch_signals(instance)
	instance.execute_ability(null)
	assert_true(instance.is_ready(), "no cooldown runs")
	assert_signal_not_emitted(instance, "cooldown_started")

## An enemy's cast starts its full cooldown, however much Control it has.
func test_an_enemys_cooldown_is_never_cut() -> void:
	var instance: CombatAbilityInstance = _instance(_technique(0.0, 30.0), _fighter(false, CONTROL))
	instance.execute_ability(null)
	assert_eq(instance.cooldown_timer.wait_time, 30.0)

## The cast gate and the payment use the cut Madra cost.
func test_the_gate_and_the_payment_use_the_cut_cost() -> void:
	var technique: AbilityData = _technique(8.0, 3.0)
	var player: CombatantNode = _fighter(true, CONTROL)
	var abilities: Array[AbilityData] = [technique]
	player.combatant_data.abilities = abilities
	var vitals := VitalsManager.new()
	add_child_autofree(vitals)
	player.vitals_manager = vitals
	var manager := CombatAbilityManager.new()
	add_child_autofree(manager)
	manager.setup(player)
	var instance: CombatAbilityInstance = manager.abilities[0]
	instance.cooldown_timer.stop()
	var cost: float = technique.get_madra_cost(instance.get_cost_cut())
	assert_lt(cost, 8.0, "precondition: Control 30 cuts the 8 Madra cost")
	vitals.current_madra = cost - 1.0
	assert_false(manager.can_cast_ability_instance(instance, null), "one Madra short of the cut cost")
	vitals.current_madra = cost
	assert_true(manager.can_cast_ability_instance(instance, null), "the cut cost is enough")
	assert_true(manager.use_ability_instance(instance, null), "the cast starts")
	assert_eq(vitals.current_madra, 0.0, "it paid the cut cost, not the full 8")
```

- [ ] **Step 3: Write the failing preview and dock tests.**
  - **`tests/unit/test_technique_slot_math.gd`:** the header adds "and the cost lines (AbilityRow.format_cost(), format_costs())". Add a helper `_costed(madra_cost: float, stamina_cost: float, base_cooldown: float, cast_time: float) -> AbilityData` (`test_costed`, "Test Costed", those four fields, no effects) and:

```gdscript
## The cost lines after Control's cuts. Stamina and the cast time are never cut.
func test_cost_lines_show_the_cut_values() -> void:
	var cases: Array[Dictionary] = [
		{"name": "no cut", "ability": _costed(8.0, 0.0, 3.0, 0.0), "cost_cut": 0.0, "cooldown_cut": 0.0,
			"cost": "8 Madra", "costs": "8 Madra · 3 s"},
		{"name": "a quarter off 8 Madra, a fifth off 3 s", "ability": _costed(8.0, 0.0, 3.0, 0.0), "cost_cut": 0.25, "cooldown_cut": 0.2,
			"cost": "6 Madra", "costs": "6 Madra · 2.4 s"},
		{"name": "7.5 Madra rounds up to 8; the cast time stays", "ability": _costed(10.0, 0.0, 15.0, 1.0), "cost_cut": 0.25, "cooldown_cut": 0.2,
			"cost": "8 Madra", "costs": "8 Madra · 12 s · 1 s cast"},
		{"name": "Stamina is never cut", "ability": _costed(0.0, 3.0, 2.0, 0.5), "cost_cut": 0.25, "cooldown_cut": 0.2,
			"cost": "3 Stamina", "costs": "3 Stamina · 1.6 s · 0.5 s cast"},
	]
	for case: Dictionary in cases:
		assert_eq(AbilityRow.format_cost(case["ability"], case["cost_cut"]), case["cost"], "%s: the cost" % case["name"])
		assert_eq(AbilityRow.format_costs(case["ability"], case["cost_cut"], case["cooldown_cut"]), case["costs"], "%s: costs and timings" % case["name"])
```

  - **`tests/integration/test_technique_dock.gd` and `tests/integration/test_abilities_book.gd`:** each gets a `##`-documented `const TEST_SOURCE: StringName = &"test_control"`; a `CharacterManager.remove_modifier_source(TEST_SOURCE)` call in `after_each()` (in the dock test, after the nodes are freed and before `_set_vitals.callv(_original_vitals)`); and this helper:

```gdscript
## A modifier source that raises Control by `amount`.
func _control_source(amount: float) -> Callable:
	return func() -> Array[StatModifierData]:
		var modifiers: Array[StatModifierData] = [StatModifierData.new(StatModifierData.Stat.CONTROL, StatModifierData.Kind.FLAT, amount)]
		return modifiers
```

  The dock test adds:

```gdscript
## On the map, the slot's cost line and the tooltip show the cut values.
func test_the_preview_and_tooltip_show_the_cut_values() -> void:
	CharacterManager.set_modifier_source(TEST_SOURCE, _control_source(20.0))
	var cost_cut: float = CharacterManager.get_stat(StatModifierData.Stat.MADRA_COST_CUT)
	var cooldown_cut: float = CharacterManager.get_stat(StatModifierData.Stat.COOLDOWN_CUT)
	assert_lt(EMPTY_PALM.get_madra_cost(cost_cut), EMPTY_PALM.madra_cost, "precondition: Control 30 cuts Empty Palm's cost")
	_equip("empty_palm", 2)
	_dock.show_loadout()
	assert_eq((_slot_node(2, "CostLabel") as Label).text, AbilityRow.format_number(EMPTY_PALM.get_madra_cost(cost_cut)), "the cost line")
	_slot(2).mouse_entered.emit()
	assert_eq((_tooltip_node("CostLabel") as Label).text, AbilityRow.format_cost(EMPTY_PALM, cost_cut), "the tooltip's cost")
	assert_eq((_tooltip_node("TimingText") as RichTextLabel).get_parsed_text(),
		TechniqueTooltip.INSTANT_TIMING_FORMAT % AbilityRow.format_seconds(EMPTY_PALM.get_cooldown(cooldown_cut)), "the tooltip's cooldown")

## In a fight the cost line shows the cut cost and reads affordable exactly when
## the cast gate lets the technique cast.
func test_the_cost_line_agrees_with_the_gate_under_a_cost_cut() -> void:
	CharacterManager.set_modifier_source(TEST_SOURCE, _control_source(20.0))
	_equip("empty_palm", 2)
	_start_fight()
	var palm: CombatAbilityInstance = _slot(2).get_ability_instance()
	await _finish_cooldown(palm)
	var cost: float = EMPTY_PALM.get_madra_cost(palm.get_cost_cut())
	assert_lt(cost, EMPTY_PALM.madra_cost, "precondition: the fight's Control cuts Empty Palm's cost")
	assert_eq((_slot_node(2, "CostLabel") as Label).text, AbilityRow.format_number(cost), "the cost line shows the cut cost")
	_vitals.current_madra = cost
	await wait_process_frames(1)
	assert_true(_player.ability_manager.can_cast_ability_instance(palm, null), "the cut cost is enough to cast")
	assert_true(_slot(2).is_cost_affordable(), "and the cost line reads affordable")
	_vitals.current_madra = cost - 1.0
	await wait_process_frames(1)
	assert_false(_player.ability_manager.can_cast_ability_instance(palm, null), "one Madra short can't cast")
	assert_false(_slot(2).is_cost_affordable(), "and the cost line reads unaffordable")
```

  The Abilities book test adds:

```gdscript
## With Control raised, the details and the row show the cut cost and cooldown.
func test_details_and_rows_show_the_control_cut_values() -> void:
	CharacterManager.set_modifier_source(TEST_SOURCE, _control_source(20.0))
	var cost_cut: float = CharacterManager.get_stat(StatModifierData.Stat.MADRA_COST_CUT)
	var cooldown_cut: float = CharacterManager.get_stat(StatModifierData.Stat.COOLDOWN_CUT)
	assert_gt(cooldown_cut, 0.0, "precondition: 20 more Control shortens cooldowns")
	var enforce: AbilityData = load("res://resources/abilities/enforce.tres")
	_view.refresh()
	_view.select_ability("enforce")
	assert_eq(_label("CooldownValue").text, AbilityRow.format_seconds(enforce.get_cooldown(cooldown_cut)), "the cut cooldown")
	assert_eq(_label("CostValue").text, AbilityRow.format_cost(enforce, cost_cut), "the cut Madra cost")
	assert_eq(_label("CastValue").text, "1 s", "Control leaves the cast time alone")
	var row_cost: Label = _row_for("enforce").find_child("CostLabel", true, false) as Label
	assert_eq(row_cost.text, AbilityRow.format_costs(enforce, cost_cut, cooldown_cut), "the row's line too")
```

- [ ] **Step 4: Run them and see them fail.**
  - Command: `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/unit/test_ability_data.gd,res://tests/unit/test_control_cuts.gd,res://tests/unit/test_technique_slot_math.gd,res://tests/integration/test_technique_dock.gd,res://tests/integration/test_abilities_book.gd -gexit`
  - Expected: FAIL: none of the five scripts parses (the new functions don't exist, and `format_cost()` takes one argument), so GUT runs none of their tests.

- [ ] **Step 5: Implement the cost rules in `scripts/resource_definitions/abilities/ability_data.gd`.** Under COST CHECKING, add `get_madra_cost()` and `get_cooldown()` (`##` docs) with the Interfaces formulas. `can_afford()` and `consume_costs()` use `get_madra_cost(cost_cut)` wherever they read `madra_cost`, and `consume_costs()` passes `cost_cut` on to `can_afford()`. The Health and Stamina lines stay as they are.

- [ ] **Step 6: Implement the cuts in `scenes/combat/combatant/combat_ability_manager/combat_ability_instance.gd`.**
  - Under PUBLIC API, `get_cost_cut()` and `get_cooldown_cut()` (`##` docs) return `_player_attributes().get_madra_cost_cut()` and `.get_cooldown_cut()`, or 0.0 when `_player_attributes()` is null.
  - Under INTERNAL LOGIC, `_player_attributes() -> CharacterAttributesData` returns `owner_combatant.combatant_data.attributes` when `owner_combatant` is set, `is_player` is true and `combatant_data` is set, and null otherwise.
  - `execute_ability()` and `cancel_cast()` call `_start_cooldown(ability_data.get_cooldown(get_cooldown_cut()))` in place of their `base_cooldown` start. `_ready()` keeps `_start_cooldown(INITIAL_COOLDOWN)`.
  - `_start_cooldown(cooldown)` keeps its `ability_data.base_cooldown > 0` gate and emits `cooldown_started.emit(cooldown)` in place of `base_cooldown`.

- [ ] **Step 7: Use the cut at the gate in `scenes/combat/combatant/combat_ability_manager/combat_ability_manager.gd`.** `can_cast_ability_instance()` checks `instance.ability_data.can_afford(owner_combatant.vitals_manager, instance.get_cost_cut())` and gains a `##` doc. `use_ability_instance()` pays with `instance.ability_data.consume_costs(owner_combatant.vitals_manager, instance.get_cost_cut())`.

- [ ] **Step 8: Make the dock slot follow the gate in `scenes/ui/combat/technique_dock/technique_slot/technique_slot.gd`.**
  - `_process()` checks `_ability_data.can_afford(_vitals_manager, _instance.get_cost_cut())`.
  - `static func _shown_cost(data: AbilityData, cost_cut: float = 0.0) -> float` returns `data.get_madra_cost(cost_cut)` in its Madra branch, and `_refresh()` passes `_cost_cut()`. That new private helper returns `_instance.get_cost_cut()` while bound and `CharacterManager.get_stat(StatModifierData.Stat.MADRA_COST_CUT)` otherwise.
  - Add a `##`-documented `func is_cost_affordable() -> bool` returning `_cost_affordable` (true while the cost reads cream).
  - In the class doc's ACTIVE line, "the cost in cream" becomes "the cost the cast gate charges (after Control's cut) in cream".

- [ ] **Step 9: Show the cut values in the previews.**
  - **`scenes/abilities/ability_row/ability_row.gd`:** `format_cost()` prints `format_number(ability_data.get_madra_cost(cost_cut))` for Madra. `format_costs()` passes its `cost_cut` to `format_cost()` and prints `format_seconds(ability_data.get_cooldown(cooldown_cut))`.
  - The live readers pass the player's cuts, `CharacterManager.get_stat(StatModifierData.Stat.MADRA_COST_CUT)` and `CharacterManager.get_stat(StatModifierData.Stat.COOLDOWN_CUT)`: `AbilityRow.setup()` to `format_costs()`; `TechniqueTooltip.show_for_ability()` to `AbilityRow.format_cost()`, and `_timing_line()` to `data.get_cooldown()`; `AbilitiesView._show_details()` to CooldownValue's `AbilityRow.format_seconds(ability.get_cooldown(...))` and CostValue's `AbilityRow.format_cost(ability, ...)`. CastValue stays as it is.

- [ ] **Step 10: Run them and see them pass.** Run the Step 4 command with `,res://tests/unit/test_combat_ability_instance_cancel.gd,res://tests/unit/test_combat_dodge.gd` added to `-gtest`, then the full suite (`tests/run_tests.ps1`, as in Task 1.9). Expected: PASS for both.

- [ ] **Step 11: Commit.** Stage the Files list above, `tests/unit/test_ability_data.gd.uid` and `tests/unit/test_control_cuts.gd.uid` (as in Task 1.9), then `git commit -m "feat(combat): cut Madra costs and cooldowns with Control" -m "One cut serves the cast gate, the payment, the cooldowns and every preview, so the screen never calls a technique affordable when the gate refuses it." -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"`

---

### Task 1.12: Stamina regen from Agility in runs

Before Step 1, invoke `godot-prompter:godot-testing`.

**Files:**
- Modify: `scenes/adventure/adventure_view/adventure_view.gd` (`_update_stamina_regen()`)
- Test: `tests/integration/test_adventure_view_frame.gd`

**Interfaces:**
- Consumes: `CharacterManager.get_stat(StatModifierData.Stat.STAMINA_REGEN) -> float` (Task 1.5: Agility × 0.1 over the totals, 1.0 at Lv 1).
- Produces: a run's `PlayerManager.vitals_manager.stamina_regen` = STAMINA_REGEN × `AdventureActionData.stamina_regen_modifier`, set at every run start and 0 at run end. Max Stamina already follows Agility (Task 1.1).

- [ ] **Step 1: Write the failing test.** In `tests/integration/test_adventure_view_frame.gd`:
  - Add a `##`-documented `const TEST_SOURCE: StringName = &"test_agility"`, and call `CharacterManager.remove_modifier_source(TEST_SOURCE)` in `after_each()` just before `_restore_vitals(_saved_vitals)`.
  - `_start_run()` gains a second parameter, `stamina_regen_modifier: float = -1.0`, set on the duplicated action when it is >= 0. Its doc adds "A modifier below 0 keeps the action's own."
  - Add `_agility_source(amount: float) -> Callable`, Task 1.11's `_control_source()` with `StatModifierData.Stat.AGILITY`, and:

```gdscript
## A run regenerates Stamina at STAMINA_REGEN (Agility x 0.1 a second) times the
## run's modifier, worked out at every run start. The run's end stops it.
func test_stamina_regen_follows_agility_at_each_run_start() -> void:
	assert_eq(ADVENTURE_ACTION.stamina_regen_modifier, 1.0, "precondition: the Shallow Woods adds no modifier of its own")
	_start_run()
	assert_almost_eq(PlayerManager.vitals_manager.stamina_regen, 1.0, 0.0001, "Lv 1 Agility: 1 Stamina a second")
	ActionManager.stop_action(false)
	_stop_every_action()
	assert_eq(PlayerManager.vitals_manager.stamina_regen, 0.0, "the run's end stops it")

	CharacterManager.set_modifier_source(TEST_SOURCE, _agility_source(20.0))
	var rate: float = CharacterManager.get_stat(StatModifierData.Stat.STAMINA_REGEN)
	assert_gt(rate, 1.0, "precondition: Agility 30 regenerates faster")
	_map = AdventureMapFixture.build_map()
	_start_run(0, 0.5)
	assert_almost_eq(PlayerManager.vitals_manager.stamina_regen, rate * 0.5, 0.0001, "the next run starts at the new rate, times its modifier")
```

- [ ] **Step 2: Run it and see it fail.**
  - Command: `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/integration/test_adventure_view_frame.gd -gexit`
  - Expected: FAIL: in `test_stamina_regen_follows_agility_at_each_run_start`, the second run regenerates the flat 1.0 × 0.5 a second instead of Agility 30's rate × 0.5.

- [ ] **Step 3: Implement it in `scenes/adventure/adventure_view/adventure_view.gd`.** Inside its `PlayerManager.vitals_manager` guard, `_update_stamina_regen(modifier: float)` sets `stamina_regen = CharacterManager.get_stat(StatModifierData.Stat.STAMINA_REGEN) * modifier`. A `##` doc saying so, and that it is set at every run start, replaces its TODO doc.

- [ ] **Step 4: Run it and see it pass.** Run the Step 2 command. Expected: PASS.

- [ ] **Step 5: Commit.** `git add scenes/adventure/adventure_view/adventure_view.gd tests/integration/test_adventure_view_frame.gd`, then `git commit -m "feat(stats): regenerate run Stamina from Agility" -m "Run Stamina regen was a flat 1.0 a second. It is now Agility's rate, worked out at every run start; Lv 1 keeps 1.0." -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"`

---

### Task 1.13: Breakthrough gate

**Files:**
- Modify: `scripts/resource_definitions/zones/zone_action_data/tribulation_action_data/tribulation_action_data.gd` (`can_attempt()`, a new `get_missing_requirements()`, the class doc)
- Modify: `singletons/action_manager/action_manager.gd` (the Tribulation refusal in `select_action()` and its doc)
- Modify: `scenes/zones/zone_action_button/presenters/tribulation_presenter.gd` (`setup()`, `teardown()`, `on_activation_rejected()`, `_update_state()`, `_update_need()`, a new `_on_stat_level_changed()`, the class doc) and `scenes/zones/zone_action_button/presenters/tribulation_presenter.tscn` (`%StatNeedLabel`)
- Modify: `scenes/ui/goals_panel/goals_panel.gd` (`_ready()`, `_update_milestone()`, a new `_on_stat_level_changed()`, the class doc)
- Modify, to Task 1.0's approved wording: `singletons/cultivation_manager/cultivation_manager.gd` (`CORE_FULL_LOG`), `resources/tribulation/foundation_tribulation.tres` (`intro_text`), `resources/zones/spirit_valley_zone/zone_actions/tribulation_action.tres` and `resources/dev/save_presets/tribulation_ready.tres` (`description`)
- Test: `tests/integration/test_tribulation_flow.gd`, `tests/integration/test_tribulation_card.gd`, `tests/integration/test_goals_panel.gd`, `tests/unit/test_foundation_tribulation_data.gd`

**Interfaces:**
- Consumes: Tasks 1.3 and 1.5 (CharacterManager's level and cap API, `get_trained_value()`, `stat_level_changed(stat, level: int)`, `get_attribute_display_name()`, the modifier sources); `CultivationManager.is_core_full()`, `get_core_density_level()`, `get_core_density_cap()`.
- Produces (Tasks 1.14 and 1.17 rely on both):
  - `static func get_missing_requirements(include_core: bool = true) -> Array[String]` on `TribulationActionData`: one line per unmet requirement, in the order Core Density, Strength, Spirit ("Core Density 95 / 100", "Strength Lv 3 / 10", "Spirit Lv 9 / 10"), from trained levels, never totals. `include_core = false` leaves the Core Density line out, for screens whose rod shows it.
  - `can_attempt() -> bool`: a trial is set, the player is in the stage before its target, and nothing is missing.

- [ ] **Step 1: Write the failing tests.** Below, `cap` is `CharacterManager.get_stat_level_cap()` and `core_cap` is `CultivationManager.get_core_density_cap()`.

`test_tribulation_flow.gd`: add `const Attribute := CharacterAttributesData.AttributeType` and `const TEST_SOURCE: StringName = &"test_tribulation_flow"`; start `after_each()` with `CharacterManager.remove_modifier_source(TEST_SOURCE)`; rename the section "THE ACTION'S TWO QUESTIONS" to "THE ACTION'S QUESTIONS"; and make `_fill_core()` call this helper first (its doc: it readies the whole trial):

```gdscript
## Strength and Spirit trained to the stage's cap, as the trial needs them.
func _cap_main_stats() -> void:
	var cap: int = CharacterManager.get_stat_level_cap()
	CharacterManager.set_stat_level(Attribute.STRENGTH, cap)
	CharacterManager.set_stat_level(Attribute.SPIRIT, cap)
```

Add:
- `test_the_trial_needs_a_full_core_and_both_main_stats_at_the_cap`, a table test. Each case sets `PersistenceManager.save_game_data.core_density_level` and Strength's and Spirit's levels, then asserts that `TribulationActionData.get_missing_requirements()` is `missing` (as `Array[String]`) and that `_tribulation().can_attempt()` is `missing.is_empty()`, each message naming the case:

| name | core | Strength | Spirit | missing |
|---|---|---|---|---|
| everything met | core_cap | cap | cap | none |
| the core short | core_cap - 5 | cap | cap | `"Core Density %d / %d" % [core_cap - 5, core_cap]` |
| Strength short | core_cap | cap - 1 | cap | `"Strength Lv %d / %d" % [cap - 1, cap]` |
| Spirit short | core_cap | cap | 1 | `"Spirit Lv 1 / %d" % cap` |
| nothing met | 0 | 1 | 1 | `"Core Density 0 / %d" % core_cap`, `"Strength Lv 1 / %d" % cap`, `"Spirit Lv 1 / %d" % cap` |

- `test_the_requirements_can_leave_the_core_out`: core 50; `get_missing_requirements(false)` is `["Strength Lv 1 / %d" % cap, "Spirit Lv 1 / %d" % cap]`.
- `test_bonuses_never_count_toward_the_cap`: `_fill_core()`, Strength Lv 1, and a `TEST_SOURCE` source of a FLAT +100.0 `StatModifierData.Stat.STRENGTH`; precondition: `get_stat(StatModifierData.Stat.STRENGTH)` is over `get_trained_value(Attribute.STRENGTH) + 50.0`; `can_attempt()` is false.
- `test_select_refuses_with_a_main_stat_below_the_cap`: `_run_foraging()`, `_fill_core()`, Strength Lv 1, `watch_signals(ActionManager)`, `ActionManager.select_action(_tribulation())`: `_current_id()` is still `FORAGING_ID`, and `start_tribulation` is not emitted.

`test_tribulation_card.gd`: add the `Attribute` const and `_cap_main_stats()`, called at the end of `before_each()` so the ready tests keep a ready card. `test_rejected_click_below_the_cap_logs_why` asserts `assert_string_contains(_logged[0], "Core Density 95 / 100")`, and `test_click_at_the_cap_starts_the_trial`'s loop checks `line.contains("The Tribulation needs")`. Add:
- `test_a_full_core_with_strength_short_is_not_ready`: `_set_core_level(FULL_CORE)`, Strength at `cap - 1`, `_card()`: the tag is "TRIAL", the ready frame is hidden, and `_has_text_containing(card, "Strength Lv %d / %d" % [cap - 1, cap])`.
- `test_a_stat_level_up_readies_the_card`: a full core with Spirit at `cap - 1` is "TRIAL" (precondition); after `CharacterManager.add_stat_levels(Attribute.SPIRIT, 1)`, the tag is "ENTER" and the ready frame shows.
- `test_rejected_click_names_every_missing_requirement`: `_run_aura_well()`, `_set_core_level(SHORT_CORE)`, Strength Lv 1, `_logged.clear()`, `_click(card)`: one log line, containing "Core Density 95 / 100" and `"Strength Lv 1 / %d" % cap`.
- `test_leaving_the_tree_disconnects_from_the_stat_levels`: as `test_leaving_the_tree_disconnects_from_the_cultivation_manager`, counting `CharacterManager.stat_level_changed`'s connections (one more in the tree, back after `remove_child`).

`test_goals_panel.gd`: add `const Attribute := CharacterAttributesData.AttributeType` and `_cap_main_stats()`; call it in `test_milestone_at_the_cap_asks_for_the_tribulation` after `_use_fresh_save(save)`, and in `test_milestone_reads_the_stages_cap` before the 40 / 40 step. Each `assert_eq(_text("MilestoneTextLabel"), "Raise Core Density to N")` in the file (five tests) becomes `assert_string_contains`. Add:
- `test_milestone_lists_every_missing_requirement`: `_add_goals()` on the fresh save; the text contains "Raise Core Density to 100", `"Strength Lv 1 / %d" % cap` and `"Spirit Lv 1 / %d" % cap`.
- `test_a_full_core_waits_for_the_main_stats`: `_use_fresh_save()` with a `SaveGameData.new()` at `core_density_level = 100.0`, then `_add_goals()`: the text holds neither "Face the Tribulation" nor "Raise Core Density" and contains `"Strength Lv 1 / %d" % cap`; `MilestoneFigureLabel` is "100 / 100".
- `test_milestone_follows_a_stat_level_up`: that save, Spirit at `cap`, Strength at `cap - 1`, `_add_goals()`; the text contains "Strength Lv" (precondition); after `add_stat_levels(Attribute.STRENGTH, 1)` it is "Face the Tribulation".

`test_foundation_tribulation_data.gd`: `test_copy` also asserts that `_load_tribulation().intro_text` and `_load_action().description` are Task 1.0's approved wording, and its doc names them.

- [ ] **Step 2: Run them and see them fail.**
`"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/integration/test_tribulation_flow.gd,res://tests/integration/test_tribulation_card.gd,res://tests/integration/test_goals_panel.gd,res://tests/unit/test_foundation_tribulation_data.gd -gexit`
Expected: FAIL. GUT cannot load `test_tribulation_flow.gd` (no `get_missing_requirements` on `TribulationActionData`). `test_tribulation_card.gd`'s four new tests and `test_rejected_click_below_the_cap_logs_why` fail (ENTER with Strength short, no stat line, "Your core must be full", nothing on `stat_level_changed`); `test_goals_panel.gd`'s three new tests fail (no stat lines; a full core reads "Face the Tribulation"); `test_copy` fails for each line whose approved wording differs from today's.
- [ ] **Step 3: Implement the gate, its readers and the copy.** Invoke `godot-prompter:hud-system` first. The card and the board look as the approved Task 1.0 mock-up shows; the binding below holds whatever the look.
  - `TribulationActionData`: `get_missing_requirements()` adds, with `include_core` and the core not full, `"Core Density %d / %d" % [floori(CultivationManager.get_core_density_level()), CultivationManager.get_core_density_cap()]`; then, for STRENGTH and then SPIRIT, each stat that is not `CharacterManager.is_stat_capped(stat)` adds `"%s Lv %d / %d" % [CharacterManager.get_attribute_display_name(stat), CharacterManager.get_stat_level(stat), CharacterManager.get_stat_level_cap()]`. `can_attempt()` returns `in_stage_before_target and get_missing_requirements().is_empty()`. The class doc says the trial needs a full core and both main stats at the cap, counting trained levels, never gear.
  - `ActionManager.select_action()`: the refusal's `Log.info` reads `"ActionManager: Cannot start the Tribulation - %s (%s)" % [", ".join(TribulationActionData.get_missing_requirements()), CultivationManager.get_current_advancement_stage_name()]`, and its doc says "a Tribulation the player isn't ready for".
  - `TribulationPresenter`:
    - `setup()` connects `CharacterManager.stat_level_changed` to `_on_stat_level_changed(_stat: CharacterAttributesData.AttributeType, _level: int) -> void`, which calls `_update_state()`; `teardown()` disconnects it.
    - While not ready, `_update_need()` keeps the rod and `"Core %d / %d"`, and sets `%StatNeedLabel` to `", ".join(TribulationActionData.get_missing_requirements(false))`, visible only when that is not empty; `button.set_tall()` takes the label's visibility in place of today's `false`, so the not-ready card is tall exactly while it shows.
    - `on_activation_rejected()` logs `"[color=red]The Tribulation needs %s.[/color]" % ", ".join(TribulationActionData.get_missing_requirements())`.
    - Scene default, if the mock-up keeps today's card: `%StatNeedLabel` is a Label (`LabelLacquerDetail`, `autowrap_mode = 3`, `mouse_filter = 2`) in `%NeedGroup` at offsets (64, 58) to (380, 76), and `%NeedGroup` gets `offset_bottom = 96`.
  - `GoalsPanel`: `_ready()` connects `CharacterManager.stat_level_changed` to `_on_stat_level_changed(_stat, _level)`, which calls `_update_milestone()`. `_update_milestone()` checks, in order: with no next stage, "<Stage> reached" (unchanged); with nothing missing, "Face the Tribulation", the rod full and the figure at cap / cap; otherwise "Raise Core Density to <cap>" (only while the core is not full), then each line of `get_missing_requirements(false)`, one per line, with the rod and the figure at level / cap. The class doc's three states follow.
  - The copy: Task 1.0's four approved lines go into `CORE_FULL_LOG`, the trial's `intro_text`, and the action's and the preset's `description`.
- [ ] **Step 4: Run them and see them pass.** Run the Step 2 command, then the one-file command for `res://tests/unit/test_cultivation_manager.gd` (it logs `CORE_FULL_LOG`). Expected: PASS.
- [ ] **Step 5: Commit.** `git add` each file under Files, by path. `git commit -m "feat(stats): gate the breakthrough on Strength and Spirit at the cap"` (+ Co-Authored-By line)

---

### Task 1.14: Dev tools for stat levels

**Files:**
- Modify: `singletons/dev_manager/dev_commands.gd` (remove `add_attribute()`; add `set_stat_level()` and `raise_stat_to_cap()` in "CULTIVATION AND RESOURCES")
- Modify: `scenes/ui/dev_panel/tabs/player_tab.gd` (node refs, `_ready()`, `_on_stat_set_pressed()` in place of `_on_attribute_add_pressed()`, the class doc) and `scenes/ui/dev_panel/tabs/player_tab.tscn` (`AttributeRow` becomes `StatRow`)
- Modify: `scripts/resource_definitions/dev/dev_step_data.gd` (`Kind.RAISE_STAT_TO_CAP`, its Kind doc line, arms in `apply()`, `describe()` and `_problem_with_target()`)
- Modify: `resources/dev/story_route.tres` (beat_9_ready's steps)
- Test: `tests/unit/test_dev_preset_data.gd`, `tests/integration/test_dev_commands.gd`, `tests/integration/test_dev_panel.gd`, `tests/integration/test_story_route.gd`, `tests/integration/test_save_presets.gd`

**Interfaces:**
- Consumes: Task 1.1 (`stat_key()`, `stat_from_key()`), Task 1.3 (CharacterManager's level, XP and cap API, `get_attribute_display_name()`), Task 1.13 (`can_attempt()`).
- Produces:
  - On `DevCommands`: `static func set_stat_level(stat_key: StringName, level: int, xp: float = 0.0) -> String` and `static func raise_stat_to_cap(stat_key: StringName) -> String` ("" or the refusal).
  - `DevStepData.Kind.RAISE_STAT_TO_CAP = 13`: its `target_id` is a stat key; it reads no amount.
  - `tribulation_ready` and `copper` built with Strength and Spirit at Foundation's cap. Task 1.17's run starts from `tribulation_ready`.

- [ ] **Step 1: Write the failing tests.**
  - `test_dev_preset_data.gd`: `"RAISE_STAT_TO_CAP": 13` in `test_kind_numbers_never_change`, `_assert_valid(_step(Kind.RAISE_STAT_TO_CAP, "strength"))` in `test_a_good_step_validates`, and `_assert_flagged(_step(Kind.RAISE_STAT_TO_CAP, "willpower"), "unknown stat")` in `test_validate_catches_each_bad_step`.
  - `test_story_route.gd`: an arm of `_assert_took_effect()`:

```gdscript
		Kind.RAISE_STAT_TO_CAP:
			var stat: int = CharacterAttributesData.stat_from_key(StringName(step.target_id))
			assert_true(CharacterManager.is_stat_capped(stat as CharacterAttributesData.AttributeType), "%s: the stat is at the cap" % what)
```

  - `test_save_presets.gd`: `test_tribulation_ready_can_face_the_trial`: after `_build_shipped("tribulation_ready")`, Strength and Spirit are `is_stat_capped()`, and `(ZoneManager.get_action_by_id(TRIBULATION_ACTION) as TribulationActionData).can_attempt()` is true. `test_copper_keeps_the_levels_it_broke_through_with`: after `_build_shipped("copper")`, Strength's and Spirit's levels both equal `(load(FOUNDATION_STAGE) as AdvancementStageResource).stat_level_cap` (levels carry across stages).
  - `test_dev_commands.gd`:
    - Add `const Attribute := CharacterAttributesData.AttributeType`; rename the section "ATTRIBUTES AND STAGE" to "STATS AND STAGE"; delete Task 1.3's `test_add_attribute_adds_levels` and `test_add_attribute_does_nothing_at_the_cap`, and `test_add_attribute_refuses_an_unknown_attribute`.
    - In `test_successful_commands_log_a_dev_line`, the `add_attribute` row becomes `["set_stat_level", func() -> String: return DevCommands.set_stat_level(&"strength", 5, 20.0)]` and `["raise_stat_to_cap", func() -> String: return DevCommands.raise_stat_to_cap(&"spirit")]`.
    - In `test_a_command_pauses_recording_for_its_own_duration`, add `var during_level: Array[bool] = _note_recording_on(CharacterManager.stat_level_changed, 2)`, call `DevCommands.set_stat_level(&"mind", 3)`, and `assert_eq(during_level, [true] as Array[bool], "set_stat_level")`.
    - `test_set_stat_level_sets_the_level_and_xp`: `set_stat_level(&"strength", 7, 30.0)` returns ""; Strength is Lv 7 with 30.0 XP.
    - `test_set_stat_level_refuses_a_bad_stat_level_or_xp` (a refusal changes nothing and logs nothing): after `watch_signals(LogManager)`, a table of three calls is each refused (not ""): "a removed stat" `(&"willpower", 3, 0.0)`, "level 0" `(&"strength", 0, 0.0)`, "negative XP" `(&"strength", 3, -1.0)`. Then Strength is still Lv 1 and `_dev_lines()` is empty.
    - `test_raise_stat_to_cap_raises_a_stat_to_the_stage_cap`: `raise_stat_to_cap(&"spirit")` returns "", and Spirit's level is `get_stat_level_cap()`.
    - `test_raise_stat_to_cap_never_lowers_a_stat`: `set_stat_level(&"spirit", cap + 2)` returns "" (precondition: the dev tools may pass the cap); after `watch_signals(LogManager)`, `raise_stat_to_cap(&"spirit")` returns "", Spirit stays at `cap + 2`, and `_dev_lines()` is empty.
    - `test_raise_stat_to_cap_refuses_an_unknown_stat`: `raise_stat_to_cap(&"foundation")` is refused (Foundation names the stage now, not a stat).
  - `test_dev_panel.gd`, after `test_player_tab_shows_a_refusal`, each on `_open_tab(_add_panel(), "PlayerTab")`: `test_player_tab_lists_the_six_stats`: `_item_metadata()` of `%StatOption` is `["strength", "body", "agility", "spirit", "mind", "control"] as Array[String]`. `test_player_tab_sets_a_stats_level_and_xp`: `_pick_item(%StatOption, &"spirit")`, `_enter(player, "StatLevelSpin", 4.0)`, `_enter(player, "StatXpSpin", 12.0)`, `_press(player, "StatSet")`: Spirit is Lv 4 with 12.0 XP.
- [ ] **Step 2: Run them and see them fail.**
`"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/unit/test_dev_preset_data.gd,res://tests/integration/test_dev_commands.gd,res://tests/integration/test_story_route.gd,res://tests/integration/test_save_presets.gd,res://tests/integration/test_dev_panel.gd -gexit`
Expected: FAIL. GUT cannot load `test_dev_preset_data.gd` or `test_story_route.gd` (`RAISE_STAT_TO_CAP` is not a member of `DevStepData.Kind`), nor `test_dev_commands.gd` (`set_stat_level` is not declared on `DevCommands`). In `test_save_presets.gd` both new tests fail (Strength and Spirit are Lv 1), and in `test_dev_panel.gd` both fail (no `%StatOption`).
- [ ] **Step 3: Implement the commands, the step kind, the tab and the route steps.** Invoke `godot-prompter:godot-ui` first, for the tab's scene. Both commands keep DevCommands' contract: refuse an unknown key first (`CharacterAttributesData.stat_from_key(stat_key) == -1`: "Unknown stat: %s"), run the work through `_while_paused()`, log one line through `_succeed()`, and return the refusal or "".
  - `set_stat_level()` also refuses `level < 1` ("The level must be at least 1") and `xp < 0.0` ("XP can't be negative"), then runs `_while_paused(CharacterManager.set_stat_level.bind(stat, level, xp))` and `_succeed("Set %s to Lv %d with %s XP" % [CharacterManager.get_attribute_display_name(stat), level, String.num(CharacterManager.get_stat_xp(stat))])`.
  - `raise_stat_to_cap()` returns "" with nothing done when `CharacterManager.get_stat_level(stat) >= CharacterManager.get_stat_level_cap()`; otherwise it runs `_while_paused(CharacterManager.set_stat_level.bind(stat, cap))` and `_succeed("Raised %s to Lv %d, the stage cap" % [name, cap])`.
  - Delete `DevCommands.add_attribute()`.
  - `DevStepData`: append `RAISE_STAT_TO_CAP,` after `TRAVEL`, with the Kind doc line `##   RAISE_STAT_TO_CAP    target_id: a stat key (strength, body, agility, spirit, mind, control)`. `apply()` returns `DevCommands.raise_stat_to_cap(StringName(target_id))`, `describe()` returns `"Raise %s to the stage cap" % target_id`, and `_problem_with_target()` returns `"unknown stat"` when `CharacterAttributesData.stat_from_key(StringName(target_id)) == -1`. `_problem_with_amount()` needs no arm.
  - `player_tab.tscn`: `AttributeRow` and its three nodes become `StatRow` (HBoxContainer), holding `%StatOption` (OptionButton, `custom_minimum_size = Vector2(130, 0)`), `%StatLevelSpin` (SpinBox, `size_flags_horizontal = 3`, `min_value = 1.0`, `max_value = 100.0`, `value = 1.0`, `allow_greater = true`), `%StatXpSpin` (SpinBox, `size_flags_horizontal = 3`, `max_value = 100000.0`) and `%StatSet` (Button, `text = "Set"`).
  - `player_tab.gd`: `_ready()` fills `%StatOption` from `CharacterAttributesData.AttributeType.values()` (text `CharacterManager.get_attribute_display_name(stat)`, metadata `CharacterAttributesData.stat_key(stat)`) and connects `%StatSet.pressed` to `_on_stat_set_pressed()`, which calls `_show_result(DevCommands.set_stat_level(StringName(_picked_id(_stat_option)), int(_stat_level_spin.value), _stat_xp_spin.value))`. The class doc says a stat is set to a level and XP.
  - `resources/dev/story_route.tres`: after `beat_9_ready_core_density_100`, add the sub_resources `beat_9_ready_strength_cap` and `beat_9_ready_spirit_cap` (`type="Resource"`, `script = ExtResource("3_step")`, `kind = 13`, `target_id = "strength"` / `"spirit"`), and set beat_9_ready's `steps = Array[ExtResource("3_step")]([SubResource("beat_9_ready_core_density_100"), SubResource("beat_9_ready_strength_cap"), SubResource("beat_9_ready_spirit_cap")])`.

- [ ] **Step 4: Run them and see them pass.** Run the Step 2 command. Expected: PASS.
- [ ] **Step 5: Commit.** `git add` each file under Files, by path. `git commit -m "feat(dev): set stat levels and cap them for the presets"` (+ Co-Authored-By line)

---

### Task 1.15: StatDisplay

**Files:**
- Create: `scripts/utils/stat_display.gd`
- Create (only if the approved mock-up asks for a new Mind icon): `assets/sprites/ui/attribute_icons/mind_icon_ai.png`
- Modify: `scenes/abilities/abilities_view.gd` (remove `_ATTRIBUTE_ICONS`; `_show_value_breakdown()` reads `StatDisplay.icon_of()`)
- Test: `tests/unit/test_stat_display.gd` (new), `tests/integration/test_abilities_book.gd`

**Interfaces:**
- Consumes: the six-value `CharacterAttributesData.AttributeType` (Task 1.1); `CharacterManager.get_attribute_display_name(stat) -> String`; `CombatEffectData.get_scaling(stat)`, which reads only Strength and Spirit after Task 1.9.
- Produces: `class_name StatDisplay extends RefCounted`: `const PHYSICAL` (STRENGTH, BODY, AGILITY) and `const SPIRITUAL` (SPIRIT, MIND, CONTROL), both `Array[CharacterAttributesData.AttributeType]`, and the statics `name_of(stat) -> String`, `icon_of(stat) -> Texture2D` and `side_name(stat) -> String`, each `stat` a `CharacterAttributesData.AttributeType`. Task 1.16 reads all five.

- [ ] **Step 1: Write the failing tests.** Create `tests/unit/test_stat_display.gd` (`extends GutTest`; header `## StatDisplay: the two sides, and each stat's name, icon and side, the one map the Character book and the Abilities book read.`; `const Attribute := CharacterAttributesData.AttributeType`):
  - `test_each_side_holds_its_three_stats_in_order`: `StatDisplay.PHYSICAL` is `[Attribute.STRENGTH, Attribute.BODY, Attribute.AGILITY]` and `StatDisplay.SPIRITUAL` is `[Attribute.SPIRIT, Attribute.MIND, Attribute.CONTROL]`, each `as Array[CharacterAttributesData.AttributeType]`.
  - `test_every_stat_sits_on_exactly_one_side`: for each of `Attribute.values()`, `int(PHYSICAL.has(stat)) + int(SPIRITUAL.has(stat))` is 1.
  - `test_every_stat_has_a_name_an_icon_and_a_side`: a table of the six (Strength, Body, Agility "Physical"; Spirit, Mind, Control "Spiritual"): `name_of()` is the name, `side_name()` the side, and `icon_of()` is not null.
  - `test_no_two_stats_share_an_icon`: the six `icon_of()` textures all differ.

  In `tests/integration/test_abilities_book.gd`, delete the `STRENGTH_ICON` and `AGILITY_ICON` consts and turn `test_damage_shows_the_total_and_each_attributes_part` (as Task 1.9 left it) into a table over Basic Strike (STRENGTH) and Empty Palm (SPIRIT), each message naming the ability: `PrimaryValue` and `ExplainText` keep Task 1.9's assertions, `ScalingPart1` shows with `get_icon() == StatDisplay.icon_of(stat)` and `get_value_text() == "+%s" % AbilityRow.format_number(effect.get_scaling_contribution(stat, attrs))`, and `ScalingPart2` is hidden (`effect`: the ability's first target effect; `attrs`: `CharacterManager.get_total_attributes_data()`).
- [ ] **Step 2: Run them and see them fail.**
`"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/unit/test_stat_display.gd,res://tests/integration/test_abilities_book.gd -gexit`
Expected: FAIL: GUT cannot load either script (`StatDisplay` is not declared), so none of their tests run.
- [ ] **Step 3: Implement `StatDisplay` and use it in `AbilitiesView`.** Invoke `godot-prompter:godot-ui` first.
  - `name_of()` returns `CharacterManager.get_attribute_display_name(stat)`, so the name keeps one home. `side_name()` returns "Physical" when `PHYSICAL.has(stat)`, else "Spiritual".
  - `icon_of()` reads a private `const _ICONS: Dictionary` of preloads from `res://assets/sprites/ui/attribute_icons/`: STRENGTH `strength_icon.png`, BODY `body_icon.png`, AGILITY `agility_icon.png`, SPIRIT `spirit_icon.png`, MIND the approved icon (`foundation_icon.png`, or `mind_icon_ai.png` if the mock-up asks for it: 32 art px stored at 2×, 64×64), CONTROL `control_icon_ai.png`. An unknown stat gets a `Log.error` and null. Never edit the existing icons.
  - `AbilitiesView`: delete `_ATTRIBUTE_ICONS`; `_show_value_breakdown()` calls `part.setup(StatDisplay.icon_of(attribute_type), ...)`.
  - `StatDisplay` is a new `class_name`, so run `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --import`. Expected: no parse error, and `git status --short project.godot` prints nothing.
- [ ] **Step 4: Run them and see them pass.** Run the Step 2 command. Expected: PASS.
- [ ] **Step 5: Commit.** `git add scripts/utils/stat_display.gd scripts/utils/stat_display.gd.uid scenes/abilities/abilities_view.gd tests/unit/test_stat_display.gd tests/unit/test_stat_display.gd.uid tests/integration/test_abilities_book.gd`, plus `assets/sprites/ui/attribute_icons/mind_icon_ai.png` and its `.png.import` if it was drawn. `git commit -m "feat(stats): add StatDisplay, one map of stat names and icons"` (+ Co-Authored-By line)

---

### Task 1.16: Character book

**Files:**
- Modify: `scenes/character/attribute_tile/attribute_tile.gd` (remove the `attribute_name` and `icon_texture` exports, change `_ready()`, and `set_stat()` replaces `set_value()`) and `scenes/character/attribute_tile/attribute_tile.tscn` (`%LevelLabel`, `%XpBar` and `%CapSeal`; no `res://icon.svg` default)
- Modify: `scenes/character/character_view.gd` (`STAT_DESCRIPTIONS` replaces `ATTRIBUTE_DETAILS`; `NOTHING_TRAINS_TEXT`; `_ready()`, `refresh()`, `_show_details()`; the four line statics; `_describe_effect_kind()` made static; `_describe_effects()` and `_EFFECT_MARK` removed) and `scenes/character/character_view.tscn` (the six tiles, the detail page's nodes, `%FightRows`, no `max_lines_visible`)
- Create (only what the approved mock-up asks for): pressed `_ai` textures for the XP bar, under `assets/sprites/ui/book/pressed/`
- Modify: `tests/integration/test_boards_never_trim_text.gd`
- Test: `tests/integration/test_character_book.gd` (rewritten)

**Interfaces:**
- Consumes: Task 1.1 (`CharacterAttributesData.make()`, the derived functions, the derived `StatModifierData.Stat` members); Tasks 1.3 and 1.5 (`CharacterManager`'s stat reads and writes, `get_stat()`, `get_total_attributes_data()`, `stat_progression`, `stats_changed`, `stat_xp_changed`, `stat_level_changed`, the modifier sources); Task 1.6 (`get_gear_bonus()`, `stat_percent_bonuses`, `stat_bonus_floor`); Task 1.15 (`StatDisplay`).
- Produces:
  - `AttributeTile.set_stat(level: int, xp: float, xp_to_next: float, capped: bool, total: float) -> void`.
  - On `CharacterView`: `static func effect_lines(stat: CharacterAttributesData.AttributeType, now: CharacterAttributesData, next: CharacterAttributesData, abilities: Array[AbilityData]) -> Array[Dictionary]` (each `{"label", "now", "next"}`, Strings); `static func source_lines(stat) -> Array[Dictionary]` and `static func fight_lines() -> Array[Dictionary]` (each `{"label", "value"}`); `static func trainer_names(stat) -> Array[String]`; `const STAT_DESCRIPTIONS: Dictionary`; `const NOTHING_TRAINS_TEXT: String`.
  - Task 2.4 makes the Madra entry of `fight_lines()` read "current / max" and also rebuilds `%FightRows` on `ResourceManager.madra_changed`. Phase 3 adds cycling trainers to `trainer_names()` and the cycles-to-next-level estimate; nothing pays stat XP per cycle in phase 1.

- [ ] **Step 1: Write the failing tests.** Rewrite `tests/integration/test_character_book.gd`; keep `test_pages_wait_for_the_open_book` and `test_pages_hide_as_the_book_closes` as they are.
  - Header: what the book shows (tiles, the detail page, In a fight) and follows while open. Consts: `CharacterViewScene`, `ANIMATION_TIMEOUT: float = 2.0`, `Attribute`, `Stat := StatModifierData.Stat`, `TEST_SOURCE: StringName = &"test_character_book"`, and the ability paths `BASIC_STRIKE` and `EMPTY_PALM`.
  - Fixture: `PersistenceManager.save_game_data = SaveGameData.new_current()` and `save_data_reset.emit()` (the original restored in `after_each()`), with `unlocked_ability_ids = ["basic_strike", "empty_palm"]`; `AbilityManager._build_catalog_index()`; the view through `add_child_autofree`. `after_each()` also removes `TEST_SOURCE` and stops actions until none runs.
  - Helpers: `_tile(name) -> AttributeTile` and `_label(name) -> Label` (`find_child(name, true, false)`); `_sword() -> ItemInstanceData` of a MAIN_HAND `EquipmentDefinitionData` (`item_id = "test_character_book_sword"`, `stat_percent_bonuses = {&"strength": 0.1}`, `stat_bonus_floor = 2`).
  - Tests (`format_number` is `AbilityRow.format_number`):
    - `test_the_tiles_are_the_six_stats_on_their_sides`: the children of `%PhysicalTiles` and `%SpiritualTiles` carry the `attribute_type`s of `StatDisplay.PHYSICAL` and `SPIRITUAL`.
    - `test_a_tile_shows_its_level_xp_and_total`: `set_stat_level(SPIRIT, 4, 30.0)`, `refresh()`: SpiritTile's `%LevelLabel` "Lv 4", `%ValueLabel` `"%.0f" % get_stat(Stat.SPIRIT)`, `%XpBar` at step `roundi(30.0 / get_stat_xp_to_next(SPIRIT) * bar.steps)`, `%CapSeal` hidden.
    - `test_a_capped_tile_shows_the_cap`: Strength at the cap, `refresh()`: StrengthTile's `%CapSeal` shows, BodyTile's does not.
    - `test_the_book_follows_stats_while_open`: `_view.show()`, `refresh()`; `add_stat_levels(SPIRIT, 1)` turns SpiritTile to "Lv 2"; `add_stat_xp(SPIRIT, 10.0)` moves its bar to step `roundi(10.0 / get_stat_xp_to_next(SPIRIT) * bar.steps)`.
    - `test_the_book_follows_gear_while_open`: `show()`, `select_attribute(STRENGTH)`, `refresh()`, `InventoryManager.equip_item(_sword(), EquipmentDefinitionData.EquipmentSlot.MAIN_HAND)`; precondition `get_gear_bonus(STRENGTH) > 0.0`; `DetailValue` is `"%.0f" % get_stat(Stat.STRENGTH)`.
    - `test_opening_shows_strength`: `select_attribute(CONTROL)`, `animate_open()`: STRENGTH is selected, `DetailPlaque` reads "Strength", StrengthTile `is_selected()`.
    - `test_pointing_at_a_tile_describes_it`: `animate_open()`, BodyTile emits `hovered(body_tile)`: `DetailName` "Body", `DetailGroup` `StatDisplay.side_name(BODY)`, `DetailDescription` `STAT_DESCRIPTIONS[BODY]`; only BodyTile is selected.
    - `test_every_stat_has_a_description`: no stat's `STAT_DESCRIPTIONS` entry is empty.
    - `test_each_stat_names_what_it_does` (table): the labels of `effect_lines(stat, make(), make(), [Basic Strike, Empty Palm])` are STRENGTH ["Basic Strike damage"], BODY ["Max Health"], AGILITY ["Max Stamina", "Stamina regen", "Dodge chance"], SPIRIT ["Empty Palm damage"], MIND ["Max Madra"], CONTROL ["Technique cost cut", "Cooldown cut"].
    - `test_now_and_next_come_from_the_blocks_functions`: with `now = make()` and `next = make({&"body": 11.0, &"spirit": 11.0})`, Body's first line is `format_number(now.get_max_health())` now and `format_number(next.get_max_health())` next; given `[Empty Palm]`, Spirit's first line is its first target effect's `calculate_value(now)` and `calculate_value(next)`, formatted.
    - `test_the_page_shows_a_row_per_effect`: `select_attribute(SPIRIT)`: `%EffectRows` has a child per line of `effect_lines(SPIRIT, block, block, AbilityManager.get_unlocked_abilities())` (`block = get_total_attributes_data()`), fewer than with `get_all_abilities()` (precondition: locked Power Font stays off).
    - `test_a_stat_with_no_known_technique_says_so`: unlocked `["enforce"]`, `select_attribute(SPIRIT)`: `%NoEffectsLabel` is visible.
    - `test_a_capped_stats_page_has_no_next_level`: Body at the cap, `select_attribute(BODY)`, `refresh()`: `%DetailCapSeal` visible, `%DetailXpLabel` not.
    - `test_the_page_shows_trained_plus_gear`: equip `_sword()` (precondition: Strength's gear bonus > 0.0): `source_lines(STRENGTH)` is two lines, valued `format_number(get_trained_value(STRENGTH))` and `"+%s" % format_number(get_gear_bonus(STRENGTH))`.
    - `test_trainers_come_from_the_training_actions`: `trainer_names()` is `[ZoneManager.get_action_by_id("aura_well_training").action_name]` for SPIRIT and `[]` for the other stats.
    - `test_a_stat_nothing_trains_says_so`: on BODY, `TrainersLabel` is `NOTHING_TRAINS_TEXT`; on SPIRIT it contains the Aura Well's `action_name`.
    - `test_in_a_fight_lists_every_total`: a `TEST_SOURCE` source of FLAT ARMOR 6.0 and FLAT WARD 4.0: the labels of `fight_lines()` are ["Health", "Madra", "Stamina", "Dodge chance", "Technique cost cut", "Cooldown cut", "Armor", "Ward"]; Health's value is `format_number(get_stat(Stat.MAX_HEALTH))`, Armor's "6", Ward's "4".
    - `test_the_fight_block_shows_a_row_per_total`: after `refresh()`, `%FightRows` has `fight_lines().size()` children.

  In `test_boards_never_trim_text.gd`, add `"res://scenes/character/character_view.tscn"` and `"res://scenes/character/attribute_tile/attribute_tile.tscn"` to `BOARD_SCENES` (naming them in its doc comment), and `"res://scenes/character/character_view.tscn": ["DetailDescription", "TrainersLabel"]` to the `wrapping` table of `test_the_labels_that_can_run_long_wrap`.
- [ ] **Step 2: Run them and see them fail.**
`"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/integration/test_character_book.gd,res://tests/integration/test_boards_never_trim_text.gd -gexit`
Expected: FAIL. GUT cannot load `test_character_book.gd` (`CharacterView.effect_lines`, `STAT_DESCRIPTIONS` and the others are not declared). `test_the_labels_that_can_run_long_wrap` fails: `character_view.tscn` has no `%TrainersLabel`.
- [ ] **Step 3: Build the book the approved mock-up shows.** Invoke `godot-prompter:godot-ui` first, and read `docs/STYLE_GUIDE.md` (rule 14, pressed paper) and `docs/UI_STYLING.md`. The unique names below are the binding; the look is the mock-up's. The description and the trainers line get `autowrap_mode = 3` and a width.
  - `attribute_tile.tscn`: keep `%Icon`, `%ValueLabel` and `%NameLabel`; add `%LevelLabel` (Label), `%XpBar` (an instance of `scenes/common/lacquer/lacquer_rod.tscn`, with the mock-up's textures and `steps`) and `%CapSeal` (a hidden `LabelBookSeal` Label, 66×26, the approved word); drop the `res://icon.svg` texture and its ext_resource (STYLE_GUIDE §9).
  - `AttributeTile`: delete the `attribute_name` and `icon_texture` exports; `_ready()` writes `StatDisplay.name_of(attribute_type)` and `StatDisplay.icon_of(attribute_type)`. `set_stat()` writes "Lv %d" and `"%.0f" % total`, fills `%XpBar` to `xp / xp_to_next` (0 when `xp_to_next` is 0; full while capped if the approved cap look includes the bar), and shows `%CapSeal` exactly while capped.
  - `character_view.tscn`: `%PhysicalTiles` holds StrengthTile (`attribute_type` 0, left at the default), BodyTile (1) and AgilityTile (2), `%SpiritualTiles` holds SpiritTile (3), MindTile (4) and ControlTile (5), and both grids get `columns = 3`; delete the tiles' `attribute_name` and `icon_texture` lines and the icon ext_resources nothing uses. Where the mock-up places them, add `%DetailLevel` (Label), `%DetailXpBar` (a `lacquer_rod.tscn` instance), `%DetailXpLabel` (Label), `%DetailCapSeal` (a hidden `LabelBookSeal` Label), `%EffectRows`, `%SourceRows` and `%FightRows` (VBoxContainers), `%NoEffectsLabel` (Label, text `NO_EFFECTS_TEXT`) and `%TrainersLabel` (Label). `%EffectRows` replaces `EffectsCaption` and `%EffectsLabel`; `%DetailDescription` loses `max_lines_visible = 3`.
  - `CharacterView`:
    - `_ready()` connects `CharacterManager.stats_changed` to `_refresh_if_shown() -> void`, and `stat_level_changed` and `stat_xp_changed` to it through `.unbind(2)` and `.unbind(3)`; `_refresh_if_shown()` calls `refresh()` while `is_visible_in_tree()`.
    - `refresh()` calls `set_stat()` on each tile with the stat's level, XP, XP to next, `is_stat_capped()` and total `CharacterManager.get_stat(StatModifierData.for_attribute(stat))`, rebuilds `%FightRows` from `fight_lines()`, and re-describes the selected stat.
    - `_show_details(tile)`: the plaque and the name from `StatDisplay.name_of()`, the icon from `icon_of()`, `%DetailGroup` from `side_name()`; `%DetailLevel` reads `"Lv %d / %d"` (level, cap) and `%DetailValue` `"%.0f"` of the total. While capped, `%DetailXpBar` and `%DetailXpLabel` hide and `%DetailCapSeal` shows; otherwise `%DetailXpLabel` reads `"%d / %d XP"` (XP, XP to next) and the bar holds their fraction. The description comes from `STAT_DESCRIPTIONS`. `%EffectRows` holds a row per line of `effect_lines(stat, now, next, AbilityManager.get_unlocked_abilities())`, with `now = CharacterManager.get_total_attributes_data()` and `next` a `now.duplicate()` given `set_attribute(stat, now.get_attribute(stat) + CharacterManager.stat_progression.get_value_for_level(level + 1) - CharacterManager.stat_progression.get_value_for_level(level))`, so next keeps gear's bonus as it is now; a row shows "now → next", or "now" alone while capped, and `%NoEffectsLabel` shows only when there are no lines. `%SourceRows` holds a row per `source_lines(stat)` line. `%TrainersLabel` reads `", ".join(trainer_names(stat))`, or `NOTHING_TRAINS_TEXT` when that is empty.
    - Rows are `TableRow`s (`scenes/inventory/pressed/table_row/table_row.tscn`, or the row scene the approved mock-up names, with the same `setup()`): add each row to its container, then `setup(label.to_upper(), LacquerText.decimal_bbcode(value))`. Old rows go at once (`remove_child()`, then `free()`, as `AbilitiesView._rebuild_rows()` does).
    - The line statics:

```
effect_lines: derived lines first (now from `now`, next from `next`), then each ability's
  effects_on_target and effects_on_self with get_scaling(stat) != 0.0, as
  "<ability_name> <damage|healing|effect>" (_describe_effect_kind()), calculate_value(), number
  BODY: Max Health get_max_health() number | MIND: Max Madra get_max_madra() number
  AGILITY: Max Stamina get_max_stamina() number, Stamina regen get_stamina_regen() "<number> / s",
           Dodge chance get_dodge_chance() percent
  CONTROL: Technique cost cut get_madra_cost_cut(), Cooldown cut get_cooldown_cut(): percent
fight_lines, from CharacterManager.get_stat(): Health MAX_HEALTH, Madra MAX_MADRA, Stamina
  MAX_STAMINA: number; Dodge chance DODGE_CHANCE, Technique cost cut MADRA_COST_CUT, Cooldown cut
  COOLDOWN_CUT: percent; Armor ARMOR, Ward WARD: number
source_lines: "Trained (Lv %d)" % level with number(get_trained_value(stat)), then "Gear" with
  "+" + number(get_gear_bonus(stat))
trainer_names: the action_name of each TrainingActionData in ZoneManager.get_all_zones()' all_actions
  whose effects_on_level holds an AwardAttributeEffectData with attribute_type == stat, each once
number = AbilityRow.format_number(v); percent = "%s%%" % AbilityRow.format_number(snappedf(v * 100.0, 0.1))
```

    - The copy: `const NOTHING_TRAINS_TEXT: String = "Nothing trains this yet"`, and `const STAT_DESCRIPTIONS: Dictionary`, keyed by `CharacterAttributesData.AttributeType`:
      - STRENGTH: "Raw physical power. Your physical techniques hit harder."
      - BODY: "Physical constitution. Sets your maximum Health."
      - AGILITY: "Speed and footwork. Sets your Stamina and how fast it returns, and gives you a chance to dodge."
      - SPIRIT: "The force of your Madra. Your Spirit techniques hit harder."
      - MIND: "The depth of your Madra channels. Sets your maximum Madra."
      - CONTROL: "Mastery of your techniques. They cost less Madra and come back sooner."
    - Update the class doc.
- [ ] **Step 4: Run them and see them pass.** Run the Step 2 command, then `tests/unit/test_book_view_state.gd`, `tests/unit/test_view_state_hud_positions.gd` and `tests/integration/test_tab_banner_title.gd` (they build the book). Expected: PASS.
- [ ] **Step 5: Commit.** `git add` each modified file under Files and each new `_ai` texture with its `.png.import`. `git commit -m "feat(stats): show levels, XP, the cap and fight totals in the Character book"` (+ Co-Authored-By line)

---

### Task 1.17: Phase 1 wrap

**Files:**
- No new files. A fix found here goes in a commit of its own, with its test.

**Interfaces:**
- Consumes: every phase 1 task; `tribulation_ready` built with the stats at the cap (Task 1.14).
- Produces: the phase 1 PR from this worktree's branch, `feat/game-stats-rework-e6a4b4`, into `main`, with its `## Docs to update` list. It is not merged: Lionel merges.

- [ ] **Step 1: Run the full suite.** `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_tests.ps1`. Expected: PASS, exit code 0, no failing test and no script that ran no tests. Rerun a failing file alone, with the command the runner prints, before investigating it.
- [ ] **Step 2: Check for leftovers of the old stats and for living-doc edits.**
  - `git grep -n -E "AttributeType\.(FOUNDATION|RESILIENCE|WILLPOWER)|Stat\.(FOUNDATION|RESILIENCE|WILLPOWER)|add_base_attribute|base_attribute_changed|attribute_bonuses|(foundation|resilience|willpower|body|agility|mind|control)_scaling|foundation_madra_multiplier|ATTRIBUTE_DETAILS|_ATTRIBUTE_ICONS|add_attribute\(|STAMINA_PER_BODY|MADRA_PER_FOUNDATION|AbilityStatsDisplay|StatTooltip|abilities/(ability_stats_display|stat_label|stat_tooltip)|^(foundation|resilience|willpower) = " -- scripts scenes singletons tests resources ":!tests/unit/test_save_migration.gd" ":!tests/unit/test_combat_effect_data.gd" ":!scripts/resource_definitions/path_progression/path_effects_summary.gd" ":!singletons/path_manager/path_manager.gd"`. GUT never loads unused scripts, so this is the check for removed names and Task 1.1's deleted widgets; the two excluded test files name old fields on purpose (Task 1.4's v1 save, Task 1.9's absence check), and `PathEffectsSummary.attribute_bonuses` is the path perks' own field, which phase 1 keeps. Expected: no output. Fix a hit in its own commit.
  - `git diff --stat main...HEAD -- docs`. Expected: only `docs/superpowers/` and `docs/inventory/ITEMS.md`, which code reads.
- [ ] **Step 3: Play the game on its own save and check it by hand.** `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64.exe" --path . scenes/main/main_game/main_game.tscn -- --preset=tribulation_ready --save=user://dev/runs/phase1.tres`. If this session can't drive the window, ask Lionel to run the checks. Expected: every check holds, and the console shows no script error.
  1. The Character book (C) shows the six stats on two sides: Strength and Spirit at Lv 10 and capped, the rest at Lv 1.
  2. Body's page reads Max Health 100 → 110, Spirit lists the Aura Well, Strength says "Nothing trains this yet", and In a fight reads Health 100, Madra 100, Stamina 50, 0%, 0%, 0%, Armor 0, Ward 0.
  3. With the book open, set Agility to Lv 6 from the dev panel's Player tab (Ctrl+Shift+D): the tile follows, and Dodge chance reads 8.8%.
  4. The Tribulation card is ENTER. Set Strength to Lv 9: the card turns to TRIAL with "Strength Lv 9 / 10", the Goals board lists the same line, and a click logs "The Tribulation needs Strength Lv 9 / 10." Set it back to Lv 10: the card is ENTER again.
  5. Award the Iron Shortsword from the Items tab and equip it. The inventory, the item panel and the merchant read "+50% Strength · +9 now" (Lv 10 is 19 points) and "+10% Agility · +2 now", and Strength's page shows Gear +9.
  6. The Abilities book's Basic Strike shows one Strength part.
  7. Quit, then relaunch with `-- --save=user://dev/runs/phase1.tres` alone: the levels are as you left them.
- [ ] **Step 4: Open the PR.** `git status --short` shows nothing staged you didn't intend (no `.godot/`, no stray `.import` cache). `git push -u origin feat/game-stats-rework-e6a4b4`. Write the body to a temporary file outside the repo and run `gh pr create --base main --head feat/game-stats-rework-e6a4b4 --title "feat(stats): six trained stats with levels, XP and a stage cap" --body-file <that file>`. The body, in order: what phase 1 delivers; "Not in this PR": the Madra pool, cycling XP, Core Density from kills, body refining; "Do not publish to itch: the breakthrough can't be reached in play until phase 5."; the test plan (the suite and Step 3's checks); the list below; last, the line `🤖 Generated with [Claude Code](https://claude.com/claude-code)`. Expected: the PR's URL.

```
## Docs to update
- docs/infrastructure/CHARACTER.md: the six stats, levels, XP and the cap; StatTrainingData, StatProgressionData; the training API and signals (base_attribute_changed gone); the Character book; StatDisplay
- docs/combat/COMBAT.md: the stat block (make(), armor, Ward); main-stat damage; armor and Ward defence; dodge; Control's cuts
- docs/abilities/ABILITIES.md: the one main-stat breakdown part; previews refreshed on stats_changed; the deleted stat widgets
- docs/abilities/ABILITIES_MATRIX.md: retuned scalings (Lv 1: 25, 28, 50); cut costs and cooldowns
- docs/infrastructure/EFFECTS.md: AwardAttributeEffectData awards a capped level; mind_madra_multiplier
- docs/cultivation/CULTIVATION.md: stat_level_cap, get_stat_level_cap(); CORE_FULL_LOG's new line
- docs/cultivation/breakthrough-tribulation.md: the gate (trained levels only), get_missing_requirements(), the card's line, the refusal, the intro text
- docs/infrastructure/PERSISTENCE.md: save version 2, stat_training, _migrate_to_v2()
- docs/tooling/DEV_TOOLS.md: set_stat_level(), raise_stat_to_cap(), the stat row, RAISE_STAT_TO_CAP, beat_9_ready, tribulation_ready's description
- docs/testing/TESTING.md: the CharacterManager log pair ("Updated 8 attributes"); coverage rows (base_attribute_changed; the stat Set control); the newer-build warning's "this build knows 2"
- docs/adventuring/ADVENTURING.md: Agility's Stamina regen, dodge and "Dodged", the Aura Well rest's Mind multiplier, the default numbers
- docs/inventory/INVENTORY.md: gear text ("+50% Strength · +5 now", "Armor 6", "Ward 4"), reprinted on stats_changed
- docs/inventory/EQUIPMENT_DESIGN.md: floored percent bonuses, armor, Ward; the "no parallel stat systems" principle
- docs/infrastructure/UNLOCKS.md: base_attribute_changed gone; ATTRIBUTE_VALUE reads totals
- docs/progression/FOUNDATION_PLAYTHROUGH.md: the breakthrough needs Strength and Spirit at the cap (out of reach until phase 5)
- docs/UI_STYLING.md and docs/STYLE_GUIDE.md: B8's deleted widgets and their orphaned variants LabelSeparatorDot and PanelStatPill; K11 if the book's look changed
- docs/infrastructure/MAIN_VIEW.md: the Character book row, StatDisplay among the utilities, the dock's cut Madra cost
- docs/infrastructure/LOGGING.md: the Tribulation refusal reads "The Tribulation needs <requirements>." (TribulationPresenter)
- docs/zones/ZONES.md: the Tribulation card's stat line and refusal; ENTER also needs Strength and Spirit at the cap
- docs/progression/QUESTS.md: the Breakthrough milestone lists each missing requirement, reads "Face the Tribulation" only when nothing is missing, and re-reads on CharacterManager.stat_level_changed
- docs/infrastructure/RESOURCES.md: the adventure capacity is Mind × 10
```

---

## Phase 2: One Madra pool

**Goal:** one saved Madra pool for home and runs, sized by Mind: Core Density stops capping it, a run spends straight from it and leaves the rest there, and every Madra readout shows it (design, "Phase 2: One Madra pool").

**Branch and PR:** `feat/stats-rework-2-madra-pool`, cut from `main` after phase 1's PR merges (Task 2.0); one PR, opened in Task 2.5.

**From phase 1:** `CharacterManager.get_stat(StatModifierData.Stat.MAX_MADRA)`, Mind × 10 plus modifiers: 100 for a new character, as `q_fill_core` needs (Task 1.1's `get_max_madra()`, read through the MAX_MADRA arm Task 1.3 keeps in `CharacterManager._get_base_stat()`); `CharacterManager.stats_changed`, `set_stat_level()` and `SaveGameData.stat_training` (Task 1.3); `StatTrainingData.set_level()` (Task 1.2); `CharacterAttributesData.make()` (Task 1.1); `EquipmentDefinitionData.stat_percent_bonuses` (Task 1.6); the "In a fight" block's `CharacterView.fight_lines()`, `%FightRows` and `_refresh_if_shown()` (Task 1.16). Expected values use phase 1's starting numbers (Mind Lv 3: 120 max Madra; Lv 6: 150; +50% Mind: +5 at Lv 1); a retune changes them.

**Conventions in this phase's steps:**
- "Run `<files>`" is the Global Constraints' one-process test command with `-gtest=` and each file's `res://` path; a bare file name is the one under the task's **Files**, and "the task's test files" are all of those. "The full suite" is `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_tests.ps1`.
- "Commit" means: check that `git diff HEAD` shows only this task's files, stage its **Files** by path (plus a new test's `.gd.uid`: after creating a test file, run `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --import` once, because the `-s` test command imports nothing, then check that `git status --short project.godot` prints nothing), and `git commit` with the given subject and body, ending with the Co-Authored-By trailer.
- "The save swap" is this fixture: `var _original_save: SaveGameData`; `before_each()` keeps `PersistenceManager.save_game_data` there, sets `SaveGameData.new_current()` and emits `save_data_reset`; `after_each()` puts the original back, emits `save_data_reset`, then calls `ActionManager.stop_action()` while `ActionManager.get_current_action() != null`.
- `_max_madra_source(amount: float) -> Callable` provides one `StatModifierData.new(StatModifierData.Stat.MAX_MADRA, StatModifierData.Kind.FLAT, amount)`, built like `test_player_vitals_manager.gd`'s `_max_health_source()`; each test file that uses it declares its own.

**The rules this phase builds:**
- `ResourceManager` owns the pool (`SaveGameData.madra`, saved already); `ResourceManager.get_max_madra()` is the max Madra stat.
- One over-max rule: the pool never holds more than the max. `add_madra()` and `set_madra()` clamp to [0, max], a max that drops (`CharacterManager.stats_changed`) brings the pool down, and a save loads at most at the max. A version-1 save's pool (600 at a full Foundation core under the old cap) is cut to the new max this way, with no save version step.
- A run needs half the max to start and spends nothing to start. It spends from the pool (the player's `VitalsManager` becomes a façade over it; enemies keep their own Madra), Scales and rest tiles refill it with no log line, and what is left when it ends stays.
- Health doesn't change until phase 5: it still refills at every run start. Expanded Core and Madra Reclamation stay inert.

---

### Task 2.0: Phase 2 mock-ups

**Files:**
- Create: a Design canvas "One Madra Pool" (an Artifact, not a repo file)
- Modify: `docs/superpowers/plans/2026-11-04-stats-rework.md` (an "Approved" line under this task; the bold copy in Tasks 2.3 and 2.4 where Lionel changes it)

**Interfaces:**
- Consumes: phase 1's approved canvas (Task 1.0); the cabinet and the "In a fight" block as phase 1 built them (Task 1.16).
- Produces: the approved copy Tasks 2.3 and 2.4 build: the cabinet's Madra figures, the adventure card's ready line, the end card's Madra line, the book's Madra row.

- [ ] **Step 1: Start the branch.** Once phase 1's PR has merged: `git fetch origin`, `git switch -c feat/stats-rework-2-madra-pool origin/main`, then `powershell -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/godot_project_list.ps1 label "One Madra pool"`. Expected: `git status` shows the new branch, nothing to commit.
- [ ] **Step 2: Read the look:** `docs/STYLE_GUIDE.md`, `docs/UI_STYLING.md`, and phase 1's approved canvas (Artifact `list`).
- [ ] **Step 3: Draw four boards on a new canvas.** Run Artifact `quickstart` with intent `design` and create a canvas titled "One Madra Pool" from the Design type it names (never add boards to phase 1's). Use a new character's figures: 25 of 100 Madra, threshold 50. The bold copy is the proposal Tasks 2.3 and 2.4 build unless Lionel changes it:
  1. **The cabinet's Madra orb:** "25 / 100", over max Madra (Mind plus gear). Beside it: Mind gear on, "140 / 150"; the gear off, "100 / 100" (the pool comes down with the max); after a Core Density level-up, the max unmoved; at a run's start, the pellets fly from the orb while its figure stays put.
  2. **The adventure card:** below the threshold, unchanged ("25 / 50", the rod, "~17 s" while the Aura Well runs). At the threshold, "5 min run" on the left and **"carries 60 Madra"** on the right: the pool the run spends from, where today it prints the max.
  3. **The end card:** **"MADRA LEFT"** over **"46 / 100"**, in place of "MADRA SPENT" over "50": what the pool kept, over its max, as the Health line reads.
  4. **The Character book:** the "In a fight" block's Madra row reads **"46 / 100"**, the pool over its max, where phase 1 prints the max alone. It follows the pool while the book is open.
  The vitals plate and the Goals board's "Awaken Your Core" figure already show the pool and change no pixel: no board.
- [ ] **Step 4: Show Lionel and record his answer.** Send the canvas link and ask him to approve or change each board. Write "Approved <date>: <changes, or none>" under this task, and edit the bold copy in Task 2.3 Step 3 and Task 2.4 Step 3 to match. Tasks 2.1 and 2.2 change no screen and can start meanwhile; Tasks 2.3 and 2.4 wait for his approval.
- [ ] **Step 5: Commit:** `docs(stats): record the approved phase 2 mock-ups` / "Tasks 2.3 and 2.4 build the copy Lionel approved on the One Madra Pool canvas."

---

### Task 2.1: One Madra max, from Mind

**Files:**
- Modify: `singletons/resource_manager/resource_manager.gd`, `scripts/resource_definitions/cycling/advancement_stage/advancement_stage.gd`, `resources/cycling/advancement_stages/foundation_advancement_stage/foundation_advancement_stage.tres`, `resources/cycling/advancement_stages/copper_advancement_stage/copper_advancement_stage.tres`, `singletons/cultivation_manager/cultivation_manager.gd`
- Modify, to repoint the callers: `scenes/zones/cultivator_plate/cultivator_plate.gd`, `scenes/cycling/cycling_technique/cycling_technique.gd`, `scenes/cycling/cycling_view/cycling_view.gd`, `scenes/zones/zone_transition/zone_transition.gd`, `scenes/zones/zone_action_button/presenters/adventure_presenter.gd`, `singletons/dev_manager/dev_commands.gd`, `scripts/resource_definitions/character/character_attributes_data.gd` (the doc of `get_max_madra()` only)
- Test, in `tests/unit/`: `test_resource_manager.gd`, and for the old cap `test_cultivation_getters.gd`, `test_cultivation_manager.gd`, `test_foundation_tribulation_data.gd`
- Test, in `tests/integration/`: `test_adventure_flow.gd` (rewritten), `test_dev_commands.gd`, and for the old cap `test_cultivator_plate.gd`, `test_cycling_technique.gd`, `test_cycling_view.gd`, `test_zone_transition.gd`, `test_board_transition_camera.gd`

**Interfaces:**
- Consumes: phase 1's names under "From phase 1".
- Produces: `ResourceManager.get_max_madra() -> float`; `add_madra(amount: float, quiet: bool = false) -> float` and `set_madra(amount: float) -> void`, held to [0, `get_max_madra()`]; `get_adventure_madra_threshold() -> float`, now `get_max_madra() * 0.5`; `can_start_adventure() -> bool`, unchanged; `DevCommands.set_madra(value: float) -> String`, which also refuses a value above the max.
- Removed: `ResourceManager.get_adventure_madra_capacity()`, `get_adventure_madra_budget()`; `CultivationManager.get_max_madra()`, `get_max_madra_at()`; `AdvancementStageResource.max_madra_base`, `max_madra_per_core_density_level`, `get_max_madra()`.

**Skills:** `godot-prompter:save-load` (the clamp on load) and `godot-prompter:godot-testing`.

- [ ] **Step 1: Write the failing tests.**

`tests/unit/test_resource_manager.gd`:
- The header: the one pool and its max (the max Madra stat), the over-max rule, gold, award_resource, the threshold, the signals and the log lines.
- The fixture becomes the save swap, bound through `_use_save()`, with `_save.madra = 0.0` and `_save.gold = 0.0` at the end of `before_each()` and `CharacterManager.remove_modifier_source(TEST_SOURCE)` first in `after_each()`. The stub stage, its two constants, the `_original_*_save` fields and the hand re-binds go: the max no longer depends on a stage. New members:
  - `const AttributeType = CharacterAttributesData.AttributeType`; `const TEST_SOURCE: StringName = &"test_resource_manager"`; `const NEW_MAX_MADRA: float = 100.0` (a new character's max: Mind Lv 1 (10) x 10); `var _save: SaveGameData`; `_max_madra_source()`.
  - `_use_save(save: SaveGameData) -> void` binds a save as a load does: sets `_save` and `PersistenceManager.save_game_data`, then emits `save_data_reset`.
  - `_raise_max_by(amount: float) -> void` puts a flat bonus on the max Madra stat: `CharacterManager.set_modifier_source(TEST_SOURCE, _max_madra_source(amount))`.
- Delete `_pool_cap()`, `_adventure_capacity()`, `test_add_madra_cap_grows_with_core_density_level`, `test_add_madra_above_a_lowered_cap_keeps_the_pool`, `test_spending_above_the_cap_still_spends`, `test_adventure_capacity_follows_mind_not_stage_cap` (phase 1's name for `test_adventure_capacity_follows_foundation_not_stage_cap`) and `test_adventure_budget_is_madra_up_to_capacity`: no pool sits above its max any more, and there is one cap, not two.
- `NEW_MAX_MADRA` replaces `_pool_cap()` in `test_add_madra_keeps_the_pool_between_zero_and_the_cap` (renamed `…_the_max`, its cases "the max absorbs the overflow" and "an add at the max stays at the max"), `test_add_madra_emits_capped_total` (renamed `test_add_madra_emits_the_total_at_the_max`) and `test_award_resource_adds_to_its_type`. `test_set_madra_sets_value` gains `{"name": "a value past the max stops at the max", "value": 150.0, "expected": 100.0}`. `test_adventure_threshold_is_half_the_max` replaces `test_adventure_threshold_is_half_capacity`; `test_can_start_adventure_at_threshold`, `test_cannot_start_adventure_below_threshold` and the other tests stay.
- Add, under MAX MADRA, ONE OVER-MAX RULE and ADVENTURE THRESHOLD headers:

```gdscript
func test_max_madra_is_the_max_madra_stat() -> void:
	var cases: Array[Dictionary] = [
		{"name": "a new character", "mind_level": 1, "bonus": 0.0, "max": 100.0},
		{"name": "Mind Lv 3", "mind_level": 3, "bonus": 0.0, "max": 120.0},
		{"name": "a +50 bonus on max Madra", "mind_level": 1, "bonus": 50.0, "max": 150.0},
	]
	for case: Dictionary in cases:
		CharacterManager.set_stat_level(AttributeType.MIND, case.mind_level)
		_raise_max_by(case.bonus)
		assert_eq(ResourceManager.get_max_madra(), case.max, case.name)

## Core Density sets no Madra cap any more.
func test_core_density_leaves_the_max_alone() -> void:
	_save.core_density_level = 50.0
	assert_eq(ResourceManager.get_max_madra(), NEW_MAX_MADRA)

## Mind gear off, say.
func test_a_falling_max_brings_the_pool_down() -> void:
	_raise_max_by(50.0)
	ResourceManager.set_madra(150.0)
	watch_signals(ResourceManager)
	CharacterManager.remove_modifier_source(TEST_SOURCE)
	assert_eq(ResourceManager.get_madra(), 100.0)
	assert_signal_emitted_with_parameters(ResourceManager, "madra_changed", [100.0])

## A version-1 save can hold 600, from the old Core Density cap.
func test_a_save_loads_with_its_pool_at_most_the_max() -> void:
	var cases: Array[Dictionary] = [
		{"name": "a pool from the old Core Density cap", "madra": 600.0, "expected": 100.0},
		{"name": "a pool under the max", "madra": 45.0, "expected": 45.0},
	]
	for case: Dictionary in cases:
		var save := SaveGameData.new_current()
		save.madra = case.madra
		_use_save(save)
		assert_eq(ResourceManager.get_madra(), case.expected, "%s: the pool" % case.name)
		assert_eq(save.madra, case.expected, "%s: the save, so the next write keeps it" % case.name)

## The save-reset path of ResourceManager._on_stats_changed().
func test_a_save_reset_leaves_the_old_saves_pool_alone() -> void:
	var old := SaveGameData.new_current()
	old.stat_training.set_level(AttributeType.MIND, 6)
	old.madra = 150.0
	_use_save(old)
	assert_eq(ResourceManager.get_madra(), 150.0, "precondition: Mind Lv 6 holds 150")
	_use_save(SaveGameData.new_current())
	assert_eq(old.madra, 150.0, "the save left behind is not cut to the new save's max of 100")

func test_adventure_threshold_is_half_the_max() -> void:
	var cases: Array[Dictionary] = [
		{"name": "a new character", "bonus": 0.0, "threshold": 50.0},
		{"name": "a +50 bonus on max Madra", "bonus": 50.0, "threshold": 75.0},
	]
	for case: Dictionary in cases:
		_raise_max_by(case.bonus)
		assert_eq(ResourceManager.get_adventure_madra_threshold(), case.threshold, case.name)
```

`test_a_falling_max_above_the_pool_leaves_it_alone` (after `test_a_falling_max_brings_the_pool_down`) is that test with `ResourceManager.set_madra(80.0)`, asserting the pool stays 80.0 and `assert_signal_not_emitted(ResourceManager, "madra_changed")`.

`tests/integration/test_adventure_flow.gd`: replace the whole file; its budget and two-cap tests go. The header: starting a run with one pool, Mind gear going through the real InventoryManager and CharacterManager (plan Review Focus 5). It holds the save swap, `const ACCESSORY := EquipmentDefinitionData.EquipmentSlot.ACCESSORY` and `_wear_mind_ring() -> void`, which equips with `InventoryManager.equip_item(instance, ACCESSORY, -1, 0)` an `ItemInstanceData` of an `EquipmentDefinitionData` (`item_id` "test_adventure_flow_ring", `item_name` "Test Mind Ring", `slot_type` ACCESSORY, `stat_percent_bonuses` from a typed `Dictionary[StringName, float]` var holding `{&"mind": 0.5}`): +5 Mind at Lv 1, so 150 max Madra and a threshold of 75. The tests:

```gdscript
func test_mind_gear_raises_the_threshold() -> void:
	ResourceManager.set_madra(60.0)
	assert_true(ResourceManager.can_start_adventure(), "precondition: 60 clears a threshold of 50")
	_wear_mind_ring()
	assert_eq(ResourceManager.get_adventure_madra_threshold(), 75.0, "half of the ring's 150")
	assert_false(ResourceManager.can_start_adventure(), "60 falls short of 75")

func test_taking_mind_gear_off_brings_the_pool_down() -> void:
	_wear_mind_ring()
	ResourceManager.set_madra(140.0)
	InventoryManager.unequip_item(ACCESSORY, 0)
	assert_eq(ResourceManager.get_madra(), 100.0, "the pool comes down to the max without the ring")
	assert_true(ResourceManager.can_start_adventure(), "100 still clears a threshold of 50")
```

`tests/integration/test_dev_commands.gd`, under MADRA, GOLD AND PATH POINTS:

```gdscript
func test_set_madra_refuses_more_than_the_max() -> void:
	ResourceManager.set_madra(30.0)
	assert_ne(DevCommands.set_madra(101.0), "", "101 is past a new character's max of 100")
	assert_eq(ResourceManager.get_madra(), 30.0, "Madra is left as it was")
	assert_eq(DevCommands.set_madra(100.0), "", "the max itself is fine")
```

The tests that read the old cap:
- `test_cycling_technique.gd`: the header's "(25 Madra, cap 100)" becomes "(25 Madra, max 100)". Add `const ROOM_SOURCE: StringName = &"test_cycling_technique_room"`, its `remove_modifier_source()` in `after_each()`, `_max_madra_source()`, and `_make_room(amount: float) -> void`, which sets `ROOM_SOURCE` to `_max_madra_source(amount)` so a cycle's Madra has room under the max. `_make_room(200.0)` replaces `core_density_level = 40.0` in `test_the_result_counts_the_madra_the_pool_gained`; `_make_room(500.0)` replaces `core_density_level = 100.0` in `test_a_hitch_through_the_end_pays_only_the_steps_left`, `test_auto_restart_keeps_the_rate` and `test_a_manual_start_begins_from_an_empty_window`. Their preconditions read `ResourceManager.get_max_madra()` (600 where they assert a value), and `test_no_madra_or_pellets_at_the_cap`'s becomes `assert_eq(ResourceManager.get_max_madra(), 100.0, "precondition: the max is 100")`. Delete `test_madra_above_the_cap_is_left_alone`: the pool can't pass its max.
- `test_cycling_view.gd`: the header's "cap 100" becomes "max 100"; `test_the_status_label_stops_promising_xp_at_a_full_core` uses `ResourceManager.set_madra(ResourceManager.get_max_madra())`.
- `test_zone_transition.gd` `_start_drain()` (doc: "on a full pool") and `test_board_transition_camera.gd` `_zoom_into_an_adventure()`: `ResourceManager.set_madra(ResourceManager.get_max_madra())`.
- `test_cultivation_getters.gd`: delete the MAX MADRA section (`test_max_madra_follows_level`) and `test_max_madra_at_a_level_follows_the_stages_curve`; the header drops max Madra and Foundation's 100 + 5 per level curve.
- `test_cultivation_manager.gd`: `_with_copper()` drops its two `copper.max_madra_*` lines and its doc's "600 Madra plus 10 a level"; delete `test_madra_cap_follows_the_new_stage`.
- `test_foundation_tribulation_data.gd`: delete `test_the_madra_cap_does_not_drop_at_the_breakthrough`, and the header's clause that a full Foundation core holds as much Madra as an empty Copper one.
- `test_cultivator_plate.gd`: delete `test_madra_fill_follows_max` (Task 2.4 tests what the max follows now).

- [ ] **Step 2: Run them and see them fail.** Run `test_resource_manager.gd`, `test_adventure_flow.gd`, `test_dev_commands.gd` and `test_cycling_technique.gd`. Expected: FAIL. The scripts that call `ResourceManager.get_max_madra()` don't parse, so GUT runs none of their tests; `test_set_madra_refuses_more_than_the_max` fails, as `DevCommands.set_madra(101.0)` returns "".

- [ ] **Step 3: Implement the max and the one over-max rule, and remove the stage cap.** CharacterManager (4th autoload) binds each save before ResourceManager (6th), at boot and on `save_data_reset`, so ResourceManager's clamp may read `CharacterManager.get_stat()`.
  - `resource_manager.gd`:
    - `get_max_madra()` returns `CharacterManager.get_stat(StatModifierData.Stat.MAX_MADRA)`. Doc: the most Madra the pool holds, the max Madra stat; every readout shows the pool against it.
    - `add_madra()` clamps with `clampf(before + amount, 0.0, get_max_madra())`; its doc: held to [0, max], returns what it added, logs "Gained N Madra" unless quiet or under 1 (the "a pool above the cap is kept" sentence goes). `set_madra()` clamps with `clampf(amount, 0.0, get_max_madra())`, with a `##` doc.
    - `get_adventure_madra_threshold()` returns `get_max_madra() * 0.5` (doc: half the max). Delete `get_adventure_madra_capacity()` and `get_adventure_madra_budget()`.
    - `_clamp_to_max() -> bool` lowers a pool above `get_max_madra()` to the max, emits nothing, and returns whether it did. `_update_resources()`, after the null check and before the two emits: `if _clamp_to_max(): Log.info("ResourceManager: Madra was past its max of %d. Loaded at the max" % int(get_max_madra()))`.
    - `_ready()`: `CharacterManager.stats_changed.connect(_on_stats_changed)` replaces the `CultivationManager` check, and the handler keeps the save-reset guard:

```gdscript
## A max that drops brings the pool down. On a save reset CharacterManager
## announces the new save's stats before this re-binds: skip, as
## _update_resources() clamps once it has.
func _on_stats_changed() -> void:
	if CharacterManager.live_save_data != live_save_data:
		return
	if _clamp_to_max():
		madra_changed.emit(live_save_data.madra)
```

  - `advancement_stage.gd`: delete `max_madra_base`, `max_madra_per_core_density_level` and `get_max_madra(level)`; Foundation's `.tres` loses `max_madra_base = 100.0` and `max_madra_per_core_density_level = 5.0`, Copper's `max_madra_base = 600.0` and `max_madra_per_core_density_level = 10.0`. `cultivation_manager.gd`: delete `get_max_madra()` and `get_max_madra_at(level)`.
  - Repoint the callers to `ResourceManager.get_max_madra()`:
    - `CultivatorPlate._update_madra()` and its doc (Task 2.4 adds the `stats_changed` listener and drops the Core Density refreshes).
    - `CyclingTechnique._madra_full()`: `ResourceManager.get_madra() >= ResourceManager.get_max_madra()`; its doc and `_draw_madra_step()`'s say "max" and drop "Madra already over it is left alone". `CyclingView._update_status()`'s `madra_full` uses the same test.
    - `ZoneTransition._on_adventure_start_requested()`: `_drain_budget = ResourceManager.get_madra()` (the whole pool, which never passes the max), and the ratio divides by `ResourceManager.get_max_madra()`. Task 2.3 removes the spend.
    - `AdventurePresenter._update_state()`: `"carries %d Madra" % floori(ResourceManager.get_max_madra())`, the same figure as before (Task 2.4 changes the copy). In the class doc, "<capacity>" becomes "<max>", and the "Capacity is…" sentence becomes "The threshold is half of max Madra, so Mind and gear move it: the card follows stat changes too."
    - `CharacterAttributesData.get_max_madra()`'s doc becomes `## Max Madra: Mind x 10, before modifiers. ResourceManager.get_max_madra() is the one pool's max.`
  - `DevCommands.set_madra()`: after the negative check, `if value > ResourceManager.get_max_madra(): return "Madra can't pass its max of %d" % int(ResourceManager.get_max_madra())`. Doc: "Refuses a negative value or one above the max."

- [ ] **Step 4: Run them and see them pass.** Run the task's test files plus `res://tests/unit/test_quiet_madra.gd,res://tests/integration/test_zone_action_cards.gd`: PASS. `git grep -n -e get_max_madra_at -e max_madra_base -e max_madra_per_core_density_level -e get_adventure_madra_capacity -e get_adventure_madra_budget -e "CultivationManager.get_max_madra" -- scenes scripts singletons tests resources`: no output. The full suite: PASS.

- [ ] **Step 5: Commit:** `feat(madra): size the Madra pool by Mind alone` / "Core Density no longer sets a Madra cap. ResourceManager.get_max_madra() is the max Madra stat, and the pool never holds more: adds and sets clamp, a falling max brings it down, and a save loads at most at the max. Home and runs can now share one pool."

---

### Task 2.2: The player's Madra is the pool

**Files:**
- Modify: `scenes/combat/combatant/vitals_manager/vitals_manager.gd`
- Modify: `scenes/adventure/adventure_view/adventure_view.gd` (`_initialize_combat_resources()`), `singletons/dev_manager/dev_commands.gd` (`refill_vitals()`), `singletons/player_manager/player_manager.gd` (`reset_vitals()`'s doc)
- Test, in `tests/unit/`: `test_player_vitals_manager.gd` (a new section), and for the player's Madra fields they wrote, `test_combat_consumable_manager.gd`
- Test, in `tests/integration/`, for the same fields: `test_vitals_plate.gd`, `test_technique_dock.gd`, `test_technique_dock_consumables.gd`, `test_dev_commands.gd`, `test_dev_adventure_commands.gd`, `test_adventure_view_frame.gd`, `test_adventure_map_zoom.gd`, `test_dev_hooks.gd`

**Interfaces:**
- Consumes: Task 2.1's ResourceManager (`get_madra()`, `get_max_madra()`, `set_madra()`, `add_madra()`, `madra_changed`).
- Produces the façade shape, which phase 5 mirrors for Health. For a player `VitalsManager` (`is_player`):
  - `current_madra: float` and `max_madra: float` read through ResourceManager (`get_madra()`, `get_max_madra()`); writing `current_madra` calls `ResourceManager.set_madra()`.
  - `_apply_madra_change(amount)` calls `ResourceManager.add_madra(amount, true)` (quiet), so `apply_vitals_change()` lands a non-zero Madra amount in the pool.
  - `signal madra_changed(new_madra: float)` is re-emitted once per pool change, from `ResourceManager.madra_changed`.
  - `initialize_current_values() -> void` has no `starting_madra` parameter. It fills Health and Stamina, and an enemy's Madra, never the player's.
  - Enemies keep in-memory Madra and are otherwise unchanged.

**Skills:** `godot-prompter:godot-testing`.

- [ ] **Step 1: Write the failing tests.**

`tests/unit/test_player_vitals_manager.gd` already swaps in a fresh save holding 25 Madra, builds `_vitals` as a player manager and removes `TEST_SOURCE` in `after_each()`. Its header adds the one pool. Add `const CRUDE_SCALE: ConsumableDefinitionData = preload("res://resources/items/consumables/crude_scale.tres")`, `_max_madra_source()`, and a MADRA: THE ONE POOL section:

```gdscript
func test_the_players_madra_reads_the_pool() -> void:
	ResourceManager.set_madra(46.0)
	CharacterManager.set_modifier_source(TEST_SOURCE, _max_madra_source(20.0))
	assert_eq(_vitals.current_madra, 46.0, "current Madra is the pool")
	assert_eq(_vitals.max_madra, 120.0, "max Madra is the pool's max")

func test_madra_changes_land_in_the_pool() -> void:
	var cases: Array[Dictionary] = [
		{"name": "Empty Palm's cost", "madra": 50.0, "change": -8.0, "expected": 42.0},
		{"name": "a Scale's refill", "madra": 50.0, "change": 20.0, "expected": 70.0},
		{"name": "a refill past the max stops at it", "madra": 90.0, "change": 20.0, "expected": 100.0},
		{"name": "a cost past the pool stops at 0", "madra": 5.0, "change": -8.0, "expected": 0.0},
	]
	for case: Dictionary in cases:
		ResourceManager.set_madra(case.madra)
		_vitals.apply_vitals_change(0.0, 0.0, case.change)
		assert_eq(ResourceManager.get_madra(), case.expected, case.name)

func test_writing_current_madra_sets_the_pool() -> void:
	_vitals.current_madra = 33.0
	assert_eq(ResourceManager.get_madra(), 33.0)

func test_each_pool_change_reaches_the_vitals_once() -> void:
	watch_signals(_vitals)
	ResourceManager.add_madra(5.0, true)
	_vitals.apply_vitals_change(0.0, 0.0, -10.0)
	assert_signal_emit_count(_vitals, "madra_changed", 2, "cycling's add and a technique's cost, once each")
	assert_signal_emitted_with_parameters(_vitals, "madra_changed", [20.0])

## A hit or a step changes no Madra, so the pool stays quiet: each of its
## signals sweeps every unlock condition.
func test_a_change_with_no_madra_leaves_the_pool_quiet() -> void:
	watch_signals(ResourceManager)
	_vitals.apply_vitals_change(-10.0, -5.0, 0.0)
	assert_signal_not_emitted(ResourceManager, "madra_changed")

## In-run refills stay quiet: no "Gained" line.
func test_a_scale_refills_the_pool_quietly() -> void:
	watch_signals(LogManager)
	CRUDE_SCALE.effects[0].process()
	assert_eq(ResourceManager.get_madra(), 45.0, "25 + 20")
	assert_signal_not_emitted(LogManager, "message_logged")

func test_initialize_current_values_leaves_the_pool_alone() -> void:
	ResourceManager.set_madra(30.0)
	_vitals.initialize_current_values()
	assert_eq(ResourceManager.get_madra(), 30.0)

func test_an_enemys_madra_is_its_own() -> void:
	var enemy := VitalsManager.new()
	enemy.character_attributes_data = CharacterAttributesData.make()
	add_child_autofree(enemy)
	enemy.initialize_current_values()
	enemy.apply_vitals_change(0.0, 0.0, -30.0)
	assert_eq(enemy.current_madra, 70.0, "100 of its own, less 30")
	assert_eq(ResourceManager.get_madra(), 25.0, "the pool is untouched")
```

The tests that wrote the player's Madra fields set the pool instead:
- `test_vitals_plate.gd`: add `const TEST_SOURCE: StringName = &"test_vitals_plate"` and `_max_madra_source()`. `_set_vitals(health, max_health, stamina, max_stamina)` drops its Madra parameters, and `_original_vitals` holds Health and Stamina only. Add `_set_madra(madra: float, max_madra: float) -> void`: `TEST_SOURCE` gets `_max_madra_source(max_madra - 100.0)` (a new character's max is 100), then `ResourceManager.set_madra(madra)`; call it before `_set_vitals()`, because the bonus re-reads the Health and Stamina maxima. `before_each()`: `_set_madra(80.0, 120.0)`, then `_set_vitals(142.0, 160.0, 80.0, 80.0)`. `after_each()`, once the plate and the combatant are freed: `CharacterManager.remove_modifier_source(TEST_SOURCE)`, then `_set_vitals.callv(_original_vitals)`. `test_orbs_fill_to_the_fraction`: `ResourceManager.set_madra(30.0)` replaces `_vitals.current_madra = 30.0`. `test_health_rounds_up_and_the_rest_round_down`: `_set_madra(79.9, 120.9)`, then `_set_vitals(141.2, 160.7, 39.9, 80.9)`. Every expected figure stays.
- `test_technique_dock.gd` and `test_technique_dock_consumables.gd`: `_set_vitals(health, max_health, stamina, max_stamina)` and `_original_vitals` lose Madra; `before_each()` calls `_set_vitals(100.0, 100.0, 50.0, 50.0)` and `ResourceManager.set_madra(100.0)`.
- `test_combat_consumable_manager.gd`: `_original_vitals = [current_health, max_health, current_stamina, max_stamina]`, restored in `after_each()` from indexes 0 to 3.
- `test_dev_commands.gd`: `_original_vitals = [vitals.current_health, vitals.current_stamina]` (doc: "The player's Health and Stamina"); the `current_madra` restore line goes.
- `test_dev_adventure_commands.gd`: `_saved_madra` and its two lines go; `RUN_MADRA`'s doc becomes "The pool the run starts on." `test_refill_vitals_keeps_the_run_madra` calls `ResourceManager.set_madra(RUN_MADRA)` before `_start_run()`, its precondition message becomes "the run plays on the pool", and it ends with `assert_eq(ResourceManager.get_madra(), madra_left, "the pool keeps what the run left")`.
- `test_adventure_view_frame.gd`: `VITALS_FIELDS` drops `&"max_madra"` and `&"current_madra"`; `_start_run()` calls `ResourceManager.set_madra(MADRA_BUDGET)` before `ActionManager.confirm_adventure_start(...)`; `test_start_fills_the_frame`'s Madra message becomes "the cabinet shows the pool the run plays on"; `test_a_key_uses_a_consumable_in_a_real_fight` adds `assert_eq(ResourceManager.get_madra(), expected_madra, "into the saved pool")`.
- `test_adventure_map_zoom.gd`: `VITALS_FIELDS` drops the two Madra fields.
- `test_dev_hooks.gd` `test_reset_vitals_gives_a_fresh_vitals_manager`: beside `stat_hooks`, take `var madra_hooks: int = ResourceManager.madra_changed.get_connections().size()`; after the frame, `assert_eq(ResourceManager.madra_changed.get_connections().size(), madra_hooks, "and its Madra hook")`.

- [ ] **Step 2: Run them and see them fail.** Run `test_player_vitals_manager.gd` and `test_vitals_plate.gd`. Expected: FAIL in the other five façade tests and the plate's Madra figures: reads give the in-memory value, the pool doesn't move, and one emission is counted, not two. The "quiet", "alone" and "its own" tests already pass: they pin what the façade must not break.

- [ ] **Step 3: Build the façade the Interfaces describe.**
  - `vitals_manager.gd`:
    - `max_madra` (still `= 100.0`) and `current_madra` get getters that read ResourceManager for the player and the stored value for an enemy. `current_madra`'s setter, for the player, calls `ResourceManager.set_madra(value)` and returns without emitting (`_on_pool_changed()` will); for an enemy it stores and emits as today. Their docs say the player's are the one pool's.
    - `_ready()`, player branch, connects `ResourceManager.madra_changed` to `_on_pool_changed(new_amount: float) -> void`, which emits `madra_changed(new_amount)`.
    - `initialize_current_values()` fills `current_health` and `current_stamina`, then `if not is_player: current_madra = max_madra`. Doc: Health and Stamina to their maxima, plus an enemy's Madra, never the player's pool.
    - `_apply_madra_change(amount)`, player branch: `ResourceManager.add_madra(amount, true)` when `amount != 0.0`, then return. The enemy branch keeps today's clamp and drops its player-only `Log.info`.
    - `_on_stats_changed()` drops its `max_madra =` line. `apply_vitals_change()` gets a `##` doc: the player's Madra change lands in the saved pool, quietly; a zero change does nothing there.
  - `adventure_view.gd` `_initialize_combat_resources()` calls `PlayerManager.vitals_manager.initialize_current_values()`. Until Task 2.3 stops the spend, a real run starts on whatever the drain left.
  - `dev_commands.gd` `refill_vitals()`: `_while_paused(vitals.initialize_current_values)`; doc: fills Health and Stamina, and the Madra pool stays as it is.
  - `player_manager.gd` `reset_vitals()` doc: "nothing of a run carries over: not its Health or Stamina, nor its regen. Madra is ResourceManager's saved pool and stays."

- [ ] **Step 4: Run them and see them pass.** Run the task's test files: PASS. The full suite: PASS.

- [ ] **Step 5: Commit:** `feat(madra): make the player's Madra the saved pool` / "The player's VitalsManager reads and writes ResourceManager's pool, so technique costs, Scales and rest tiles spend and refill the one saved pool, quietly, and the vitals plate shows it. Enemies keep their own Madra."

---

### Task 2.3: Runs start and end on the pool

**Files:**
- Modify: `scenes/zones/zone_transition/zone_transition.gd`, `singletons/action_manager/action_manager.gd`, `scenes/adventure/adventure_view/adventure_view.gd`, `scenes/ui/main_view/states/adventure_view_state.gd`, `scenes/ui/dev_panel/tabs/adventure_tab.gd`, `scripts/resource_definitions/adventure/adventure_result_data.gd`, `scenes/adventure/adventure_end_card/adventure_end_card.gd`, `scenes/adventure/adventure_end_card/adventure_end_card.tscn`
- Test, in `tests/integration/`: `test_zone_transition.gd`, `test_adventure_end_flow.gd`, `test_adventure_end_card.gd` (new), and for the callers of the old signatures `test_adventure_view_frame.gd`, `test_adventure_map_zoom.gd`, `test_play_stats_recording.gd`, `test_dev_adventure_commands.gd`, `test_dev_panel.gd`
- Test, in `tests/unit/`: `test_adventure_result_data.gd`, `test_adventure_view_state.gd`

**Interfaces:**
- Consumes: Task 2.1's `get_madra()` and `get_max_madra()`; Task 2.2's façade and `initialize_current_values()`; Task 2.0's end card copy.
- Produces: `signal ActionManager.start_adventure(action_data: AdventureActionData)`; `ActionManager.confirm_adventure_start(action_data: AdventureActionData) -> void`; `AdventureView.start_adventure(action_data: AdventureActionData) -> void`; `AdventureResultData.madra_left: float` and `madra_max: float`; `static func ZoneTransition.drain_pellet_count(madra: float, max_madra: float) -> int`.
- Removed: the `madra_budget` parameters, `AdventureView._madra_budget`, `AdventureResultData.madra_spent`, ZoneTransition's spend.

**Skills:** `godot-prompter:hud-system` (the end card) and `godot-prompter:godot-testing`.

- [ ] **Step 1: Write the failing tests.**

`test_zone_transition.gd`: the header's "pours the Madra budget out as pellets" becomes "pours pellets as a flourish, spending nothing". The last asserts of `test_drain_pours_pellets_then_starts_the_adventure` become:

```gdscript
	assert_signal_emitted_with_parameters(ActionManager, "start_adventure", [ZoneManager.get_action_by_id(ADVENTURE_ID)])
	assert_false(_transition.is_transitioning())
	assert_eq(ResourceManager.get_madra(), 100.0, "the pellets spend nothing: the run spends from the pool")
```

Add:

```gdscript
## From DRAIN_MIN_PARTICLES (empty) to DRAIN_MAX_PARTICLES (full).
func test_a_fuller_pool_pours_more_pellets() -> void:
	var cases: Array[Dictionary] = [
		{"name": "an empty pool", "madra": 0.0, "max": 100.0, "pellets": 8},
		{"name": "half full", "madra": 50.0, "max": 100.0, "pellets": 16},
		{"name": "full", "madra": 100.0, "max": 100.0, "pellets": 25},
		{"name": "no max", "madra": 10.0, "max": 0.0, "pellets": 8},
	]
	for case: Dictionary in cases:
		assert_eq(ZoneTransition.drain_pellet_count(case.madra, case.max), case.pellets, case.name)
```

`test_adventure_end_flow.gd`: `_start_adventure()` calls `ActionManager.confirm_adventure_start(action)`; the comments that say the Madra drains before a run say "while the start's pellets fly"; add:

```gdscript
## Plan Review Focus 5: the end card is told the pool as it stands.
func test_a_run_quit_midway_keeps_what_it_spent_and_what_is_left() -> void:
	_set_player_health(40.0)
	ResourceManager.set_madra(80.0)
	_begin_a_run_without_a_map(300.0)
	PlayerManager.vitals_manager.apply_vitals_change(0.0, 0.0, -30.0)
	_view.stop_adventure()
	assert_eq(ResourceManager.get_madra(), 50.0, "what the run spent stays spent, and the rest stays in the pool")
	assert_eq(_results.size(), 1, "the retreat ended the run once")
	if _results.size() == 1:
		assert_eq(_results[0].madra_left, 50.0, "the end card is told the Madra left")
		assert_eq(_results[0].madra_max, 100.0, "over the pool's max")
```

`test_adventure_result_data.gd`: in `test_defaults`, `["madra_spent", 0.0]` becomes `["madra_left", 0.0]` and `["madra_max", 0.0]`; in `test_populate`'s victory case, `"madra_spent": 150.0` becomes `"madra_left": 46.0` and `"madra_max": 100.0`.

`test_adventure_end_card.gd` (new): `extends GutTest`, a header (the end card's Madra line shows what the pool kept, over its max), `const EndCardScene := preload("res://scenes/adventure/adventure_end_card/adventure_end_card.tscn")`, and:

```gdscript
func test_the_madra_line_shows_what_the_pool_kept() -> void:
	var card: AdventureEndCard = EndCardScene.instantiate() as AdventureEndCard
	add_child_autofree(card)
	var result := AdventureResultData.new()
	result.madra_left = 46.0
	result.madra_max = 100.0
	await card.show_results(result)
	assert_eq((card.get_node("%MadraValueLabel") as Label).text, "46 / 100")
```

The callers of the old signatures:
- `test_adventure_view_frame.gd`: `MADRA_BUDGET` becomes `RUN_START_MADRA` (doc: "The pool each run starts on: exactly half a new character's 100, the threshold"). `_start_run()` keeps Task 1.12's `stamina_regen_modifier` parameter, calls `ResourceManager.set_madra(RUN_START_MADRA)` and `ActionManager.confirm_adventure_start(action)`, and its doc drops "with its budget". `test_start_fills_the_frame` adds `assert_eq(ResourceManager.get_madra(), RUN_START_MADRA, "starting the run spent none of it")`.
- `confirm_adventure_start()` loses its second argument in `test_adventure_map_zoom.gd` (where `MADRA_BUDGET` goes), `test_play_stats_recording.gd` and `test_dev_adventure_commands.gd`; `test_dev_panel.gd` emits `ActionManager.start_adventure.emit(AdventureActionData.new())`; `test_adventure_view_state.gd` calls `_adventure_state._on_start_adventure(null)` in all four places.

- [ ] **Step 2: Run them and see them fail.** Run `test_zone_transition.gd`, `test_adventure_end_flow.gd`, `test_adventure_result_data.gd` and `test_adventure_end_card.gd`. Expected: FAIL. The first two and the end card test don't parse (`drain_pellet_count` isn't declared, `confirm_adventure_start()` takes two arguments, `madra_left` isn't a member of AdventureResultData); `test_adventure_result_data.gd` reads null for `madra_left`, not 0.0.

- [ ] **Step 3: Implement the start and the end.**
  - `zone_transition.gd`:
    - Add `drain_pellet_count()` (doc: the pellets a run's start pours for madra out of max_madra): `int(lerpf(DRAIN_MIN_PARTICLES, DRAIN_MAX_PARTICLES, fullness))`, fullness being `madra / max_madra` clamped to 0..1, or 0 when `max_madra <= 0.0`.
    - `_on_adventure_start_requested()` sets `_drain_total_particles = drain_pellet_count(ResourceManager.get_madra(), ResourceManager.get_max_madra())`.
    - Delete `_drain_budget`, `_drain_budget_ratio`, `_drain_madra_per_particle`, `_drain_deficit_particle_amount`, `_drain_total_particles`' deficit comment, the deficit-pellet block and `ResourceManager.spend_madra()` in `_spawn_drain_particle()`. The last pellet's `delivered` still starts the zoom.
    - `_on_zoom_complete()` calls `ActionManager.confirm_adventure_start(_pending_adventure_data)`. The class doc says the pellets are a flourish, because the run spends from the pool itself.
  - `action_manager.gd`: the signal and `confirm_adventure_start()` carry the action only; it keeps the play-stat count, and its log line drops the budget.
  - `adventure_view.gd`:
    - `start_adventure()` takes the action only; delete `_madra_budget`; the comment over the `_initialize_combat_resources()` call drops the budget.
    - `_initialize_combat_resources() -> void` takes no parameter; its log is `Log.info("AdventureView: The run starts on %.1f Madra" % ResourceManager.get_madra())`, and its doc says Health and Stamina fill and Madra is the saved pool as it stands.
    - `_build_result_data()` sets `result.madra_left = ResourceManager.get_madra()` and `result.madra_max = ResourceManager.get_max_madra()`.
    - The comment in `stop_adventure()` says the action is current "while the start's pellets fly", not "while its Madra drains".
  - `adventure_view_state.gd`: `_on_start_adventure(_data: AdventureActionData) -> void`. `adventure_tab.gd`: `_on_adventure_started(_action: AdventureActionData) -> void`.
  - `adventure_result_data.gd`: `madra_spent` gives way to `## The Madra the pool held when the run ended: it stays there.` `var madra_left: float = 0.0` and `## The pool's max when the run ended.` `var madra_max: float = 0.0`.
  - The end card, with the copy approved in Task 2.0 (proposal **"MADRA LEFT"**, **"46 / 100"**): `adventure_end_card.gd` `_populate()` sets `madra_value_label.text = "%d / %d" % [floori(data.madra_left), floori(data.madra_max)]` (if the approved line shows the amount alone, drop `madra_max` everywhere), keeping the colour override; in `adventure_end_card.tscn`, MadraStat's `StatInfo/StatNameLabel` gets `text = "MADRA LEFT"`.

- [ ] **Step 4: Run them and see them pass.** Run the task's test files plus `res://tests/integration/test_board_transition_camera.gd`: PASS. `git grep -n -e madra_budget -e madra_spent -e _drain_budget -e "MADRA SPENT" -- scenes scripts singletons tests`: no output. The full suite: PASS.

- [ ] **Step 5: Commit:** `feat(adventure): start and end runs on the one pool` / "Starting a run spends nothing: the drain is a flourish and the run spends from the saved pool, so whatever is left at the end is still there. The budget parameter goes, and the end card shows the Madra left over its max."

---

### Task 2.4: Every Madra readout shows the pool

**Files:**
- Modify: `scenes/zones/cultivator_plate/cultivator_plate.gd`, `scenes/zones/zone_action_button/presenters/adventure_presenter.gd`, `scenes/character/character_view.gd`
- Test, in `tests/integration/`: `test_cultivator_plate.gd`, `test_zone_action_cards.gd`, `test_character_book_madra.gd` (new)

**Interfaces:**
- Consumes: Task 2.1's `get_madra()`, `get_max_madra()` and `madra_changed`; `CharacterManager.stats_changed`; Task 1.16's `static func CharacterView.fight_lines() -> Array[Dictionary]` (`{"label", "value"}` entries Health, Madra, Stamina, … in order, one `%FightRows` `TableRow` each; if Task 1.16 built the rows from another scene, `_madra_row_text()` reads that scene's value), `refresh()` and `_refresh_if_shown()`; Task 2.0's copy.
- Produces: `fight_lines()`'s Madra entry reads "<pool> / <max>". `CharacterView._rebuild_fight_rows() -> void`, which phase 5's Task 5.4 also calls on `ResourceManager.health_changed` for the Health entry.

**Skills:** `godot-prompter:godot-ui` and `godot-prompter:hud-system`.

- [ ] **Step 1: Write the failing tests.**

`test_cultivator_plate.gd`: add `const TEST_SOURCE: StringName = &"test_cultivator_plate"`, its `remove_modifier_source()` in `after_each()`, and `_max_madra_source()`. Under MADRA:

```gdscript
func test_the_madra_max_follows_the_max_madra_stat() -> void:
	ResourceManager.set_madra(100.0)
	CharacterManager.set_modifier_source(TEST_SOURCE, _max_madra_source(100.0))
	assert_eq(_text("MadraMaxLabel"), "/ 200")
	assert_almost_eq(_fill("MadraOrb"), 0.5, 0.0001, "100 of 200 Madra")
```

`test_zone_action_cards.gd`:
- `test_adventure_ready_copy_and_enter`: `assert_eq(card.get_detail_right_text(), "carries 60 Madra", "the pool the run spends from, in the right column")`.
- `test_adventure_follows_equipment_capacity`, with phase 1's +50% Mind ring on (max 150, threshold 75): `ResourceManager.set_madra(140.0)` replaces `set_madra(80.0)`, followed by `assert_true(_has_text_containing(card, "carries 140 Madra"))`; after the unequip, `assert_true(_has_text_containing(card, "carries 100 Madra"), "taking the ring off brings the pool down to the new max")`. Its opening comment says the threshold is half of max Madra.

`test_character_book_madra.gd` (new). The header: the In a fight block's Madra row, the pool over its max, live while the book is open. It holds the save swap; `const CharacterViewScene := preload("res://scenes/character/character_view.tscn")`; `const TEST_SOURCE: StringName = &"test_character_book_madra"`, removed first in `after_each()`; `_max_madra_source()`; and `var _view: CharacterView`, instanced and added with `add_child_autofree()` at the end of `before_each()`, after `AbilityManager._build_catalog_index()` as in `test_character_book.gd` (other suites leave a fake catalog). Then:

```gdscript
## The In a fight block's Madra entry: the second of fight_lines() (Task 1.16).
func _madra_entry() -> Dictionary:
	return CharacterView.fight_lines()[1]

## The Madra row as the open book prints it: the second row of %FightRows.
func _madra_row_text() -> String:
	var row: TableRow = _view.get_node("%FightRows").get_child(1)
	return (row.get_node("%Value") as RichTextLabel).get_parsed_text()

func test_the_madra_line_shows_the_pool_over_its_max() -> void:
	ResourceManager.set_madra(46.0)
	assert_eq(_madra_entry()["label"], "Madra", "precondition: the second entry is Madra")
	assert_eq(_madra_entry()["value"], "46 / 100")

func test_the_madra_line_follows_the_pool_and_its_max_while_open() -> void:
	_view.show()
	_view.refresh()
	ResourceManager.add_madra(1.5, true)
	assert_eq(_madra_row_text(), "26 / 100", "the Aura Well's trickle: 25 + 1.5")
	CharacterManager.set_modifier_source(TEST_SOURCE, _max_madra_source(50.0))
	assert_eq(_madra_row_text(), "26 / 150", "a bonus on max Madra")
```

- [ ] **Step 2: Run them and see them fail.** Run the task's test files. Expected: FAIL. The cabinet reads "/ 100" (it hears no `stats_changed`); the card reads "carries 100 Madra" (the max); the book's Madra entry and row read "100", Task 1.16's max alone.

- [ ] **Step 3: Build the three readouts** with the copy approved in Task 2.0.
  - `cultivator_plate.gd`: `_ready()` connects `CharacterManager.stats_changed` to a new `_on_stats_changed() -> void` that calls `_update_madra()` (doc: "Mind, gear and any modifier source move the max."). Delete the `_update_madra()` calls in `hold_core_xp()`, `release_core_xp()`, `_on_core_density_level_updated()` and `_on_advancement_stage_changed()`, there only because the max followed the Core Density level shown. The class doc drops "with the Madra max of the level shown", and `_update_madra()`'s doc says the max is the pool's (`ResourceManager.get_max_madra()`).
  - `adventure_presenter.gd` `_update_state()`: `button.set_detail_right("carries %d Madra" % floori(ResourceManager.get_madra()), ThemeConstants.LACQUER_BRASS)` (proposal **"carries 60 Madra"**: the pool). The class doc's "<max>" becomes "<pool>"; `_on_stats_changed()`'s doc says Mind, gear and any modifier source move the max and the threshold with it.
  - `character_view.gd`:
    - `fight_lines()`: the Madra entry's value becomes `"%d / %d" % [floori(ResourceManager.get_madra()), floori(ResourceManager.get_max_madra())]` (proposal **"46 / 100"**); its label stays "Madra", the other entries don't change, and the doc says Madra is the pool over its max.
    - `refresh()`'s rebuild of `%FightRows` moves into `_rebuild_fight_rows() -> void`, which `refresh()` calls (keep Task 1.16's helper if it already has one).
    - `_ready()` connects `ResourceManager.madra_changed` to `_on_madra_changed(_amount: float) -> void`, which calls `_rebuild_fight_rows()` while `is_visible_in_tree()` (the gate `_refresh_if_shown()` uses): a pool change rebuilds only those rows. `stats_changed` already rebuilds them through `_refresh_if_shown()`.

- [ ] **Step 4: Run them and see them pass.** Run the task's test files plus `res://tests/integration/test_character_book.gd,res://tests/integration/test_cycling_view.gd,res://tests/unit/test_book_view_state.gd,res://tests/integration/test_boards_never_trim_text.gd`: PASS. The full suite: PASS. Then open the editor and compare the cabinet, the card and the book with the approved canvas by eye.

- [ ] **Step 5: Commit:** `feat(ui): show the one Madra pool on every readout` / "The cabinet's orb follows the max Madra stat instead of Core Density, the adventure card says what the run carries from the pool, and the Character book's In a fight block shows the pool over its max, live while it is open."

---

### Task 2.5: Phase 2 wrap

**Files:**
- Modify: `docs/superpowers/plans/2026-11-04-stats-rework.md` (Tasks 2.0 to 2.5 ticked, with any deviations noted)

**Interfaces:**
- Consumes: Tasks 2.0 to 2.4.
- Produces: the phase 2 PR.

- [ ] **Step 1: Run the full suite.** Expected: PASS, with no script that runs no tests (confirm a failure in one process, with the command the runner prints, before acting on it).
- [ ] **Step 2: Play it on a save of its own:** `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64.exe" --path . scenes/main/main_game/main_game.tscn -- --save=user://dev/runs/phase2_madra.tres`. Each check holds, or is a bug to fix before the PR:
  1. A new save's cabinet reads "25 / 100", and so does the Goals board's "Awaken Your Core" figure.
  2. In the dev panel's Player tab, Set Madra 150 is refused ("Madra can't pass its max of 100"); Set 100 completes "Awaken Your Core".
  3. Once the adventure unlocks, its card reads "carries 100 Madra". Starting the Shallow Woods, the pellets fly while the cabinet stays at 100, and the vitals plate opens on "100 / 100".
  4. In a fight, Enforce (10 Madra) drops the plate to 90. A Crude Scale, awarded from the dev panel and put on the hotbar in the Inventory book before the run, adds 20 with no "Gained" line in the log.
  5. Retreat: the end card's MADRA LEFT reads the pool over 100, and back in the zone the cabinet and the book's Madra row read the same figures.
- [ ] **Step 3: Review the branch.** `git diff origin/main...HEAD --stat`: under `docs/`, only `docs/superpowers/plans/2026-11-04-stats-rework.md` (living docs wait for the docs PR); no `.import` files; `git diff origin/main...HEAD | Select-String "print\("` finds nothing.
- [ ] **Step 4: Update the plan and commit.** Tick Tasks 2.0 to 2.5 and note under each task anything built differently (CLAUDE.md: the plan reflects final reality). Commit: `docs(stats): mark phase 2 done in the plan` / "Records what phase 2 built, ahead of its PR."
- [ ] **Step 5: Push and open the PR.** `git push -u origin feat/stats-rework-2-madra-pool`, then `gh pr create --base main --title "Stats rework phase 2: one Madra pool" --body-file <a temporary file outside the repo>`. Never merge it: Lionel does. The body: a summary of Tasks 2.1 to 2.4; a test plan (the full suite and the Step 2 checks); and a closing `## Docs to update` section, followed only by the line `🤖 Generated with [Claude Code](https://claude.com/claude-code)`, listing:
  - `docs/infrastructure/RESOURCES.md`: one saved pool sized by the max Madra stat; the over-max rule; no capacity or budget; the threshold is half the max.
  - `docs/README.md`: the Resources row's "two Madra caps"; the Madra unification records are superseded.
  - `docs/cultivation/CULTIVATION.md`: Core Density no longer raises a Madra cap; a new save's max is 100, from Mind; no Madra fields in the stage files. `docs/cultivation/breakthrough-tribulation.md`: Copper's Madra cap goes.
  - `docs/adventuring/ADVENTURING.md`: the start spends nothing; runs spend from and refill the saved pool; the end card's MADRA LEFT line.
  - `docs/zones/ZONES.md`: the card's "carries <pool> Madra"; `confirm_adventure_start(action_data)`. `docs/infrastructure/MAIN_VIEW.md`: ZoneTransition's drain is visual; the cabinet's max follows `stats_changed`.
  - `docs/cycling/CYCLING.md`: "Madra full" against `ResourceManager.get_max_madra()`.
  - `docs/infrastructure/CHARACTER.md`: the player's `VitalsManager` Madra is the pool, which `initialize_current_values()` never touches; the In a fight block's Madra row.
  - `docs/combat/COMBAT.md`: a run's Madra is the saved pool. `docs/infrastructure/EFFECTS.md`: an awarded Madra gain stops at the max; ChangeVitals refills the pool quietly.
  - `docs/infrastructure/PERSISTENCE.md`: the saved Madra is clamped to the max on load; a quit run keeps what it spent. `docs/tooling/DEV_TOOLS.md`: Set Madra refuses a value above the max; Refill vitals keeps the pool.
  - `docs/progression/FOUNDATION_PLAYTHROUGH.md`: the threshold is half of max Madra; Copper's Madra cap lines go. `docs/progression/PATH_PROGRESSION.md`: Madra Reclamation has nothing to refund; Expanded Core would raise max Madra.
  - `docs/testing/TESTING.md`: `test_foundation_tribulation_data.gd` no longer pins a Madra cap. `docs/infrastructure/MADRA_UNIFICATION_DESIGN.md` and `MADRA_UNIFICATION_PLAN.md`: superseded.

  Expected: `gh pr view` shows the PR open against `main`. After Lionel merges it, open the docs PR on a `docs/<topic>` branch cut from the new `main` that writes this list (CLAUDE.md, Documentation).

---

## Phase 3: Cycling (outline)

Outline only. Task 3.0 cuts `feat/stats-rework-3-cycling` from `main` once phase 2's PR merges (as Task 2.0 Step 1 does) and draws a new Design canvas, "Stats rework · Phase 3"; once Lionel approves it and answers every item under "Settled at the mock-up step" (recorded under the task), the outline becomes full tasks like phases 1 and 2's. One PR, opened in Task 3.14. * marks proposals the full tasks confirm. Each task also fixes its entries under "Tests that break". Test files go by name: the unit ones are under Files, the rest in `tests/integration/`.

### Goal

Cycling becomes the Spiritual side's training, as listed under Decided; the Aura Well changes role, and the screens show stat XP, level-ups and capped stats. Nothing pays Core Density until phase 4.

### Decided

- Every technique refills Madra and pays Spirit XP (`CyclingTechniqueData.spirit_xp_per_cycle: float`); Spirit raises the Madra a cycle draws.
- At most one minor stat per technique (`CyclingTechniqueData.minor_stat: int`, an `AttributeType` or -1). Lionel's target: two main techniques, Spirit + Control and Spirit + Mind.
- One mini-game per stat: following the ball trains Spirit, and each minor stat gets its own.
- Following means following the ball: `CyclingRules.is_following(...) -> bool` replaces `CyclingTechnique.advance()`'s distance-only test (`CURSOR_REACH`, 36 px), which pays a cursor parked on the path whenever the ball passes. `wants_pointer()` keeps the reach for presses.
- Auto unlocks per technique after a perfect cycle (`SaveGameData.auto_cycling_technique_ids: Array[String]`, Strings like every technique id); hands-on until then.
- `CyclingTechnique.try_score_zone()` stops calling `CultivationManager.add_core_density_xp()`.
- XP at the cap is lost, and level-ups log themselves (Task 1.3). Task 2.1 points `CyclingTechnique._madra_full()` and `CyclingView._update_status()` at `ResourceManager.get_max_madra()`.

### Settled at the mock-up step

- Which mini-game trains Control and which Mind (timed presses, unbroken following), and how techniques combine.
- Auto's rate: one flat rate for refills and XP (0.2× or 0.4×, Lionel leaning 0.4×), or full-speed refills with reduced XP. Whether Auto pays the minor stat, runs with the board closed (today `CyclingView._on_visibility_changed()` stops the technique and `_on_hidden()` ends the cycle), and whether the toggle chains attended cycles before the unlock.
- The Aura Well's role (keep its capped +1 Spirit level per training level, pay Spirit XP per tick, refill Madra only, or go) and copy (`NowStrip.LEVEL_REWARD_FORMAT`'s "+1 Spirit at Lv n" reads two ways once stats have levels).
- The roster, and whether the Foundational Technique stays (the save's default unlocked and equipped id, and the story route's start).
- The feel notes: the cycle speeding and slowing with how well you stay inside it; Auto not keeping that curve.
- Claude's proposal: Smooth Flow is Spirit + Control and Torrential Flow Spirit + Mind; Spirit XP pays for the share of the cycle followed, not Madra drawn; XP keeps flowing at full Madra; the Foundational Technique trains Spirit only.
- Left open by the code: what a perfect cycle is (every zone PERFECT and the cycle followed through? a zoneless technique only follows, and `CycleResult` has no followed share); when Spirit XP lands (0.08 s steps with pellets, or the cycle's end); where stat pellets, floaters and level-ups land (the cabinet has no stats unless Task 1.0's mock-ups added them); the follow rule's thresholds; the Spirit-to-Madra curve (1.0× at Lv 1, keeping today's 50 / 200 / 250 Madra a cycle); the copy of the status line, zone floaters, cycle line, drawers and Cycling card ("Madra and Core Density XP" today).

### Files

- Data: in `scripts/resource_definitions/`, `cycling/cycling_technique/cycling_technique_data.gd` and `cycling_zone_data.gd`, `character/character_attributes_data.gd`, and `effects/award_attribute_effect_data.gd` (if the Aura Well's award changes); `singletons/persistence_manager/save_game_data.gd`.
- Logic: `scenes/cycling/cycling_technique/cycling_technique.gd`, `cycling_rules.gd` and `cycle_result.gd`; `singletons/cycling_manager/cycling_manager.gd`; `singletons/action_manager/action_manager.gd` (closed-board Auto only).
- Scenes: `scenes/cycling/cycling_view/cycling_view.gd` and `.tscn`; `scenes/cycling/technique_drawer/technique_drawer.gd`; in `scenes/zones/`, `zone_action_button/presenters/cycling_presenter.gd` and `training_presenter.gd`, `zone_panel/now_strip/now_strip.gd`, `cultivator_plate/cultivator_plate.gd` and `.tscn`, `map_markers/map_markers.gd`; `scenes/character/character_view.gd` and `.tscn`.
- Content: in `resources/cycling/cycling_techniques/`, `foundation_cycling_technique/foundation_cycling_technique.tres`, `smooth_flow/smooth_flow.tres`, `smooth_flow/cycling_zone_data/zone_1.tres` to `zone_4.tres`, `torrential_flow/torrential_flow.tres` (inline zone) and `cycling_technique_list.tres` (roster changes only); in `resources/zones/spirit_valley_zone/zone_actions/`, `aura_well_training_action.tres`, `aura_well_madra_trickle_effect.tres` and `aura_well_spirit_award_effect.tres`; `resources/path_progression/pure_madra/nodes/torrential_flow.tres`. New art (stat marks, pellet ramps beyond `LacquerPellet.Ramp`'s MADRA, BRASS, CREAM and TAN) ends in `_ai`.
- Unit tests (`tests/unit/`): `test_cycling_rules.gd`, `test_cycling_technique_data.gd`, `test_cycling_manager.gd`, `test_character_attributes_data.gd`, `test_save_round_trip.gd`, `test_award_attribute_effect_data.gd`.

---

### Task outline

- **Task 3.0: Mock-ups.** Boards: following, at full Madra, with a stat capped, and with Auto unlocked and running; a stat XP hit and a level-up; drawers naming what they train; the Now tray; the Cycling and Aura Well cards; the Character book's Spirit page.
- **Task 3.1: Training data.** Every technique file of the approved roster gets `spirit_xp_per_cycle` and `minor_stat`, and every zone `perfect_xp`, `good_xp` and `ok_xp` rebalanced for the minor stat, all written explicitly (Smooth Flow's `zone_1`, `zone_2` and `zone_4` lean on `ok_xp`'s default 5). A roster change is its own commit. Test: `test_cycling_technique_data.gd` `test_every_technique_trains_spirit_and_at_most_one_spiritual_minor` (`spirit_xp_per_cycle` > 0; `minor_stat` -1, MIND or CONTROL).
- **Task 3.2: Spirit raises Madra per cycle.** `CharacterAttributesData.get_cycling_madra_multiplier() -> float`* (1.0 at Spirit 10); `CyclingTechniqueData.get_madra_per_cycle(madra_multiplier: float = 1.0) -> float`*, and that parameter on `get_madra_per_second()`. `_madra_per_step()`, `NowStrip._update_technique()` and `TechniqueDrawer.detail_text()` pass `CharacterManager.get_total_attributes_data().get_cycling_madra_multiplier()`. Tests: a multiplier table in `test_character_attributes_data.gd`; `test_cycling_technique.gd` `test_spirit_raises_the_madra_a_cycle_draws`.
- **Task 3.3: Real following.** `is_following(...)` takes this and the last frame's cursor and drawn ball, and whether the last frame followed. The ball barely moves at a cycle's ends and snaps to 2 px, and the Foundational path starts, crosses and ends at one point, so a still ball continues a streak but never starts one, except on a cycle's first frame, just after the press. Tests: `test_cycling_rules.gd` `test_is_following` (a table: moving with the ball, parked as it passes, the eased start and end, past the reach); `test_cycling_technique.gd` `test_a_cursor_parked_on_the_path_draws_nothing` on the Foundational path, which passes (322.5, 400) at its start, middle and end.
- **Task 3.4: Spirit XP for following.** `advance()` accrues followed time on its own clock (`_draw_madra_step()` stops at full Madra) and pays `CharacterManager.add_stat_xp(SPIRIT, …)`, `spirit_xp_per_cycle` per fully followed cycle, in 0.08 s steps or at the cycle's end, never per frame (each call emits `stat_xp_changed`, capped or not). `_return_to_ready()` pays what a stopped, switched or hidden cycle had not yet paid, since those emit no `CycleResult`. Signal `stat_xp_paid(stat, from_pos, amount)`* carries the pellets; `CycleResult` gains `followed_ratio`*, `stat_xp`* (per stat) and `capped_stats`* (stats the cap took XP from). Tests in `test_cycling_technique.gd`: `test_following_pays_spirit_xp_with_madra_full`, `test_a_stopped_cycle_keeps_the_spirit_xp_it_followed`, `test_spirit_xp_at_the_cap_marks_the_result`.
- **Task 3.5: Presses stop paying Core Density.** `try_score_zone()` drops `add_core_density_xp()`. If presses are a minor stat's mini-game, it pays `CharacterManager.add_stat_xp(technique_data.minor_stat, xp)` instead (nothing for -1). `capped_stats` replaces `CycleResult.core_full`.
- **Task 3.6: The other minor stat's mini-game.** Its pure rule in `CyclingRules` (an unbroken-following streak, say), wired into `advance()` and paid through `add_stat_xp()` and `stat_xp_paid`. Tests: a table of the rule in `test_cycling_rules.gd`; `test_cycling_technique.gd` `test_a_technique_pays_its_minor_stat_through_its_mini_game`.
- **Task 3.7: The Auto unlock.** `SaveGameData.auto_cycling_technique_ids: Array[String] = []`; `CyclingManager.unlock_auto(technique_id: String)`*, `is_auto_unlocked(technique_id: String) -> bool`* and `signal auto_unlocked(technique: CyclingTechniqueData)`*; `CycleResult.is_perfect() -> bool`*. `CyclingView._on_cycle_completed()` unlocks the equipped technique after a perfect cycle. Tests: `test_cycling_manager.gd` (saved, idempotent, an unknown id refused); `test_cycling_rules.gd` `test_is_perfect` (a table with a zoneless case); `test_cycling_view.gd` `test_a_perfect_cycle_unlocks_auto_for_its_technique`.
- **Task 3.8: Unattended Auto.** With `auto_cycle` on, the technique's Auto unlocked and nobody following, `advance()` pays Madra at `CyclingRules.AUTO_MADRA_RATE`* and XP at `AUTO_XP_RATE`* (equal under one flat rate). `_on_auto_toggled()` and `_show_auto_state()` gate the toggle as approved. Closed-board Auto (cycling as an idle action) pays from an `ActionManager` timer like the Aura Well's `_on_train_timer_finished()`. Tests in `test_cycling_technique.gd`: `test_unattended_auto_pays_at_the_auto_rate`, `test_auto_pays_nothing_unattended_before_the_unlock`.
- **Task 3.9: The speed curve, only if kept.** `advance()` scales how far `_elapsed` moves by how well the cursor follows, and Auto runs at the flat speed. Madra per cycle stays fixed, and `_madra_per_step()`, `_record_rate()` and `_update_session()` stop assuming a fixed `cycle_duration`. Test: `test_cycling_technique.gd` `test_following_speeds_the_cycle_and_auto_does_not`.
- **Task 3.10: The cycle's lines and copy.** `CycleResult.summary()` shows Spirit and minor XP and the capped states (the chest's `%LastCycleLabel` and the log read it). `TechniqueDrawer.detail_text()` names what a technique trains. `CyclingPresenter.REWARD_TEXT` and the `torrential_flow.tres` path node's description ("at the expense of Core Density XP") take the approved copy: phase 3 owns cycling copy, phase 6 only dialogue and quests.
- **Task 3.11: The board shows stat XP.** `CyclingView.status_line()` takes the capped states in place of `zones_pay_xp` (`MADRA_FULL_ZONES` follows). Zone floaters name the stat, and a capped stat gets the capped look and no pellets (today's `core_full` branch of `_on_zone_scored()`). Stat pellets fly to the approved readout, held and released like `hold_madra()` / `release_madra()`, with the approved level-up and capped looks. `CultivatorPlate.hold_core_xp()`, `release_core_xp()`, `rewind_core()` and `_held_xp` go with their only use, `_on_zone_scored()`'s core pellets. Any new board scene joins `BOARD_SCENES` in `test_boards_never_trim_text.gd`. Test: a capped floater in `test_cycling_view.gd`.
- **Task 3.12: The Aura Well's new role.** First write the tick curve, `amount` and `resource_type` explicitly in its three files, then the approved role. `TrainingPresenter._detail_parts()`, `NowStrip._level_reward_text()` and `MapMarkers._on_training_tick_processed()` follow.
- **Task 3.13: The Character book's cycling lines,** in Task 1.16's `CharacterView`. `trainer_names(stat)` adds each technique of `CyclingManager.get_all_techniques()` that trains the stat (all for Spirit, by `minor_stat` for the rest) and still finds the Aura Well. `effect_lines()` gains Spirit's "Madra per cycle": the equipped technique's `get_madra_per_cycle()` at the `now` and `next` blocks' multipliers. `cycles_to_next_level(stat) -> int`* is the XP still needed over the equipped technique's `CyclingTechniqueData.get_xp_per_cycle(stat)`*, rounded up; its line hides while capped or at 0 XP a cycle. Test: `test_character_book.gd` `test_cycles_to_next_level_reads_the_equipped_technique`.
- **Task 3.14: Wrap.** `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_tests.ps1` passes, and a dev run covers a perfect cycle, Auto and a capped stat: `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64.exe" --path . scenes/main/main_game/main_game.tscn -- --preset=path_open --save=user://dev/runs/phase3_cycling.tres`. The PR carries `## Docs to update` (below) and says nothing pays Core Density until phase 4.

### Tests that break

- Task 3.1: `test_cycling_technique.gd` `test_a_scored_zone_shows_in_the_result` (`result.xp == 25`, Smooth Flow `zone_1`'s PERFECT). If an id changes: `test_dev_hooks.gd`, `test_story_route.gd` and `test_save_presets.gd` (beat_2 of `resources/dev/story_route.tres` equips `smooth_flow`), `test_cycling_technique_data.gd` and `test_cycling_manager.gd`, and the rest of `git grep -l -e foundation_technique -e smooth_flow -e torrential_flow -- tests`.
- Task 3.3: `test_cycling_technique.gd` `test_tracking_needs_the_cursor_on_the_ball`, `test_tracking_uses_the_drawn_ball` and `test_the_cursor_tracks_on_the_ring_and_not_past_it` pass under a rule that judges a cycle's first frame and a near-still ball by reach alone; any other rule rewrites them.
- Task 3.5, in `test_cycling_technique.gd`: rewrite `test_scoring_an_active_zone_uses_the_tier_rule` (the minor stat gains the XP, Core Density none); capped-stat versions replace `test_a_zone_scored_at_the_cap_marks_the_result` and `test_the_zone_that_fills_the_core_marks_the_result`.
- Task 3.7: `test_save_round_trip.gd` `test_the_full_save_leaves_no_field_at_its_default`, until `_full_save()` sets `auto_cycling_technique_ids`.
- Task 3.8, if the toggle is gated: `test_cycling_view.gd` `test_auto_toggle_sets_auto_cycle` and `test_a_toggle_that_starts_pressed_is_honoured`.
- Task 3.10: `test_cycling_rules.gd` `test_result_lines`, `test_log_line`, and `test_a_full_core_line_says_so` (now a capped line; `test_xp_per_tier` lives while `xp_for_tier()` and the zone fields keep their names); `test_zone_panel.gd` `test_the_last_cycle_line_shows_the_result` and `test_a_long_last_cycle_line_wraps_and_pushes_the_rest_down`; `test_technique_drawer.gd` `test_detail_text` and `test_setup_shows_icon_name_and_detail`.
- Task 3.11: `test_cycling_view.gd` `test_status_line_copy`, `test_the_status_label_stops_promising_xp_at_a_full_core`, `test_scoring_pops_the_zone_floater_and_pellets`, `test_a_full_core_floater_sends_no_pellets`, `test_the_core_shows_the_xp_as_its_pellets_land`, `test_hiding_the_view_shows_what_its_pellets_carried`, and `test_hiding_the_view_frees_the_pellets_in_flight` if a zone hit sends no pellets; `test_cultivator_plate.gd` deletes `test_held_xp_shows_once_released`, `test_held_xp_holds_back_a_level_up`, `test_rewind_core_within_a_level`, `test_rewind_core_steps_back_through_levels` and `test_rewind_core_stops_at_nothing`.
- Task 3.12, if the well changes: `test_training_flow.gd` `test_training_ticks_fire_effects_and_level_up`; `test_zone_panel.gd` `test_strip_shows_for_aura_well` and `test_strip_follows_training_ticks`; `test_zone_action_cards.gd` `test_training_detail`; `test_map_markers.gd` `test_floater_on_training_tick`; `test_award_attribute_effect_data.gd`; `test_cycling_technique.gd` `test_the_aura_well_rate_survives_closing_cycling` if its "+1.5 / s" changes.
- Task 3.13, as Task 1.16 left them: `test_character_book.gd` `test_trainers_come_from_the_training_actions`, `test_each_stat_names_what_it_does`, `test_a_stat_with_no_known_technique_says_so` (Spirit always has its Madra per cycle line: point it at Strength), `test_now_and_next_come_from_the_blocks_functions` (Spirit's first line is Madra per cycle), and `test_a_stat_nothing_trains_says_so` if the Aura Well goes.

### Risks

- **Saves.** `foundation_technique` is the save's default unlocked and equipped id. → An id the roster drops is moved on every load, as `SaveGameData._apply_zone_id_migrations()` moves zone ids, and the empty Auto list suits old saves. No save version, so phase 5 keeps v3.
- **No Core Density until phase 4,** so beat 3b and the Tribulation can't be reached in play. → Accepted, as `main` may be broken between phases; `DevCommands.reach_core_density()` uses real XP, so the route and presets still build.
- **Tuning.** The Spirit cap should land about when Core Density reaches 100. → Set `spirit_xp_per_cycle` against `CharacterManager.stat_progression` and Foundation's cap of 10; phase 4's retune reads those rates.

### Docs to update

`CYCLING.md`, `CULTIVATION.md`, `RESOURCES.md`, `ZONES.md`, `CHARACTER.md`, `PERSISTENCE.md`, `PATH_PROGRESSION.md`, `FOUNDATION_PLAYTHROUGH.md`, `TESTING.md`; `MAIN_VIEW.md` and `UI_STYLING.md` if a stat readout or new pellet ramps come; `EFFECTS.md` if the Aura Well's award changes.

---

## Phase 4: Core Density (outline)

Outline only, run like phase 3: Task 4.0 cuts `feat/stats-rework-4-core-density` from `main` once phase 3's PR merges and draws "Stats rework · Phase 4". One PR, opened in Task 4.8. The * mark, "Tests that break" and test file names work as in phase 3.

### Goal

Core Density comes from won fights, as listed under Decided, on a curve retuned to about 6–10 Shallow Woods runs. It shows as a ball of stars, and a kill shows what it paid.

### Decided

- A won fight pays Core Density XP by tier: `AdventureActionData.core_density_xp_regular`, `core_density_xp_elite` and `core_density_xp_boss`.
- The tier is the tile's `AdventureEncounter.encounter_type` (COMBAT_REGULAR 0, COMBAT_BOSS 2, COMBAT_ELITE 3), and `CombatChoice.is_boss` also marks the boss. Not `CombatantData` (the Shallow Woods boss, `manifested_spirit_encounter.tres`, reuses the regular `amorphous_spirit.tres`), and not gold (the Coalescing Spirit, an elite, drops none).
- Paid at the kill, in `AdventureTilemap.handle_combat_result()`'s once-per-fight `if _current_combat_choice:` block, before the boss branch's `ActionManager.stop_action(true)`; kept if the run is lost (Claude's call), since `CultivationManager.add_core_density_xp()` writes the live save at once and no lost, timed-out or retreated run undoes it.
- Core Density keeps its other jobs: 0–100 per stage, a path point every 10 levels (`PATH_POINT_LEVEL_INTERVAL`, `_pay_milestone()`), the breakthrough at 100, and the 5-level penalty for a failed Tribulation.
- Tuning target (Claude's call): 0 to 100 in Foundation takes about 6–10 Shallow Woods runs, with no new maps. A full clear of `resources/adventure/data/shallow_woods.tres` is 7 regular, 4 elite and 1 boss fight in a 300 s run.
- The breakthrough gate and its requirement lines are Task 1.13's (`TribulationActionData.can_attempt()`, `get_missing_requirements()`); phase 4 changes only how Core Density looks there.
- The path tree doesn't change; a lost fight ends the run as today, keeping loot already won.
- The look: a main ball with 9 or 10 stars, each filled star shown graphically (Lionel).

### Settled at the mock-up step

- 9 or 10 stars; what a star is worth; whether stars line up with the path-point milestones (10 stars of 10 levels match `PATH_POINT_LEVEL_INTERVAL`).
- Where the ball and stars show, and whether "Level N" and "xp / need XP" survive beside them: the cabinet (`%CoreOrb`, `%XpBeads`, `%LevelLabel`, `%XpLabel`), the Goals board's Breakthrough row (`%MilestoneRod`, `%MilestoneFigureLabel`), the Tribulation card (`%CoreRod`, `%CoreFigure`), the adventure end card.
- How a kill shows what it paid: the tile summary (`AdventureTilemap.summary_for()`, "Won · 15 gold" today), a floater in the fight, the chest's Run ledger (`ExpeditionPage.set_run_stats()`), the end card, or the Goals board (under the vitals cabinet during a run, already following `core_density_level_updated`).
- Left open by the code: whether COMBAT_AMBUSH pays the regular amount (no content uses it); `CORE_FULL_LOG`'s timing, since Task 1.13 set its wording and from now on it logs mid-run, at the kill that fills the core.

### Files

- Data: in `scripts/resource_definitions/`, `zones/zone_action_data/adventure_action_data/adventure_action_data.gd`, `cycling/advancement_stage/advancement_stage.gd` (also a `##` doc on `get_xp_for_level()`), `adventure/adventure_result_data.gd` (if the end card shows the run's total), and `zones/zone_action_data/tribulation_action_data/tribulation_action_data.gd` (if Core Density's line is reworded).
- Logic: `scenes/adventure/adventure_tilemap/adventure_tilemap.gd`; `singletons/cultivation_manager/cultivation_manager.gd`; `scenes/adventure/adventure_view/adventure_view.gd`.
- Scenes: `scenes/zones/cultivator_plate/cultivator_plate.gd` and `.tscn`; `scenes/ui/goals_panel/goals_panel.gd` and `.tscn`; `scenes/zones/zone_action_button/presenters/tribulation_presenter.gd` and `.tscn`; as the mock-ups show, `scenes/adventure/adventure_end_card/adventure_end_card.gd` and `.tscn` and `scenes/adventure/adventure_chest/expedition_page/expedition_page.gd`.
- Content, every value written explicitly: `resources/zones/spirit_valley_zone/zone_actions/spirit_valley_adventure_action.tres` (the three amounts); in `resources/cycling/advancement_stages/`, `foundation_advancement_stage/foundation_advancement_stage.tres` (Task 4.3's curve, whose base cost and cap are omitted today, and the star count) and `copper_advancement_stage/copper_advancement_stage.tres` (the star count; its curve stays, as Copper has no content). Art: `assets/ui/lacquer/lacquer_core_stars_strip_ai.png`*, plus any smaller strip the card and the board need, all `_ai`.
- Unit tests (`tests/unit/`): `test_fight_rules.gd`, `test_cultivation_manager.gd`, `test_cultivation_getters.gd`.

---

### Task outline

- **Task 4.0: Mock-ups.** Boards: the star ball on the cabinet; the Goals board's Breakthrough row and the Tribulation card empty, part-way and full; a kill paying Core Density in the fight, on the tile, in the ledger and on the end card.
- **Task 4.1: The kill reward rule.** The three amounts on `AdventureActionData`, written explicitly in `spirit_valley_adventure_action.tres`. `get_core_density_xp_for(encounter_type: AdventureEncounter.EncounterType, is_boss: bool) -> float`* pays the boss amount for `is_boss` or COMBAT_BOSS, the elite one for COMBAT_ELITE, the regular one for COMBAT_REGULAR (and COMBAT_AMBUSH if approved), else 0. `experience_multiplier` stays unread. Test: `test_fight_rules.gd` `test_core_density_reward_by_encounter_type` (a table with REST_SITE and NONE).
- **Task 4.2: Pay at the kill.** Where Decided says, call `CultivationManager.add_core_density_xp(current_adventure_action_data.get_core_density_xp_for(get_encounter_at(get_current_tile()).encounter_type, _current_combat_choice.is_boss))`, skipped when `current_adventure_action_data` is null; a tile with no encounter counts as NONE. The run's total, `get_core_density_xp_earned() -> float`*, resets in `start_adventure_on_map()`. Tests walk to FIGHT, since a fight picked on START pays nothing: `test_adventure_tilemap_events.gd` `test_a_won_fight_pays_its_core_density_once` (a win reported twice pays once) and `test_core_density_is_kept_when_a_later_fight_is_lost`; `test_adventure_end_flow.gd` `test_the_boss_pays_its_core_density_before_the_run_ends`.
- **Task 4.3: Retune the curve.** Write `core_density_base_xp_cost`, `core_xp_scaling_factor` and `max_core_density_level = 100` explicitly in `foundation_advancement_stage.tres`, so a full core takes 6–10 full clears at Task 4.1's amounts, about when phase 3's Spirit XP rates reach the Spirit cap. The PR description records both estimates, since no test pins shipped tuning ("What to test" in `docs/testing/TESTING.md`); `test_cultivation_manager.gd` `test_xp_for_level_follows_base_times_scaling` still covers the formula.
- **Task 4.4: The star rule.** `AdvancementStageResource.core_density_star_count: int`*, written explicitly in both stage files, and `get_stars_lit(level: int) -> int`* (each star an equal share of `max_core_density_level`, unless approved otherwise). `CultivationManager.get_core_density_stars_lit() -> int`* and `get_core_density_star_count() -> int`* read the current stage. Test: `test_cultivation_manager.gd` `test_stars_lit_follow_the_level`, a table on `_make_stage()` stages: empty, one level short of a star, a star, the cap, and a stage of 40 levels.
- **Task 4.5: The cabinet's star ball.** `CultivatorPlate._update_core_density()` shows the approved ball and stars on a `LacquerStripRect` over the new strip, in the room of `%CoreOrb` and `%XpBeads`; the board art `lacquer_cult_ai.png` stays. Its rewritten tests check that the strip's frame follows `get_core_density_stars_lit()` and the stage's cap, and read any XP need from `CultivationManager.get_xp_for_next_level()`.
- **Task 4.6: Stars on the Goals board and the Tribulation card.** `GoalsPanel._update_milestone()` and `TribulationPresenter._update_need()` show the Core Density requirement as stars beside Task 1.13's stat lines. If the mock-ups reword Core Density's line, `TribulationActionData.get_missing_requirements()` and `on_activation_rejected()` change with it. The rewritten card tests assert the stars lit.
- **Task 4.7: A kill shows what it paid,** as approved: `summary_for()` gains the amount; `ExpeditionPage.set_run_stats()` gains the run's total, passed by `AdventureView._on_run_stats_changed()`; `AdventureResultData.core_density_xp_earned: float`*, which `AdventureView._build_result_data()` fills from Task 4.2's total and `AdventureEndCard._populate()` shows; or a floater in the fight. Tests: `test_adventure_end_flow.gd` `test_the_result_carries_the_runs_core_density`, through `_build_result_data()`; if the end card shows the total, a case in Task 2.3's `test_adventure_end_card.gd` reads its line.
- **Task 4.8: Wrap.** `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_tests.ps1` passes, and one Shallow Woods dev run checks the stars and the kill display: `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64.exe" --path . scenes/main/main_game/main_game.tscn -- --preset=adventure_open --save=user://dev/runs/phase4_core_density.tres`. The PR carries `## Docs to update` (below), Task 4.3's arithmetic and the story-order note.

### Tests that break

- Task 4.3: `test_cultivation_getters.gd` `test_xp_for_level_follows_the_stages_curve` (Foundation's 10 × 1.02^(L−1)) goes, with its section and header line.
- Task 4.5: `test_cultivator_plate.gd` `test_beads_follow_xp` ("5 / 10 XP", from the level-1 cost of 10), `test_level_and_stage_text`, `test_core_fill_follows_a_level_up`, `test_core_fill_reads_the_stages_cap` and `test_losing_levels_ends_core_full` ("Level N", the orb's fill, the beads, "Core full").
- Task 4.6, as Task 1.13 left them: in `test_goals_panel.gd` (on the "N / cap" figure, the rod's steps or "Raise Core Density to N"): `test_milestone_text`, `test_milestone_at_the_cap_asks_for_the_tribulation`, `test_milestone_follows_level_up`, `test_milestone_follows_the_stage_change`, `test_the_figure_returns_with_a_new_save`, `test_milestone_reads_the_stages_cap`, `test_npc_4_hands_the_board_to_the_breakthrough`, `test_milestone_lists_every_missing_requirement` and `test_a_full_core_waits_for_the_main_stats`; in `test_tribulation_card.gd`, `test_below_the_cap_shows_the_core_figure` and `test_card_follows_a_lost_level` ("Core 95 / 100", the rod) and `test_filling_the_core_readies_the_card` (its "Core 99 / 100" precondition). If Core Density's requirement line is reworded, also `test_rejected_click_below_the_cap_logs_why`, `test_rejected_click_names_every_missing_requirement`, and `test_tribulation_flow.gd` `test_the_trial_needs_a_full_core_and_both_main_stats_at_the_cap`.
- Task 4.7, per the mock-ups: `test_adventure_tilemap_events.gd` `test_won_fight_summary` and `test_summary_for`, if the tile shows it; `test_expedition_page.gd` `test_run_ledger_values`, `test_ledger_keeps_the_latest_six`, `test_a_new_run_clears_the_ledger` and `test_the_ledger_does_not_touch_the_tile`, if `set_run_stats()` gains an argument.
- Unaffected (checked): `test_cultivation_manager.gd` (its own stages); `test_play_stats_recording.gd` (fights picked on START, a NoOpEncounter of type NONE, pay nothing; it asserts no Core Density); `test_story_route.gd`, `test_save_presets.gd`, `test_dev_commands.gd` and `test_beat_3b_merchant_unlock.gd` (`DevCommands.reach_core_density()` or set levels work on any curve).

### Risks

- **Repeated wins, and the boss's early end.** `VitalsManager`'s Health setter emits on every set, so `AdventureCombat._on_enemy_health_changed()` reports a win again on each hit at 0 Health (`AdventureView._on_stop_combat()` and the gold line count it again), and the boss's `stop_action(true)` ends the run and builds the end card at once. → Pay once, in the once-per-fight block, before that call.
- **Mid-run side effects.** `core_density_level_updated` now fires during runs: the Goals board refreshes, `UnlockManager` latches `q_reach_cd_10` (NPC 4) and `core_density_full` (the Tribulation card), path points land in the dock, and `CORE_FULL_LOG` logs. → All already work away from the zone view; the log's timing is a Task 4.0 question.
- **Story order.** Kills pay from the first run, so `q_reach_cd_10` (latched at CD ≥ 10) opens NPC 4 before NPC 3, and the CD-10 path point comes before `q_first_steps`' free one. → Accepted until phase 6 reorders the beats; the PR description says so.
- **Art and room.** The cabinet is a fixed board texture with absolutely placed children, and the Tribulation card is a 72 px drawer. → The stars fit the orb-and-beads room and the card's footer; changed board art is a new `_ai` file; a taller card uses `ZoneActionButton.set_tall()`.

### Docs to update

`CULTIVATION.md`, `ADVENTURING.md`, `breakthrough-tribulation.md`, `MAIN_VIEW.md`, `ZONES.md`, `PATH_PROGRESSION.md`, `FOUNDATION_PLAYTHROUGH.md`, `TESTING.md`; `UI_STYLING.md` if the star strip becomes a kit piece.

---

## Phase 5: Body refining and Health (outline)

Branch `feat/stats-rework-5-body-refining`, cut from `main` after phase 4 merges; one PR. Task 5.0's approved mock-ups turn this outline into full tasks. Names outside the shared contract are proposals.

### Goal

One saved Health pool for home and runs, refilled at home only by body refining: drills on a board opened from a zone action. Each drill pays Strength XP plus at most one other Physical stat, and each rep restores Health, more with Strength. Auto unlocks after a perfect set; adventure manuals teach drills. Strength reaches the cap, so the breakthrough opens in play.

### Decided

- **Health:** one saved pool in `ResourceManager` (`SaveGameData.health`, a version step). A run leaves it as it is; at home only body refining refills it; in runs, rest tiles still heal it.
- **Fix first (Task 5.1):** `AdventureCombat.initialize_combat()` connects `_on_player_health_changed` to `PlayerManager.vitals_manager.health_changed` and never disconnects it, so after one fight, Health reaching 0 anywhere (likelier once it persists) reports a lost fight.
- **Health façade, as Task 2.2's for Madra:** the player's `VitalsManager` reads `current_health` and `max_health` from `ResourceManager.get_health()` and `get_max_health()`, a `current_health` write calls `set_health()`, `_apply_health_change()` calls `add_health(amount, true)`, and `health_changed` is re-emitted once, from `ResourceManager.health_changed`. `ChangeVitalsEffectData.process()`, which calls `apply_vitals_change()`, thus heals the saved pool unchanged (a test pins it). Enemies keep in-memory Health.
- **Task 2.1's over-max rule:** `ResourceManager._on_stats_changed()` clamps Health behind its guard (skip while `CharacterManager.live_save_data != live_save_data`, as `CharacterManager` re-binds and emits first on a save reset), and so does `_update_resources()`.
- **Body refining:** `ZoneActionData.ActionType.BODY_REFINING = 8` (after `TRIBULATION = 7`, pinned), `BodyRefiningActionData`, `BodyRefiningManager` (an autoload modelled on `CyclingManager`), `DrillData`, `DrillRules`. A drill refills Health and pays Strength XP plus at most one minor (`DrillData.minor_stat: int`: `BODY`, `AGILITY` or -1, like Task 3.1's `CyclingTechniqueData.minor_stat`); Strength raises Health per rep. XP goes through `CharacterManager.add_stat_xp()` (Task 1.3): lost at the cap, while Health still refills.
- Auto unlocks per drill after a perfect set (`SaveGameData.auto_drill_ids: Array[String]`, like Task 3.7's list; drill ids are Strings). Manuals drop on adventures. The gate stays Task 1.13's `TribulationActionData.can_attempt()`.

**(Claude's call)**, open to the mock-ups: one starting drill per save (as `foundation_technique` is); the action unlocks on `q_fill_core_completed` with the adventure, so a hurt player can always refill; Stamina stays per run; the card warns below half Health; XP flows at full Health; run starts refill Health through the façade until Task 5.17, keeping each commit playable.

### Settled at the mock-up step

- The design's list: the drill roster and each drill's minor stat, how manuals drop and teach (pickup or use), combinations, Auto's rate and whether it runs beside Auto cycling (one wait between runs or two), a lost run's cost, and whether a consumable heals Health (none does today).
- Each drill's input (hold and release in the band, hold steady, click to catch, press on the beat), a set's reps, and how PERFECT, GOOD and OK are judged.
- Drawers in the chest or a picker on the board; a running set in the Now strip or not.
- The cabinet's Health readout (orb or row), the book's Health line, the Goals board's new place.
- Low Health: a warning, or also a refusal in `ActionManager.select_action()` beside the Madra one (below half, or at 0).
- The Aura Well rest tile (`aura_well_encounter.tres`, `body_hp_multiplier = 5.0`): kept or retuned.
- Drill XP pellets (after Task 3.11's), result and log lines, a `PlayStatsData` set count, the action's name and card text.

### Files

Create:
- `scripts/resource_definitions/zones/zone_action_data/body_refining_action_data/body_refining_action_data.gd`: `BodyRefiningActionData extends ZoneActionData`, whose `_init()` sets `action_type = ActionType.BODY_REFINING`.
- `scripts/resource_definitions/body_refining/drill/`: `drill_data.gd` (`DrillData`: `id: String`, `drill_name: String`, `icon: Texture2D`, `minor_stat: int`, `strength_xp_per_rep: float`, `minor_xp_per_rep: float`, `health_per_rep: float` at Strength Lv 1, the input's fields) and `drill_list.gd` (`DrillList`: `drills: Array[DrillData]`); `resources/body_refining/drills/drill_list.tres` and `resources/body_refining/drills/<drill_id>/<drill_id>.tres` per drill, every value written out.
- `singletons/body_refining_manager/body_refining_manager.gd`, the autoload `BodyRefiningManager` right after `CyclingManager` in `project.godot`.
- `scenes/body_refining/drill/`: `drill_rules.gd` (statics), `drill_set_result.gd` (a RefCounted), `drill_run.gd` (judges a set at exact times, like `scripts/tribulation/tribulation_run.gd`), `drill_play.gd` and `.tscn` (an injectable `clock_usec: Callable`, like `TribulationView`'s).
- `scenes/body_refining/body_refining_view/body_refining_view.gd` and `.tscn` (after `CyclingView`), `scenes/ui/main_view/states/body_refining_view_state.gd`, `scenes/zones/zone_action_button/presenters/body_refining_presenter.gd` and `.tscn`, `resources/zones/spirit_valley_zone/zone_actions/body_refining_action.tres`.
- If approved: `scenes/body_refining/drill_drawer/drill_drawer.gd` and `.tscn`, `scenes/zones/zone_panel/drill_drawer_list/drill_drawer_list.gd` and `.tscn`; manual items such as `resources/items/quest_items/<manual_id>.tres`. Art only as `_ai` files; the cabinet can reuse `assets/ui/lacquer/lacquer_orb_health_ai.png`.
- `tests/unit/`: `test_body_refining_action_data.gd`, `test_drill_data.gd`, `test_drill_rules.gd`, `test_body_refining_manager.gd`, `test_body_refining_view_state.gd`; `tests/integration/`: `test_drill_play.gd`, `test_body_refining_view.gd`, `test_drill_manuals.gd`.

Modify:
- `singletons/`: `persistence_manager/save_game_data.gd`, `resource_manager/resource_manager.gd`, `player_manager/player_manager.gd` (`reset_vitals()`'s doc: Health is the save's), `action_manager/action_manager.gd`, `zone_manager/zone_manager.gd`, `dev_manager/dev_commands.gd`, `dev_manager/dev_manager.gd`.
- `scenes/combat/combatant/vitals_manager/vitals_manager.gd`, `scenes/combat/adventure_combat/adventure_combat.gd`, `scenes/adventure/adventure_view/adventure_view.gd` (`_initialize_combat_resources()`; `stop_adventure()` if runs may start at 0 Health).
- `scenes/zones/cultivator_plate/cultivator_plate.gd` and `.tscn`, `scenes/character/character_view.gd`, `scenes/ui/main_view/states/zone_view_state.gd` (`GOALS_POSITION`), `scenes/ui/dev_panel/tabs/player_tab.gd` and `.tscn`.
- `scenes/zones/zone_action_button/`: `zone_action_button.gd`, `presenters/adventure_presenter.gd` and `.tscn`. `scripts/resource_definitions/zones/zone_action_data/zone_action_data.gd`, `scripts/utils/zone_action_groups.gd`, `resources/zones/spirit_valley_zone/spirit_valley_zone.tres`.
- `scenes/main/main_game/main_game.tscn` (`BodyRefiningView` hidden at z_index 3, after `TribulationView` and before `BoardTransition`; `BodyRefiningViewState` under `MainViewStateMachine`; the GoalsPanel) and `scenes/ui/main_view/main_view.gd` (`@onready var body_refining_view` and `body_refining_view_state`, their `scene_root` line in `_ready()`, a cabinet hand-over like `_hand_cabinet_to_cycling_view()`).
- The encounters under `resources/adventure/encounters/shallow_woods/` that drop manuals, each through a `LootTableEntry`, as `combat_encounters/elite/ravenous_dreadbeast_encounter.tres` drops its necklace.
- If the mock-ups need them: a drills chest (`scenes/zones/zone_panel/zone_panel.gd`, `scenes/ui/main_view/board_transition/board_transition.gd`, `board_transition_spec.gd`); the Now strip (`scenes/zones/zone_panel/now_strip/now_strip.gd`); an appended manual item type (`scripts/resource_definitions/items/item_definition_data.gd`, `singletons/inventory_manager/inventory_manager.gd`); a set count (`singletons/persistence_manager/play_stats_data.gd`: `sets_finished`, `count_set_finished()`); a `drill_press` input action (`project.godot`); `docs/inventory/ITEMS.md`'s Quest items section, which names the map as the only quest item (code reads this doc, so it changes in the PR).

---

### Task outline

Test files are named without their folder.

- **Task 5.0: Mock-ups.** A new Design canvas, "Body refining and Health" (the old Body Refining canvas has the old stats), answering the list above, with a manual on the end card and in the inventory and the Physical stat pages. Lionel approves it before UI tasks 5.4, 5.5, 5.10–5.12, 5.14–5.16, 5.18 and 5.20.
- **Task 5.1: The fight lets go of Health.** `AdventureCombat.stop()` disconnects `_on_player_health_changed`. `test_adventure_combat_victory_event.gd` `test_health_at_zero_after_the_fight_reports_nothing`: win, `stop()`, `LETHAL_DAMAGE` on the player; `_combat_ends.size()` stays 1.
- **Task 5.2: Saved Health.** `SaveGameData.health`, defaulting to the const `HEALTH_UNSET = -1.0`; `CURRENT_VERSION = 3` (or the next free number), with `_migrate_to_v3()` writing the sentinel explicitly. `ResourceManager`: `signal health_changed(new_amount: float)` and twins of the Madra functions as Task 2.1 leaves them, held to [0, max]: `get_health()`, `get_max_health()` (the `StatModifierData.Stat.MAX_HEALTH` stat), `add_health(amount, quiet = false) -> float`, `spend_health(amount) -> bool`, `set_health(amount)`, plus `is_health_low()`, below `LOW_HEALTH_RATIO := 0.5` of the max. `_update_resources()` fills a negative Health to the max, clamps one above it, and emits; `_on_stats_changed()` clamps behind its guard. `test_resource_manager.gd`: `test_add_health_keeps_the_pool_between_zero_and_max`, `test_spend_health_refuses_more_than_the_pool`, `test_an_unset_health_binds_full`, `test_health_above_a_lowered_max_is_clamped`, `test_a_save_swap_leaves_the_old_saves_health_alone`; `test_save_migration.gd`: `test_v3_leaves_health_for_the_bind_to_fill`.
- **Task 5.3: The player's Health is the pool.** The façade; until Task 5.17, `initialize_current_values()` fills Health through it. `test_player_vitals_manager.gd`: `test_player_health_reads_and_writes_the_saved_pool`, `test_each_health_change_reaches_the_vitals_once`, `test_an_enemys_health_is_its_own`; `test_change_vitals_effect_data.gd`: `test_process_heals_the_saved_pool`.
- **Task 5.4: The cabinet and the book show it.** `CultivatorPlate`'s readout, with `get_health_orb_global_position()`, `hold_health()` and `release_health()` as for Madra; the Goals board moves if the cabinet grows; `CharacterView.fight_lines()`'s Health reads "current / max", rebuilt on `ResourceManager.health_changed` (Task 2.4's Madra pattern). `test_cultivator_plate.gd`: `test_shows_health_over_max`, `test_health_follows_its_signal`, `test_held_health_shows_once_released`; `test_character_book.gd`: `test_the_health_line_shows_the_saved_pool`, reading `fight_lines()`.
- **Task 5.5: The low-Health warning.** `AdventurePresenter` warns while `is_health_low()`, following `health_changed`; an approved refusal joins the Madra one in `select_action()`. `test_resource_manager.gd`: `test_health_is_low_below_half` (a table); `test_zone_action_cards.gd`: `test_adventure_card_warns_below_half_health`, `test_the_warning_clears_when_health_refills`; with a refusal, `test_adventure_flow.gd`: `test_low_health_blocks_adventure`.
- **Task 5.6: The BODY_REFINING type.** The enum value, `BodyRefiningActionData`, cycling's ActionManager signals and handlers renamed for it (`start_body_refining(action_data: BodyRefiningActionData)`, `stop_body_refining()`, `_execute_body_refining_action()`, `_stop_body_refining_action(successful: bool)`), with a branch each in `_execute_action()` and `_stop_executing_current_action()`; `ZoneActionGroups.group_of()` CULTIVATE and `mode_tag()` "ACTIVE". `test_body_refining_action_data.gd`: `test_body_refining_type_is_eight`, `test_selecting_starts_body_refining_and_stopping_stops_it`, `test_stopping_runs_the_completion_effects`; rows in `test_zone_action_groups.gd`'s `test_group_of_each_type` and `test_mode_tags`.
- **Task 5.7: Drill data and the approved drills.** `test_drill_data.gd`: `test_each_drill_trains_at_most_one_physical_minor` (over `drill_list.tres`: `strength_xp_per_rep` > 0; `minor_stat` -1, BODY or AGILITY), `test_drill_ids_are_unique`.
- **Task 5.8: `DrillRules` and `DrillSetResult`.** `enum Tier { OK, GOOD, PERFECT }`, the approved judge, `xp_for_rep(base_xp, tier)`, `health_for_rep(drill, tier, strength)` (in the shape Task 3.2 gives Spirit's Madra; Claude's proposal: `health_per_rep` × the tier's factor × `strength / CharacterAttributesData.STAT_BASELINE`) and `perfect_set_xp(drill, stat)`; `DrillSetResult.is_perfect()`, `summary()`, `log_line()`. Table tests for each in `test_drill_rules.gd`.
- **Task 5.9: `BodyRefiningManager`.** The catalog; saved fields named as cycling's (`unlocked_drill_ids`, default the starting drill; `equipped_drill_id`; `seen_drill_ids`; `seen_drills_initialized`) plus `auto_drill_ids`; CyclingManager's technique API with drill for technique (`unlock_drill()`, `get_equipped_drill()`, …), `unlock_auto()`, `is_auto_unlocked()`; signals `drill_unlocked`, `equipped_drill_changed` and `auto_unlocked`, each with the `DrillData`; `pay_rep(drill, tier, result: DrillSetResult)`, paying XP through `add_stat_xp()` and Health through `ResourceManager.add_health(..., true)` at `CharacterManager.get_stat(StatModifierData.Stat.STRENGTH)`. `ZoneManager._on_drill_unlocked()` marks the card NEW, as `_on_technique_unlocked()` does. `test_body_refining_manager.gd`: `test_a_rep_pays_strength_the_minor_and_health`, `test_a_capped_strength_still_refills_health`, and `test_cycling_manager.gd`'s tests from `test_default_save_has_foundation_unlocked` to `test_save_reset_runs_the_first_pass_on_the_new_save`, drill for technique; `test_seen_actions.gd`: `test_drill_unlock_lights_the_body_refining_card`.
- **Task 5.10: Drill play, one task per approved input.** `DrillRun`, and `DrillPlay` (`start_set() -> bool`, `stop_set()`, `handle_press_event(event) -> bool`, signals `rep_scored(tier)` and `set_completed(result: DrillSetResult)`), which pays each scored rep through `pay_rep()`. `test_drill_play.gd`: `test_a_set_scores_and_pays_each_rep`, at exact `clock_usec` times.
- **Task 5.11: The board and its state.** `BodyRefiningView`; `BodyRefiningViewState` opens and closes through `BoardTransition` like `CyclingViewState` and takes input like `TribulationViewState` (`ui_cancel` stops the action; presses go to `DrillPlay.handle_press_event()`); the MainView and main_game.tscn wiring. `test_body_refining_view_state.gd`: `test_tribulation_view_state.gd`'s push, close, reversal, press and `test_main_game_holds_the_board_and_its_state` tests, plus `test_escape_stops_the_action`; `test_body_refining_view.gd`: the status line, Health pellets landing in the cabinet, the close button stopping the action. `BOARD_SCENES` in `test_boards_never_trim_text.gd` gains the board; `test_cycling_mode.gd::test_main_game_names_the_zone_furniture_for_main_view` asserts `%BoardTransition` after `%BodyRefiningView`.
- **Task 5.12: The card.** `BodyRefiningPresenter` in `PRESENTER_SCENES`. `test_zone_action_cards.gd`: `test_body_refining_detail`.
- **Task 5.13: In Spirit Valley.** `body_refining_action.tres` (`action_type = 8`), unlocked by `q_fill_core_completed`, in `all_actions`; `test_story_route.gd::test_the_route_covers_the_story` stays green (beat_1 reaches `q_fill_core_completed`).
- **Task 5.14: Drill drawers, only if approved.** A drills mode beside `ZonePanel.set_techniques_mode()`, whose API stays. Drills-mode tests in `test_zone_panel.gd` and `test_board_transition.gd`. The techniques-mode tests stay green: `test_board_transition.gd`'s `test_the_chest_swaps_at_the_swap_point_both_ways`, `test_a_row_freed_mid_slide_is_skipped` and `test_a_list_rebuilt_mid_slide_ends_at_rest`, `test_cycling_mode.gd`'s `is_techniques_mode()` assertions, and `test_zone_panel.gd`'s.
- **Task 5.15: A running set in the Now strip, only if approved.** A set session on `BodyRefiningManager`, like `CyclingManager.start_cycle_session()`. `test_zone_panel.gd`: `test_strip_shows_a_running_set`.
- **Task 5.16: Auto after a perfect set.** `BodyRefiningView` unlocks the equipped drill's Auto when `set_completed` carries `is_perfect()`; Auto then plays reps at the approved rate, like Task 3.8's. `test_body_refining_manager.gd`: `test_auto_unlock_is_saved_per_drill`; `test_body_refining_view.gd`: `test_auto_stays_locked_until_a_perfect_set`, `test_a_perfect_set_unlocks_auto`; `test_drill_play.gd`: `test_auto_plays_reps_at_the_auto_rate`.
- **Task 5.17: Health comes home.** `initialize_current_values()` stops filling the player's Health; `DevCommands.refill_vitals()` adds `ResourceManager.set_health(ResourceManager.get_max_health())`; if runs may start at 0 Health, `AdventureView.stop_adventure()` classifies a loss by a flag the lost fight sets. `test_adventure_view_frame.gd`: `test_health_comes_home_from_a_run`; `test_dev_adventure_commands.gd::test_refill_vitals_keeps_the_run_madra` also checks Health refills.
- **Task 5.18: Manuals.** A manual teaches its drill through `BodyRefiningManager.unlock_drill()`, on pickup or on use as approved. `test_drill_manuals.gd`: `test_a_looted_manual_teaches_its_drill`, `test_a_second_copy_teaches_nothing`, `test_every_manual_drops_in_the_shallow_woods`; `test_inventory_manager.gd`, if a new item type is added.
- **Task 5.19: Combinations, as approved.** `test_body_refining_manager.gd`: `test_a_combined_rep_pays_each_minor_once`.
- **Task 5.20: The Physical pages name their drills.** `CharacterView.trainer_names()` adds every catalog drill to Strength, and the drills whose `minor_stat` matches to Body and Agility; each page gives about how many perfect sets of the equipped drill its next level takes (`perfect_set_xp()`). `test_character_book.gd`: `test_a_physical_stat_names_the_drills_that_train_it`, `test_a_physical_stat_counts_the_sets_to_its_next_level`.
- **Task 5.21: Drills open the trial (test only).** `test_tribulation_flow.gd` `test_strength_trained_by_drills_opens_the_trial`: `DevCommands.reach_core_density(100)` and `DevCommands.set_stat_level(&"spirit", CharacterManager.get_stat_level_cap())`, then `BodyRefiningManager.pay_rep()` until `CharacterManager.is_stat_capped(STRENGTH)`; `select_action()` then starts the trial.
- **Task 5.22: Dev tools.** `DevCommands.set_health(value)` (refuses below 0 or past the max), `unlock_drill(drill_id)`, `equip_drill(drill_id)` and `unlock_all_drills()`, each returning "" or the refusal; the player tab's Health and drill controls; `_tear_down()` ends Task 5.15's set session, if built. `test_dev_commands.gd`: `test_set_health_sets_exactly_and_refuses_past_the_max`, `test_unlock_and_equip_drill`, `test_drill_commands_refuse_an_unknown_id_and_equip_refuses_a_locked_one`; `test_dev_panel.gd`: `test_player_tab_sets_health`; `test_dev_manager_sessions.gd::test_teardown_clears_the_runtime_state`, with a set session.
- **Task 5.23: Wrap.** `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_tests.ps1` passes. The PR has a `## Docs to update` list and says the breakthrough can be reached in play again, so an itch build is possible; Lionel publishes by hand.

### Tests that break

Updated in the task named:
- 5.2, 5.9: `test_save_round_trip.gd::test_the_full_save_leaves_no_field_at_its_default`: `_full_save()` sets `health`, the drill fields, and `stats.sets_finished` if sets are counted.
- 5.3: `test_dev_hooks.gd::test_reset_vitals_gives_a_fresh_vitals_manager` expects the save's Health, not 0, and `ResourceManager.health_changed` keeping its connection count (Task 2.2's Madra check). `test_vitals_plate.gd`'s `test_shows_the_runs_vitals`, `test_orbs_fill_to_the_fraction`, `test_health_rounds_up_and_the_rest_round_down` and `test_follows_the_vitals_signals` write a max Health of 160, which the façade ignores: a FLAT `Stat.MAX_HEALTH` bonus beside Task 2.2's MAX_MADRA one sets it, then `ResourceManager.set_health()`; the figures stay.
- 5.4: `test_main_game_layout.gd::test_the_furniture_keeps_its_places_through_an_editor_save` pins the GoalsPanel at (24, 276), if the cabinet grows.
- 5.4: `test_character_book.gd::test_in_a_fight_lists_every_total`: Health's value becomes "current / max".
- 5.6: `test_idle_action_resolution.gd::test_is_idle_action_is_foraging_and_training_only` classifies every `ActionType`: add `BODY_REFINING: false`.
- 5.13: `test_zone_panel.gd::test_count_label`: "10 here" becomes "11 here".
- 5.17: `test_player_vitals_manager.gd::test_new_max_health_fills_the_next_run` becomes `test_a_run_starts_at_the_saved_health`; `test_adventure_view_frame.gd::test_gear_equipped_before_the_run_raises_the_cabinets_max_health` drops "and the run starts at that maximum"; if runs may start at 0 Health, `test_adventure_end_flow.gd::test_zero_health_counts_a_lost_adventure`, which sets Health to 0 before the run.
- 5.20: `test_character_book.gd::test_trainers_come_from_the_training_actions` (as Task 3.13 left it) gains the drills for Strength and for their minor stats; `test_a_stat_nothing_trains_says_so` moves off Body if a drill's minor is Body.
- Rerun after 5.3, expected green since each writes into the save it bound or a save's own Health back (checked): the other writers of the player's `current_health`, directly or through `adventure_map_fixture.gd`'s `swap_in_known_vitals()`: `test_adventure_combat_victory_event`, `test_fight_rules`, `test_technique_dock`, `test_technique_dock_consumables`, `test_combat_consumable_manager`, `test_adventure_map_zoom`, `test_adventure_tilemap_events`, `test_play_stats_recording`, `test_adventure_end_flow`, `test_dev_commands`, `test_dev_adventure_commands`.

### Risks

- **"Full" depends on Body and gear, and the text saver skips defaults:** the `HEALTH_UNSET` sentinel, filled at bind, once `CharacterManager` (whose gear source reads its own save) gives the new max; `_migrate_to_v3()` writes it explicitly.
- **A half-built action type** (no stop signal or completion effects without its ActionManager branches; its card under Visit, tagged STORY, without a group, tag and presenter): Tasks 5.6 and 5.12.
- **Unattended Auto** (board closed, or beside Auto cycling) breaks one action at a time and four idle checks (`ActionManager.is_idle_action()`, `ZoneActionButton._is_idle_action()`, `NowStrip._is_idle()`, `MapMarkers._is_idle()`): Task 5.16 reuses Task 3.8's Auto; both at once goes back to Lionel.
- **The cycling-only chest flag** (`ZonePanel`, `BoardTransition._apply_chest()`, `BoardTransitionSpec.swaps_chest`, `MainView.open_board()`'s instant path): Task 5.14's drills mode sits beside `set_techniques_mode()` and `is_techniques_mode()`; without drawers the spec sets `swaps_chest = false`, as the Tribulation's does.
- **The click shield** covers only boards before `BoardTransition` in main_game.tscn: Task 5.11.
- **Manual pickups:** `InventoryManager.award_items()` emits `item_awarded` before matching the type (an unsupported type shows in the loot, never stored), and item-award effects lack `describe()` (the tile reads "Done"): Task 5.18 uses a stored type or tests a new branch, and tests learning end to end.
- **Late latches:** UnlockManager re-checks only on events, stage changes, Core Density level, Madra and gold, so ITEM_OWNED or ATTRIBUTE_VALUE gates lag: the action unlocks on an event, and manuals teach through `BodyRefiningManager`.
- **A run at 0 Health:** `AdventureView.stop_adventure()` checks `current_health <= 0` before the timer, so a retreat counts as a loss: Task 5.17's flag, unless Task 5.0 refuses such runs.
- **Shared config:** the autoload and any input action edit `project.godot`; the board closes on `ui_cancel` like the Tribulation (cycling's key is `close_cycling_view`), and each `project.godot` edit is committed with its task.

### Docs to update

- `docs/infrastructure/`: `RESOURCES.md` (the Health pool), `PERSISTENCE.md` (the version step, `health`, the drill fields), `CHARACTER.md` (Strength from drills, Health per rep, the book's Health line), `EFFECTS.md` (`ChangeVitalsEffectData` heals the saved pool), `MAIN_VIEW.md` (the board's state and keys, the cabinet's Health, the Goals board's place), `UNLOCKS.md` (only if a condition is added).
- `docs/combat/COMBAT.md` (the fight's Health handler lives only for the fight), `docs/adventuring/ADVENTURING.md` (Health comes home, rest tiles heal the saved pool, the warning, manuals in loot), `docs/zones/ZONES.md` (the action, card, chest, Now strip), `docs/inventory/INVENTORY.md` (manuals).
- `docs/cultivation/CULTIVATION.md` and `breakthrough-tribulation.md` (the breakthrough is reachable in play), `docs/progression/FOUNDATION_PLAYTHROUGH.md`, `docs/tooling/DEV_TOOLS.md`, `docs/testing/TESTING.md` (the player's Health belongs to the bound save).
- New `docs/body_refining/BODY_REFINING.md`, with its `docs/README.md` row; `CLAUDE.md` (the singleton count, the built systems).

---

## Phase 6: Quests and story (outline)

Branch `feat/stats-rework-6-quests`, cut from `main` after phase 5 merges; one PR. Task 6.0's approved mock-ups turn this outline into full tasks.

### Goal

The Foundation quests teach the new loop: train at home (cycling grows Spirit and refills Madra, body refining grows Strength and refills Health), fight for Core Density, and break through with a full core and Strength and Spirit capped. The Intervener stops teaching the old loop, the chain stays in order now that kills pay Core Density, and the route and presets play the new beats.

### Decided

Elixir quests stay out, with elixirs. Phase 6 owns dialogue and quest copy only: the cycling copy (`CyclingPresenter.REWARD_TEXT`, the `torrential_flow.tres` path node) is Task 3.10's; the breakthrough copy (`CultivationManager.CORE_FULL_LOG`, `foundation_tribulation.tres`'s `intro_text`, `tribulation_action.tres`, the `tribulation_ready` preset's description) Task 1.13's, and `CORE_FULL_LOG`'s timing phase 4's.

What the code shows must be fixed:
- **The chain opens out of order.** NPC 4 (`celestial_intervener_dialogue_4.tres`) is gated only on `q_reach_cd_10` (CULTIVATION_LEVEL ≥ 10, latched). Today only Smooth Flow pays Core Density, bought with the path point `q_first_steps` pays at NPC 3; once kills pay it, NPC 4 can show beside NPC 3 in the first runs. Talked to first, it fires `celestial_intervener_dialogue_4`, and `QuestManager._retroactive_advance()` completes `q_reach_core_density_10` as soon as NPC 3 starts it.
- **False lines** in `assets/dialogue/timelines/celestial_intervener_introduction_1.dtl`: line 16 (`dialogue_3`) says to strengthen the core by cycling, which pays no Core Density from phase 3; line 4 (`dialogue_1`) and `celestial_intervener_dialogue_2.tres`'s description ("With your core now full") call the Madra pool the core, though "Core full" means Core Density 100 elsewhere, and line 4 closes its colour tag with `[color]`; line 21 (`dialogue_4`) reports the Core Density 10 beat.
- **Body refining has no beat;** phase 5 unlocks it with the adventure, on `q_fill_core_completed`.

What stays **(Claude's call)**:
- Pattern B and the rules of `docs/progression/QUESTS_EVENTS_UNLOCKS_CONVENTIONS.md`; in the spirit of its rule 2, every return NPC also requires the previous NPC's event.
- The event ids other content gates on: `celestial_intervener_dialogue_1` (cycling, the Test Zone), `q_fill_core_completed` (adventure, foraging, body refining), `q_first_steps_enemy_defeated` (fired in `AdventureCombat._on_enemy_health_changed()`), `aura_well_discovered`, `merchant_discovered`, `core_density_full`.
- Quest and beat ids, wherever the content keeps its meaning (saves hold `quest_progression.active_quests`, quest id → step index, and `completed_quest_ids`; presets and tests name beats); new content gets new ids.
- Task 1.14's steps raising Strength and Spirit to the cap, in `beat_9_ready`, which the `tribulation_ready` and `copper` presets build on.

### Settled at the mock-up step

- The beat order: which beats teach cycling, body refining and fighting, and in what order.
- Whether "Harden Your Core" keeps a Core Density 10 target, and `q_first_steps` its free path point, now that kill-paid milestones pay one.
- New quests (say a body refining beat): steps, criteria, rewards, the NPC that starts each; new NPC beats as labels `dialogue_5` onward in the same timeline.
- The new lines for every changed label, and the player-facing word for the Madra pool.
- Which NPC puts the breakthrough on the Goals board (`breakthrough_goal_condition` in `foundation_advancement_stage.tres`, today `celestial_intervener_dialogue_4`); any new presets, such as one at the body refining beat.

### Files

Modify:
- `resources/quests/q_fill_core.tres`, `q_first_steps.tres`, `q_reach_core_density_10.tres`, `quest_list.tres`.
- `resources/zones/spirit_valley_zone/zone_actions/celestial_intervener_dialogue_1.tres` to `_4.tres` (`unlock_conditions`, `success_effects`, `description`); `resources/zones/spirit_valley_zone/spirit_valley_zone.tres`, only for new NPC actions.
- `resources/unlocks/q_reach_cd_10.tres` (its target, or removed with its registration) and `resources/unlocks/unlock_condition_list.tres`.
- `assets/dialogue/timelines/celestial_intervener_introduction_1.dtl`.
- `resources/cycling/advancement_stages/foundation_advancement_stage/foundation_advancement_stage.tres` (`breakthrough_goal_condition`), only if the chain's last NPC changes.
- `resources/dev/story_route.tres`, `resources/dev/save_presets/*.tres`.
- Only if needed: a criterion type (`scripts/resource_definitions/unlocks/unlock_condition_data.gd`, `singletons/unlock_manager/unlock_manager.gd`); a step kind (`scripts/resource_definitions/dev/dev_step_data.gd`, `singletons/dev_manager/dev_commands.gd`); a version step (`singletons/persistence_manager/save_game_data.gd`).

Create:
- `resources/unlocks/celestial_intervener_dialogue_2.tres` and `celestial_intervener_dialogue_3.tres`: EVENT_TRIGGERED on the event of the same name, registered in `unlock_condition_list.tres` (`_1` and `_4` exist); one more per further gate the approved chain needs.
- Per new quest, NPC beat or preset: `resources/quests/q_<id>.tres`, `resources/zones/spirit_valley_zone/zone_actions/celestial_intervener_dialogue_<N>.tres`, `resources/dev/save_presets/<preset_id>.tres`.
- `tests/integration/test_foundation_quest_chain.gd`, `tests/unit/test_npc_dialogue_labels.gd`.

---

### Task outline

Test files are named without their folder.

- **Task 6.0: Mock-ups.** A new Design canvas, "Quests and story", answering the list above: the beats as a flow, each quest's steps and rewards, each step's Goals board row, the Intervener's lines as copy. Lionel approves it before Task 6.2.
- **Task 6.1: The chain can't open out of order.** NPCs 2, 3 and 4 each add the previous NPC's event condition to `unlock_conditions`. `test_foundation_quest_chain.gd` `test_no_return_npc_shows_before_the_one_before_it`, a table over NPCs 2 to 4: meet the NPC's own condition early through `DevCommands` (`set_madra(100.0)`, `trigger_event("q_first_steps_enemy_defeated")`, `reach_core_density(10)`), check it stays out of `ZoneManager.get_available_actions()`, then complete the previous NPC (`DevCommands.complete_action()`) and check it shows.
- **Task 6.2: Quest data.** The approved quests, `quest_list.tres`, every condition registered, and the tests pinning the old names and targets. `test_foundation_quest_chain.gd`: `test_every_condition_a_step_or_npc_uses_is_registered`.
- **Task 6.3: NPC actions.** Pattern B effects in order (`TriggerEvent`, then `StartQuest`), descriptions, and the breakthrough goal on the approved NPC. `test_foundation_quest_chain.gd`: `test_each_npc_completes_one_quest_and_starts_the_next`; `test_cultivation_getters.gd::test_foundations_breakthrough_goal_waits_for_npc_4`, renamed if the NPC changes.
- **Task 6.4: Dialogue.** The changed lines and new labels in the timeline, and line 4's `[/color]`; wording is checked by eye. `test_npc_dialogue_labels.gd` `test_every_npc_action_jumps_to_a_label_of_its_timeline`: each NPC action's `dialogue_timeline_name` resolves through `project.godot`'s `[dialogic] directories/dtl_directory` to a file holding `label <dialogue_timeline_label_jump>`.
- **Task 6.5: A new step criterion, only if the mock-ups add one** (such as a stat level): appended to `UnlockConditionData.ConditionType`, re-checked by `UnlockManager` on `CharacterManager.stat_level_changed`, and measurable (`is_measurable()`, `get_current_value()`, `get_target_value()`) so the Goals board shows a figure. A row in `test_unlock_condition_progress.gd::test_measurable_conditions_read_current_and_target`; a figure test in `test_goals_panel.gd`.
- **Task 6.6: The story route.** Beats in the approved order, a step for every criterion; a criterion with no step kind gets an appended `DevStepData.Kind` (after Task 1.14's `RAISE_STAT_TO_CAP = 13`), its `DevCommands` command and its check in `test_story_route.gd`. `test_story_route.gd::test_the_route_validates` and `::test_the_route_covers_the_story`; `test_dev_preset_data.gd::test_kind_numbers_never_change`, if a kind is added.
- **Task 6.7: Presets.** Each preset's `story_through`, plus approved new presets. `test_save_presets.gd`: `STARTING_PRESETS`, `test_the_starting_presets_start_where_the_spec_says`, `test_every_preset_validates_and_builds`.
- **Task 6.8: Old saves' quest progress, only if a kept quest's steps change.** A version step, numbered after phase 5's, moves the indices in `quest_progression.active_quests` to the new steps. `test_save_migration.gd`: `test_v4_moves_an_active_quest_to_its_new_step` (v4 if phase 5 took v3).
- **Task 6.9: Wrap.** The full suite passes, and the PR has a `## Docs to update` list. After the merge, the milestone docs (`docs/STATE_OF_THE_GAME.md`, `docs/GAMEPLAY_STATE.md`, `docs/CODEBASE_STATE.md`) get a docs PR of their own.

### Tests that break

These pin today's chain; each is updated in the task that changes what it pins.
- `test_goals_panel.gd`: `test_quest_row_shows_current_step` and `test_reads_active_quest_on_ready` ("Awaken Your Core"); `test_shows_the_first_active_quest` and `test_refreshes_on_save_reset` ("First Steps Out"); `test_figure_follows_madra` ("60 / 100"); `test_a_quest_before_npc_4_stands_alone` and `test_npc_4_hands_the_board_to_the_breakthrough`.
- `test_beat_3b_merchant_unlock.gd::test_full_beat_3b_flow` shows NPC 4 by reaching Core Density 10 alone; from Task 6.1 it completes NPC 3 first. It also breaks if the map moves to another quest.
- `test_journal_page.gd` ("Harden Your Core" gave the map) and `test_quest_item_link.gd::test_refugee_camp_map_belongs_to_harden_your_core`.
- `test_unlock_condition_progress.gd::test_measurable_conditions_read_current_and_target`: `q_fill_core_madra_full` at 100, `q_reach_cd_10` at 10.
- `test_cultivation_getters.gd::test_foundations_breakthrough_goal_waits_for_npc_4`, if the goal moves.
- Both tests in `test_story_route.gd`, and `STARTING_PRESETS` in `test_save_presets.gd`, until Tasks 6.6 and 6.7.
- Only if the ids they name go away: `test_dev_hooks.gd` (the three quest ids); `test_dev_manager_build.gd` (`q_reach_cd_10`, NPC 4); `test_dev_panel_story_tab.gd` (`beat_1`, `beat_2`, NPCs 1, 2 and 4, `q_fill_core`, "Locked: needs q_fill_core_madra_full"); `test_dev_panel_saves_tab.gd` (NPC 4, `q_fill_core_completed`); `test_dev_preset_data.gd` (NPCs 1 and 2, `q_fill_core.tres`).
- Green while the kept event ids keep their meaning: `test_adventure_combat_victory_event.gd` (`q_first_steps_enemy_defeated`), and the files that open content through `celestial_intervener_dialogue_1` or `q_fill_core_completed`: `test_zone_panel`, `test_zone_action_cards`, `test_seen_actions`, `test_idle_action_resolution`, `test_map_markers`, `test_zone_travel`, `test_zone_walk_steps`, `test_zone_map_render`, `test_zone_map_state`, `test_materials_page`, `test_merchant_shop_flow`, `test_material_sources`, `test_zone_progression_data`, `test_tribulation_flow`.

### Risks

- **A quest done the moment it starts:** `_retroactive_advance()` skips met steps, so approved criteria must be unmeetable before their quest starts; Task 6.1's test reaches Core Density 10 early and plays on.
- **Old saves' quest progress:** `_prune_unknown_active_quests()` drops a renamed quest, and changed steps change what a saved index means: keep ids and append steps, or Task 6.8.
- **UID mismatches:** `quest_list.tres` references `q_first_steps.tres` as `uid://bqfirststeps01` (header `uid://d1mcp5rsmbbwu`); `q_reach_cd_10.tres` is referenced as `uid://i2xnqd3pem53` (header `uid://bqreachcd10001`) and `q_first_steps_enemy_defeated.tres` as `uid://d1vxkodelucwu` (header `uid://bqfsendefeat01`). An editor save may rewrite references, so edit these by hand and commit any editor rewrite alone.
- **Late latches:** UnlockManager re-checks only on events, stage changes, Core Density level, Madra and gold: prefer event criteria, or Task 6.5.
- **Dialogic:** a new timeline needs registering in `project.godot`'s `[dialogic] directories/dtl_directory`, a key a fresh `--import` once emptied: new labels go in the existing timeline.
- **Beat ids:** presets, dev panel tests and the route name beats: keep them; new beats get new ids.

### Docs to update

- `docs/progression/`: `QUESTS.md` (quests, steps, rewards), `QUESTS_EVENTS_UNLOCKS_CONVENTIONS.md` (its Foundation examples), `FOUNDATION_PLAYTHROUGH.md` (the beats). `docs/infrastructure/`: `DIALOGUE.md` (the label and NPC tables, the malformed-tag note), `UNLOCKS.md` (new conditions). `docs/tooling/DEV_TOOLS.md` (route beats and presets).
- The milestone docs, in their own docs PR after the merge (Task 6.9).

---

## After phase 6

- **Milestone docs:** once phase 6 merges, `docs/STATE_OF_THE_GAME.md`, `docs/GAMEPLAY_STATE.md` and `docs/CODEBASE_STATE.md` are refreshed in a docs PR of their own (CLAUDE.md). CLAUDE.md's count of manager singletons and its list of built systems change with phase 5's new autoload.
- **Elixirs (out of scope):** `docs/superpowers/specs/2026-11-03-elixirs-and-materials-notes.md` assumes cycling pays Core Density. Revisit it before elixirs are built: cycling elixirs could boost stat XP instead, or the Core Density boost could move to fights.
- **Set aside for later, by Lionel:** fights paying stat XP, Core Density raising the stat cap every X levels, and XP banked while a stat is capped.
- **Publishing:** no itch build until phase 5 lands, because the breakthrough can't be reached before then (Claude's call; Lionel publishes by hand).
