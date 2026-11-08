# Feature Workflow

How a version's features get built. One coordinator session plans the work into GitHub issues. One session per issue designs and builds it. Every PR merges into the version's release branch.

The user's part is fixed:
- answer the design questions;
- approve each canvas;
- merge every PR;
- merge the release into `main`.

The stats rework (tracking issue #85) ran this way. This guide keeps what worked there, plus the changes the user asked for after it. A coordinator session loads it with the `feature-workflow` skill.

## The Branches

- **A release branch per version.** At the start, the coordinator cuts `release/vX.Y.Z` from `main` and pushes it. The version comes after the last one published to itch; v0.0.1 was the first ([its devlog](https://lionelshnizel.itch.io/endless-path/devlog/1762048/endlesspath-v001)).
- **Every issue targets it:**
  - each session cuts its worktree from the release branch (`start_session`'s `source_branch`);
  - it merges the release branch into its own branch once, right before the PR merges;
  - it opens the PR with `gh pr create --base release/vX.Y.Z`.
- **Only the user merges.** That covers each issue's PR into the release branch, and the release into `main` once the version is done.
- **`main` matches the last release.** A fix that can't wait (`main` won't boot) branches from `main` and merges into `main`. It then reaches the release branch through a merge of `main` into it.
- **Claimed at merge.** Save versions and append-only enum values are claimed as PRs merge into the release branch. When two open PRs both take a save version, whichever merges second renumbers its step.

## Who Does What

| Who | Does |
|---|---|
| The user | Gives the requirements and the docs to read, answers questions, approves every canvas, merges every PR and then the release, publishes, and writes the devlog |
| The coordinator | One session on the most capable model at its highest effort, using workflows (Ultracode) to plan. It plans and creates the issues, starts the issue sessions, watches merges and starts what they unblock, and keeps the tracking issue current. It builds nothing itself beyond small fixes |
| An issue session | One per issue, in its own worktree. It draws the canvas, writes its plan, builds, tests and opens the PR. Its effort follows the issue's difficulty: low runs at medium effort, medium at high, high at max |

## 1. Plan

1. **Questions first.** The coordinator reads the requirements and the docs they point at, then asks the user everything still open. The questions go in batches, each with a recommended answer, before any planning.
2. **Map, then cut.** A planning workflow maps the code the feature touches and cuts the work into issues. It then checks every pair of issues for shared files and functions. That check sets each issue's Needs (what must merge first) and Runs alongside (what may share a file).
3. **Bigger issues.** Make one issue per area of a system, and one bug batch per round of bugs, even when an issue touches files in several places. Aim for 5 to 10 issues for a feature. Split an area only when its parts can't share a PR: one needs the other merged first, or both would rewrite the same functions. The stats rework's many small issues cost more review and coordination than the work needed.
4. **Review before creating.** The coordinator publishes the plan (the issues, their graph and the waves) as a review page. It creates the issues only on the user's go-ahead, with a script that writes each one and fills every `{{issue:<id>}}` with its number.
5. **The tracking issue** lists every issue with its size, difficulty and needs, and holds the dependency graph, the waves and the rules this guide sets. Its boxes are ticked as PRs merge.

### The Issue Template

An issue is planned at the design level: what the player gets and why, what is decided, and what stays open. It carries no implementation steps and no test code, since its session plans against the release branch when it starts. Sections, in order:

| Section | Holds |
|---|---|
| First line | The feature and tracking issue it belongs to, with the user's own words when the issue comes from a note of theirs |
| Size and difficulty | S, M or L and low, medium or high, with one line on what makes it hard, so the session's effort can be set |
| What the player gets | The change as the player sees it |
| Why | The reason, with its source |
| What happens now | What the code does today: the owning classes, scenes and data files, and the merged PRs that built them |
| Decided | One bullet per settled point, each with its source |
| Settle at the mock-up step | The questions the canvas answers, or "No player-facing change, so no mock-up step." |
| Touches | The classes, scenes, data files and test areas it changes, specific enough to spot overlaps, then a "Save:" line |
| Needs | The issues that must merge first, each with the reason |
| Runs alongside | The issues that may run beside it, what they share, and who changes what |
| Done when | The checks the user makes in the game on the issue's own save (`-- --save=user://dev/runs/<id>.tres`) or a preset, then "The test suite passes." |
| Out of scope | What it leaves alone |
| Docs to update | The living docs the release's docs pass will update |

## 2. Run

1. **Start what's ready.** An issue starts once every issue in its Needs has merged into the release branch. The app starts a session only from the user's own message. On a turn that the watcher or a workflow started, the coordinator asks once ("Start the N issues that are ready?"), so a single click starts them all. Proposal cards are the fallback, at most three per turn.
2. **The brief.** Every session's brief has the same shape:
   - read `CLAUDE.md`, the issue, the tracking issue's rules, and the merged PRs the issue names;
   - draw the canvas first if the player sees the change;
   - write a plan file under `docs/superpowers/plans/`, then build with tests;
   - open a PR into the release branch that closes the issue and ends with `## Docs to update`;
   - don't merge;
   - run the Done when checks on the issue's own save.

   It adds what only the coordinator knows: which issues run beside it, what they share, and what changed under the issue since it was written.
3. **Check stale issues.** An issue written before its needs merged is checked against what those PRs built before its session starts. A short workflow does it: one reader per issue, and one for the overlaps between them. The brief then says what in the issue is out of date.
4. **A canvas for every look change.** Each session draws a new canvas for its issue, from captures of the real game where it can. It records the user's answers on the issue. When two issues must agree on a look, their canvases link each other and show the shared boards side by side.
5. **Watch merges.** A background loop polls the tracking issue's issues every 2 minutes and wakes the coordinator when one closes. On each closure, the coordinator:
   - ticks the issue in the tracking issue;
   - starts what it unblocks;
   - tells the sessions in flight when the merged PR changed code they share.

   The loop dies with the coordinator's process, so re-arm it after a restart. Stopping the coordinator stops it too.

## 3. Finish

1. **Docs at the end.** No PR edits living docs. The release's last issue writes every merged PR's `## Docs to update` list on the release branch, so the docs reach `main` with the code they describe.
2. **Balance by playing.** Pacing is measured as well as worked out. A driver plays the stage in a game window, muted and sped up, the way an average player would, and logs when each goal lands. On the stats rework, the driver showed the core filling half an hour before the stat caps, a gap the arithmetic had missed.
3. **Release.** The user merges the release branch into `main`, publishes to itch ([PUBLISHING.md](PUBLISHING.md)) and writes the devlog.

## Running the Game in a Session

A session that opens a game window keeps it out of the user's way:
- **Muted:** add `--audio-driver Dummy`, unless the check is about sound. Headless runs are silent anyway.
- **Off the main screen:** `.claude/hooks/game_window_args.ps1` prints the `--screen` option for the screen the Claude app is on. When Claude shares the main screen, it picks the largest other screen. Godot numbers screens in Windows' order.
- **Focus:** a new window may still take focus. That's accepted.
- **Its own save:** `-- --save=user://dev/runs/<name>.tres`, or a preset ([DEV_TOOLS.md](DEV_TOOLS.md)).
- **Sped up for timing runs:** use the dev time speed (`DevManager.set_time_speed()`) or `Engine.time_scale`. Drills and the Tribulation read the wall clock, and fight transitions ignore the time scale, so a timing run spends those at ×1.

```bash
"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64.exe" --path . --audio-driver Dummy $(powershell -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/game_window_args.ps1) scenes/main/main_game/main_game.tscn -- --save=user://dev/runs/<name>.tres
```

## Pitfalls

- **Session starts need the user's own turn.** A coordinator turn that a watcher or workflow started can only propose sessions.
- **`gh` outside a checkout** needs `--repo LionelEisenberg/EndlessPath`.
- **`gh pr edit` can fail** on GitHub's retired Projects (classic) API. `gh api -X PATCH repos/LionelEisenberg/EndlessPath/pulls/<n> -F body=@<file>` sets a PR's description instead.
- **Rerunning an issue-creation script** rewrites every issue it made, including edits made since. Create a late issue on its own.
- **The repository is public.** Keep local paths and personal details out of issues and PRs.
- **Tests pin shipped values.** A retune breaks the tests that check them, and those change with it. A subagent on a cheaper model can do that work.
