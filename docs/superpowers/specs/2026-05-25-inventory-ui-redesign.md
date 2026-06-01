# Inventory UI Redesign

**Date:** 2026-05-25
**Status:** Draft (pending user review)
**Mockup:** [docs/superpowers/mockups/inventory-redesign/](../mockups/inventory-redesign/index.html) (`python -m http.server 3789 --directory docs/superpowers/mockups/inventory-redesign`)
**Approved direction:** mockup confirmed "perfect" by user 2026-05-25.

---

## Goal

Bring the inventory UI to a single, cohesive level of polish across all categories, and introduce **Consumables** as a first-class tab with combat hotbar slots. The book/parchment metaphor stays — what changes is rhythm, density, and how each page is used.

### What the player gets

- A tighter, more readable Equipment grid with a functioning Discard slot.
- A Materials tab that finally uses the right page (detail panel) and lays items out on a grid instead of a vertical list.
- A Journal (Quest items) tab that reads like a journal entry, with provenance and a linked-quest indicator.
- A new Consumables tab with a 4-slot combat hotbar on the right page.

---

## Scope

### In scope

1. **Visual refresh of shared chrome** — banner styling stays, but the sub-banner, scroll rail, slot frame, and grid background get a unified pixel-art treatment that all four tabs share. Rarity colour shows as a corner notch on each occupied slot.
2. **Equipment tab polish**
   - Tighter 6×5 grid (was 5×4) — same parchment page footprint, more capacity.
   - Functional **Discard** slot (drop-to-destroy with a single-replacement rule).
   - Restyled vertical scroll rail.
3. **Materials tab rebuild**
   - Grid (not list) — same slot component the Equipment tab uses.
   - Right page now shows a **material detail card** with source, recipes-that-use-it, and worth.
   - Discard slot present.
   - Sort arrows shown but disabled (no sorting in this slice — explicit user call).
4. **Quest (Journal) tab rebuild**
   - Left page: rich rows with icon + name + one-line provenance + wax-seal marker showing whether the linked quest is active.
   - Right page: journal entry card with full body text (drop cap), `From:` provenance, `Linked quest:` pulsing dot for active quests.
   - Gold banner (the journal breaks the red-ribbon pattern intentionally).
5. **Consumables tab (new)**
   - Left page: same grid component, stack counts on every occupied cell.
   - Right page: **Combat Hotbar** — 4 slots, each tied to keybinds `1`–`4`, drag a stack from the grid into a slot to equip. Selected stack's detail card appears below.
   - Discard slot present.
   - Inventory-side equip/unequip lives here; **combat-side use** (cooldown timers, actually firing the effect from the HUD) is the follow-up [combat-use spec](./2026-05-24-consumables-design.md#out-of-scope-deferred-to-the-combat-use-spec).

### Out of scope (deferred)

- **Equipment type sorting (filter arrows wired to filter the grid)** — designed in mockup, low-priority per user. UI is rendered but the filter logic is a follow-up so this PR stays focused.
- **Material type sorting** — explicit user call: "no priority, don't do this yet."
- **Combat-side hotbar usage** — covered by the deferred [combat-use spec](./2026-05-24-consumables-design.md).
- **Consumable cooldown timers / cooldown ring on hotbar icons** — falls out once combat-side use lands.
- **Favorites system for materials** — shown as a hint in the mockup; not built in this slice.
- **Persistent main-HUD hotbar** — for now the hotbar lives on the Consumables tab's right page; promoting it to a permanent strip on the main view is a separate design call.

---

## Architecture

The redesign is bigger surface-area than it is depth. Most of the work is in scene composition and a couple of shared sub-scenes; the data layer barely moves.

```
┌────────────────────────── inventory_view.tscn (root) ──────────────────────────┐
│  TabSwitcher (now 4 buttons: Equipment / Consumables / Materials / Journal)    │
│                                                                                │
│  ┌─ EquipmentTab.tscn ─┐  ┌─ ConsumablesTab.tscn ─┐                            │
│  │ Banner              │  │ Banner                │                            │
│  │ SortSubBanner       │  │ SortSubBanner         │                            │
│  │ GridToolbar         │  │ GridToolbar           │                            │
│  │ InventoryGrid (6×5) │  │ InventoryGrid (6×5)   │                            │
│  │ ScrollRail          │  │ ScrollRail            │                            │
│  │ TrashSlot           │  │ TrashSlot             │                            │
│  │ GearSelector        │  │ CombatHotbar (NEW)    │                            │
│  │ ItemDescriptionPanel│  │ ItemDescriptionPanel  │                            │
│  └─────────────────────┘  └───────────────────────┘                            │
│                                                                                │
│  ┌─ MaterialsTab.tscn (rebuilt) ┐  ┌─ JournalTab.tscn (rebuilt from QuestTab)─┐│
│  │ Banner                       │  │ JournalBanner (gold variant)            ││
│  │ SortSubBanner (disabled)     │  │ "Items of consequence" subtitle         ││
│  │ GridToolbar                  │  │ JournalList (rich rows w/ wax seal)     ││
│  │ InventoryGrid (6×5)          │  │ ScrollRail                              ││
│  │ ScrollRail                   │  │ QuestJournalCard (drop cap + meta)      ││
│  │ TrashSlot                    │  └─────────────────────────────────────────┘│
│  │ MaterialDetailCard (NEW)     │                                              │
│  │ MaterialTipCard (NEW)        │                                              │
│  └──────────────────────────────┘                                              │
└────────────────────────────────────────────────────────────────────────────────┘
```

### New shared scenes (live under `scenes/inventory/common/`)

| Scene | What it is | Replaces / used by |
|---|---|---|
| `InventoryGrid.tscn` | A configurable grid of `InventorySlot`s. Takes `slot_count`, `columns`, an optional `item_source` strategy (equipment / consumables / materials), and emits `slot_clicked` / `slot_dragged`. | Replaces today's per-tab grid code. Used by Equipment, Consumables, Materials. |
| `ScrollRail.tscn` | Gold-capped vertical scroll widget styled to match the parchment chrome. Wraps a `VScrollBar`. | Used by every tab. |
| `SortSubBanner.tscn` | The "[◀ All ▶]" widget with dot indicators. `enabled: bool`, `options: PackedStringArray`. | New; appears on Equipment + Materials + Consumables. |
| `GridToolbar.tscn` | The thin row above the grid with the slot count on the left and the `TrashSlot` on the right. | New; one toolbar per tab. |
| `ItemDetailCard.tscn` | A polished version of today's `ItemDescriptionPanel` — name + sub + rarity-tinted icon frame + divider + body + effect pills. | Replaces the current `item_description_panel.tscn` usage everywhere. (Old scene file deleted once nothing references it.) |

### Per-tab scenes

| Scene | Change |
|---|---|
| `EquipmentTab.tscn` | Recompose to use the new shared scenes. Grid swap from 5×4 → 6×5. Keep `GearSelector` and right-page item card. |
| `ConsumablesTab.tscn` (new) | Same composition pattern as Equipment, but the right-page region holds `CombatHotbar.tscn` instead of the gear selector. |
| `MaterialsTab.tscn` (rebuilt) | Throw away today's `VBoxContainer` of `MaterialContainer` rows. Replace with `InventoryGrid` + `MaterialDetailCard` + `MaterialTipCard`. |
| `QuestItemsTab.tscn` (rebuilt) | Throw away today's `QuestItemRow`. New `JournalRow` with icon-circle + name + sub + wax seal. New `QuestJournalCard` for the right page. Banner text becomes "Journal" but the directory and class names stay `quest_items_tab/` to avoid a noisy rename in git history. |
| `inventory_view.tscn` | TabSwitcher gets a 4th button (Consumables). Tab order: Equipment, Consumables, Materials, Journal. |

### New: `CombatHotbar.tscn`

Lives at `scenes/inventory/inventory_view/consumables_tab/combat_hotbar/`. Renders 4 `HotbarSlot`s in a row, modeled on the ability loadout slots. Each `HotbarSlot`:

- Accepts drops only of `ConsumableDefinitionData`.
- Renders the item glyph, stack count (×N from inventory), and a static keybind chip (`1` / `2` / `3` / `4`).
- Empty state shows a faint `+` and the keybind chip.
- Click an equipped slot to clear it back into the grid.
- **Enforces uniqueness across slots:** equipping a consumable that's already in another slot clears the old slot first. Matches how the ability loadout works.

### `InventoryData` additions

```gdscript
# Already approved in 2026-05-24-consumables-design.md:
@export var consumables: Dictionary[ConsumableDefinitionData, int] = {}

# NEW for this spec:
## Hotbar mapping. Keys are physical slot indices 0..3 (corresponding to
## hotkeys 1..4). Values are the equipped ConsumableDefinitionData, or
## absent if the slot is empty. The stack count is read from `consumables`,
## not stored here, so the count is always live.
@export var equipped_consumables: Dictionary[int, ConsumableDefinitionData] = {}
```

### `InventoryManager` additions

| Method | What it does |
|---|---|
| `equip_consumable(def: ConsumableDefinitionData, slot_index: int) -> void` | Sets `equipped_consumables[slot_index] = def`. If `def` is already in another slot, that other slot is cleared first (uniqueness rule, matches ability loadout). Emits `inventory_changed`. |
| `unequip_consumable(slot_index: int) -> void` | Erases `equipped_consumables[slot_index]`. Emits `inventory_changed`. |
| `discard_equipment_instance(instance: ItemInstanceData) -> void` | Removes from `inventory.equipment`. If currently in `equipped_gear` or `equipped_accessories`, unequip first. Logs in red. Emits `inventory_changed`. |
| `discard_material(def: MaterialDefinitionData, quantity := -1) -> void` | Decrements `inventory.materials[def]` by `quantity` (`-1` = all). Erases the dict entry when the count reaches zero. Logs + emits. |
| `discard_consumable(def: ConsumableDefinitionData, quantity := -1) -> void` | Same as `discard_material` but for `inventory.consumables`. Also clears any `equipped_consumables` slot that was holding `def` if the count hits zero. Logs + emits. |

The three `discard_*` methods are what the `TrashSlot` calls — one per item-category, branched at the UI layer based on what's in the hold-buffer (the buffer always knows its own type).

### Trash slot semantics (the "single-replacement rule")

Per the user's spec: "any item can be dropped into the X inventory slot, and while said item can be picked up from this slot, if another item is placed there, then the item that was there before just gets deleted forever."

That maps to:

1. `TrashSlot` holds at most one `ItemInstanceData` (or a `(MaterialDefinitionData, 1)` stack) in a transient hold-buffer.
2. Drop onto an empty `TrashSlot` → store in the hold-buffer, leave inventory alone.
3. Drag the held item *out* of `TrashSlot` back into the grid → restored (no destruction).
4. Drop a *second* item onto `TrashSlot` while it already holds one → the held one is permanently destroyed via `InventoryManager.discard_item`, and the new item takes its place in the hold-buffer.
5. Closing the inventory while the hold-buffer is non-empty → the held item is **returned** to inventory (it was never destroyed; only the *replaced* item is destroyed).

The "Discarded forever" flash overlay from the mockup fires only on step 4. The trash slot icon stays the same X glyph in all states; the hold-buffer is shown as the item's icon overlaid on the X.

### Right-page detail panels

Each tab's right-page card is its own scene that takes a single `ItemDefinitionData`-flavoured input:

- **Equipment**: existing `GearSelector` + `ItemDetailCard` (no change in spirit, just restyled).
- **Consumables**: `CombatHotbar` (top) + `ItemDetailCard` (bottom). The detail card shows the currently selected/hovered grid item; if nothing is selected, falls back to the most recent.
- **Materials**: `MaterialDetailCard` — extends `ItemDetailCard` with three extra rows (Source / Used in / Worth). These three values come from new fields on `MaterialDefinitionData` (see below). Below the card: a static `MaterialTipCard` (the "favorites" hint — text-only, no functionality this slice).
- **Journal**: `QuestJournalCard` — bigger icon-circle, drop-cap-styled body text, `From:` meta row (the `Linked quest:` row from the mockup is omitted until QuestManager exists).

### `MaterialDefinitionData` additions

```gdscript
## Where this material is typically found. Free-form lore string —
## displayed on the material detail panel.
@export var source_description: String = ""

## Comma-separated names of recipes/items that consume this material.
## Free-form for now; we can graph this from recipe data once crafting
## lands. Pure metadata in this slice.
@export var used_in: String = ""
```

`base_value` already exists on `ItemDefinitionData` — that's the "Worth" row.

`ConsumableDefinitionData` doesn't get new fields; its detail card uses `description` + `_get_item_effects()`.

`ItemDefinitionData` doesn't get new fields either — quest item provenance ("From:") is a new optional field on a tighter subclass:

### `QuestItemDefinitionData` (new)

Today, quest items reuse the base `ItemDefinitionData`. To support the journal entry layout cleanly, add a thin subclass:

```gdscript
class_name QuestItemDefinitionData
extends ItemDefinitionData

## Where the player obtained this — free-form lore. Displayed on the
## journal card as the "From:" line.
@export var from_source: String = ""

func _init() -> void:
    item_type = ItemType.QUEST_ITEM
```

No `linked_quest_*` fields yet — per the decision above, every quest item shows the red "active" wax seal and the journal card omits the "Linked quest" row until a real `QuestManager` exists to source that state. When it does land, the field(s) get added here and the journal layout gets a single `if linked_quest_name != "":` block.

Migrate the existing `refugee_camp_map.tres` to this class. Old `ItemDefinitionData`-typed quest items keep working — `JournalRow` checks `if item is QuestItemDefinitionData` before reading the new field.

---

## Data flow

1. **Tab change** → `inventory_view.gd` shows/hides the relevant Tab.tscn. Page-turn animation unchanged.
2. **Inventory change** → `InventoryManager.inventory_changed` → each tab's `_on_inventory_changed` repopulates its grid + detail.
3. **Drag/drop within a tab** → handled by the tab's script using `InventorySlot` + `GearSlot` + `HotbarSlot` + `TrashSlot`. Drop targets validate the dropped item type (e.g., `HotbarSlot` rejects non-consumables).
4. **Drop on TrashSlot** → `TrashSlot._on_drop` checks hold-buffer; if non-empty, calls `InventoryManager.discard_item(held)` and replaces the buffer; if empty, just stores.
5. **Drop on HotbarSlot** → `InventoryManager.equip_consumable(def, slot_index)`. Click on equipped hotbar slot → `InventoryManager.unequip_consumable(slot_index)`.

---

## Testing

### Unit (GUT, `tests/unit/`)

- `test_inventory_manager_discard.gd`
  - discard equipment instance removes it from `inventory.equipment` and unequips it if it was in `equipped_gear`.
  - discard material with no quantity erases the dict entry.
  - discard material with quantity decrements and keeps the entry if non-zero.
  - discard consumable that is currently in the hotbar removes it from `equipped_consumables` too.
- `test_inventory_manager_consumable_hotbar.gd`
  - `equip_consumable` populates `equipped_consumables[slot]`.
  - equipping the same def into a different slot clears the prior slot.
  - `unequip_consumable` erases the slot.
  - `inventory_changed` fires on both equip and unequip.

### Integration (`tests/integration/`)

- `test_trash_slot_flow.gd` — drives the trash-slot semantics end-to-end on a headless `EquipmentTab` instance: drop an item, verify nothing destroyed; drop a second, verify first destroyed and second held; pull held back out, verify restored; close inventory mid-hold, verify held returns to inventory.
- `test_quest_journal_render.gd` — instantiate the rebuilt `QuestItemsTab`, award one `QuestItemDefinitionData`, assert the row's wax seal renders in the active state (always-active during this slice) and that `from_source` shows in the journal card's "From:" row.

The existing `test_equipment_grid.gd` (if any) gets updated for the 6×5 dimensions.

---

## Migration

- **`MaterialDefinitionData`** gains two optional fields. Existing `.tres` files (`spirit_fern.tres`, `dewdrop_tear.tres`) load fine with empty strings — they get populated as a follow-up content pass.
- **`QuestItemDefinitionData`** is a new class. Existing `refugee_camp_map.tres` is migrated: change `script_class` to the new class and add `from_source` / `linked_quest_name` values. Any code that does `item is ItemDefinitionData` still works because the new class extends it.
- **`InventoryData`** gains `consumables` (already approved) and `equipped_consumables` (new). Saved games without these keys fall back to empty dicts on load — GDScript's `@export Dictionary` defaults handle this.
- **Scene file rename**: not doing one. `quest_items_tab/` stays as-is on disk; only the in-game banner label changes to "Journal". (If the rename is desired later, it's a separate housekeeping commit.)

---

## Implementation order (preview — full plan in writing-plans skill output)

1. Shared chrome scenes (`InventoryGrid`, `ScrollRail`, `SortSubBanner`, `GridToolbar`, `ItemDetailCard`) — no behavioural change yet.
2. Wire Equipment tab to the new shared scenes. Bump grid to 6×5. Verify nothing broke.
3. `InventoryManager.discard_item` + `TrashSlot` rewrite. Tests.
4. Rebuild Materials tab on the new shared scenes. Add `MaterialDefinitionData` fields. Author detail card.
5. `QuestItemDefinitionData` + migrate `refugee_camp_map.tres`. Rename tab. Build the new `JournalRow` + `QuestJournalCard`.
6. `InventoryData.equipped_consumables` + `InventoryManager.equip_consumable` / `unequip_consumable`. Tests.
7. New `ConsumablesTab.tscn` + `CombatHotbar.tscn` + `HotbarSlot.tscn`.
8. Add the Consumables button to the tab switcher; finalize tab order.
9. Content/polish pass on existing `.tres` files (material sources, quest item provenance).

Each numbered step is a separate commit so the visual progression is reviewable.

---

## Decisions confirmed by the mockup review

| Question | Decision |
|---|---|
| Trash slot confirmation step? | No — the "Discarded forever" flash on replacement is enough. |
| Hotbar location? | Right page of the Consumables tab for now. Persistent main-HUD strip is a separate design call. |
| Journal banner colour breaks the pattern? | Intentional — gold for the journal, red ribbons for the others. |
| Filter arrows on Materials? | Rendered but disabled per user's "no sorting yet" call. |

## Decisions resolved 2026-05-25

| Question | Decision |
|---|---|
| Same consumable in multiple hotbar slots? | **No** — enforce uniqueness, like the ability loadout slots. |
| Tab order? | **Equipment → Consumables → Materials → Journal.** |
| `linked_quest_active`? | **Defer entirely.** Don't add the field. Wax seal always renders as active; journal card omits the "Linked quest" row until a real QuestManager lands. |
| Asset strategy? | **Implementation proceeds with placeholders.** User produces 5 new sprites in parallel; scenes wire `@export var texture: Texture2D` so each placeholder is swapped in the editor without code changes. |

### Placeholder strategy

Where new art is pending, the scenes use these placeholders in the meantime — each is a single `ColorRect` or `Label` so the swap is trivial:

| Pending asset | Placeholder | Swap-in path |
|---|---|---|
| Consumables banner (#1) | `TextureRect` pointing at `materials_tab/banner.png` (same shape) + a centered `Label` "CONSUMABLES" with `LabelTitle` variant overlaid. | Replace `texture` with the new banner PNG; remove the overlaid Label. |
| Journal banner (#2) | Same red `tab_banner.png` reused. The visual gold-vs-red break lands when the new sprite arrives. | Replace `texture`. |
| Trash slot (#3) | `unocupied_inventory_slot.png` as the frame + a Label with text "X" on top (60% alpha, dark ink). When holding an item, the Label hides and the item glyph shows over the slot. | Replace the frame texture; remove the X Label (it lives on the new sprite). |
| Combat hotbar slot (#4) | A `ColorRect` 66×66 with `color = Color(0.08, 0.06, 0.04, 1)` + a 2px gold `border` via stylebox, plus the existing `equipment_grid/selected_option.png` corner-stamped at slot top-left for the keybind chip with a Label "1/2/3/4". | Replace the `ColorRect`/stylebox with the hotbar-slot `Texture2D`. |
| Wax seal (#5) | A 14×14 `ColorRect` with `color = Color("#b04a2f")` and `rounded` via a circular stylebox. | Replace with the wax-seal `Texture2D`. |

The implementation plan calls out these placeholder swaps explicitly so the asset hand-off is a single line item per sprite.
