# Cycling Technique Unlock Integration

**Date:** 2026-04-12
**Status:** Approved
**Depends on:** PR #20 (Path Progression System)

## Overview

Integrate the path progression system's cycling technique unlocks into a new CyclingManager singleton, making unlocked techniques available in the cycling view. Currently, when a player unlocks a cycling technique via a path node, nothing happens -- it's a pass-through. This feature makes those unlocks functional end-to-end.

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Manager ownership | New CyclingManager singleton | Single responsibility; cycling will grow (mastery, bonuses). Keeps CultivationManager focused on advancement. |
| Locked technique UI | Hidden | Only unlocked techniques appear. Simplest implementation; new techniques appearing feels rewarding. |
| Default technique | Foundation Technique (placeholder) | Always unlocked by default. Will be removed in a future change. |
| Unlock signal flow | PathManager calls CyclingManager directly | PathManager calls `CyclingManager.unlock_technique(id)`. No intermediate signal needed. |
| Equipped technique ownership | CyclingManager | CyclingManager owns both unlocked list and equipped technique. CyclingView no longer writes to SaveGameData directly. |
| Save model | String IDs | `Array[String]` of technique IDs in SaveGameData. CyclingManager looks up full resources from CyclingTechniqueList. |
| Technique identification | Separate `id` field | New `id: String` on CyclingTechniqueData (e.g., `"torrent_flow"`). Decoupled from display name. |

## New Singleton: CyclingManager

**File:** `singletons/cycling_manager/cycling_manager.gd`

**Responsibility:** Authoritative owner of all cycling state -- which techniques are unlocked, which is equipped, and technique data lookups.

### State

- Reference to `SaveGameData` (from PersistenceManager, same pattern as CultivationManager)
- Loads `CyclingTechniqueList` resource (the full catalog of all techniques)

### Signals

- `technique_unlocked(technique: CyclingTechniqueData)` -- emitted when a new technique is unlocked
- `equipped_technique_changed(technique: CyclingTechniqueData)` -- emitted when player switches equipped technique

### Public API

| Method | Return | Description |
|--------|--------|-------------|
| `get_unlocked_techniques()` | `Array[CyclingTechniqueData]` | Returns full resource data for all unlocked technique IDs |
| `get_equipped_technique()` | `CyclingTechniqueData` | Returns the currently equipped technique |
| `unlock_technique(technique_id: String)` | `void` | Adds to unlocked list in SaveGameData, emits `technique_unlocked` |
| `equip_technique(technique_id: String)` | `void` | Sets equipped technique in SaveGameData, emits `equipped_technique_changed` |
| `is_technique_unlocked(technique_id: String)` | `bool` | Convenience check |

### Initialization

On `_ready()`: gets SaveGameData reference from PersistenceManager and loads the CyclingTechniqueList resource.

## SaveGameData Changes

**New field:**

```gdscript
@export var unlocked_cycling_technique_ids: Array[String] = ["foundation_technique"]
```

**Changed field:** `current_cycling_technique_name` is renamed to `equipped_cycling_technique_id: String = "foundation_technique"` and now stores the technique ID instead of the display name. CyclingManager reads/writes this field.

No schema migration needed for the new `unlocked_cycling_technique_ids` field -- missing fields use declared defaults. For `equipped_cycling_technique_id` (renamed from `current_cycling_technique_name`), existing saves will have the old field ignored and pick up the new default. Since this is early development and saves are not permanent, this is acceptable.

## CyclingTechniqueData Changes

**New field:**

```gdscript
@export var id: String
```

Added to `scripts/resource_definitions/cycling/cycling_technique/cycling_technique_data.gd`. Each `.tres` technique resource must be updated with a unique snake_case ID (e.g., `"foundation_technique"`, `"torrent_flow"`).

## Data Flow

### Unlock Flow (player activates a path node with UNLOCK_CYCLING_TECHNIQUE)

```
PathManager (applies path node effects)
  -> CyclingManager.unlock_technique(technique_id)
    -> adds technique_id to SaveGameData.unlocked_cycling_technique_ids (if not already present)
    -> looks up CyclingTechniqueData from CyclingTechniqueList by id
    -> emits technique_unlocked(technique: CyclingTechniqueData)
      -> CyclingView rebuilds its technique list (if visible)
```

### CyclingView Query Flow (when view opens or technique list changes)

```
CyclingView._ready() or _on_technique_unlocked()
  -> CyclingManager.get_unlocked_techniques()
    -> returns Array[CyclingTechniqueData]
  -> populates CyclingTabPanel with only unlocked techniques
```

### Equip Flow (player clicks a technique slot)

```
CyclingTechniqueSlot emits technique_change_request(technique)
  -> CyclingView calls CyclingManager.equip_technique(technique.id)
    -> CyclingManager updates SaveGameData.equipped_cycling_technique_id
    -> emits equipped_technique_changed(technique)
  -> CyclingView updates UI
```

## CyclingView Changes

**Current behavior:** Loads ALL techniques from `CyclingTechniqueList` directly and shows them all.

**New behavior:**
- Queries `CyclingManager.get_unlocked_techniques()` instead of loading CyclingTechniqueList directly
- On `_ready()` and when `CyclingManager.technique_unlocked` fires, rebuilds the technique list
- Equip/unequip goes through `CyclingManager.equip_technique()` instead of writing to SaveGameData directly
- `CyclingManager.get_equipped_technique()` replaces the direct SaveGameData read

**CyclingTabPanel:** Receives the filtered list from CyclingView -- no changes to its internal logic beyond receiving fewer items.

**CyclingTechniqueSlot:** No changes needed -- it already just displays what it's given and emits `technique_change_request`.

## PathManager Integration

In the method that applies `UNLOCK_CYCLING_TECHNIQUE` effects (within PathManager), replace the current pass-through with a direct call:

```gdscript
PathNodeEffectData.EffectType.UNLOCK_CYCLING_TECHNIQUE:
    CyclingManager.unlock_technique(effect.string_value)
```

No new signal needed on PathManager. The `string_value` on the path node effect must match the `id` field on the target `CyclingTechniqueData`.

## Autoload Registration

CyclingManager must be registered in `project.godot` as an autoload. It should load after PersistenceManager (needs SaveGameData) and before any scene that references it.

## Files Changed

| File | Change |
|------|--------|
| `singletons/cycling_manager/cycling_manager.gd` | **New** -- CyclingManager singleton |
| `singletons/persistence_manager/save_game_data.gd` | Add `unlocked_cycling_technique_ids` field, rename `current_cycling_technique_name` to `equipped_cycling_technique_id` |
| `scripts/resource_definitions/cycling/cycling_technique/cycling_technique_data.gd` | Add `id: String` field |
| `resources/cycling/techniques/*.tres` | Add `id` values to each technique resource |
| `singletons/path_manager/path_manager.gd` | Call `CyclingManager.unlock_technique()` on UNLOCK_CYCLING_TECHNIQUE effect |
| `scenes/cycling/cycling_view/cycling_view.gd` | Query CyclingManager instead of static list; equip through CyclingManager |
| `project.godot` | Register CyclingManager autoload |

## Out of Scope

- Technique mastery or upgrade systems
- Cycling bonuses from techniques
- UI animations for technique unlock notifications
- Removing Foundation Technique as default (future work)
