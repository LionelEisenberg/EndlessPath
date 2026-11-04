# Stats rework: decisions

A running record of the design questions for the stats rework, kept so the answers don't live only in one Claude Code session. Started 2026-11-03. The design built from it is [2026-11-04-stats-rework-design.md](2026-11-04-stats-rework-design.md).

The inputs were Lionel's brief, a Figma board with Lionel's brother, the brother's doc "Thoughts on Endless Path" (with Lionel's comments on it), and two mock-up canvases ("Cultivator Stats" and "Body Refining"). The canvases were built on the old eight stats, so their pieces are reused, not their numbers.

Two kinds of line, kept apart:
- **Lionel** marks Lionel's answers, paraphrased. Only quoted text is Lionel's own wording. R1 to R4 are the question rounds; Lionel's messages are voice-transcribed.
- **Claude's call** marks defaults Claude chose. Lionel hasn't confirmed them and can overrule any.

## Settled

| Decision | Choice | Source | Revisit when |
|---|---|---|---|
| The six stats | Physical: Strength (main), Body, Agility. Spiritual: Spirit (main), Mind (was Foundation), Control. Resilience and Willpower are removed. | Lionel (brief, R1 Q6) | |
| What "main" means | Every cycling technique trains Spirit and refills Madra. Every body refining drill trains Strength and refills Health ("health to refine" in the voice note). The technique or drill you pick decides which minor stat also grows. | Lionel (brief) | |
| How stats grow | Only by training (cycling, body refining). XP per action stays constant, and level costs climb faster than it. Fights give no stat XP. | Lionel (comment on the brother's doc; brief; R1) | Fights: "Yes, I'm gonna do that later." |
| What caps stats | One hard cap per cultivation stage, raised only by the breakthrough. | Lionel (R1 Q1) | Test the alternative later: Core Density raising the cap every X levels. It's on hold because it is hard to show the player clearly. |
| Training at the cap | XP earned while a stat is at the cap is lost. | Lionel (R2 Q4) | "We can update that/iterate on that later." |
| What ties training to fighting | Fights fill Core Density. Core Density pays path points and opens the breakthrough at 100, and the breakthrough also needs Strength and Spirit at the stage cap. | Lionel (R1) | |
| The breakthrough in pass 1 | Strength and Spirit must still be at the cap. Nothing trains Strength until pass 2, so the breakthrough can't be reached in normal play until pass 2 lands. | Lionel (R4 Q1 b) | |
| Core Density | Earned from fights, not cycling. Otherwise it keeps its jobs: 0–100 per stage, a path point every 10 levels, the breakthrough at 100. | Lionel (brief, R1 Q1) | Its look, a main ball with 9 or 10 stars that fill: a later session. |
| Path tree | Still paid by Core Density milestones (now from fights), and still gives passives and actives. | Lionel (R1) | |
| Health and Madra | One pool each, shared by the overworld and adventures, kept between runs. Only training refills them: cycling refills Madra, body refining refills Health. Until body refining exists, Health keeps refilling at every run start. | Lionel (brief, R1 Q2, R2 Q1 b) | Health lands in pass 2. |
| What each stat does | Strength: physical technique damage, plus Health per refining rep. Body: max Health. Agility: max Stamina, Stamina regen, and a chance to dodge. Spirit: Spirit technique damage, plus Madra per cycle. Mind: max Madra. Control: cheaper techniques and cooldown reduction. | Lionel (R1 Q5, R2 Q2) | |
| Gear | Armor (against physical damage) and magic resist (against Spirit damage) live on gear. Gear raises stats by a percentage with a floor (for example +10%, at least +1), so a sword neither feels weak early nor fades later. Lionel leaned toward not spelling the floor out. | Lionel (brief, R1 Q3, R2 Q3) | |
| Side names | Physical and Spiritual. | Lionel (R1 Q6) | |
| Pass 1 | The stats, one Madra pool, and the Core Density swap. The other systems they touch get a pass too. | Lionel (R1 Q4, R2 Q1) | |
| Pass 2 | Body refining and persistent Health, together. | Lionel (R2 Q1) | |
| Auto | Not in pass 1: Auto keeps chaining cycles while you play, and nothing is earned unattended. Unattended Auto comes with the cycling rework or pass 2. | Lionel (R4 Q2 a) | Its rate, when it's built. Lionel's R1 answer reads two ways: "Only by training, but auto-refills at full speed" (refills at full speed, XP at the reduced rate), then "auto-runs at 0.2 for everything. Or at 0.4, maybe that makes most sense" (one flat rate). "After a perfect cycle or set" comes from the brother's doc, where Lionel replied "Yup this was planned". |
| The Aura Well | Unchanged in pass 1: its training action keeps its Madra trickle and its +1 Spirit per training level. Lionel's words (read as "Aura Well" and "pass"): "don't change the order whatsoever. We can do that in a second or third class. It's really not first class." | Lionel (R3, answering R2 Q5 again) | Pass 2 or 3. |

## Claude's calls

**Pass 1, before body refining exists**
- Nothing trains the Physical stats yet, so they stay at their starting level. Gear still raises them. Their pages say nothing trains them yet.
- Dev tools and the save presets at or past the breakthrough set the stats the breakthrough needs, so it can be tested before pass 2.

**Stats**
- Every stat starts at Lv 1, with formulas rebased so a new character keeps today's numbers (100 Health, 100 Madra, 50 Stamina, a Basic Strike of about 25 before defence). Levels carry across stages.
- Technique damage scales from its side's main stat only.
- Dodge rises with Agility on a curve that flattens toward a hard ceiling, works against every hit, and shows "Dodged". Only the player dodges in pass 1.
- Control's two cuts each flatten toward a ceiling.
- The screens never print "minor". The canvases' Full / Waning / Spent ranges go (this follows from Lionel's XP rule). A stat's page says roughly how many cycles its next level takes.
- Tuning targets: the Spirit cap arrives at about the same time as Core Density 100; Foundation takes 30–60 minutes, up to about 90 with training (the documented target, which the retune has to create).

**Cycling, until the cycling rework**
- Following the ball pays Madra and Spirit XP, and each timed press pays the technique's minor stat. Smooth Flow trains Control and Torrential Flow trains Mind, standing in for Lionel's "two main cycling techniques". The Foundational Technique trains Spirit only.
- XP keeps flowing when the Madra pool is full.
- Close the hole where a cursor resting on the path keeps drawing Madra on Auto.

**The Aura Well**
- Its +1 Spirit becomes +1 Spirit level and respects the hard cap. Lionel's "don't change the Aura Well" and "hard cap" meet here. The Well can still carry Spirit toward the cap with no one playing.

**Defence and gear**
- Defence comes only from gear. Spirit stops reducing Spirit damage. Magic resist shows as "Ward". Armor and Ward keep today's formula shape, and MIXED damage uses their average.
- The gear floor is never spelled out: cards and breakdowns show "+10% Strength · +1 now".
- Gear can lift a stat past the cap; the cap limits training.
- Each enemy family gets authored armor and Ward. Enemy damage is retuned for the physical and Spirit cuts every fighter loses.

**One Madra pool**
- Mind sets its maximum, and Core Density stops setting a Madra cap (following from one pool sized by Mind).
- Madra restored during a run (rest tiles, Scales) comes home with the rest of the pool.
- Starting a run still needs half of max Madra.
- Path number perks stay inert, as they all are today. Madra Reclamation gets repointed when the perks are wired.

**Core Density**
- Kills pay by enemy tier and are kept on a lost run. The Foundation curve is retuned so a full core takes a set number of Shallow Woods runs, with no new maps.
- A lost fight ends the run as today, and loot already won is kept.
- Cycling elixirs could boost stat XP instead of Core Density, as a direction for the elixir session, not a decision. Lionel once named elixirs the best way to boost Core Density, and that role could move to fights.

**Story, saves, release**
- Quests stay as they are, and only lines that become false get reworded.
- Saves carry over through one version-2 migration. Aura Well Spirit becomes Spirit levels. The one saved Madra value is clamped to the new max. Every stat is written out explicitly, because Godot's text saver skips values equal to the default.
- No itch build until pass 2 lands, because the breakthrough can't be reached before then.
- Offline progress and new maps or enemies are out of pass 1.

**Code**
- One stat block shared with enemies, kept apart from the player's saved levels and XP. Gear keys its bonuses by stat name, and stored enums only ever grow at the end.

**Pass 2 sketch**
- The first body refining drill is the pass 2 design's choice; Stone Lifting from the canvas is a candidate. Stamina stays per run, and the adventure card warns below half Health.

## Open

None for pass 1. Lionel answered the last two in R4 ("1b2a").

## Later sessions

- Pass 2: body refining and persistent Health.
- The Aura Well's role, which clashes with "training starts active" and "only training refills" (pass 2 or 3).
- Core Density's look (stars).
- The cycling rework: combination mini-games, one per stat.
- The body refining rework beyond the first drill: more drills, manuals found on adventures, combinations.
- Screen layouts, shown as mock-ups on a new canvas.
- The quest reshuffle.
