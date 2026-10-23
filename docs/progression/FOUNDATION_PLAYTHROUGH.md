# Foundation Stage Playthrough

Last updated: 2026-10-22

> This document is the authoritative walkthrough of the Foundation stage in Zone 1 (Spirit Valley). It first describes the beats as they play on `main` today, with every trigger, id, reward, and unlock. It then covers the designed but unbuilt beats, the economy numbers, and open tuning questions.
>
> System mechanics live in [QUESTS.md](QUESTS.md), [EVENTS.md](../infrastructure/EVENTS.md), [UNLOCKS.md](../infrastructure/UNLOCKS.md), [EFFECTS.md](../infrastructure/EFFECTS.md), and [DIALOGUE.md](../infrastructure/DIALOGUE.md). Authoring rules are in [QUESTS_EVENTS_UNLOCKS_CONVENTIONS.md](QUESTS_EVENTS_UNLOCKS_CONVENTIONS.md).

## Overview

- **Target:** 30–60 minutes of committed play across 10 beats, ending with the Foundation → Copper breakthrough (Tribulation).
- **Built:** Beats 1, 2, 3a, 3b and 4. Beat 3b unlocks the Merchant; Beat 4 is its shop (Merchant v1).
- **Content ends** after the Merchant. See [Where content ends](#where-content-ends).
- **Planned:** Beats 5–10. See [Planned beats](#planned-beats-510).

| Status tag | Meaning |
|---|---|
| `PLANNED` | Designed here; no code or data |
| `STUBBED` | Systems or data partly wired; the beat's content or UI is missing |
| `IMPLEMENTED` | Code and content exist, but the beat has not been playtested end to end |
| `PLAYTESTED` | Played through; feel validated; numbers settled |

## Framing notes

- **Adventure tiles are gated by difficulty, not by unlocking.** Combat and boss tiles are always on the map; early players die before reaching or surviving them. Special tiles are map anchors: every Shallow Woods map places exactly one Aura Well, and the Refugee Camp is placed only while its gate holds.
- **Failure is the loop.** Adventures are meant to end in death or a clear, following incremental-genre convention. The code also ends a run at its 300 s time limit.
- **Quests only where the next step is ambiguous.** A new zone action, a path point, or a Goals board entry should be enough of a signal. By design, Beats 3a, 4, and 6 have no quest, and Beat 5's quest is optional.
- **Chains live on NPC actions (Pattern B).** The NPC dialogue action that completes one quest starts the next. Quests never reference each other.
- **One NPC.** The Celestial Intervener (Dialogic description: "Ashe"; display name "Intervener [Celestial]"; action names "[INTERVENER]") is the only character. Narratively, the Intervener leaves after the fourth talk. Names are placeholders.
- **Path points in Foundation:** one freebie from `q_first_steps`, then +1 every 10 Core Density levels (`CultivationManager.PATH_POINTS_PER_STAGE[FOUNDATION] = 1`). That makes 11 points by CD 100.
- **Keystones on the Pure Madra tree:** #1 Pure Core Awakening (the tree's only root: Empty Palm plus Smooth Flow) and #2 Power Font (the `power_font` ability) exist. #3, a burst or finisher, is not authored. See [PATH_PROGRESSION.md](PATH_PROGRESSION.md).
- **Ability slots:** all four are open from the start (`AbilityManager.MAX_SLOTS = 4`). `basic_strike` and `enforce` fill slots 1–2, so path abilities go into slots 3–4. The original idea of earning slots 3–4 through path nodes is not built.

## Player Experience (as built)

### Starting state (fresh save)

| State | Value | Source |
|---|---|---|
| Zone | Spirit Valley (`SpiritValley`, tile (0,0), always unlocked) | `zone_data_list.tres` (first entry) |
| Available zone actions | "Talk to the [INTERVENER]" only | `ZoneManager.get_available_actions()` |
| Map | Spirit Valley only, framed in fog. Test Zone (-1, 0), gated on `celestial_intervener_dialogue_1`, is hidden on the map (`hidden_on_map`) | `spirit_valley_zone.tres`, `test_zone.tres` |
| Madra | 25, with a cap of 100 at CD 0 | `SaveGameData.madra`, `foundation_advancement_stage.tres` |
| Core Density | Level 0, 0 XP | `SaveGameData` |
| Path points | 0, with the path set to `pure_madra` | `PathManager.DEFAULT_PATH_ID` |
| Abilities | `basic_strike` and `enforce`, unlocked and equipped | `SaveGameData` |
| Cycling technique | `foundation_technique` (Foundational Technique) | `SaveGameData` |
| Quests, events, conditions | None. The Goals board shows only the Breakthrough milestone ("Raise Core Density to 100", `0 / 100`). | — |
| HUD | The cultivator cabinet (Madra, Core Density, gold), the Goals and log boards, and the dock's Inventory, Abilities, Character, and Path buttons are visible from the first frame | — |

### Beat chain at a glance

```
START  Spirit Valley: only "Talk to the [INTERVENER]"
  │ NPC 1 (dialogue_1) ─ event celestial_intervener_dialogue_1 ─► Wilderness Cycling, Test Zone (hidden)
  │                    ─ start q_fill_core
BEAT 1  cycle to 100 Madra ─ cond q_fill_core_madra_full ─► step 0 done, NPC 2 visible
  │ NPC 2 (dialogue_2) ─ event celestial_intervener_dialogue_2 ─► q_fill_core complete
  │                    ─ event q_fill_core_completed ─► The Shallow Woods, Spring Forest Foraging
  │                    ─ start q_first_steps; the dialogue's end starts foraging (the zone's idle action)
BEAT 2  win any combat ─ event q_first_steps_enemy_defeated ─► step 0 done, NPC 3 visible
  │ NPC 3 (dialogue_3) ─ event celestial_intervener_dialogue_3 ─► q_first_steps complete ─► +1 path point
  │                    ─ start q_reach_core_density_10
  │ (player buys Pure Core Awakening; equips Smooth Flow and Empty Palm)
BEAT 3a (any Shallow Woods run) Aura Well tile ─ "Mark down the location"
  │                    ─ event aura_well_discovered ─► Aura Well training action
BEAT 3b CD 10 ─ cond q_reach_cd_10 ─► step 0 done, NPC 4 visible   (+1 path point from CD milestone)
  │ NPC 4 (dialogue_4) ─ event celestial_intervener_dialogue_4 ─► q_reach_core_density_10 complete
  │                    ─► Refugee Camp Map
  │ next Shallow Woods map places the Refugee Camp ─ "Approach the camp"
  │                    ─ event merchant_discovered ─► Traveling Merchant
BEAT 4  Traveling Merchant ─ shop: gold buys 6 gear pieces (once per save each) and Crude Scales
END OF AUTHORED CONTENT
```

### Beat 1: Awakening `IMPLEMENTED`

**Trigger:** a new save.

| # | Player does | What happens | Ids |
|---|---|---|---|
| 1 | Clicks **Talk to the [INTERVENER]** | Timeline `celestial_intervener_introduction_1` plays from label `dialogue_1` (2 lines). When it ends, the action is consumed (`max_completions` 1) and its `success_effects` run. | Action `celestial_intervener_dialogue_1` |
| 2 | — | `TriggerEventEffectData` fires the event and the condition latches. **Wilderness Cycling** appears (with a NEW seal), and the **Test Zone** unlocks. The Test Zone has no actions and stays hidden on the map. | Event and condition `celestial_intervener_dialogue_1` |
| 3 | — | `StartQuestEffectData` starts the quest. Toast: "Quest Started: Awaken Your Core". | Quest `q_fill_core`, step 0 `reach_max_madra` |
| 4 | Cycles with the Foundational Technique | 8 s cycle and 50 base Madra per cycle, scaled by mouse-tracking accuracy. The technique has no cycling zones, so it gives no Core Density XP. | `foundation_technique` |
| 5 | Reaches 100 Madra (the CD-0 cap) | The condition latches, step 0 completes ("Quest Updated: Return to the Celestial [INTERVENER]"), and **Return to the [INTERVENER]** (NPC 2) appears | Condition `q_fill_core_madra_full` (RESOURCE_AMOUNT, madra ≥ 100.0) |
| 6 | Clicks NPC 2 | Label `dialogue_2` plays, then the event fires and `q_fill_core` completes ("Quest Complete: Awaken Your Core") | Action and event `celestial_intervener_dialogue_2` |
| 7 | — | `q_fill_core.completion_effects` fires an event, the condition latches, and **The Shallow Woods** and **Spring Forest Foraging** appear | Event and condition `q_fill_core_completed`; actions `shallow_woods_adventure_action`, `sprint_forest_foraging_action` |
| 8 | — | NPC 2's second effect starts Beat 2 ("Quest Started: First Steps Out") | Quest `q_first_steps` |
| 9 | — | The dialogue was a session action, so its end resumes the zone's idle action: Spring Forest Foraging starts on its own ("Resumed Spring Forest Foraging"), with the Now strip and the map ring | `ActionManager.resolve_idle_action()` |

| Property | Value |
|---|---|
| Player goal (fiction) | Understand cultivation well enough to survive |
| Player goal (mechanical) | Learn cycling, fill the core, return to the NPC |
| Systems exercised | Dialogue, cycling, quests, unlocks |
| Exit gate | Adventure available, and `q_first_steps` active |

Deviations from the original design:
- The Madra bar is not gated; it is visible from the start.
- Foraging unlocks together with Adventure through a temporary gate.
- NPC 1 no longer awards a dagger.
- NPC 1 also unlocks the empty Test Zone, which is hidden on the map.

### Beat 2: First Steps Out `IMPLEMENTED`

**Trigger:** the NPC 2 click that completes Beat 1.

| # | Player does | What happens | Ids |
|---|---|---|---|
| 1 | Starts **The Shallow Woods** | Requires Madra ≥ 50% of adventure capacity: FOUNDATION × 10 × 0.5 = 50 at default stats. The run has a 300 s limit. The map comes from `shallow_woods.tres` (see [ADVENTURING.md](../adventuring/ADVENTURING.md)): Starving Dreadbeast ×3 and Amorphous Spirit ×4 regular fights, Coalescing Spirit ×2 and Ravenous Dreadbeast ×2 elites, a Manifested Spirit boss (the regular `amorphous_spirit` enemy), one Aura Well, and the Refugee Camp when eligible. Enemy stats are in [COMBAT.md](../combat/COMBAT.md). | Adventure `shallow_woods` |
| 2 | Wins any combat | On the first enemy death `AdventureCombat._on_enemy_health_changed()` fires the event. Step 0 completes ("Quest Updated: Return to the Celestial [INTERVENER]"), the condition latches, and NPC 3 appears in Spirit Valley. | Event and condition `q_first_steps_enemy_defeated` |
| 3 | Clicks NPC 3 | Label `dialogue_3` plays, then the event fires and `q_first_steps` completes. `AwardPathPointEffectData(1)` adds the first path point ("Quest Complete: First Steps Out"), and the dock's Path button shows its count seal. | Action and event `celestial_intervener_dialogue_3` |
| 4 | — | NPC 3's second effect starts Beat 3b's quest ("Quest Started: Harden Your Core") | Quest `q_reach_core_density_10`, step 0 `reach_cd_10` |
| 5 | Opens the Path tree and buys **Pure Core Awakening** | The keystone costs 1 point and is the only root, so it is the only purchase possible. It unlocks the ability `empty_palm` and the technique `smooth_flow` (see [ABILITIES.md](../abilities/ABILITIES.md)). The dock's Abilities button shows a ring until Empty Palm is equipped, and the Path button's seal clears with the spent point. Smooth Flow has to be equipped by hand in the cycling view, with no notification. | Node `pure_core_awakening` |

| Property | Value |
|---|---|
| Player goal (fiction) | Test the wilderness |
| Player goal (mechanical) | Survive one fight; collect the first tools |
| Systems exercised | Adventure, combat, quests, path tree, ability loadout |
| Exit gate | `q_first_steps` complete, Pure Core Awakening bought, `q_reach_core_density_10` active |

Deviations from the original design:
- There is no in-combat tutorial popup.
- Quests chain from NPC actions rather than from adventure entry or keystone purchase.
- Unlocks are equipped manually. Only the Abilities button has a notification ring: `CyclingManager.has_unequipped_unlocks()` exists, but no UI shows it.

### Beat 3a: Aura Well Discovery `IMPLEMENTED`

**Trigger:** reaching the Aura Well tile on any Shallow Woods map. This can happen as early as the first adventure.

- **Placement:** a `shallow_woods.tres` `encounter_quotas` entry with count 1, ANCHOR placement, `min_distance_from_origin` 3, and `min_fillers_on_path` 1. Every map gets exactly one Aura Well, drawn with the REST_SITE icon. Map generation is described in [ADVENTURING.md](../adventuring/ADVENTURING.md).
- **Choices** (`aura_well_encounter.tres`):
  - **Rest:** ChangeVitals with `body_hp_multiplier` 5.0 and `foundation_madra_multiplier` 2.0, which gives +50 HP and +20 Madra at the default BODY and FOUNDATION of 10. Always available.
  - **Mark down the location:** the same rest plus `TriggerEventEffectData("aura_well_discovered")`. `requirements = {aura_well_discovered: false}` and `completion_condition = aura_well_discovered`. Once the event has fired, every Aura Well renders this choice disabled as "✓ Location noted".
- **Unlock:** the event latches the condition `aura_well_discovered`, and the **Aura Well** training action (`aura_well_training`, TRAIN_STATS) appears in Spirit Valley.
- **Training:** 1 s ticks award +1.5 Madra per tick (`aura_well_madra_trickle_effect.tres`), and each training level awards +1 SPIRIT (`aura_well_spirit_award_effect.tres`). Levels cost 60, 300, 600, and 1200 ticks, then ×2 per level (2400, 4800, …). That is about 1, 5, 10, 20, and 40 minutes, with no cap.
- **No quest.** The new card, with its NEW seal, is the only signal. The Aura Well resolves before foraging only when the zone has no saved last idle action, so a player who forages keeps foraging until they pick the well.

### Beat 3b: Second Keystone + Merchant Unlock `IMPLEMENTED`

**Trigger:** `q_reach_core_density_10` starts at the NPC 3 click.

| # | Player does | What happens | Ids |
|---|---|---|---|
| 1 | Cycles with **Smooth Flow** | 15 s cycle, 200 base Madra, and 4 cycling zones that give Core Density XP per click (perfect / good / ok): 25/15/5, 25/15/5, 50/25/10, 25/15/5. CD 10 needs about 110 cumulative XP, roughly one perfect cycle. | `smooth_flow` |
| 2 | Reaches CD 10 | `CultivationManager` adds +1 path point (the milestone award). The condition latches, step 0 completes ("Quest Updated: Return to the Celestial [INTERVENER]"), and NPC 4 appears. | Condition `q_reach_cd_10` (CULTIVATION_LEVEL ≥ 10) |
| 3 | Optionally buys **Power Font** (Keystone #2) | It requires Pure Core Awakening and unlocks the `power_font` ability. The alternatives are Torrential Flow (MAJOR: a technique) and Expanded Core (MINOR: +25 Madra capacity). Nothing requires the keystone. | Node `power_font` |
| 4 | Clicks NPC 4 | Label `dialogue_4` plays, then the event fires and `q_reach_core_density_10` completes. The quest's `completion_effects` (`AwardItemEffectData`) add the **Refugee Camp Map** and log "Obtained 1x Refugee Camp Map" ("Quest Complete: Harden Your Core"). NPC 4 itself only fires the event. The map shows in Inventory → Quest Items. | Action and event `celestial_intervener_dialogue_4`; item `refugee_camp_map` |
| 5 | Starts another Shallow Woods run | The **Refugee Camp** anchor is placed: count 1, `min_distance_from_origin` 3, REST_SITE icon. Its live gate is `refugee_camp_map_owned` (ITEM_OWNED) = true and `merchant_discovered` = false. | Encounter `refugee_camp` |
| 6 | Chooses **Approach the camp** | The event fires and the condition latches, and **Traveling Merchant** appears in Spirit Valley. The tile then reads "The camp is empty now — they must have moved on, following your map back to the valley." Later maps never place the camp. | Event and condition `merchant_discovered`; action `spirit_valley_merchant` |
| 7 | Clicks **Traveling Merchant** | The shop opens: see [Beat 4](#beat-4-merchant-shop-implemented). | Action `spirit_valley_merchant` |

### Beat 4: Merchant Shop `IMPLEMENTED`

**Trigger:** clicking **Traveling Merchant**, which Beat 3b unlocks. There is no quest. Decisions and the pricing test plan are in the [Merchant v1 spec](../superpowers/specs/2026-10-19-merchant-v1-design.md).

- **Opening.** `ActionManager` emits `start_merchant` and the shop fades in over the zone view. The action stays current until the player presses Leave or Escape. That stops the action (`stop_merchant`) and fades the shop out; if another view has opened above the shop, it closes at once and that view stays open. When the shop closes, the zone's idle action resumes (the foraging or training the visit replaced, as the zone's last idle action). Every visit adds 1 to the action's completion count; the action has unlimited uses and no effects.
- **Stock** (`resources/merchants/spirit_valley_merchant_stock.tres`). Each price is the item's `base_value`. All prices are starting values.

| Item | Slot | Price | Limit |
|---|---|---|---|
| Crude Scale | Consumable | 10 | Unlimited |
| Cultivator's Cowl | Head | 40 | 1 per save |
| Makeshift Dagger | Main hand | 60 | 1 per save |
| Scripted Bark | Off hand | 75 | 1 per save |
| Leeching Ring | Accessory | 120 | 1 per save |
| Iron Shortsword | Main hand | 150 | 1 per save |
| Reinforced Robes | Armor | 180 | 1 per save |

- **Rules** (`MerchantManager`):
  - A gear piece bought from this merchant stays sold out for the rest of the save, even if the player trashes it. Purchases are kept per merchant in `SaveGameData.merchant_ledgers`.
  - When the price is above the player's gold, the row reads "Need N more gold" and Buy is disabled.
  - Hovering Buy previews the purchase beside the gold in the footer: "N left" in green when the player can afford it, "N short" in red when they can't.
  - When every equipment slot is full, gear rows read "Equipment full". Crude Scales stay buyable.
  - No gold moves until every check passes.
  - Broken stock data never takes gold. An entry with no item gets no row, and the shop logs a warning. An entry whose item class doesn't match its `item_type` (so `InventoryManager.award_items()` couldn't place it) can't be bought.
  - The merchant buys nothing back.
- **Look.** A dark teal panel with drifting mist, motes and a glowing edge, from `assets/themes/merchant/spirit_valley_merchant_theme.tres`. A merchant in another zone sets its own `shop_theme`. The log and Goals boards are hidden while the shop is open, so the panel never cuts off their text. Leave sits beside the title; the gold sits in the footer, beside the status line.

| Property | Value |
|---|---|
| Player goal (fiction) | Trade adventure gold for real gear |
| Player goal (mechanical) | Choose which upgrade to save for |
| Systems exercised | Gold, inventory, merchant, save |
| Exit gate | None; the shop is repeatable |

Deviations from the original design:
- Stock does not rotate in v1.
- The Refugee Camp discovery shipped with Beat 3b.

### Where content ends

After Beat 4:

- No quest is active, and the Goals board shows only the Breakthrough milestone.
- No further NPC actions, events, or conditions exist, and the Intervener is gone. Gold buys the Merchant's six gear pieces once each; after that it only buys Crude Scales.
- Only repeatable systems remain:
  - cycling (+1 path point per 10 CD levels)
  - Shallow Woods runs (elites, the Manifested Spirit boss, Aura Well rests, loot)
  - Aura Well training
  - Spring Forest Foraging
  - the Merchant (Crude Scales, and gear until it sells out)
  - consumables
  - Path tree purchases (14 nodes)
- Core Density keeps rising past 100 with no effect. `CultivationManager.attempt_breakthrough()` is an empty stub, only the Foundation `AdvancementStageResource` exists, there is no Tribulation scene, and no CD-100 condition is registered.
- The Test Zone is hidden on the map and has no actions (the dev panel's "Show hidden zones" toggle can show it).

### Beat index

| # | Beat | Key unlock / moment | Status |
|---|---|---|---|
| 1 | Awakening | Cycling, then Adventure and Foraging, via `q_fill_core` and NPCs 1–2 | `IMPLEMENTED` |
| 2 | First Steps Out | First victory, first path point, Keystone #1 (Pure Core Awakening) | `IMPLEMENTED` |
| 3a | Aura Well Discovery | Aura Well training action (+1.5 Madra/tick, +1 Spirit/level) | `IMPLEMENTED` |
| 3b | Second Keystone + Merchant unlock | CD 10, NPC 4, Refugee Camp Map, Refugee Camp, Merchant action | `IMPLEMENTED` |
| 4 | Merchant shop | Gold buys gear (once per save each) and Crude Scales | `IMPLEMENTED` |
| 5 | Elite Gear Drop | First elite defeated; tier-bump gear | `STUBBED` |
| 6 | Third Keystone | Keystone #3 at CD ~30 | `PLANNED` |
| 7 | Tribulation Guardian | Boss defeated, Advancement Zone accessible | `PLANNED` |
| 8 | Advancement Zone | Tribulation Site; `q_breakthrough_seek` | `PLANNED` |
| 9 | Tribulation | CD 100 plus Tribulation, then Copper | `PLANNED` |
| 10 | Zone 2 Onramp | Zone 2 accessible | `PLANNED` (sketch) |

## Planned beats (5–10)

### Beat 5: Elite Gear Drop `STUBBED`

- **Design:** Elites are always on the map. With two keystones, Aura Well attributes, and merchant gear, an elite is winnable but not trivial. An optional `q_first_elite` starts when an elite tile is first seen and completes on defeat. The reward is the first real equipment tier bump.
- **Exists:** 2 × Coalescing Spirit and 2 × Ravenous Dreadbeast elites (COMBAT_ELITE) per map. The Ravenous Dreadbeast's `CombatChoice.success_effects` rolls a Dreadbeast Tooth Necklace at 25%.
- **Needs:**
  - the `q_first_elite` quest
  - an elite-defeated event, via a `TriggerEventEffectData` in the elite `CombatChoice.success_effects` (data-only)
  - a "tile first seen" hook, which doesn't exist
  - a guaranteed tier-bump reward

### Beat 6: Third Keystone `PLANNED`

- **Design:** Core Density ~30 awards the third path point. The player picks Keystone #3, a combat burst or finisher that raises the damage ceiling for the Guardian. No quest; the path-point notification is the signal.
- **Exists:** CD 30 awards a point, and the dock's Path button shows the unspent balance on a count seal.
- **Needs:**
  - a third KEYSTONE node and its ability on the Pure Madra tree
  - a louder notification than the dock seal if playtests miss it (see Work Remaining → UI)
  - retuning, since CD 30 currently arrives about four perfect Smooth Flow cycles after Beat 2 (see [Economy](#loop-economy))

### Beat 7: The Tribulation Guardian `PLANNED`

- **Design:** The Guardian has always been on the map. `q_tribulation_guardian` ("Defeat the Tribulation Guardian") starts the first time the player enters an adventure with Keystone #3, or first reaches the Guardian tile. This is the marquee Foundation fight. Defeating the Guardian makes the Advancement Zone accessible.
- **Exists:** the Shallow Woods boss slot. Today it is `manifested_spirit_encounter` (COMBAT_BOSS, `min_distance_from_origin` 5), which fights the regular `amorphous_spirit` enemy. A boss win ends the adventure with `stop_action(true)`, and **nothing records the clear**: the boss `CombatChoice` has no `success_effects`, `spirit_valley_adventure_action.tres` has no `success_effects`, no event fires, and `ADVENTURE_COMPLETED` always evaluates false. No beat can be gated on "clear the Shallow Woods" yet. Encounter details are in [ADVENTURING.md](../adventuring/ADVENTURING.md).
- **Needs:**
  - the Guardian encounter and enemy
  - the quest
  - a boss-defeated event: a TriggerEvent in the boss `CombatChoice.success_effects`, or an implementation of `ADVENTURE_COMPLETED`
  - a trigger for "has Keystone #3", which needs a node-purchased event or condition type; neither exists

### Beat 8: The Advancement Zone `PLANNED`

- **Design:** A small, atmospheric zone centered on the Tribulation Site. `q_breakthrough_seek` ("Reach the Breakthrough Site and cultivate to full Core Density") progresses toward CD 100. No combat. The zone can be revisited before CD 100 without triggering the Tribulation.
- **Exists:** the map's LOCKED and UNCHARTED states (`zone_unlock_conditions`, `chart_conditions`), with plates naming the blocker and popovers giving the requirement and "Show me". The dev demo zones show them today: a locked "Advancement Zone" at (0, -1) ("Defeat the Tribulation Guardian in The Shallow Woods") and an uncharted hex beyond it. The Test Zone at (-1, 0) is an empty placeholder, hidden on the map.
- **Needs:**
  - the zone's `ZoneData` and actions
  - the quest
  - a gating event from Beat 7. Note that `ZONE_UNLOCKED` is unimplemented.

### Beat 9: Tribulation `PLANNED`

- **Design:** At the Tribulation Site with CD ≥ 100, the Tribulation mini-game runs. Success advances the player to Copper and ends Foundation. Failure is open (Q-5).
- **Conflicting design:** [breakthrough-tribulation.md](../cultivation/breakthrough-tribulation.md) gates the breakthrough only on CD 100, which adds a Breakthrough Encounter tile to regular adventure maps. That flow is a Dialogic beat, then a 15–30 s mouse-tracking Tribulation, then on success Copper with a CD reset to 0 and Scripting and Elixir Making unlocked through `CULTIVATION_STAGE` conditions. Failure has no penalty. Beats 7–9 here instead route through a Guardian and an Advancement Zone, and Q-5 leans toward a partial penalty. Reconcile the two before building.
- **Exists:**
  - `CultivationManager.attempt_breakthrough()` (empty)
  - the `AdvancementStage` enum (FOUNDATION through SILVER)
  - `PATH_POINTS_PER_STAGE[COPPER] = 2`
  - the `CULTIVATION_STAGE` condition type
  - UnlockManager's sweep on `advancement_stage_changed`
- **Needs:**
  - a Tribulation scene
  - a stage-advance method
  - a Copper `AdvancementStageResource`
  - a CD-100 condition
  - dialogue timelines
  - Copper unlock conditions and content

### Beat 10: Zone 2 Onramp `PLANNED` (sketch)

- **Design:** A successful Tribulation makes Zone 2 visible. A short spirit-NPC moment acknowledges that the disaster is spreading and the player must follow. Full Zone 2 content belongs in a future doc.
- **Needs:** Zone 2 `ZoneData` and tile, the gating event, the NPC and timeline.

## Loop Economy

### Current data values

| Value | Data | Source |
|---|---|---|
| Starting Madra / Foundation cap | 25 / 100 + 5 × CD level (100 at CD 0, 150 at CD 10, 600 at CD 100) | `SaveGameData`, `foundation_advancement_stage.tres` |
| Adventure capacity / start threshold | FOUNDATION × 10 (100 at default) / 50% of capacity | `CharacterAttributesData.get_max_madra()`, `ResourceManager` |
| Shallow Woods time limit | 300 s | `spirit_valley_adventure_action.tres` |
| Foundational Technique | 8 s cycle, 50 base Madra (accuracy-scaled), no zones, so 0 CD XP | `foundation_cycling_technique.tres` |
| Smooth Flow | 15 s cycle, 200 base Madra, 4 zones; per-cycle CD XP is 125 perfect / 70 good / 25 ok | `smooth_flow.tres`, `cycling_zone_data/zone_1..4.tres` |
| Torrential Flow | 8 s cycle, 250 base Madra, 1 zone (30 / 25 / 20 XP) | `torrential_flow.tres` |
| CD XP to reach level L | 10 × 1.02^(L−1) | `core_density_base_xp_cost` (default 10) × `core_xp_scaling_factor` 1.02 |
| Cumulative CD XP | CD 10 ≈ 110; CD 30 ≈ 406; CD 50 ≈ 846; CD 100 ≈ 3,122 | Computed |
| Path points by CD 100 | 11 (1 quest + 10 milestones) | `q_first_steps`, `CultivationManager` |
| Pure Madra tree capacity | 14 nodes at 1 point each = 22 purchases (repeatables max 3 / 5 / 3) | `resources/path_progression/pure_madra/nodes/` |
| Aura Well training | +1.5 Madra per 1 s tick; +1 SPIRIT per level; 60 / 300 / 600 / 1200 ticks, then ×2 | `aura_well_training_action.tres`, `TrainingActionData` defaults |
| Aura Well rest | +5 × BODY HP, +2 × FOUNDATION Madra | `aura_well_encounter.tres` |
| Consumables | Crude Scale and Barely Coalesced Scale: +20 Madra (10 s cooldown, not enforced) | `resources/items/consumables/` |
| Merchant prices | Crude Scale 10, Cultivator's Cowl 40, Makeshift Dagger 60, Scripted Bark 75, Leeching Ring 120, Iron Shortsword 150, Reinforced Robes 180 (starting values; all gear 625) | Item `base_value`; stock in `spirit_valley_merchant_stock.tres` |

**Pacing reality (computed):** No Core Density XP multiplier is applied in code. `PathEffectsSummary.core_density_xp_mult` and `CyclingActionData.xp_multiplier` are never read. With Smooth Flow, CD 10 takes about 1 perfect cycle (≈15 s), CD 30 about 4 cycles, and CD 100 about 25 perfect or 45 good cycles, which is roughly 6–11 minutes of cycling. That is far ahead of the [pacing targets](#progression-pacing-targets) (Beat 3b at 6–15 min, Beat 6 at 20–30 min, Beat 9 at 35–60 min). The curve must be retuned before Beats 6–9 ship.

### Targets to validate

| Area | Metric | Starting target | Fail signal / test |
|---|---|---|---|
| Cycling | Cycles to fill Madra in Beat 1 | 2–4 | Player stuck more than 5 min (Q-1) |
| Cycling | Madra per session, average vs skilled | TBD | Skilled-play gap under 20% means skill expression is too weak |
| Cycling | Time per session | TBD | Over 45 s is a chore; under 10 s is trivial |
| Adventure | Combats won before death (first runs) | ~2–3 | Accidental first clear, or death in the first fight (Q-2) |
| Adventure | Cycles needed to fund one adventure | ~1 | More than 3 cycles per adventure means the loop is unbalanced (Q-4) |
| Adventure | Real-time minutes per run | TBD (cap 5) | Over 10 min of committed play per early attempt |
| Adventure | Madra runs dry mid-run | TBD | Over 30% of runs means adventures are too expensive |
| Combat | Starter enemy TTK | ~5–10 s | Over 20 s is a slog; under 3 s leaves no interaction (Q-3) |
| Combat | Ability uses per fight | TBD | Fewer than 1 means the fight ends before decisions matter |
| Rewards | Adventures between meaningful drops | TBD | More than 4 empty runs in a row |
| Rewards | Concurrent quests | TBD | More than 3 overloads the early tracker |
| Rewards | Merchant gear price | ~3–5 adventures of gold | Unaffordable, or bought on the first visit (Q-8) |

### Progression pacing targets

| Milestone | Target minute | Fail signal / test |
|---|---|---|
| Beat 1 complete (Adventure unlocked) | 0–3 | Stuck cycling more than 5 min |
| Beat 2 complete (first victory and return) | 3–6 | First adventure over 10 min, or under 2 min |
| Beat 3a (Aura Well discovered) | 6–15 | |
| Beat 3b (CD 10, Keystone #2, map, Merchant) | 6–15 | Computed: reachable about 1 cycle after equipping Smooth Flow |
| Beat 4 (Merchant shop) | 10–18 | |
| Beat 5 (Elite defeated) | 15–25 | |
| Beat 6 (Keystone #3 at CD ~30) | 20–30 | Computed: CD 30 ≈ 4 Smooth Flow cycles |
| Beat 7 (Guardian defeated) | 25–45 | |
| Beat 8 (Advancement Zone entered) | 30–50 | |
| Beat 9 (Tribulation success, Copper) | 35–60 | Whole Foundation over 75 min is too slow |

## Open Tuning Questions

Template: **ASSUMPTION** / **IMPACT** / **IF WRONG** / **VALIDATE** / **STATUS**. When a question resolves, move its answer into the economy tables and delete the entry.

### Q-1: Cycles to fill the core in Beat 1

- **ASSUMPTION:** 2–4 sessions to go from 25 to 100 Madra. The data allows at least 2 cycles at full accuracy (50 base per 8 s cycle).
- **IMPACT:** Sets the first impression of cycling.
- **IF WRONG:** The intro is trivial, or it drags and the player bounces.
- **VALIDATE:** Internal playtest; target about 3 cycles for average play.
- **STATUS:** Open

### Q-2: Combats before failure in early adventures

- **ASSUMPTION:** About 2–3 wins before the first death.
- **IMPACT:** The early loss and retry rhythm.
- **IF WRONG:** An accidental first clear, or death in the first fight.
- **VALIDATE:** Record combats beaten before death across at least 5 first runs.
- **STATUS:** Open

### Q-3: Starter combat numbers

- **ASSUMPTION:** The starter enemy dies in 3–5 ability uses; median TTK is about 7 s; player loss rate is 30–50%.
- **IMPACT:** Combat rhythm.
- **IF WRONG:** The fight feels like an auto-win or an impossible wall.
- **VALIDATE:** Test Starving Dreadbeast and Amorphous Spirit fights in isolation (stats in [COMBAT.md](../combat/COMBAT.md)).
- **STATUS:** Open

### Q-4: Cycle-to-adventure ratio

- **ASSUMPTION:** One full Madra bar funds one adventure (about 1:1).
- **IMPACT:** If cycles per adventure drifts above 3, the loop is choreographed around cycling.
- **IF WRONG:** Frequent idling at full Madra, or running dry mid-run.
- **VALIDATE:** Instrument cycles per adventure; target 0.8–1.2 mid-Foundation.
- **STATUS:** Open

### Q-5: Tribulation failure consequence

- **ASSUMPTION:** Undecided between (a) a full reset with unlocks kept, (b) a free retry, and (c) a drop to about CD 90. This doc leans toward (c). [breakthrough-tribulation.md](../cultivation/breakthrough-tribulation.md) specifies (b), no penalty.
- **IMPACT:** The weight of the climax.
- **IF WRONG:** The climax feels weightless, or players quit.
- **VALIDATE:** Pick one design, playtest, and observe the retry feel.
- **STATUS:** Open. The two docs conflict and must be reconciled.

### Q-6: Path points vs tree size

- **ASSUMPTION:** Named beats at CD 10 and ~30; CD 40–90 award "silent" points.
- **IMPACT:** Points pile up, or there is room for tree flexibility.
- **IF WRONG:** The tree runs out of meaningful nodes, or points sit unspent.
- **VALIDATE:** Compare the 11 points earned by CD 100 against the 22 purchases available on the 14-node Pure Madra tree. Only 2 of those nodes are keystones; Keystone #3 is missing.
- **STATUS:** Open

### Q-7: Time-to-beat targets

- **ASSUMPTION:** Foundation fits in 30–60 minutes ([pacing targets](#progression-pacing-targets)).
- **IMPACT:** Middle beats feel padded or compressed.
- **IF WRONG:** Late beats feel rushed, or early beats run long.
- **VALIDATE:** Timestamp each beat in playtests. The computed CD pacing already undercuts the targets.
- **STATUS:** Open

### Q-8: Merchant pricing vs adventure gold

- **ASSUMPTION:** One piece costs about 3–5 adventures of gold. Merchant v1 sets the Ring (120), Shortsword (150) and Robes (180) in that band at ~45 gold per run. It deliberately prices the Cowl (40), Dagger (60) and Bark (75) lower, so the first visit has a purchase.
- **IMPACT:** Whether the Merchant feels meaningful.
- **IF WRONG:** A dead system, or a trivial purchase.
- **VALIDATE:** The [Merchant v1 test plan](../superpowers/specs/2026-10-19-merchant-v1-design.md#starting-values-and-test-plan). Over at least 5 playthroughs, record the gold banked at the first visit and the runs between main-piece purchases. Pass: the first visit buys at most one cheap piece plus scales, and each main piece takes 3–5 runs.
- **STATUS:** Open. Starting values are set; not playtested.

### Q-9: Aura Well training cost curve

- **ASSUMPTION:** An exponential curve: about 1, 5, 10, and 20 minutes for the first four Spirit points. Implemented as `[60, 300, 600, 1200]` ticks with a ×2 tail.
- **IMPACT:** How often the player returns to train instead of adventuring or cycling.
- **IF WRONG:** Training trivializes combat, or is ignored.
- **VALIDATE:** Check total attributes at Beats 5, 7, and 9 against gear and keystone contributions.
- **STATUS:** Open (implemented, not playtested)

## Key Files

| File | Role in the chain |
|---|---|
| `resources/zones/spirit_valley_zone/spirit_valley_zone.tres` | Spirit Valley and its 9 actions |
| `resources/zones/spirit_valley_zone/zone_actions/celestial_intervener_dialogue_{1..4}.tres` | NPC beats (events and quest starts) |
| `resources/zones/spirit_valley_zone/zone_actions/wilderness_cycling_action.tres`, `spirit_valley_adventure_action.tres`, `spring_forest_foraging_action.tres` | Beat 1 unlocks |
| `resources/zones/spirit_valley_zone/zone_actions/aura_well_training_action.tres` (+ `aura_well_madra_trickle_effect.tres`, `aura_well_spirit_award_effect.tres`) | Beat 3a training |
| `resources/zones/spirit_valley_zone/zone_actions/spirit_valley_merchant_action.tres` | Beat 3b Merchant action, a `MerchantActionData` (stock, greeting, shop theme) |
| `resources/merchants/spirit_valley_merchant_stock.tres` | Beat 4 stock and limits |
| `singletons/merchant_manager/merchant_manager.gd` | Beat 4 purchase rules and per-merchant ledgers |
| `scenes/merchant/` | Beat 4 shop view, rows, atmosphere and view state |
| `assets/themes/merchant/spirit_valley_merchant_theme.tres` | Beat 4 Spirit Valley shop look |
| `resources/zones/test_zone/test_zone.tres` | Empty Test Zone (unlocks at NPC 1, hidden on the map at (-1, 0), no description) |
| `resources/zones/dev/` | Dev demo zones for the locked and uncharted map states (Beats 7–10's machinery) |
| `resources/quests/q_fill_core.tres`, `q_first_steps.tres`, `q_reach_core_density_10.tres`, `quest_list.tres` | Quests |
| `resources/unlocks/*.tres`, `unlock_condition_list.tres` | Conditions |
| `resources/effects/trigger_event/celestial_intervener_dialogue_1.tres` | NPC 1 event effect |
| `assets/dialogue/timelines/celestial_intervener_introduction_1.dtl` | The four dialogue labels |
| `resources/adventure/data/shallow_woods.tres` | Adventure quotas (Aura Well, Refugee Camp, combats, boss) |
| `resources/adventure/encounters/shallow_woods/special_encounters/aura_well_encounter.tres`, `refugee_camp_encounter.tres` | Special encounters |
| `resources/items/quest_items/refugee_camp_map.tres` | Beat 3b reward |
| `resources/path_progression/pure_madra/nodes/pure_core_awakening.tres`, `power_font.tres` | Keystones #1 and #2 |
| `scenes/combat/adventure_combat/adventure_combat.gd` | `q_first_steps_enemy_defeated` producer |
| `singletons/cultivation_manager/cultivation_manager.gd` | CD milestone path points; `attempt_breakthrough()` stub |
| `tests/integration/test_aura_well_discovery_unlock.gd`, `test_beat_3b_merchant_unlock.gd` | Beat 3a and 3b integration tests |
| `tests/unit/test_merchant_manager.gd`, `test_merchant_data.gd`, `test_merchant_view_state.gd`, `test_spirit_valley_merchant_stock.gd`, `test_spirit_valley_merchant_theme.gd`, `tests/integration/test_merchant_shop_flow.gd` | Beat 4 tests |

## Work Remaining

### Bugs

- `[MEDIUM]` Quests can soft-lock. QuestManager never re-checks a step after advancing, so a "return" event that fires early leaves the quest stuck. Normal play avoids this through NPC gating, but the dev panel's force-unlock reproduces it. See [QUESTS.md](QUESTS.md).
- `[MEDIUM]` `dialogue_1` has malformed BBCode: `[color=blue][CORE][color]` is never closed. See [DIALOGUE.md](../infrastructure/DIALOGUE.md).

### Missing Functionality

- `[HIGH]` There is no breakthrough: `CultivationManager.attempt_breakthrough()` is empty, and there is no Copper stage resource, no Tribulation scene, and no CD-100 gate. This blocks Beats 8–10 and the Copper milestone.
- `[MEDIUM]` Once the six gear pieces are bought (625 gold), gold only buys Crude Scales. The next gold sink needs new stock (for example a Copper merchant) or rotation.
- `[MEDIUM]` No events or working condition types exist for an elite defeated, the boss defeated, an adventure completed, or a zone unlocked. `ADVENTURE_COMPLETED` and `ZONE_UNLOCKED` always return false. Beats 5, 7, and 8 depend on them.
- `[MEDIUM]` There is no "path node purchased" event or condition, which Beat 7's quest trigger ("enters an adventure with Keystone #3") needs.
- `[LOW]` The Madra bar is not gated behind Beat 1 as the original design intended.

### Content

- `[HIGH]` Nothing narrative exists after Beat 3b: no quest, dialogue, or NPC leads toward Beats 4–10 or the breakthrough.
- `[HIGH]` Keystone #3 (burst or finisher) is not on the Pure Madra tree, which has only two KEYSTONE nodes.
- `[HIGH]` The Core Density curve undercuts the pacing targets. CD 10 arrives within about one Smooth Flow cycle, and CD 100 within about 6–11 minutes of cycling (see [Economy](#loop-economy)).
- `[MEDIUM]` Player-facing names are placeholders:
  - "[INTERVENER]" in action names, quest steps, and descriptions
  - the display name "Intervener [Celestial]"
  - "[CORE]", "[DREADBEAST]", "[REMNANT]", "[TIMELINE ALTERING EVENT]", and "[REPORT REQUESTED]" in the timeline
  - The map's `from_source`, "Old Vesh, in the broken shrine", contradicts the Intervener handing it over.
  - The map's icon is the placeholder `res://64.png`.
- `[LOW]` Spring Forest Foraging still uses the temporary Beat 1 gate (`q_fill_core_completed`) and `test_loot_table_foraging.tres`.
- `[LOW]` The Tribulation Guardian is not authored. The boss slot holds Manifested Spirit, which reuses the regular `amorphous_spirit` enemy.

### UI

- `[MEDIUM]` Path points are announced only by the dock. While points are unspent, the Path button shows the brass ring and a count seal (the dock listens to `points_changed`), which is the signal Beat 6 relies on. Nothing writes a log line or shows a toast, so a CD-milestone point earned while cycling (the view covers the dock) or in an adventure goes unseen until the zone view returns. Playtest whether the seal is enough.
- `[HIGH]` Beat 3b can stall a new player. The Foundational Technique gives 0 CD XP, so "Reach Core Density level 10" can't progress until the player buys Pure Core Awakening and equips Smooth Flow. The only hint is "that fancy new cycling technique" in `dialogue_3`, and cycling has no notification (`CyclingManager.has_unequipped_unlocks()` is unused).
- `[MEDIUM]` The Aura Well discovery and the Refugee Camp search have no quest on the Goals board. The map's purpose is explained only in `dialogue_4` and the item description.
- `[LOW]` On first launch there is no objective until the player clicks the single NPC action. The Goals board shows only the Breakthrough milestone.
- `[LOW]` Merchant gear purchases log as "Looted 1x …" (Crude Scales as "Obtained 1x …"), because the shop awards items through `InventoryManager.award_items()`.

### Tech Debt

- `[LOW]` Only Beats 3a and 3b have integration tests. The Beat 1–2 chain is untested end to end: NPC 1 → `q_fill_core` → NPC 2 → `q_first_steps` → combat event → NPC 3 → path point. The combat-to-event test is tautological.
