"""Copy the lacquer cycling kit into the Godot project.

Usage: python import_cycling.py <mock folder> <assets/ui/lacquer>

The textures go to <assets/ui/lacquer>/cycling/, except the three technique icons, which go to
<assets/ui/lacquer>/icons/. They keep the 2x size they were drawn at. Each file is copied byte for
byte unless a table below bakes a hard drop shadow (STYLE_GUIDE rule 6) or padding into it.

Only the files named in those tables are imported. The rest of the mock folder is skipped: the
turned-down boards B and C, body_brass, body_seated, pellet_jade, tray_side, dither, gen/ and
.gdignore. bake_shadow is written out here, the same as in zone-view-lacquer/gen/import_kit.py,
instead of being taken from it: that module reads sys.argv and starts its own copy the moment
Python loads it.
"""
import shutil
import sys
from pathlib import Path

from PIL import Image

# Hard drop shadows, the same two the zone kit uses: (offset in px, colour).
SHADOW_BIG = (4, (0x05, 0x07, 0x07))
SHADOW_SMALL = (2, (0x15, 0x09, 0x09))

CYCLING = "cycling"
ICONS = "icons"

# Copied byte for byte: source name -> folder under the destination.
COPY = {
    "lacquer_cyc_pellet_brass_ai.png": CYCLING,
    "lacquer_cyc_pellet_cream_ai.png": CYCLING,
    "lacquer_cyc_pellet_tan_ai.png": CYCLING,
    "lacquer_ic_tech_foundation_ai.png": ICONS,
    "lacquer_ic_tech_smooth_ai.png": ICONS,
    "lacquer_ic_tech_torrent_ai.png": ICONS,
}

# The game's own versions, which differ from the mock's (kit_cycling.py game_kit()): copied
# byte for byte from the mock folder's game/ subfolder, under the same name -> folder under
# the destination.
GAME_DIR = "game"
GAME = {
    "lacquer_cyc_body_carved_ai.png": CYCLING,
    "lacquer_cyc_ball_strip_ai.png": CYCLING,
    "lacquer_cyc_ball_rings_ai.png": CYCLING,
    "lacquer_cyc_zone_strip_ai.png": CYCLING,
}

# Given a drop shadow, in the cycling folder: source name -> (name there, shadow offset, shadow colour).
# Board A is the one kept (B and C were turned down), so it loses its letter on the way in.
SHADOWS = {
    "lacquer_cyc_board_a_ai.png": ("lacquer_cyc_board_ai.png", *SHADOW_BIG),
    "lacquer_cyc_auto_ai.png": ("lacquer_cyc_auto_ai.png", *SHADOW_SMALL),
}

# Padded with clear px right and bottom, in the cycling folder: source name -> (name there, px).
# The pressed Auto toggle casts no shadow, so it is padded to the raised one's size to swap in place.
PADS = {
    "lacquer_cyc_auto_on_ai.png": ("lacquer_cyc_auto_on_ai.png", 2),
}


def bake_shadow(src: Path, dst: Path, offset: int, rgb: tuple) -> None:
    """Hard drop shadow (STYLE_GUIDE rule 6): the silhouette in the shadow colour at +offset, under the art."""
    img = Image.open(src).convert("RGBA")
    w, h = img.size
    out = Image.new("RGBA", (w + offset, h + offset), (0, 0, 0, 0))
    alpha = img.getchannel("A")
    shadow = Image.new("RGBA", (w, h), rgb + (255,))
    shadow.putalpha(alpha)
    out.alpha_composite(shadow, (offset, offset))
    out.alpha_composite(img, (0, 0))
    out.save(dst)
    print(f"shadow {offset}px {src.name} -> {dst.name} {w + offset}x{h + offset}")


def pad(src: Path, dst: Path, px: int) -> None:
    """Grow the canvas by px of clear right and bottom, the art staying at 0."""
    img = Image.open(src).convert("RGBA")
    w, h = img.size
    out = Image.new("RGBA", (w + px, h + px), (0, 0, 0, 0))
    out.alpha_composite(img, (0, 0))
    out.save(dst)
    print(f"pad {px}px {src.name} -> {dst.name} {w + px}x{h + px}")


def main(argv: list) -> None:
    if len(argv) != 3:
        raise SystemExit("usage: python import_cycling.py <mock folder> <assets/ui/lacquer>")
    kit, dest = Path(argv[1]), Path(argv[2])
    wanted = [*COPY, *SHADOWS, *PADS]
    missing = [name for name in wanted if not (kit / name).is_file()]
    missing += [f"{GAME_DIR}/{name}" for name in GAME if not (kit / GAME_DIR / name).is_file()]
    if missing:
        raise SystemExit(f"missing from {kit}: {missing}")
    for folder in (CYCLING, ICONS):
        (dest / folder).mkdir(parents=True, exist_ok=True)
    for name, folder in COPY.items():
        shutil.copy2(kit / name, dest / folder / name)
        print(f"copy {name} -> {folder}/")
    for name, folder in GAME.items():
        shutil.copy2(kit / GAME_DIR / name, dest / folder / name)
        print(f"copy {GAME_DIR}/{name} -> {folder}/")
    for name, (out, offset, rgb) in SHADOWS.items():
        bake_shadow(kit / name, dest / CYCLING / out, offset, rgb)
    for name, (out, px) in PADS.items():
        pad(kit / name, dest / CYCLING / out, px)
    for src in sorted(kit.glob("*.png")):
        if src.name not in wanted:
            note = " (the game's version is in game/)" if src.name in GAME else ""
            print(f"skip {src.name}{note}")


if __name__ == "__main__":
    main(sys.argv)
