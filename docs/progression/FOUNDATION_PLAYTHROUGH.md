# Foundation Stage Playthrough Plan

> **Purpose:** the intended 0-to-advancement path through the Foundation stage and Zone 1 (Spirit Valley, placeholder name) plus a sketch of the Zone 2 handoff. This is the *target* — the code converges toward this, not the other way around. When something feels off in playtest, this is where we write down *why* and *what to tune*.

> **Scope:** Foundation stage only. Target real-time length: **30-60 minutes** of committed play, **10 beats**. Ends at the first breakthrough / Tribulation leading into Copper.

> **How to use this doc:**
> - **Section 1 (Spine)** answers: *what should the player be doing right now, and what unlocks next?*
> - **Section 2 (Economy)** answers: *are the numbers tuned right?*
> - **Section 3 (Questions)** answers: *what do we not yet know and how will we find out?*
> - When a design decision lands, update the relevant section. When a playtest resolves an open question, promote it from Section 3 into a concrete number in Section 2.

---

## Status Legend

| Tag | Meaning |
|---|---|
| `PLANNED` | Described in this doc, no code yet |
| `STUBBED` | Systems/data wired but content placeholder |
| `IMPLEMENTED` | Fully coded + content, not playtested end-to-end |
| `PLAYTESTED` | Played through; feel validated; numbers settled |

---

## Framing notes

These assumptions shape the entire spine. Update here if they change.

- **Adventure tiles always exist; they are gated by difficulty, not by progressive unlocking.** The player can always walk to any tile — they just die before reaching or surviving it early. "Discovery" and "unlock" of an adventure feature means the player finally survives long enough to interact.
- **Adventures run to death or clear — no retreat button.** Consistent with incremental-genre conventions (Pokeclicker etc.). First adventures are expected to end in death; that is the loop.
- **Quests only where ambiguous.** If the next objective is self-evident from UI (new zone action appearing, path-point notification, new quest tracker entry), no explicit quest is needed.
- **NPCs are placeholder roles.** Story/thematic framing comes later; beats hit gameplay moments first.
- **Path points in Foundation:**
  - First point is a **one-time freebie** (reward for Beat 2).
  - Subsequent points come from Core Density level milestones — every 10 CD levels awards 1 path point (existing `PathManager` behavior).
- **Keystones** are keystone-tier nodes on the Pure Madra path tree. All three live on the same tree for Foundation — distinct paths (Blackflame, Earth, etc.) are not yet scaffolded. They grant:
  - **Keystone #1** (Beat 2, `pure_core_awakening`): new cycling technique (generates CD XP) + combat ability + path lore.
  - **Keystone #2** (Beat 3b): ability-focused — gives a second combat ability for slot 2.
  - **Keystone #3** (Beat 6): combat-focused — burst/finisher ability that raises damage ceiling.
- **Ability slots 3-4** are earned via path-tree non-keystone nodes (later in the tree), not via scripted beats.

---

## 1. Progression Spine

### Beat 1 — Awakening `PLANNED`

**Initial state:** Zone 1 starting view. One zone action available: *Talk to [NPC]*.

- **Talk to NPC (first time)** → dialogue (disaster context, cultivation primer).
  - **Unlocks:** Madra bar UI, Cycling zone action.
  - **Quest starts:** `q_fill_core`
    - Step 1: *Reach max Madra by cycling*
    - Step 2: *Return to [NPC]*
- Player cycles **2-4 sessions** (starting value → [§3 Q-1](#q-1-cycles-to-fill-core-in-beat-1)).
- **Talk to NPC (second time)** → `q_fill_core` completes.
  - **Unlocks:** Adventure zone action, Zone 1 adventure map.

| Property | Value |
|---|---|
| Player goal (fiction) | Understand cultivation enough to survive. |
| Player goal (mechanical) | Learn cycling → fill bar → return to NPC. |
| Systems exercised | Dialogue, cycling, quests. |
| Primary emotion | Curiosity / discovery. |
| Exit gate | Adventure zone action is available and the player enters it. |

### Beat 2 — First Steps Out `IMPLEMENTED`

**Trigger:** Beat 1 completion. `celestial_intervener_dialogue_2.success_effects` fires a `StartQuest("q_first_steps")` sub-resource on the same NPC click that completes `q_fill_core` (Pattern B — chain transitions live on NPC actions, not in quest `completion_effects`).

- First adventure is the **normal Spirit Valley baseline** — same tiles, same encounters; `test_enemy` retuned so the player loses ~50% HP winning one combat (BODY 10→0 drops enemy HP 200→100; STR 10→13 raises damage 11→14 per cast).
- **`q_first_steps` — 2 steps:**
  - Step 1: *"Defeat an enemy in combat"* — completes on `q_first_steps_enemy_defeated` event, fired by `AdventureCombat` when `trigger_combat_end(true, ...)` emits on victory.
  - Step 2: *"Return to the Celestial Intervener"* — completes on `celestial_intervener_dialogue_3` event (third NPC action, gated by step 1's completion via the `q_first_steps_enemy_defeated` unlock condition).
- **`q_first_steps.completion_effects`:** `AwardPathPointEffect(1)` only — grants the first Path Point via `PathManager.add_points(1)`. Next-quest transition lives on NPC 3 per Pattern B.
- **NPC 3 (`celestial_intervener_dialogue_3`) `success_effects`:** `TriggerEvent("celestial_intervener_dialogue_3")` then `StartQuest("q_reach_core_density_10")` — Beat 3's stub quest becomes active.
- **No in-combat tutorial popup.** Quest description does the light onboarding; combat UI does the teaching.
- **Manual equip.** Player spends the path point in the Path Tree UI on Pure Core Awakening (only purchasable node at this point). Keystone unlocks Smooth Flow + Empty Palm via existing PathManager → CyclingManager/AbilityManager wiring. Player manually equips via CyclingView and AbilitiesView.
- **Badge indicator** on the Abilities system-menu button signals unequipped unlocks (`AbilityManager.has_unequipped_unlocks()` drives visibility; listens to `ability_unlocked` + `equipped_abilities_changed`). Cycling badging deferred — cycling enters via a zone action, not a SystemMenuButton (different UI surface).

| Property | Value |
|---|---|
| Player goal (fiction) | Test the wilderness. |
| Player goal (mechanical) | Survive or die; collect first real tools. |
| Systems exercised | Adventure, combat, inventory, path tree, quests. |
| Primary emotion | Tension → relief (or: failure → resolve to try again). |
| Exit gate | `q_first_steps` complete, 1 Path Point spent on Pure Core Awakening keystone, `q_reach_core_density_10` active. |

**Deviations from the original plan** (documented for reference):
- No tutorial popup (cut for scope; incremental-genre convention — combat UI IS the tutorial).
- `q_first_steps` triggered by NPC 2 click (Pattern B) rather than by "adventure entry" — identical player experience.
- `q_reach_core_density_10` starts on NPC 3 click (Pattern B) rather than on keystone purchase — also identical moment functionally.
- Keystone effects are not auto-equipped; player equips manually. Badge indicator signals availability.

### Beat 3 — Preparing to Go Deeper `PLANNED`

*Two parallel tracks; either order. Both must resolve before Beat 4 is reachable.*

#### Beat 3a — Aura Well Discovery `IMPLEMENTED`

- During an adventure, player may reach an **Aura Well** special tile — one entry in `shallow_woods.special_encounter_pool`. With only Aura Wells in the pool today, every map currently has ~4 Aura Wells (one of the 5 special slots is overwritten with the boss). As more special encounters land, the pool diversifies.
- Encounter panel offers two choices:
  - **Rest** — restores `5 × BODY` HP and `2 × FOUNDATION` Madra. Always available.
  - **Mark down the location** — same Rest payload *plus* fires the `aura_well_discovered` event. Gated by `requirements = {aura_well_discovered: false}` so it's only pickable pre-discovery. Paired with `completion_condition = aura_well_discovered` + `completed_label = "✓ Location noted"`, so sibling Aura Well tiles (and Aura Wells on future adventures) render the button as "✓ Location noted" grayed.
- Firing `aura_well_discovered` satisfies the `aura_well_discovered` unlock condition on the `aura_well_training` zone action → the **Aura Well** button appears in Zone 1's main view.
- Zone action is a `TrainingActionData`: 1s ticks, `+1.5 Madra` trickle per tick, `ticks_per_level = [60, 300, 600, 1200]` with `tail_growth_multiplier = 2.0` (~1m / 5m / 10m / 20m for first four points, see [§3 Q-9](#q-9-basic-training-cost-curve)). Each level crossed awards `+1 Spirit` attribute.
- **No quest.** New zone action appearing in Zone 1 is the signal.
- **Schema additions this beat introduced** (referenced by later beats):
  - `UnlockConditionData`-keyed `Dictionary` for `EncounterChoice.requirements` (`{condition: expected_bool}`) replaces the older Array + `negate` design.
  - `EncounterChoice.completion_condition` + `EncounterChoice.completed_label` — per-choice completion state, independent of eligibility.
  - `ChangeVitalsEffectData.body_hp_multiplier` + `foundation_madra_multiplier` — attribute-scaled Rest effect.

#### Beat 3b — Second Keystone + Merchant Handoff `IMPLEMENTED (map + merchant unlock only — Merchant shop UI still PLANNED)`

- Player cycles with Keystone #1 technique; Core Density rises.
- At **Core Density 10**, `CultivationManager`'s existing CD-milestone hook awards the second path point. `q_reach_core_density_10`'s `completion_effects` award the Refugee Camp Map only — no path-point double-award.
- Player picks Keystone #2 (ability-focused) on the Pure Madra tree → second combat ability equipped to slot 2.
- `q_reach_core_density_10` step 1 completes on CD10. A **second step** sends the player back to the Celestial Intervener — NPC hands over a **map** item, fires the next event, and starts Beat 4's quest chain. This map unlock is the gate that enables the **Merchant** zone action (Beat 4 below).

| Property | Value |
|---|---|
| Combined effect | Adventure viability rises via attributes + passive resources (3a), a second combat ability (3b), and the Merchant unlock (3b → 4 handoff). |
| Exit gate | Aura Well discovered AND Keystone #2 picked AND NPC map handed over. |

### Beat 4 — Refugee Camp `PLANNED`

**Trigger:** Player now survives long enough to reach the **Refugee Camp tile** on the adventure map.

- One-shot flavor event: small group of survivors, a wandering merchant among them.
- **Unlocks:** Merchant zone action in Zone 1 main view.
  - Merchant sells equipment one tier above starter gear, priced in gold. Rotating stock (design TBD).
  - Gold — passively accumulated from adventures — now has a sink.
- **No quest.**

### Beat 5 — Elite Gear Drop `PLANNED`

**Trigger:** Player reaches and defeats the **Elite encounter** on its fixed adventure tile.

- Elite has always been present; the player has been walking past / dying.
- With 2 keystones + Spirit Well attributes + merchant gear, the elite is winnable but not trivial.
- **Optional quest:** `q_first_elite` — starts when the elite tile is first *seen* (signals "this is a thing to aim for"); completes on defeat.
- **Reward:** equipment tier bump — the first "real" loot moment.

### Beat 6 — Third Keystone `PLANNED`

**Trigger:** Core Density reaches ~30 → third path point awarded.

- Player picks Keystone #3 — a **combat-focused burst/finisher ability** (see [§3 Q-6](#q-6-core-density-thresholds-for-path-points-in-foundation)).
- **No quest.** Path-point notification is the signal.
- **Effect:** combat feel shifts from sustain (Keystones #1-2) to burst-capable — needed to threaten the Guardian (Beat 7).

### Beat 7 — The Tribulation Guardian `PLANNED`

**Trigger:** Player is strong enough to reach and survive the **Tribulation Guardian boss tile**.

- Guardian has always been on the map; player has been unable to approach or survive.
- **Quest:** `q_tribulation_guardian` — "Defeat the Tribulation Guardian." Starts the first time the player enters adventure with Keystone #3, or first reaches the Guardian tile — whichever is sooner.
- Marquee fight of Foundation stage. First encounter the player has to *earn the right to attempt*.
- **Defeat** → `q_tribulation_guardian` completes → **Advancement Zone becomes accessible.**

### Beat 8 — The Advancement Zone `PLANNED`

**Trigger:** Advancement Zone is accessible (link from Zone 1 map, or as a distinct zone — implementation TBD).

- Player enters Advancement Zone — smaller, atmospheric area centered on the **Tribulation / Breakthrough Site**.
- **Quest:** `q_breakthrough_seek` — "Reach the Breakthrough Site and cultivate to full Core Density." Progresses as the player approaches CD 100.
- No combat required here. The space exists for cultivation + reflection.
- Can be revisited freely before CD 100 without auto-triggering Tribulation.

### Beat 9 — Tribulation `PLANNED`

**Trigger:** Player is at the Tribulation Site AND Core Density ≥ 100.

- Tribulation mini-game fires — design in [`docs/cultivation/breakthrough-tribulation.md`](../cultivation/breakthrough-tribulation.md).
- **Success:** advancement to Copper stage. Foundation ends.
- **Failure consequence:** TBD → see [§3 Q-5](#q-5-tribulation-failure-consequence).

### Beat 10 — Zone 2 Onramp `PLANNED — sketch only`

**Trigger:** Successful Tribulation.

- Zone 2 becomes visible/accessible on the world/zone map.
- Short spirit-NPC moment acknowledging the disaster spreads and the player must follow.
- Full Zone 2 content lives in a future doc.

---

## Beat Index

| # | Beat | Key unlock / moment | Status |
|---|---|---|---|
| 1 | Awakening | Cycling + Adventure unlocked via NPC dialogue | `PLANNED` |
| 2 | First Steps Out | First adventure + Keystone #1 | `PLANNED` |
| 3a | Aura Well Discovery | Aura Well adventure encounter + Aura Well zone action (+1.5 Madra/tick passive, +1 Spirit per level) | `IMPLEMENTED` |
| 3b | Second Keystone + Merchant handoff | Keystone #2 at Core Density 10 + NPC map unlock (gates Merchant) | `IMPLEMENTED (partial — shop UI deferred)` |
| 4 | Refugee Camp | Merchant zone action + gold sink | `PLANNED` |
| 5 | Elite Gear Drop | First elite defeated, tier-bump gear | `PLANNED` |
| 6 | Third Keystone | Keystone #3 (burst/finisher) at Core Density ~30 | `PLANNED` |
| 7 | Tribulation Guardian | Boss defeated → Advancement Zone accessible | `PLANNED` |
| 8 | The Advancement Zone | Tribulation Site reachable; `q_breakthrough_seek` active | `PLANNED` |
| 9 | Tribulation | CD 100 + Tribulation mini-game → advancement to Copper | `PLANNED` |
| 10 | Zone 2 Onramp | Zone 2 accessible; story handoff | `PLANNED` |

---

## 2. Loop Economy Targets

Tuning dashboard. Every number here is either **source-backed** or a **starting value with a test plan**. No bare "feels right" numbers.

### 2.1 Cycling economy

| Metric | Early Zone 1 | Mid Zone 1 | Late Zone 1 | Fail signal / test |
|---|---|---|---|---|
| Madra gained per cycling session (avg play) | _TBD_ | _TBD_ | _TBD_ | Player cycles >2x before an adventure feels viable → value too low |
| Madra gained per cycling session (skilled play) | _TBD_ | _TBD_ | _TBD_ | Gap to avg <20% → skill expression too weak |
| Time per cycling session (seconds) | _TBD_ | _TBD_ | _TBD_ | >45s feels like a chore; <10s feels trivial |
| Core Density XP gained per session (Keystone #1 technique) | _TBD_ | _TBD_ | _TBD_ | Time-to-CD-10 governs Beat 3b pacing |
| Cycles to fill Madra (Beat 1 specifically) | **2-4** (starting value) | — | — | See [§3 Q-1](#q-1-cycles-to-fill-core-in-beat-1) |

### 2.2 Adventure economy

| Metric | Early Zone 1 | Mid Zone 1 | Late Zone 1 | Fail signal / test |
|---|---|---|---|---|
| Madra spent per adventure (avg) | _TBD_ | _TBD_ | _TBD_ | Player runs dry mid-run >30% → adventure too expensive |
| Encounters per adventure | _TBD_ | _TBD_ | _TBD_ | |
| Real-time minutes per adventure | _TBD_ | _TBD_ | _TBD_ | >10min of committed play per attempt = too long early |
| Cycles needed to fund one adventure | _TBD_ | _TBD_ | _TBD_ | >3 cycles per 1 adventure → loop imbalanced |
| Combats beaten before death (first adventure) | ~2-3 (starting value) | — | — | See [§3 Q-2](#q-2-combats-before-failure-in-early-adventures) |

### 2.3 Combat economy

| Metric | Starter enemy | Mid enemy | Elite (Beat 5) | Tribulation Guardian (Beat 7) | Fail signal / test |
|---|---|---|---|---|---|
| Enemy HP | _TBD_ | _TBD_ | _TBD_ | _TBD_ | |
| Enemy DPS (vs starter player) | _TBD_ | _TBD_ | _TBD_ | _TBD_ | |
| Expected player TTK | _TBD_ | _TBD_ | _TBD_ | _TBD_ | >20s vs trash = slog; <3s = no interaction |
| Expected player HP loss per fight | _TBD_ | _TBD_ | _TBD_ | _TBD_ | |
| Ability uses per fight | _TBD_ | _TBD_ | _TBD_ | _TBD_ | <1 means fight ends before decisions matter |

### 2.4 Progression pacing

Target real-time windows for reaching each beat, assuming committed play. Starting values; validate via playtest.

| Milestone | Target minute | Fail signal / test |
|---|---|---|
| Beat 1 complete (Adventure unlocked) | 0-3 | Player stuck cycling >5min = Beat 1 drags |
| Beat 2 complete (first adventure ends) | 3-6 | First adventure >10min = too long; <2min = too brief to teach |
| Beat 3a (Spirit Well discovered) | 6-15 | |
| Beat 3b (CD 10 → Keystone #2) | 6-15 | |
| Beat 4 (Refugee Camp / Merchant) | 10-18 | |
| Beat 5 (Elite defeated) | 15-25 | |
| Beat 6 (Keystone #3 at CD ~30) | 20-30 | |
| Beat 7 (Tribulation Guardian defeated) | 25-45 | |
| Beat 8 (Advancement Zone entered) | 30-50 | |
| Beat 9 (Tribulation success → Copper) | 35-60 | Whole Foundation >75min = pacing too slow |

### 2.5 Reward cadence

| Metric | Target | Fail signal / test |
|---|---|---|
| Adventures between meaningful drops | _TBD_ | >4 empty runs in a row kills motivation |
| Adventures between new unlock moments | _TBD_ | |
| Quests active simultaneously (typical) | _TBD_ | >3 concurrent = tracker overload early-game |
| Merchant gear price (Zone 1 starter) | ~3-5 adventures of gold (starting value) | See [§3 Q-8](#q-8-merchant-pricing-vs-adventure-gold-output) |

---

## 3. Open Tuning Questions

Running list of things we haven't decided. When a question resolves, move the answer into Section 2 or Section 1 and delete the entry here.

### Question Template

```
### Q-<number>: <short name>

ASSUMPTION: what we're currently assuming is true
IMPACT: why the design depends on this
IF WRONG: what breaks / what the failure mode looks like
VALIDATE: how we will check (playtest script / instrumentation / math)
STATUS: Open | Testing | Resolved → (pointer to where the answer lives)
```

### Q-1: Cycles to fill core in Beat 1

- **ASSUMPTION:** 2-4 cycling sessions to fill the Madra bar from 0 to max (100) for the first time.
- **IMPACT:** Too few → intro feels trivial. Too many → intro drags. Sets first impression of cycling.
- **IF WRONG:** player bounces off in first minute, OR races past intro without understanding cycling.
- **VALIDATE:** internal playtest. Count cycles-to-full for avg-play and skilled-play. Target: avg player fills in ~3 cycles.
- **STATUS:** Open

### Q-2: Combats-before-failure in early adventures

- **ASSUMPTION:** Player beats ~2-3 combats in their first few adventures before dying, giving them multiple combat exposures per run to learn mechanics.
- **IMPACT:** Pace of early loss/retry. Too few → frustrating. Too many → first-adventure success rate too high, breaks the "failure is normal" conceit.
- **IF WRONG:** player wins first adventure accidentally (missing the intended flee → improve → retry loop) OR dies in first combat and never sees the full run shape.
- **VALIDATE:** first-adventure playtest; record combats-beaten-before-death across ≥5 runs.
- **STATUS:** Open

### Q-3: Starter combat numbers (enemy HP, player DPS, TTK)

- **ASSUMPTION:** Starter enemy is beatable in 3-5 ability uses by a player with the bare-hands starter ability. Median TTK ~5-10s.
- **IMPACT:** Combat rhythm. Too fast → no strategic space. Too slow → grindy.
- **IF WRONG:** first combat feels either auto-win or unreachable.
- **VALIDATE:** test starter combat in isolation; aim for median TTK 7s, player-loss-rate 30-50% (to justify "return stronger").
- **STATUS:** Open

### Q-4: Cycle-to-adventure ratio across Foundation

- **ASSUMPTION:** Post-Beat 2, a full Madra bar funds one adventure; one adventure's return motivates the next cycle session. Target ratio ~1:1.
- **IMPACT:** If cycles-per-adventure drifts to 3+, loop feels choreographed around cycling and time is wasted.
- **IF WRONG:** player idles at full Madra frequently (too much cycling) or runs dry mid-adventure constantly (too little).
- **VALIDATE:** instrument average cycles-per-adventure across a full playthrough; target 0.8-1.2 for mid-Foundation.
- **STATUS:** Open

### Q-5: Tribulation failure consequence

- **ASSUMPTION:** Undecided. Options:
  - (a) Full death penalty — respawn at Zone 1 start; keep unlocks and gear.
  - (b) Soft retry — stay at CD 100; retry with no cost.
  - (c) Partial penalty — drop to CD ~90, must re-earn the last stretch.
- **IMPACT:** Defines the weight of the Tribulation moment. Soft retry (b) risks trivializing the climax. Full penalty (a) may punish players past their patience.
- **IF WRONG:** climax feels weightless, OR players quit after first failure.
- **VALIDATE:** pick a default (lean: (c)), playtest, observe retry feel.
- **STATUS:** Open

### Q-6: Core Density thresholds for path points in Foundation

- **ASSUMPTION:** Beat 3b awards at CD 10. Beat 6 at CD ~30. CD 100 is Tribulation. That leaves CD 40, 50, 60, 70, 80, 90 as "silent" point-earning moments — path points awarded without a named beat.
- **IMPACT:** Player keeps earning path points through mid-late Foundation. Is that a pacing problem (points pile up with nothing to spend) or a feature (player has tree flexibility)?
- **IF WRONG:** path tree runs out of meaningful nodes before CD 100, OR bottlenecks with unspent points.
- **VALIDATE:** design the path tree with ≥10 meaningful node slots reachable across Foundation; check beat density against total point-earning rate (CD 10/20/30/…/100 = ~10 points + freebie = 11 total).
- **STATUS:** Open

### Q-7: Time-to-beat targets

- **ASSUMPTION:** Foundation fits in 30-60 min committed play per the per-beat windows in [§2.4](#24-progression-pacing).
- **IMPACT:** If the curve is off, middle beats (4-6) feel padded or compressed.
- **IF WRONG:** late beats feel rushed OR early beats run over-long.
- **VALIDATE:** timestamp playtests at each beat entry; compare to targets.
- **STATUS:** Open

### Q-8: Merchant pricing vs adventure gold output

- **ASSUMPTION:** One piece of merchant gear costs ~3-5 adventures' worth of gold. Keeps merchant a goal, not an immediate purchase.
- **IMPACT:** Pricing governs whether merchant feels meaningful.
- **IF WRONG:** gear unaffordable (dead system) OR trivially bought on first visit (no choice).
- **VALIDATE:** set starting prices; playtest adventure-to-purchase count.
- **STATUS:** Open

### Q-9: Basic Training cost curve

- **ASSUMPTION:** Exponential — first Spirit point takes ~1 minute of passive time at the Spirit Well, second ~5min, third ~10min, fourth ~20min, etc.
- **IMPACT:** Sets how often the player returns to a training site vs. adventures/cycles. Too cheap → dominates other actions. Too expensive → ignored.
- **IF WRONG:** training either trivializes combat early (points pile up) or never matters (too slow to progress).
- **VALIDATE:** set starting curve, observe player attribute total at Beats 5 / 7 / 9; compare to expected gear + keystone contributions.
- **STATUS:** Open

---

## Change Log

- *2026-04-17* — Initial scaffold created; brainstorm session filled in the 10-beat Foundation spine end-to-end, added framing notes (tile-always-exists / no-retreat / quests-for-ambiguity / NPC placeholders), and seeded 9 open tuning questions in Section 3.
- *2026-04-20* — Beat 3a (Aura Well) promoted `PLANNED → IMPLEMENTED`. Renamed Spirit Well → Aura Well throughout (training action, trickle/award effects). Reframed discovery as an adventure-encounter Mark choice rather than a generic tile interaction. Updated Keystone framing note — all three Foundation keystones live on the Pure Madra tree (the "first node of each path" phrasing was incorrect). Expanded Beat 3b to document the NPC → map → Merchant handoff that gates Beat 4.
- *2026-04-21* — Beat 3b implementation landed (map item + refugee camp encounter + Merchant zone-action stub). Merchant shop UI still deferred. Implemented `UnlockConditionData.ITEM_OWNED` and added per-encounter `unlock_conditions` filtering (using `Dictionary[UnlockConditionData, bool]` to match the Beat 3a encounter-choice pattern).
