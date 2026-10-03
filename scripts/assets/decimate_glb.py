"""Geometry-only pass for imported props: weld the block seams, then decimate.

Usage:
  blender -b --factory-startup --python scripts/assets/decimate_glb.py -- \
      --source "<in.glb>" --output "game/items/models/<id>.glb" [--triangles 15000]

This is the first of the two asset passes. It only touches geometry, so the glTF
exporter never re-encodes an image and never needs a writable temporary directory
(the confined Windows run cannot rely on one). Textures are handled afterwards by
`repack_glb.py`, which scales, re-encodes and fixes mimeType in pure Python.

Welding is not optional. Sketchfab's own exporter splits meshes at the 16-bit
index limit (65532 vertices), so a joined import carries a duplicate ring of
vertices at every seam; collapse decimation cannot cross those seams and sheds
the surface instead. Observed on the silver urn (542967 -> 10076 vertices) and
the copper wire coil (82417 -> 7500).

Proven uses:
  copper wire coil   --triangles 15000   (144000 -> 15000, 21.99 MiB -> 1.20 MiB)
  fuse               --triangles 4000    (126296 -> 4000,  6.63 MiB -> 0.27 MiB)
"""
import argparse
import sys
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[2]


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--triangles", type=int, default=15000)
    parser.add_argument("--weld", type=float, default=0.0002)
    parser.add_argument("--smooth", default="yes", choices=("yes", "no"))
    return parser.parse_args(argv)


def local_size(obj) -> tuple:
    from mathutils import Vector
    corners = [Vector(corner) for corner in obj.bound_box]
    lo = Vector((min(c[i] for c in corners) for i in range(3)))
    hi = Vector((max(c[i] for c in corners) for i in range(3)))
    return tuple(round(v, 6) for v in (hi - lo))


def main() -> None:
    args = parse_args()
    source = Path(args.source).resolve()
    if not source.is_file():
        raise SystemExit(f"SOURCE_MISSING {source}")
    target = Path(args.output)
    if not target.is_absolute():
        target = ROOT / target

    bpy.ops.wm.read_factory_settings(use_empty=True)
    scratch = ROOT / "artifacts/blender-tmp"
    scratch.mkdir(parents=True, exist_ok=True)
    bpy.context.preferences.filepaths.temporary_directory = str(scratch)
    bpy.ops.import_scene.gltf(filepath=str(source))

    meshes = [item for item in bpy.data.objects if item.type == "MESH"]
    if not meshes:
        raise SystemExit("SOURCE_HAS_NO_MESH")
    imported_tris = 0
    for item in meshes:
        item.data.calc_loop_triangles()
        imported_tris += len(item.data.loop_triangles)

    bpy.ops.object.select_all(action="DESELECT")
    for item in meshes:
        item.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.object

    before_verts = len(obj.data.vertices)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=args.weld)
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.data.calc_loop_triangles()
    welded_tris = len(obj.data.loop_triangles)

    size_before = local_size(obj)
    ratio = min(1.0, args.triangles / max(welded_tris, 1))
    decimate = obj.modifiers.new("PropDecimate", "DECIMATE")
    decimate.decimate_type = "COLLAPSE"
    decimate.ratio = ratio
    decimate.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=decimate.name)

    obj.data.calc_loop_triangles()
    final_tris = len(obj.data.loop_triangles)

    if args.smooth == "yes":
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.faces_shade_smooth()
        bpy.ops.object.mode_set(mode="OBJECT")

    target.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(
        filepath=str(target),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_animations=False,
        export_image_format="AUTO",
        export_yup=True,
    )

    print("DECIMATE_IMPORTED_TRIS", imported_tris)
    print("DECIMATE_WELD", before_verts, "->", len(obj.data.vertices), "verts; welded tris", welded_tris)
    print("DECIMATE_FINAL_TRIS", final_tris, "RATIO", round(ratio, 5))
    print("DECIMATE_SIZE_BEFORE", size_before, "AFTER", local_size(obj))
    print("DECIMATE_TARGET_BYTES", target.stat().st_size)


main()
