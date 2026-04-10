# Equipment Attribute Bonuses — Implementation Plan

**Status:** Complete (PR #9)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire equipment to the attribute system so equipping gear grants attribute bonuses that flow into combat, vitals, and all downstream systems.

**Architecture:** Flatten EquipmentDefinitionData (remove Weapon/Armor subclasses), add `attribute_bonuses` dictionary, implement `CharacterManager._get_attribute_bonuses()` to sum equipped gear. Reduce equipment slots from 8 to 6 (remove LEGS, FEET; rename CHEST→ARMOR).

**Tech Stack:** Godot 4.5, GDScript, `.tres` resource files

**Source Design:** `docs/inventory/EQUIPMENT_DESIGN.md`

---

## User Manual Steps (Godot Editor Required)

These steps **cannot** be done purely in code — you must open the Godot editor to complete them. They are called out inline in the tasks below but collected here for reference.

| Step | When | What to Do in Editor |
|------|------|---------------------|
| **M1** | After Task 2 | Open `gear_selector.tscn`. Delete `LegsGearSlot` and `FeetGearSlot` nodes. Rename `ChestGearSlot` to `ArmorGearSlot`. Set `ArmorGearSlot.slot_type` to `3` (ARMOR) in the Inspector. Verify layout looks correct — you may need to adjust VBoxContainer spacing. |
| **M2** | After Task 3 | Open `dagger.tres`, `sword.tres` in editor. Confirm they load without errors and show `attribute_bonuses` in the Inspector. If Godot shows "invalid script" errors, re-save each `.tres` from the editor. |
| **M3** | After Task 5 | Open the game. Equip the dagger. Open the character/combat stats panel and verify attribute totals reflect the bonus. Check the tooltip shows "+3 Strength" etc. |
| **M4** | After Task 5 | Delete your save file (`user://save.tres`) or keep `reset_save_data = true` to avoid stale equipped_gear data referencing old enum values. |

---

## File Map

| Action | File | Responsibility |
|--------|------|---------------|
| Modify | `scripts/resource_definitions/items/equipment/equipment_definition_data.gd` | New enum, attribute_bonuses, updated tooltip |
| Delete | `scripts/resource_definitions/items/equipment/weapon_definition_data.gd` | Removed — folded into parent |
| Delete | `scripts/resource_definitions/items/equipment/armor_definition_data.gd` | Removed — folded into parent |
| Modify | `singletons/character_manager/character_manager.gd` | `_get_attribute_bonuses()` reads equipped gear |
| Modify | `resources/items/test_items/dagger.tres` | Convert to EquipmentDefinitionData with attribute_bonuses |
| Modify | `resources/items/test_items/sword.tres` | Convert to EquipmentDefinitionData with attribute_bonuses |
| Modify (editor) | `scenes/inventory/inventory_view/equipment_tab/gear_selector/gear_selector.tscn` | Remove 2 slot nodes, rename 1, update slot_type values |
| No change | `singletons/inventory_manager/inventory_manager.gd` | Already uses EquipmentSlot enum generically |
| No change | `scripts/resource_definitions/items/item_instance_data.gd` | Already references ItemDefinitionData base |
| No change | `scenes/inventory/inventory_view/equipment_tab/gear_selector/gear_slot.gd` | `is_valid_item()` already checks `slot_type` match |
| No change | `singletons/persistence_manager/inventory_data.gd` | `equipped_gear` dict keys will use updated enum |

---

## Task 1: Update EquipmentSlot Enum and Flatten EquipmentDefinitionData

**Files:**
- Modify: `scripts/resource_definitions/items/equipment/equipment_definition_data.gd`

This task rewrites the equipment base class: new 6-slot enum, removes EquipmentType enum, adds `attribute_bonuses`, and updates the tooltip.

- [ ] **Step 1: Rewrite `equipment_definition_data.gd`**

Replace the entire file with:

```gdscript
class_name EquipmentDefinitionData
extends ItemDefinitionData

## EquipmentDefinitionData
## Base data for all equippable items. Slot determines role, attribute_bonuses determine effect.

#-----------------------------------------------------------------------------
# ENUMS
#-----------------------------------------------------------------------------

enum EquipmentSlot {
	MAIN_HAND,
	OFF_HAND,
	HEAD,
	ARMOR,
	ACCESSORY_1,
	ACCESSORY_2
}

#-----------------------------------------------------------------------------
# EXPORTS
#-----------------------------------------------------------------------------

@export var slot_type: EquipmentSlot = EquipmentSlot.MAIN_HAND

## Attribute bonuses granted while equipped. Keys are AttributeType enum values, values are float bonuses.
## Example: { AttributeType.STRENGTH: 3.0, AttributeType.AGILITY: 1.0 }
@export var attribute_bonuses: Dictionary = {}

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _init() -> void:
	item_type = ItemType.EQUIPMENT

#-----------------------------------------------------------------------------
# TOOLTIP
#-----------------------------------------------------------------------------

func _get_item_effects() -> Array[String]:
	var effects: Array[String] = []
	effects.append("Slot: %s" % EquipmentSlot.keys()[slot_type].replace("_", " ").capitalize())

	for attr_type: int in attribute_bonuses:
		var value: float = attribute_bonuses[attr_type]
		var attr_name: String = CharacterAttributesData.AttributeType.keys()[attr_type].capitalize()
		if value > 0:
			effects.append("[color=green]+%g %s[/color]" % [value, attr_name])
		elif value < 0:
			effects.append("[color=red]%g %s[/color]" % [value, attr_name])

	return effects
```

- [ ] **Step 2: Delete `weapon_definition_data.gd` and `armor_definition_data.gd`**

```bash
rm scripts/resource_definitions/items/equipment/weapon_definition_data.gd
rm scripts/resource_definitions/items/equipment/armor_definition_data.gd
```

- [ ] **Step 3: Verify no other scripts reference the deleted classes**

```bash
grep -r "WeaponDefinitionData\|ArmorDefinitionData" scripts/ singletons/ scenes/ --include="*.gd" --include="*.tscn"
```

Expected: Only hits in `.tres` files (handled in Task 3) and possibly `.godot/` cache (ignorable). If any `.gd` or `.tscn` files reference these classes, update them to use `EquipmentDefinitionData` instead.

- [ ] **Step 4: Commit**

```bash
git add scripts/resource_definitions/items/equipment/equipment_definition_data.gd
git rm scripts/resource_definitions/items/equipment/weapon_definition_data.gd
git rm scripts/resource_definitions/items/equipment/armor_definition_data.gd
git commit -m "refactor(equipment): flatten hierarchy, add attribute_bonuses

Remove WeaponDefinitionData and ArmorDefinitionData subclasses.
Add attribute_bonuses dictionary to EquipmentDefinitionData.
Update EquipmentSlot enum to 6 slots (remove LEGS, FEET, rename CHEST to ARMOR).
Remove EquipmentType enum — slot determines item role."
```

---

## Task 2: Update GearSelector Scene (User — Godot Editor)

**Files:**
- Modify (editor): `scenes/inventory/inventory_view/equipment_tab/gear_selector/gear_selector.tscn`

> **This is manual step M1 — must be done in the Godot editor.**

- [ ] **Step 1: Open `gear_selector.tscn` in the Godot editor**

- [ ] **Step 2: In VBoxContainer (left column), delete the `LegsGearSlot` node**

Right-click → Delete. This was `slot_type = 2` (LEGS, now removed from enum).

- [ ] **Step 3: Rename `ChestGearSlot` to `ArmorGearSlot`**

Right-click → Rename. Then in the Inspector, set `slot_type` to `ARMOR` (enum value 3 in the new enum).

- [ ] **Step 4: In VBoxContainer2 (right column), delete the `FeetGearSlot` node**

This node was bugged anyway (had `slot_type = 5` / OFF_HAND instead of FEET).

- [ ] **Step 5: Update remaining slot_type values in Inspector**

The enum values changed. Open each GearSlot node and set via the Inspector dropdown:

| Node | New slot_type (select from dropdown) |
|------|--------------------------------------|
| HeadGearSlot | HEAD |
| ArmorGearSlot | ARMOR |
| MainWeaponGearSlot | MAIN_HAND |
| OffhandGearSlot | OFF_HAND |
| Accessory1GearSlot | ACCESSORY_1 |
| Accessory2GearSlot | ACCESSORY_2 |

- [ ] **Step 6: Verify layout — adjust VBoxContainer spacing if needed**

Left column should have 2 slots (Head, Armor). Right column should have 2 slots (Main Hand, Off Hand). Bottom row should have 2 slots (Accessory 1, Accessory 2).

- [ ] **Step 7: Save the scene and commit**

```bash
git add scenes/inventory/inventory_view/equipment_tab/gear_selector/gear_selector.tscn
git commit -m "refactor(equipment): update gear selector to 6 slots

Remove LegsGearSlot and FeetGearSlot nodes.
Rename ChestGearSlot to ArmorGearSlot.
Update all slot_type exports to match new EquipmentSlot enum."
```

---

## Task 3: Convert .tres Item Files

**Files:**
- Modify: `resources/items/test_items/dagger.tres`
- Modify: `resources/items/test_items/sword.tres`

These files currently reference `WeaponDefinitionData` (deleted in Task 1). We rewrite them to use `EquipmentDefinitionData` with `attribute_bonuses`.

- [ ] **Step 1: Rewrite `dagger.tres`**

Replace the entire file with:

```tres
[gd_resource type="Resource" script_class="EquipmentDefinitionData" load_steps=3 format=3 uid="uid://bwpoorfeekkiu"]

[ext_resource type="Texture2D" uid="uid://n4bia46t2gbq" path="res://assets/asperite/inventory/dagger_icon.png" id="1_m84n8"]
[ext_resource type="Script" uid="uid://crbclsuiby2yn" path="res://scripts/resource_definitions/items/equipment/equipment_definition_data.gd" id="2_m84n8"]

[resource]
script = ExtResource("2_m84n8")
slot_type = 0
attribute_bonuses = {
0: 3.0,
2: 1.0
}
item_id = "dagger"
item_name = "Dagger"
description = "Dagger!! StabStab"
icon = ExtResource("1_m84n8")
item_type = 2
```

Notes on the `attribute_bonuses` dictionary:
- Key `0` = `AttributeType.STRENGTH` (maps to new enum order: STRENGTH=0)
- Key `2` = `AttributeType.AGILITY` (AGILITY=2)
- `slot_type = 0` = `EquipmentSlot.MAIN_HAND`

- [ ] **Step 2: Rewrite `sword.tres`**

Replace the entire file with:

```tres
[gd_resource type="Resource" script_class="EquipmentDefinitionData" load_steps=3 format=3 uid="uid://cehsoutejuih0"]

[ext_resource type="Texture2D" uid="uid://irvbdl0pat88" path="res://assets/asperite/inventory/sword_icon.png" id="1_sword"]
[ext_resource type="Script" uid="uid://crbclsuiby2yn" path="res://scripts/resource_definitions/items/equipment/equipment_definition_data.gd" id="2_m84n8"]

[resource]
script = ExtResource("2_m84n8")
slot_type = 0
attribute_bonuses = {
0: 6.0,
2: 2.0
}
item_id = "sword"
item_name = "Test Sword"
description = "A sturdy sword for testing drag swaps."
icon = ExtResource("1_sword")
item_type = 2
```

- [ ] **Step 3: Verify `dagger_instance.tres` still works**

Read `resources/items/test_items/dagger_instance.tres` — it references `dagger.tres` via UID. Since we preserved the UID (`uid://bwpoorfeekkiu`), the reference should resolve. No changes needed to this file.

> **Manual step M2:** Open both `.tres` files in the Godot editor and confirm they load without errors. Check that `attribute_bonuses` appears in the Inspector with the correct keys/values.

- [ ] **Step 4: Check for any other .tres files referencing deleted scripts**

```bash
grep -r "weapon_definition_data\|armor_definition_data\|WeaponDefinitionData\|ArmorDefinitionData" resources/ --include="*.tres"
```

If any other `.tres` files reference these scripts, convert them the same way.

- [ ] **Step 5: Commit**

```bash
git add resources/items/test_items/dagger.tres resources/items/test_items/sword.tres
git commit -m "refactor(equipment): convert test items to attribute_bonuses format

Dagger: attack_power 10 -> STRENGTH +3, AGILITY +1
Sword: attack_power 25 -> STRENGTH +6, AGILITY +2"
```

---

## Task 4: Wire Equipment Bonuses in CharacterManager

**Files:**
- Modify: `singletons/character_manager/character_manager.gd`

This is the core integration — `_get_attribute_bonuses()` reads equipped gear and sums attribute bonuses.

- [ ] **Step 1: Replace `_get_attribute_bonuses()` in `character_manager.gd`**

Find the existing method (around line 178) and replace it:

```gdscript
## Calculate total bonuses for an attribute from equipped gear
func _get_attribute_bonuses(attr_type: AttributeType) -> float:
	var total_bonus: float = 0.0

	var inventory: InventoryData = InventoryManager.get_inventory()
	for slot: int in inventory.equipped_gear:
		var instance: ItemInstanceData = inventory.equipped_gear[slot]
		if instance == null or instance.item_definition == null:
			continue
		var equip_def: EquipmentDefinitionData = instance.item_definition as EquipmentDefinitionData
		if equip_def == null:
			continue
		if equip_def.attribute_bonuses.has(attr_type):
			total_bonus += equip_def.attribute_bonuses[attr_type]

	return total_bonus
```

- [ ] **Step 2: Commit**

```bash
git add singletons/character_manager/character_manager.gd
git commit -m "feat(equipment): wire attribute bonuses from equipped gear

CharacterManager._get_attribute_bonuses() now sums attribute_bonuses
from all equipped items via InventoryManager. Equipment bonuses flow
into combat, vitals, and all systems reading get_total_attributes_data()."
```

---

## Task 5: Manual Smoke Test (User — Godot Editor)

> **This is manual steps M3 and M4.**

- [ ] **Step 1: Delete save data or confirm `reset_save_data = true`**

Old saves may have items in CHEST/LEGS/FEET slots with stale enum values. Either delete `user://save.tres` or confirm the game resets on launch.

- [ ] **Step 2: Launch the game and open the inventory**

Verify the gear selector shows 6 slots (Head, Armor, Main Hand, Off Hand, Accessory 1, Accessory 2).

- [ ] **Step 3: Equip the dagger to Main Hand**

Drag the dagger from the equipment grid to the Main Hand gear slot.

- [ ] **Step 4: Check the tooltip**

Hover over the equipped dagger. Verify it shows:
```
Slot: Main Hand
+3 Strength
+1 Agility
```

- [ ] **Step 5: Verify attribute bonuses apply**

Check the character stats display (if visible). Total Strength should be base (10) + 3 = 13. Total Agility should be base (10) + 1 = 11.

If no stats panel is visible, add a temporary log line in `CharacterManager.get_strength()`:

```gdscript
func get_strength() -> float:
	var base = live_save_data.character_attributes.get_attribute(AttributeType.STRENGTH)
	var bonuses = _get_attribute_bonuses(AttributeType.STRENGTH)
	Log.info("CharacterManager: Strength = %.1f base + %.1f bonus = %.1f" % [base, bonuses, base + bonuses])
	return base + bonuses
```

Remove the log line after verifying.

- [ ] **Step 6: Unequip and verify bonuses are removed**

Unequip the dagger. Strength should return to 10, Agility to 10.

- [ ] **Step 7: Test equip swap**

Equip the dagger, then drag the sword onto the same Main Hand slot. Verify the dagger returns to the grid and the sword's bonuses (+6 STR, +2 AGI) now apply.

---

## Task 6: Cleanup and Final Commit

- [ ] **Step 1: Remove any temporary log lines added during testing**

- [ ] **Step 2: Verify no references to deleted classes remain**

```bash
grep -r "WeaponDefinitionData\|ArmorDefinitionData\|EquipmentType\|attack_power\b\|\.defense\b" scripts/ singletons/ scenes/ resources/ --include="*.gd" --include="*.tscn" --include="*.tres" | grep -v ".godot/" | grep -v "addons/"
```

Expected: No matches (or only matches in documentation/comments).

- [ ] **Step 3: Final commit if any cleanup was needed**

```bash
git add -A
git commit -m "chore(equipment): cleanup references to removed weapon/armor subclasses"
```

---

## Summary of Changes

| What | Before | After |
|------|--------|-------|
| EquipmentSlot enum | 8 values (HEAD, CHEST, LEGS, FEET, MAIN_HAND, OFF_HAND, ACCESSORY_1, ACCESSORY_2) | 6 values (MAIN_HAND, OFF_HAND, HEAD, ARMOR, ACCESSORY_1, ACCESSORY_2) |
| EquipmentType enum | WEAPON, ARMOR, ACCESSORY | **Removed** — slot determines role |
| Class hierarchy | EquipmentDefinitionData → WeaponDefinitionData / ArmorDefinitionData | EquipmentDefinitionData only (flat) |
| Stat model | `attack_power: float` / `defense: float` | `attribute_bonuses: Dictionary` (AttributeType → float) |
| Bonus integration | `_get_attribute_bonuses()` returns 0.0 | Sums all equipped gear attribute_bonuses |
| GearSelector slots | 8 nodes | 6 nodes |
| Tooltip | "Attack Power: 10" | "+3 Strength, +1 Agility" |
