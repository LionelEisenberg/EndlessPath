# Items

> **Source-of-truth catalog for item content in EndlessPath.**
>
> Tables below define every item in the game. A planned generator script (`scripts/tools/items_md_to_resources.gd`) reads these tables and writes the corresponding `.tres` files under `resources/items/<type>/<zone>/`. **Direct edits to generated `.tres` files will be overwritten on next run** — edit here instead.
>
> See [INVENTORY.md](INVENTORY.md) for the UI/storage system and [EQUIPMENT_DESIGN.md](EQUIPMENT_DESIGN.md) for equipment design intent and tier guidelines.

---

## How this doc works

- Items are organized by **type** (top-level `##` sections) and **introducing zone** (`###` subsections).
- One markdown table per `(type × zone)` combination.
- `tier` is a column inside each table, not a structural section — lets a single zone hold items across multiple tiers as the game grows.
- Some columns (`identity`, `source`) are **doc-only** designer reference — the generator ignores them. Others map directly to `.tres` fields.
- Icon paths follow the convention `res://assets/sprites/items/<type>/<id>.png` by default; add an explicit `icon` column row-by-row only when overriding.

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
| `cost` | `base_value` | Gold value; also informs merchant pricing (sell-back is derived) |
| `identity` | — (doc-only) | One short phrase capturing design intent |
| `source` | — (doc-only) | Where the item appears in the loop; comma-sep when multi-source |
| `description` | `description` | Player-facing flavor |
| `icon` *(opt)* | `icon` (Texture2D) | Override only — defaults to `res://assets/sprites/items/equipment/<id>.png` |

### Stats DSL

Format: `<ATTR>[+-]<N>, ...`

- Attribute literals match the `AttributeType` enum exactly: `STRENGTH`, `BODY`, `AGILITY`, `SPIRIT`, `FOUNDATION`, `CONTROL`, `RESILIENCE`, `WILLPOWER`.
- Values are integers (stored as float in the resource).
- Empty stats cell = empty `attribute_bonuses` dictionary.

**Foundation tier authoring guidelines** (per [EQUIPMENT_DESIGN.md](EQUIPMENT_DESIGN.md)):
- 1-2 attribute bonuses per item
- Values in the `+1` to `+5` range
- Simple, clear identity — a sword gives `STRENGTH`, a helm gives `WILLPOWER`

### Spirit Valley

| # | id | name | slot | stats | tier | cost | identity | source | description |
|---|----|------|------|-------|------|------|----------|--------|-------------|
| E1 | makeshift_dagger | Makeshift Dagger | MAIN_HAND | STRENGTH+3, AGILITY+2 | Foundation | 0 | Starter weapon | NPC reward (Beat 1) | A simple iron blade, well-balanced for a beginner. |
| E2 | iron_shortsword | Iron Shortsword | MAIN_HAND | STRENGTH+5, AGILITY+2 | Foundation | 10 | Dagger upgrade | Merchant | A heavier blade, demanding both hands. |
| E3 | cultivators_cowl | Cultivator's Cowl | HEAD | WILLPOWER+3, SPIRIT+1 | Foundation | 6 | First HEAD slot — mental focus | Merchant | A felted cowl, traditional among initiate cultivators. |
| E4 | reinforced_robes | Reinforced Robes | ARMOR | BODY+4, RESILIENCE+2 | Foundation | 7 | First ARMOR slot — survivability | Merchant | Padded robes lined with light scripted plates. |
| E5 | dreadbeast_tooth_necklace | Dreadbeast Tooth Necklace | ACCESSORY | STRENGTH+2, AGILITY+2 | Foundation | 0 | Physical Offense | Loot | A small dreadbeast tooth, fashioned around a leather strap. |
| E6 | leeching_ring | Leeching Ring | ACCESSORY | CONTROL+2, FOUNDATION+2 | Foundation | 50 | Cooldown + max mana | Merchant, Loot | A polished metal band engraved with a single character. |
| E7 | scripted_bark | Scripted Bark | OFF_HAND | BODY+2 | Foundation | 0 | First offhand slot, played with makeshift dagger dropped by first mob seen | Loot | A small scripted piece of bark, not much but will take a hit or two |

---

## Materials

> **Not yet captured in this doc.** Existing materials (Spirit Fern, Dewdrop Tear) live in `resources/items/materials/`. Will get their own section here with a per-zone breakdown when the generator extends to cover materials.

---

## Quest items

> **Not yet captured in this doc.** Existing quest items (Refugee Camp Map) live in `resources/items/quest_items/`. Same plan as Materials — added in a later pass.

---

## Generator

> **Planned** — not yet implemented. Will live at `scripts/tools/items_md_to_resources.gd`.

### Invocation

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s scripts/tools/items_md_to_resources.gd
```

### Folder layout (target output)

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

Icons live alongside under `assets/sprites/items/equipment/<id>.png`.

### Behavior

| Case | Behavior |
|---|---|
| `.tres` exists, content matches doc | Skip (no rewrite) |
| `.tres` exists, content differs | Overwrite via `ResourceSaver.save()` (preserves UID) |
| `.tres` missing | Create new |
| `.tres` exists in tracked folder, no matching doc row | Report as orphan; **never delete by default** (use `--delete-orphans` to opt in) |
| Stats DSL invalid | Fail-loud, abort run |
| Icon file missing | Fail-loud, abort run with the missing path |
| Two rows share the same id | Fail-loud, abort run |

Generated `.tres` files prepend `; AUTO-GENERATED FROM docs/inventory/ITEMS.md — DO NOT EDIT` as the first line.

### Migration notes (one-time)

- Existing `resources/items/test_items/dagger.tres` → `resources/items/equipment/spirit_valley/makeshift_dagger.tres`. Update `item_id` to `makeshift_dagger`, name to `Makeshift Dagger`, stats per E1 row. UID preserved by `ResourceSaver.save()` on the existing loaded resource.
- Existing `resources/items/test_items/sword.tres` → `resources/items/equipment/spirit_valley/iron_shortsword.tres`. Update `item_id` to `iron_shortsword`, name to `Iron Shortsword`, stats per E2 row.
- `resources/items/test_items/dagger_instance.tres` (ItemInstanceData wrapping dagger) — check whether anything still references it; if not, delete. If yes, update its `item_definition` reference to point at the new file.
- Once migrated, `resources/items/test_items/` folder should be empty and can be removed.
