"""
Resize hex tile variants in a biome folder under hex_tiles/ and pack
them into a single atlas PNG that the project's TileSet references as
one TileSetAtlasSource with multiple cells.

Usage:

    py scenes/tilemaps/scripts/pack_hex_atlas.py <biome>

Where <biome> is a folder name under assets/sprites/tilemap/hex_tiles/.
For example:

    py scenes/tilemaps/scripts/pack_hex_atlas.py forest

The biome folder is expected to contain files named
Hex_<Biome>_NN_<label>.png (e.g. Hex_Forest_07_Mountains1.png), where
NN is the variant index that determines its position in the atlas grid.

Two phases per run:

1. Resize/quantize phase: every Hex_<Biome>_*.png file in the biome
   folder is resized to 164x190 with 32-color quantization (a no-op for
   files already at the target size, so it's safe to re-run). Both the
   resized individual files AND the packed atlas are kept on disk so
   variants can be inspected one at a time without unpacking the atlas.

2. Atlas pack phase: all 164x190 variants are gathered, sorted by their
   filename's NN index, and pasted into grid cells of a single
   hex_<biome>_atlas.png written into the same biome folder. Variant
   index N maps to grid cell (N % ATLAS_COLS, N // ATLAS_COLS). The
   TileSet references this atlas and picks cells via atlas coords keyed
   on ZoneData.tile_variant_index.
"""

from PIL import Image
import glob
import os
import re
import sys

# --- Configuration ---

HEX_TILES_DIR = "assets/sprites/tilemap/hex_tiles"

# Output PNG bounds. Match the project TileSet.tile_size exactly so the
# new art drops into the grid at the same effective size as the existing
# tile_horizontal.png.
TARGET_PNG_SIZE = (164, 190)

# Visible hex dimensions inside the PNG. Matches the hex content of
# tile_horizontal.png for consistent grid alignment across all tiles.
TARGET_HEX_SIZE = (156, 181)

# Top-left offset where the visible hex is pasted onto the output
# canvas. Matches tile_horizontal.png's layout so all tiles share the
# same border padding.
PASTE_OFFSET = (4, 4)

# How many RGB colors to keep in the quantized output.
#   Lower  (8-16)  = more posterized / painted look, max sharpness
#   Medium (24-48) = balanced, still reads as detailed
#   Higher (64+)   = approaches the blurry pre-quantization result
# 32 is a good starting point for detailed tile art.
PALETTE_COLORS = 32

# Atlas pack settings. Variants are gridded into ATLAS_COLS columns;
# rows extend as needed to hold all variants. Variant index N goes to
# cell (N % ATLAS_COLS, N // ATLAS_COLS). Keep ATLAS_COLS in sync with
# the matching const in zone_tilemap.gd (e.g. FOREST_ATLAS_COLS).
ATLAS_COLS = 6


# --- Resize phase ---

def resize_and_quantize(path: str) -> None:
    """Resize one hex variant to the target tile dimensions with
    palette quantization. Modifies the file in place."""
    src = Image.open(path)
    if src.size == TARGET_PNG_SIZE:
        print(f"  skip (already {TARGET_PNG_SIZE}): {os.path.basename(path)}")
        return
    if src.mode != "RGBA":
        src = src.convert("RGBA")

    # Auto-detect the visible hex bounds from the alpha channel so each
    # variant's individual padding doesn't need to be hardcoded.
    bbox = src.split()[-1].getbbox()
    if bbox is None:
        print(f"  skip (fully transparent): {os.path.basename(path)}")
        return

    # 1. Crop to the visible hex
    hex_only = src.crop(bbox)

    # 2. LANCZOS downscale for smooth geometric shape
    resized = hex_only.resize(TARGET_HEX_SIZE, Image.LANCZOS)

    # 3. Quantize RGB to a limited palette to reverse the muddy
    #    color-blending introduced by the downscale. The alpha channel
    #    is kept separately so the hex edges stay smoothly anti-aliased.
    rgb = resized.convert("RGB")
    quantized_p = rgb.quantize(
        colors=PALETTE_COLORS,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    )
    quantized_rgb = quantized_p.convert("RGB")
    alpha = resized.split()[-1]
    quantized_rgba = Image.merge("RGBA", (*quantized_rgb.split(), alpha))

    # 4. Paste onto a fresh 164x190 transparent canvas at the standard
    #    offset that matches tile_horizontal.png's layout.
    canvas = Image.new("RGBA", TARGET_PNG_SIZE, (0, 0, 0, 0))
    canvas.paste(quantized_rgba, PASTE_OFFSET)
    canvas.save(path)

    print(f"  resized {src.size} -> {TARGET_PNG_SIZE} ({PALETTE_COLORS} colors): {os.path.basename(path)}")


# --- Atlas pack phase ---

def _build_index_pattern(biome_capitalized: str) -> "re.Pattern[str]":
    """Builds the regex used to pull NN out of Hex_<Biome>_NN_*.png."""
    return re.compile(rf"Hex_{re.escape(biome_capitalized)}_(\d+)_")


def _extract_variant_index(path: str, index_pattern: "re.Pattern[str]") -> int:
    """Pulls the NN integer out of a Hex_<Biome>_NN_*.png filename."""
    match = index_pattern.search(os.path.basename(path))
    if match is None:
        return -1
    return int(match.group(1))


def pack_atlas(
    variant_files: list[str],
    atlas_output_path: str,
    biome_capitalized: str,
) -> None:
    """Pack the resized variants into a single grid atlas PNG. Variant
    indices determine cell position via (idx % ATLAS_COLS, idx // ATLAS_COLS).
    Empty grid cells (gaps in the index sequence) stay transparent."""
    index_pattern = _build_index_pattern(biome_capitalized)
    indexed = [(p, _extract_variant_index(p, index_pattern)) for p in variant_files]
    indexed = [(p, i) for (p, i) in indexed if i >= 0]
    if not indexed:
        print("pack_atlas: no valid variants found; skipping atlas generation")
        return

    indexed.sort(key=lambda pair: pair[1])
    max_index = indexed[-1][1]
    rows = (max_index // ATLAS_COLS) + 1
    atlas_w = ATLAS_COLS * TARGET_PNG_SIZE[0]
    atlas_h = rows * TARGET_PNG_SIZE[1]

    atlas = Image.new("RGBA", (atlas_w, atlas_h), (0, 0, 0, 0))
    for path, idx in indexed:
        col = idx % ATLAS_COLS
        row = idx // ATLAS_COLS
        x = col * TARGET_PNG_SIZE[0]
        y = row * TARGET_PNG_SIZE[1]
        cell = Image.open(path)
        if cell.mode != "RGBA":
            cell = cell.convert("RGBA")
        if cell.size != TARGET_PNG_SIZE:
            print(f"  WARN: {os.path.basename(path)} is {cell.size}, expected {TARGET_PNG_SIZE} - skipping")
            continue
        atlas.paste(cell, (x, y), cell)

    os.makedirs(os.path.dirname(atlas_output_path), exist_ok=True)
    atlas.save(atlas_output_path)
    print(f"packed {len(indexed)} variants into {atlas_output_path} ({atlas_w}x{atlas_h}, {ATLAS_COLS} cols x {rows} rows)")


# --- Entry point ---

def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: py scenes/tilemaps/scripts/pack_hex_atlas.py <biome>")
        print("  e.g. py scenes/tilemaps/scripts/pack_hex_atlas.py forest")
        sys.exit(1)

    biome = sys.argv[1].strip().lower()
    if not biome:
        print("error: biome name cannot be empty")
        sys.exit(1)
    biome_capitalized = biome.capitalize()
    biome_dir = os.path.join(HEX_TILES_DIR, biome)
    if not os.path.isdir(biome_dir):
        print(f"error: biome folder not found: {biome_dir}")
        sys.exit(1)

    # Phase 1: resize/quantize. Glob within the biome folder for the
    # variant files matching the Hex_<Biome>_NN_*.png pattern. The two
    # digit slots keep this from accidentally re-processing the script's
    # own atlas output (hex_<biome>_atlas.png), which Windows' case
    # insensitive glob would otherwise match.
    pattern = os.path.join(biome_dir, f"Hex_{biome_capitalized}_[0-9][0-9]_*.png")
    files = sorted(glob.glob(pattern))
    print(f"Found {len(files)} Hex_{biome_capitalized} file(s) in {biome_dir}")
    for f in files:
        resize_and_quantize(f)

    # Phase 2: pack the atlas alongside the individual files in the
    # same biome folder.
    atlas_output_path = os.path.join(biome_dir, f"hex_{biome}_atlas.png")
    pack_atlas(files, atlas_output_path, biome_capitalized)
    print("done")


if __name__ == "__main__":
    main()
