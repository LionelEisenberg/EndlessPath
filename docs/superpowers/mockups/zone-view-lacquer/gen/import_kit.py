"""Copy the lacquer kit into the Godot project.

Screen-space textures (drawn at 2x) go to assets/ui/lacquer/ unchanged.
Map-space textures the kit drew at 2x are halved (nearest, after checking that
every 2x2 block is uniform) into assets/ui/lacquer/map/, because the zone
camera's zoom 2 doubles them again.
Placeholder action icons (native 16x16) go to assets/ui/lacquer/icons/.
User files and the mock-only full-screen fog lattices are skipped.
"""
import shutil
import sys
from pathlib import Path

from PIL import Image

KIT = Path(sys.argv[1])
DEST = Path(sys.argv[2])

MAP_FILES = [
    "lacquer_fog_t1_atlas_ai.png", "lacquer_fog_t2_atlas_ai.png", "lacquer_fog_t3_atlas_ai.png",
    "lacquer_tile_locked_ai.png", "lacquer_tile_locked_hover_ai.png",
    "lacquer_tile_uncharted_ai.png", "lacquer_tile_uncharted_hover_ai.png",
    "lacquer_hex_current_ai.png", "lacquer_hex_open_ai.png", "lacquer_hex_hover_ai.png",
    "lacquer_hex_hover_in_ai.png", "lacquer_hex_pinned_in_ai.png",
    "lacquer_route_dot_ai.png", "lacquer_route_dot_lit_ai.png",
    "lacquer_char_shadow_ai.png",
]
SKIP = {
    "lacquer_fog_base_ai.png", "lacquer_fog_open_ai.png",
    "lacquer_fog_locked_ai.png", "lacquer_fog_both_ai.png",
    "BMEULJIROTTF.ttf", "YatraOne-Regular.ttf",
    "Hex_Forest_00_Basic.png", "Hex_Forest_06_River.png",
    "main_character_spritesheet.png", "inventory_icon.png",
    "character_icon.png", "combat_icon.png", "gold_icon.png", "star_icon.png",
}


SHADOW_BIG = (4, (0x05, 0x07, 0x07))
SHADOW_SMALL = (2, (0x15, 0x09, 0x09))
SHADOWS = {}
for n in ["cult", "goals", "log1", "log2", "log3", "log4", "log5", "dock", "lore", "pop_locked",
          "pop_locked_preview", "pop_uncharted", "pop_uncharted_preview", "drawer_run"]:
    SHADOWS[f"lacquer_{n}_ai.png"] = SHADOW_BIG
for n in ["drawer", "drawer_tall", "drawer_tall_ready", "btn", "btn_hover", "btn_ring", "about",
          "now_plate", "showme", "token"] + [f"plate_{k}{h}" for k in ("current", "open", "locked", "uncharted")
                                    for h in ("", "_hover")]:
    SHADOWS[f"lacquer_{n}_ai.png"] = SHADOW_SMALL


def bake_shadow(src: Path, dst: Path, offset: int, rgb: tuple) -> None:
    """Hard drop shadow (kit rule 3): the silhouette in the shadow colour at +offset, under the art."""
    img = Image.open(src).convert("RGBA")
    w, h = img.size
    out = Image.new("RGBA", (w + offset, h + offset), (0, 0, 0, 0))
    alpha = img.getchannel("A")
    shadow = Image.new("RGBA", (w, h), rgb + (255,))
    shadow.putalpha(alpha)
    out.alpha_composite(shadow, (offset, offset))
    out.alpha_composite(img, (0, 0))
    out.save(dst)
    print(f"shadow {offset}px {src.name} -> {w + offset}x{h + offset}")


CHEST = ["lacquer_chest_top_ai.png", "lacquer_chest_mid_ai.png", "lacquer_chest_bot_ai.png"]


def bake_column(kit: Path, dest: Path) -> None:
    """The chest is a column (top, tiled mid, bottom) whose wrapper casts one 4 px shadow.
    Each slice gets the shadow of the column around it: the slice above it (the mid tiles
    onto itself) supplies the 4 rows of overhang, and only the bottom slice grows taller."""
    off, rgb = SHADOW_BIG
    top, mid, bot = (Image.open(kit / n).convert("RGBA") for n in CHEST)
    for name, img, above, last in ((CHEST[0], top, None, False), (CHEST[1], mid, mid, False),
                                   (CHEST[2], bot, mid, True)):
        w, h = img.size
        lead = off if above is not None else 0
        tall = Image.new("RGBA", (w, h + lead), (0, 0, 0, 0))
        if above is not None:
            tall.alpha_composite(above.crop((0, above.size[1] - off, w, above.size[1])), (0, 0))
        tall.alpha_composite(img, (0, lead))
        shadow = Image.new("RGBA", (w + off, h + lead + off), (0, 0, 0, 0))
        sil = Image.new("RGBA", tall.size, rgb + (255,))
        sil.putalpha(tall.getchannel("A"))
        shadow.alpha_composite(sil, (off, off))
        out = shadow.crop((0, lead, w + off, lead + h + (off if last else 0)))
        out.alpha_composite(img, (0, 0))
        out.save(dest / name)
        print(f"column shadow {name} -> {out.size[0]}x{out.size[1]}")


def halve(src: Path, dst: Path) -> None:
    img = Image.open(src).convert("RGBA")
    w, h = img.size
    assert w % 2 == 0 and h % 2 == 0, f"{src.name}: odd size {w}x{h}"
    px = img.load()
    bad = 0
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            a = px[x, y]
            if px[x + 1, y] != a or px[x, y + 1] != a or px[x + 1, y + 1] != a:
                bad += 1
    if bad:
        raise SystemExit(f"{src.name}: {bad} non-uniform 2x2 blocks, cannot halve losslessly")
    img.resize((w // 2, h // 2), Image.NEAREST).save(dst)
    print(f"halved {src.name} {w}x{h} -> {w // 2}x{h // 2}")


def main() -> None:
    (DEST / "map").mkdir(parents=True, exist_ok=True)
    (DEST / "icons").mkdir(parents=True, exist_ok=True)
    for src in sorted(KIT.iterdir()):
        name = src.name
        if name in SKIP or name in CHEST:
            continue
        if name in MAP_FILES:
            halve(src, DEST / "map" / name)
        elif name.startswith("ic_"):
            shutil.copy2(src, DEST / "icons" / name)
        elif name in SHADOWS:
            bake_shadow(src, DEST / name, *SHADOWS[name])
        elif name.startswith("lacquer_"):
            shutil.copy2(src, DEST / name)
        else:
            raise SystemExit(f"unexpected file {name}")
    bake_column(KIT, DEST)
    missing = [m for m in MAP_FILES if not (DEST / "map" / m).exists()]
    missing += [m for m in SHADOWS if not (DEST / m).exists()]
    if missing:
        raise SystemExit(f"missing map files: {missing}")


main()
