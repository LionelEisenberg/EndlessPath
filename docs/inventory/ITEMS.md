# Items

> **Source-of-truth catalog for equipment content in EndlessPath.**
>
> The generator reads the **Equipment** tables below and writes one `.tres` per row under `resources/items/equipment/<zone>/`. Its command runs `scripts/tools/items_md_to_resources.gd`, which loads the worker, `scripts/tools/items_md_generator.gd`, once the autoloads exist; the worker parses the tables with `ItemsMdParser` (`scripts/tools/items_md_parser.gd`). Re-running it overwrites the generated fields in those files (`item_id`, `item_name`, `description`, `slot_type`, `stat_percent_bonuses`, `stat_bonus_floor`, `armor`, `ward`, `base_value`, `icon`). **Edit equipment here, not in the `.tres`.**
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
| `stats` | `stat_percent_bonuses` (Dictionary[StringName, float]), `stat_bonus_floor`, `armor`, `ward` | Inline DSL, see below |
| `tier` | — (doc-only) | `Foundation` / `Copper` / `Iron` / … — used by designer for balance grouping |
| `cost` | `base_value` | Gold value, and the merchant's buy price (`MerchantStockEntry.get_price()` rounds it). A future sell-back will derive from it. Prices are starting values; see [Merchant v1](../superpowers/specs/2026-10-19-merchant-v1-design.md#starting-values-and-test-plan) |
| `identity` | — (doc-only) | One short phrase capturing design intent |
| `source` | — (doc-only) | Where the item appears in the loop; comma-sep when multi-source |
| `description` | `description` | Player-facing flavor |
| `icon` *(opt)* | `icon` (Texture2D) | Not supported yet — the generator ignores this column and always uses `res://assets/sprites/items/equipment/<id>.png` |

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

### Spirit Valley

| # | id | name | slot | stats | tier | cost | identity | source | description |
|---|----|------|------|-------|------|------|----------|--------|-------------|
| E1 | makeshift_dagger | Makeshift Dagger | MAIN_HAND | STRENGTH+30%, AGILITY+10%, FLOOR+2 | Foundation | 60 | Starter weapon | Merchant | A simple iron blade, well-balanced for a beginner. |
| E2 | iron_shortsword | Iron Shortsword | MAIN_HAND | STRENGTH+50%, AGILITY+10%, FLOOR+2 | Foundation | 150 | Dagger upgrade | Merchant | A heavier blade, demanding both hands. |
| E3 | cultivators_cowl | Cultivator's Cowl | HEAD | SPIRIT+15%, WARD+4 | Foundation | 40 | First HEAD slot — mental focus | Merchant | A felted cowl, traditional among initiate cultivators. |
| E4 | reinforced_robes | Reinforced Robes | ARMOR | BODY+40%, ARMOR+6 | Foundation | 180 | First ARMOR slot — survivability | Merchant | Padded robes lined with light scripted plates. |
| E5 | dreadbeast_tooth_necklace | Dreadbeast Tooth Necklace | ACCESSORY | STRENGTH+20%, AGILITY+20% | Foundation | 0 | Physical Offense | Loot | A small dreadbeast tooth, fashioned around a leather strap. |
| E6 | leeching_ring | Leeching Ring | ACCESSORY | MIND+20%, CONTROL+20% | Foundation | 120 | Cooldown + max mana | Merchant, Loot | A polished metal band engraved with a single character. |
| E7 | scripted_bark | Scripted Bark | OFF_HAND | BODY+20% | Foundation | 75 | First offhand slot, played with makeshift dagger dropped by first mob seen | Merchant, Loot | A small scripted piece of bark, not much but will take a hit or two |

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

The generator covers the **Equipment** section only. It was implemented on 2026-05-22 and is made of:

- `scripts/tools/items_md_to_resources.gd`, the headless CLI script (`extends SceneTree`) the command runs with `-s`. Godot compiles a `-s` script, with every class it names, before it registers the autoloads, and the item classes reach code that reads an autoload, so this script names no game class. Once the run has started and the autoloads exist, it loads the worker and runs it.
- `scripts/tools/items_md_generator.gd`, the worker: it reads this doc, checks every row and writes the files.
- `ItemsMdParser` in `scripts/tools/items_md_parser.gd`, a set of static helpers unit-tested in `tests/unit/test_items_md_parser.gd`. The worker parses the tables with it.

### Invocation

```bash
"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s scripts/tools/items_md_to_resources.gd
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
| Unknown `slot` literal, an empty `id` / `name` / `slot` / `description`, or a bad stats token | Run aborts before anything is written, naming the row |

The generated fields are `item_id`, `item_name`, `description`, `slot_type`, `stat_percent_bonuses`, `stat_bonus_floor`, `armor`, `ward`, `base_value` and `icon`. `item_type` comes from `EquipmentDefinitionData._init()`. Generated files carry no "do not edit" marker.

In May 2026 the UIDs injected into newly created files caused "invalid UID" warnings and had to be stripped (b658264). After a run that creates files, open the project in the editor and check for UID warnings before committing.

### Migration (done)

The legacy `resources/items/test_items/` resources were migrated on 2026-05-22 (d414981):

- `dagger.tres` → `makeshift_dagger.tres`
- `sword.tres` → `iron_shortsword.tres`
- `dagger_instance.tres` was deleted because nothing referenced it
- the `test_items/` folder was removed
