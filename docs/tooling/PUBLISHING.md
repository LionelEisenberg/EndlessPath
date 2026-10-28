# Publishing

## Overview

The game is published to [itch.io](https://lionelshnizel.itch.io/endless-path) by hand, one click at a time, always from `main`. A GitHub Actions workflow tests the game, exports it from a clean checkout and uploads the builds, so what players get is exactly what `main` holds, not what happens to be on a development machine.

| Build | Export preset | itch.io channel | What the player gets |
|-------|---------------|-----------------|----------------------|
| Web | `Web` | `web` | The game playable in the browser on the itch.io page |
| Windows | `Windows Desktop` | `windows` | A download holding `EndlessPath.exe` and the game's data in `EndlessPath.pck` beside it |

Publishing is manual by choice: merging to `main` publishes nothing, so a merged PR reaches players only when someone decides it should.

## Publishing a Build

In GitHub, open **Actions → Publish to itch.io → Run workflow**, keep the branch on `main` and run it. From a terminal:

```bash
gh workflow run publish-itch.yml --ref main
```

The run has three jobs:

| Job | Runs on | What it does |
|-----|---------|--------------|
| Tests | Windows | Imports the project and runs the GUT suite through `tests/run_tests.ps1`, the same runner as on a development machine ([TESTING.md](../testing/TESTING.md)) |
| Export | Ubuntu | Imports the project and exports both presets with the pinned Godot release, then keeps the builds as the run's artifacts |
| Publish | Ubuntu | Pushes both builds to itch.io with [butler](https://itch.io/docs/butler/). Starts only after Tests and Export pass |

Each upload is labelled with the date and commit (`YYYY.MM.DD-<short sha>`), which itch.io shows as the build's version. A channel whose build has not changed since the last upload is skipped.

The Publish job runs only for a manual run on `main`. A run on any other branch, and the run a pull request starts when it changes the workflow or `export_presets.cfg`, tests and exports but publishes nothing. Its builds can be downloaded from the run's page.

A failing test stops the publish. A test that depends on frame timing can fail on a busy runner, so rerun the failed job before investigating, as on a development machine.

## The Builds

The presets live in `export_presets.cfg` and export to the gitignored `build/` folder.

- **Web** is single-threaded, so itch.io needs no SharedArrayBuffer setting. Saves go to the browser's storage for the itch.io site and carry over from one published build to the next.
- **Windows** keeps the game's data in a `.pck` next to the exe rather than inside it. The exe is Godot's unmodified engine and is identical in every build, so when players update through the itch.io app, the download is only the game data that changed. The exe is not code-signed, so Windows SmartScreen warns on first launch.

Both presets leave out what players don't need: `tests/`, the GUT addon, `docs/` and `.aseprite` sources. They also leave out `.mcp.json` (local tool paths) and `.gutconfig.json`, which Godot would otherwise export because it treats `.json` files as resources. Dialogic's `.dtl` timelines and `.dch` characters are included by name.

To export locally, install the export templates for the project's Godot version (Editor → Manage Export Templates), then, from the project root:

```bash
"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --export-release "Web" build/web/index.html
```

A Web build needs an HTTP server to run: opening `index.html` from disk does not work.

## Configuration

### Repository settings

In the GitHub repository's **Settings → Secrets and variables → Actions**:

| Name | Kind | Value |
|------|------|-------|
| `BUTLER_API_KEY` | Secret | An itch.io API key, from itch.io → Settings → API keys |
| `ITCH_GAME` | Variable | The itch.io page as `user/game`: `lionelshnizel/endless-path` |

The Publish job stops with an error naming whichever of the two is missing.

### The itch.io page

The page's kind is HTML. On the page's edit screen, the `web` upload has "This file will be played in the browser" ticked, which itch.io keeps for later uploads to that channel. The embed size and the fullscreen button are set there too: the game renders at 1920×1080 and scales to the embed.

### Godot version

`GODOT_VERSION` at the top of the workflow pins the Godot release every job uses. It must match the editor the project is worked in. Changing it also changes the export job's cache key, so the next run downloads the new engine and templates.

## Key Files

| File | Role |
|------|------|
| `.github/workflows/publish-itch.yml` | The workflow: triggers, the three jobs, the pinned Godot version |
| `export_presets.cfg` | The Web and Windows presets, with their include and exclude filters |
| `tests/run_tests.ps1` | The test runner the Tests job calls |

## Work Remaining

### Missing Functionality

- `[MEDIUM]` Decide whether public builds keep the dev panel. It ships in every exported build, open to anyone who presses its hotkey ([DEV_TOOLS.md](DEV_TOOLS.md#dev-panel)).
- `[MEDIUM]` Saves carry over between published builds, so a change to the save format reaches players' existing saves. Changes to `SaveGameData` need a migration before they are published.
- `[LOW]` No Linux or macOS channel. Linux is one more preset and export step; macOS needs signing and notarization to launch without warnings.
- `[LOW]` The game does not show its build version, so a bug report can't say which build it came from. The version butler labels the upload with could also be written into `application/config/version` at export.

### Tech Debt

- `[LOW]` The Publish job installs butler's latest release, so a butler update can change a publish without a change to the repository.
- `[LOW]` The presets export the editor-only parts of the addons (AsepriteWizard's interface, Dialogic's editor images) into the pack.
