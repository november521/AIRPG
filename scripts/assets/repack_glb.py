#!/usr/bin/env python3
"""Repack a binary glTF for shipping: bake a uniform scale and shrink embedded textures.

Usage:
  python scripts/assets/repack_glb.py --source <in.glb> --output <out.glb> \
      [--scale 0.01] [--texture 2048] [--normal-texture 1024] [--quality 88]

Why this exists next to the Blender builders: models that already ship at a sane
polygon count need no geometry editing, only a unit conversion and a texture
budget. Blender's glTF exporter re-encodes images through its own temporary
directory, which a confined Windows run cannot rely on; this path touches no
temporary files. Geometry is never simplified here.

The scale is baked into the POSITION accessors and their min/max, so the exported
root keeps an identity transform.
"""
import argparse
import json
import struct
import sys
from pathlib import Path

from PIL import Image

JSON_CHUNK = 0x4E4F534A
BIN_CHUNK = 0x004E4942
COMPONENT_FLOAT = 5126


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--scale", type=float, default=1.0)
    parser.add_argument("--texture", type=int, default=2048)
    parser.add_argument("--normal-texture", type=int, default=1024)
    parser.add_argument("--quality", type=int, default=88)
    return parser.parse_args()


def read_glb(path: Path):
    raw = path.read_bytes()
    magic, version, total = struct.unpack_from("<III", raw, 0)
    if magic != 0x46546C67:
        raise SystemExit(f"NOT_A_GLB {path}")
    offset = 12
    gltf = None
    binary = b""
    while offset < total:
        length, kind = struct.unpack_from("<II", raw, offset)
        payload = raw[offset + 8: offset + 8 + length]
        if kind == JSON_CHUNK:
            gltf = json.loads(payload.decode("utf-8"))
        elif kind == BIN_CHUNK:
            binary = payload
        offset += 8 + length
    if gltf is None:
        raise SystemExit("GLB_WITHOUT_JSON")
    return gltf, binary


def write_glb(path: Path, gltf: dict, binary: bytes) -> None:
    payload = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    payload += b" " * ((4 - len(payload) % 4) % 4)
    blob = binary + b"\x00" * ((4 - len(binary) % 4) % 4)
    total = 12 + 8 + len(payload) + (8 + len(blob) if blob else 0)
    out = bytearray()
    out += struct.pack("<III", 0x46546C67, 2, total)
    out += struct.pack("<II", len(payload), JSON_CHUNK) + payload
    if blob:
        out += struct.pack("<II", len(blob), BIN_CHUNK) + blob
    path.write_bytes(bytes(out))


def normal_image_indices(gltf: dict) -> set:
    indices = set()
    for material in gltf.get("materials", []):
        reference = material.get("normalTexture")
        if not reference:
            continue
        texture = gltf["textures"][reference["index"]]
        if "source" in texture:
            indices.add(texture["source"])
    return indices


def position_targets(gltf: dict):
    """(accessor index, bufferView index, byteOffset, component count) for POSITION data."""
    targets = []
    for index, accessor in enumerate(gltf.get("accessors", [])):
        if accessor.get("componentType") != COMPONENT_FLOAT:
            continue
        if accessor.get("type") != "VEC3" or "bufferView" not in accessor:
            continue
        if not accessor.get("_isPosition"):
            continue
        targets.append((index, accessor))
    return targets


def collect_position_accessors(gltf: dict) -> set:
    used = set()
    for mesh in gltf.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            if "POSITION" in primitive.get("attributes", {}):
                used.add(primitive["attributes"]["POSITION"])
    return used


def main() -> None:
    args = parse_args()
    source = Path(args.source)
    target = Path(args.output)
    gltf, binary = read_glb(source)

    image_views = {}
    for index, image in enumerate(gltf.get("images", [])):
        if "bufferView" in image:
            image_views[image["bufferView"]] = index
        # Every embedded image is rewritten as JPEG below; a stale mimeType would
        # make loaders disagree with the bytes.
        if "bufferView" in image:
            image["mimeType"] = "image/jpeg"
            image.pop("uri", None)

    normals = normal_image_indices(gltf)
    positions = collect_position_accessors(gltf)

    views = gltf.get("bufferViews", [])
    new_binary = bytearray()
    report = []
    for view_index, view in enumerate(views):
        start = view.get("byteOffset", 0)
        data = bytearray(binary[start:start + view["byteLength"]])

        if view_index in image_views:
            image_index = image_views[view_index]
            budget = args.normal_texture if image_index in normals else args.texture
            width, height, encoded = reencode(bytes(data), budget, args.quality)
            data = bytearray(encoded)
            report.append(("image", image_index, f"{width}x{height}", len(encoded),
                           "normal" if image_index in normals else "colour"))

        if args.scale != 1.0:
            scale_positions(gltf, views, view_index, data, positions, args.scale)

        while len(new_binary) % 4:
            new_binary.append(0)
        view["byteOffset"] = len(new_binary)
        view["byteLength"] = len(data)
        new_binary += data

    for accessor_index in positions:
        accessor = gltf["accessors"][accessor_index]
        for key in ("min", "max"):
            if key in accessor:
                accessor[key] = [round(value * args.scale, 6) for value in accessor[key]]

    # Sketchfab/FBX assets often keep the mesh origin far from its vertices.
    # Baking a unit conversion into POSITION alone leaves those node offsets
    # unscaled, so the visible mesh lands metres away from its scene root.
    if args.scale != 1.0:
        for node in gltf.get("nodes", []):
            if "translation" in node:
                node["translation"] = [value * args.scale for value in node["translation"]]
            if "matrix" in node:
                for axis in (12, 13, 14):
                    node["matrix"][axis] *= args.scale

    if gltf.get("buffers"):
        gltf["buffers"][0]["byteLength"] = len(new_binary)

    target.parent.mkdir(parents=True, exist_ok=True)
    write_glb(target, gltf, bytes(new_binary))

    print("REPACK_SOURCE", source)
    print("REPACK_TARGET", target)
    print("REPACK_SCALE", args.scale)
    print("REPACK_IMAGES", len(image_views), "NORMAL_MAPS", sorted(normals))
    for kind, index, size, size_bytes, role in report:
        print("REPACK_IMAGE", index, size, f"{size_bytes / 1024:.0f} KiB", role)
    print("REPACK_BIN_BYTES", len(new_binary))
    print("REPACK_TARGET_BYTES", target.stat().st_size)


def scale_positions(gltf, views, view_index, data, positions, scale) -> None:
    for accessor_index in positions:
        accessor = gltf["accessors"][accessor_index]
        if accessor.get("bufferView") != view_index:
            continue
        base = accessor.get("byteOffset", 0)
        stride = views[view_index].get("byteStride") or 12
        for element in range(accessor["count"]):
            offset = base + element * stride
            for axis in range(3):
                at = offset + axis * 4
                value = struct.unpack_from("<f", data, at)[0]
                struct.pack_into("<f", data, at, value * scale)


def reencode(payload: bytes, budget: int, quality: int):
    import io
    image = Image.open(io.BytesIO(payload))
    if image.mode not in ("RGB", "L"):
        image = image.convert("RGB")
    width, height = image.size
    if max(width, height) > budget:
        factor = budget / max(width, height)
        image = image.resize((max(1, round(width * factor)), max(1, round(height * factor))),
                             Image.LANCZOS)
    if image.mode == "L":
        image = image.convert("RGB")
    buffer = io.BytesIO()
    image.save(buffer, format="JPEG", quality=quality, optimize=True)
    return image.size[0], image.size[1], buffer.getvalue()


main()
