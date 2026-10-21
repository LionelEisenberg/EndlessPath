# Items

Last updated: 2026-10-19

> **Source-of-truth catalog for equipment content in EndlessPath.**
>
> The generator `scripts/tools/items_md_to_resources.gd` reads the **Equipment** tables below, using `scripts/tools/items_md_parser.gd`. It writes one `.tres` per row under `resources/items/equipment/<zone>/`. Re-running it overwrites the generated fields in those files (`item_id`, `item_name`, `description`, `slot_type`, `attribute_bonuses`, `base_value`, `icon`). **Edit equipment here, not in the `.tres`.**
>
> Materials, consumables and quest items are not generated yet. They are hand-authored `.tres` files; see their sections below.
>
> See [INVENTORY.md](INVENTORY.md) for the UI and storage system, where each item comes from in game, and current content values. See [EQUIPMENT_DESIGN.md](EQUIPMENT_DESIGN.md) for equipment design intent and tier guidelines.

---

## How this doc works

- Items are organized by **type** (top-level `##` sections) and **introducing zone** (`###` subsections).
- Each `(type × zone)` combination gets one markdown table.
- `tier` is a column inside each table rather than a section of its own, so one zone can hold items from several tiers as the game grows.
- The `#`, `tier`, `identity` and `source` columns are **doc-only** designer reference, and the generator ignores them. The other columns map directly to `.tres` fields.
- Icons always load from `res://assets/sprites/items/equipment/<id>.png`. The generator aborts the run if that file is missing. An `icon` override column is not supported yet.
- Parser rules (`ItemsMdParser.parse_equipment_sections`):
  - Only tables under the `## Equipment` heading are read.
  - Each `### <Zone>` heading becomes the output folder: lower-cased, with spaces turned into `_` (`Spirit Valley` → `spirit_valley`).
  - A table is a roster only if its header row has both an `id` and a `slot` column.
  - A blank line ends a table.
  - Renaming `## Equipment` or a zone heading changes what gets generated. Renaming a zone leaves the old folder's files behind as orphans.

---

## Equipment

### Schema

| Column | Maps to | Notes |
|---|---|---|
| `#` | — | Row index for human reference ("let's bump E5"); not generated |
| `id` | `item_id` | snake_case; becomes filename `<id>.tres` |
| `name` | `item_name` | Player-facing display name |
| `slot` | `slot_type` (EquipmentSlot enum) | One of `MAIN_HAND` / `OFF_HAND` / `HEAD` / `ARMOR` / `ACCESSORY` |
| `stats` | `attribute_bonuses` (Dictionary[AttributeType, float]) | Inline DSL, see below |
| `tier` | — (doc-only) | `Foundation` / `Copper` / `Iron` / … — used by designer for balance grouping |
| `cost` | `base_value` | Gold value, and the merchant's buy price (`MerchantStockEntry.get_price()` rounds it). A future sell-back will derive from it. Prices are starting values; see [Merchant v1](../superpowers/specs/2026-10-19-merchant-v1-design.md#starting-values-and-test-plan) |
| `identity` | — (doc-only) | One short phrase capturing design intent |
| `source` | — (doc-only) | Where the item appears in the loop; comma-sep when multi-source |
| `description` | `description` | Player-facing flavor |
| `icon` *(opt)* | `icon` (Texture2D) | Not supported yet — the generator ignores this column and always uses `res://assets/sprites/items/equipment/<id>.png` |

### Stats DSL

Format: `<ATTR>[+-]<N>, ...`

- Attribute literals match the `AttributeType` enum exactly: `STRENGTH`, `BODY`, `AGILITY`, `SPIRIT`, `FOUNDATION`, `CONTROL`, `RESILIENCE`, `WILLPOWER`.
- Values are integers (stored as float in the resource).
- Empty stats cell = empty `attribute_bonuses` dictionary.
- An unknown attribute, or a token with no `+`/`-`, logs an error, and the item is written with **empty** `attribute_bonuses`. The run does not abort, so check the generator output for errors.

**Foundation tier authoring guidelines** (per [EQUIPMENT_DESIGN.md](EQUIPMENT_DESIGN.md)):
- 1-2 attribute bonuses per item
- Values in the `+1` to `+5` range
- Simple, clear identity — a sword gives `STRENGTH`, a helm gives `WILLPOWER`

### Spirit Valley

| # | id | name | slot | stats | tier | cost | identity | source | description |
|---|----|------|------|-------|------|------|----------|--------|-------------|
| E1 | makeshift_dagger | Makeshift Dagger | MAIN_HAND | STRENGTH+3, AGILITY+2 | Foundation | 60 | Starter weapon | Merchant | A simple iron blade, well-balanced for a beginner. |
| E2 | iron_shortsword | Iron Shortsword | MAIN_HAND | STRENGTH+5, AGILITY+2 | Foundation | 150 | Dagger upgrade | Merchant | A heavier blade, demanding both hands. |
| E3 | cultivators_cowl | Cultivator's Cowl | HEAD | WILLPOWER+3, SPIRIT+1 | Foundation | 40 | First HEAD slot — mental focus | Merchant | A felted cowl, traditional among initiate cultivators. |
| E4 | reinforced_robes | Reinforced Robes | ARMOR | BODY+4, RESILIENCE+2 | Foundation | 180 | First ARMOR slot — survivability | Merchant | Padded robes lined with light scripted plates. |
| E5 | dreadbeast_tooth_necklace | Dreadbeast Tooth Necklace | ACCESSORY | STRENGTH+2, AGILITY+2 | Foundation | 0 | Physical Offense | Loot | A small dreadbeast tooth, fashioned around a leather strap. |
| E6 | leeching_ring | Leeching Ring | ACCESSORY | CONTROL+2, FOUNDATION+2 | Foundation | 120 | Cooldown + max mana | Merchant, Loot | A polished metal band engraved with a single character. |
| E7 | scripted_bark | Scripted Bark | OFF_HAND | BODY+2 | Foundation | 75 | First offhand slot, played with makeshift dagger dropped by first mob seen | Merchant, Loot | A small scripted piece of bark, not much but will take a hit or two |

---

## Materials

> **Not yet captured in this doc, and not generated.** The two materials are hand-authored `.tres` files in `resources/items/materials/`:
>
> - `spirit_fern.tres`, `item_id` `SpiritFern`
> - `dewdrop_tear.tres`, `item_id` `DewdropTear`
>
> Their ids are PascalCase while every other item uses snake_case, so bringing materials into this doc first needs a decision on renaming them. Current values are in [INVENTORY.md → Existing Content](INVENTORY.md#materials).

---

## Consumables

> **Not yet captured in this doc, and not generated.** Both consumables are hand-authored `ConsumableDefinitionData` files in `resources/items/consumables/`:
>
> - `crude_scale.tres` (Crude Scale)
> - `barely_coalesced_scale.tres` (Barely Coalesced Scale)
>
> The two files hold the same effect (+20 Madra, 10 s cooldown). Crude Scale's base value is 10, its merchant price; Barely Coalesced Scale's is 1. Only Crude Scale has an icon. See [INVENTORY.md → Existing Content](INVENTORY.md#consumables).

---

## Quest items

> **Not yet captured in this doc, and not generated.** The only quest item is `resources/items/quest_items/refugee_camp_map.tres` (`QuestItemDefinitionData`).

---

## Generator

The generator covers the **Equipment** section only. It was implemented on 2026-05-22 and has two parts:

- `scripts/tools/items_md_to_resources.gd`, a headless CLI script (`extends SceneTree`)
- `ItemsMdParser` in `scripts/tools/items_md_parser.gd`, a set of static helpers unit-tested in `tests/unit/test_items_md_parser.gd`

### Invocation

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s scripts/tools/items_md_to_resources.gd
```

Run it from the project root. It prints `ItemsMdGenerator: created=N updated=N skipped=N orphans=N`, then one `orphan: <path>` line per orphan. It exits with 0 on success and 1 on a fatal error.

### Folder layout (current output)

```
resources/items/
  equipment/
    spirit_valley/
      makeshift_dagger.tres
      iron_shortsword.tres
      cultivators_cowl.tres
      reinforced_robes.tres
      dreadbeast_tooth_necklace.tres
      leeching_ring.tres
      scripted_bark.tres
```

Icons are read from `assets/sprites/items/equipment/<id>.png`; all seven exist.

### Behavior

| Case | Behavior |
|---|---|
| `.tres` exists and its generated fields match the doc | Skipped (no rewrite) |
| `.tres` exists and any generated field differs | The loaded resource is updated in place and re-saved with `ResourceSaver.save()`. Its UID and non-generated fields are kept |
| `.tres` missing | Created. The tool then injects a fresh `uid="..."` into the file header |
| `.tres` in `resources/items/equipment/<zone>/` with no matching row | Reported as an orphan and never deleted. The `--delete-orphans` flag is not implemented |
| Icon file missing | Run aborts before anything is written, naming the path |
| Two rows share an id (across all zones) | Run aborts before anything is written |
| Unknown `slot` literal, or an empty `id` / `name` / `slot` / `description` | Run aborts. Files already written in this run stay written |
| Invalid stats DSL | An error is logged and the item is written with empty `attribute_bonuses`. The run continues and exits 0 |

The generated fields are `item_id`, `item_name`, `description`, `slot_type`, `attribute_bonuses`, `base_value` and `icon`. `item_type` comes from `EquipmentDefinitionData._init()`. Generated files carry no "do not edit" marker.

In May 2026 the UIDs injected into newly created files caused "invalid UID" warnings and had to be stripped (b658264). After a run that creates files, open the project in the editor and check for UID warnings before committing.

### Migration (done)

The legacy `resources/items/test_items/` resources were migrated on 2026-05-22 (d414981):

- `dagger.tres` → `makeshift_dagger.tres`
- `sword.tres` → `iron_shortsword.tres`
- `dagger_instance.tres` was deleted because nothing referenced it
- the `test_items/` folder was removed
