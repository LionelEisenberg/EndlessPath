# Combat System

Last updated: 2026-10-23

## Overview

Combat is a real-time, one-versus-one fight that runs inside an adventure. When the player picks a `CombatChoice` on an adventure tile, the hex map hides and `AdventureCombat` builds two `CombatantNode`s: the player (attributes snapshot + equipped loadout) and the first enemy in the choice's `enemy_pool`. Each side casts abilities that cost Health, Madra or Stamina, may have a cast time, then go on cooldown. Effects deal damage, heal, apply buffs, interrupt casts, or strip buffs. The enemy is driven by `SimpleEnemyAI`. The fight ends the moment either side's Health reaches 0.

There is no AP pool (the GDD's AP/Cycle-skill economy is not built). Health and Madra do not regenerate during an adventure; Stamina regenerates at 1/s. Madra is a per-adventure budget drained from the zone Madra pool when the adventure starts.

This doc covers the combat side. How a fight is triggered from the map and how results feed back into the adventure is in [ADVENTURING.md](../adventuring/ADVENTURING.md). Ability data, unlocks and the loadout are in [ABILITIES.md](../abilities/ABILITIES.md); per-ability numbers are in [ABILITIES_MATRIX.md](../abilities/ABILITIES_MATRIX.md).

## Player Experience

1. On the adventure map the player reaches a combat tile (regular, elite or boss) and picks its combat choice, e.g. "Attack the Spirit".
2. The map hides and the combat view fades in: the zone background with a vignette, drifting mist and motes. The player's sprite stands on the left and the enemy's on the right, both sliding in from their own side. Sprites are scaled to a shared height (elites 15% larger); every enemy currently uses the placeholder `test_enemy_sprite.png`.
3. The adventure's frame stays up. The vitals cabinet (top left) keeps showing Health, Madra and Stamina, and shows the player's buffs in up to three sockets beside the Health figures. The chest (top right) keeps the expedition page and the run clock. The technique dock (bottom centre) binds its four slots to the player's techniques. Above the enemy floats its older plate: a red intent tab (only while it casts), a card with its name and Health bar, and a row of buff icons. The plate's right end runs under the chest until the fight is reworked.
4. Slots show the bound key on a key cap (read from the InputMap: Q/W/E/R by loadout slot; cream in a fight, tan in the map's preview), and under the slot its cost with the resource's mini icon (cream, or tan while unaffordable). A cooldown shows as a sweep: the part of the icon still to recharge is drawn in the kit's dark locked veil, uncovered clockwise from 12 o'clock in 24 whole steps, with the whole seconds left in the centre. Empty loadout slots show only their socket and key cap. Every player ability starts the fight on a 1.5 s cooldown.
5. The player clicks a slot or presses its key. Instant abilities fire immediately; abilities with a cast time show the cast tray above the dock (the technique's name, a rod filling toward release and the time left) while the casting slot wears a steady brass frame. The slots stay visible throughout. Only one cast runs at a time. A press that cannot cast (casting, cooling down, too little of a resource) shakes the slot and does nothing else, with no log line. When a cooldown ends, the slot's brass frame flashes once.
6. The enemy acts on its own. Its casts show in the intent tab on its plate (icon, name, time left, and a bar that ramps from orange to red and throbs in the last 0.6 s), which is the window for Empty Palm's interrupt. An interrupted cast shows "Interrupted" with a shake. Enemy abilities with no cooldown can start casting on the first frame and repeat back to back.
7. Hovering a slot shows a tooltip above the dock: the name, "Cast 1.2 s · Cooldown 3 s" (or "Instant · Cooldown 3 s"), the cost with its mini icon, a damage line such as "about 9 Physical damage" for a technique whose first target effect deals damage (before the target's defense), and the description. The cost is not previewed on the cabinet. Hovering a buff socket on the cabinet shows the buff's name, whole seconds left, stacks and effect; hovering a buff icon on the enemy's plate shows the older tooltip with its live remaining time and stacks.
8. When an ability executes the caster lunges (self-only abilities give a gold pulse instead); the target flashes white, recoils, and a damage number pops over its head (heals in green). The enemy's Health bar trails recent losses with a pale ghost. The cabinet's orbs and rod simply follow the player's vitals. The log board (at the bottom left, as in the zone view; L opens the full log) records damage taken, heals, interrupts and buff strips.
9. When the enemy reaches 0 Health the player wins gold and returns to the map; beating the boss ends the adventure as a victory. When the player reaches 0 Health the adventure ends in defeat. Either way the end card shows when the adventure ends.
10. Health, Madra and Stamina carry over to the next fight in the same adventure. Buffs and cooldowns do not.

## Architecture

### Scene composition during a fight

```
AdventureView (Control)                          adventure_view.gd (adventure-owned host)
├── ZoneViewBackground                           parallax backdrop, visible behind combat (the map's ground covers it)
├── TilemapView/…/AdventureTilemap               emits start_combat(choice)
├── CombatView (Control, hidden outside combat; fades in when a fight starts)
│   └── CombatSubviewportContainer/SubViewport   1920x1080
│       └── AdventureCombat (Node2D)             adventure_combat.gd
│           ├── Atmosphere (CanvasLayer 5)       instanced in _setup_atmosphere(), moved to index 0
│           ├── PlayerSpot / EnemySpot (Marker2D) fighters' feet, (660, 790) / (1300, 790)
│           ├── HudLayer (CanvasLayer 100)       above the atmosphere
│           │   └── EnemyNameplate               placed above the enemy sprite by _place_nameplate()
│           ├── PlayerCombatant (CombatantNode)  created per fight
│           └── EnemyCombatant (CombatantNode)   created per fight
│               └── EnemyAI (SimpleEnemyAI)      added by _create_enemy_combatant()
├── VitalsPlate                                  vitals cabinet, top left; binds the player's buffs in a fight
├── AdventureChest                               chest, top right; the expedition page stays up through a fight
├── TechniqueDock                                technique bar, bottom centre; its slots activate in combat
└── RunTimer (Timer)                             the run's time limit
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
├── CombatBuffManager (Node)           combat_buff_manager.gd
│   └── Timer (DoT tick, 1 s, runs only while a DoT is active)
└── CombatantVisual (Node2D)           combatant_visual.gd, origin = the fighter's feet
    ├── Shadow (Sprite2D)              radial ground shadow
    ├── Body (Node2D) → Sprite         hit_flash.gdshader material; idle bob on the sprite
    ├── NumberAnchor (Marker2D)        damage number spawn point
    └── NumberLayer (CanvasLayer 100)  DamageNumber instances, above the atmosphere
```

`CombatantNode._update_visuals()` passes `CombatantData.texture`, `scale` and `offset` to `CombatantVisual.setup()`, which scales the sprite to `display_height × scale` (280 px at 1.0) and mirrors enemies to face the player. The node then listens to its `VitalsManager.health_changed` (a loss of at least 0.5 → `play_hit()`: white flash, recoil, damage number; a gain of at least 1 → `play_heal()`) and to each ability's `executed` signal (`play_attack()` lunge for abilities with target effects, `play_buff()` gold pulse for self-only ones). The thresholds keep regen ticks from triggering reactions.

### Technique dock

The player's technique bar (`technique_dock.tscn`), in the zone view's dock place. It is visible for the whole adventure: on the map the slots preview the equipped loadout (`show_loadout()`: each technique in its loadout slot with its icon, cost and a tan key; unequipped slots show only the socket and key cap); `bind(ability_manager, vitals_manager)` binds them to a fight and `reset()` returns them to the preview (and hides the cast tray and the tooltip).

```
TechniqueDock (Control, (722, 920), 476×136)     technique_dock.gd, mouse STOP, lacquer theme
├── Board                                        lacquer_tdock_ai.png
├── Slot1 … Slot4 (TechniqueSlot, 80×80)         at x 30, 142, 254, 366; y 18   technique_slot.gd
│   ├── Body → Socket, Icon (sweep material), SecondsLabel, HoverFrame, CastFrame, ReadyFlash
│   ├── KeyCap → KeyLabel                        Q / W / E / R from the InputMap
│   └── CostLine → CostIcon, CostLabel           centred under the slot
├── CastTray (476×44, dock-local (0, −52))       cast_tray.gd: name, cast rod, time left
└── TechniqueTooltip (PanelContainer, 304 wide)  technique_tooltip.gd, top level, on board9.tres
```

- **Slot states** (`TechniqueSlot.SlotState`): EMPTY (socket and key cap), PREVIEW (icon, cost, tan key) and ACTIVE (cream key; the cost cream, or tan while unaffordable, checked each frame while the slot is neither cooling nor casting).
- **Cooldown sweep.** The icon has a local-to-scene `ShaderMaterial` on `lacquer_cooldown_sweep.gdshader`, whose one uniform is `progress` (0 to 1). Per 2 px cell of the 64×64 icon, a cell whose centre angle (clockwise from 12 o'clock) is at or past `floor(progress × 24 + 0.5) / 24 × TAU` takes the kit's locked-veil colour for its luminance band (`#151A18 #39423E #4B5550 #5F6A65`) and keeps its alpha; the other cells keep the icon. There is no blending, `smoothstep` or `TIME`. The `+ 0.5` rounds to the nearest step, because `progress` is always k / 24 and for k = 7 and 14 the product lands exactly halfway between float32 values, which a bare `floor` would leave to the GPU's rounding; a 0.0001 rad bias does the same for cells whose centre falls on a step's edge. The slot sets `progress = sweep_step(time_left, duration) / 24` on `bind()` (it reads the running opening cooldown) and on `cooldown_started` / `cooldown_updated`, and shows `seconds_text(time_left)` (`ceili`, empty at 0). `sweep_step()` is `clampi(floori((1 − time_left / duration) × 24 + 1e-6), 0, 24)`. `cooldown_ready` shows the plain icon, hides the seconds and flashes the brass frame once.
- **Casting.** `CastFrame` is shown from `cast_started` to `cast_finished` / `cast_cancelled`. The cast tray shows outright on any bound instance's `cast_started` (the rod at 1 − time left / duration), steps on `cast_updated` and hides on `cast_finished` / `cast_cancelled`.
- **Input.** Q/W/E/R (`ability_slot_1` to `_4`) are read in `TechniqueDock._unhandled_input`, only while the dock is active and visible, and a click on a slot does the same. A press asks `CombatAbilityManager.can_cast_ability_instance(instance, null)`: accepted, the dock emits `ability_selected(instance)`; refused, `TechniqueSlot.refuse()` shakes the slot on `MapGlyph.shake_offset_at()` and nothing else happens. The manager still writes its own `Log.warn` for a refusal (a diagnostic; the player's log stays silent). A slot key is marked handled during a fight even when its slot is empty.
- **Tooltip.** `TechniqueTooltip.show_for_ability(data, slot, cast_tray_shown)` fills the name (`LabelLacquerPopoverTitle`), the timing ("Cast <t> s · Cooldown <c> s" or "Instant · Cooldown <c> s", through `AbilityRow.format_seconds()` and `LacquerText.decimal_bbcode()`), the cost row (mini icon and `AbilityRow.format_cost()`), the damage line (`AbilityRow.format_damage(data, CharacterManager.get_total_attributes_data())`, hidden when the technique deals no damage), a divider and the description. It is 304 wide and hugs its height rounded up to an even number, so its top stays on the 2 px grid. Its bottom sits at screen y 912 (860 while the cast tray shows) and its left 8 px left of the hovered slot, kept on screen.

### Vitals cabinet and buffs in a fight

`VitalsPlate` shows the player's vitals on the map and in a fight ([ADVENTURING.md](../adventuring/ADVENTURING.md#the-frame-cabinet-chest-and-dock)). `AdventureView` calls `bind_buffs(player.buff_manager)` when a fight starts and `unbind_buffs()` when it ends: up to three sockets fill from the left as buffs land (a socket flashes its brass frame once), with a count seal while a buff stacks. Hovering a socket opens a `BuffTooltip` at the cabinet's right edge: the buff's name, "<n> s left" (rounded up) with " · ×<stacks>", a divider and `BuffEffectData.describe()`. The plate keeps its own list of buffs from `buff_applied` / `buff_removed` / `buff_stacked`, because `clear_all_buffs()` announces each removal before it empties the manager's list, and hides the tooltip when its buff ends.

### EnemyNameplate (`enemy_nameplate.tscn`)

The enemy's plate is the fight's last piece of the older HUD; the opponent page in the chest replaces it in PR 2 of the lacquer rework.

```
EnemyNameplate (VBox)                     enemy_nameplate.gd
├── IntentBar (intent_bar.tscn)           CastBar variant: red tab, ramps to red, throbs in the last 0.6 s
├── Panel (panel_nameplate.tres)          NameLabel (LabelValueMedium) + HealthBar (ResourceBar)
└── BuffMargin → BuffBar                  enemy buffs and debuffs
```

### Buff icon

```
BuffIcon (MarginContainer)                   buff_icon.gd
└── BackgroundRect → BuffTexture → DurationProgressBar, StackLabel; DurationLabel under the icon
```

`BuffIcon`s fill the enemy plate's `BuffBar`. The player's buffs show in the cabinet's sockets instead.

## Data Model

### CombatantData (`scripts/resource_definitions/combat/combatant_data.gd`)

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| `character_name` | `String` | `"Combatant"` | Enemy plate name and log label |
| `attributes` | `CharacterAttributesData` | new instance (all 10) | Offense scaling, defense, vitals maxima |
| `abilities` | `Array[AbilityData]` | `[]` | One `CombatAbilityInstance` each, in array order |
| `texture` | `Texture2D` | null | Sprite drawn by `CombatantVisual` |
| `scale` | `float` | 1.0 | Multiplier on the shared sprite height (elites use 1.15) |
| `offset` | `Vector2` | `(0, 0)` | Sprite offset from the fighter's feet, in px |
| `base_gold_drop` | `int` | 0 | Base of the victory gold formula |

The player's `CombatantData` is built in code each fight: name `"Player"`, `attributes = CharacterManager.get_total_attributes_data()` (base + equipment, snapshot), `abilities = AbilityManager.get_equipped_abilities()` (slot order, empty slots skipped), `texture = test_character_sprite.png` (placeholder).

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

`calculate_value(caster)` returns `base_value + Σ(attribute × get_scaling(attribute))` and logs each term. `calculate_damage(caster, target)` applies defense (below).

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
| Max Health | `BODY × 10` (`VitalsManager.max_health_for()`, which the Here tray's Health figure calls too) | `health_regen` (always 0) |
| Max Stamina | `BODY × 5` | `stamina_regen`: `1.0 × AdventureActionData.stamina_regen_modifier` during an adventure, 0 otherwise (set by `AdventureView._update_stamina_regen()`) |
| Max Madra | `CharacterAttributesData.get_max_madra()` = `FOUNDATION × 10` | `madra_regen` (always 0) |

- Maxima are recomputed when `character_attributes_data` is assigned. `apply_vitals_change(health, stamina, madra)` clamps each value to `[0, max]`; regen is applied in `_process`.
- Every `current_*` assignment emits its `*_changed` signal, even when the value does not change, and `apply_vitals_change()` assigns all three values, so any call emits all three signals.
- **Player:** one persistent `VitalsManager` owned by `PlayerManager` (`is_player = true`). In `_ready` it connects to `CharacterManager.base_attribute_changed` and re-pulls `get_total_attributes_data()`. At adventure start `AdventureView` calls `initialize_current_values(madra_budget)`: full Health and Stamina, Madra = the budget drained from the zone pool (`min(FOUNDATION × 10, Madra pool)`). Stamina is also spent on map movement (see ADVENTURING.md).
- **Enemy:** `CombatantNode.setup()` uses the node's own `VitalsManager`, assigns the enemy attributes, and starts at full Health, Stamina and Madra.

### Ability lifecycle

1. **Request.** `TechniqueDock` emits `ability_selected(instance)` on a click or key that `can_cast_ability_instance()` would accept (a refused press only shakes the slot); `AdventureView` has connected it to `AdventureCombat.on_player_ability_selected()`, which calls `player.ability_manager.use_ability_instance(instance, enemy)`. The AI calls the same method.
2. **Gate** — `CombatAbilityManager.can_cast_ability_instance()`: the instance belongs to this manager; no instance of this combatant is casting (global lock); the instance is ready (cooldown timer stopped and not casting); `AbilityData.can_afford(vitals)`. Failures log a warning and return false.
3. **Pay.** `AbilityData.consume_costs(vitals)` deducts all costs at cast start. Cancelled casts are not refunded.
4. **Cast.** `CombatAbilityInstance.start_cast(target)`. If `cast_time > 0`: `is_casting = true`, cast timer starts, `cast_started` emits, and `cast_updated` emits every frame; on timeout `execute_ability()` runs, then `cast_finished` emits. If `cast_time == 0`: `execute_ability()` runs immediately.
5. **Execute** — `execute_ability(target)`:
   - emits `executed(self)` (the caster's lunge or buff pulse);
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
2. `AdventureCombat.start()` → `_create_player_combatant()` (placed on `PlayerSpot`, `setup(data, PlayerManager.vitals_manager, true)`, `play_enter()`) then `_create_enemy_combatant()`: `enemy_pool[0]`, own vitals, placed on `EnemySpot` and slid in, `EnemyNameplate.setup()` (positioned above the sprite on the next frame), `SimpleEnemyAI` child, enemy `health_changed` connection.
3. `AdventureView` calls `TechniqueDock.bind(ability_manager, vitals_manager)` (slots bound to the player's abilities, cast tray bound) and `VitalsPlate.bind_buffs(buff_manager)`, connects `ability_selected` → `on_player_ability_selected`, swaps the tilemap view for the combat view and fades it in.

End:
- Enemy Health ≤ 0 → `_calculate_gold_reward()` → `EventManager.trigger_event("q_first_steps_enemy_defeated")` (every victory; EventManager de-duplicates) → `trigger_combat_end(true, gold)`.
- Player Health ≤ 0 → `trigger_combat_end(false, 0)`.
- `AdventureView._on_stop_combat()` lets the dock and the cabinet go (`TechniqueDock.reset()` puts the slots back into loadout preview and hides the cast tray; `VitalsPlate.unbind_buffs()` clears the sockets), restores the map view and clears `is_in_combat`. It then calls `AdventureCombat.stop()`, which resets `EnemyNameplate`, runs `clear_all_buffs()` on both sides and `queue_free()`s both combatants. Next it calls `AdventureTilemap.handle_combat_result(successful, gold)`, and on defeat `ActionManager.stop_action(false)`. A boss win ends the adventure from inside `handle_combat_result()`. Because `is_in_combat` is already false at that point, `stop_adventure()` doesn't end the fight a second time.

Gold is the static `AdventureCombat.gold_reward_for(choice, action)`: `floor(base_gold_drop × CombatChoice.gold_multiplier × AdventureActionData.gold_multiplier × CharacterManager.get_gold_multiplier())` for the first enemy of the pool (0 for an empty pool; the action's multiplier counts 1 with no action). `_calculate_gold_reward()` returns it and writes the log line, and the chest's fight drawer shows the same figure as "<gold> gold if you win". All three multipliers are 1.0 in current content (`get_gold_multiplier()` is a stub).

### Signals

| Emitter | Signal | Listener |
|---------|--------|----------|
| `AdventureTilemap` | `start_combat(choice)` | `AdventureView._on_start_combat` |
| `AdventureCombat` | `trigger_combat_end(is_successful, gold_earned)` | `AdventureView._on_stop_combat` |
| `VitalsManager` | `health_changed`, `madra_changed`, `stamina_changed` | `VitalsPlate` (the player's orbs, rod and figures); `EnemyNameplate` (Health); `CombatantNode` (hit/heal reactions); `AdventureCombat` death checks (health) |
| `CombatAbilityInstance` | `cooldown_started`, `cooldown_updated`, `cooldown_ready` | `TechniqueSlot` |
| `CombatAbilityInstance` | `cast_started`, `cast_updated`, `cast_finished`, `cast_cancelled` | `CastBar` (enemy intent tab); `CastTray` and `TechniqueSlot` (the player's cast tray and casting frame) |
| `CombatAbilityInstance` | `executed(instance)` | `CombatantNode` (lunge or buff pulse) |
| `CombatBuffManager` | `buff_applied`, `buff_removed`, `buff_refreshed`, `buff_stacked` | `VitalsPlate` (the player's sockets; it ignores `buff_refreshed`); `BuffBar` (the enemy's) |
| `TechniqueSlot` | `pressed`, `hovered(ability_data)`, `unhovered` | `TechniqueDock` |
| `TechniqueDock` | `ability_selected(instance)` | `AdventureCombat.on_player_ability_selected` |
| `BuffIcon` | `hovered(buff_data)`, `unhovered` | `BuffBar` (buff tooltip) |

## Combat UI

| Component | Script | Behavior |
|-----------|--------|----------|
| `TechniqueDock` | `technique_dock.gd` | The player's technique bar. `show_loadout()` at adventure start, `bind(ability_manager, vitals_manager)` / `reset()` around each fight. Reads Q/W/E/R and clicks, emits `ability_selected` for a press the manager would accept and shakes the slot for one it would refuse. Owns the cast tray and the tooltip |
| `TechniqueSlot` | `technique_slot.gd` | One slot: EMPTY (socket and key cap), PREVIEW (icon, cost, tan key) or ACTIVE. Key hint read from the `ability_slot_N` InputMap actions; the cost under the slot with the resource's mini icon (tan while unaffordable); the cooldown sweep with whole seconds left; a steady brass frame while casting; a brass flash when the cooldown ends; the hover frame; a shake when a press is refused |
| `CastTray` | `cast_tray.gd` | The player's cast: the technique's name, a rod that fills toward release and the time left (`"%.1f s"` through `LacquerText.decimal_bbcode()`). Shows outright on `cast_started`, hides on `cast_finished` and `cast_cancelled` |
| `TechniqueTooltip` | `technique_tooltip.gd` | The board above the dock: name, timing, cost, damage line, divider and description (see [Technique dock](#technique-dock)) |
| `VitalsPlate` | `scenes/adventure/vitals_plate/vitals_plate.gd` | The vitals cabinet: Health and Madra orbs, the Stamina rod and three buff sockets for the player's buffs (see [Vitals cabinet and buffs in a fight](#vitals-cabinet-and-buffs-in-a-fight)) |
| `BuffTooltip` | `buff_tooltip.gd` | The cabinet's buff tooltip: the name (`buff_id.capitalize()`), whole seconds left with `×N` stacks, a divider and `BuffEffectData.describe()`. The plate hides it when its buff ends |
| `ResourceBar` | `resource_bar.gd` | Flat `ProgressBar` (fill stylebox per resource) with the name on the left and `cur / max` on the right; regen is in its tooltip. Losses tween the bar and hold a ghost for 0.45 s before it drains; gains move both. Optional floating `-N`/`+N` text; `compact` for thin bars. Only the enemy plate's Health bar uses it now, and nothing calls its `preview_cost()` since the dock dropped cost previews |
| `CastBar` | `cast_bar.gd` | Binds to a `CombatAbilityManager`: icon, name, time left, and a bar that fills toward release. Fades when idle but keeps its layout space; flashes on release; "Interrupted" and a shake on cancel. `danger_color` ramps the fill and `imminent_time` throbs the panel (used by `intent_bar.tscn`, the enemy's intent tab, its only user now) |
| `EnemyNameplate` | `enemy_nameplate.gd` | Intent tab, name, Health bar and buffs for the enemy. `setup(combatant)` / `reset()` |
| `DamageNumber` | `damage_number.gd` | Pops from 40% scale, rises 70 px with a random drift and fades over 0.9 s |
| `FloatingText` | `scenes/ui/floating_text/floating_text.gd` | Rises 100 px over 1.5 s, starts fading after 0.45 s, frees itself. Used by `ResourceBar` and by cycling |
| `BuffBar` | `buff_bar.gd` | Wrapping row of `BuffIcon`s mirroring a `CombatBuffManager` (durations synced from `ActiveBuff.time_remaining` every frame); hosts the buff tooltip. The enemy plate's |
| `BuffIcon` | `buff_icon.gd` | Icon, duration sweep, `"%.1fs"` under the icon, stack count when > 1 |
| `CombatBuffTooltip` | `combat_buff_tooltip.gd` | The enemy plate's buff tooltip: name (`buff_id.capitalize()`), effect text from `BuffEffectData.describe()`, live `x.xs remaining`, `xN stacks` |

Keybindings (`project.godot`, physical keys):

| Action | Key | Handler |
|--------|-----|---------|
| `ability_slot_1` … `ability_slot_4` | Q / W / E / R | `TechniqueDock._unhandled_input` → ability in loadout slot 0–3 while the slots are bound for a fight (a press the manager would refuse shakes the slot) |
| `open_abilities` | A | Opens/closes the Abilities view from the zone view (not available during adventures) |

Styleboxes in use (`assets/styleboxes/combat/`, all for the enemy's plate and `ResourceBar`): `panel_intent.tres` (enemy intent tab), `panel_nameplate.tres` (enemy card), `bar_track.tres`, `bar_fill_{health,ghost}.tres`, `cast_bar_fill.tres` / `cast_bar_fill_enemy.tres` and `cost_preview.tres`. The player's side is built from the lacquer kit, and both tooltips sit on `assets/styleboxes/lacquer/board9.tres`.

## Integration Points

| System | Direction | Connection |
|--------|-----------|------------|
| Adventure (`AdventureView`, `AdventureTilemap`) | in / out | `start_combat(choice)` starts a fight; `trigger_combat_end` → `handle_combat_result()` awards gold (`ResourceManager.add_gold`), applies `CombatChoice.success_effects`/`failure_effects`, completes the tile, or ends the run on a boss win. See [ADVENTURING.md](../adventuring/ADVENTURING.md) |
| `AbilityManager` | in | `get_equipped_abilities()` → player abilities and the dock's loadout preview; `get_ability_at_slot()` → slot mapping and key routing |
| `CharacterManager` | in | `get_total_attributes_data()` snapshot at fight start; `base_attribute_changed` refreshes player vitals maxima; `get_gold_multiplier()` |
| `PlayerManager` | in / out | Persistent player `VitalsManager` shared by map and combat |
| `ResourceManager` | in | Adventure Madra budget becomes starting combat Madra |
| `EventManager` | out | `q_first_steps_enemy_defeated` on victory (Foundation Beat 2 quest step) |
| `LogManager` | out | Damage, heal, interrupt and strip lines; `AdventureView` logs encounter, victory and defeat |
| `Atmosphere` | — | Instanced by `AdventureCombat._setup_atmosphere()` with radius 0.5, softness 0.35, 25 cyan / 8 warm motes. It is a CanvasLayer on layer 5, so mist drifts in front of the fighters; the enemy plate and damage numbers render on layer 100 above it |
| Dev panel | in | `AdventureView.force_win_combat()` emits `trigger_combat_end(true, 0)` directly (no gold, no quest event) |

## Existing Content

### Enemies

`resources/combat/combatant_data/`. Attributes not listed are 10.0. Vitals follow the formulas above.

| Enemy (`.tres`) | Name | Non-default attributes | Health / Stamina / Madra | Abilities | Gold | Texture |
|-----------------|------|------------------------|--------------------------|-----------|------|---------|
| `amorphous_spirit` | Amorphous Spirit | none | 100 / 50 / 100 | `madra_lash` | 15 | placeholder |
| `coalescing_spirit` | Coalescing Spirit | BODY 20, SPIRIT 25 | 200 / 100 / 100 | `madra_lash`, `coalesce` | 0 (unset) | placeholder, ×1.15 |
| `starving_dreadbeast` | Starving Dreadbeast | BODY 8.5, FOUNDATION 12 | 85 / 42.5 / 120 | `famishing_bite` | 20 | placeholder |
| `ravenous_dreadbeast` | Ravenous Dreadbeast | STRENGTH 15, BODY 8.5, FOUNDATION 12 | 85 / 42.5 / 120 | `famishing_bite` | 20 | placeholder, ×1.15 |

"placeholder" is `assets/sprites/combat/enemies/test_enemy_sprite.png`; ×1.15 is the `scale` field.

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
| `scenes/combat/combatant/combatant_visual/combatant_visual.gd` / `.tscn` | Fighter sprite, shadow, hit flash, lunge, damage numbers |
| `scenes/combat/combatant/combatant_visual/damage_number.gd` | Floating damage number |
| `assets/shaders/hit_flash.gdshader` | White/gold flash on the fighter sprite |
| `scenes/ui/combat/technique_dock/technique_dock.gd` (with `technique_slot/`, `cast_tray/`, `technique_tooltip/`) | The technique dock, its slots, cast tray and tooltip |
| `assets/shaders/lacquer_cooldown_sweep.gdshader` | The cooldown sweep on a slot's icon |
| `scenes/adventure/vitals_plate/vitals_plate.gd` | The vitals cabinet: orbs, Stamina rod, the player's buff sockets |
| `scenes/ui/combat/buff_tooltip/buff_tooltip.gd` | The cabinet's buff tooltip |
| `scenes/abilities/ability_row/ability_row.gd` | `format_cost()`, `format_seconds()` and `format_damage()`, shared with the Abilities book |
| `scenes/ui/combat/enemy_nameplate/enemy_nameplate.gd` | Enemy plate (intent, name, Health, buffs) |
| `scenes/ui/combat/resource_bar/resource_bar.gd` | Flat vitals bar with ghost trail (the enemy's Health bar) |
| `scenes/ui/combat/cast_bar/cast_bar.gd`, `intent_bar.tscn` | Enemy intent tab |
| `scenes/ui/combat/buff_bar/buff_bar.gd` | The enemy plate's buff row and buff tooltip host |
| `scenes/ui/combat/buff_icon/buff_icon.gd` | Buff icon |
| `scenes/ui/combat/combat_buff_tooltip/combat_buff_tooltip.gd` | The enemy plate's buff tooltip |
| `scripts/resource_definitions/combat/combatant_data.gd` | `CombatantData` |
| `scripts/resource_definitions/combat/combat_effect_data.gd` | `CombatEffectData`, damage formula |
| `scripts/resource_definitions/combat/buff_effect_data.gd` | `BuffEffectData` |
| `scripts/resource_definitions/abilities/ability_data.gd` | `AbilityData`, costs, predicates |
| `singletons/player_manager/player_manager.gd` | Owns the persistent player `VitalsManager` |
| `resources/combat/combatant_data/` | Enemy definitions and enemy abilities |
| `tests/unit/test_combat_damage.gd`, `test_combat_effect_data.gd`, `test_combat_effect_types.gd`, `test_combat_buff_manager_stacking.gd`, `test_combat_buff_manager_strip.gd`, `test_combat_ability_instance_cancel.gd`, `test_adventure_combat_victory_event.gd`, `test_adventure_combat_count.gd`, `test_fight_rules.gd`, `test_buff_effect_describe.gd`, `test_technique_slot_math.gd` | Unit tests |
| `tests/integration/test_empty_palm_interrupt.gd`, `test_power_font_buff_strip.gd` | Integration tests (real `.tres` through the effect pipeline) |
| `tests/integration/test_technique_dock.gd`, `test_vitals_plate.gd` | Integration tests (the dock's slots, sweep, cast tray, presses and tooltip; the cabinet's figures, orbs and buff sockets) |

## Work Remaining

### Bugs

- `[MEDIUM]` Equipment never updates the player's vitals maxima. The player `VitalsManager` recomputes max Health/Stamina/Madra only on `CharacterManager.base_attribute_changed` (`vitals_manager.gd` `_ready`). Equipping Reinforced Robes (+4 BODY) or Leeching Ring (+2 FOUNDATION) leaves max Health/Madra unchanged until a base attribute changes or the game restarts, while damage and defense already use the new totals.
- `[MEDIUM]` Defense ignores buffs. `CombatEffectManager.process_effect()` passes the target's unmodified `combatant_data.attributes` to `calculate_damage()`, so RESILIENCE/SPIRIT/WILLPOWER attribute buffs do nothing defensively.
- `[LOW]` 0 s-cooldown abilities skip the opening cooldown and the post-interrupt cooldown (`CombatAbilityInstance._start_cooldown()` returns early when `base_cooldown <= 0`). Madra Lash and Famishing Bite start casting on frame 1, and an Empty Palm interrupt only restarts their cast.
- `[LOW]` `AdventureCombat._on_player_health_changed` stays connected to the player `VitalsManager` after combat. A lethal non-combat Health change during an adventure (e.g. a trap's `ChangeVitalsEffectData`) is reported as a combat defeat (`_combats_fought` + 1, `handle_combat_result(false)`). Latent: `test_trap_encounter` (−10 Health) is not in any adventure.
- `[LOW]` `FloatingText._ready()` sets font size with `add_theme_constant_override("font_size", 24)`, which does not change a Label's font size (needs a font-size override).

### Missing Functionality

- `[HIGH]` Attribute design pass. CONTROL and WILLPOWER have no combat effect (no ability deals `MIXED`), AGILITY is only a damage coefficient, and the `AttributeType` comments promise evasion, cooldown and cost reduction that do not exist. Current gear already grants inert stats (Cultivator's Cowl +3 WILLPOWER, Leeching Ring +2 CONTROL).
- `[HIGH]` Only `enemy_pool[0]` is used (`_create_enemy_combatant()`, `_calculate_gold_reward()`): no random pick and no multi-enemy fights.
- `[MEDIUM]` No buff stack cap. Outgoing-damage and DoT stacks are unbounded and outgoing stacks compound; a dreadbeast that bites every 3 s doubles its damage roughly every 5 s until Power Font (a path unlock) strips it. Add a `max_stacks` field to `BuffEffectData`.
- `[MEDIUM]` No in-combat resource economy beyond Stamina regen. No AP or Cycle skill (GDD), no Madra or Health regen, and the Iron Will path node's `stamina_recovery_mult` is never applied.
- `[MEDIUM]` Casts are only interrupted by `CANCEL_CAST`; damage never interrupts (the Power Font spec assumed it does).
- `[MEDIUM]` Combat feedback is visual only: hits flash and recoil, attackers lunge, numbers pop and interrupted casts shake, but there are no interrupt or strip VFX on the fighters, no death or victory beat (the fight ends the frame Health reaches 0), no screen shake and no combat audio.
- `[LOW]` DoT ignores `dot_damage_type`, defense and modifiers and is not logged (`CombatBuffManager._apply_dot_damage`). No content uses DoTs.
- `[LOW]` `INCOMING_DAMAGE_MODIFIER` and attribute buffs only refresh, never stack. No content uses either.
- `[LOW]` `AdventureActionData.difficulty_modifier` is never read; `CharacterManager.get_gold_multiplier()` is a stub returning 1.0.
- `[LOW]` `SimpleEnemyAI` has no priorities beyond "longest cooldown first" and the heal gate. Its comment calls `sort_custom` stable; Godot documents it as unstable (matters once an enemy has two abilities with equal cooldowns).
- `[LOW]` Using consumables in combat (`CombatConsumableManager`, `ConsumableButton`, hotkeys 1–4) exists only on the unmerged branch `feat/infallible-chaum-58f8ad` (20 commits, 2026-06-01). On `main`, combat ignores the inventory consumable hotbar.

### Content

- `[HIGH]` No real boss. `manifested_spirit_encounter` (the Shallow Woods boss) fights the regular `amorphous_spirit` (100 Health, 9 damage per lash, 15 gold). The Foundation Beat 7 Tribulation Guardian does not exist.
- `[MEDIUM]` Coalescing Spirit (elite) has no `base_gold_drop` and its encounter has no loot.
- `[MEDIUM]` No enemy art. Every enemy uses the placeholder `test_enemy_sprite.png` and the player uses `test_character_sprite.png`, both high-resolution images drawn with the project's nearest filter. Madra Lash and Coalesce have no icon, so the intent tab shows no icon for them.
- `[MEDIUM]` Four enemies, all for The Shallow Woods; nothing for later Foundation beats or Copper.
- `[LOW]` Enemy effects have empty `effect_name` (Madra Lash damage, Famishing Bite damage and Hunger), so `Log` lines and the Hunger tooltip lack names.

### UI

- `[MEDIUM]` Buff tooltips (`BuffEffectData.describe()`, in the cabinet's and the enemy plate's tooltips) misstate stacked buffs: "Outgoing damage x1.5" regardless of stacks (actual 1.5^stacks), DoT text ignores stacks, and `consume_on_use` and `effect_description` are not shown.
- `[LOW]` The technique tooltip's damage line covers only a first target effect that deals damage; heals (Coalesce), interrupts and strips show only through the description text.
- `[LOW]` The enemy plate does not mark elites or bosses; the encounter type never reaches `AdventureCombat` (elites are only drawn larger).
- `[LOW]` The enemy plate's right end runs under the chest during a fight (about x 1120 to 1460) until the opponent page replaces the plate.
- `[LOW]` The combat backdrop is the Spirit Valley parallax background (`ZoneViewBackground`, which only the adventure view uses since the lacquer zone view dropped it) plus Atmosphere values hardcoded in `_setup_atmosphere()`; there is no per-zone backdrop.

### Tech Debt

- `[LOW]` Dead code: the unused child `VitalsManager` on the player's `CombatantNode`, art the old info panel used (`assets/sprites/ui/resource_bar/*.png`, `assets/sprites/character/base_player.png`), and `AbilityStatsDisplay`, `StatLabel` and `StatTooltip` (`scenes/abilities/`), which lost their last user with the old ability tooltip. The user's `ability_button_border.png` and `ability_button_overlay.png` are unused too and stay until the user says to delete them.
- `[LOW]` `TechniqueDock._unhandled_input` marks a slot key handled during a fight even when that slot is empty.
- `[LOW]` `AbilityEquipSlot.KEY_LABELS` hardcodes Q/W/E/R; the combat slots read their keys from the InputMap.
- `[LOW]` Public functions without `##` doc comments (CLAUDE.md): `VitalsManager.initialize_current_values()`/`apply_vitals_change()`, `CombatAbilityManager.can_cast_ability_instance()`, `AdventureCombat.on_player_ability_selected()`.
- `[LOW]` Test gaps: nothing covers `SimpleEnemyAI`, `VitalsManager`, `execute_ability()` (modifier consumption, effect order), incoming modifiers, DoT ticks, or `AdventureCombat.stop()`. (`max_health_for()` and `gold_reward_for()` are tested in `test_fight_rules.gd`.) `test_adventure_combat_victory_event.gd` starts a real `AdventureCombat` but only checks how the fight ends.
