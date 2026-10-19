# Combat System

Last updated: 2026-10-18

## Overview

Combat is a real-time, one-versus-one fight that runs inside an adventure. When the player picks a `CombatChoice` on an adventure tile, the hex map hides and `AdventureCombat` builds two `CombatantNode`s: the player (attributes snapshot + equipped loadout) and the first enemy in the choice's `enemy_pool`. Each side casts abilities that cost Health, Madra or Stamina, may have a cast time, then go on cooldown. Effects deal damage, heal, apply buffs, interrupt casts, or strip buffs. The enemy is driven by `SimpleEnemyAI`. The fight ends the moment either side's Health reaches 0.

There is no AP pool (the GDD's AP/Cycle-skill economy is not built). Health and Madra do not regenerate during an adventure; Stamina regenerates at 1/s. Madra is a per-adventure budget drained from the zone Madra pool when the adventure starts.

This doc covers the combat side. How a fight is triggered from the map and how results feed back into the adventure is in [ADVENTURING.md](../adventuring/ADVENTURING.md). Ability data, unlocks and the loadout are in [ABILITIES.md](../abilities/ABILITIES.md); per-ability numbers are in [ABILITIES_MATRIX.md](../abilities/ABILITIES_MATRIX.md).

## Player Experience

1. On the adventure map the player reaches a combat tile (regular, elite or boss) and picks its combat choice, e.g. "Attack the Spirit".
2. The map hides. The combat view shows the zone background with a vignette, drifting mist and motes. The player's info panel moves to the left-centre of the screen (`(390, 500)`); the enemy's panel sits to its right. There are no character sprites; each panel has a portrait, and both portraits are currently the player sprite.
3. Each panel shows the combatant's name, Health/Madra/Stamina bars with `current / max` values (plus `(x/s)` when a regen rate is set, i.e. Stamina), a row of buff icons, and a row of ability buttons.
4. Player buttons show the bound key (Q/W/E/R by loadout slot), a cost strip (Madra blue, Stamina gold, Health red), and a cooldown overlay with seconds left. Every player ability starts the fight on a 1.5 s cooldown.
5. The player clicks a button or presses its key. Instant abilities fire immediately; abilities with a cast time replace the button row with a casting indicator (ability name, draining bar, `time_left / total s`). Only one cast runs at a time. Unaffordable abilities dim to 35% and the missing resource's cost turns red.
6. The enemy acts on its own. Its casts show in the casting indicator on its panel, which is the window for Empty Palm's interrupt. Enemy abilities with no cooldown can start casting on the first frame and repeat back to back.
7. Hovering an ability shows a tooltip (icon, name, CD, cast time, costs, and a pre-defense DMG total for the first target effect). Hovering a buff icon shows its name, effect, live remaining time and stacks.
8. Health and Madra changes float up from the bar as red `-N` / green `+N` numbers, and a ghost bar trails damage. The log window records damage taken, heals, interrupts and buff strips.
9. When the enemy reaches 0 Health the player wins gold and returns to the map; beating the boss ends the adventure as a victory. When the player reaches 0 Health the adventure ends in defeat. Either way the end card shows when the adventure ends.
10. Health, Madra and Stamina carry over to the next fight in the same adventure. Buffs and cooldowns do not.

## Architecture

### Scene composition during a fight

```
AdventureView (Control)                          adventure_view.gd (adventure-owned host)
├── ZoneViewBackground                           parallax backdrop, visible behind map and combat
├── TilemapView/…/AdventureTilemap               emits start_combat(choice)
├── CombatView (Control, hidden outside combat)
│   └── CombatSubviewportContainer/SubViewport   1920x1080
│       └── AdventureCombat (Node2D)             adventure_combat.gd
│           ├── Atmosphere                       instanced in _setup_atmosphere(), moved to index 0
│           ├── CanvasLayer
│           │   └── EnemyInfoPanel (CombatantInfoPanel)
│           ├── CastTimer (Label)                stray placeholder text, unreferenced
│           ├── PlayerCombatant (CombatantNode)  created per fight
│           └── EnemyCombatant (CombatantNode)   created per fight
│               └── EnemyAI (SimpleEnemyAI)      added when enable_ai is true
└── PlayerInfoPanel (CombatantInfoPanel)         persistent; (170, 872) on the map, (390, 500) in combat
```

### CombatantNode (`combatant_node.tscn`)

```
CombatantNode (Node2D)                 combatant_node.gd
├── CombatAbilityManager (Node)        combat_ability_manager.gd
│   └── AbilityInstance_<name> (Node)  combat_ability_instance.gd, created in code per AbilityData
│       ├── Timer (cooldown, one-shot)
│       └── Timer (cast, one-shot)
├── VitalsManager (Node)               vitals_manager.gd (used by enemies; the player uses PlayerManager's)
├── CombatEffectManager (Node)         combat_effect_manager.gd (scene root is named CombatEffectProcessor)
└── CombatBuffManager (Node)           combat_buff_manager.gd
    └── Timer (DoT tick, 1 s, runs only while a DoT is active)
```

There is no sprite node; `_update_visuals()` is an empty stub.

### CombatantInfoPanel (`combatant_info_panel.tscn`)

```
CombatantInfoPanel (Control)                      combatant_info_panel.gd
├── HBoxContainer
│   ├── MainVBox
│   │   ├── VitalsPanel (panel_vitals.tres)
│   │   │   └── VitalsHBox
│   │   │       ├── PortraitColumn: ProfileIconRect, NameLabel (LabelHeading)
│   │   │       └── BarsColumn: HealthProgressBar, MadraProgressBar, StaminaProgressBar (ResourceBar)
│   │   └── AbilitiesPanel (panel_abilities.tres) abilities_panel.gd, hidden until setup_abilities()
│   │       └── MarginContainer
│   │           ├── AbilitiesContainer (HBox)     AbilityButton instances
│   │           └── CastingIndicator (VBox)       AbilityInformation, AbilityTypeIcon (unused),
│   │                                             ProgressBar (cast_bar_fill.tres) + CastTimer label
│   └── BuffContainer (HBox)                      BuffIcon instances
├── CombatAbilityTooltip
└── CombatBuffTooltip
```

### Ability button and buff icon

```
AbilityButton (MarginContainer)              ability_button.gd
└── BackgroundRect (TextureRect, border art)
    ├── Button (TextureButton, ability icon)
    │   └── CooldownProgressBar → CooldownLabel
    ├── KeyHintPanel (panel_keyhint.tres) → KeyHintLabel
    └── CostStrip (panel_keyhint.tres) → MadraCostLabel, StaminaCostLabel, HealthCostLabel

BuffIcon (MarginContainer)                   buff_icon.gd
└── BackgroundRect → BuffTexture → DurationProgressBar, DurationLabel, StackLabel
```

## Data Model

### CombatantData (`scripts/resource_definitions/combat/combatant_data.gd`)

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| `character_name` | `String` | `"Combatant"` | Panel name and log label |
| `attributes` | `CharacterAttributesData` | new instance (all 10) | Offense scaling, defense, vitals maxima |
| `abilities` | `Array[AbilityData]` | `[]` | One `CombatAbilityInstance` each, in array order |
| `texture` | `Texture2D` | null | Not read anywhere |
| `scale` | `float` | 1.0 | Not read anywhere |
| `offset` | `Vector2` | `(0, 0)` | Not read anywhere |
| `base_gold_drop` | `int` | 0 | Base of the victory gold formula |

The player's `CombatantData` is built in code each fight: name `"Player"`, `attributes = CharacterManager.get_total_attributes_data()` (base + equipment, snapshot), `abilities = AbilityManager.get_equipped_abilities()` (slot order, empty slots skipped).

### CharacterAttributesData — combat roles

8 `@export float` fields (`strength`, `body`, `agility`, `spirit`, `foundation`, `control`, `resilience`, `willpower`), all defaulting to `10.0`, read through `get_attribute(AttributeType)`. Full attribute docs: [CHARACTER.md](../infrastructure/CHARACTER.md).

| Attribute | Offense (scaling coefficient on) | Defense | Vitals | Effective today |
|-----------|----------------------------------|---------|--------|-----------------|
| `STRENGTH` | basic_strike 1.0, famishing_bite 1.0 | — | — | Yes |
| `BODY` | — | — | Max Health = BODY × 10, Max Stamina = BODY × 5 | Yes |
| `AGILITY` | basic_strike 0.5, empty_palm 0.3 | — | — | Damage only |
| `SPIRIT` | empty_palm 1.0, power_font 1.5, madra_lash 1.0, coalesce (heal) 3.0 | vs `SPIRIT` damage | — | Yes |
| `FOUNDATION` | power_font 0.5 | — | Max Madra = FOUNDATION × 10 (also the adventure Madra capacity) | Yes |
| `CONTROL` | — | — | — | No effect |
| `RESILIENCE` | — | vs `PHYSICAL`; half of `MIXED` | — | Yes |
| `WILLPOWER` | — | half of `MIXED` | — | No effect (no ability deals `MIXED`) |

The `AttributeType` doc comments describe roles that are not implemented (AGILITY "evasion, and cooldown reduction", CONTROL "madra cost reduction", FOUNDATION "regeneration").

### CombatEffectData (`scripts/resource_definitions/combat/combat_effect_data.gd`)

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| `effect_type` | `EffectType` | `DAMAGE` | `DAMAGE`, `HEAL`, `BUFF`, `CANCEL_CAST`, `STRIP_BUFFS` |
| `effect_name` | `String` | `""` | Used in `Log` lines only |
| `effect_description` | `String` | `""` | Not read anywhere |
| `base_value` | `float` | 0.0 | Flat value before scaling |
| `percentage_value` | `float` | 0.0 | Not read anywhere |
| `strength_scaling` … `willpower_scaling` | `float` ×8 | 0.0 | Added as `caster_attribute × coefficient` |
| `damage_type` | `DamageType` | `PHYSICAL` | `PHYSICAL`, `SPIRIT`, `TRUE`, `MIXED` |

`calculate_value(caster)` returns `base_value + Σ(attribute × scaling)` and logs each term. `calculate_damage(caster, target)` applies defense (below).

### BuffEffectData (`buff_effect_data.gd`, extends CombatEffectData)

`_init()` forces `effect_type = BUFF`. `validate()` requires a non-empty `buff_id` and `duration > 0`.

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| `buff_id` | `String` | `""` | Identity for refresh/stack lookup; tooltip title is `buff_id.capitalize()` |
| `buff_icon` | `Texture2D` | null | BuffIcon and tooltip art |
| `duration` | `float` | 5.0 | Seconds; refreshed to full on re-apply |
| `buff_type` | `BuffType` | `ATTRIBUTE_MODIFIER_MULTIPLICATIVE` | See below |
| `attribute_modifiers` | `Dictionary[AttributeType, float]` | `{}` | Multipliers on the caster's attributes |
| `dot_damage_per_tick` | `float` | 0.0 | Per 1 s tick, × stack count |
| `dot_damage_type` | `DamageType` | `TRUE` | Not read anywhere |
| `damage_multiplier` | `float` | 1.0 | Outgoing or incoming damage multiplier |
| `consume_on_use` | `bool` | false | Removed after the first proc |

| BuffType | Effect | Re-apply behavior |
|----------|--------|-------------------|
| `ATTRIBUTE_MODIFIER_MULTIPLICATIVE` | Multiplies the owner's attributes when the owner casts (offense only) | Refresh duration |
| `DAMAGE_OVER_TIME` | `dot_damage_per_tick × stack_count` raw Health loss every 1 s | Refresh + add stack |
| `OUTGOING_DAMAGE_MODIFIER` | Multiplies the owner's outgoing damage by `damage_multiplier ^ stack_count` | Refresh + add stack |
| `INCOMING_DAMAGE_MODIFIER` | Multiplies damage the owner takes by `damage_multiplier` | Refresh duration |

### ActiveBuff (`active_buff.gd`, RefCounted)

Runtime record per applied buff: `buff_data`, `time_remaining`, `stack_count` (starts at 1), `is_consumed`. `tick(delta)` returns true when expired or consumed.

### AbilityData

Costs (`health_cost`, `madra_cost`, `stamina_cost`), `base_cooldown`, `cast_time`, and two effect lists: `effects_on_target` (sent to the enemy) and `effects_on_self` (sent to the caster). Predicates such as `deals_damage()` are derived from those lists. Full field list in [ABILITIES.md](../abilities/ABILITIES.md#data-model).

## Core Systems

### Vitals (`VitalsManager`)

| Value | Formula | Regen |
|-------|---------|-------|
| Max Health | `BODY × 10` | `health_regen` (always 0) |
| Max Stamina | `BODY × 5` | `stamina_regen`: `1.0 × AdventureActionData.stamina_regen_modifier` during an adventure, 0 otherwise (set by `AdventureView._update_stamina_regen()`) |
| Max Madra | `CharacterAttributesData.get_max_madra()` = `FOUNDATION × 10` | `madra_regen` (always 0) |

- Maxima are recomputed when `character_attributes_data` is assigned. `apply_vitals_change(health, stamina, madra)` clamps each value to `[0, max]`; regen is applied in `_process`.
- Every `current_*` assignment emits its `*_changed` signal, even when the value does not change, and `apply_vitals_change()` assigns all three values, so any call emits all three signals.
- **Player:** one persistent `VitalsManager` owned by `PlayerManager` (`is_player = true`). In `_ready` it connects to `CharacterManager.base_attribute_changed` and re-pulls `get_total_attributes_data()`. At adventure start `AdventureView` calls `initialize_current_values(madra_budget)`: full Health and Stamina, Madra = the budget drained from the zone pool (`min(FOUNDATION × 10, Madra pool)`). Stamina is also spent on map movement (see ADVENTURING.md).
- **Enemy:** `CombatantNode.setup()` uses the node's own `VitalsManager`, assigns the enemy attributes, and starts at full Health, Stamina and Madra.

### Ability lifecycle

1. **Request.** `AbilitiesPanel` emits `ability_selected(instance)` on click or key; `CombatantInfoPanel` re-emits it; `AdventureCombat.on_player_ability_selected()` calls `player.ability_manager.use_ability_instance(instance, enemy)`. The AI calls the same method.
2. **Gate** — `CombatAbilityManager.can_cast_ability_instance()`: the instance belongs to this manager; no instance of this combatant is casting (global lock); the instance is ready (cooldown timer stopped and not casting); `AbilityData.can_afford(vitals)`. Failures log a warning and return false.
3. **Pay.** `AbilityData.consume_costs(vitals)` deducts all costs at cast start. Cancelled casts are not refunded.
4. **Cast.** `CombatAbilityInstance.start_cast(target)`. If `cast_time > 0`: `is_casting = true`, cast timer starts, `cast_started` emits, and `cast_updated` emits every frame; on timeout `execute_ability()` runs, then `cast_finished` emits. If `cast_time == 0`: `execute_ability()` runs immediately.
5. **Execute** — `execute_ability(target)`:
   - starts the cooldown (`base_cooldown`), so cooldowns begin when the cast resolves;
   - builds caster attributes with buff multipliers (`_get_modified_attributes()`);
   - if `deals_damage()`, calls `buff_manager.consume_outgoing_modifier()` once per cast;
   - sends each `effects_on_target` entry to `target.receive_effect(effect, attrs, outgoing_modifier)`;
   - then sends each `effects_on_self` entry to the caster with modifier 1.0.
6. **Cancel.** `cancel_cast()` (via `CombatAbilityManager.cancel_current_cast()`) stops the cast timer, clears `is_casting`, starts the full cooldown and emits `cast_cancelled`.

Cooldown rules: `INITIAL_COOLDOWN = 1.5` s is started in `_ready`, but `_start_cooldown()` does nothing when `base_cooldown <= 0`. Abilities with a 0 s base cooldown therefore have no opening cooldown and no post-cancel cooldown. `cooldown_started` always reports `base_cooldown` as its duration.

### Effect resolution (`CombatEffectManager.process_effect`)

The receiving combatant processes each effect against itself.

| EffectType | Resolution |
|------------|------------|
| `DAMAGE` | `effect.calculate_damage(source_attrs, own combatant_data.attributes)` → × outgoing modifier → × `buff_manager.consume_incoming_modifier()` → `apply_vitals_change(-damage)` → log line `<Name> took N Damage` |
| `HEAL` | `effect.calculate_value(source_attrs)` → `apply_vitals_change(+heal)` → log line `<Name> healed for N Health`. No modifiers, no defense |
| `BUFF` | Cast to `BuffEffectData` and `buff_manager.apply_buff()` |
| `CANCEL_CAST` | `ability_manager.cancel_current_cast()`; logs `<Name>'s cast was interrupted!` only if a cast was cancelled |
| `STRIP_BUFFS` | `buff_manager.strip_all_buffs()`; logs `<Name>'s buffs were stripped!` (also when there were none) |

### Damage formula

```
raw     = base_value + Σ (caster_attribute[i] × scaling[i])     # caster attrs include buff multipliers
reduced = raw × 100 / (100 + defense)                            # skipped for TRUE
final   = reduced × outgoing_modifier × incoming_modifier
```

| DamageType | Defense attribute (target) |
|------------|----------------------------|
| `PHYSICAL` | `RESILIENCE` |
| `SPIRIT` | `SPIRIT` |
| `MIXED` | `(RESILIENCE + WILLPOWER) / 2` |
| `TRUE` | none |

Defense reads the target's unmodified `combatant_data.attributes`; attribute buffs on the target never change its defense. Log lines truncate damage to an integer. Worked numbers per ability are in [ABILITIES_MATRIX.md](../abilities/ABILITIES_MATRIX.md).

### Buffs (`CombatBuffManager`)

- `apply_buff(data)`: validates, then either refreshes the existing buff with the same `buff_id` (`buff_refreshed`, plus `add_stack()` and `buff_stacked` for DoT and outgoing-damage buffs) or creates an `ActiveBuff` (`buff_applied`). Starts the DoT timer when a DoT is applied.
- `_process` ticks every buff and removes expired or consumed ones (`buff_removed`).
- `get_attribute_modifier(attr)`: product of all attribute-modifier multipliers for that attribute.
- `consume_outgoing_modifier()`: product of `damage_multiplier ^ stack_count` over unconsumed outgoing buffs; marks `consume_on_use` buffs consumed.
- `consume_incoming_modifier()`: product of unconsumed incoming multipliers (stacks ignored); marks `consume_on_use` buffs consumed. Called once per incoming `DAMAGE` effect.
- DoT: every 1 s, `dot_damage_per_tick × stack_count` is applied as a raw Health change — no defense, no modifiers, no log line.
- `strip_all_buffs()`: mid-combat wipe (Power Font); emits `buff_removed` per buff and stops the DoT timer. `clear_all_buffs()`: end-of-combat cleanup from `AdventureCombat.stop()`.
- No stack cap. Outgoing stacks compound: Hunger (×1.5) gives 1.5, 2.25, 3.375, 5.06… as long as each bite lands within the 10 s refresh window.

### Enemy AI (`SimpleEnemyAI`)

Runs every frame while `active` and both combatants exist:

1. Skip if the enemy is casting.
2. Sort a copy of the enemy's ability instances by `base_cooldown`, longest first.
3. Take the first one where `can_cast_ability_instance()` passes and `_should_cast_ability()` is true. Heal-self abilities (`heals_self()`) only qualify when missing Health ≥ `get_total_self_heal()` (no overheal); everything else always qualifies.
4. `use_ability_instance(ability, player)`.

There is no targeting choice, priority list, or reaction to the player's casts. Because the AI checks every frame, a 0 s-cooldown ability is recast as soon as the previous cast resolves.

### Combat start and end (combat side)

Start — `AdventureView._on_start_combat(choice)`:
1. `AdventureCombat.initialize_combat(choice, action_data)` stores the context and connects `PlayerManager.vitals_manager.health_changed` (once; never disconnected).
2. `AdventureCombat.start()` → `_create_player_combatant()` (`setup(data, PlayerManager.vitals_manager, true)`) then `_create_enemy_combatant()`: `enemy_pool[0]`, own vitals, `EnemyInfoPanel` setup (name, vitals, buffs, abilities), `SimpleEnemyAI` child, enemy `health_changed` connection.
3. `AdventureView` wires the persistent `PlayerInfoPanel` (`setup_buffs`, `setup_abilities`, `ability_selected` → `on_player_ability_selected`), moves it, and swaps the tilemap view for the combat view.

End:
- Enemy Health ≤ 0 → `_calculate_gold_reward()` → `EventManager.trigger_event("q_first_steps_enemy_defeated")` (every victory; EventManager de-duplicates) → `trigger_combat_end(true, gold)`.
- Player Health ≤ 0 → `trigger_combat_end(false, 0)`.
- `AdventureView._on_stop_combat()` restores the map view and clears `is_in_combat`. It then calls `AdventureCombat.stop()`, which resets `EnemyInfoPanel`, runs `clear_all_buffs()` on both sides and `queue_free()`s both combatants. Next it calls `AdventureTilemap.handle_combat_result(successful, gold)`, and on defeat `ActionManager.stop_action(false)`. A boss win ends the adventure from inside `handle_combat_result()`. Because `is_in_combat` is already false at that point, `stop_adventure()` doesn't end the fight a second time.

Gold: `floor(base_gold_drop × CombatChoice.gold_multiplier × AdventureActionData.gold_multiplier × CharacterManager.get_gold_multiplier())`. All three multipliers are 1.0 in current content (`get_gold_multiplier()` is a stub).

### Signals

| Emitter | Signal | Listener |
|---------|--------|----------|
| `AdventureTilemap` | `start_combat(choice)` | `AdventureView._on_start_combat` |
| `AdventureCombat` | `trigger_combat_end(is_successful, gold_earned)` | `AdventureView._on_stop_combat` |
| `VitalsManager` | `health_changed`, `madra_changed`, `stamina_changed` | `CombatantInfoPanel.update_labels`; `AdventureCombat` death checks (health) |
| `CombatAbilityInstance` | `cooldown_started`, `cooldown_updated`, `cooldown_ready` | `AbilityButton` |
| `CombatAbilityInstance` | `cast_started`, `cast_updated`, `cast_finished`, `cast_cancelled` | `AbilitiesPanel` (casting indicator); `AbilityButton` (`cast_started`/`cast_finished` only) |
| `CombatAbilityManager` | `ability_registered`, `ability_used` | none |
| `CombatBuffManager` | `buff_applied`, `buff_removed`, `buff_refreshed`, `buff_stacked` | `CombatantInfoPanel` |
| `AbilityButton` | `pressed`, `hovered(instance)`, `unhovered` | `AbilitiesPanel` |
| `AbilitiesPanel` / `CombatantInfoPanel` | `ability_selected(instance)` | `AdventureCombat.on_player_ability_selected` (player panel only) |
| `BuffIcon` | `hovered(buff_data)`, `unhovered` | `CombatantInfoPanel` (buff tooltip) |

## Combat UI

| Component | Script | Behavior |
|-----------|--------|----------|
| `CombatantInfoPanel` | `combatant_info_panel.gd` | Portrait (`profile_texture` export, set in the scene), name, three `ResourceBar`s, buff row, `AbilitiesPanel`. Syncs buff icon durations from `ActiveBuff.time_remaining` every frame. Auto-cleans when the buff/ability managers leave the tree |
| `ResourceBar` | `resource_bar.gd` | Label `Prefix: cur / max` (+ `(x/s)` when regen ≠ 0). Damage drops the main bar and starts a 0.5 s ghost timer, then a 0.5 s tween; heals move both bars. Floating `-N`/`+N` text unless the new value equals max. Stamina has floating text disabled |
| `FloatingText` | `scenes/ui/floating_text/floating_text.gd` | Rises 100 px over 1.5 s, starts fading after 0.45 s, frees itself |
| `AbilitiesPanel` | `abilities_panel.gd` | One `AbilityButton` per instance; slot index from `AbilityManager.get_ability_at_slot()`; Q/W/E/R input; casting indicator; owns the ability tooltip |
| `AbilityButton` | `ability_button.gd` | Icon, key hint (slot 0–3 → Q/W/E/R; hidden for enemy abilities), cost strip, cooldown overlay (`time_left / base_cooldown`) and `"%.1f (s)"` label; when ready and unaffordable: icon alpha 0.35, border `#553333`, missing costs `#E06060` |
| `BuffIcon` | `buff_icon.gd` | Icon, duration bar and `"%.1fs"`, stack count when > 1 |
| `CombatAbilityTooltip` | `combat_ability_tooltip.gd` | Icon, name, `AbilityStatsDisplay` in `TIMING_COSTS` and `DAMAGE_TOTAL` modes; damage row hidden for abilities with no target effects. Hidden on unhover or key press |
| `CombatBuffTooltip` | `combat_buff_tooltip.gd` | Name (`buff_id.capitalize()`), generated effect text, live `x.xs remaining`, `xN stacks` |

Keybindings (`project.godot`, physical keys):

| Action | Key | Handler |
|--------|-----|---------|
| `ability_slot_1` … `ability_slot_4` | Q / W / E / R | `AbilitiesPanel._unhandled_input` → ability in loadout slot 0–3 (ignored if its button is disabled) |
| `open_abilities` | A | Opens/closes the Abilities view from the zone view (not available during adventures) |

Styleboxes in use: `assets/styleboxes/combat/panel_vitals.tres`, `panel_abilities.tres`, `cast_bar_fill.tres`, `panel_keyhint.tres` (key hint and cost strip, also the loadout slot hint). `panel_buffs.tres` is unreferenced.

## Integration Points

| System | Direction | Connection |
|--------|-----------|------------|
| Adventure (`AdventureView`, `AdventureTilemap`) | in / out | `start_combat(choice)` starts a fight; `trigger_combat_end` → `handle_combat_result()` awards gold (`ResourceManager.add_gold`), applies `CombatChoice.success_effects`/`failure_effects`, completes the tile, or ends the run on a boss win. See [ADVENTURING.md](../adventuring/ADVENTURING.md) |
| `AbilityManager` | in | `get_equipped_abilities()` → player abilities; `get_ability_at_slot()` → key hints and key routing |
| `CharacterManager` | in | `get_total_attributes_data()` snapshot at fight start; `base_attribute_changed` refreshes player vitals maxima; `get_gold_multiplier()` |
| `PlayerManager` | in / out | Persistent player `VitalsManager` shared by map and combat |
| `ResourceManager` | in | Adventure Madra budget becomes starting combat Madra |
| `EventManager` | out | `q_first_steps_enemy_defeated` on victory (Foundation Beat 2 quest step) |
| `LogManager` | out | Damage, heal, interrupt and strip lines; `AdventureView` logs encounter, victory and defeat |
| `Atmosphere` | — | Instanced by `AdventureCombat._setup_atmosphere()` with radius 0.5, softness 0.35, 25 cyan / 8 warm motes |
| Dev panel | in | `AdventureView.force_win_combat()` emits `trigger_combat_end(true, 0)` directly (no gold, no quest event) |

## Existing Content

### Enemies

`resources/combat/combatant_data/`. Attributes not listed are 10.0. Vitals follow the formulas above.

| Enemy (`.tres`) | Name | Non-default attributes | Health / Stamina / Madra | Abilities | Gold | Texture |
|-----------------|------|------------------------|--------------------------|-----------|------|---------|
| `amorphous_spirit` | Amorphous Spirit | none | 100 / 50 / 100 | `madra_lash` | 15 | none |
| `coalescing_spirit` | Coalescing Spirit | BODY 20, SPIRIT 25 | 200 / 100 / 100 | `madra_lash`, `coalesce` | 0 (unset) | none |
| `starving_dreadbeast` | Starving Dreadbeast | BODY 8.5, FOUNDATION 12 | 85 / 42.5 / 120 | `famishing_bite` | 20 | none |
| `ravenous_dreadbeast` | Ravenous Dreadbeast | STRENGTH 15, BODY 8.5, FOUNDATION 12 | 85 / 42.5 / 120 | `famishing_bite` | 20 | none |

Threat against a default player (all attributes 10, 100 Health):

| Enemy | Attack | Per hit | Cadence | Notes |
|-------|--------|---------|---------|-------|
| Amorphous Spirit | Madra Lash (SPIRIT) | 9.1 | 2 s cast, back to back | Interruptible by Empty Palm, recast immediately |
| Coalescing Spirit | Madra Lash (SPIRIT) | 22.7 | 2 s cast | Its SPIRIT 25 cuts incoming SPIRIT damage to 80% of raw (91% at SPIRIT 10) |
| Coalescing Spirit | Coalesce (heal) | +75 Health | 5 s cast, 30 s cooldown | Only when missing ≥ 75 Health; first use after 1.5 s |
| Starving Dreadbeast | Famishing Bite (PHYSICAL) | 9.1 × 1.5^(n−1) | 3 s cast, back to back | Hunger stacks after each bite; 5th bite ≈ 46, 6th ≈ 69 |
| Ravenous Dreadbeast | Famishing Bite (PHYSICAL) | 13.6 × 1.5^(n−1) | 3 s cast, back to back | Same Hunger stacking |

Enemy abilities live in `resources/combat/combatant_data/enemy_abilities/` and are not in the player catalog; full values in [ABILITIES_MATRIX.md](../abilities/ABILITIES_MATRIX.md#enemy-abilities).

### Encounters that start combat

All are in `resources/adventure/encounters/shallow_woods/combat_encounters/` and used by The Shallow Woods. Every `CombatChoice` has one enemy and `gold_multiplier = 1.0`.

| Encounter | Type | Enemy | Choice label | Rewards beyond gold | Shallow Woods quota |
|-----------|------|-------|--------------|---------------------|---------------------|
| `amorphous_spirit_encounter` | COMBAT_REGULAR | `amorphous_spirit` | Attack the Spirit | — | 4 |
| `starving_dreadbeast_encounter` | COMBAT_REGULAR | `starving_dreadbeast` | Attack the Dreadbeast | — | 3 |
| `coalescing_spirit_encounter` | COMBAT_ELITE | `coalescing_spirit` | Attack the Spirit | — | 2 |
| `ravenous_dreadbeast_encounter` | COMBAT_ELITE | `ravenous_dreadbeast` | Attack the Dreadbeast | 25% Dreadbeast Tooth Necklace | 2 |
| `manifested_spirit_encounter` | COMBAT_BOSS (`is_boss`) | `amorphous_spirit` | Confront the Boss | Ends the adventure as a victory | boss |

### Player abilities

`basic_strike`, `enforce` (innate) and `empty_palm`, `power_font` (Pure Madra path). See [ABILITIES_MATRIX.md](../abilities/ABILITIES_MATRIX.md).

## Key Files

| File | Purpose |
|------|---------|
| `scenes/combat/adventure_combat/adventure_combat.gd` / `.tscn` | Fight orchestrator: combatant creation, AI, death checks, gold |
| `scenes/combat/combatant/combatant_node.gd` / `.tscn` | Combatant composition root, `receive_effect()` |
| `scenes/combat/combatant/combat_ability_manager/combat_ability_manager.gd` | Gate checks, cost payment, `cancel_current_cast()` |
| `scenes/combat/combatant/combat_ability_manager/combat_ability_instance.gd` | Cast, cooldown, execution, cancel |
| `scenes/combat/combatant/combat_effect_manager/combat_effect_manager.gd` | Effect routing and damage application |
| `scenes/combat/combatant/combat_buff_manager/combat_buff_manager.gd` | Buffs, stacking, modifiers, DoT |
| `scenes/combat/combatant/combat_buff_manager/active_buff.gd` | Runtime buff record |
| `scenes/combat/combatant/vitals_manager/vitals_manager.gd` | Health / Madra / Stamina |
| `scenes/combat/ai/simple_enemy_ai.gd` | Enemy decision loop |
| `scenes/ui/combat/combatant_info_panel/combatant_info_panel.gd` | Combatant panel (vitals, buffs, abilities) |
| `scenes/ui/combat/combatant_info_panel/resource_bar.gd` | Vitals bar with ghost trail and floating text |
| `scenes/ui/combat/abilities_panel.gd` | Ability row, keybindings, casting indicator |
| `scenes/ui/combat/ability_button/ability_button.gd` | Ability button |
| `scenes/ui/combat/buff_icon/buff_icon.gd` | Buff icon |
| `scenes/ui/combat/combat_ability_tooltip/combat_ability_tooltip.gd` | Ability tooltip |
| `scenes/ui/combat/combat_buff_tooltip/combat_buff_tooltip.gd` | Buff tooltip |
| `scripts/resource_definitions/combat/combatant_data.gd` | `CombatantData` |
| `scripts/resource_definitions/combat/combat_effect_data.gd` | `CombatEffectData`, damage formula |
| `scripts/resource_definitions/combat/buff_effect_data.gd` | `BuffEffectData` |
| `scripts/resource_definitions/abilities/ability_data.gd` | `AbilityData`, costs, predicates |
| `singletons/player_manager/player_manager.gd` | Owns the persistent player `VitalsManager` |
| `resources/combat/combatant_data/` | Enemy definitions and enemy abilities |
| `tests/unit/test_combat_damage.gd`, `test_combat_effect_types.gd`, `test_combat_buff_manager_stacking.gd`, `test_combat_buff_manager_strip.gd`, `test_combat_ability_instance_cancel.gd`, `test_adventure_combat_victory_event.gd`, `test_adventure_combat_count.gd` | Unit tests |
| `tests/integration/test_empty_palm_interrupt.gd`, `test_power_font_buff_strip.gd` | Integration tests (real `.tres` through the effect pipeline) |

## Work Remaining

### Bugs

- `[MEDIUM]` Equipment never updates the player's vitals maxima. The player `VitalsManager` recomputes max Health/Stamina/Madra only on `CharacterManager.base_attribute_changed` (`vitals_manager.gd` `_ready`). Equipping Reinforced Robes (+4 BODY) or Leeching Ring (+2 FOUNDATION) leaves max Health/Madra unchanged until a base attribute changes or the game restarts, while damage and defense already use the new totals.
- `[MEDIUM]` Defense ignores buffs. `CombatEffectManager.process_effect()` passes the target's unmodified `combatant_data.attributes` to `calculate_damage()`, so RESILIENCE/SPIRIT/WILLPOWER attribute buffs do nothing defensively.
- `[MEDIUM]` Enemy ability tooltips show the player's numbers. `AbilityStatsDisplay` always reads `CharacterManager.get_total_attributes_data()`, so hovering Coalescing Spirit's Madra Lash shows a DMG value from the player's SPIRIT (10 on a new save) instead of the spirit's 25.
- `[LOW]` 0 s-cooldown abilities skip the opening cooldown and the post-interrupt cooldown (`CombatAbilityInstance._start_cooldown()` returns early when `base_cooldown <= 0`). Madra Lash and Famishing Bite start casting on frame 1, and an Empty Palm interrupt only restarts their cast.
- `[LOW]` `AdventureCombat._on_player_health_changed` stays connected to the player `VitalsManager` after combat. A lethal non-combat Health change during an adventure (e.g. a trap's `ChangeVitalsEffectData`) is reported as a combat defeat (`_combats_fought` + 1, `handle_combat_result(false)`). Latent: `test_trap_encounter` (−10 Health) is not in any adventure.
- `[LOW]` `CombatantInfoPanel.setup_buffs()` reads `buff.time_left`, but `ActiveBuff` has `time_remaining`. It errors if a panel attaches to a manager that already has buffs (does not happen today).
- `[LOW]` `AbilityButton` does not listen to `cast_cancelled`; after an interrupt its `_is_casting` stays true and affordability visuals stop updating for that button.
- `[LOW]` `CombatAbilityTooltip.position_below()`: the doc comment says "above", the code places it below the panel, and the overflow check compares `y` with 1920 (window width) instead of the viewport height.
- `[LOW]` `FloatingText._ready()` sets font size with `add_theme_constant_override("font_size", 24)`, which does not change a Label's font size (needs a font-size override).

### Missing Functionality

- `[HIGH]` Attribute design pass. CONTROL and WILLPOWER have no combat effect (no ability deals `MIXED`), AGILITY is only a damage coefficient, and the `AttributeType` comments promise evasion, cooldown and cost reduction that do not exist. Current gear already grants inert stats (Cultivator's Cowl +3 WILLPOWER, Leeching Ring +2 CONTROL).
- `[HIGH]` Only `enemy_pool[0]` is used (`_create_enemy_combatant()`, `_calculate_gold_reward()`): no random pick and no multi-enemy fights.
- `[MEDIUM]` No buff stack cap. Outgoing-damage and DoT stacks are unbounded and outgoing stacks compound; a dreadbeast that bites every 3 s doubles its damage roughly every 5 s until Power Font (a path unlock) strips it. Add a `max_stacks` field to `BuffEffectData`.
- `[MEDIUM]` No in-combat resource economy beyond Stamina regen. No AP or Cycle skill (GDD), no Madra or Health regen, and the Iron Will path node's `stamina_recovery_mult` is never applied.
- `[MEDIUM]` Casts are only interrupted by `CANCEL_CAST`; damage never interrupts (the Power Font spec assumed it does).
- `[MEDIUM]` No combat feedback beyond floating numbers: no hit, interrupt or strip VFX/SFX (`AbilitiesPanel._on_cast_cancelled` has `TODO: VFX pass`) and no combat audio.
- `[LOW]` DoT ignores `dot_damage_type`, defense and modifiers and is not logged (`CombatBuffManager._apply_dot_damage`). No content uses DoTs.
- `[LOW]` `INCOMING_DAMAGE_MODIFIER` and attribute buffs only refresh, never stack. No content uses either.
- `[LOW]` `AdventureActionData.difficulty_modifier` is never read; `CharacterManager.get_gold_multiplier()` is a stub returning 1.0.
- `[LOW]` `SimpleEnemyAI` has no priorities beyond "longest cooldown first" and the heal gate. Its comment calls `sort_custom` stable; Godot documents it as unstable (matters once an enemy has two abilities with equal cooldowns).
- `[LOW]` Using consumables in combat (`CombatConsumableManager`, `ConsumableButton`, hotkeys 1–4) exists only on the unmerged branch `feat/infallible-chaum-58f8ad` (20 commits, 2026-06-01). On `main`, combat ignores the inventory consumable hotbar.

### Content

- `[HIGH]` No real boss. `manifested_spirit_encounter` (the Shallow Woods boss) fights the regular `amorphous_spirit` (100 Health, 9 damage per lash, 15 gold). The Foundation Beat 7 Tribulation Guardian does not exist.
- `[MEDIUM]` Coalescing Spirit (elite) has no `base_gold_drop` and its encounter has no loot.
- `[MEDIUM]` No enemy art. No `CombatantData` sets `texture`, and Madra Lash and Coalesce have no icon, so their buttons in the enemy row are blank.
- `[MEDIUM]` Four enemies, all for The Shallow Woods; nothing for later Foundation beats or Copper.
- `[LOW]` Enemy effects have empty `effect_name` (Madra Lash damage, Famishing Bite damage and Hunger), so `Log` lines and the Hunger tooltip lack names.

### UI

- `[MEDIUM]` No combatant visuals. `CombatantNode` has no sprite (removed 2026-04-08), `CombatantData.texture`/`scale`/`offset` are unused, the player texture set in `_create_player_combatant()` is dead, and `EnemyInfoPanel.profile_texture` is `base_player.png`, so every enemy shows the player's portrait.
- `[MEDIUM]` Buff tooltip misstates stacked buffs: "Outgoing damage x1.5" regardless of stacks (actual 1.5^stacks), DoT text ignores stacks, and `consume_on_use` and `effect_description` are not shown.
- `[LOW]` The ability tooltip only shows the raw total of the first target effect; heals (Coalesce), interrupts, strips and descriptions are not shown.
- `[LOW]` Info panel positions are hardcoded in `AdventureView` (`(390, 500)` in combat, `(170, 872)` on the map), and `PlayerInfoPanel` has a stray `rotation = -0.0037` (fixed on the consumables branch).
- `[LOW]` The combat backdrop is the shared zone background plus Atmosphere values hardcoded in `_setup_atmosphere()`; there is no per-zone backdrop.
- `[LOW]` The cooldown overlay divides by `base_cooldown`, so the 1.5 s opening cooldown renders as a fraction of the full cooldown (10% for Enforce).
- `[LOW]` Casting-indicator labels (`AbilityInformation`, `CastTimer`) use inline font size/colour overrides instead of Label variants; the `AbilityTypeIcon` TextureRect is never set.

### Tech Debt

- `[MEDIUM]` `enable_ai` debug export under `# TODO: DELETE DEBUG` is still in `adventure_combat.gd` (lines 33–36); earlier docs wrongly said PR #15 removed it.
- `[LOW]` Stray `CastTimer` Label with placeholder text `"2.7 / 8.0s"` under the `AdventureCombat` root in `adventure_combat.tscn`; nothing references it.
- `[LOW]` Dead code: `combat_ability_instance.tscn` (unused; root node misspelled `CombatAbilitiyInstance`), `CombatAbilityManager.ability_registered`/`ability_used` (no listeners; `ability_used` declared with two args, emitted with one), `CombatBuffManager.get_outgoing_damage_modifier()` (tests only) and `get_incoming_damage_modifier()` (unused), `panel_buffs.tres`, and the unused child `VitalsManager` on the player's `CombatantNode`.
- `[LOW]` `CombatantInfoPanel` calls `CombatBuffManager._find_buff_by_id()` (private) for duration sync and tooltips.
- `[LOW]` `AbilitiesPanel._unhandled_input` marks a slot key handled even when that panel has no button for the slot, and the enemy panel runs the same handler; correct behaviour depends on input order.
- `[LOW]` Key letters are hardcoded (`AbilityButton.KEY_LABELS`, `AbilityEquipSlot.KEY_LABELS`) instead of read from the InputMap.
- `[LOW]` Public functions without `##` doc comments (CLAUDE.md): `VitalsManager.initialize_current_values()`/`apply_vitals_change()`, `CombatAbilityManager.can_cast_ability_instance()`, `AdventureCombat.on_player_ability_selected()`, `CombatantInfoPanel.setup_abilities()`.
- `[LOW]` Test gaps: nothing covers `SimpleEnemyAI`, `VitalsManager`, `execute_ability()` (modifier consumption, effect order), incoming modifiers, DoT ticks, the gold formula, or `AdventureCombat` start/stop. `test_adventure_combat_victory_event.gd` only calls `EventManager` directly, and `test_adventure_combat_count.gd` re-implements the counting logic instead of calling `AdventureTilemap.get_total_combat_count()`.
