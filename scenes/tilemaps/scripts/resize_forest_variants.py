"""
Resize Hex_Forest_*.png variants to match the project tile grid size
while preserving crisp color bands via RGB palette quantization.

The LANCZOS downscale alone produces too much color blending at the
output resolution (source art is ~3x larger than target), making small
details look muddy. Post-resize palette quantization restores the
crisp "painted" look of the original art by reducing the RGB channels
to a limited color count while keeping the alpha channel smooth for
anti-aliased edges.

Run from the worktree root:

    py scenes/tilemaps/scripts/resize_forest_variants.py

Processes every Hex_Forest_*.png in assets/sprites/tilemap/ in place
and skips files that are already at the target size (safe to re-run
after importing new variants).
"""

from PIL import Image
import os
import glob

# --- Configuration ---

ASSET_DIR = "assets/sprites/tilemap"

# Output PNG bounds. Match the project TileSet.tile_size exactly so the
# new art drops into the grid at the same effective size as the
# existing tile_horizontal.png.
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
# 32 is a good starting point for detailed forest art.
PALETTE_COLORS = 32


# --- Implementation ---

def resize_and_quantize(path: str) -> None:
    """Resize one Hex_Forest variant to the target tile dimensions with
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


def main() -> None:
    # Recursive glob — picks up Hex_Forest_*.png both directly under
    # ASSET_DIR and in nested subdirectories like hex_tiles/forest/.
    pattern = os.path.join(ASSET_DIR, "**", "Hex_Forest_*.png")
    files = sorted(glob.glob(pattern, recursive=True))
    print(f"Found {len(files)} Hex_Forest file(s)")
    for f in files:
        resize_and_quantize(f)
    print("done")


if __name__ == "__main__":
    main()
