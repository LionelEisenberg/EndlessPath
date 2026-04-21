# Beat 3b — Merchant Unlock (Design)

> **Status:** Spec only. No implementation yet.
> **Source:** [FOUNDATION_PLAYTHROUGH.md §Beat 3b](../../progression/FOUNDATION_PLAYTHROUGH.md)
> **Scope:** Beat 3b quest chain + Merchant zone action stub only. The actual Merchant buy/sell UI is deferred — this spec bundles Beat 3b's NPC handoff with the Beat 4 Merchant **unlock mechanic** (but not Merchant content).

---

## 1. Goal

Finish `q_reach_core_density_10` by sending the player back to the Celestial Intervener for a final conversation, reward the player with a **Refugee Camp Map** quest item, and use that item to gate a new `refugee_camp` special encounter in the adventure. Visiting the refugee camp unlocks a **Merchant** zone action in Zone 1 — stubbed for now, but wired so that a later beat can fill in real buy/sell behavior without touching unlock plumbing.

Along the way, implement the declared-but-missing `UnlockConditionData.ITEM_OWNED` condition type and add `unlock_conditions` support to `AdventureEncounter` so future special encounters can also gate their appearance on player state.

---

## 2. Player flow

1. Player cycles with the Keystone #1 technique; Core Density rises.
2. Core Density reaches **10** → `q_reach_cd_10` condition (existing) satisfies → `q_reach_core_density_10` **step 1** completes.
3. Quest tracker now shows **step 2: "Return to the Celestial Intervener"**. The fourth NPC action (`celestial_intervener_dialogue_4`) becomes visible in Zone 1 because its unlock condition is the same `q_reach_cd_10` condition.
4. Player clicks the NPC → `dialogue_4` timeline plays → `celestial_intervener_dialogue_4` event fires → step 2 completes → `q_reach_core_density_10` completes → `completion_effects` awards the **Refugee Camp Map** to inventory.
5. Player starts a new `shallow_woods` adventure.
6. Map generator now sees the `refugee_camp` encounter as **eligible** (its `unlock_conditions` resolve true: player owns the map AND `merchant_discovered` has not fired). Placement follows the same random rules as Aura Well.
7. Player walks to the refugee camp tile. Encounter panel opens with a single "Approach the camp" choice.
8. Choice success effects fire the `merchant_discovered` event. The **Merchant** zone action appears in Zone 1's main view on the next UnlockManager pass.
9. On subsequent adventures, the `refugee_camp` encounter is no longer eligible (`merchant_discovered = false` fails via the `negate` flag on its event condition) — tile stops appearing. Map item stays in inventory permanently as a keepsake.
10. Clicking the Merchant zone action logs a "coming soon" message via `LogManager`. No modal, no buy/sell UI — that's a future beat.

### Non-flow (out of scope)

- Actual Merchant buy/sell UI, stock, pricing.
- Inventory-view surface for quest items (player sees the map via the award log line only; a Quest Items tab can come later if needed).

---

## 3. Idempotency notes

- **`ITEM_OWNED(refugee_camp_map)`** is non-latching in theory (items can be consumed), but in this beat the map is **never consumed**. It stays in inventory indefinitely, so the condition behaves monotonically true once satisfied.
- **`merchant_discovered`** is event-based → latching. Once fired, it stays true. This is the durable gate for Merchant-action visibility.
- The encounter's `merchant_not_yet_discovered` (event + `negate = true`) is evaluated fresh at map-generation time — no UnlockManager registration needed.

---

## 4. Schema changes

### 4.1 `UnlockConditionData.ITEM_OWNED` — implement

File: `scripts/resource_definitions/unlocks/unlock_condition_data.gd`

The enum value already exists; the `evaluate()` branch currently logs a warning and returns false. Replace with a real implementation:

```gdscript
ConditionType.ITEM_OWNED:
    if not InventoryManager:
        Log.error("UnlockConditionData: InventoryManager is not initialized")
        return false
    return InventoryManager.has_item(str(target_value))
```

`target_value` holds the `item_id` string (e.g. `"refugee_camp_map"`).

### 4.2 `InventoryManager.has_item`

File: `singletons/inventory_manager/inventory_manager.gd`

Add a public `has_item(item_id: String) -> bool` that returns true if the player owns **any** item whose `item_definition.item_id == item_id` — checks materials, equipment grid, equipped gear, and the new quest-item dictionary.

```gdscript
## Returns true if the player owns at least one item with the given item_id.
func has_item(item_id: String) -> bool:
    var inv := get_inventory()
    for material in inv.materials:
        if material and material.item_id == item_id and inv.materials[material] > 0:
            return true
    for slot_idx in inv.equipment:
        var instance: ItemInstanceData = inv.equipment[slot_idx]
        if instance and instance.item_definition and instance.item_definition.item_id == item_id:
            return true
    for slot in inv.equipped_gear:
        var instance: ItemInstanceData = inv.equipped_gear[slot]
        if instance and instance.item_definition and instance.item_definition.item_id == item_id:
            return true
    for quest_item in inv.quest_items:
        if quest_item and quest_item.item_id == item_id and inv.quest_items[quest_item] > 0:
            return true
    return false
```

### 4.3 `InventoryData.quest_items`

File: `singletons/persistence_manager/inventory_data.gd`

Add a typed dictionary for quest items, mirroring `materials`:

```gdscript
## Dictionary of ItemDefinitionData (QUEST_ITEM type) -> Quantity owned.
@export var quest_items: Dictionary[ItemDefinitionData, int] = {}
```

### 4.4 `InventoryManager.award_items` — handle `QUEST_ITEM`

File: `singletons/inventory_manager/inventory_manager.gd`

Add a new match arm in `award_items`:

```gdscript
ItemDefinitionData.ItemType.QUEST_ITEM:
    _award_quest_item(item, quantity)
    if LogManager:
        LogManager.log_message("[color=yellow]Obtained %dx %s[/color]" % [quantity, item.item_name])
```

And the helper:

```gdscript
func _award_quest_item(item: ItemDefinitionData, quantity: int) -> void:
    if live_save_data.inventory.quest_items.has(item):
        live_save_data.inventory.quest_items[item] += quantity
    else:
        live_save_data.inventory.quest_items[item] = quantity
    inventory_changed.emit(get_inventory())
```

Existing MATERIAL / EQUIPMENT arms untouched.

### 4.5 `AdventureEncounter.unlock_conditions`

File: `scripts/resource_definitions/adventure/encounters/adventure_encounter.gd`

Add:

```gdscript
## Optional gates evaluated at map-generation time. Encounters with unmet conditions
## are filtered out of the random pool before placement — the player never sees them.
@export var unlock_conditions: Array[UnlockConditionData] = []
```

Default `[]` → existing encounters (`aura_well`, combat encounters, etc.) remain unconditionally eligible.

### 4.6 Map generator filtering

File: `scenes/adventure/adventure_tilemap/adventure_map_generator.gd`

`_assign_special_tiles()` currently does:

```gdscript
all_map_tiles[coord] = adventure_data.special_encounter_pool[randi_range(0, pool.size() - 1)]
```

Replace with a filtered pool built once per `_assign_special_tiles` call:

```gdscript
var eligible_pool: Array[AdventureEncounter] = []
for encounter in adventure_data.special_encounter_pool:
    if _encounter_eligible(encounter):
        eligible_pool.append(encounter)

# …later, when picking per tile:
if eligible_pool.is_empty():
    all_map_tiles[coord] = NoOpEncounter.new()  # or skip — match existing pool-empty behavior
else:
    all_map_tiles[coord] = eligible_pool[randi_range(0, eligible_pool.size() - 1)]
```

Helper:

```gdscript
func _encounter_eligible(encounter: AdventureEncounter) -> bool:
    for condition in encounter.unlock_conditions:
        if not condition.evaluate():
            return false
    return true
```

If `eligible_pool.is_empty()`, match the existing empty-pool behavior from earlier in the function (log warn + leave tiles as `NoOpEncounter`). Do not fall back to the unfiltered pool — that would place gated encounters the player isn't meant to see.

---

## 5. File changes

### 5.1 New resources

**`resources/items/quest_items/refugee_camp_map.tres`** — new folder `quest_items/` under `resources/items/`.
- Script: `item_definition_data.gd`
- `item_id = "refugee_camp_map"`
- `item_name = "Refugee Camp Map"`
- `description = "A hand-drawn map leading to a camp of survivors hidden in the valley."`
- `item_type = ItemType.QUEST_ITEM`
- `icon` — placeholder (`res://64.png`) until art lands.
- `stack_size = 1`, `base_value = 0`

**`resources/unlocks/merchant_discovered.tres`**
- Script: `unlock_condition_data.gd`
- `condition_id = "merchant_discovered"`
- `condition_type = EVENT_TRIGGERED`
- `target_value = "merchant_discovered"`
- `negate = false`
- Registered in `unlock_condition_list.tres` (standalone because the Merchant zone action consumes it for visibility).

**`resources/zones/spirit_valley_zone/zone_actions/celestial_intervener_dialogue_4.tres`**
- Script: `npc_dialogue_action_data.gd`
- `action_id = "celestial_intervener_dialogue_4"`
- `action_name = "Return to the [INTERVENER]"`
- `action_type = NPC_DIALOGUE`
- `description = "Your core is tempered. Report back to the [INTERVENER] before they leave."`
- `dialogue_timeline_name = "celestial_intervener_introduction_1"`
- `dialogue_timeline_label_jump = "dialogue_4"`
- `unlock_conditions = [q_reach_cd_10.tres]` (reuse — same predicate that advances quest step 1)
- `max_completions = 1`
- `success_effects = [TriggerEventEffectData("celestial_intervener_dialogue_4")]`

**`resources/zones/spirit_valley_zone/zone_actions/spirit_valley_merchant_action.tres`**
- Script: `zone_action_data.gd` (base class — no subclass needed for the stub)
- `action_id = "spirit_valley_merchant"`
- `action_name = "Traveling Merchant"`
- `action_type = MERCHANT`
- `description = "The refugee-camp merchant has set up a small stall in the valley."`
- `unlock_conditions = [merchant_discovered.tres]`
- `max_completions = 0` (unlimited)
- `success_effects = []` — click handler logs "coming soon"; see §6.

**`resources/adventure/encounters/special_encounters/refugee_camp_encounter.tres`**
- Script: `adventure_encounter.gd`
- `encounter_id = "refugee_camp"`
- `encounter_name = "Refugee Camp"`
- `description = "A cluster of makeshift tents under the trees. A merchant's wagon leans against a rock, its owner watching you approach."`
- `text_description_completed` = (unused; encounter won't re-appear once visited)
- `encounter_type = REST_SITE` (reuses existing icon; a dedicated `MERCHANT`/`REFUGEE_CAMP` glyph is a future polish)
- `unlock_conditions` = **inline** sub-resources:
  - `UnlockConditionData(ITEM_OWNED, target_value = "refugee_camp_map", negate = false)`
  - `UnlockConditionData(EVENT_TRIGGERED, target_value = "merchant_discovered", negate = true)`
- `choices` = single inline sub-resource:
  - `label = "Approach the camp"`
  - `tooltip = "Show them the map and see what they trade."`
  - `success_effects = [TriggerEventEffectData("merchant_discovered")]`

### 5.2 Dialogue timeline update

File: `assets/dialogue/timelines/celestial_intervener_introduction_1.dtl`

Append a new `dialogue_4` label at the end. Draft copy (tone-matched to existing dialogue — informal, playful):

```
label dialogue_4
join celestial_intervener center
celestial_intervener: Look at you! Core's humming nicely now, eh? Right before I slip off I'm gonna leave you something useful.
celestial_intervener: Here, take this map. There's a little refugee camp tucked away in the woods — go find them. Got a merchant with them who'll trade you real gear for coin. Tell 'em I sent you!
leave celestial_intervener
[end_timeline]
```

Copy is a draft — designer can rewrite without touching any script or gating.

### 5.3 Existing resource edits

**`resources/quests/q_reach_core_density_10.tres`**
- Keep existing step 1 (`reach_cd_10`) unchanged.
- Add **step 2** sub-resource: `step_id = "return_to_npc"`, `description = "Return to the Celestial [INTERVENER]"`, `completion_event_id = "celestial_intervener_dialogue_4"`.
- Set `completion_effects = [AwardItemEffectData(refugee_camp_map, 1)]`.

**`resources/zones/spirit_valley_zone/spirit_valley_zone.tres`**
- Add `celestial_intervener_dialogue_4.tres` and `spirit_valley_merchant_action.tres` to `all_actions`.

**`resources/adventure/data/shallow_woods.tres`**
- Append `refugee_camp_encounter.tres` to `special_encounter_pool`. Pool is now `[aura_well_encounter, refugee_camp_encounter]`.

**`resources/unlocks/unlock_condition_list.tres`**
- Register `merchant_discovered.tres` so UnlockManager re-evaluates it and emits `condition_unlocked` when the event fires.

---

## 6. Merchant click stub

The `MERCHANT` action type currently has no handler. For this beat:

- No new `MerchantActionData` class, no scene, no UI.
- The zone-action button-click dispatcher (wherever `success_effects` are processed for a clicked zone action) should gracefully handle `action_type = MERCHANT` by logging a message:
  - `LogManager.log_message("[color=yellow]The merchant waves you over but has nothing to offer yet. (Shop coming soon.)[/color]")`
- Wire this as an explicit `match` arm in the action dispatcher, not inside `spirit_valley_merchant_action.tres`. This way the stub lives in one place and can be replaced wholesale when the real Merchant UI lands.

If the dispatcher already falls through success_effects silently for unknown types, add the log line at the same site so the click produces visible feedback instead of appearing broken.

Exact dispatcher file/function: locate during implementation by grepping for where `zone_action.success_effects` are processed on click.

---

## 7. Testing

### Unit

- **`tests/unit/test_unlock_condition_item_owned.gd`** — mock `InventoryManager.has_item`, assert `evaluate()` returns true/false correctly for `ITEM_OWNED` condition with `target_value` string. Confirm `negate` still works (true when not owned).
- **`tests/unit/test_inventory_manager_has_item.gd`** — award a material, a quest item, an equipment piece (separately); assert `has_item(id)` true for each. Assert false when nothing matches. Confirm equipped gear is detected.
- **`tests/unit/test_inventory_manager_quest_items.gd`** — `award_items` on a `QUEST_ITEM` lands in `inventory.quest_items`; emits `item_awarded` and `inventory_changed`.
- **`tests/unit/test_adventure_map_generator_filter.gd`** — seed `special_encounter_pool` with one encounter that has unmet `unlock_conditions` plus one without; assert generator never places the gated encounter while its conditions fail, and includes it once conditions pass.

### Integration

- **`tests/integration/test_beat_3b_merchant_unlock.gd`** — full flow:
  1. Start with `q_reach_core_density_10` active, CD < 10, NPC 4 not yet available.
  2. Push CD to 10 → `q_reach_cd_10` condition satisfies, NPC 4 visible, quest step 1 complete.
  3. Simulate NPC 4 click (fire `celestial_intervener_dialogue_4`) → quest step 2 completes → quest completes → `InventoryManager.has_item("refugee_camp_map")` returns true.
  4. Generate `shallow_woods` → refugee camp encounter eligible in pool.
  5. Simulate encounter success → fire `merchant_discovered` → Merchant zone action visible.
  6. Re-generate `shallow_woods` → refugee camp encounter no longer eligible (negated merchant_discovered now true).

### Manual playtest (non-gating)

- Complete Beat 2 → cycle until CD 10 → confirm NPC 4 appears → click NPC 4 → confirm dialogue 4 plays and "Obtained 1x Refugee Camp Map" log line fires.
- Enter `shallow_woods` repeatedly until the refugee camp tile appears; confirm it sits alongside Aura Well in the pool (roughly equal frequency).
- Visit the camp → confirm Merchant zone action appears in Zone 1 view.
- Click Merchant → confirm log line fires.
- Start a new `shallow_woods` run → refugee camp no longer appears; Aura Wells still do.

---

## 8. Out of scope / follow-ups

- **Merchant buy/sell UI.** Real stock, pricing, sell-back fraction, restock, rotating inventory — all Beat 4 / future-beat work. A `MerchantActionData` subclass + merchant scene would slot in cleanly once that work begins.
- **Quest-items inventory tab.** Player currently sees the Refugee Camp Map only as a log line on acquisition. A dedicated Quest Items view can come with the next quest-item addition.
- **Dedicated `REFUGEE_CAMP` encounter icon.** Reuses `REST_SITE` for now.
- **Path-point awarding on CD 10.** Existing PathManager CD-milestone behavior is expected to award the second path point at CD 10 independently of the quest. The quest's `completion_effects` deliberately do **not** re-award it. Verify during implementation; if PathManager's milestone hook isn't wired yet, handle in a separate pass — not as part of this beat.
- **Dialogue copy polish.** Draft in §5.2 is placeholder; final copy can land anytime without touching mechanics.
- **UI surfacing of quest items.** If playtest reveals players don't notice the map → camp → merchant chain, add either a Quest Items tab in inventory or a highlighted quest log entry. Out of scope for a stub pass.
