# SortSubBanner Filtering — Design

**Date:** 2026-05-28
**Status:** Approved

## Goal

Make the existing `SortSubBanner` functional (today it cycles labels but nothing
happens) while keeping it reusable across inventory tabs. Selecting a category
visually highlights matching items by graying out the rest — a pure visual
filter that leaves grid layout, pagination, and interaction untouched.

## Behavior

- The banner is a generic category selector: the arrows cycle labels and emit
  `option_changed(index)`. (Unchanged.)
- Selecting a category dims every slot whose item does NOT match the category,
  plus empty slots, leaving matching items at full opacity. "All" (index 0)
  clears all dimming.
- Dimming is **purely visual** (`modulate.a`). Every slot stays fully
  interactive — drag, equip (drag-to-gear / right-click), and trash work on
  dimmed slots exactly as before.
- On the paginated Equipment grid, matching items are highlighted in place
  (page by page) — no compacting or re-flow. The dim state re-applies
  automatically on page flips and inventory changes.

## Architecture

Approach: generic banner + grid-owned dimming + tab-owned categories.

### SortSubBanner (unchanged)

Already a reusable generic selector: `set_options(labels)`,
`option_changed(index)`, `current_index`, `enabled`. No code changes — it is
simply enabled and wired by each consuming tab.

### EquipmentGrid (new filter hook)

- `const DIM_ALPHA := 0.3`
- `var _category_match: Callable` — defaults to match-all
  (`func(_d: ItemInstanceData) -> bool: return true`).
- `set_category_filter(match: Callable) -> void` — stores the predicate and
  re-renders the current page via `_update_grid`.
- `_update_grid()` — after binding each visible slot's data, set
  `slots[i].modulate.a = 1.0 if _category_match.call(data) else DIM_ALPHA`,
  where `data` is the slot's `ItemInstanceData` or `null` for an empty slot.
  Because dimming lives inside the render, it re-applies on every page flip and
  inventory change with no extra wiring.

### EquipmentTab (categories + wiring)

- Defines categories as data, each `{ "label": String, "match": Callable }`
  where `match` takes an `ItemInstanceData` (or `null`) and returns `bool`:
  - All → always `true`
  - Weapons → `MAIN_HAND`, `OFF_HAND`
  - Armor → `HEAD`, `ARMOR`
  - Accessories → `ACCESSORY`
- A shared helper drives the category closures:

```gdscript
func _item_in_slots(data: ItemInstanceData, slot_types: Array) -> bool:
	if data == null:
		return false
	var def := data.item_definition
	return def is EquipmentDefinitionData \
		and (def as EquipmentDefinitionData).slot_type in slot_types
```

- `_ready()`: set banner options from the category labels, set
  `sort_banner.enabled = true`, connect `option_changed` → `_on_filter_changed`.
- `_on_filter_changed(index: int)`:
  `equipment_grid.set_category_filter(CATEGORIES[index].match)`.

### Materials / Consumables / Journal (unchanged)

No category data exists on `MaterialDefinitionData` / `ConsumableDefinitionData`,
so those tabs keep their single "All" option (banner inactive). The pattern
above is the template for adopting filtering once category data exists. Journal
has no banner.

## Reusability contract

A tab adds filtering by:

1. Defining categories as `[{label, match}]`.
2. Feeding the labels to its `SortSubBanner` and enabling it.
3. On `option_changed`, telling its grid which predicate to dim by.

The banner carries zero item-domain knowledge; each tab owns its categories.

## Testing

- **Unit** (category predicates): Weapons matches a `MAIN_HAND` item, rejects an
  `ARMOR` item and `null`; All matches everything including `null`.
- **Integration** (`EquipmentGrid.set_category_filter`): a weapons predicate
  dims non-weapon and empty slots (`modulate.a == DIM_ALPHA`) and leaves weapons
  at `1.0`; the dim state persists after `set_page`; a match-all predicate
  restores every slot to `1.0`.

## Out of scope

- Compacting / re-flowing filtered results.
- Sorting (reordering) — this is filter-by-highlight only.
- Adding category data to materials / consumables.
