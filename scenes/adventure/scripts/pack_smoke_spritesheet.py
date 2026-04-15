"""
Pack the 25 black smoke frames in assets/Black smoke/ into a single
5x5 grid spritesheet at assets/sprites/atmosphere/smoke_veil_spritesheet.png.

Each frame is resized to 164x190 (matches the project hex tile bounds)
using LANCZOS. No color quantization — smoke is amorphous and the
gradients should stay smooth.

Re-runnable: regenerates the spritesheet from the source frames each run.
Drop new black-smoke frames into assets/Black smoke/ and re-run to
update.

Run from the worktree root:

    py scenes/adventure/scripts/pack_smoke_spritesheet.py
"""

from PIL import Image
import glob
import os
import re

SRC_DIR = "assets/Black smoke"
OUTPUT_PATH = "assets/sprites/atmosphere/smoke_veil_spritesheet.png"

# Per-cell size matches the project hex tile (164x190). The smoke is
# amorphous so the slight aspect squish is invisible.
CELL_SIZE = (164, 190)

# Atlas grid. 5x5 = 25 cells, exactly matching the source frame count.
ATLAS_COLS = 5
ATLAS_ROWS = 5

_INDEX_PATTERN = re.compile(r"blackSmoke(\d+)\.png", re.IGNORECASE)


def _extract_index(path: str) -> int:
    match = _INDEX_PATTERN.search(os.path.basename(path))
    if match is None:
        return -1
    return int(match.group(1))


def main() -> None:
    pattern = os.path.join(SRC_DIR, "blackSmoke*.png")
    paths = sorted(glob.glob(pattern))
    indexed = [(p, _extract_index(p)) for p in paths]
    indexed = [(p, i) for (p, i) in indexed if i >= 0]
    if not indexed:
        print(f"error: no blackSmoke*.png files found in {SRC_DIR}")
        return

    indexed.sort(key=lambda pair: pair[1])
    print(f"Found {len(indexed)} smoke frame(s)")

    atlas_w = ATLAS_COLS * CELL_SIZE[0]
    atlas_h = ATLAS_ROWS * CELL_SIZE[1]
    atlas = Image.new("RGBA", (atlas_w, atlas_h), (0, 0, 0, 0))

    for path, idx in indexed:
        if idx >= ATLAS_COLS * ATLAS_ROWS:
            print(f"  WARN: {os.path.basename(path)} index {idx} exceeds {ATLAS_COLS * ATLAS_ROWS} cells; skipping")
            continue
        col = idx % ATLAS_COLS
        row = idx // ATLAS_COLS
        x = col * CELL_SIZE[0]
        y = row * CELL_SIZE[1]

        src = Image.open(path)
        if src.mode != "RGBA":
            src = src.convert("RGBA")
        resized = src.resize(CELL_SIZE, Image.LANCZOS)
        atlas.paste(resized, (x, y), resized)
        print(f"  packed {os.path.basename(path)} -> cell ({col}, {row})")

    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    atlas.save(OUTPUT_PATH)
    print(f"wrote {OUTPUT_PATH} ({atlas_w}x{atlas_h}, {ATLAS_COLS} cols x {ATLAS_ROWS} rows)")


if __name__ == "__main__":
    main()
