# EndlessPath Test Suite — One-Shot Agent Prompt

## Usage

Paste the prompt below into a fresh Claude Code session, or run headless:

```bash
claude -p "$(cat docs/testing/TEST_SUITE_PROMPT.md)" --allowedTools "Read,Edit,Write,Bash,Grep,Glob,Agent"
```

Or paste everything below the `---` line into a new conversation.

---

## Prompt

You are setting up a comprehensive test suite for EndlessPath, a Godot 4.6 GDScript game. There are currently ZERO tests. Your job is to install a testing framework and write thorough unit tests for every singleton manager and core system.

### Phase 1: Install GUT (Godot Unit Test)

1. Clone GUT into the addons folder:
```bash
cd addons && git clone --depth 1 --branch v9.3.0 https://github.com/bitwes/Gut.git gut && cd ..
```
2. Create `.gutconfig.json` in the project root:
```json
{
  "dirs": ["res://tests/"],
  "prefix": "test_",
  "suffix": ".gd",
  "should_maximize": false,
  "compact_mode": true,
  "opacity": 100,
  "font_size": 20,
  "log_level": 2
}
```
3. Create the test directory: `mkdir -p tests/unit tests/integration`

### Phase 2: Write Unit Tests

For EACH system below, read the source file FIRST, understand the public API, then write tests. Each test file goes in `tests/unit/`. Test file naming: `test_<system_name>.gd`. Every test file extends `GutTest`.

**DO NOT skip any system. DO NOT write placeholder tests. Every test must have real assertions.**

#### 2a. ResourceManager (`singletons/resource_manager/resource_manager.gd`)

Test file: `tests/unit/test_resource_manager.gd`

Test these behaviors:
- `add_madra()` adds correct amount and clamps to max
- `add_madra()` with amount > remaining capacity clamps to max
- `spend_madra()` returns true and deducts when affordable
- `spend_madra()` returns false and doesn't deduct when unaffordable
- `get_madra()` returns current value
- `can_afford_madra()` returns correct boolean
- `add_gold()` / `spend_gold()` / `get_gold()` same patterns
- `get_adventure_madra_capacity()` returns `50 + Foundation * 10`
- `get_adventure_madra_budget()` returns min of capacity and current madra
- `get_adventure_madra_threshold()` returns 50% of capacity
- `can_start_adventure()` returns true/false based on threshold
- `madra_changed` signal fires on add/spend
- `gold_changed` signal fires on add/spend
- Sub-1.0 madra additions don't log messages

#### 2b. CultivationManager (`singletons/cultivation_manager/cultivation_manager.gd`)

Test file: `tests/unit/test_cultivation_manager.gd`

Read the file first. Test:
- `add_core_density_xp()` adds XP correctly
- XP overflow triggers level up
- Multi-level-up works in a single call
- `get_core_density_level()` returns correct level
- `get_core_density_xp()` returns current XP within level
- XP-for-next-level scales correctly per stage formula
- `core_density_xp_updated` signal fires
- `core_density_level_updated` signal fires on level up
- Stage name getter returns correct string

#### 2c. CharacterManager (`singletons/character_manager/character_manager.gd`)

Test file: `tests/unit/test_character_manager.gd`

Test:
- `get_strength()` returns base + equipment bonuses
- `get_foundation()` returns base + equipment bonuses
- All 8 attribute getters work (strength, body, agility, spirit, foundation, control, resilience, willpower)
- `_get_equipment_bonuses()` sums equipped gear attribute_bonuses correctly
- `_get_equipment_bonuses()` returns 0 when no gear equipped
- `_get_equipment_bonuses()` handles null InventoryManager gracefully
- `add_base_attribute()` modifies the base and emits signal
- `get_total_attributes_data()` returns CharacterAttributesData with correct totals

#### 2d. InventoryManager (`singletons/inventory_manager/inventory_manager.gd`)

Test file: `tests/unit/test_inventory_manager.gd`

Test:
- `equip_item()` places item in gear slot
- `equip_item()` swaps existing item to grid when slot occupied
- `unequip_item()` moves item from gear to first available grid slot
- `unequip_item_to_slot()` places item at specific grid index
- `swap_gear_slots()` swaps between two equipped slots
- `move_equipment()` reorders grid items
- `get_equipped_item()` returns correct item or null
- `award_items()` for equipment creates instances and adds to grid
- `award_items()` for materials adds to material dictionary
- `inventory_changed` signal fires on all operations

#### 2e. Combat Damage Formula (`scripts/resource_definitions/combat/combat_effect_data.gd`)

Test file: `tests/unit/test_combat_damage.gd`

Test:
- Base damage calculation: `base_value + (attribute * scaling)`
- Physical damage applies Resilience defense
- Spirit damage applies Spirit defense
- Mixed damage uses (Resilience + Willpower) / 2
- True damage ignores all defense
- Damage reduction formula: `100 / (100 + defense)`
- Zero defense = full damage
- High defense doesn't go negative
- Each attribute scaling works independently

#### 2f. Equipment System (`scripts/resource_definitions/items/equipment/equipment_definition_data.gd`)

Test file: `tests/unit/test_equipment.gd`

Test:
- EquipmentSlot enum has 6 values
- `attribute_bonuses` dictionary stores AttributeType → float
- `_get_item_effects()` returns formatted BBCode strings
- Positive bonuses show with color tag
- Negative bonuses show with different color tag
- Empty bonuses returns empty effects array
- `_init()` sets item_type to EQUIPMENT

### Phase 3: Integration Tests

Test file: `tests/integration/test_adventure_flow.gd`

Test the adventure start flow:
- Adventure blocked when Madra below threshold
- Adventure proceeds when Madra above threshold
- `adventure_start_requested` signal fires on valid start
- `start_adventure` signal carries correct madra_budget
- Madra budget = min(capacity, current)
- VitalsManager receives correct starting_madra

### Phase 4: Verify

Run all tests via CLI to confirm they pass:
```bash
godot --headless -s addons/gut/gut_cmdln.gd -gexit
```

If any tests fail, fix them. Do NOT commit with failing tests.

### Phase 5: Commit

Stage and commit with:
```bash
git add addons/gut tests/ .gutconfig.json
git commit -m "test: add comprehensive unit test suite with GUT framework

Install GUT v9.3.0. Add unit tests for ResourceManager, CultivationManager,
CharacterManager, InventoryManager, combat damage formulas, and equipment system.
Add integration test for adventure start flow.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

### Rules

- Read each source file BEFORE writing its tests
- Every test must have real assertions (`assert_eq`, `assert_true`, `assert_false`, `assert_gt`, etc.)
- Use GUT's `watch_signals()` to test signal emission
- Use `autofree()` for any nodes you create in tests
- If a singleton depends on another (e.g., ResourceManager needs CultivationManager), mock or stub the dependency
- Do NOT modify any game source code — tests only
- If you can't test something due to singleton initialization order, skip it with a comment explaining why and move to the next test
- Aim for 80+ test cases total across all files
