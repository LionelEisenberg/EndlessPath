# Stats rework: design

Approved by Lionel on 2026-11-04, then widened the same day to the whole rework. Phases 1 and 2 are designed in full. Phases 3 to 6 list what is already decided and what their mock-up step must settle before they are built. Each decision and who made it is recorded in [2026-11-04-stats-rework-decisions.md](2026-11-04-stats-rework-decisions.md). In this document, **(Claude's call)** marks a choice Lionel hasn't confirmed. Everything else is Lionel's answer or follows directly from one. The implementation plan is [2026-11-04-stats-rework.md](../plans/2026-11-04-stats-rework.md).

## Why

Three things are wrong with stats and resources today:

- **Stats barely matter.** There are eight, all starting at 10. Control does nothing, Willpower does nothing in play (it only feeds a damage type no technique deals), and Agility is a small damage term. The only way to raise a stat in play is the Aura Well training action (+1 Spirit per training level). The merchant sells gear whose stats do nothing (the Leeching Ring's Control, the Cultivator's Cowl's Willpower).
- **There are two Madras.** The overworld pool is capped by Core Density. A run gets its own pool, sized by the Foundation stat and drained one way out of the overworld pool. Lionel's brother called this "the first and most confusing issue with the game right now". It also hides a lock-out: starting a run needs half of Foundation × 10, while Foundation's overworld cap is 100 + 5 × Core Density level. Today's content can't reach it, but training the Madra stat by cycling would.
- **Core Density comes only from cycling's timed presses.** Growing means cycling. Adventures pay gold and gear, but nothing that raises your core or your stats.

The new loop: **training at home grows your stats and refills your pools; fighting deepens your core, which pays path points and opens the breakthrough; the breakthrough raises the stats' cap.** Each activity gets one job:

| Activity | Refills | Grows |
|---|---|---|
| Cycling | Madra | Spirit, plus at most one Spiritual minor stat, chosen by the technique |
| Body refining | Health | Strength, plus at most one Physical minor stat, chosen by the drill |
| Adventures | | Core Density (path points, the breakthrough), loot and gear |

## Scope and phases

Everything this rework touches is in scope except **elixirs**. It lands in six phases. Each phase is one PR and one focused unit of change. `main` may be broken between phases. Each phase's screens get mock-ups on a new canvas, shown after the previous phase lands and approved before the phase is built.

| Phase | Subject | Summary |
|---|---|---|
| 1 | **Stats** | The six stats with levels, XP and the stage cap; what each does; armor and Ward; percent gear; enemy values; the save migration; dev tools; the stat screens. |
| 2 | **One Madra pool** | One saved pool for home and runs, sized by Mind; Core Density stops capping it; every Madra readout shows it. |
| 3 | **Cycling** | The cycling rework: Madra and stat XP from every technique, one mini-game per stat, real following, unattended Auto, no more Core Density from cycling, the Aura Well's new role. |
| 4 | **Core Density** | Earned from kills; a retuned curve; the star look wherever Core Density shows (the breakthrough's stat lines on the Tribulation card and Goals board come in phase 1). |
| 5 | **Body refining and Health** | One saved Health pool; the body refining board and drills; manuals from adventures; Auto after a perfect set. Strength can reach the cap, so the breakthrough opens. |
| 6 | **Quests and story** | The quest reshuffle around the new loop, the dialogue that changes, the dev story route and presets. |

What breaks between phases: stats have no source but the Aura Well until phase 3, nothing pays Core Density between phases 3 and 4, and the breakthrough can't be reached until phase 5. **No itch build until phase 5 lands** **(Claude's call; Lionel publishes by hand and can overrule it)**.

## Goals

1. Six stats, each with a job the player can feel in a fight.
2. Stats grow only by training, with XP, up to a hard cap per cultivation stage.
3. One Madra pool and one Health pool, shared by home and runs.
4. Core Density comes from fights; cycling and body refining pay stat XP and refill the pools.
5. The player can always see what a stat does now and what its next level gives.
6. Existing saves carry over **(Claude's call)**.

## Non-goals

- Elixirs (out of scope).
- Fights paying stat XP, Core Density raising the stat cap, and XP banked while capped. Lionel set each aside for later. Offline progress is also out **(Claude's call)**.
- New zones, maps or enemy families **(Claude's call)**.

## Anti-goals

Any of these makes the rework a failure even if it works:

- A stat that does nothing, or whose effect the player can't find.
- Two different Madra numbers, or two different Health numbers, anywhere on screen.
- Training that is idle from the start (Auto unlocks only after a perfect cycle or set).
- A first sword that does nothing, or gear that fades as stats climb.
- A player locked out of adventures once the rework is done, or with no way to reach the breakthrough once phase 5 lands.
- Text cut off anywhere (style guide rule 14).

## The six stats

| Side | Stat | What it does |
|---|---|---|
| Physical | **Strength** (main) | Physical technique damage, and Health per body refining rep (from phase 5). |
| Physical | **Body** | Max Health. |
| Physical | **Agility** | Max Stamina, Stamina regen, and a chance to dodge. |
| Spiritual | **Spirit** (main) | Spirit technique damage, and Madra per cycle (from phase 3). |
| Spiritual | **Mind** | Max Madra. |
| Spiritual | **Control** | Cheaper techniques (Madra cost) and shorter cooldowns. |

- **Main** means every training activity on that side trains it: every cycling technique trains Spirit, and every body refining drill trains Strength. The technique or drill decides which minor stat also grows, if any. The screens never print the word "minor" **(Claude's call)**.
- **Names:** the sides are Physical and Spiritual. Mind replaces the Foundation stat, so Foundation names only the stage. Resilience and Willpower are removed.
- **Defence moves to gear.** Armor cuts physical damage and Ward cuts Spirit damage (magic resist shows as "Ward", **Claude's call**). Today Resilience cuts physical damage and the target's own Spirit cuts Spirit damage, so Spirit stops defending and Ward takes that job **(Claude's call)**.
- **Technique damage scales from its side's main stat only:** Basic Strike from Strength, Empty Palm and Power Font from Spirit, and the same for enemy techniques **(Claude's call)**. Today Basic Strike and Empty Palm also scale a little with Agility, and Power Font with Foundation.
- **Dodge** rises with Agility on a curve that flattens toward a hard ceiling **(Claude's call)**. It works against any incoming hit and shows "Dodged". Only the player dodges, so the player's own hits never miss for a reason they can't see **(Claude's call)**. Enemy Stamina is never spent today, so enemy Agility does nothing in a fight for now.
- **Control's** two cuts each follow a curve that flattens toward a ceiling **(Claude's call)**.

## Levels, XP and the cap

- Every stat is a whole-number level with an XP bar. A new character starts at Lv 1 in every stat. The formulas are rebased so a new character keeps today's numbers: 100 Health, 100 Madra, 50 Stamina, and a Basic Strike of about 25 before defence **(Claude's call)**.
- XP per action stays constant, and each level costs more than the last, rising faster than XP can keep up (Lionel's rule, from a comment on the brother's doc). A technique that pays more is simply a better technique, so the mock-ups' per-technique ranges (Full, Waning, Spent) are dropped.
- Each cultivation stage has one hard cap for all six stats, and the breakthrough raises it. **XP earned at the cap is lost.** A capped stat shows as capped, and training it still refills.
- **Tuning target:** an average player reaches the Spirit cap at about the same time Core Density reaches 100, so the stretch where training pays nothing stays short **(Claude's call)**. Foundation's documented target is 30–60 minutes (`FOUNDATION_PLAYTHROUGH.md`); the retune has to create that length, up to about 90 minutes with training **(Claude's call)**.
- Levels carry across stages **(Claude's call)**.
- **Fights pay no stat XP** (Lionel: "Yes, I'm gonna do that later"). Stats are fixed during a run.

## Phase 1: Stats

Builds the six stats, their levels, XP and cap, everything they do in a fight, gear's new bonuses, and the screens that show them.

- **Sources in phase 1:** only the Aura Well and dev tools raise stats. The Aura Well training action keeps its +1.5 Madra a second and +1 Spirit per training level until phase 3. In the new model that reward is +1 Spirit level, and it can't pass the cap; at the cap it is lost, like XP **(Claude's call)**. Two of Lionel's rules meet here, the hard cap and "don't change the Aura Well", and this keeps both as far as they can go together.
- **The Physical stats** have no source until phase 5. They stay at their starting level, and gear raises them.
- **Gear:**
  - **Armor** cuts physical damage and **Ward** cuts Spirit damage, with today's shape of formula, damage × 100 / (100 + armor) **(Claude's call)**. MIXED damage uses the average of the two, and TRUE ignores both. Gear is the only source.
  - **Gear raises stats by a percentage with a floor,** for example +10% Strength, at least +1. The floor is never spelled out **(Claude's call, following Lionel's lean that the floor shouldn't be explicit)**: item cards and stat breakdowns show the percent, then what it gives right now in parentheses, "+10% Strength (+1)".
  - The cap limits training, not gear, so gear can lift a stat past the cap **(Claude's call)**.
  - **Today's Spirit Valley gear converts:** every stat bonus becomes a percent of the same stat (Strength, Agility, Body, Spirit, Control); the Leeching Ring's Foundation becomes Mind; the Reinforced Robes' Resilience becomes armor; the Cultivator's Cowl's Willpower becomes Ward. `docs/inventory/ITEMS.md` generates the gear files, so the new stat words go there.
- **Enemies:** each family gets authored armor and Ward, for example armored Dreadbeasts and warded Spirits **(Claude's call)**. Enemy damage is retuned for the cuts every fighter loses: about 9% on physical damage (Resilience 10), and the Spirit-based cut on Spirit damage, about 9% for the player against Madra Lash and about 20% for the Coalescing Spirit against the player's Spirit techniques.
- **The breakthrough** needs Core Density 100 and Strength and Spirit at the cap from phase 1 on (Lionel). Strength can't train until phase 5, so dev tools and the save presets at or past the breakthrough set the stats to test it.
- **Saves** (all **Claude's call**): one version-2 migration keeps stage, Core Density, path points, items, quests and zone progress. Spirit earned at the Aura Well becomes the same number of Spirit levels above the start, up to the cap. Resilience and Willpower are dropped; only dev tools ever raised them. Every stat is written out explicitly, because Godot's text saver skips values equal to the script default, and changed defaults would silently rewrite old saves.
- **Screens:**
  - **Character book.** Pressed paper, the Inventory's look (Lionel). The Physical and Spiritual sides, each stat with its level, XP bar and cap state. A stat's detail page shows what it does at this level and the next and where its value comes from (trained level plus gear); from phase 3 it also gives roughly how many cycles the next level takes **(Claude's call)**. It doesn't name what trains the stat (Lionel). An "In a fight" block totals Health, Madra, Stamina, dodge chance, the technique cost and cooldown cuts, armor and Ward.
  - **Zone view.** The cultivator cabinet shows the six stats as two triangles side by side, Physical left and Spiritual right, each with its level and a ring of XP beads, full at the cap (Lionel). The cabinet grows to hold them, and the Goals board hangs lower.
  - **Gear text** everywhere (inventory, item panels, merchant): "+10% Strength (+1)", "Armor 6", "Ward 4". Lionel reworks the item description panel (the item tooltip) later, so phase 1 leaves its code alone; it prints the same lines, read from the item **(Claude's call)**.
  - **Abilities book and technique tooltips:** the damage breakdown comes from the side's main stat.
  - **Tribulation card and Goals board:** every breakthrough requirement.
  - **Dev panel and save presets:** set any stat's level and XP; the presets at or past the breakthrough (such as `tribulation_ready` and `copper`) set the stats it needs.

## Phase 2: One Madra pool

- One saved Madra pool serves both the overworld and adventures, and Mind sets its maximum (plus modifiers). Core Density stops setting a Madra cap **(Claude's call, following from one pool sized by Mind)**.
- A run spends straight from that pool, and whatever is left when the run ends is simply still there. Rest tiles and consumables refill the same pool, so Madra restored during a run comes home **(Claude's call)**.
- Starting a run still needs half of max Madra, now measured against one number **(Claude's call)**. That ends the lock-out, because the threshold and the cap come from the same stat.
- At home only cycling and the Aura Well refill it.
- Every Madra readout shows the same pool: the zone cabinet's orb (current and max), the adventure card (the pool against the start threshold), the adventure vitals plate, the end card's Madra line, the Goals board's "Awaken Your Core" figure, and a new Madra line in the Character book.
- **The first quest:** `q_fill_core`'s first step needs the pool to reach 100, so a new character's max Madra must be at least 100.
- **Path perks written for two pools stay inert, as every number perk is today** **(Claude's call)**. Madra Reclamation (refunds unspent run Madra) has nothing left to do and gets repointed when the perks are wired. Expanded Core (+25 Madra capacity) would raise max Madra.
- **Saves:** a save holds one Madra value, the overworld pool (a run's pool lives only in memory). The migration keeps it, clamped to the new max **(Claude's call)**.
- **Health doesn't change until phase 5.** It still refills at every run start (Lionel).

## Phase 3: Cycling

**Decided:**
- Every cycling technique refills Madra and pays Spirit XP. Spirit also raises the Madra each cycle draws.
- Each technique trains at most one minor stat. Lionel's target: two main techniques, one giving Spirit and Control and one giving Spirit and Mind, which "we can combine", as the body refining drills on the canvas combine stats.
- Each stat gets its own mini-game inside cycling (the brother's idea, which Lionel "like[s] a lot"): following the ball trains Spirit, and each minor stat gets a mini-game of its own.
- "Following" has to mean following the ball. Today cycling decides it by distance alone, so a cursor resting on the path keeps drawing Madra each time the ball passes.
- Unattended Auto unlocks after a perfect cycle (an idea from the brother's doc that Lionel said was planned). Training is fully hands-on until then.
- Cycling stops paying Core Density.
- The Aura Well's role is settled here (Lionel: "a second or third pass").

**Claude's starting proposal for the mock-up step:** today's Smooth Flow becomes the Spirit and Control technique and Torrential Flow the Spirit and Mind one; Spirit XP is paid for the share of the cycle followed, not for Madra drawn; XP keeps flowing when the Madra pool is full; the Foundational Technique trains Spirit only.

**Settled with the phase 3 mock-ups:**
- Which mini-game trains Control and which trains Mind (today's timed presses are one candidate; the brother suggested timing for one stat and unbroken following for another).
- How techniques combine.
- Auto's rate. Lionel's answer reads two ways: one flat rate for refilling and XP alike (0.2× or 0.4×, leaning 0.4×), or refills at full speed with XP at the reduced rate.
- The Aura Well's new role.
- The technique roster, including whether the Foundational Technique stays.
- The Figma's cycling feel notes: the cycle speeding up and slowing down with how well you stay inside it, and Auto not keeping that speed curve.

## Phase 4: Core Density

**Decided:**
- Defeating an enemy pays Core Density XP by tier: regular, then elite, then boss. It is paid at the kill and kept if the run is lost **(Claude's call)**.
- Core Density keeps every other job: 0–100 per stage, a path point every 10 levels, the breakthrough at 100, and the 5-level penalty for a failed Tribulation. It loses only the Madra cap (phase 2).
- **Tuning target:** Core Density 0 to 100 in Foundation takes a set number of Shallow Woods runs, starting around 6 to 10, with no new maps. The curve is retuned to fit **(Claude's call)**.
- The breakthrough needs Core Density 100 and Strength and Spirit at the cap (set up in phase 1).
- The path tree doesn't change: path points still come from Core Density milestones and still buy passives and actives.
- A lost fight ends the run as today, and loot already won is kept **(Claude's call)**.
- **The look:** instead of 0–100, "a main ball that has like 9 stages or 9 stars or 10 stars", each filled star shown graphically (Lionel).

**Settled with the phase 4 mock-ups:** 9 or 10 stars; how much Core Density a star is worth and whether stars line up with the path-point milestones; where the ball and stars show (the cabinet's core orb and beads, the Goals board, the Tribulation card, the adventure end card); how a kill shows the Core Density it paid.

## Phase 5: Body refining and Health

**Decided:**
- One saved Health pool serves both the overworld and adventures. It comes home from a run as it is, and only body refining refills it at home. In runs, rest tiles still heal.
- Body refining is a board of its own, opened from a zone action as the cycling board is. Every drill refills Health and pays Strength XP, plus at most one Physical minor stat (Body or Agility). Strength also raises the Health each rep restores.
- Auto unlocks after a perfect set.
- Strength can reach the cap, so the breakthrough opens.
- Known hazards to fix first: the fight's Health handler stays connected after the first fight, so Health reaching 0 outside a fight would report a lost fight; `ChangeVitalsEffectData` writes to the in-memory pool; Health is never saved.

**Claude's starting proposal for the mock-up step**, from the Body Refining canvas (built on the old stats, so its numbers don't carry over): a board in the map gap with a chest of drills; drills such as Stone Lifting (hold to lift, let go in the brass band), Horse Stance (hold steady in a drifting band), Falling Leaf (click to catch) and Waterfall Tempering (press on the beat), remapped to Strength plus Body or Agility; manuals found on adventures; sets of reps with PERFECT, GOOD and OK; Auto at a flat rate after a perfect set. Stamina stays per run and refills at every start, and the adventure card warns below half Health.

**Settled with the phase 5 mock-ups:** the drill roster and which minor each trains; how manuals drop and how a drill is learned; combinations; Auto's rate, and whether an Auto drill can run beside Auto cycling (one wait between runs or two); what a lost run costs now that Health persists; whether any consumable heals Health (none does today).

## Phase 6: Quests and story

**Decided:** the quest structure is reworked around the new loop, the dialogue that becomes false is rewritten, and the dev story route and save presets follow. Elixir quests stay out with elixirs.

**Settled with the phase 6 mock-ups:** the new beat order. Today's beats teach the old loop: "Awaken Your Core" (fill Madra by cycling), "First Steps" (defeat an enemy, +1 path point) and "Harden Your Core" (Core Density 10 by cycling with Smooth Flow), plus dialogue lines such as "strengthen your core while cycling".

## Code shape

Lionel invited reworking the stats patterns. This is a guide, and the plan fixes the details.

- **A combat stat block shared with enemies:** the six stats plus armor and Ward, as named fields with no positional constructor. Today `CharacterAttributesData` plays this role for the player and the enemies alike.
- **The player's training record, saved:** a level and XP per stat, and the current stage cap.
- **`StatModifierStack`** stays the way bonuses reach totals (base + flat, then × (1 + percent)). Gear moves to percent bonuses with a floor.
- **Keys by stat name.** Gear `.tres` files store raw enum integers today, so dropping or reordering enum values silently remaps them. Enums only ever grow at the end.
- **Remove** the Resilience and Willpower code paths, the unused `willpower_scaling`, MIXED's Resilience/Willpower average, and Spirit's defence against Spirit damage.
- **Tests** follow `docs/testing/TESTING.md`. About 15 test files build `CharacterAttributesData` with eight positional arguments, and several assert eight attribute types.
- **Living docs** go in each PR's "Docs to update" list, not the PR itself (CLAUDE.md): `CHARACTER.md`, `COMBAT.md`, `ABILITIES_MATRIX.md`, `EQUIPMENT_DESIGN.md` (its "no parallel stat systems" principle changes), `INVENTORY.md`, `RESOURCES.md`, `EFFECTS.md`, `UNLOCKS.md`, `CULTIVATION.md`, `breakthrough-tribulation.md`, `CYCLING.md`, `ADVENTURING.md`, `ZONES.md`, `MAIN_VIEW.md`, `PATH_PROGRESSION.md`, `QUESTS.md`, `FOUNDATION_PLAYTHROUGH.md`, `PERSISTENCE.md`, `DEV_TOOLS.md`, `TESTING.md`, and `MADRA_UNIFICATION_DESIGN.md` (superseded). `ITEMS.md` is read by code, so it changes in the PR. The milestone docs are refreshed separately, as CLAUDE.md says.

## Left to the builder

- **Every number,** aiming at the targets above: XP per action, the level-cost curve, the Foundation cap, the formula coefficients, the dodge and Control curves and their ceilings, gear percents and floors, enemy armor and Ward, Core Density per kill and its retuned curve.
- The code structure, within the guide above and the plan.
- Exact placement of pellets, floaters and log lines, which the mock-ups settle.
