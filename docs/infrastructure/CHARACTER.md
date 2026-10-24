# Character, Player Vitals and Character View

Last updated: 2026-10-23

## Overview

Three pieces make up the player's persistent identity outside of abilities:

- **`CharacterManager`** (autoload) owns the 8 **base attributes**, which are persisted in `SaveGameData.character_attributes`. It computes **total attributes** as base + equipment bonuses for every system that needs stats.
- **`PlayerManager`** (autoload) holds the player's single persistent **`VitalsManager`** (health, stamina, and combat Madra), which every adventure and fight reuses.
- **Character View** (press **C**) is a read-only menu book (the indigo one of the four menu books, see [MAIN_VIEW.md](MAIN_VIEW.md#menu-books)). The left page shows the 8 total attributes as tiles; the right page describes the one you point at.

Abilities are not part of this system. Unlocks and the 4-slot loadout live in `AbilityManager` (see [ABILITIES.md](../abilities/ABILITIES.md)).

## Player Experience

1. On the zone view, press **C** or click **Character** on the dock at the bottom. A grey backdrop fades in while the indigo book opens.
2. The left page carries the "Character" title ribbon and two header plaques, each over a row of four attribute tiles (the icon at 64 px, the value in large gold and the name, centred on a small card):
   - **Physical:** Strength, Body, Agility, Resilience
   - **Spiritual:** Spirit, Foundation, Control, Willpower
3. Values are **totals** (base + equipped gear), rounded to whole numbers (`"%.0f"`). A new character shows 10 everywhere.
4. Pointing at a tile selects it (a warm tint) and describes it on the right page: a plaque with the name, then one card that fills the page. The card has the icon, name, group ("Physical attribute") and value, the description in a three-line area, a divider, an "Effects" caption and the effect lines. Those lines (each marked "▲") are the attribute's formulas, written to match the code, then every unlocked ability that scales with it, read from the ability data ("Basic Strike: +1 damage per point"). An attribute with neither says "Not yet active". The effects start at the same height for every attribute. The right page keeps the last attribute pointed at; Strength is shown when the book opens.
5. **C**, **Esc**, the close tab on the book's top edge, or a click outside the book closes it. It can only be opened from the zone view, not during adventures, cycling or other modals.

Attributes grow in two ways:

- **Gear:** equipment `attribute_bonuses`, which apply immediately to totals.
- **Base gains:** `AwardAttributeEffectData`. The only content using it is the Aura Well training action, which gives +1 Spirit per training level.

## Architecture

```
CharacterManager (autoload)                singletons/character_manager/character_manager.gd
  live_save_data.character_attributes ──► base values (CharacterAttributesData)
  get_total_attributes_data() ──► new CharacterAttributesData(base + equipment bonuses)
  signal base_attribute_changed(attribute_type, new_value)

PlayerManager (autoload)                   singletons/player_manager/player_manager.gd
  └── PlayerVitalsManager (VitalsManager, is_player = true)
        listens: CharacterManager.base_attribute_changed → refresh attrs → recompute max values

MainView (main_game.tscn)
  MainViewStateMachine/CharacterViewState  scenes/character/character_view_state.gd (BookViewState)
  CharacterView (Control, z_index 3)       scenes/character/character_view.tscn / .gd (MenuBookView, theme book_theme.tres)
    BookLayer (centred, scale 2)
      BookFrame %                          scenes/ui/book_frame/, style character_book_style.tres
      BookContent → TitleBanner "Character" (TabBanner at the inventory's ribbon position)
    PageLayer (centred, screen pixels)
      LeftPage (VBox)
        PhysicalPlaque (LabelBookPlaque) → PhysicalTiles % (GridContainer, 4 columns) → Strength/Body/Agility/ResilienceTile
        SpiritualPlaque → SpiritualTiles % (GridContainer, 4 columns) → Spirit/Foundation/Control/WillpowerTile
      RightPage (VBox)
        DetailPlaque % → DetailCard (PanelBookCard, fills the page): DetailIcon % (64×64), DetailName %,
                         DetailGroup %, DetailValue % (LabelBookValueLarge), DetailDescription % (3 lines, fixed),
                         EffectsSep, EffectsCaption ("Effects"), EffectsLabel %
  AttributeTile (×8, PanelContainer, PanelBookTile, 110×150)  scenes/character/attribute_tile/
    TileVBox → Icon % (64×64), ValueLabel % (LabelBookValueLarge), NameLabel % (LabelBookMuted)
```

## Data Model

### CharacterAttributesData

`scripts/resource_definitions/character/character_attributes_data.gd` defines `class_name CharacterAttributesData extends Resource`.

| Field | Type | Default | `AttributeType` value |
|-------|------|---------|-----------------------|
| `strength` | `float` | `10.0` | `STRENGTH` = 0 |
| `body` | `float` | `10.0` | `BODY` = 1 |
| `agility` | `float` | `10.0` | `AGILITY` = 2 |
| `spirit` | `float` | `10.0` | `SPIRIT` = 3 |
| `foundation` | `float` | `10.0` | `FOUNDATION` = 4 |
| `control` | `float` | `10.0` | `CONTROL` = 5 |
| `resilience` | `float` | `10.0` | `RESILIENCE` = 6 |
| `willpower` | `float` | `10.0` | `WILLPOWER` = 7 |

| Method | Behaviour |
|--------|-----------|
| `_init(strength_value = 10.0, …, willpower_value = 10.0)` | Positional constructor in enum order |
| `get_attribute(type) -> float` | `match` dispatch. Unknown types call `Log.error` and return 0.0 |
| `set_attribute(type, value)` | `match` dispatch |
| `add_to_attribute(type, amount)` | Get, then set, then `Log.info` |
| `get_max_madra() -> float` | `foundation × 10.0`. Shared by `VitalsManager` and `ResourceManager.get_adventure_madra_capacity()` |

The same class is used for enemy stat blocks (`CombatantData.attributes`). Until commit `1ce7ecd` (2026-05-23) the values were stored in a single `attributes` dictionary, and saves from before that change are incompatible (see [PERSISTENCE.md](PERSISTENCE.md#versioning)).

### CharacterManager

| Member | Behaviour |
|--------|-----------|
| `const AttributeType` | Alias of `CharacterAttributesData.AttributeType` |
| `signal base_attribute_changed(attribute_type, new_value)` | Emitted by `add_base_attribute()`, and for all 8 attributes from `_update_resources()` in `_ready()` and on `save_data_reset` |
| `get_total_attributes_data() -> CharacterAttributesData` | Builds a **new** instance each call from `get_strength()` … `get_willpower()` |
| `get_strength()` … `get_willpower() -> float` | `base + _get_attribute_bonuses(type)` |
| `add_base_attribute(type, amount)` | Mutates the saved base value, emits `base_attribute_changed`, and calls `Log.info` |
| `get_gold_multiplier() -> float` | Always `1.0` (a `TODO`) |
| `static get_attribute_display_name(type) -> String` | `"STRENGTH"` becomes `"Strength"`. Used only in log lines |
| `_get_attribute_bonuses(type)` | Equipment only. The TODOs for buffs, cultivation and temporary effects are unimplemented |
| `_get_equipment_bonuses(type)` | Sums `EquipmentDefinitionData.attribute_bonuses[type]` over `InventoryData.equipped_gear` and `equipped_accessories` |

### PlayerManager and VitalsManager

`PlayerManager._ready()` creates `VitalsManager.new()` named `PlayerVitalsManager`, sets `is_player = true`, and adds it as a child. Code reaches it through `PlayerManager.vitals_manager`. None of this state is saved.

| VitalsManager behaviour (player) | Detail |
|----------------------------------|--------|
| Attribute source | On `_ready()`, and on every `CharacterManager.base_attribute_changed`, it sets `character_attributes_data = CharacterManager.get_total_attributes_data()`. That setter recomputes the max values |
| Max values | `max_health = BODY × 10`, `max_stamina = BODY × 5`, `max_madra = FOUNDATION × 10` (defaults 100 / 50 / 100) |
| Adventure start | `AdventureView` calls `initialize_current_values(madra_budget)`: health and stamina go to max, and Madra is set to the drained budget |
| Regen | `stamina_regen = 1.0 × AdventureActionData.stamina_regen_modifier` per second during an adventure, then 0 after it. `health_regen` and `madra_regen` are never set (0) |
| Changes | `apply_vitals_change(health, stamina, madra)` clamps each to `[0, max]`. Callers: adventure movement (−5 stamina per tile, `MOVEMENT_STAMINA_COST`), `ChangeVitalsEffectData`, and combat effects and costs |
| Signals | `health_changed`, `stamina_changed`, `madra_changed` (separate from `ResourceManager.madra_changed`) |

See [COMBAT.md](../combat/COMBAT.md) for how combat uses these.

### Character View nodes

| Node / script | Key members |
|---------------|-------------|
| `CharacterView` (`class_name CharacterView extends MenuBookView`) | `ATTRIBUTE_DETAILS: Dictionary` (per attribute: a description and the `formulas` it feeds, written to match the code); `NO_EFFECTS_TEXT` ("Not yet active"); `refresh()`; `select_attribute(type)` (marks the tile, fills the right page; pointing again at the described attribute does nothing); `get_selected_attribute()`; `_before_open()` selects Strength and refreshes; `_describe_effects()` lists the formulas, then each unlocked ability whose effects scale with the attribute (`CombatEffectData.get_scaling()`); `_tiles_by_type`, filled from the AttributeTile children of `%PhysicalTiles` / `%SpiritualTiles` |
| `AttributeTile` (`class_name AttributeTile`) | Exports `attribute_name: String`, `attribute_type: AttributeType`, `icon_texture: Texture2D` (set per instance to `assets/sprites/ui/attribute_icons/<attr>_icon.png`, 32 px art stored at 2×, shown at 64). `set_value(float)` writes `"%.0f"`. Signal `hovered(tile)`. `set_selected(bool)` swaps between `PanelBookTile` and the tinted `PanelBookTileSelected` |
| `CharacterViewState` (`class_name CharacterViewState extends BookViewState`) | View `character_view`; closes on `ui_cancel`, `open_character`, the close tab or a backdrop click |

## Core Systems and Flows

### Total attributes

```
get_total_attributes_data()
  for each of the 8 attributes:
    base  = live_save_data.character_attributes.get_attribute(type)
    bonus = Σ attribute_bonuses[type] over equipped_gear + equipped_accessories
  return CharacterAttributesData.new(totals…)       # fresh object, nothing cached
```

These are not included in totals:

- Path `ATTRIBUTE_BONUS` perks. `PathManager` aggregates them, but nothing reads them.
- Combat buffs, which `CombatBuffManager` applies to combat attributes only.
- Cultivation stage bonuses.

### Derived stats

| Stat | Formula | Computed in |
|------|---------|-------------|
| Max Health | `BODY × 10` | `VitalsManager.max_health_for()` (static; `_get_max_health()` returns it) |
| Max Stamina | `BODY × 5` | `VitalsManager._get_max_stamina()` |
| Max combat Madra | `FOUNDATION × 10` | `CharacterAttributesData.get_max_madra()` |
| Adventure Madra capacity / threshold | `FOUNDATION × 10` / 50% of that | `ResourceManager` (see [RESOURCES.md](RESOURCES.md)) |
| Ability value | `base_value + Σ(attribute × *_scaling)` | `CombatEffectData.calculate_value()` |
| Damage taken | `damage × 100 / (100 + defense)`. Defense is RESILIENCE for PHYSICAL, SPIRIT for SPIRIT, `(RESILIENCE + WILLPOWER) / 2` for MIXED, and none for TRUE | `CombatEffectData.calculate_damage()` |
| Vitals effects | `health_change + BODY × body_hp_multiplier`; `madra_change + FOUNDATION × foundation_madra_multiplier` | `ChangeVitalsEffectData` |
| Gold multiplier | `1.0` | `CharacterManager.get_gold_multiplier()` |

### Attribute usage

| Attribute | What reads it today | Gear granting it |
|-----------|---------------------|------------------|
| STRENGTH | `strength_scaling` (Basic Strike ×1.0) | Iron Shortsword +5, Makeshift Dagger +3, Dreadbeast Tooth Necklace +2 |
| BODY | Max Health, Max Stamina, `body_hp_multiplier` | Reinforced Robes +4, Scripted Bark +2 |
| AGILITY | `agility_scaling` (Basic Strike ×0.5, Empty Palm ×0.3) | Iron Shortsword +2, Makeshift Dagger +2, Dreadbeast Tooth Necklace +2 |
| SPIRIT | `spirit_scaling` (Empty Palm ×1.0, Power Font ×1.5), SPIRIT-damage defense | Cultivator's Cowl +1. Base: Aura Well training +1 per level |
| FOUNDATION | Max combat Madra, adventure capacity, `foundation_scaling` (Power Font ×0.5), `foundation_madra_multiplier` | Leeching Ring +2 |
| CONTROL | Nothing (no ability sets `control_scaling`) | Leeching Ring +2 |
| RESILIENCE | PHYSICAL defense, half of MIXED defense | Reinforced Robes +2 |
| WILLPOWER | Half of MIXED defense | Cultivator's Cowl +3 |

`UnlockConditionData` `ATTRIBUTE_VALUE` conditions compare the total attributes. The only content using one is `test_attribute_requirement_unlock_data` (BODY >= 20).

### Base attribute award

```
TrainingActionData.effects_on_level (Aura Well) → AwardAttributeEffectData.process()
  → CharacterManager.add_base_attribute(SPIRIT, 1.0)
      → character_attributes.add_to_attribute()       (saved at the next SaveTimer tick)
      → base_attribute_changed.emit(SPIRIT, new_value)
          → PlayerVitalsManager refreshes its attributes and max values
```

### Opening and closing the Character View

```
C key / dock Character button (SystemMenuButton MenuType.CHARACTER → Input.parse_input_event(open_character), then its release)
  → MainView._unhandled_input → ZoneViewState.handle_input("open_character")
  → MainView.push_state(character_view_state) → CharacterViewState.enter()
  → GreyBackground.show_with_panel(character_view) → CharacterView.animate_open()
      → _before_open(): select_attribute(STRENGTH), refresh() reads
        CharacterManager.get_total_attributes_data() → each AttributeTile.set_value()
      → BookFrame open animation → pages shown

C / Esc / close tab / click outside the book (top state is CharacterViewState)
  → BookViewState._request_close() → GreyBackground.hide_with_panel(character_view)
  → CharacterView.animate_close() → pages hidden, book closes → close_finished
  → grey fade-out and book close both finished → both hidden → panel_hidden → MainView.pop_state()
  → CharacterViewState.exit() (BookViewState) disconnects the close tab and the backdrop click
```

Values are read only when the book opens. Nothing updates them while it is open. The log and the Goals board stay showing under the backdrop. The state machine, `GreyBackground` and the dock are documented in [MAIN_VIEW.md](MAIN_VIEW.md).

## Integration Points

| System | Connection |
|--------|------------|
| PersistenceManager | `SaveGameData.character_attributes` holds the base values. `save_data_reset` triggers `_update_resources()` |
| InventoryManager | `_get_equipment_bonuses()` reads `get_inventory().equipped_gear` / `equipped_accessories`. CharacterManager does not listen to `inventory_changed` |
| ResourceManager | `get_adventure_madra_capacity()` uses the total Foundation (see [RESOURCES.md](RESOURCES.md)) |
| AdventureCombat | Snapshots `get_total_attributes_data()` into the player `CombatantData` at combat start, and passes `PlayerManager.vitals_manager` as the player's external vitals |
| AdventureView / AdventureTilemap | Initialize vitals with the Madra budget, set stamina regen, spend 5 stamina per move, and read health for the end card |
| ChangeVitalsEffectData | Reads total BODY and FOUNDATION and applies the result to `PlayerManager.vitals_manager` (encounters, consumables) |
| AwardAttributeEffectData | The only caller of `add_base_attribute()` (see [EFFECTS.md](EFFECTS.md)) |
| UnlockConditionData | `ATTRIBUTE_VALUE` conditions read totals. UnlockManager does not listen to `base_attribute_changed`, so these conditions are only re-checked when another signal fires (Madra, gold, event, cultivation) |
| AbilitiesView, `TechniqueTooltip` | Damage previews from `get_total_attributes_data()` (see [ABILITIES.md](../abilities/ABILITIES.md)) |
| AbilityManager | The Effects card lists the unlocked abilities that scale with the attribute |
| PathManager | `PathEffectsSummary.attribute_bonuses` is computed but not consumed |
| MainView / GreyBackground / Dock | Host the Character View and drive its modal flow |

## Existing Content

- **Attribute icons:** `assets/sprites/ui/attribute_icons/{strength,body,agility,spirit,foundation,control,resilience,willpower}_icon.png` (32 px art stored at 2×). The original Control art sits 6 px right of centre, so the books use `control_icon_ai.png`, a re-centred copy; the original is unchanged. The Abilities book's damage breakdown uses them too. The dock's Character button uses `assets/sprites/ui/system_menu/character_icon.png`, shown at 32x32.
- **Gear with attribute bonuses:** the 7 items in `resources/items/equipment/spirit_valley/`, listed in the attribute-usage table above. Most of them cannot be obtained on `main`:
  - The Dreadbeast Tooth Necklace is in the Ravenous Dreadbeast elite encounter's loot table.
  - The Makeshift Dagger and Iron Shortsword appear only in `test_loot_table_weapon.tres`, which is used only by the unreferenced `test_treasure_encounter.tres`.
  - Nothing references the Cultivator's Cowl, Leeching Ring, Reinforced Robes or Scripted Bark resources.
  - There is no starting gear, and the old NPC dagger award was removed in `d934de4` (2026-04-19).

  See [ITEMS.md](../inventory/ITEMS.md).
- **Base-attribute awards:** `resources/zones/spirit_valley_zone/zone_actions/aura_well_spirit_award_effect.tres` (SPIRIT, amount 1.0).

## Key Files

| File | Purpose |
|------|---------|
| `singletons/character_manager/character_manager.gd` | Base and total attributes, equipment bonuses |
| `scripts/resource_definitions/character/character_attributes_data.gd` | Attribute storage, `get_max_madra()` |
| `singletons/player_manager/player_manager.gd` | Creates the persistent player `VitalsManager` |
| `scenes/combat/combatant/vitals_manager/vitals_manager.gd` | Max values, regen, clamped vitals changes |
| `scripts/resource_definitions/effects/award_attribute_effect_data.gd` | Data-driven base-attribute award |
| `scenes/character/character_view.tscn` / `.gd` | Character book and the attribute details text |
| `scenes/character/character_view_state.gd` | Modal state (`BookViewState`) |
| `scenes/character/attribute_tile/attribute_tile.tscn` / `.gd` | Tile subscene |
| `tests/integration/test_character_book.gd` | Tiles four to a row, right page follows hover, opens on Strength, values from `CharacterManager`, effects share the details pane and stay put, match the code and list only unlocked abilities, pages wait for the open book |
| `scenes/ui/main_view/states/zone_view_state.gd` | Pushes `CharacterViewState` on `open_character` |
| `tests/unit/test_character_attributes_data.gd` | `get_max_madra()` (3 tests) |
| `tests/unit/test_character_manager.gd` | 28 tests: `CharacterAttributesData` getters, and the real `get_total_attributes_data()` with gear, both accessory slots, stacking and negative bonuses, equip/unequip through `InventoryManager`, and `add_base_attribute()` with its signal |
| `tests/unit/test_award_attribute_effect_data.gd` | `AwardAttributeEffectData` → `add_base_attribute()` against the real singleton |
| `tests/unit/test_change_vitals_effect_data.gd` | BODY / FOUNDATION scaling through the real `get_total_attributes_data()` |

Design history: [character view spec](../superpowers/specs/2026-04-16-character-view-design.md) and [plan](../superpowers/plans/2026-04-16-character-view.md). Shipped on 2026-04-16 with the deviations listed under Work Remaining.

## Work Remaining

### Bugs

- `[LOW]` The Effects card's formula lines are still hand-written (`ATTRIBUTE_DETAILS.formulas`), matched to `VitalsManager`, `get_max_madra()` and `calculate_damage()` as of 2026-10-21. A change to those formulas needs the text changed too. The ability lines are read from the ability data.
- `[MEDIUM]` The player's maximum vitals ignore equipment changed during a session. `PlayerVitalsManager` refreshes its attributes only on `base_attribute_changed`, and equipping or unequipping gear never emits it.
  - Equipping Reinforced Robes (+4 BODY) leaves max health at 100 until a base attribute changes or the game restarts.
  - With Leeching Ring (+2 FOUNDATION), `ResourceManager.get_adventure_madra_capacity()` allows a 120 budget, but `VitalsManager.max_madra` stays at 100, so the extra 20 is clamped away on the first combat Madra change.

  Refresh on `InventoryManager.inventory_changed` (or add a total-attributes-changed signal), or refresh at adventure start.
- `[LOW]` The Character View doesn't update while open. The spec called for a `base_attribute_changed` connection. Values refresh only in `animate_open()`, so an Aura Well level-up gained while the panel is open isn't shown.

### Missing Functionality

- `[HIGH]` The attribute system needs a design pass. CONTROL has no effect at all (no ability uses `control_scaling`, and nothing reduces cooldowns). WILLPOWER only feeds MIXED defense, and no MIXED-damage ability exists. AGILITY has no role beyond scaling. The combat side is tracked in [COMBAT.md](../combat/COMBAT.md); attributes are owned here.
- `[MEDIUM]` Path `ATTRIBUTE_BONUS` perks are not applied. `_get_attribute_bonuses()` sums equipment only, and `PathEffectsSummary.attribute_bonuses` is never read. No current Pure Madra node uses `ATTRIBUTE_BONUS`, so nothing visible is lost yet.
- `[MEDIUM]` The Character View shows totals only. It has no base/gear breakdown, no equipped-gear summary, no cultivation stage or Core Density, and no derived stats (HP, stamina, Madra capacity). The spec left these out of scope.
- `[MEDIUM]` `CharacterManager.get_gold_multiplier()` always returns `1.0`.
- `[LOW]` `_get_attribute_bonuses()` has unimplemented TODOs for buffs, cultivation techniques and temporary effects.

### UI

- `[LOW]` The details card fills the right page but its effects are often a line or two. Derived totals (Max Health, Max Madra, Max Stamina) as numbers would fit there; not built.

### Tech Debt

- `[MEDIUM]` Nothing tests the `PlayerManager` / `VitalsManager` refresh on `base_attribute_changed`.
- `[LOW]` `get_total_attributes_data()` allocates a new resource on every call, and every consumer polls it. A cached total plus a change signal would also fix the vitals bug above.
- `[LOW]` Several doc comments are stale:
  - The `CharacterManager` class comment says it computes "health, madra, and combat stats", but it doesn't.
  - The `AttributeType` comments promise mechanics that don't exist: AGILITY "evasion, cooldown reduction", FOUNDATION "regeneration", CONTROL "madra cost reduction", WILLPOWER "technique power".
  - The CONTROL description in `ATTRIBUTE_DETAILS` says "reduce ability cooldowns", which contradicts the enum comment.
- `[LOW]` `CharacterManager._update_resources()` is named after the ResourceManager pattern but only re-emits attributes. `get_total_attributes_data()` has no `##` doc comment, and the locals in the getters and `_update_resources()` are untyped (`var base = …`).
- `[LOW]` `PlayerManager` has no class doc. The player `VitalsManager` connects `base_attribute_changed` through an untyped lambda in `_ready()`.
