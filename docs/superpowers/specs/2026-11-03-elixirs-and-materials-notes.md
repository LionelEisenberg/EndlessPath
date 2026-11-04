# Elixirs and materials: working notes

Draft, 2026-11-03. **Nothing here is decided.**

Lionel asked for three things: a spec for elixir making and material gathering, leaving out the brewing mini-game; a UI design spec; and "a one pager that I can share with my brother that I'm working on this so that we can build that out". None of them is started. First, from 1 to 3 November, Claude asked design questions Q1 to Q37, ran the two deep dives Lionel asked for (Q31, what a dose does; Q32, how recipes unlock), and built the mockup Lionel asked to see for Q33. Then Lionel stopped the questions: "don't accept these as truth". The question rounds live in that Claude Code session, not in the repo. These notes keep three things apart:

- **What Lionel said.** Most answers were one letter picking one of Claude's options. Those lines paraphrase the option and show the pick, as in (Q4: a). In that section, only quoted text is Lionel's own wording.
- **What Claude assumed:** readings and defaults Lionel never confirmed.
- **What Claude proposed:** designs from the deep dives and the mockup, not agreed.

The open questions at the end continue the numbering from Q38, so a reply can't be mistaken for an old answer.

## Why

Adventuring doesn't feed Core Density today: "there's incentive, but there's no real use to go adventuring … it's really not linked with core density whatsoever, and that's a problem" (Q28, agreeing with Claude's reading that cycling sends the player nowhere). Elixirs are meant to be the link: a run brings home materials, materials brew elixirs, and elixirs make cycling pay more Core Density XP. Lionel's first message called cycling "a little too boring, a little too easy". Asked whether that meant pace, skill or sameness (Q12), Lionel answered "wrong you misunderstood completely", and Q28's reading replaced it.

## What Lionel said

**Materials**
- Three sources: drops from monsters on adventures, materials foraged at home, and special tiles on adventure maps. And "every elixir is going to require 2 materials".
- A recipe is one adventure material plus one foraged material from the same zone (Q7: a).
- Monster drops are per enemy family: regular enemies about half the time, elites 2 guaranteed, the boss a bigger bundle (Q4: a).
- "For question 34, it's definitely A": one enemy drop brews one dose, so winning more fights brings more elixirs.
- The special tile "should just be a special interest tile like another that now lives on the adventure" (Q5).
- Foraging yields: "for now not touch we'll see later" (Q6).

**Spirit Valley's elixirs**
- Three: two cycling elixirs, one per enemy family (Spirits and Dreadbeasts), and an adventure elixir made from the special tile's material (Q1: b). Lionel's words on the ingredients were unclear: "the spirit drop and the dew drop tier that are the ones that we can get from the foraging".
- The cycling elixirs go to the two techniques unlocked on the path tree, Smooth Flow and Torrential Flow: "So that should be the two unlockable ones" (Q30).
- For Torrential Flow, Lionel picked the option that took it off the path tree and reworked it, then added "but left on the tree. still doable without elixir" (Q15). Whether the rework stands is open (Q42).
- The adventure elixir is a draught drunk before a run that lasts the whole run, with hotbar elixirs in a later zone (Q23: e). In Spirit Valley it adds damage: "for zone 1? a" (Q24).

**Cycling with a dose**
- "hard without elixir (can still run technique but slower and less xp) faster with elixir" (Q14).
- A dose pays more Core Density XP, about 2 to 3 times the base rate at the same skill (Q16: a), and is harder, with skill scaling the reward (Q17: b). Q17's examples, a bonus for a PERFECT streak and a small XP cost for a stray press, were Claude's.
- How long a dose lasts: "# of cycles?" (Q18).
- Auto keeps chaining dosed cycles but stops, spending nothing, after a cycle nobody played (Q19: a).
- Keep today's base cycling pace (Q20: c).
- On what a dose does (Q33), Lionel asked to see option (a) first: "a new markup where you mean with A for question 33". The Ladder and Tear canvas below is that mockup, and Lionel hasn't given a verdict.

**Unlocking and brewing**
- Move Elixir Making from Copper to Foundation: "And yes move it to foundation" (Q2).
- How it opens: first the Core Density 10 milestone "OR by buying an elixirmaking table from the merchant either or" (Q2), and "not sure about this. It will probably be buying an item from the merchant if I had to guess" (Q3). Then: "I think it makes most sense for the player to buy the elixir making table from the merchant, because I think that gives a gameplay loop that is appreciable", and "I think we'll probably have a quest as well, or some sort of tutorial or something", when the Traveling Merchant unlocks or when its quest is done (Q29).
- Foraging unlocks at the same point: "Also this will be where we unlock foraging as well" (Q3).
- A Brewing card in each zone opens a brewing board, the way the cycling board opens (Q9: a). Brewing is instant, ×1 or all, always succeeds, and costs only the two materials (Q10: a).

**Recipes**
- Spirit Valley's cycling recipes are known once brewing opens, and the adventure recipe appears the first time the special tile is harvested (Q8: e). How new recipes unlock is "a point of focus".
- As the rule for every zone, Lionel agreed to Claude's option (a), which Claude called *carry it, know it*: a recipe is learned the first time you hold its adventure ingredient. "That for now, A makes the most sense" (Q35). For Spirit Valley's cycling recipes, this clashes with Q8. The game needs "the right way to show the player that they've unlocked this".
- Next, where a Q36 answer would go: "Or maybe does it make most sense for the table to just come with the recipes?" Claude said yes; Lionel hasn't confirmed (Q36).
- The message then broke off at "Incorrect for" (Q38).

**Later zones**
- Lionel's first message: "1 elixir or 2 elixirs per zone". To Claude's recommendation for later zones (each brings a new technique and elixir of its own, Spirit Valley's fades, and cross-zone recipes are decided one by one), Lionel answered "yes" (Q22).

## What Claude assumed

- **Lionel's "2 materials"** means two kinds, each with a quantity, and "forge" means forage. Every material and elixir name is a placeholder.
- **The pairings:** Spirit drop + Spirit Fern brews the Smooth Flow elixir, and Dreadbeast drop + Dewdrop Tear the Torrential Flow elixir. They came with Claude's Q30 option; Lionel confirmed the two techniques, not the pairings.
- **Nobody is blocked:** a player who never brews still finishes Foundation, only slower. Lionel asked "soft gate?" (Q13), and Claude took Q14 as settling it.
- **Without a dose,** a technique plays exactly as it does today (asked in Q42).
- **A dose is 15 cycles,** one spent as each cycle starts, and only while cycling with its technique. A second dose adds cycles, and none are spent while the core is full. Claude took Q18's "# of cycles?" as a yes.
- **Drinking** happens at the technique's drawer in the cycling board's chest, and doesn't switch technique. Q21 (whether locked elixir techniques show) got "???", and Claude called it moot, since both techniques stay on the path tree.
- **Buying the table** opens the Brewing card and foraging, and monsters drop materials only from then on.
- **The special tile:** one per Shallow Woods map, offering Gather or Leave.
- **Torrential Flow's elixir** can be brewed before the technique is learned. A player who spent the Core Density 10 path point on Power Font holds Dreadbeast drops they can't use until the next point, at 20.
- **The draught** adds about 25% damage (Claude's example in Q24).
- **Q25 to Q27 got "blah",** so Claude took its own picks: materials are kept the moment they drop, even on a lost run, and the one-pager pitches the loop and asks Lionel's brother for input. Claude's Q25 pick (one run buys about one dose) was replaced by Q34.
- **The Merchant** sells no materials or elixirs, and the Tribulation stays elixir-free.
- **Every number is a starting value.** Claude also planned to size them at a later curve retune, which Lionel never asked for (Q40).

## What Claude proposed

**What a dose does: the ladder and the Tear** (from the Q31 deep dive). It is playable on the [Ladder and Tear](https://claude.ai/artifact/2jWQazQfaWaz8iTV2njSU8) canvas, which is private until Lionel shares it. Claude checked its rules by script but never looked at it on screen.
- A dose never changes the ball's path or speed, its press area, the scoring windows or the Madra. While a dose runs, every scoring zone is *loaded*: it is drawn filled and pays the bonus.
- **Smooth Flow climbs a ladder,** ×2 → ×2.5 → ×3 on a loaded zone's XP. A PERFECT climbs a rung and pays at the new one; a GOOD pays and holds; an OK pays ×1 and drops back to ×2. A loaded zone left unpressed pays nothing and also drops the ladder to ×2.
- **Torrential Flow fills a Tear,** a charge named after the Dewdrop Tear, while the cursor follows the ball, and the ball swells as it fills. Pressing the ball on the scoring zone crushes the Tear into that hit. The first second of following adds nothing; half (3.5 s) pays ×4.75 and full (7 s) ×10.
- **A stray press spills the elixir:** a press with no scoring zone in reach drops the ladder to ×2 and turns the next loaded zone *plain*, or empties the Tear. There is no spill in a cycle's first 1 s or last 0.5 s, within 0.3 s of a hit, or within 0.25 s after the ball leaves a zone nobody scored. Unlike Q17's example XP cost, a spill never takes back XP already earned.
- The ladder and the Tear carry between dosed cycles. They reset on a cycle without a dose, a technique switch or closing the board, and are never saved.
- A cut-off dosed cycle's remaining time must pass before the next dosed start, which blocks a tail skip that works in today's game (Q42). Cycling elixirs stay off the combat hotbar.
- Measured on the mockup, XP per cycle with a dose against without:
  - Smooth Flow, every press PERFECT: about 375 against 125.
  - Smooth Flow, every press GOOD: 140 against 70.
  - Torrential Flow, following the ball and hitting GOOD: about 244 against 25.
- Clicking once a second or faster gains nothing from a dose. Slower unaimed clicks gain a little, far below aimed play.
- The mockup's look is Claude's and unreviewed: jade loaded zones, a brass ring at full strength, "Spilled" and "Missed" floaters, and a dose line and a Drink button on the two techniques' drawers. One call is already known wrong: at the ladder's ×3, the brass ring hides the ring that shows the cursor is following. The mockup also stops Auto after an unplayed cycle without a dose, which Q19 didn't ask for.

**The exchange** (on top of Q34 and Q4)
- One enemy drop plus two of the recipe's foraged material (2 Spirit Fern, say) brew one elixir, and one elixir is one 15-cycle dose.
- The boss drops three, and the first enemy of each family in a run always drops.

**Recipes** (from the Q32 deep dive)
- In Spirit Valley the table teaches both cycling recipes, which keeps Q8, and *carry it, know it* covers the draught and later zones.
- Each zone's brewing board shows all its elixirs. An unlearned one is a sealed card saying where its missing ingredient comes from: "Dropped by Spirits · The Shallow Woods".
- Learning a recipe brings a toast, a log line, and NEW seals on the Brewing card and the recipe.
- A tutorial quest starts at the Intervener's fourth talk, the farewell after Core Density 10. Its steps: reach the Refugee Camp, where the Traveling Merchant is found; buy the table; brew a Smooth Flow elixir; drink it.

## Open questions

Most important first.

- **Q38 · What was incorrect?** Lionel's 3 November answers end mid-sentence: "Incorrect for". Claude guessed it was the start of a Q37 answer and asked Q37 again, but it may have been a correction of something in that round. Ask this first: it may change the answers above.
- **Q33 · What a dose does,** once Lionel has played the canvas:
  - (a) the ladder and the Tear, which asks the most and costs the most (the deep dive put its cycling side at 7 to 9 days);
  - (b) plain multipliers, PERFECT ×3, GOOD ×2, OK ×1, the cheapest;
  - (c) extra scoring zones while dosed, the only option that fills Smooth Flow's empty 6 s tail.

  If (a), the Tear pays about 10 times Torrential Flow's own XP per cycle, and 4 to 6.5 times Smooth Flow's per minute. That is well past Q16's 2 to 3 times. A 25-cycle dose at ×3 / ×6 would earn about the same and stay inside it. And is a spill the right price for a stray press?
- **Q36 · The table.** Does it teach Spirit Valley's two cycling recipes (Lionel's idea, which Claude backed)? Does it also hold one Spirit drop so the first brew happens at home, or does the first brew wait for the next run's drops? A drop would break the "Merchant sells no materials" assumption. And what does the table cost, and does it sell only once per save?
- **Q37 · The draught before its tile is found.** A sealed card from the start ("Found somewhere in the Shallow Woods"), or hidden until the first harvest? Q8 (e) has the recipe appear at the first harvest, which matches hidden; the sealed card is Claude's idea.
- **Q39 · Core Density and runs.** Core Density doesn't raise max Health or a run's Madra; both come from attributes. Its only link to runs is the path point every 10 levels, and most path nodes do nothing yet. The loop Lionel described ("comes back to the overworld, gets stronger, does the adventure stronger") rests on that link, on gear and on the draught. Is that enough once the path nodes work, or should Core Density feed the adventure directly?
- **Q40 · How big a dose is.** The Core Density 10 → 100 climb is about 3,000 XP. In Claude's simulation, an average player's 15 dosed Smooth Flow cycles earn about 92% of it, 55% from the dose itself. Even a curve six times longer would be paid off by one or two middling runs, after which runs stop mattering for Core Density. Claude suggested sizing doses so that going from the table to Core Density 100 takes about 3 to 5 runs. That needs a slower curve, and Lionel chose to keep today's pace (Q20). Does that answer stand?
- **Q41 · How a learned recipe shows.** Are a toast, a log line and NEW seals enough, or does learning a recipe need a bigger moment?
- **Q42 · Cycling without a dose.** Lionel said "hard without elixir", and at first spoke of using elixirs "to gate certain cycling techniques". Does a technique without a dose stay as it is today, or get harder? Is Torrential Flow still reworked (Q15)? And should plain cycling block the tail skip too? Today, switching technique twice after Smooth Flow's last scoring zone and restarting skips its 6 s tail, for 45 to 52% more XP a second.
- **Q43 · The draught itself.** Which foraged material goes in it, if Spirit Fern and Dewdrop Tear both go into the cycling elixirs? How much damage? How many draughts does one harvest brew? Claude's Q25 pick was about two runs per draught; one per harvest, with a tile on every map, would make it a damage bonus on every run. And what is the tile's material?
- **Q44 · Foraging behind the table.** New games would have no idle action until the Aura Well is found. Claude planned for saves that already have foraging to keep it. Is that right?
- **Q45 · The "blah" answers.** Should a lost run cost materials (Q26)? What should the one-pager ask of Lionel's brother (Q27)?
- **Later, with the mini-game:** does instant brewing stay as a quick brew? (Q11: "not sure")
