# Stats rework: decisions

A running record of the design questions for the stats rework, kept so the answers don't live only in one Claude Code session. Started 2026-11-03. The design built from it is [2026-11-04-stats-rework-design.md](2026-11-04-stats-rework-design.md), and the implementation plan is [2026-11-04-stats-rework.md](../plans/2026-11-04-stats-rework.md).

The inputs were Lionel's brief, a Figma board with Lionel's brother, the brother's doc "Thoughts on Endless Path" (with Lionel's comments on it), and two mock-up canvases ("Cultivator Stats" and "Body Refining"). The canvases were built on the old eight stats, so their pieces are reused, not their numbers.

Two kinds of line, kept apart:
- **Lionel** marks Lionel's answers, paraphrased. Only quoted text is Lionel's own wording. R1 to R5 are the question rounds, and R6 is his feedback on the phase 1 mock-ups; Lionel's messages are voice-transcribed.
- **Claude's call** marks defaults Claude chose. Lionel hasn't confirmed them and can overrule any.

## Settled

| Decision | Choice | Source | Revisit when |
|---|---|---|---|
| Scope | Everything the rework touches, except elixirs. | Lionel (R5) | |
| Phases | Six phases, each one PR and one focused unit of change: 1 Stats, 2 One Madra pool, 3 Cycling, 4 Core Density, 5 Body refining and Health, 6 Quests and story. | Lionel (R5, approving Claude's list) | |
| Mock-ups | Each phase's screens get mock-ups, shown after the previous phase lands and approved before the phase is built. | Lionel (R5) | |
| `main` between phases | May be broken: "this is a big enough scope that things will be broken". | Lionel (R5) | |
| The six stats | Physical: Strength (main), Body, Agility. Spiritual: Spirit (main), Mind (was Foundation), Control. Resilience and Willpower are removed. | Lionel (brief, R1 Q6) | |
| What "main" means | Every cycling technique trains Spirit and refills Madra. Every body refining drill trains Strength and refills Health ("health to refine" in the voice note). The technique or drill you pick decides which minor stat also grows. | Lionel (brief) | |
| How stats grow | Only by training (cycling, body refining). XP per action stays constant, and level costs climb faster than it. Fights give no stat XP. | Lionel (comment on the brother's doc; brief; R1) | Fights: "Yes, I'm gonna do that later." |
| What caps stats | One hard cap per cultivation stage, raised only by the breakthrough. | Lionel (R1 Q1) | Test the alternative later: Core Density raising the cap every X levels. It's on hold because it is hard to show the player clearly. |
| Training at the cap | XP earned while a stat is at the cap is lost. | Lionel (R2 Q4) | "We can update that/iterate on that later." |
| What ties training to fighting | Fights fill Core Density. Core Density pays path points and opens the breakthrough at 100, and the breakthrough also needs Strength and Spirit at the stage cap. | Lionel (R1) | |
| The breakthrough before phase 5 | Strength and Spirit must be at the cap from phase 1 on. Nothing trains Strength until phase 5, so the breakthrough can't be reached in normal play until then. | Lionel (R4 Q1 b) | |
| Core Density | Earned from fights, not cycling. Otherwise it keeps its jobs: 0–100 per stage, a path point every 10 levels, the breakthrough at 100. | Lionel (brief, R1 Q1) | |
| Core Density's look | A main ball with 9 or 10 stars that fill, instead of 0–100. | Lionel (R1, R5) | Phase 4 mock-ups. |
| Path tree | Still paid by Core Density milestones (now from fights), and still gives passives and actives. | Lionel (R1) | |
| Health and Madra | One pool each, shared by the overworld and adventures, kept between runs. Only training refills them: cycling refills Madra, body refining refills Health. Until body refining exists, Health keeps refilling at every run start. | Lionel (brief, R1 Q2, R2 Q1 b) | |
| What each stat does | Strength: physical technique damage, plus Health per refining rep. Body: max Health. Agility: max Stamina, Stamina regen, and a chance to dodge. Spirit: Spirit technique damage, plus Madra per cycle. Mind: max Madra. Control: cheaper techniques and cooldown reduction. | Lionel (R1 Q5, R2 Q2) | |
| Gear | Armor (against physical damage) and magic resist (against Spirit damage) live on gear. Gear raises stats by a percentage with a floor (for example +10%, at least +1), so a sword neither feels weak early nor fades later. Lionel leaned toward not spelling the floor out. | Lionel (brief, R1 Q3, R2 Q3) | |
| Gear text | A stat line shows the item's percent and the stat, then what it gives right now in parentheses: "+50% Strength (+5)" ("instead of +X now, just do +50% and then between parentheses, the actual number"). Armor and Ward lines stay "Armor 6" and "Ward 4". The item description panel (the item tooltip) is Lionel's to rework later, so phase 1 leaves its code alone ("ignore updating item description panel because I'm going to update that anyways later on"). | Lionel (R6) | Lionel's rework of the item description panel. |
| Side names | Physical and Spiritual. | Lionel (R1 Q6) | |
| Stats on the zone view | Phase 1 shows the six stats on the cultivator cabinet, as two triangles side by side, Physical left and Spiritual right, each cell 80% of the canvas's first draw: "add stats to the zone view, make them 20% smaller and in side by side triangular positions". | Lionel (phase 1 canvas) | |
| The Character book's look | Pressed paper, the Inventory's look ("Pressed paper inventory look"). Its XP bars are pressed into the page with an ink fill: "Why not keep using the circles? but yes pressed is fine for now". | Lionel (phase 1 canvas) | The bars: Lionel asked why they aren't the cabinet's bead rings. |
| What trains a stat | The book doesn't say: no "What trains it" section and no list of trainers ("remove its too much logic nuke it entirely"). | Lionel (phase 1 canvas) | |
| Auto | Not in phase 1: Auto keeps chaining cycles while you play, and nothing is earned unattended. Unattended Auto comes with the cycling phase (and with body refining in phase 5). | Lionel (R4 Q2 a) | Its rate, in phase 3's mock-up step. Lionel's R1 answer reads two ways: "Only by training, but auto-refills at full speed" (refills at full speed, XP at the reduced rate), then "auto-runs at 0.2 for everything. Or at 0.4, maybe that makes most sense" (one flat rate). "After a perfect cycle or set" comes from the brother's doc, where Lionel replied "Yup this was planned". |
| The Aura Well | Unchanged until phase 3: its training action keeps its Madra trickle and its +1 Spirit per training level. Its new role is settled in phase 3. Lionel's words (read as "Aura Well" and "pass"): "don't change the order whatsoever. We can do that in a second or third class. It's really not first class." | Lionel (R3, answering R2 Q5 again; R5) | Phase 3 mock-ups. |

## Claude's calls

**Before body refining exists (phases 1–4)**
- Nothing trains the Physical stats, so they stay at their starting level. Gear still raises them.
- Dev tools and the save presets at or past the breakthrough set the stats the breakthrough needs, so it can be tested before phase 5.

**Stats**
- Every stat starts at Lv 1, with formulas rebased so a new character keeps today's numbers (100 Health, 100 Madra, 50 Stamina, a Basic Strike of about 25 before defence). Levels carry across stages.
- Technique damage scales from its side's main stat only.
- Dodge rises with Agility on a curve that flattens toward a hard ceiling, works against every hit, and shows "Dodged". Only the player dodges.
- Control's two cuts each flatten toward a ceiling.
- The screens never print "minor". The canvases' Full / Waning / Spent ranges go (this follows from Lionel's XP rule). From phase 3, when cycling pays stat XP, a stat's page says roughly how many cycles its next level takes.
- Tuning targets: the Spirit cap arrives at about the same time as Core Density 100; Foundation takes 30–60 minutes, up to about 90 with training (the documented target, which the retune has to create).

**The Aura Well, until phase 3**
- Its +1 Spirit becomes +1 Spirit level and respects the hard cap. Lionel's "don't change the Aura Well" and "hard cap" meet here.

**Defence and gear**
- Defence comes only from gear. Spirit stops reducing Spirit damage. Magic resist shows as "Ward". Armor and Ward keep today's formula shape, and MIXED damage uses their average.
- The gear floor is never spelled out: cards and breakdowns show "+10% Strength (+1)", in Lionel's format (R6). Until Lionel reworks the item description panel, it keeps its code and prints the same lines, read from the item, as they stand when the tooltip opens.
- Gear can lift a stat past the cap; the cap limits training.
- Each enemy family gets authored armor and Ward. Enemy damage is retuned for the physical and Spirit cuts every fighter loses.

**One Madra pool**
- Mind sets its maximum, and Core Density stops setting a Madra cap (following from one pool sized by Mind).
- Madra restored during a run (rest tiles, Scales) comes home with the rest of the pool.
- Starting a run still needs half of max Madra.
- Path number perks stay inert, as they all are today. Madra Reclamation gets repointed when the perks are wired.

**Phase 3 starting proposal**
- Smooth Flow becomes the Spirit and Control technique and Torrential Flow the Spirit and Mind one. Spirit XP is paid for following, not for Madra drawn. XP keeps flowing when the Madra pool is full. The Foundational Technique trains Spirit only.

**Core Density**
- Kills pay by enemy tier and are kept on a lost run. The Foundation curve is retuned so a full core takes a set number of Shallow Woods runs, with no new maps.
- A lost fight ends the run as today, and loot already won is kept.

**Phase 5 starting proposal**
- Drills from the Body Refining canvas (Stone Lifting, Horse Stance, Falling Leaf, Waterfall Tempering), remapped to Strength plus Body or Agility. Stamina stays per run, and the adventure card warns below half Health.

**Saves, release, scope edges**
- Saves carry over through one version-2 migration in phase 1. Aura Well Spirit becomes Spirit levels. Every stat is written out explicitly, because Godot's text saver skips values equal to the default. Phase 2 clamps the one saved Madra value to the new max.
- No itch build until phase 5 lands, because the breakthrough can't be reached before then.
- Offline progress and new zones, maps or enemy families are out.

**Code**
- One stat block shared with enemies, kept apart from the player's saved levels and XP. Gear keys its bonuses by stat name, and stored enums only ever grow at the end.

## Open

None for phases 1 and 2. What each later phase still has to settle is listed in the design under that phase, for its mock-up step.

## Out of scope

- Elixirs. The elixir notes ([2026-11-03-elixirs-and-materials-notes.md](2026-11-03-elixirs-and-materials-notes.md)) assume cycling pays Core Density, so they need revisiting before elixirs are built.
