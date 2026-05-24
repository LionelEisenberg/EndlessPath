# Consumables — MVP Design

**Date:** 2026-05-24
**Status:** Draft (pending user review)
**Mockups (future-scope):**
- [Combat consumable slots](../mockups/consumable-combat-slots-mockup.html)
- [Inventory equip UX](../mockups/consumable-inventory-equip-mockup.html)

## Goal

Introduce the consumable item category, ship the first-tier resource — the **Barely Coalesced Scale** — and lay down the data + storage scaffolding that the follow-up "combat-use + equip-slots" spec will plug into. **No combat-side use API in this slice.**

## Scope

### In scope

- New `ConsumableDefinitionData` resource type, extending `ItemDefinitionData`, with a small `use()` method that applies its effects.
- Effects composed via existing `Array[EffectData]` (reuses `ChangeVitalsEffectData`).
- Stacked storage in `InventoryData` (mirrors materials).
- `cooldown_seconds` field declared on the definition — pure metadata at this stage; nothing reads it yet.
- `InventoryManager.award_items` + new `_award_consumable` + `has_item` extended for the new item type.
- `InventoryManager.use_consumable(def) -> bool` — fires the definition's effects and decrements the stack. No cooldown check (that's the future combat instance's job).
- First `.tres`: `barely_coalesced_scale.tres`.
- Unit + integration tests for the pieces above.

### Out of scope (deferred to the combat-use spec)

- **Cooldown enforcement and the combat-side use path.** No combat instance / manager, no cooldown timers, no use trigger from the HUD. `InventoryManager.use_consumable` exists as the inventory-side primitive, but nothing in the game UI calls it yet. The combat-side wrapper (which adds cooldown gating + slot semantics) is the follow-up spec.
- **Equipped consumable slots.** Mockup'd in `docs/superpowers/mockups/`; designed in the same follow-up spec.
- **Cooldown enforcement / HUD indicator.** Falls out of the combat instance pattern once that lands.
- **Crafting / vendor sale** of consumables.
- **Combat-buff consumables** that wrap `BuffEffectData`. Bridge later via an `ApplyBuffEffectData extends EffectData` wrapper.
- **Multiple consumable subtypes** (potion / scroll / food). One unified type for now; differentiate by `effects` content.

## Architecture

```
┌─────────────────────────┐   defined by   ┌──────────────────────────┐
│ ConsumableDefinitionData│◀───────────────│ barely_coalesced_scale   │
│ (Resource)              │                │ .tres                    │
│  - effects[]            │                └──────────────────────────┘
│  - cooldown_seconds     │
│  + use()                │
└─────────────────────────┘

┌─────────────────────────┐   reads/writes   ┌─────────────────────┐
│ InventoryManager        │─────────────────▶│ InventoryData       │
│  + award_items          │                  │  - consumables: Dict│
│  + has_item             │                  │     [def → count]   │
│  + use_consumable       │                  └─────────────────────┘
└─────────────────────────┘

(Cooldown enforcement, equipped-slot wiring, and the combat HUD trigger
that actually calls use_consumable are deferred — see "Future work" below.)
```

Two components, clear seams:

1. **`ConsumableDefinitionData`** is pure data + one tiny method (`use()`). Knows nothing about inventory or cooldowns — it just applies its effects when asked.
2. **`InventoryManager`** owns the inventory-side verbs: awarding, lookup, and `use_consumable` (fire effects + decrement stack). **No cooldown check here** — the future `CombatConsumableInstance` wraps `use_consumable` with its own `is_ready()` gate.

## Data model

### `ConsumableDefinitionData`

```gdscript
class_name ConsumableDefinitionData
extends ItemDefinitionData

## ConsumableDefinitionData
## Definition-side data for a consumable item. `use()` applies the effects;
## stacking, cooldown enforcement, and combat-side timing live elsewhere
## (InventoryData for storage; future CombatConsumableInstance for cooldown).

@export var effects: Array[EffectData] = []

## Seconds before this consumable can be used again, *once cooldown is enforced
## by the combat-side manager*. Pure metadata in this slice — declared so .tres
## files are forward-compatible, but nothing reads it yet.
@export var cooldown_seconds: float = 0.0

func _init() -> void:
	item_type = ItemType.CONSUMABLE
	# stack_size inherited from ItemDefinitionData (default 99)

## Apply the consumable's effects. Pure — caller is responsible for inventory
## decrement and cooldown handling.
func use() -> void:
	for effect: EffectData in effects:
		effect.process()

## Tooltip text. Currently delegates to each effect's _to_string(); replace
## per-effect once a richer tooltip pass lands.
func _get_item_effects() -> Array[String]:
	var lines: Array[String] = []
	for effect: EffectData in effects:
		lines.append("[color=#7ea870]%s[/color]" % str(effect))
	if cooldown_seconds > 0.0:
		lines.append("[color=#a89070]Cooldown: %.1fs[/color]" % cooldown_seconds)
	return lines
```

### `InventoryData` addition

Mirrors `materials` exactly:

```gdscript
# In InventoryData:
@export var consumables: Dictionary[ConsumableDefinitionData, int] = {}
```

### `ItemDefinitionData.ItemType.CONSUMABLE`

Already exists in the enum — no change needed.

## InventoryManager changes

**1. Extend `award_items()` switch:**

```gdscript
ItemDefinitionData.ItemType.CONSUMABLE:
    if item is ConsumableDefinitionData:
        _award_consumable(item as ConsumableDefinitionData, quantity)
        if LogManager:
            LogManager.log_message("[color=cyan]Obtained %dx %s[/color]" % [quantity, item.item_name])
    else:
        Log.error("InventoryManager: Item type not supported: %s" % item.item_type)
```

(Cyan is a tentative log color — distinct from materials/equipment/quest-items. Easy to swap.)

**2. New private award helper (mirrors `_award_material`):**

```gdscript
func _award_consumable(consumable: ConsumableDefinitionData, quantity: int) -> void:
    if live_save_data.inventory.consumables.has(consumable):
        live_save_data.inventory.consumables[consumable] += quantity
    else:
        live_save_data.inventory.consumables[consumable] = quantity
    inventory_changed.emit(get_inventory())
```

**3. Extend `has_item()`** to scan `inventory.consumables` (parallels the existing materials/quest-items scans).

**4. New public `use_consumable`:**

```gdscript
## Fire the consumable's effects and decrement the player's stack by one.
## Returns true on success, false if the definition is null or the player
## has none in stock. Does NOT check cooldown — that's the caller's job
## (the future CombatConsumableInstance handles it).
func use_consumable(def: ConsumableDefinitionData) -> bool:
    if def == null:
        Log.error("InventoryManager.use_consumable: null definition")
        return false

    var inventory := get_inventory()
    var count: int = inventory.consumables.get(def, 0)
    if count <= 0:
        Log.warn("InventoryManager.use_consumable: no %s available" % def.item_id)
        return false

    def.use()
    if count == 1:
        inventory.consumables.erase(def)
    else:
        inventory.consumables[def] = count - 1
    inventory_changed.emit(inventory)
    return true
```

Two notes:

- **No cooldown check by design.** The combat instance gates `use_consumable` behind its own `is_ready()` before calling. Callers outside combat (tests, dev tools, eventually the overworld if we ever allow it) can use freely.
- **Erases the dict entry on zero.** Keeps the `consumables` dict the same shape as `materials` — no zero-count keys lingering.

## First consumable `.tres`

**File:** `data/consumables/barely_coalesced_scale.tres`

| field | value |
|---|---|
| `item_id` | `"barely_coalesced_scale"` |
| `item_name` | `"Barely Coalesced Scale"` |
| `description` | `"A poorly-formed flake of madra, scarcely worth the name. Crude practitioners still find a use for them."` |
| `item_type` | `ItemType.CONSUMABLE` (set by `_init`) |
| `icon` | _TBD — placeholder until art exists_ |
| `stack_size` | `99` (inherited) |
| `base_value` | `1.0` |
| `effects` | one `ChangeVitalsEffectData` with `madra_change: 20.0` |
| `cooldown_seconds` | `10.0` (declared for future use; nothing enforces it in this slice) |

Effect resource lives at `data/consumables/effects/barely_coalesced_scale_effect.tres` (or inline as a sub-resource — designer's choice in the editor).

## Testing

### Unit (GdUnit4)

`tests/unit/test_consumable_definition_data.gd`:

- `_init()` sets `item_type = ItemType.CONSUMABLE`.
- `use()` calls `process()` on each effect in order. Use a stub `EffectData` subclass that counts invocations.
- `use()` with an empty `effects` array is a no-op (no errors).
- `_get_item_effects()` returns one line per effect + a `Cooldown:` line when `cooldown_seconds > 0`.
- `_get_item_effects()` omits the cooldown line when `cooldown_seconds == 0`.

### Integration (GdUnit4, uses real InventoryManager)

`tests/unit/test_inventory_manager_consumables.gd`:

- `award_items(consumable_def, 5)` routes through `_award_consumable` and populates `inventory.consumables` with `{def: 5}`.
- Awarding the same definition again adds to the existing count (e.g., 5 → 8 after a second `award_items(def, 3)`).
- `has_item("barely_coalesced_scale")` returns true while the player has any consumable of that id.
- `inventory_changed` signal fires on award.
- `use_consumable(def)` with stock ≥ 1 → returns true, fires effects (madra +20 on the player vitals manager for a Barely Coalesced Scale), stack decrements by 1.
- `use_consumable(def)` that drops the count to 0 → dict entry is erased; `has_item("barely_coalesced_scale")` then returns false.
- `use_consumable(def)` with 0 stock → returns false, no state change, no effects fired.
- `use_consumable(null)` → returns false, logs error.
- `use_consumable` ignores `cooldown_seconds` — calling twice back-to-back with stock available both succeed and fire effects both times.
- `inventory_changed` signal fires on successful use.

### Resource-loading test

`tests/unit/test_barely_coalesced_scale_tres.gd`:

- Load `res://data/consumables/barely_coalesced_scale.tres` and assert: type is `ConsumableDefinitionData`, `item_id == "barely_coalesced_scale"`, has exactly one `ChangeVitalsEffectData` effect with `madra_change == 20.0`, `cooldown_seconds == 10.0`.

## Future work — combat-use + equip-slots (separate spec)

The follow-up spec will mirror the existing **`CombatAbilityInstance` / `CombatAbilityManager` pattern** on the combatant. Sketch:

```
CombatantNode  (per-combat, freed on exit)
├── CombatAbilityManager
│   └── CombatAbilityInstance[]      ← already exists
└── CombatConsumableManager          ← NEW
    └── CombatConsumableInstance[]   ← NEW, one per equipped slot
         ├── consumable_def: ConsumableDefinitionData
         ├── slot_index: int
         ├── cooldown_timer: Timer   ← child node, mirrors abilities
         ├── signal cooldown_started/updated/ready
         ├── is_ready() → cooldown_timer.is_stopped()
         └── use() → if is_ready(): InventoryManager.use_consumable(consumable_def); _start_cooldown(consumable_def.cooldown_seconds)
```

Why this shape:

- **Cooldowns are scene-tree state**, not autoload state. They reset for free when the combatant node is freed at combat end — same as ability cooldowns do today.
- **Per-slot cooldowns fall out naturally** — one instance per equipped slot, each with its own `Timer`. The same definition equipped to two slots gets two independent cooldowns.
- **HUD integration is identical to abilities** — the consumable slot UI subscribes to `cooldown_updated` and renders the sweep, exactly as the ability bar does. No new UI patterns needed.
- **`Timer` respects `Engine.time_scale`** — if combat ever introduces pause/slow-mo, cooldowns honor it automatically.

The follow-up spec will also add:

- `InventoryData.equipped_consumables: Dictionary[int, ConsumableDefinitionData]` — slot index → definition (mirrors `equipped_gear`).
- `InventoryManager.equip_consumable(def, slot_index)` / `unequip_consumable(slot_index)` — same shape as `equip_item` / `unequip_item`.
- Combat HUD additions per [`consumable-combat-slots-mockup.html`](../mockups/consumable-combat-slots-mockup.html).
- Inventory equip UX per [`consumable-inventory-equip-mockup.html`](../mockups/consumable-inventory-equip-mockup.html).
- Total slot count decision (mockup shows 3).

## Open questions

None blocking for *this* slice. For the follow-up spec:

- Slot count (3? 4?).
- HUD layout exact placement of the consumable strip.
- Whether icon art for Barely Coalesced Scale lands in this slice or with combat-use.

## Risks

- **Resource identity as dict key.** Godot resource identity is stable for `.tres` files loaded once and shared, which is the pattern used elsewhere (`materials` dict in `InventoryData`). New `.new()` instances would not deduplicate. Tests must use `load("res://data/consumables/...")` consistently — same as the materials test setup.
