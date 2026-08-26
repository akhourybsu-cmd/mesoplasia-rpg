#!/usr/bin/env python3
"""Build the Wayfarer pilot visual-approval board from 640x360 captures."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parents[2]
CAPTURES = ROOT / "docs/art/previews/wayfarers_approach/pilot_v1"
OUTPUT = CAPTURES / "wayfarer_pilot_comparison_board_v1.png"


def font(size: int, bold: bool = False) -> ImageFont.ImageFont:
    name = "segoeuib.ttf" if bold else "segoeui.ttf"
    path = Path("C:/Windows/Fonts") / name
    return ImageFont.truetype(str(path), size) if path.exists() else ImageFont.load_default()


def add_capture(board: Image.Image, name: str, label: str, xy: tuple[int, int], size: tuple[int, int]) -> None:
    image = Image.open(CAPTURES / f"{name}.png").convert("RGB")
    fitted = ImageOps.fit(image, (size[0], size[1] - 40), Image.Resampling.NEAREST)
    board.paste(fitted, (xy[0], xy[1] + 40))
    draw = ImageDraw.Draw(board)
    draw.rectangle((xy[0], xy[1], xy[0] + size[0] - 1, xy[1] + size[1] - 1), outline=(88, 96, 91), width=2)
    draw.text((xy[0] + 12, xy[1] + 8), label, fill=(242, 240, 231), font=font(18, True))


def add_depth_pair(
    board: Image.Image,
    behind_name: str,
    front_name: str,
    label: str,
    xy: tuple[int, int],
    size: tuple[int, int],
    centering: tuple[float, float],
) -> None:
    draw = ImageDraw.Draw(board)
    draw.rectangle((xy[0], xy[1], xy[0] + size[0] - 1, xy[1] + size[1] - 1), outline=(88, 96, 91), width=2)
    draw.text((xy[0] + 12, xy[1] + 8), label, fill=(242, 240, 231), font=font(18, True))
    half = (size[0] - 18) // 2
    for index, (name, caption) in enumerate(((behind_name, "Player behind"), (front_name, "Player in front"))):
        image = Image.open(CAPTURES / f"{name}.png").convert("RGB")
        fitted = ImageOps.fit(image, (half, size[1] - 68), Image.Resampling.NEAREST, centering=centering)
        x = xy[0] + 6 + index * (half + 6)
        board.paste(fitted, (x, xy[1] + 42))
        draw.text((x + 8, xy[1] + size[1] - 24), caption, fill=(181, 190, 182), font=font(13, False))


def main() -> int:
    board = Image.new("RGB", (1920, 1080), (21, 24, 23))
    draw = ImageDraw.Draw(board)
    draw.text((40, 24), "Wayfarer limited pilot - two-asset in-engine comparison", fill=(247, 243, 230), font=font(32, True))
    draw.text((40, 65), "05 bench cluster on grass; 07 hitching rail near the traveler yard. Existing geometry remains authoritative.", fill=(181, 190, 182), font=font(17))
    panel_size = (584, 438)
    columns = (40, 668, 1296)
    add_capture(board, "grass_before_640x360", "Grass area - before", (columns[0], 112), panel_size)
    add_capture(board, "grass_after_640x360", "Grass area - pilot", (columns[1], 112), panel_size)
    add_depth_pair(board, "bench_player_behind_640x360", "bench_player_front_640x360", "05 depth sorting", (columns[2], 112), panel_size, (0.72, 0.78))
    add_capture(board, "road_before_640x360", "Road-adjacent area - before", (columns[0], 594), panel_size)
    add_capture(board, "road_after_640x360", "Road-adjacent area - pilot", (columns[1], 594), panel_size)
    add_depth_pair(board, "rail_player_behind_640x360", "rail_player_front_640x360", "07 depth sorting", (columns[2], 594), panel_size, (0.56, 0.78))
    board.save(OUTPUT, compress_level=9)
    print(f"comparison={OUTPUT.relative_to(ROOT).as_posix()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
