"""Render reproducible Town Square environmental-dressing review previews.

The renderer reads placements and texture references directly from TownSquare.tscn.
It composites only production terrain, runtime sprites, and scene contact shadows;
development labels, placeholder polygons, actors, and collision visuals are omitted
from the clean views and represented separately in the clearance overlay.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
import re

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
SCENE_PATH = ROOT / "scenes/world/caden/TownSquare.tscn"
TERRAIN_PREVIEW = ROOT / "docs/art/previews/caden_terrain_runtime_v1_1_town_square_preview.png"
BEFORE_PREVIEW = ROOT / "docs/art/previews/caden_edenite_festival_runtime_v1_town_square_preview.png"
OUTPUT_DIRECTORY = ROOT / "docs/art/previews"

EXT_RESOURCE_RE = re.compile(r'^\[ext_resource .* path="([^"]+)" id="([^"]+)"\]$')
NODE_RE = re.compile(
    r'^\[node name="([^"]+)"(?: type="([^"]+)")?(?: parent="([^"]+)")?(?: instance=.*)?\]$'
)
VECTOR_RE = re.compile(r"Vector2\((-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)\)")
COLOR_RE = re.compile(
    r"Color\((-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?),\s*"
    r"(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)\)"
)


@dataclass
class SceneNode:
    name: str
    node_type: str
    parent: str | None
    full_path: str
    order: int
    properties: dict[str, str] = field(default_factory=dict)


def parse_vector(value: str | None) -> tuple[float, float]:
    if value is None:
        return (0.0, 0.0)
    match = VECTOR_RE.search(value)
    if match is None:
        raise ValueError(f"Unsupported Vector2 value: {value}")
    return (float(match.group(1)), float(match.group(2)))


def parse_color(value: str) -> tuple[int, int, int, int]:
    match = COLOR_RE.search(value)
    if match is None:
        raise ValueError(f"Unsupported Color value: {value}")
    return tuple(round(float(component) * 255) for component in match.groups())


def parse_scene() -> tuple[dict[str, Path], list[SceneNode], dict[str, SceneNode]]:
    text = SCENE_PATH.read_text(encoding="utf-8")
    resources: dict[str, Path] = {}
    nodes: list[SceneNode] = []
    by_path: dict[str, SceneNode] = {}
    current: SceneNode | None = None

    for line in text.splitlines():
        resource_match = EXT_RESOURCE_RE.match(line)
        if resource_match is not None:
            resource_path, resource_id = resource_match.groups()
            if resource_path.startswith("res://"):
                resources[resource_id] = ROOT / resource_path.removeprefix("res://")
            continue

        node_match = NODE_RE.match(line)
        if node_match is not None:
            name, node_type, parent = node_match.groups()
            if parent is None:
                full_path = ""
            elif parent == ".":
                full_path = name
            else:
                full_path = f"{parent}/{name}"
            current = SceneNode(name, node_type or "", parent, full_path, len(nodes))
            nodes.append(current)
            by_path[full_path] = current
            continue

        if current is not None and " = " in line and not line.startswith("["):
            key, value = line.split(" = ", 1)
            current.properties[key] = value

    return resources, nodes, by_path


def global_position(
    node: SceneNode,
    by_path: dict[str, SceneNode],
    cache: dict[str, tuple[float, float]],
) -> tuple[float, float]:
    if node.full_path in cache:
        return cache[node.full_path]
    local_x, local_y = parse_vector(node.properties.get("position"))
    if node.parent is None or node.parent == ".":
        result = (local_x, local_y)
    else:
        parent = by_path[node.parent]
        parent_x, parent_y = global_position(parent, by_path, cache)
        result = (parent_x + local_x, parent_y + local_y)
    cache[node.full_path] = result
    return result


def extract_resource_id(value: str) -> str:
    match = re.search(r'ExtResource\("([^"]+)"\)', value)
    if match is None:
        raise ValueError(f"Unsupported ExtResource value: {value}")
    return match.group(1)


def sprite_frame(image: Image.Image, node: SceneNode) -> Image.Image:
    horizontal_frames = int(node.properties.get("hframes", "1"))
    vertical_frames = int(node.properties.get("vframes", "1"))
    frame = int(node.properties.get("frame", "0"))
    if horizontal_frames == 1 and vertical_frames == 1:
        return image
    frame_width = image.width // horizontal_frames
    frame_height = image.height // vertical_frames
    column = frame % horizontal_frames
    row = frame // horizontal_frames
    return image.crop(
        (
            column * frame_width,
            row * frame_height,
            (column + 1) * frame_width,
            (row + 1) * frame_height,
        )
    )


def polygon_points(value: str) -> list[tuple[float, float]]:
    prefix = "PackedVector2Array("
    if not value.startswith(prefix) or not value.endswith(")"):
        raise ValueError(f"Unsupported polygon value: {value}")
    numbers = [float(item.strip()) for item in value[len(prefix) : -1].split(",")]
    return list(zip(numbers[0::2], numbers[1::2]))


def render_scene() -> Image.Image:
    resources, nodes, by_path = parse_scene()
    preview = Image.open(TERRAIN_PREVIEW).convert("RGBA")
    positions: dict[str, tuple[float, float]] = {}

    for node in nodes:
        if node.properties.get("visible") == "false":
            continue
        if node.node_type == "Polygon2D" and node.name == "ContactShadow":
            node_x, node_y = global_position(node, by_path, positions)
            points = [
                (round(node_x + point_x), round(node_y + point_y))
                for point_x, point_y in polygon_points(node.properties["polygon"])
            ]
            ImageDraw.Draw(preview, "RGBA").polygon(points, fill=parse_color(node.properties["color"]))
            continue
        if node.node_type != "Sprite2D" or "texture" not in node.properties:
            continue

        resource_id = extract_resource_id(node.properties["texture"])
        texture_path = resources[resource_id]
        texture = sprite_frame(Image.open(texture_path).convert("RGBA"), node)
        node_x, node_y = global_position(node, by_path, positions)
        offset_x, offset_y = parse_vector(node.properties.get("offset"))
        top_left = (
            round(node_x + offset_x - texture.width / 2),
            round(node_y + offset_y - texture.height / 2),
        )
        preview.alpha_composite(texture, top_left)

    return preview


def crop_camera_view(scene: Image.Image, left: int, top: int) -> Image.Image:
    return scene.crop((left, top, left + 640, top + 360))


def write_clearance_overlay(scene: Image.Image) -> None:
    overlay = scene.copy()
    draw = ImageDraw.Draw(overlay, "RGBA")

    principal_routes = [
        (0, 288, 224, 416),
        (736, 288, 960, 416),
        (416, 0, 544, 160),
        (416, 544, 544, 704),
    ]
    entry_clearances = [
        (0, 256, 144, 448),
        (816, 256, 960, 448),
        (384, 0, 576, 192),
        (384, 512, 576, 704),
    ]
    approach_clearances = [
        (96, 160, 192, 224),
        (96, 608, 192, 672),
        (784, 256, 880, 320),
        (768, 608, 864, 672),
        (304, 656, 400, 704),
        (240, 400, 336, 496),
        (624, 208, 720, 304),
    ]
    locked_solids = [
        (64, 64, 224, 160),
        (64, 512, 224, 608),
        (768, 160, 896, 256),
        (736, 512, 896, 608),
        (288, 592, 416, 656),
        (608, 96, 928, 128),
        (608, 32, 640, 128),
    ]

    for rectangle in principal_routes:
        draw.rectangle(rectangle, fill=(255, 198, 72, 38), outline=(255, 198, 72, 220), width=2)
    for rectangle in entry_clearances:
        draw.rectangle(rectangle, fill=(80, 195, 255, 24), outline=(80, 195, 255, 190), width=2)
    for rectangle in approach_clearances:
        draw.rectangle(rectangle, fill=(104, 232, 169, 32), outline=(104, 232, 169, 210), width=2)
    for rectangle in locked_solids:
        draw.rectangle(rectangle, outline=(234, 88, 88, 205), width=2)

    reserved = (256, 224, 352, 320)
    draw.rectangle(reserved, fill=(218, 116, 255, 44), outline=(218, 116, 255, 255), width=3)
    draw.text((262, 228), "RESERVED 3x3 - EMPTY", fill=(70, 24, 78, 255))
    draw.text((8, 8), "ORANGE routes | BLUE entries | GREEN approaches | RED solids", fill=(28, 24, 20, 255))
    overlay.save(
        OUTPUT_DIRECTORY / "caden_town_square_environmental_dressing_v1_clearance_overlay.png",
        optimize=False,
    )


def write_before_after(scene: Image.Image) -> None:
    before = Image.open(BEFORE_PREVIEW).convert("RGBA")
    header_height = 30
    comparison = Image.new(
        "RGBA",
        (before.width + scene.width, max(before.height, scene.height) + header_height),
        (38, 34, 30, 255),
    )
    comparison.alpha_composite(before, (0, header_height))
    comparison.alpha_composite(scene, (before.width, header_height))
    draw = ImageDraw.Draw(comparison)
    draw.text((8, 8), "BEFORE - provisional scatter", fill=(245, 235, 210, 255))
    draw.text((before.width + 8, 8), "AFTER - clustered environmental dressing v1", fill=(245, 235, 210, 255))
    comparison.save(
        OUTPUT_DIRECTORY / "caden_town_square_before_vs_after_environmental_dressing.png",
        optimize=False,
    )


def main() -> None:
    OUTPUT_DIRECTORY.mkdir(parents=True, exist_ok=True)
    scene = render_scene()
    views = {
        "center": (160, 172),
        "northwest": (0, 0),
        "northeast": (320, 0),
        "southwest": (0, 344),
        "southeast": (320, 344),
    }
    for name, (left, top) in views.items():
        crop_camera_view(scene, left, top).save(
            OUTPUT_DIRECTORY / f"caden_town_square_environmental_dressing_v1_{name}.png",
            optimize=False,
        )

    closure = scene.crop((576, 32, 896, 192)).resize((640, 320), Image.Resampling.NEAREST)
    closure.save(
        OUTPUT_DIRECTORY / "caden_town_square_environmental_dressing_v1_terrebonne_closure.png",
        optimize=False,
    )
    write_clearance_overlay(scene)
    write_before_after(scene)
    for output in sorted(OUTPUT_DIRECTORY.glob("caden_town_square_*environmental_dressing*.png")):
        print(output.relative_to(ROOT))


if __name__ == "__main__":
    main()
