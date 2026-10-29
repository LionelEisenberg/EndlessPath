# Stat modifier layer: design

The player's numbers come from several places: base attributes in the save, gear, and soon path perks, elixirs and scripts. Each of those should be able to raise a stat without knowing who else does. This round builds that layer and moves gear onto it. It also gives the three derived vitals (max Health, max Stamina, max Madra) one home, so their formulas exist once. Nothing the player sees changes.

## Why

Today `CharacterManager` adds gear bonuses to base attributes in eight copy-pasted getters, with TODOs for the other sources. The derived formulas are scattered:

- Body × 10 lives in `VitalsManager.max_health_for()`.
- Body × 5 lives in `VitalsManager._get_max_stamina()`.
- Foundation × 10 lives in `CharacterAttributesData.get_max_madra()`.
- The character sheet copies all three by hand as text.

Seven path perks are inert because nothing reads them, and the elixirs and scripts in `docs/planned/` will need the same thing: one place a bonus goes in and every reader sees it.

The gear fix on this branch (gear now raises the player's max vitals) made one thing clear. A cached bonus is only as fresh as the signals that refresh it, and `InventoryManager` emits nothing when a save loads or resets. So the layer asks each source for its bonuses at the moment a stat is read.

## Decisions

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Scope | The layer plus one home for the derived vitals; gear moves onto it; nothing visible changes | Smallest step that gives the next pass (path perks) a real place to plug in | — |
| Gear fix | Stays on this branch, one PR | The layer builds on its signal and replaces its code | — |
| What a modifier can target | The eight attributes and the three derived vitals, in one `Stat` enum | One dropdown for designers later; a modifier can raise Body or max Health directly | the path-perk pass adds game stats (Madra generation, Core Density XP, …) to the same enum |
| Stacking | Additive: `(base + sum of flat) × (1 + sum of percent)`; percent `0.1` is +10% | Reads cleanly on a sheet ("+30%"), linear within a stat (user's choice) | a source should compound on purpose |
| Order | Attribute modifiers → derived formula → derived-stat modifiers | A Body bonus raises max Health through the formula; a max Health bonus adds after it | — |
| Freshness | Pull: each source is a provider asked at read time | No cache to invalidate; immune to autoload and save-reset ordering | reads become hot (per frame) |
| Where it lives | `CharacterManager` owns a `StatModifierStack`; no new singleton | `CharacterManager` already owns totals and is early in autoload order | — |
| Derived formulas' home | `CharacterAttributesData`, beside `get_max_madra()` | Pure functions of attributes; enemies and the player share them | — |
| Gear data | Unchanged; `attribute_bonuses` becomes flat modifiers at read time | No `.tres` churn | gear should grant non-attribute bonuses |
| Save | Nothing new saved | Gear is already saved; totals stay derived | timed buffs (elixirs) need saving |
| Combat buffs | Stay fight-local in `CombatBuffManager` | They work, and last one fight | an elixir must reach into a fight |
| Change signal | `CharacterManager.total_attributes_changed` is renamed `stats_changed` | A max Health modifier changes no attribute, yet listeners must hear it | — |

### Conflict with the GodotPrompter pattern

The `ability-system` skill's `StatSet` compounds multipliers (`running *= 1 + value` per modifier), keeps an OVERRIDE pass, and stores modifiers pushed by their owners. This design follows the user's additive rule, drops OVERRIDE (no user), and pulls from providers. Pushing would need every owner to refresh the layer on every change, including save resets, which this codebase does not signal reliably.

## The design

### `StatModifierData` (Resource)

`scripts/resource_definitions/character/stat_modifier_data.gd`. One bonus to one stat.

- `enum Stat { STRENGTH, BODY, AGILITY, SPIRIT, FOUNDATION, CONTROL, RESILIENCE, WILLPOWER, MAX_HEALTH, MAX_STAMINA, MAX_MADRA }`. The first eight share their names with `AttributeType`. They are mapped by name, not by position.
- `enum Kind { FLAT, PERCENT }`
- `stat`, `kind`, `value` exports. For PERCENT, `0.1` is +10%.
- `for_attribute(attribute) -> Stat` and `attribute_of(stat) -> int` (−1 for a derived vital) map between the enums.

It is a Resource so a later elixir or script definition can list its modifiers in the Inspector.

### `StatModifierStack` (RefCounted)

`singletons/character_manager/stat_modifier_stack.gd`. It holds named sources. A source is a `Callable` that returns `Array[StatModifierData]`.

- `set_source(source, provider)` adds or replaces a source.
- `remove_source(source)` removes it.
- `apply(stat, base) -> float` asks every source, keeps the modifiers for `stat`, and returns `(base + Σflat) × (1 + Σpercent)`. A source whose callable is no longer valid (its owner was freed) is skipped.

### Derived vitals

`CharacterAttributesData` gets the constants `HEALTH_PER_BODY = 10.0`, `STAMINA_PER_BODY = 5.0` and `MADRA_PER_FOUNDATION = 10.0`, and three getters:

- `get_max_health()`
- `get_max_stamina()`
- `get_max_madra()` (existing)

`VitalsManager.max_health_for()` and its private formula helpers go away. An enemy's `VitalsManager` computes its maxima from its own attributes through these getters. The character sheet builds "Max Health = Body × 10", "Max Stamina = Body × 5" and "Max Madra = Foundation × 10" from the constants, so the text cannot drift from the code.

### `CharacterManager`

- It owns one `StatModifierStack`, with the `&"gear"` source registered at `_ready`. The gear source reads equipped gear and accessories from `CharacterManager`'s own `live_save_data`, not through `InventoryManager`. So during a save reset, it already sees the new save.
- `get_stat(stat) -> float` is the one read:
  - For an attribute, it is the base from the save with the attribute's modifiers.
  - For a derived vital, it is the formula over the total attributes, with the vital's modifiers.
- `get_total_attributes_data()` keeps its signature and is built from `get_stat()`. Combat's fight-start snapshot, ability previews and unlock conditions keep working unchanged.
- `set_modifier_source(source, provider)` and `remove_modifier_source(source)` are the entry point for the next sources (path perks, elixirs). Each one emits `stats_changed`.
- `stats_changed` fires after a base attribute changes, after any inventory change, after a save reset, and after a source is set or removed.
- The eight per-attribute getters and the equipment-summing helpers are removed. Nothing outside `CharacterManager` calls them.

### Readers

- **The player's `VitalsManager`** takes its maxima from `get_stat(MAX_HEALTH / MAX_STAMINA / MAX_MADRA)` on `stats_changed`. It no longer sets `character_attributes_data`, which the existing `_ready` warning already says a player manager should not have.
- **`ResourceManager.get_adventure_madra_capacity()`** reads `get_stat(MAX_MADRA)`. The adventure capacity and the in-adventure max Madra stay one number.
- **`AdventurePresenter`** listens to `stats_changed`.

## Non-goals

- Wiring the seven path perks. That is the next pass, and it adds game stats to `Stat`.
- The zone Madra cap (`CultivationManager.get_max_madra()`), which comes from the cultivation stage and is a different number from the adventure capacity.
- Timed modifiers (elixirs, scripts) and saving them.
- Showing on the character sheet where a number comes from.
- Clamping. A negative total is possible only from negative bonuses, as it is today.

## Anti-goals

- **A number the player sees changes.** This covers max Health, Stamina and Madra in and out of fights, the adventure card's capacity and threshold, attribute tiles, ability previews and the character sheet's formula lines.
- **Gear stops counting somewhere it counts today**, in particular right after loading a save or switching dev presets.
- **An enemy's vitals pick up the player's modifiers.**

## Docs to update after the merge

- `docs/infrastructure/CHARACTER.md`:
  - totals come from the modifier layer; describe `get_stat()`, the `Stat` enum, `stats_changed`, sources, the additive stacking rule and its order;
  - derived vitals live on `CharacterAttributesData`;
  - the InventoryManager dependency row: `CharacterManager` reads equipped gear from its own save and listens to `inventory_changed`;
  - drop the player-vitals-ignore-gear bug.
- `docs/infrastructure/RESOURCES.md`:
  - the adventure capacity rows cite `CharacterManager.get_stat(MAX_MADRA)`;
  - the file table lists `CharacterAttributesData`'s three vitals getters.
- `docs/combat/COMBAT.md`:
  - the vitals table cites `CharacterAttributesData.get_max_health()` / `get_max_stamina()` / `get_max_madra()` and the player's `get_stat()`;
  - the test-gaps line no longer names `max_health_for()`;
  - drop the gear bug.
- `docs/adventuring/ADVENTURING.md`: the Here tray paragraph and the "No enemy Health before a fight" item cite `CharacterAttributesData.get_max_health()` instead of `VitalsManager.max_health_for()`.
- `docs/cultivation/CULTIVATION.md`: the adventure capacity row reads `CharacterManager.get_stat(MAX_MADRA)`.
- `docs/zones/ZONES.md`:
  - the `AdventurePresenter` row refreshes on `CharacterManager.stats_changed`;
  - the adventure-start paragraph cites `get_stat(MAX_MADRA)`.
- `docs/planned/SOULSMITHING.md`: the stats pipeline is the modifier layer's gear source (`EquipmentDefinitionData.get_stat_modifiers()`), not `_get_attribute_bonuses()`.
- `docs/progression/PATH_PROGRESSION.md`, Work Remaining: perks plug in as a modifier source.
- `docs/STATE_OF_THE_GAME.md` and `docs/CODEBASE_STATE.md` (at the next milestone refresh): remove "Player max vitals ignore equipment".

Historical records (`docs/inventory/EQUIPMENT_IMPLEMENTATION_PLAN.md`, `docs/testing/TEST_SUITE_PROMPT.md`) keep their old names.
