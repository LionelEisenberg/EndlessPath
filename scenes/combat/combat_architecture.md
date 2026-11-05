# Combat Architecture

Short orientation for the code in `scenes/combat/`. The maintained reference (data model, ability lifecycle, damage formula, buffs, AI, UI, enemy content, open work) is [docs/combat/COMBAT.md](../../docs/combat/COMBAT.md).

> Earlier versions of this file described a `CombatantResourceManager`, a `CombatView` script, `CombatEncounter` and `character_abilities_data`. None of those exist: the resource manager became `VitalsManager`, the fight is hosted by `AdventureView`, encounters use `CombatChoice`, and the loadout comes from `AbilityManager`.

## What lives here

| Path | Contents |
|------|----------|
| `adventure_combat/` | `AdventureCombat` (Node2D): builds both combatants per fight, attaches the enemy AI, watches both Health values, computes gold, emits `trigger_combat_end(is_successful, gold_earned)` |
| `combatant/` | `CombatantNode` and its components: `CombatAbilityManager` + `CombatAbilityInstance`, `VitalsManager`, `CombatEffectManager`, `CombatBuffManager` + `ActiveBuff` |
| `ai/` | `SimpleEnemyAI`: longest-cooldown ready ability first; self-heals only when they would not overheal |

Combat UI is in `scenes/ui/combat/` (`TechniqueDock` with its `TechniqueSlot`s, `CastTray` and `TechniqueTooltip`, `EnemyNameplate`, `CastBar`, `ResourceBar`, `BuffBar`, `BuffIcon`, the buff tooltips). The player's vitals and buffs show on `VitalsPlate` in `scenes/adventure/vitals_plate/`. Data classes are in `scripts/resource_definitions/combat/` and `scripts/resource_definitions/abilities/`.

## Runtime composition

```
AdventureView                                   scenes/adventure/adventure_view/
├── CombatView/…/SubViewport
│   └── AdventureCombat (Node2D)
│       ├── Atmosphere                          added in code
│       ├── HudLayer/EnemyNameplate             the enemy's plate
│       ├── PlayerCombatant (CombatantNode)     vitals = PlayerManager.vitals_manager (persistent)
│       └── EnemyCombatant (CombatantNode)      own VitalsManager, full vitals each fight
│           └── EnemyAI (SimpleEnemyAI)
├── VitalsPlate                                 the player's vitals and buffs, persistent across fights
└── TechniqueDock                               the player's techniques, bound for each fight

CombatantNode
├── CombatAbilityManager → AbilityInstance_<name> × N (cooldown + cast Timers)
├── VitalsManager
├── CombatEffectManager
└── CombatBuffManager (1 s DoT Timer)
```

Each combatant draws its sprite through `CombatantVisual`; the player's vitals show on `VitalsPlate` and the enemy's on `EnemyNameplate`.

## How a fight runs

1. `AdventureTilemap.start_combat(choice)` → `AdventureView` → `AdventureCombat.initialize_combat(choice, action_data)` and `start()`.
2. The player combatant gets `CharacterManager.get_total_attributes_data()` and `AbilityManager.get_equipped_abilities()`; the enemy is `choice.enemy_pool[0]`. Each ability becomes a `CombatAbilityInstance` with a 1.5 s opening cooldown (skipped when `base_cooldown` is 0).
3. Player input (a `TechniqueDock` click or Q/W/E/R, which the dock forwards only if `can_cast_ability_instance()` would accept it) and the AI both call `CombatAbilityManager.use_ability_instance(instance, target)`.
4. The receiving combatant resolves each effect in its own `CombatEffectManager`; `DAMAGE` and `HEAL` change its `VitalsManager`, `BUFF` goes to its `CombatBuffManager`, `CANCEL_CAST` and `STRIP_BUFFS` hit its ability and buff managers.
5. Health ≤ 0 on either side → `trigger_combat_end` → `AdventureView` → `AdventureCombat.stop()` (clear buffs, free combatants) → `AdventureTilemap.handle_combat_result()`.
