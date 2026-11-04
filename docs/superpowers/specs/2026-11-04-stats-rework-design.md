# Stats rework, pass 1: design

Draft for Lionel's review, 2026-11-04. Each decision and who made it is recorded in [2026-11-04-stats-rework-decisions.md](2026-11-04-stats-rework-decisions.md). In this document, **(Claude's call)** marks a choice Lionel hasn't confirmed. Everything else is Lionel's answer or follows directly from one.

## Why

Three things are wrong with stats and resources today:

- **Stats barely matter.** There are eight, all starting at 10. Control does nothing, Willpower does nothing in play (it only feeds a damage type no technique deals), and Agility is a small damage term. The only way to raise a stat in play is the Aura Well training action (+1 Spirit per training level). The merchant sells gear whose stats do nothing (the Leeching Ring's Control, the Cultivator's Cowl's Willpower).
- **There are two Madras.** The overworld pool is capped by Core Density. A run gets its own pool, sized by the Foundation stat and drained one way out of the overworld pool. Lionel's brother called this "the first and most confusing issue with the game right now". It also hides a lock-out: starting a run needs half of Foundation × 10, while Foundation's overworld cap is 100 + 5 × Core Density level. Today's content can't reach it, but training the Madra stat by cycling would.
- **Core Density comes only from cycling's timed presses.** Growing means cycling. Adventures pay gold and gear, but nothing that raises your core or your stats.

The new loop: **training at home grows your stats and refills your pools; fighting deepens your core, which pays path points and opens the breakthrough; the breakthrough raises the stats' cap.** Each activity gets one job:

| Activity | Refills | Grows |
|---|---|---|
| Cycling | Madra | Spirit, plus at most one Spiritual minor stat, chosen by the technique |
| Body refining (pass 2) | Health | Strength, plus at most one Physical minor stat, chosen by the drill |
| Adventures | | Core Density (path points, the breakthrough), loot and gear |

## The passes

- **Pass 1, this design:** the six stats and how they grow, one Madra pool, Core Density from fights, and the screens for all of it.
- **Pass 2, sketched at the end:** body refining and persistent Health.
- **Pass 2 or 3:** the Aura Well's role.
- **Separate projects:** the cycling rework (combination mini-games, one per stat), Core Density's look (a ball with 9 or 10 stars instead of 0–100), the body refining rework beyond its first drill, the quest reshuffle, and elixirs.

## Goals

1. Six stats, each with a job the player can feel in a fight.
2. Stats grow only by training, with XP, up to a hard cap per cultivation stage. The one exception is the Aura Well, which keeps its +1 Spirit per training level until pass 2 or 3.
3. One Madra number everywhere.
4. Core Density comes from fights, and cycling pays stat XP instead.
5. The player can always see what a stat does now, what its next level gives, and what trains it. In pass 1 the Physical stats say that nothing trains them yet.
6. Existing saves carry over **(Claude's call)**.

## Non-goals for pass 1

- Body refining and persistent Health (pass 2).
- New cycling mini-games or techniques (the cycling rework).
- Unattended Auto training. It comes with the cycling rework or pass 2, and its rate is settled then.
- Core Density's star look, the quest reshuffle, elixirs, changes to the Aura Well.
- Fights paying stat XP, Core Density raising the stat cap, and XP banked while capped. Lionel set each aside for later. Offline progress is also out **(Claude's call)**.
- New maps or enemies **(Claude's call)**.

## Anti-goals

Any of these makes pass 1 a failure even if it works:

- A stat that does nothing, or whose effect the player can't find.
- Two different Madra numbers anywhere on screen.
- Training that is idle from the start. The Aura Well's idle training stays as it is until pass 2 or 3, by Lionel's choice.
- A first sword that does nothing, or gear that fades as stats climb.
- A player locked out of adventures. (The breakthrough can't be reached until pass 2 lands, by Lionel's choice, so pass 1 doesn't go to players on its own.)
- Text cut off anywhere (style guide rule 14).

## The six stats

| Side | Stat | What it does |
|---|---|---|
| Physical | **Strength** (main) | Physical technique damage. In pass 2, also Health per body refining rep. |
| Physical | **Body** | Max Health. |
| Physical | **Agility** | Max Stamina, Stamina regen, and a chance to dodge. |
| Spiritual | **Spirit** (main) | Spirit technique damage, and Madra per cycle. |
| Spiritual | **Mind** | Max Madra. |
| Spiritual | **Control** | Cheaper techniques (Madra cost) and shorter cooldowns. |

- **Main** means every training activity on that side trains it: every cycling technique trains Spirit, and every body refining drill trains Strength. The technique or drill decides which minor stat also grows, if any. The screens never print the word "minor" **(Claude's call)**.
- **Names:** the sides are Physical and Spiritual. Mind replaces the Foundation stat, so Foundation names only the stage. Resilience and Willpower are removed.
- **Defence moves to gear.** Armor cuts physical damage and Ward cuts Spirit damage (magic resist shows as "Ward", **Claude's call**). Today Resilience cuts physical damage and the target's own Spirit cuts Spirit damage, so Spirit stops defending and Ward takes that job **(Claude's call)**.
- **Technique damage scales from its side's main stat only:** Basic Strike from Strength, Empty Palm and Power Font from Spirit, and the same for enemy techniques **(Claude's call)**. Today Basic Strike and Empty Palm also scale a little with Agility, and Power Font with Foundation.
- **Dodge** rises with Agility on a curve that flattens toward a hard ceiling **(Claude's call)**. It works against any incoming hit and shows "Dodged". Only the player dodges in pass 1, so the player's own hits never miss for a reason they can't see **(Claude's call)**. Enemy Stamina is never spent today, so enemy Agility does nothing in a fight for now.
- **Control's** two cuts each follow a curve that flattens toward a ceiling **(Claude's call)**.
- **Spirit's Madra per cycle:** each cycle draws more Madra as Spirit grows.

## Levels, XP and the cap

- Every stat is a whole-number level with an XP bar. A new character starts at Lv 1 in every stat. The formulas are rebased so a new character keeps today's numbers: 100 Health, 100 Madra, 50 Stamina, and a Basic Strike of about 25 before defence **(Claude's call)**.
- XP per action stays constant, and each level costs more than the last, rising faster than XP can keep up (Lionel's rule, from a comment on the brother's doc). A technique that pays more is simply a better technique, so the mock-ups' per-technique ranges (Full, Waning, Spent) are dropped.
- Each cultivation stage has one hard cap for all six stats, and the breakthrough raises it. **XP earned at the cap is lost.** A capped stat shows as capped, and training it still refills.
- **Tuning target:** an average player reaches the Spirit cap at about the same time Core Density reaches 100, so the stretch where training pays nothing stays short **(Claude's call)**. Foundation's documented target is 30–60 minutes (`FOUNDATION_PLAYTHROUGH.md`); the retune has to create that length, up to about 90 minutes with training **(Claude's call)**.
- Levels carry across stages **(Claude's call)**.

## Where stat XP comes from in pass 1

**Cycling** is the only active source. Until the cycling rework designs the real techniques, today's techniques pay like this **(Claude's call)**:
- Following the ball pays Madra, as today, plus Spirit XP for the share of the cycle you followed. Spirit XP is paid for following, not for Madra drawn, so Spirit's own Madra-per-cycle bonus doesn't speed up its training.
- Each timed press pays the technique's minor stat, by tier (PERFECT, GOOD, OK). Smooth Flow trains Control and Torrential Flow trains Mind. They stand in for Lionel's "two main cycling techniques", one giving Spirit and Control and one giving Spirit and the second Spiritual stat. The Foundational Technique has no presses, so it trains Spirit only.
- XP flows even when the Madra pool is full. A full pool doesn't stop training; the stage cap is the limit.
- **Close a hole first:** cycling decides "following" by distance alone, so a cursor resting on the path keeps drawing Madra each time the ball passes. With Auto on, nobody has to play. Following has to mean following the ball.

**The Aura Well** training action is unchanged: +1.5 Madra a second and +1 Spirit per training level. In the new model that reward is +1 Spirit level, and it can't pass the cap; at the cap it is lost, like XP **(Claude's call)**. Two of Lionel's rules meet here, the hard cap and "don't change the Aura Well", and this keeps both as far as they can go together. The Well can still carry Spirit toward the cap with no one playing.

**The Physical stats have no source in pass 1,** because body refining moved to pass 2. They stay at their starting level, and gear raises them. That's no worse than today, where Spirit is the only stat that grows, but it does mean the breakthrough waits for pass 2 (see Core Density).

**Fights pay no stat XP** (Lionel: "Yes, I'm gonna do that later"). Stats are fixed during a run.

**Auto** keeps working as it does today: it chains cycles, and nothing is earned without following and pressing. Unattended Auto, unlocked by a perfect cycle or set (an idea from the brother's doc that Lionel said was planned), comes with the cycling rework or pass 2. Its rate is settled then: Lionel's earlier answer reads two ways, one flat rate for refilling and XP alike (0.2× or 0.4×, leaning 0.4×), or refills at full speed with XP at the reduced rate.

## Gear

- **Armor** cuts physical damage and **Ward** cuts Spirit damage, with today's shape of formula, damage × 100 / (100 + armor) **(Claude's call)**. MIXED damage uses the average of the two, and TRUE ignores both. Gear is the only source.
- **Gear raises stats by a percentage with a floor,** for example +10% Strength, at least +1. The floor is never spelled out: item cards and stat breakdowns show the percent and what it gives right now, "+10% Strength · +1 now" **(Claude's call, following Lionel's lean that the floor shouldn't be explicit)**.
- The cap limits training, not gear, so gear can lift a stat past the cap **(Claude's call)**.
- **Today's Spirit Valley gear converts:** every stat bonus becomes a percent of the same stat (Strength, Agility, Body, Spirit, Control); the Leeching Ring's Foundation becomes Mind; the Reinforced Robes' Resilience becomes armor; the Cultivator's Cowl's Willpower becomes Ward. The Ring's Control now does something. `docs/inventory/ITEMS.md` generates the gear files, so the new stat words go there.
- **Enemies:** each family gets authored armor and Ward, for example armored Dreadbeasts and warded Spirits **(Claude's call)**. Enemy damage is retuned for the cuts every fighter loses: about 9% on physical damage (Resilience 10), and the Spirit-based cut on Spirit damage, about 9% for the player against Madra Lash and about 20% for the Coalescing Spirit against the player's Spirit techniques.

## One Madra pool

- One saved Madra pool serves both the overworld and adventures, and Mind sets its maximum (plus modifiers). Core Density stops setting a Madra cap **(Claude's call, following from one pool sized by Mind)**.
- A run spends straight from that pool, and whatever is left when the run ends is simply still there. Rest tiles and consumables refill the same pool, so Madra restored during a run comes home **(Claude's call)**.
- Starting a run still needs half of max Madra, now measured against one number **(Claude's call)**. That ends the lock-out, because the threshold and the cap come from the same stat.
- At home only cycling and the Aura Well refill it.
- Every Madra readout shows the same pool: the zone cabinet's orb (current and max), the adventure card (the pool against the start threshold), the adventure vitals plate, the end card's Madra line, the Goals board's "Awaken Your Core" figure, and a new Madra line in the Character book.
- **The first quest:** `q_fill_core`'s first step needs the pool to reach 100, so a new character's max Madra must be at least 100.
- **Path perks written for two pools stay inert, as every number perk is today** **(Claude's call)**. Madra Reclamation (refunds unspent run Madra) has nothing left to do and gets repointed when the perks are wired. Expanded Core (+25 Madra capacity) would raise max Madra.
- **Health doesn't change in pass 1.** It still refills at every run start (Lionel, R2).

## Core Density from fights

- Defeating an enemy pays Core Density XP by tier: regular, then elite, then boss. It is paid at the kill and kept if the run is lost **(Claude's call)**.
- Cycling's timed presses stop paying Core Density and pay stat XP instead.
- Core Density keeps every other job: 0–100 per stage, a path point every 10 levels, the breakthrough at 100, and the 5-level penalty for a failed Tribulation. It loses only the Madra cap (see above).
- **Tuning target:** Core Density 0 to 100 in Foundation takes a set number of Shallow Woods runs, starting around 6 to 10, with no new maps. The curve is retuned to fit **(Claude's call)**.
- **The breakthrough** needs Core Density 100 and Strength and Spirit at the cap, in pass 1 too. Nothing trains Strength until pass 2, so in pass 1 the breakthrough can't be reached in normal play; dev tools and save presets set the stats to test it. The Tribulation card and the Goals board show every requirement.
- **The path tree doesn't change:** Pure Core Awakening still unlocks Empty Palm and Smooth Flow.
- A lost fight ends the run as today, and loot already won is kept **(Claude's call)**.
- **Story:** lines that become false get reworded, such as dialogue 3's "strengthen your core while cycling", and the "Harden Your Core" beat that assumes Smooth Flow is how you earn Core Density. The quest structure stays; the reshuffle is on Lionel's side burner **(Claude's call)**.
- **Elixirs (not built), a direction for the elixir session rather than a decision:** cycling elixirs could boost stat XP instead of Core Density **(Claude's call)**. Lionel once named elixirs the best way to boost Core Density without endless cycling, and with Core Density moving to fights, that role could move to fights too. Either way, [2026-11-03-elixirs-and-materials-notes.md](2026-11-03-elixirs-and-materials-notes.md) needs revisiting before elixirs are built.

## Screens

This section says what each screen must show. Layouts get mock-ups on a new canvas before anything is built, in the lacquer look of `docs/STYLE_GUIDE.md`, with no text cut off.

- **Character book.** The Physical and Spiritual sides, each stat with its level, XP bar and cap state. A stat's detail page shows what it does at this level and the next, where its value comes from (trained level plus gear), which techniques train it, and roughly how many cycles its next level takes **(Claude's call)**. The Physical stats say nothing trains them yet. An "In a fight" block totals Health, Madra, Stamina, dodge chance, the technique cost and cooldown cuts, armor and Ward.
- **Zone view.** The cabinet's Madra orb shows the one pool. The mock-ups settle whether the stats themselves also show on the zone view (the Cultivator Stats canvas grew the cabinet to hold them).
- **Cycling view.** The technique drawers say what each technique trains ("Spirit · Control"). XP pellets fly to the trained stat with floaters. A level-up gets a flash and a log line ("Spirit reached Lv 6"). A capped stat shows as capped, and its XP stops.
- **Adventure view.** The vitals plate shows the one Madra pool. Stats are fixed for the run. A kill shows the Core Density it paid, and the end card totals the Core Density gained and the Madra left.
- **Gear text** everywhere (inventory, item panels, merchant): "+10% Strength · +1 now", "Armor 6", "Ward 4".
- **Abilities book and technique tooltips.** The damage breakdown comes from the side's main stat.
- **Tribulation card and Goals board.** Every breakthrough requirement.
- **Dev panel and save presets.** Set any stat's level and XP. The presets at or past the breakthrough (such as `tribulation_ready` and `copper`) set the stats the breakthrough needs.

## Saves

All of this section is **Claude's call**.

- One version-2 migration keeps everything else: stage, Core Density, path points, items, quests and zone progress.
- Spirit earned at the Aura Well becomes the same number of Spirit levels above the start, up to the cap.
- Resilience and Willpower are dropped; only dev tools ever raised them.
- A save holds one Madra value, the overworld pool (a run's pool lives only in memory). The migration keeps it, clamped to the new max.
- Every stat is written out explicitly, because Godot's text saver skips values equal to the script default, and changed defaults would silently rewrite old saves.
- No itch build until pass 2 lands, because the breakthrough can't be reached before then. Lionel publishes by hand and can overrule this.

## Code shape

Lionel invited reworking the stats patterns. This is a guide, and the builder decides the details.

- **A combat stat block shared with enemies:** the six stats plus armor and Ward, as named fields with no positional constructor. Today `CharacterAttributesData` plays this role for the player and the enemies alike.
- **The player's training record, saved:** a level and XP per stat, and the current stage cap.
- **`StatModifierStack`** stays the way bonuses reach totals (base + flat, then × (1 + percent)). Gear moves to percent bonuses with a floor, either as a new modifier shape or as a rule inside the gear source.
- **Keys by stat name.** Gear `.tres` files store raw enum integers today, so dropping or reordering enum values silently remaps them. Enums only ever grow at the end.
- **Remove** the Resilience and Willpower code paths, the unused `willpower_scaling`, MIXED's Resilience/Willpower average, and Spirit's defence against Spirit damage.
- **Tests:** about 15 test files build `CharacterAttributesData` with eight positional arguments, and several assert eight attribute types. Rewrite them on the new shape, following `docs/testing/TESTING.md`.
- **Living docs** go in the PR's "Docs to update" list, not the PR itself (CLAUDE.md): `CHARACTER.md`, `COMBAT.md`, `ABILITIES_MATRIX.md`, `EQUIPMENT_DESIGN.md` (its "no parallel stat systems" principle changes), `INVENTORY.md`, `RESOURCES.md`, `EFFECTS.md`, `UNLOCKS.md`, `CULTIVATION.md`, `breakthrough-tribulation.md`, `CYCLING.md`, `ADVENTURING.md`, `ZONES.md`, `MAIN_VIEW.md`, `PATH_PROGRESSION.md`, `FOUNDATION_PLAYTHROUGH.md`, `PERSISTENCE.md`, `DEV_TOOLS.md`, `TESTING.md`, and `MADRA_UNIFICATION_DESIGN.md` (superseded). `ITEMS.md` is read by code, so it changes in the PR. The milestone docs are refreshed separately, as CLAUDE.md says.

## Left to the builder

- **Every number,** aiming at the targets above: XP per action, the level-cost curve, the Foundation cap, the formula coefficients, the dodge and Control curves and their ceilings, gear percents and floors, enemy armor and Ward, Core Density per kill and its retuned curve. The press XP of Smooth Flow (four zones) and Torrential Flow (one zone) needs rebalancing so that Control and Mind train at comparable paces.
- How "following the ball" is detected.
- The code structure, within the guide above.
- Exact placement of pellets, floaters and log lines, which the mock-ups settle.

## Pass 2 sketch

- **Body refining:** its own board, opened from a zone action as the cycling board is. Its first drill pays Strength XP, at most one minor stat's XP, and Health. Which drill comes first is the pass 2 design's choice; the Body Refining canvas's Stone Lifting (hold to lift, let go in the brass band) is a candidate **(Claude's call)**. Auto unlocks after a perfect set.
- **Persistent Health:** one saved pool, shown in the zone cabinet. It comes home from a run as it is, and only body refining refills it at home. In runs, rest tiles still heal; no consumable heals Health today, so a Health consumable would be new content. Stamina stays per run and refills at every start, and the adventure card warns below half Health **(Claude's call)**.
- **The breakthrough becomes reachable again,** because Strength can finally train to the cap. The Physical stats' XP bars and training lines appear.
- **The Aura Well's role** is settled in pass 2 or 3.
- **Known hazards to fix first:** the fight's Health handler stays connected after the first fight, so Health reaching 0 outside a fight would report a lost fight. `ChangeVitalsEffectData` writes to the in-memory pool. Health is never saved.
