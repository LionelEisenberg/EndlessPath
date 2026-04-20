# Breakthrough / Tribulation Design Document

## 1. Overview

When a player's Core Density reaches level 100, they become eligible to advance their cultivation stage. Rather than a passive stat check, the breakthrough is a gauntlet: the player must adventure to find a breakthrough site on the map, engage with a short narrative beat, and then survive a Tribulation -- an intense, stripped-down variant of the cycling mini-game where only mouse-tracking accuracy matters. For Foundation to Copper, the Tribulation is short (15-30 seconds), forgiving on failure, and rewards the player with access to two new game systems: Scripting and Elixir Making. The system is designed to scale in difficulty and stakes for future stage transitions without requiring redesign.

---

## 2. Player Experience Flow

### Phase A: Eligibility

1. Player reaches Core Density level 100 through cycling.
2. A UI hint appears in the cycling resource panel and/or zone view: *"Your core is full... seek a place of dense aura."*
3. The hint directs the player toward adventure mode. No other gates exist for Foundation to Copper.

### Phase B: Seeking the Breakthrough Site

4. When Core Density is 100, adventure maps in the player's current zone gain a **Breakthrough Encounter** -- a special tile placed on the map alongside the usual encounter distribution.
5. The breakthrough tile has a distinct visual overlay on the hex grid (new overlay source ID, unique color/icon -- e.g., a glowing golden/white tile distinct from boss, combat, treasure, etc.).
6. The player navigates the adventure map normally -- spending stamina, fighting enemies, etc. -- until they reach the breakthrough tile.
7. Reaching the tile opens the `EncounterInfoPanel` with the encounter name (e.g., "Place of Dense Aura") and a single choice: "Begin Tribulation".

### Phase C: Narrative Beat

8. Selecting "Begin Tribulation" triggers a short Dialogic timeline. For Foundation to Copper, this is 2-4 lines of internal monologue communicating:
   - The character senses the dense aura.
   - The character steels themselves -- the core must be refined, and failure means starting the journey over.
   - The Tribulation begins.
9. When the dialogue ends, the adventure view transitions to the Tribulation view.

### Phase D: Tribulation Mini-Game

10. The screen transitions to the Tribulation view: the cycling body diagram with the Madra Ball, but **no cycling UI** (no resource panel, no technique selector, no auto-cycle toggle, no start button).
11. A minimal Tribulation HUD appears:
    - **Accuracy Meter**: a bar or arc showing current running accuracy (0-100%).
    - **Time Remaining**: countdown timer.
    - **Threshold Line**: a visible mark on the accuracy meter showing the minimum accuracy required to pass.
12. The Tribulation starts immediately (no "Start" button). The Madra Ball begins moving along a path. The player must track it with their mouse cursor.
13. As the timer progresses, intensity effects escalate:
    - Gentle screen shake begins at ~50% time elapsed.
    - Aura particles intensify around the body diagram.
    - Vignette darkens at the edges of the screen.
    - The ball may slightly increase speed in the final seconds (scaling framework, not yet tuned).
14. The Tribulation ends when the timer reaches zero.

### Phase E: Resolution -- Success

15. If `mouse_tracking_accuracy >= accuracy_threshold`:
    - A success visual plays (flash of golden light, particles burst, screen shake resolves).
    - A short Dialogic timeline plays: 1-2 lines acknowledging the advancement (*"The core solidifies. Copper."*).
    - `CultivationManager` advances the stage from FOUNDATION to COPPER.
    - Scripting and Elixir Making become available (gated by `UnlockConditionData` conditions that evaluate on `advancement_stage_changed`).
    - Core Density resets to level 0 (new stage, new progression track).
    - The adventure ends successfully (equivalent to boss defeat -- `ActionManager.stop_action(true)`).

### Phase F: Resolution -- Failure

16. If `mouse_tracking_accuracy < accuracy_threshold`:
    - A failure visual plays (the glow fades, the character slumps).
    - A short Dialogic timeline plays: 1-2 lines (*"The aura dissipates. Not yet."*).
    - The character "passes out" -- the adventure ends via `ActionManager.stop_action(false)`.
    - **No penalties**: no Madra loss, no Core Density loss, no cooldown.
    - The player returns to the zone view and can start a new adventure to try again.

---

## 3. Tribulation Mini-Game Design

### Orb Movement

The Tribulation reuses the cycling `Path2D` + `PathFollow2D` + `MadraBall` system. The ball follows a path curve over a fixed duration, identical to how cycling works mechanically. The key differences:

- **No cycling zones.** No inflection points to click. Pure mouse tracking.
- **No Madra generation.** The cycle_completed signal is not connected to ResourceManager.
- **Dedicated path curve.** The Tribulation uses its own `Curve2D` resource, not the player's selected cycling technique. This curve should be moderately complex -- more turns and tighter bends than the Foundation Technique path, to make tracking non-trivial.

The ball moves from `progress_ratio = 0.0` to `1.0` over the Tribulation duration. The existing `_process(delta)` mouse-tracking logic in `CyclingTechnique` calculates `mouse_tracking_accuracy` identically.

### Accuracy Measurement

Accuracy is calculated the same way as cycling: `time_mouse_in_ball / elapsed_cycle_time`, producing a 0.0-1.0 ratio. This is checked at the end of the timer.

- **Starting value -- Accuracy threshold**: 0.70 (70%)
- **Test plan**: Playtest with 5+ attempts. If success rate on first attempt is above 80%, raise threshold by 0.05. If below 40%, lower by 0.05. Target: ~60% first-attempt success rate for a player who has been cycling regularly.

### Duration

- **Starting value -- Duration**: 20 seconds
- **Test plan**: Playtest at 15s, 20s, and 25s. The Tribulation should feel tense but not tedious. If players report anxiety fatigue (losing focus, feeling punished by length), shorten. If it feels trivially short, lengthen.

### Orb Speed

The orb speed is implicitly controlled by `cycle_duration` (shorter duration = faster ball for same path length). The Tribulation's dedicated `CyclingTechniqueData` resource controls this.

- **Starting value -- Tribulation cycle duration**: 20 seconds (same as the timer -- one full pass of the path equals one Tribulation).
- **Test plan**: If the path feels too slow/boring, shorten duration (faster ball). If tracking is frustratingly hard regardless of accuracy threshold, lengthen duration.

### Minimal HUD

The Tribulation HUD overlays the cycling body diagram and contains only:

| Element | Description | Position |
|---------|-------------|----------|
| Accuracy Meter | Horizontal bar, fills based on running `mouse_tracking_accuracy`. Color-coded: red below threshold, yellow near threshold, green above. | Top center |
| Threshold Marker | Vertical line or notch on the accuracy bar at the required accuracy value. | On accuracy meter |
| Time Remaining | Countdown text, large font. Pulses or changes color in final 5 seconds. | Top right |

No other UI elements. No technique name, no Madra display, no XP, no buttons. The player's entire focus is on the orb.

### Visual Effects (Intensity Escalation)

Effects are time-based, ramping linearly from the start to end of the Tribulation:

| Effect | Start | End | Notes |
|--------|-------|-----|-------|
| Screen shake | Intensity 0.0 at 0% time | Intensity 0.3 at 100% time | Starting value. Subtle, not nauseating. |
| Aura particles | Low emission rate, cool blue | High emission, bright gold/white | GPU particles on the body diagram. |
| Vignette | 0% opacity | 30% opacity, dark edges | Shader uniform or `ColorRect` with shader. |
| Ball speed | 1.0x | 1.0x (Foundation) | Future stages can ramp speed within a single Tribulation. |

---

## 4. State Machine

### States

```
IDLE -> DIALOGUE_PRE -> TRIBULATION_ACTIVE -> DIALOGUE_POST_SUCCESS
                                           -> DIALOGUE_POST_FAILURE -> IDLE
```

### State Details

**IDLE**
- Default state. The Tribulation system is not active.
- Entry: game start, or after post-Tribulation dialogue ends.

**DIALOGUE_PRE**
- Entry condition: Player selects the "Begin Tribulation" choice on a Breakthrough Encounter tile, AND Core Density level >= 100.
- Behavior: A Dialogic timeline plays. Movement is locked. Adventure map is still visible behind the dialogue.
- Exit: Dialogic `dialogue_ended` signal fires. Transitions to TRIBULATION_ACTIVE.
- Interruptibility: Not interruptible. The dialogue is short (2-4 lines) and has no branching.

**TRIBULATION_ACTIVE**
- Entry condition: Pre-dialogue completed.
- Behavior: The adventure view is hidden. The Tribulation view (stripped cycling view) is shown. Timer starts. Mouse tracking begins.
- Exit: Timer reaches zero. Evaluate `mouse_tracking_accuracy` against threshold.
  - If `accuracy >= threshold`: transition to DIALOGUE_POST_SUCCESS.
  - If `accuracy < threshold`: transition to DIALOGUE_POST_FAILURE.
- Interruptibility: **Not interruptible.** Escape does nothing. The player cannot quit mid-Tribulation. This is a deliberate design choice -- it creates tension and commitment, and the duration is short enough (15-30s) that forced completion is not punishing.

**DIALOGUE_POST_SUCCESS**
- Entry: Tribulation passed.
- Behavior: Success VFX play. Dialogic timeline plays. Then: stage advanced, systems unlocked, adventure ends.
- Exit: Dialogue ends. `ActionManager.stop_action(true)`. Return to zone view.

**DIALOGUE_POST_FAILURE**
- Entry: Tribulation failed.
- Behavior: Failure VFX play. Dialogic timeline plays. Then: adventure ends with failure.
- Exit: Dialogue ends. `ActionManager.stop_action(false)`. Return to zone view.

### Edge Cases

| Edge Case | Handling |
|-----------|----------|
| Player somehow loses Core Density before reaching breakthrough tile | The encounter choice should re-evaluate `core_density_level >= 100` when selected. If no longer eligible, show a message ("Your core is no longer ready") and do not enter the Tribulation. |
| Adventure timer expires while in Tribulation | The Tribulation is not subject to the adventure timer. When entering TRIBULATION_ACTIVE, pause or ignore the adventure timer. Resume/end on exit. |
| Player dies in combat before reaching breakthrough tile | Normal adventure failure. No special handling. |
| Save/load during Tribulation | The Tribulation is not saveable mid-attempt. If the game closes during a Tribulation, treat it as if the adventure was abandoned (no penalty). On reload, the player is back at the zone view. |
| Player already at Copper but Core Density is 100 again | This design only covers Foundation to Copper. Higher-stage breakthrough encounters should not appear until that system is designed. Gate by checking `current_advancement_stage == FOUNDATION`. |

---

## 5. Difficulty Scaling Framework

### Foundation to Copper (MVP, Fully Designed)

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Accuracy threshold | 70% (starting value) | Forgiving. Players have practiced mouse tracking in cycling. |
| Duration | 20s (starting value) | Short and intense. Respects player time. |
| Ball speed | Same as a standard cycling technique (~10s cycle on Foundation path length) | Familiar feel. |
| Orb movement | Single Path2D pass, moderately complex curve | No randomness, learnable. |
| Failure penalty | None. Adventure ends. | First breakthrough should feel achievable, not punishing. |
| Intensity effects | Mild screen shake, particle ramp, light vignette | Sets the mood without overwhelming. |

### Higher Stages (Framework Only -- Not Designed in Detail)

The following axes are available for scaling. Each higher stage can turn one or more of these dials:

| Scaling Axis | How It Scales | Example |
|--------------|---------------|---------|
| **Accuracy threshold** | Increase required accuracy | Copper to Iron: 80%. Iron to Jade: 88%. |
| **Duration** | Longer Tribulations | 30s, 45s, 60s. |
| **Ball speed** | Faster movement, or speed ramps within a single Tribulation | Ball accelerates over the duration. |
| **Path complexity** | More curves, tighter turns, direction reversals | Each stage has a unique, harder Curve2D. |
| **Failure penalty** | Escalating stakes | Core Density loss (e.g., -10 levels), Madra drain, cooldown timer before retry, consumed breakthrough items. |
| **Additional gates** | Item requirements, NPC quests | Jade breakthrough requires a Tribulation Elixir (crafted via Elixir Making). |
| **Intensity effects** | Stronger screen shake, screen flash, color desaturation | Higher stages feel more dangerous. |
| **Orb behavior** | Random deviations from path, size changes | Orb briefly shrinks, or jitters off-path. |

This framework means each new stage breakthrough can be designed as a self-contained `TribulationData` resource (a new resource class) without modifying the core Tribulation logic.

---

## 6. Adventure Integration

### Breakthrough Encounter Placement

The breakthrough encounter appears on adventure maps when the player is eligible. Two approaches, with the recommended one first:

**Recommended: Conditional Encounter Injection**

The `AdventureMapGenerator` checks `CultivationManager.get_core_density_level() >= 100` AND `CultivationManager.get_current_advancement_stage() == FOUNDATION` at map generation time. If eligible, it injects a Breakthrough Encounter onto one of the special tile slots (or adds an extra special tile). The breakthrough tile is placed at moderate distance from the origin -- not the closest tile, not the farthest.

This means the breakthrough site only appears when the player is ready. If they are not at Core Density 100, adventure maps generate normally.

**Alternative: Always Present, Gated by Choice Requirements**

The breakthrough encounter is always placed on maps but the "Begin Tribulation" choice has a requirement (`UnlockConditionData` checking Core Density >= 100). If not met, the choice is visible but grayed out. This is simpler but clutters maps with an unusable tile for most of the player's Foundation experience.

### Encounter & Choice Structure

A new `EncounterType` value is needed:

```
BREAKTHROUGH  # New value in AdventureEncounter.EncounterType enum
```

The encounter resource:
- `encounter_name`: "Place of Dense Aura"
- `description`: "The air here is thick with vital aura. Your core resonates -- this is the place."
- `encounter_type`: `BREAKTHROUGH`
- `choices`: A single choice of a new subclass.

A new `EncounterChoice` subclass is needed: `BreakthroughChoice`. This is analogous to how `CombatChoice` triggers combat and `DialogueChoice` triggers a timeline. `BreakthroughChoice` triggers the Tribulation flow.

Fields on `BreakthroughChoice`:
- `pre_dialogue_timeline`: String (Dialogic timeline name for the pre-Tribulation narrative)
- `success_dialogue_timeline`: String (post-success narrative)
- `failure_dialogue_timeline`: String (post-failure narrative)
- `tribulation_data`: Reference to a `TribulationData` resource (see below)

### TribulationData Resource

A new resource class holding the tuning parameters for a specific Tribulation:

| Field | Type | Description |
|-------|------|-------------|
| `tribulation_name` | `String` | e.g., "Foundation Tribulation" |
| `target_stage` | `CultivationManager.AdvancementStage` | The stage to advance TO on success |
| `path_curve` | `Curve2D` | The path the orb follows |
| `duration_seconds` | `float` | How long the Tribulation lasts |
| `accuracy_threshold` | `float` | 0.0-1.0, minimum accuracy to pass |
| `ball_radius_override` | `float` | Optional override for the MadraBall collision radius (-1 = use default) |
| `speed_ramp_curve` | `Curve` | Optional curve for speed changes over duration (null = constant speed) |

### AdventureTilemap Integration

`_on_choice_selected()` in `AdventureTilemap` needs a new branch:

```
elif choice is BreakthroughChoice:
    # Signal up to AdventureView to begin the Tribulation flow
```

`AdventureView` handles the transition similarly to how it handles combat: hide the tilemap view, show the Tribulation view, wait for completion, then process the result.

### Map Overlay

A new overlay source ID is needed for the highlight map, similar to the existing BOSS, COMBAT, REST, TREASURE overlays. The breakthrough tile should use a distinct, unmissable visual -- bright gold or white, possibly with a pulse animation like the existing `PulseNode` but with a unique color.

---

## 7. Unlock Results

When the player successfully completes the Foundation to Copper Tribulation:

### Immediate Effects

| Effect | Mechanism |
|--------|-----------|
| Advancement stage changes to COPPER | `CultivationManager` sets `live_save_data.current_advancement_stage = AdvancementStage.COPPER` and emits `advancement_stage_changed` |
| Core Density resets to level 0 | `live_save_data.core_density_level = 0`, `live_save_data.core_density_xp = 0` |
| Scripting and Elixir Making become available | `advancement_stage_changed` fires `UnlockManager._evaluate_all_conditions()`; `UnlockConditionData` entries gated on `CULTIVATION_STAGE >= COPPER` unlock and their UI/actions become visible |
| Copper AdvancementStageResource becomes active | New max Madra formula, new XP scaling, new Core Density progression curve |
| Adventure ends successfully | `ActionManager.stop_action(true)` |

### Downstream Effects (Triggered by Signals)

- `advancement_stage_changed` signal triggers `UnlockManager._evaluate_all_conditions()`, which may unlock additional conditions gated on stage.
- `condition_unlocked` signals from newly satisfied conditions drive UI updates — new tabs/buttons for Scripting and Elixir Making appear in the zone view or main navigation.
- The cycling resource panel updates to show the new stage name and next-stage info.
- Madra capacity increases per the Copper stage's `max_madra_base` and `max_madra_per_core_density_level`.

### Required Content

- A `CopperAdvancementStageResource` `.tres` file must be created with tuned values for the Copper stage (XP scaling, Madra caps, etc.).
- The Foundation stage's `next_stage` field must be populated with the Copper stage resource.
- The `advancement_stage_resources` array on `CultivationManager` must include the Copper stage resource.

---

## 8. Failure & Retry

### What Happens on Failure

1. The Tribulation timer expires with accuracy below threshold.
2. Failure VFX play (subtle -- screen dims, particles dissipate).
3. A short Dialogic timeline plays (1-2 lines).
4. The adventure ends: `ActionManager.stop_action(false)`.
5. The player returns to the zone view.

### What Does NOT Happen

- No Core Density loss.
- No Madra loss.
- No cooldown or lockout.
- No item consumption.
- The breakthrough encounter is not "used up" -- it will appear again on the next adventure.

### How the Player Retries

1. The player starts a new adventure from the zone view.
2. A new map generates. Since Core Density is still 100, the breakthrough encounter is injected again.
3. The player navigates to the breakthrough tile and attempts the Tribulation again.
4. The adventure itself (stamina cost, combat encounters on the way) is the natural friction preventing instant retry spam.

### Design Rationale

Foundation to Copper is the player's first breakthrough. Harsh penalties here risk losing players who are still learning the game. The adventure requirement provides enough friction (2-5 minutes of gameplay per attempt) without feeling punitive. The Tribulation's skill check means the player must actually engage with the mouse-tracking mechanic they have been practicing, not just accumulate a resource and click a button.

---

## 9. Five-Component Evaluation

### Clarity

**How well does the player understand what to do?**

- The UI hint ("Your core is full... seek a place of dense aura") communicates eligibility and direction.
- The breakthrough tile's distinct visual overlay on the adventure map signals "this is special, go here."
- The encounter description explicitly names what is happening.
- The pre-Tribulation dialogue sets expectations.
- The Tribulation HUD shows exactly two things: your accuracy and the time remaining, with a clear threshold marker.
- **Risk**: If the player has never paid attention to mouse tracking accuracy in cycling, the Tribulation's importance of that mechanic might feel like a surprise. The UI hint text should allude to it: "...seek a place of dense aura. Your focus must be absolute."

### Motivation

**Why does the player want to do this?**

- Narrative: the player has been building toward this since the start of the game. The cultivation fantasy is "I am becoming stronger."
- Mechanical: Copper unlocks two entire new game systems (Scripting, Elixir Making). This is the biggest reward event in the game so far.
- Emotional: the Tribulation is the first moment of real stakes -- the player's skill determines success, not just accumulated resources.
- **Risk**: If the player reaches Core Density 100 and does not realize they need to adventure, they may feel stuck. The UI hint mitigates this, but it needs to be prominent (not just a tooltip).

### Response

**How does the game react to the player's actions?**

- During the Tribulation: real-time accuracy meter provides continuous feedback. The player sees their accuracy rise and fall with their mouse tracking. Intensity effects (shake, particles, vignette) create escalating drama.
- On success: immediate, dramatic positive feedback (golden flash, particles, dialogue, stage advancement, system unlocks). The game state visibly changes.
- On failure: gentle negative feedback (fade, short dialogue). No punishment reinforces "try again" rather than "you lost something."
- **Risk**: The Tribulation is 20 seconds of a single mechanic with no variation. If the accuracy meter is the only feedback, it could feel flat. The intensity effects are critical to maintaining engagement.

### Satisfaction

**How rewarding does completion feel?**

- The Tribulation is the culmination of all Foundation-stage play. Success should feel earned and significant.
- Two new game systems unlocking at once is a massive "world opens up" moment.
- The dialogue framing ("Copper.") gives narrative weight.
- Core Density resetting to 0 communicates "new chapter" rather than "lost progress" because it is paired with a stage advancement and new capabilities.
- **Risk**: If the Tribulation is too easy (threshold too low, or players always pass on first try), it feels like a formality rather than an achievement. Tuning the accuracy threshold is essential.

### Fit

**How well does this integrate with the rest of the game?**

- The Tribulation bridges cycling and adventuring -- two systems that currently operate independently. Cycling builds Core Density, adventuring finds the breakthrough site, and the Tribulation reuses cycling's core mechanic in a new context.
- The encounter/choice system in adventures already supports heterogeneous choice types (CombatChoice, DialogueChoice). Adding BreakthroughChoice follows the established pattern.
- The stage advancement and unlock system already exist (CultivationManager, UnlockManager). This feature fills the empty `attempt_breakthrough()` stub.
- The data-driven design (TribulationData resource, BreakthroughChoice resource) follows the project's existing patterns.
- **Risk**: The Tribulation view needs to coexist with the adventure view's lifecycle (timer, combat state). The adventure timer must be paused/ignored during the Tribulation to avoid the adventure ending while the player is mid-attempt.

---

## 10. Implementation Notes

### Existing Code to Reuse

| Component | What to Reuse | Modifications Needed |
|-----------|---------------|---------------------|
| `CyclingTechnique` | Mouse tracking logic (`_process`), `MadraBall`, `Path2D`/`PathFollow2D`, `is_mouse_in_madra_ball()` | Need a mode or subclass that skips zone creation, skips Madra generation, and exposes accuracy for external consumption. |
| `CyclingTechnique.mouse_tracking_accuracy` | Direct reuse of the accuracy calculation | None -- the math is identical. |
| `AdventureEncounter` / `EncounterChoice` | Encounter/choice pattern | Add new `EncounterType.BREAKTHROUGH` enum value. Create `BreakthroughChoice` subclass. |
| `AdventureTilemap._on_choice_selected()` | Choice dispatch pattern | Add `elif choice is BreakthroughChoice` branch. |
| `AdventureView` | View transition pattern (tilemap <-> combat) | Add tribulation view transition (tilemap <-> tribulation), analogous to combat. |
| `CultivationManager` | `attempt_breakthrough()` stub, `advancement_stage_changed` signal | Fill in the stub with real logic. |
| `UnlockManager` / `UnlockConditionData` | Stage-gated conditions auto-evaluate on `advancement_stage_changed` | Author `CULTIVATION_STAGE >= COPPER` conditions and wire them to Scripting/Elixir Making unlocks. |
| `Dialogic` / `DialogueManager` | Timeline playback | Author new timelines for pre/post Tribulation. |
| `AdventureMapGenerator` | Tile placement logic | Add conditional breakthrough encounter injection. |

### What is New

| Component | Description |
|-----------|-------------|
| `TribulationData` resource class | Holds all tuning parameters for a Tribulation attempt. |
| `BreakthroughChoice` resource class | New `EncounterChoice` subclass that references `TribulationData` and dialogue timelines. |
| Tribulation View scene | A stripped-down variant of the cycling view: body diagram + ball + path, no cycling UI. Plus the Tribulation HUD (accuracy meter, timer). |
| Tribulation state management | Logic to orchestrate the IDLE -> DIALOGUE_PRE -> ACTIVE -> DIALOGUE_POST -> IDLE flow. Could live in AdventureView or a dedicated TribulationManager. |
| Breakthrough encounter `.tres` | The AdventureEncounter resource with a BreakthroughChoice. |
| Foundation Tribulation `.tres` | TribulationData resource with Foundation-to-Copper tuning values. |
| Copper AdvancementStageResource `.tres` | Stage resource for the Copper stage. |
| Dialogic timelines | Pre-tribulation, post-success, post-failure timelines. |
| Visual effects | Screen shake, particle emitter, vignette shader/overlay. |
| Breakthrough tile overlay | New hex tile overlay graphic for the adventure map. |
| UI hint system | Mechanism to show "Your core is full..." messaging when Core Density hits 100. |

### Rough Build Order

1. **Data layer**: `TribulationData` resource class, `BreakthroughChoice` resource class, `EncounterType.BREAKTHROUGH` enum value. Copper `AdvancementStageResource`.
2. **Tribulation view**: New scene reusing cycling body diagram and ball mechanics, stripped of cycling UI, with the Tribulation HUD (accuracy meter, timer).
3. **Tribulation logic**: State machine (pre-dialogue -> active -> post-dialogue), accuracy evaluation, success/failure branching, calls to `CultivationManager` and `UnlockManager`.
4. **Adventure integration**: `BreakthroughChoice` handling in `AdventureTilemap`, Tribulation view transition in `AdventureView`, breakthrough encounter injection in `AdventureMapGenerator`.
5. **Content**: Breakthrough encounter `.tres`, Foundation Tribulation `.tres`, Dialogic timelines, Copper stage `.tres` with `next_stage` linkage.
6. **Polish**: Visual effects (shake, particles, vignette), breakthrough tile overlay, UI hint for Core Density 100 eligibility.
7. **Tuning**: Playtest accuracy threshold, duration, path curve difficulty. Adjust per test plan.

---

## 11. Open Questions

| # | Question | Impact | Suggested Resolution |
|---|----------|--------|---------------------|
| 1 | **What is the max Core Density level for Foundation?** The current system has no hard cap on `core_density_level`. Is 100 a soft target or a hard cap? If soft, the player could overshoot to level 150 before attempting breakthrough. | Affects when the UI hint appears and whether there is a "wasted XP" problem. | Add a `max_core_density_level` field to `AdvancementStageResource`. At level 100, XP gain stops (or overflows into a small bonus). The UI hint triggers at exactly 100. |
| 2 | **Should the breakthrough encounter replace the boss tile or be an additional special tile?** | Map generation logic. If it replaces the boss, there is no boss fight on breakthrough runs. If additional, the map is slightly larger. | Make it an additional special tile, placed at moderate distance. The boss encounter still exists -- reaching the breakthrough site is the goal, but the player may fight the boss for loot along the way. |
| 3 | **Where does the Tribulation view live in the scene tree?** | Architectural. It could be a child of `AdventureView` (like `CombatView`), or a sibling managed by `MainView`. | Child of `AdventureView`, following the combat pattern. `AdventureView` already manages tilemap/combat transitions; adding a third view state (tribulation) is consistent. |
| 4 | **Should the Tribulation path curve be the same as the player's equipped cycling technique, or a fixed Tribulation-specific curve?** | Gameplay feel. Using the player's technique rewards familiarity. Using a fixed curve ensures consistent difficulty. | Fixed Tribulation-specific curve. The Tribulation is a standardized test, not a cycling session. Familiarity with cycling helps (same mechanic), but the specific path should be designed for the Tribulation's difficulty target. |
| 5 | **How prominent should the "Your core is full" UI hint be?** | Discoverability vs. intrusiveness. | First occurrence: a one-time popup or Dialogic monologue. Subsequent: a persistent icon or text on the zone view / cycling resource panel that the player can dismiss. |
| 6 | **Does the Tribulation need audio?** | Cycling currently has no audio (noted in CYCLING.md). Adding Tribulation audio without cycling audio may feel inconsistent. | Defer audio to a broader "cycling + Tribulation audio pass." The Tribulation can ship without audio if cycling also lacks it. If audio is added, prioritize: heartbeat SFX during Tribulation, success/failure stingers. |
| 7 | **What happens to overflow Core Density XP after stage advancement?** | If the player is at level 100 with residual XP, does it carry over to the Copper stage's level 0? | Reset to 0 XP, 0 level. The stage advancement is the reward. Carrying over XP would let players skip early Copper levels, which undermines the "new chapter" feeling. |
