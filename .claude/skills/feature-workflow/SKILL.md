---
name: feature-workflow
description: Use when starting or coordinating a feature or release built through GitHub issues, with a release branch, one session per issue, canvases and merge watching. Covers planning the issues, starting the sessions, watching merges, and cutting the release.
---

# Feature Workflow (Coordinator)

Read `docs/tooling/FEATURE_WORKFLOW.md` in full first: it is the process, and this list only orders it.

1. **Release branch.** Cut `release/vX.Y.Z` from `main` and push it ("The Branches").
2. **Questions.** Read the requirements and the docs they point at, then ask the user every open question, in batches with a recommended answer each.
3. **Plan.** Run a planning workflow that maps the code, cuts bigger issues (5 to 10 for a feature) and checks every pair for overlaps. Publish the plan as a review page ("1. Plan").
4. **Create.** On the user's go-ahead, create the issues and the tracking issue with a script, from the issue template.
5. **Start.** Start every ready issue in its own session, cut from the release branch, with effort by difficulty and the brief from "2. Run". Starts need the user's own turn: on an automated turn, ask once so a single click starts them.
6. **Watch.** Arm the merge watcher. On each closure, tick the issue, check stale issues against what merged, and start or offer what it unblocks.
7. **Finish.** The release's last issue writes the docs on the release branch. Balance by playing, with a driver. The user merges the release into `main` and publishes ("3. Finish").

Every game window you open is muted and off the user's main screen ("Running the Game in a Session").
