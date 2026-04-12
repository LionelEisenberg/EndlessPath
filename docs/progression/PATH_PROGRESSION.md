# Path Progression System

## Overview

Path Progression is the primary within-run character customization system. Players spend **Path Points** earned through Core Density leveling to unlock perks in a **Path Tree** tied to their chosen Madra Path. The tree shapes how cycling, combat, adventuring, and other systems feel throughout a run.

### Core Loop

1. Player cycles / adventures / plays -> earns Core Density XP
2. Core Density levels up -> earns Path Points
3. Player spends Path Points in their Path Tree -> unlocks perks
4. Perks change how cycling, combat, adventuring, and other systems feel
5. Player advances to next cultivation stage -> deeper tree tiers unlock
6. At run's end -> ascend, tree resets, ascension perks earned
7. New run -> choose path (possibly a new one), build tree differently

### Relationship to Ascension

- Path Tree **resets completely** each ascension
- **Ascension Perks** (separate system) carry over and can modify the path experience:
  - Double path points in Foundation stage
  - Unlock second core at Jade (ascension-gated, not available on early runs)
  - Unlock new paths beyond Pure Madra
- First run is **always Pure Madra** -- additional paths unlock through ascension milestones

### New Singleton: PathManager

`PathManager` owns:
- Current path selection
- Tree state (which nodes are purchased)
- Point balance
- Methods for spending points and querying unlocked perks

Other managers (CombatAbilityManager, CyclingTechnique, etc.) query PathManager to know what's available.

**Note:** The existing hardcoded ability equipping in `CharacterManager.get_equipped_abilities()` stays as-is for now. How abilities get *equipped* is a future ability rework concern. Path Progression unlocks abilities; it does not change how they are equipped.

---

## Path Selection

- **Paths = Madra types.** Each path is defined by the type of Madra the player uses. The Madra type is the root, and everything flows from it: cycling technique, combat abilities, encounter matchups.
- **Locked per run.** The player chooses a path at the start of each ascension. This choice is permanent for that run.
- **Unique perks per path.** Perks are not shared between paths. Each path's tree is entirely its own. This makes path choice implicitly harder and each run feel distinct.
- **First run = Pure Madra.** No choice on the first playthrough. Subsequent paths unlock through ascension milestones.
- **Second core (ascension-gated).** An ascension perk allows the player to unlock a second core in a future run once they reach a specific cultivation stage (e.g., Jade). This grants access to a second path tree to spend progression points on. This is a deep-investment reward, not available on early ascensions.

---

## Tree Structure

### Freeform Node Graph

The tree is a **freeform node graph** -- not rigid rows or layers. Nodes are connected by prerequisite links and the player traces paths through the web organically, gravitating toward clusters that interest them. Think Skyrim constellations, not WoW talent rows.

### Tier Gates

The only hard structure is **tier gates** at cultivation stage boundaries. These are visual dividers (dotted lines) that require the player to have reached the corresponding advancement stage before accessing nodes beyond the gate.

| Tier | Required Stage |
|------|---------------|
| Tier 1 | Foundation |
| Tier 2 | Copper |
| Tier 3 | Iron |
| Tier 4 | Jade |

Within a tier section, nodes are arranged organically with ~3-4 depth worth of prerequisite chains, but not in strict layers.

### Visibility

The **entire tree is visible from the start of a run**. Players can see what's behind future tier gates, giving them motivation targets during the cultivation grind. They just can't purchase nodes beyond their current tier.

---

## Branching Model: Budget Branching

All nodes are accessible -- there are no hard locks or exclusive forks. Point scarcity forces trade-offs naturally.

### How It Works

- Deeper nodes require prerequisite nodes (must own node A to buy node B)
- The player doesn't have enough points to buy everything
- Build identity emerges from **where the player chose to invest**, not where they were locked out
- Two players on the same path can have meaningfully different builds based on which routes they traced through the graph

### Scarcity Targets

| Run Type | Tree Completion |
|----------|----------------|
| First run (no ascension perks) | ~60-70% |
| Mid ascensions (some bonus point perks) | ~80% |
| Late ascensions (full bonus point perks) | ~90-100% |

First-run players face real trade-offs. Veteran players on later ascensions earn the power fantasy of filling out a tree they previously had to agonize over.

---

## Node Types

| Type | Frequency | Purchase | Role |
|------|-----------|----------|------|
| **Keystone** | ~20% | Once | Game-changers: new abilities, new cycling techniques, fundamental mechanic shifts |
| **Major** | ~30% | Once | Significant upgrades, meaningful new options |
| **Minor** | ~25% | Once | Stat bonuses, small QoL, connective tissue |
| **Repeatable** | ~25% | Multiple (capped) | Stackable bonuses, point sinks |

### Keystones

- Tier gates **always** have a keystone as the entry node
- Keystones can **also** appear mid-tier -- not exclusively at gates
- Mid-tier keystones create discovery moments as the player traces deeper into the graph

### Repeatable Nodes

- Can be purchased multiple times, each purchase stacking the effect
- Each has a defined cap (e.g., "Unspent Adventure Madra Return" at 10/20/30/40/50%)
- Serve as natural point sinks that make Budget Branching work -- a player who loves cycling can keep pumping points into repeatable cycling nodes rather than being forced to diversify

### Opening Keystone Template

**Every path's opening keystone unlocks three things:**

1. Establishes the Madra type
2. Unlocks a path-specific combat ability
3. Unlocks a path-specific cycling technique

This template applies to all paths (Pure, Blackflame, Earth, and any future paths).

---

## Point Economy

### Primary Source: Core Density Leveling (v1)

| Stage | Points per Award | Award Frequency | Points Available per Stage | Tier Perk Costs |
|-------|-----------------|-----------------|---------------------------|----------------|
| Foundation | 1 | Every 10 Core Density levels | ~10 | 1 per node |
| Copper | 2 | Every 10 Core Density levels | ~20 | 2-3 per node |
| Iron | 3 | Every 10 Core Density levels | ~30 | 3-4 per node |
| Jade | 4 | Every 10 Core Density levels | ~40 | 4-6 per node |

**Total first-run budget:** ~100 points
**Estimated total tree cost:** ~140-160 points
**Result:** ~60-70% completion on first run

### Scaling Principle

Higher stages yield more points per award, but higher-tier perks cost proportionally more. This means a Copper-stage player can either:
- Buy remaining cheap Foundation perks quickly, **or**
- Invest in fewer but more impactful Copper perks

No stage transition feels like a nerf.

### Planned Future Point Sources (Not in v1)

These are documented for future implementation but are **not** part of the initial system:

- **Adventure first-clears** -- bonus path points as a first-time reward
- **Hidden encounters / quest rewards** -- one-time path point awards
- **First level in a new advancement stage** -- multiplied reward (e.g., 3x normal)
- **Ascension perks** -- "Gain 2 path points instead of 1 in Foundation stage"

---

## Pacing & Progression Timing

### Stage Duration (First Ascension)

| Stage Transition | Estimated Play Time | Cumulative |
|-----------------|-------------------|------------|
| Foundation -> Copper | ~35 min | 35 min |
| Copper -> Iron | ~70 min | ~1.75 hrs |
| Iron -> Jade | ~140 min | ~4 hrs |
| Jade -> Silver | ~280 min | ~8.5 hrs |

Each stage approximately doubles in duration from the previous. Total first ascension: ~8-10 hours.

### Path Point Rhythm

In Foundation (~35 min, 10 points), the player earns roughly one path point every 3-4 minutes. Choices are frequent and low-stakes -- the player is learning the system.

By Jade (~280 min, 40 points), each point represents ~7 minutes of play. Choices carry more weight as the player is deeply invested in their build.

### Subsequent Ascensions

Later ascensions should compress stage durations (roughly 50-70% of first-run times). Exact tuning is an ascension system design concern, not a path progression concern.

---

## Pure Madra Path -- Tier 1 (Foundation) Full Design

### Identity

- Jack of all trades, master of disruption
- Combat: neutralizing enemy Madra techniques, stripping buffs, clean efficient strikes
- Cycling: smooth, balanced, steady generation -- the baseline other paths contrast against
- Weakness: no elemental specialization, lower raw damage than specialized paths

### Opening Keystone: "Pure Core Awakening"

Unlocks three things per the template:
1. **Establishes Pure Madra** type
2. **Empty Palm** combat ability -- cancels the enemy's current ability cast and silences their Madra techniques for X seconds
3. **Smooth Flow** cycling technique -- the current default cycling technique becomes the Pure path's technique. Smooth, forgiving, balanced. Biased toward Core Density XP generation.

### Mid-tier Keystone: "Madra Strike"

- New combat ability: Madra-infused strike that costs Madra but deals significantly more damage than basic strike
- Teaches the player that Madra is a combat resource, not just a cycling/progression currency

### Mid-tier Major: "Torrent Flow" (Second Cycling Technique)

- Faster, more demanding cycling technique
- Biased toward higher Madra generation at the expense of Core Density XP
- Creates a strategic decision loop: "Do I need levels or resources right now?"

### Nodes (Freeform Graph, Loose Thematic Groupings)

**Cycling-adjacent:**
- Madra ball slowdown near cycling zones (accuracy forgiveness)
- Increased Madra generation per cycle
- Max Madra capacity increase (flat bonus)

**Combat-adjacent:**
- Empty Palm upgrades -- longer silence duration, reduced cooldown, lower Madra cost
- Madra Strike upgrades -- damage scaling, reduced stamina cost
- Stamina recovery rate increase (helps player sustain longer in adventures)

**Progression-adjacent:**
- Core Density XP bonus (repeatable)
- Bonus Madra on Core Density level-up
- Unspent adventure Madra partial return (repeatable -- 10/20/30/40/50%)

### Tier 1 Budget

- ~10 points available, ~14-16 total node cost
- Player completes ~60-70% of Tier 1
- Enough to go deep in one area and dip into another, or spread moderately
- Intentionally safe -- no trap choices, clear value on every node

---

## Pure Madra Path -- Tiers 2-4 (Placeholder)

Tiers 2-4 are not yet designed. They will be designed when:
- Tier 1 is implemented and playtested
- The combat system has been further developed
- Crafting systems (Scripting, Elixir Making, Soulsmithing) are closer to implementation
- Each tier should deepen the Pure Madra identity while broadening available options

Each tier follows the same structural principles:
- Keystone at tier gate entry
- Additional keystones and majors mid-tier
- Freeform node graph with prerequisite chains
- Budget Branching with appropriate point costs for the tier

---

## Path Sketches (Validation Only)

These are high-level sketches to validate that the system generalizes beyond Pure Madra. They are **not** full designs and will be expanded when those paths are ready for implementation.

### Blackflame

Aggressive, destructive Madra type. Burns hot and costs more. Opening keystone unlocks a **Blackflame Striker** ability (high damage, burns the user's own health as a cost) and an aggressive cycling technique that's faster but punishes missed accuracy harder. The tree leans into a glass cannon identity -- nodes increase damage output but perks are needed to manage the self-burn. Adventures feel like a race against your own resource drain. The player who picks Blackflame wants to hit hard and end fights fast.

### Earth

Slow, heavy Madra type. Immovable and inevitable. Opening keystone unlocks a **Stone Pillar** ability (high damage, long cast time -- rewards reading enemy patterns and timing) and a **Bedrock** cycling technique that's slower than Smooth Flow but each cycle generates significantly more Madra and Core Density. The tree leans into patience as a strategy -- nodes reduce cast time slightly, increase damage the longer you wait between abilities, boost defense and damage reduction. Adventures feel deliberate: fewer but heavier hits, more resilience to sustain through long encounters. The player who picks Earth wants to plan two moves ahead and watch enemies break against them.

### Validation Matrix

| | Pure | Blackflame | Earth |
|---|---|---|---|
| **Combat feel** | Disrupt and control | Burst and burn | Time and crush |
| **Cycling feel** | Smooth, balanced | Fast, punishing | Slow, rewarding per cycle |
| **Risk profile** | Low | High (self-damage) | Low (but slow = exposure) |
| **Adventure pace** | Moderate | Fast, risky | Slow, safe |
| **Player type** | Generalist / explorer | Aggressive / speedrunner | Strategic / patient |

All three paths:
- Fit the opening keystone template (Madra type + ability + cycling technique)
- Have distinct identity without gating any game system
- Support Budget Branching (multiple viable build directions within each)
- Make cycling feel different

---

## Open Design Questions

These are decisions deferred for future design work:

1. **Ascension Perks system** -- How are ascension perks earned? What's the full list? How do they interact with path progression?
2. **Second core mechanics** -- When exactly does this unlock? How does spending points across two trees work? Can both trees be from the same path?
3. **Tier 2-4 perk design** -- Dependent on combat rework, crafting systems, and Tier 1 playtesting
4. **Additional paths beyond three** -- How many total? What Madra types? Unlocked at which ascension milestones?
5. **Ability equip rework** -- How path-unlocked abilities integrate with a future ability loadout system
6. **Exact node counts per tier** -- Requires balancing against point budget and desired completion percentages
7. **Repeatable node caps** -- Exact cap values per node need balance testing
8. **Point award frequency tuning** -- Every 10 levels is the starting value; may need adjustment based on how long levels take in practice
