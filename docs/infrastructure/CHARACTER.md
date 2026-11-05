# Character, Player Vitals and Character View

## Overview

Three pieces make up the player's persistent identity outside of abilities:

- **`CharacterManager`** (autoload) owns the six **stats**: Strength, Body and Agility on the Physical side, Spirit, Mind and Control on the Spiritual side. Each is a trained level with XP toward the next, saved in `SaveGameData.stat_training` (`StatTrainingData`). A stat's **total** is its trained value plus its modifier sources, and every system that needs stats reads the totals. Mind is the Madra stat; Foundation names only the first cultivation stage. No stat cuts damage taken: gear's armor and Ward do.
- **`PlayerManager`** (autoload) holds the player's single persistent **`VitalsManager`** (health, stamina, and combat Madra), which every adventure and fight reuses.
- **Character View** (press **C**) is a read-only menu book (the indigo one of the four menu books, see [MAIN_VIEW.md](MAIN_VIEW.md#menu-books)). The left page shows the six stats as tiles; the right page describes the one you point at.

Abilities are not part of this system. Unlocks and the 4-slot loadout live in `AbilityManager` (see [ABILITIES.md](../abilities/ABILITIES.md)).

## Player Experience

1. On the zone view, press **C** or click **Character** on the dock at the bottom. A grey backdrop fades in while the indigo book opens.
2. The pages are pressed paper, as in the Inventory, each headed by a title with its ornament (`PageTitle`): "Character" on the left page, the name of the stat described on the right. On the left page, two rows of three tiles sit under captions in capitals:
   - **PHYSICAL:** Strength, Body, Agility
   - **SPIRITUAL:** Spirit, Mind, Control

   Each tile shows the stat's icon with its total on a paper tag, its name, its level ("Lv 3") and a bar of its XP toward the next level. At the stage's cap the bar is full under a CAPPED seal. On a fresh save every tile shows Lv 1 and 10.
3. Under the tiles, **IN A FIGHT** lists the totals a fight reads, in two columns: Health, Madra, Stamina and Dodge chance, then Technique cost cut, Cooldown cut, Armor and Ward.
4. Pointing at a tile marks it with printer's marks and describes it on the right page, under the stat's side (PHYSICAL or SPIRITUAL):
   - its icon with the total on a paper tag, its level against the stage's cap ("Lv 3 / 10"), an XP bar and the XP figure ("57 / 157 XP": the XP rounds down and the cost up, so a level never reads as reached before it is);
   - a line on what the stat is;
   - **WHAT IT DOES**, each line at the stat's level and at the next ("NOW → LV 4"): first the derived stats it sets (Body's Max Health, Agility's Max Stamina, Stamina regen and Dodge chance, Mind's Max Madra, Control's two cuts), then each unlocked technique that scales with it ("Basic Strike damage"). A stat with no line, such as Spirit before any Spirit technique, says "Not yet active";
   - **WHERE IT COMES FROM**: the trained value ("Trained (Lv 3)") and the worn gear's bonus ("Gear", "+2").

   At the cap the XP figure and the "NOW → LV" caption hide, and each line shows only its current value. The page never names what trains a stat. It keeps the last stat pointed at; Strength is shown when the book opens.
5. The book reads every stat as it opens. While it is open it follows every stat, level and XP change, gear's included, and a breakthrough, which raises the cap.
6. **C**, **Esc**, the close tab on the book's top edge, or a click outside the book closes it. It can only be opened from the zone view, not during adventures, cycling or other modals. The open and close path is in [MAIN_VIEW.md](MAIN_VIEW.md#menu-books).

Stats grow in two ways:

- **Trained levels:** the Aura Well training action gives a whole Spirit level per training level (`AwardAttributeEffectData`), up to the stage's cap. The dev tools set any stat's level.
- **Gear:** each worn item adds its percents of the trained values, at once ([Total attributes](#total-attributes)).

## Architecture

```
CharacterManager (autoload)                singletons/character_manager/character_manager.gd
  live_save_data.stat_training ──► each stat's trained level and XP (StatTrainingData)
  modifier sources (StatModifierStack) ──► "gear": the worn items' percents of the trained values, armor and Ward
  get_stat(stat) / get_total_attributes_data() ──► totals, and the derived stats over them
  signals: stats_changed, stat_level_changed(stat, level), stat_xp_changed(stat, xp, xp_to_next)

PlayerManager (autoload)                   singletons/player_manager/player_manager.gd
  └── PlayerVitalsManager (VitalsManager, is_player = true)
        listens: CharacterManager.stats_changed → max Health, Stamina and Madra from get_stat()

MainView (main_game.tscn)
  MainViewStateMachine/CharacterViewState  scenes/character/character_view_state.gd (BookViewState)
  CharacterView (MenuBookView)             scenes/character/character_view.tscn / .gd, theme book_theme.tres
    BookFrame                              scenes/ui/book_frame/, style character_book_style.tres
    left page:  PageTitle "Character"      scenes/inventory/pressed/page_title/
                PHYSICAL → AttributeTile ×3 (Strength, Body, Agility)
                SPIRITUAL → AttributeTile ×3 (Spirit, Mind, Control)
                IN A FIGHT → TableRows in two columns   scenes/inventory/pressed/table_row/
    right page: PageTitle (the stat's name) and the stat's side
                the icon with the total on a paper tag, the level and cap, an XP bar, the XP figure, the CAPPED seal
                the stat's description
                WHAT IT DOES (NOW → LV n) → TableRows
                WHERE IT COMES FROM → TableRows

AttributeTile (PanelContainer)             scenes/character/attribute_tile/
  the icon with the total on a paper tag, the name, the level, an XP bar, the CAPPED seal, printer's marks

XP bars: LacquerRod                        scenes/common/lacquer/lacquer_rod.tscn, on the pressed XP art
                                           (assets/sprites/ui/book/pressed/pressed_xp_{tile,page}_{empty,full}_ai.png)
StatDisplay                                scripts/utils/stat_display.gd: each stat's name, icon and side
```

## Data Model

### CharacterAttributesData

`scripts/resource_definitions/character/character_attributes_data.gd` defines `class_name CharacterAttributesData extends Resource`: one combatant's stat block, an enemy's or the player's fight snapshot. It is not the save's record (see [StatTrainingData](#stattrainingdata)).

| Field | Type | Default | `AttributeType` value |
|-------|------|---------|-----------------------|
| `strength` | `float` | `10.0` | `STRENGTH` = 0 |
| `body` | `float` | `10.0` | `BODY` = 1 |
| `agility` | `float` | `10.0` | `AGILITY` = 2 |
| `spirit` | `float` | `10.0` | `SPIRIT` = 3 |
| `mind` | `float` | `10.0` | `MIND` = 4 |
| `control` | `float` | `10.0` | `CONTROL` = 5 |
| `armor` | `float` | `0.0` | — (cuts physical damage taken) |
| `ward` | `float` | `0.0` | — (cuts Spirit damage taken) |

`.tres` files store `AttributeType` values as ints (an award effect's or an unlock condition's `attribute_type`), so values are only ever added at the end.

| Method | Behaviour |
|--------|-----------|
| `static make(values = {})` | A block with the given values by key (the stat keys, `&"armor"` and `&"ward"`), the rest at their defaults. An unknown key is logged and skipped |
| `static stat_key(type) -> StringName` | The stat's key, its enum name in lower case (`&"mind"`). The training record and gear's percents are keyed by it |
| `static stat_from_key(key) -> int` | The stat with that key, or −1 |
| `get_attribute(type) -> float` / `set_attribute(type, value)` | `match` dispatch. An unknown type calls `Log.error` (and `get_attribute()` returns 0.0) |
| `get_max_health()`, `get_max_stamina()`, `get_stamina_regen()`, `get_max_madra()`, `get_dodge_chance()`, `get_madra_cost_cut()`, `get_cooldown_cut()` | The derived stats over this block's values (formulas under [Derived stats](#derived-stats)) |

Enemy blocks are authored in each `CombatantData.attributes`. The player's block is built for each fight by `CharacterManager.get_total_attributes_data()` and never saved. How an older save's stats load is in [PERSISTENCE.md](PERSISTENCE.md#versioning).

### StatTrainingData

`scripts/resource_definitions/character/stat_training_data.gd`: the player's training record, saved as `SaveGameData.stat_training`. In play CharacterManager is its only reader and writer.

| Field | Type | Default |
|-------|------|---------|
| `levels` | `Dictionary[StringName, int]` | `{}`: stat key → level. A stat with no entry is at Lv 1 |
| `xp` | `Dictionary[StringName, float]` | `{}`: stat key → XP toward the next level. A stat with no entry has none |

`new_default()` writes every stat out at Lv 1 with no XP, for a fresh save. Its setters write what they are given, unclamped: CharacterManager enforces the rules.

### StatProgressionData and the stat cap

`scripts/resource_definitions/character/stat_progression_data.gd` is the level curve. CharacterManager's `stat_progression` export holds `resources/character/stat_progression.tres`:

| Field | Value | Meaning |
|-------|-------|---------|
| `xp_to_level_two` | `100` | The XP that Lv 2 costs |
| `xp_growth` | `1.25` | Each later level costs this many times the one before |
| `value_per_level` | `1` | What each level past Lv 1 adds to the stat, which is 10 at Lv 1 |

`get_xp_to_next(level)`, the XP from `level` to the next, is `100 × 1.25^(level − 1)`, and `get_value_for_level(level)` is `10 + (level − 1)`.

Each stage's `stat_level_cap` (`AdvancementStageResource`) is the highest level a stat can be trained to in that stage; [CULTIVATION.md](../cultivation/CULTIVATION.md#advancement-stages) has the values. `CharacterManager.get_stat_level_cap()` reads it live, so the breakthrough raises it. The cap counts trained levels only: levels and XP past it are lost, but gear can lift a total past it.

### CharacterManager

| Member | Behaviour |
|--------|-----------|
| `signal stats_changed` | Any total may have changed: after a trained level changes, after every `InventoryManager.inventory_changed` (worn gear moves the bonuses), after a save reset, and after a modifier source is set or removed. Listeners re-read `get_stat()` or `get_total_attributes_data()` |
| `signal stat_level_changed(stat, level)` | Once for each level a stat gains, and once per `set_stat_level()` |
| `signal stat_xp_changed(stat, xp, xp_to_next)` | Once per `add_stat_xp()`, `add_stat_levels()` and `set_stat_level()` call |
| `get_stat(stat: StatModifierData.Stat) -> float` | The total of one of the six stats, or of a derived stat (see [Total attributes](#total-attributes)) |
| `get_total_attributes_data() -> CharacterAttributesData` | A fresh block of the six totals, armor and Ward: the player's fight snapshot, which does not follow later changes |
| `set_modifier_source(source, provider)` / `remove_modifier_source(source)` | Sets or removes the named source of `StatModifierData`, which is asked at every read. Both emit `stats_changed`. `"gear"` is the worn gear's ([Total attributes](#total-attributes)) |
| `get_gear_bonus(stat) -> float` | The flat points the worn gear adds to the stat (the book's "Gear" line) |
| `get_stat_level(stat)`, `get_stat_xp(stat)`, `get_stat_xp_to_next(stat)` | The trained level (1 without a save), the XP toward the next level, and what that level costs on the curve, also at the cap |
| `get_stat_level_cap()`, `is_stat_capped(stat)` | The stage's cap, read from `CultivationManager`; true when the trained level is at or past it. Gear never counts |
| `get_trained_value(stat)`, `get_trained_values()` | A stat's value from its level alone, or all six by `AttributeType`. They never call `get_stat()`, so a modifier source can call them |
| `add_stat_xp(stat, amount)` | Adds XP and raises a level for each level it pays for, up to the cap. A capped stat holds no XP: what arrives is lost, and the level that reaches the cap drops the XP left over. Nothing in the game calls it |
| `add_stat_levels(stat, count)` | Raises the stat `count` whole levels, up to the cap: the levels past it are lost, and a stat at or past the cap stays where it is. The XP is kept unless the call reaches the cap. `AwardAttributeEffectData` calls it |
| `set_stat_level(stat, level, xp = 0.0)` | The dev tools' setter: any level from 1, past the cap too, with the XP held below the level's cost. It logs nothing |
| `get_gold_multiplier() -> float` | Always `1.0` (a `TODO`) |
| `static get_attribute_display_name(type) -> String` | `"STRENGTH"` becomes `"Strength"`: the stat's name on screen and in the log |

Each level gained through `add_stat_xp()` or `add_stat_levels()` writes "**Spirit** reached Lv 4" to the player's log. Among the signals' listeners are the Character book and the cultivator cabinet's stat cells.

### PlayerManager and VitalsManager

`PlayerManager._ready()` creates `VitalsManager.new()` named `PlayerVitalsManager`, sets `is_player = true`, and adds it as a child. Code reaches it through `PlayerManager.vitals_manager`. None of this state is saved. `PlayerManager.reset_vitals()` replaces it with a new one built the same way, so nothing of a run carries over (not its Health, Stamina or Madra, nor its regen): the old one leaves the tree at once and is freed at the end of the frame, and a board that bound it follows the new one when the main scene loads again. A dev session switch calls it.

| VitalsManager behaviour (player) | Detail |
|----------------------------------|--------|
| Attribute source | On `_ready()`, and on every `CharacterManager.stats_changed`, it reads its maxima from `CharacterManager.get_stat()`, so gear and any other source count |
| Max values | `max_health`, `max_stamina` and `max_madra` are the derived Max Health, Max Stamina and Max Madra ([Derived stats](#derived-stats)). An enemy's come from its own `character_attributes_data` |
| Adventure start | `AdventureView` calls `initialize_current_values(madra_budget)`: health and stamina go to max, and Madra is set to the drained budget |
| Regen | `stamina_regen` is the run's Stamina regen during an adventure ([ADVENTURING.md](../adventuring/ADVENTURING.md#adventureactiondata-extends-zoneactiondata) has how a run sets it with `stamina_regen_modifier`), then 0 after it. `health_regen` and `madra_regen` are never set (0) |
| Changes | `apply_vitals_change(health, stamina, madra)` clamps each to `[0, max]`. Callers: adventure movement (−5 stamina per tile, `MOVEMENT_STAMINA_COST`), `ChangeVitalsEffectData`, and combat effects and costs |
| Signals | `health_changed`, `stamina_changed`, `madra_changed` (separate from `ResourceManager.madra_changed`) |

See [COMBAT.md](../combat/COMBAT.md) for how combat uses these.

### Character View nodes

| Node / script | What it does |
|---------------|--------------|
| `CharacterView` (`class_name CharacterView extends MenuBookView`) | Fills both pages from CharacterManager: each tile's level, XP and total, the In a fight block, and the right page, which describes the stat pointed at: its level, XP and description, the derived stats it sets and the unlocked techniques that scale with it at its level and the next, and where its total comes from. It selects Strength and reads everything as the book opens, and while the book is shown it reads again on every stat, level, XP and stage change |
| `AttributeTile` (`class_name AttributeTile`) | Shows one stat on the left page, the one its `attribute_type` export names: icon and name from `StatDisplay`, the total, the level, the XP bar and, at the cap, the CAPPED seal. Pointing at it emits `hovered(tile)`, and it wears printer's marks while its stat is the one described |
| `CharacterViewState` (`class_name CharacterViewState extends BookViewState`) | View `character_view`; closes on `ui_cancel`, `open_character`, the close tab or a backdrop click |

## Core Systems and Flows

### Total attributes

```
get_stat(stat)                     # the one read; nothing is cached
  STRENGTH … CONTROL:  base = the trained value (its level's value on the curve)
  derived stats:       base = the stat's formula over get_total_attributes_data()
  ARMOR, WARD:         base = 0
  total = (base + Σ flat modifiers) × (1 + Σ percent modifiers), over every source
```

A modifier source is a provider under a name, set with `set_modifier_source()`. It returns `StatModifierData` (a stat, `FLAT` or `PERCENT`, and a value) and is asked at every read, so no total goes stale. `StatModifierStack` folds the sources: each stat's flat modifiers are added, then its percents are summed and applied once. A derived stat takes its own modifiers after its formula, and armor and Ward come from modifiers alone.

The game has one source, `"gear"`. For each equipped item and accessory it gives the item's stat percents as flat points, each the percent of the stat's trained value rounded down and never below the item's `stat_bonus_floor`, then the item's armor and Ward. A percent counts the trained value, never a total that holds another item's bonus, and the cap never limits it. Percents keep gear worth wearing as the stats climb, and the floor keeps a small percent from giving nothing at Lv 1. The gear source reads the equipped items from CharacterManager's own save, so during a save reset it already reads the save being loaded.

These are not included in totals:

- Path `ATTRIBUTE_BONUS` perks. `PathManager` aggregates them, but nothing reads them.
- Combat buffs, which `CombatBuffManager` applies to combat attributes only.
- Cultivation stage bonuses. The stage caps trained levels and adds nothing to a total.

### Derived stats

| Stat | Formula | Computed in |
|------|---------|-------------|
| Max Health | `Body × 10` | `CharacterAttributesData.get_max_health()` |
| Max Stamina | `Agility × 5` | `CharacterAttributesData.get_max_stamina()` |
| Stamina regen | `Agility × 0.1` a second | `CharacterAttributesData.get_stamina_regen()` |
| Max Madra | `Mind × 10`: the player's combat Madra maximum, not the core's Madra pool cap | `CharacterAttributesData.get_max_madra()` |
| Adventure Madra capacity / threshold | See [RESOURCES.md](RESOURCES.md#madra-caps) | `ResourceManager` |
| Dodge chance | `0.35 × x / (x + 15)`, where `x` is Agility above 10: none at Lv 1, half the 35% ceiling at 15 points above it, never the ceiling | `CharacterAttributesData.get_dodge_chance()` |
| Technique cost cut | `0.5 × x / (x + 20)`, where `x` is Control above 10: half the 50% ceiling at 20 points above Lv 1 | `CharacterAttributesData.get_madra_cost_cut()` |
| Cooldown cut | `0.4 × x / (x + 20)`, where `x` is Control above 10: half the 40% ceiling at 20 points above Lv 1 | `CharacterAttributesData.get_cooldown_cut()` |
| Ability value | See [COMBAT.md](../combat/COMBAT.md#combateffectdata-scriptsresource_definitionscombatcombat_effect_datagd) | `CombatEffectData.calculate_value()` |
| Damage taken | See [COMBAT.md](../combat/COMBAT.md#damage-formula) | `CombatEffectData.calculate_damage()` |
| Vitals effects | Total Body through `body_hp_multiplier` and total Mind through `mind_madra_multiplier`; the formulas are in [EFFECTS.md](EFFECTS.md#changevitalseffectdata) | `ChangeVitalsEffectData` |
| Gold multiplier | `1.0` | `CharacterManager.get_gold_multiplier()` |

`CharacterManager.get_stat()` reads each formula over the player's totals, then adds the stat's own modifiers. At Lv 1 with no gear the player has 100 Health, 50 Stamina, 1 Stamina a second, 100 Madra, and no dodge or cuts. Where a fight applies the dodge and the cuts is in [COMBAT.md](../combat/COMBAT.md#ability-lifecycle).

### Attribute usage

| Stat | What reads it |
|------|---------------|
| STRENGTH | `strength_scaling`: physical technique damage (Basic Strike's). The Tribulation needs its trained level at the cap |
| BODY | Max Health, `body_hp_multiplier` |
| AGILITY | Max Stamina, Stamina regen, the dodge chance (only the player dodges) |
| SPIRIT | `spirit_scaling`: Spirit technique damage (Empty Palm's and Power Font's) and heals. The Tribulation needs its trained level at the cap too. It cuts no damage taken: Ward cuts Spirit damage |
| MIND | Max Madra, the adventure Madra capacity, `mind_madra_multiplier` |
| CONTROL | The technique cost cut and the cooldown cut (the player's only) |

Techniques scale from Strength or Spirit only; [ABILITIES_MATRIX.md](../abilities/ABILITIES_MATRIX.md#scaling-reference) has each one's coefficients. Each gear item's percents, armor and Ward are in [ITEMS.md](../inventory/ITEMS.md#spirit-valley).

`UnlockConditionData` `ATTRIBUTE_VALUE` conditions compare the total attributes. The only content using one is `test_attribute_requirement_unlock_data` (BODY >= 20).

## Integration Points

| System | Connection |
|--------|------------|
| PersistenceManager | `SaveGameData.stat_training` holds the training record. A save reset makes CharacterManager emit `stats_changed` |
| InventoryManager | CharacterManager hears `inventory_changed` and emits `stats_changed`. The gear source reads `equipped_gear` / `equipped_accessories` from CharacterManager's own save's inventory |
| ResourceManager | `get_adventure_madra_capacity()` reads Max Madra, from the total Mind (see [RESOURCES.md](RESOURCES.md)) |
| CultivationManager | `get_stat_level_cap()` gives the stage's stat cap. The Character book and the cabinet follow `advancement_stage_changed`, because a breakthrough raises the cap |
| AdventureCombat | Snapshots `get_total_attributes_data()` (the six stats, armor and Ward) into the player `CombatantData` at combat start, and passes `PlayerManager.vitals_manager` as the player's external vitals. The fight reads the dodge chance and Control's cuts from that snapshot |
| AdventureView / AdventureTilemap | Initialize vitals with the Madra budget, set the run's Stamina regen from `get_stat(STAMINA_REGEN)` ([ADVENTURING.md](../adventuring/ADVENTURING.md#adventureactiondata-extends-zoneactiondata) has how the run's modifier applies), spend 5 stamina per move, and read health for the end card |
| ChangeVitalsEffectData | Reads total Body and Mind and applies the result to `PlayerManager.vitals_manager` (encounters, consumables) |
| AwardAttributeEffectData | The only game code that calls `add_stat_levels()` (see [EFFECTS.md](EFFECTS.md#awardattributeeffectdata)). The dev commands `DevCommands.set_stat_level()` and `raise_stat_to_cap()` set a level through `CharacterManager.set_stat_level()` instead ([DEV_TOOLS.md](../tooling/DEV_TOOLS.md#dev-commands)) |
| Tribulation gate, card and Goals milestone | `TribulationActionData` needs Strength and Spirit at the cap, counting trained levels, never gear (`is_stat_capped()`). Its card and the Goals board's Breakthrough milestone list each one still short ("Strength Lv 3 / 10") and follow `stat_level_changed` ([ZONES.md](../zones/ZONES.md#activity-cards-and-presenters), [QUESTS.md](../progression/QUESTS.md#goalspanel-scenesuigoals_panelgoals_paneltscn-class-goalspanel)) |
| Cultivator cabinet (zone view) | `CultivatorPlate`'s six `StatCell`s show each stat's trained level and a ring of its XP, full at the cap. The cabinet follows `stats_changed` and `stat_xp_changed` ([ZONES.md](../zones/ZONES.md#cultivator-cabinet-and-dock)) |
| UnlockConditionData | `ATTRIBUTE_VALUE` conditions read totals. UnlockManager does not listen to `stats_changed`, so these conditions are only re-checked when another signal fires (Madra, gold, event, cultivation) |
| AbilitiesView, `TechniqueTooltip` | Damage previews from `get_total_attributes_data()`, and cost and cooldown after Control's cuts through `get_stat()` (see [ABILITIES.md](../abilities/ABILITIES.md)) |
| AbilityManager | The right page lists the unlocked abilities that scale with the stat |
| PathManager | `PathEffectsSummary.attribute_bonuses` is computed but not consumed |
| MainView / GreyBackground / Dock | Host the Character View and drive its modal flow |

## Existing Content

- **Stat icons:** in `assets/sprites/ui/attribute_icons/`, `strength_icon.png`, `body_icon.png`, `agility_icon.png`, `spirit_icon.png`, `foundation_icon.png` (Mind's) and `control_icon_ai.png` (32 px art stored at 2×). `StatDisplay` hands them out, so the Character book, the cultivator cabinet and the Abilities book's damage breakdown show the same six. The original `control_icon.png` sits off centre, so `control_icon_ai.png` is a re-centred copy. Nothing loads `control_icon.png`, `resilience_icon.png` or `willpower_icon.png`. The dock's Character button uses `assets/sprites/ui/system_menu/character_icon.png`.
- **Gear with stat bonuses:** the items in `resources/items/equipment/spirit_valley/`. [ITEMS.md](../inventory/ITEMS.md#spirit-valley) lists each one's percents, armor, Ward and source.
- **Stat awards:** `resources/zones/spirit_valley_zone/zone_actions/aura_well_spirit_award_effect.tres` (SPIRIT, amount 1.0): a Spirit level for each Aura Well training level.

## Key Files

| File | Purpose |
|------|---------|
| `singletons/character_manager/character_manager.gd` | Trained levels and XP, the cap, totals through the modifier sources (the gear source among them), the derived stats, the stat signals |
| `singletons/character_manager/stat_modifier_stack.gd` | Folds every source's modifiers into a stat |
| `scripts/resource_definitions/character/stat_modifier_data.gd` | One flat or percent bonus, and the `Stat` enum: the six stats and the derived ones |
| `scripts/resource_definitions/character/character_attributes_data.gd` | A combatant's stat block, the stat keys, the derived-stat formulas |
| `scripts/resource_definitions/character/stat_training_data.gd` | The saved training record: each stat's level and XP |
| `scripts/resource_definitions/character/stat_progression_data.gd`, `resources/character/stat_progression.tres` | The level curve: each level's XP cost and value |
| `scripts/utils/stat_display.gd` | `StatDisplay`, the one map of each stat's name, icon and side |
| `singletons/player_manager/player_manager.gd` | Creates the persistent player `VitalsManager` |
| `scenes/combat/combatant/vitals_manager/vitals_manager.gd` | Max values, regen, clamped vitals changes |
| `scripts/resource_definitions/effects/award_attribute_effect_data.gd` | Data-driven award of whole stat levels |
| `scenes/character/character_view.tscn` / `.gd` | Character book, the stat descriptions and the lines its pages print |
| `scenes/character/character_view_state.gd` | Modal state (`BookViewState`) |
| `scenes/character/attribute_tile/attribute_tile.tscn` / `.gd` | Tile subscene |
| `scenes/ui/main_view/states/zone_view_state.gd` | Pushes `CharacterViewState` on `open_character` |

Tests: `tests/unit/test_character_*.gd` and `tests/integration/test_character_*.gd`, among others named after what they check; [TESTING.md](../testing/TESTING.md#coverage-gaps) lists what they do not cover.

Design history: [character view spec](../superpowers/specs/2026-04-16-character-view-design.md) and [plan](../superpowers/plans/2026-04-16-character-view.md); the stats rework's [spec](../superpowers/specs/2026-11-04-stats-rework-design.md), [decision record](../superpowers/specs/2026-11-04-stats-rework-decisions.md) and [plan](../superpowers/plans/2026-11-04-stats-rework.md).

## Work Remaining

### Bugs

- `[LOW]` The tile's and the page's XP bars round to the nearest step, so a stat just short of its next level shows a full bar on both, while the page's figure reads, say, "156 / 157 XP". The cabinet's ring lights a bead only once its share is earned.

### Missing Functionality

- `[HIGH]` Only Spirit can be trained in play, by the Aura Well's whole levels. Strength, Body, Agility, Mind and Control stay at Lv 1 except through the dev tools (gear raises their totals, not their levels), and with Strength untrainable the breakthrough can't be readied in play. Nothing pays stat XP either (`add_stat_xp()` has no caller in the game), so in play the cabinet's rings and the book's XP bars show no progress toward a level: they are empty below the cap and full at it, which only Spirit reaches, through the Aura Well. The [stats rework spec](../superpowers/specs/2026-11-04-stats-rework-design.md) designs their sources: cycling for the Spiritual stats and body refining for the Physical ones.
- `[MEDIUM]` Path `ATTRIBUTE_BONUS` perks are not applied. The worn gear is CharacterManager's only modifier source, and `PathEffectsSummary.attribute_bonuses` is never read. No current Pure Madra node uses `ATTRIBUTE_BONUS`, so nothing visible is lost yet.
- `[MEDIUM]` The Character book has no summary of the worn gear, and shows neither the cultivation stage nor Core Density.
- `[MEDIUM]` `CharacterManager.get_gold_multiplier()` always returns `1.0`.

### UI

- `[LOW]` The book's levels borrow theme variants named for other pages: the right page's level uses `LabelBookItemName`, and the tile's `LabelBookQuestName`.

### Tech Debt

- `[LOW]` Consumers follow `stats_changed`, but every derived read builds the whole snapshot: `get_stat()` of a derived stat reads all six stats, armor and Ward through every source, so one refresh of the book builds it many times. A cached block, rebuilt on `stats_changed`, would build it once.
- `[LOW]` A modifier source that raised the dodge chance or a cut directly would show in `get_stat()`, which the book's In a fight block and the Abilities book's and the technique tooltip's costs and cooldowns read, but a fight would not apply it: the fight reads the snapshot's curves from Agility and Control. Nothing bounds such a modifier either, so a large one would read past 100%.
- `[LOW]` `AttributeTile` and `CharacterView` each copy `PaperTag`'s even-width fit for their paper tags, and the In a fight block's column widths are set in code, not in the scene.
- `[LOW]` `PlayerManager` has no class doc.
