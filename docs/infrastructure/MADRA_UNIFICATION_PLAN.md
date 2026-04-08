# Madra Pool Unification — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unify zone Madra and combat Madra into a single economy — cycling fills the pool, adventures drain it, combat uses the drained amount as budget.

**Architecture:** Add adventure budget methods to ResourceManager, modify VitalsManager to accept a starting Madra parameter, wire the spend into AdventureView's start flow, and add a threshold check before adventure actions fire.

**Tech Stack:** Godot 4.6, GDScript

**Source Design:** `docs/infrastructure/MADRA_UNIFICATION_DESIGN.md`

---

## File Map

| Action | File | Responsibility |
|--------|------|---------------|
| Modify | `singletons/resource_manager/resource_manager.gd` | Add adventure budget/threshold methods |
| Modify | `scenes/combat/combatant/vitals_manager/vitals_manager.gd` | Accept starting_madra parameter |
| Modify | `scenes/adventure/adventure_view/adventure_view.gd` | Calculate budget, spend, pass to vitals |
| Modify | `singletons/action_manager/action_manager.gd` | Check threshold before starting adventure |
| No change | `scenes/zones/zone_action_button/zone_action_button.gd` | Threshold check happens in ActionManager |
| No change | `scenes/ui/inkbrush_button/inkbrush_button.gd` | No changes needed |

---

## Task 1: Add Adventure Budget Methods to ResourceManager

**Files:**
- Modify: `singletons/resource_manager/resource_manager.gd`

- [ ] **Step 1: Add three new methods after `can_afford_madra()`**

Find the `can_afford_madra` method (around line 100) and add after it:

```gdscript
## Get the maximum Madra the player can bring into an adventure (Foundation capacity).
func get_adventure_madra_capacity() -> float:
	return 50.0 + CharacterManager.get_foundation() * 10.0

## Get the actual Madra budget for an adventure (limited by current pool).
func get_adventure_madra_budget() -> float:
	return min(get_adventure_madra_capacity(), get_madra())

## Get the minimum Madra required to start an adventure (50% of capacity).
func get_adventure_madra_threshold() -> float:
	return get_adventure_madra_capacity() * 0.5

## Check if the player has enough Madra to start an adventure.
func can_start_adventure() -> bool:
	return get_madra() >= get_adventure_madra_threshold()
```

- [ ] **Step 2: Commit**

```bash
git add singletons/resource_manager/resource_manager.gd
git commit -m "feat(resources): add adventure Madra budget and threshold methods"
```

---

## Task 2: Modify VitalsManager to Accept Starting Madra

**Files:**
- Modify: `scenes/combat/combatant/vitals_manager/vitals_manager.gd`

- [ ] **Step 1: Change `initialize_current_values()` to accept optional starting_madra**

Find the method (around line 85) and replace:

```gdscript
# Before:
func initialize_current_values() -> void:
	current_health = max_health
	current_stamina = max_stamina
	current_madra = max_madra

# After:
func initialize_current_values(starting_madra: float = -1.0) -> void:
	current_health = max_health
	current_stamina = max_stamina
	current_madra = starting_madra if starting_madra >= 0.0 else max_madra
```

The default `-1.0` means "use max" which preserves existing behavior for enemies and any other callers.

- [ ] **Step 2: Commit**

```bash
git add scenes/combat/combatant/vitals_manager/vitals_manager.gd
git commit -m "feat(combat): VitalsManager accepts starting_madra parameter"
```

---

## Task 3: Wire Budget Spending into Adventure Start

**Files:**
- Modify: `scenes/adventure/adventure_view/adventure_view.gd`

- [ ] **Step 1: Replace `_initialize_combat_resources()` to spend from zone pool**

Find the method (around line 173) and replace:

```gdscript
# Before:
func _initialize_combat_resources() -> void:
	PlayerManager.vitals_manager.initialize_current_values()
	player_info_panel.setup_vitals(PlayerManager.vitals_manager)

# After:
func _initialize_combat_resources() -> void:
	var budget: float = ResourceManager.get_adventure_madra_budget()
	ResourceManager.spend_madra(budget)
	PlayerManager.vitals_manager.initialize_current_values(budget)
	player_info_panel.setup_vitals(PlayerManager.vitals_manager)
	Log.info("AdventureView: Spent %.1f Madra from zone pool for adventure budget" % budget)
```

- [ ] **Step 2: Commit**

```bash
git add scenes/adventure/adventure_view/adventure_view.gd
git commit -m "feat(adventure): spend zone Madra on adventure start, pass as combat budget"
```

---

## Task 4: Add Threshold Check Before Adventure Start

**Files:**
- Modify: `singletons/action_manager/action_manager.gd`

- [ ] **Step 1: Add threshold check in `_execute_adventure_action()`**

Find the method (around line 147) and replace:

```gdscript
# Before:
func _execute_adventure_action(action_data: AdventureActionData) -> void:
	Log.info("ActionManager: Executing adventure action: %s" % action_data.action_name)
	start_adventure.emit(action_data)

# After:
func _execute_adventure_action(action_data: AdventureActionData) -> void:
	if not ResourceManager.can_start_adventure():
		var threshold: float = ResourceManager.get_adventure_madra_threshold()
		var current: float = ResourceManager.get_madra()
		Log.info("ActionManager: Cannot start adventure - need %.0f Madra, have %.0f" % [threshold, current])
		if LogManager:
			LogManager.log_message("[color=red]Not enough Madra! Need %.0f, have %.0f[/color]" % [threshold, current])
		_set_current_action(null)
		return
	Log.info("ActionManager: Executing adventure action: %s" % action_data.action_name)
	start_adventure.emit(action_data)
```

- [ ] **Step 2: Commit**

```bash
git add singletons/action_manager/action_manager.gd
git commit -m "feat(adventure): block adventure start below Madra threshold"
```

---

## Task 5: Smoke Test

- [ ] **Step 1: Set Madra to 0 and verify adventure is blocked**

Start the game with 0 Madra. Click "Fight the Baddies!" — should see red log message "Not enough Madra! Need X, have 0" and adventure should NOT start.

- [ ] **Step 2: Cycle to fill Madra above threshold**

Do cycling until Madra reaches the threshold. Verify the exact threshold value: `(50 + Foundation * 10) * 0.5`.

- [ ] **Step 3: Start adventure and verify zone pool drains**

Click adventure. Check that zone Madra orb decreases by the budget amount. Note the budget value.

- [ ] **Step 4: Check combat Madra matches budget**

In combat, verify the Madra bar shows the budget amount (not the Foundation max). Use an ability to confirm it spends from the budget pool.

- [ ] **Step 5: Complete adventure and verify no Madra returns**

Finish the adventure. Zone Madra should NOT increase — what was spent is gone.

- [ ] **Step 6: Verify auto-cycle refill loop**

After adventure, go back to cycling. Verify you can refill Madra and start another adventure. The cycle→adventure loop should feel complete.

---

## Summary of Changes

| What | Before | After |
|------|--------|-------|
| Zone Madra | Accumulates with no sinks | Spent on adventure start |
| Combat Madra | Fresh from Foundation (disconnected) | Drawn from zone pool (capped by Foundation) |
| Adventure entry | Always allowed | Blocked below 50% Foundation capacity |
| Adventure end | Combat Madra evaporates | Same (nothing returns at Foundation stage) |
| VitalsManager | Always initializes to max | Accepts optional starting_madra |
| ResourceManager | No adventure methods | Budget, threshold, and can_start_adventure methods |
