"""Export the delivered V3 manor art scene into the game GLB.

Usage (PowerShell 7, Blender 5.2 LTS):

    & "D:\\SteamLibrary\\steamapps\\common\\Blender\\blender.exe" -b --factory-startup `
        --python scripts/assets/export_manor_v3.py -- `
        --source "C:\\Users\\<user>\\Downloads\\死光庄园_完整建模包_V3_20261003\\manor_v3\\manor_furnished_v3.blend" `
        --target game/presentation/manor/manor.glb `
        --report output/manor_v3/export_report.json

The delivered .blend is read-only input: this script unhides the presentation collections in
memory, adds one walk-collision object, exports one GLB and never saves the .blend.
Coordinate mapping is unchanged from the earlier structure export: Blender (x, y, z) -> Godot
(x, z, -y). Door handles stay out of both visuals and the walk mesh, as the scoped-interaction
ADR requires. See docs/manor-v3-import.md for provenance and known limits.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import bpy

# Presentation collections of the delivered package. Roof, ceilings and upper walls are part of
# the exported model; the .blend only hides them for its own cutaway overview camera.
VISUAL_COLLECTIONS = (
    "MS_01_Floors", "MS_02_Walls_Lower", "MS_03_Walls_Upper", "MS_04_Doors", "MS_05_Windows",
    "MS_06_Porch", "MS_07_Roof", "MS_08_Ceilings", "MS_09_Cellar", "MS_10_Site",
    "Furniture", "Props", "V3_Architecture", "V3_UpperDecor", "V3_Exterior",
)
# Artist lighting, cameras and plan annotation never enter the game scene: the walk scene owns
# its own lights, and roof-source meshes duplicate MS_07_Roof.
EXCLUDED_COLLECTIONS = ("MS_11_Lights_Cameras", "MS_12_Plan_Labels", "MS_13_Roof_Source",
                        "V3_Cameras", "V3_Lighting", "Collection")
# Walk collision comes from structure only: furniture, props and wall dressing must not block.
COLLISION_COLLECTIONS = ("MS_01_Floors", "MS_02_Walls_Lower", "MS_03_Walls_Upper", "MS_04_Doors",
                         "MS_05_Windows", "MS_06_Porch", "MS_08_Ceilings", "MS_09_Cellar",
                         "MS_10_Site")
# Detailed treads stay visible while the walk mesh uses three continuous ramps (same ramps as the
# earlier structure export; V3 keeps the shell geometry).
COLLISION_SKIP_TOKENS = ("Cellar_Tread_", "SideEntry_StoneStep_", "Entry_StoneStep_", "Threshold",
                         "_Boards", "_BrassHandle")
WALK_RAMPS = (
    ((-7.36, 0.99, -0.46), (-6.40, 0.99, 0.0), (-6.40, 2.29, 0.0), (-7.36, 2.29, -0.46)),
    ((-5.78, 9.08, 0.0), (-4.62, 9.08, 0.0), (-4.62, 12.44, -2.72), (-5.78, 12.44, -2.72)),
    ((4.32, -8.80, -0.46), (6.48, -8.80, -0.46), (6.48, -7.80, 0.02), (4.32, -7.80, 0.02)),
)
HINGES = ("MS_SideEntry_Hinge", "MS_MainEntry_Hinge", "MS_Bathroom_Door_Hinge",
          "MS_DoctorBedroom_Door_Hinge", "MS_DoctorStudy_Door_Hinge", "MS_EmiliaBedroom_Door_Hinge",
          "MS_EmiliaStudy_Door_Hinge", "MS_Kitchen_Door_Hinge", "MS_Reception_Door_Hinge",
          "MS_Reception_Kitchen_Door_Hinge")
COLLISION_NAME = "ManorWalkCollision"


def _options() -> argparse.Namespace:
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--target", required=True)
    parser.add_argument("--report", default="")
    parser.add_argument("--keep-modifiers", action="store_true",
                        help="Skip modifier evaluation; the export keeps base meshes only.")
    return parser.parse_args(raw)


def _classify() -> list:
    scene = bpy.context.scene
    known = {collection.name for collection in scene.collection.children}
    missing = [name for name in VISUAL_COLLECTIONS if name not in known]
    if missing:
        raise RuntimeError("V3_COLLECTION_MISSING: %s" % ", ".join(missing))
    for name in EXCLUDED_COLLECTIONS:
        collection = bpy.data.collections.get(name)
        if collection is not None:
            collection.hide_viewport = True
            collection.hide_render = True
    selected = []
    for name in VISUAL_COLLECTIONS:
        collection = bpy.data.collections[name]
        collection.hide_viewport = False
        collection.hide_render = False
        for item in collection.objects:
            if item.type not in {"MESH", "CURVE", "EMPTY"}:
                continue
            if "_BrassHandle" in item.name:
                continue
            item["manor_v3_collection"] = name
            item.hide_set(False)
            selected.append(item)
    bpy.context.view_layer.update()
    return selected


def _validate_doors() -> list:
    problems = []
    for hinge_name in HINGES:
        hinge = bpy.data.objects.get(hinge_name)
        if hinge is None:
            problems.append("%s missing" % hinge_name)
            continue
        leaf = next((child for child in hinge.children_recursive
                     if child.name.endswith("_SolidTimberLeaf")), None)
        if leaf is None:
            problems.append("%s has no leaf" % hinge_name)
    if problems:
        raise RuntimeError("MANOR_DOOR_BINDING_MISSING: %s" % "; ".join(problems))
    return list(HINGES)


def _mesh_arrays(objects, depsgraph):
    verts, faces = [], []
    triangles = 0
    for item in objects:
        if item.type != "MESH":
            continue
        evaluated = item.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        mesh.calc_loop_triangles()
        offset = len(verts)
        verts.extend(tuple(item.matrix_world @ vertex.co) for vertex in mesh.vertices)
        faces.extend(tuple(offset + index for index in triangle.vertices)
                     for triangle in mesh.loop_triangles)
        triangles += len(mesh.loop_triangles)
        evaluated.to_mesh_clear()
    return verts, faces, triangles


def _build_collision(depsgraph):
    sources = []
    for name in COLLISION_COLLECTIONS:
        for item in bpy.data.collections[name].objects:
            if item.type != "MESH":
                continue
            if any(token in item.name for token in COLLISION_SKIP_TOKENS):
                continue
            sources.append(item)
    verts, faces, _ = _mesh_arrays(sources, depsgraph)
    for ramp in WALK_RAMPS:
        offset = len(verts)
        verts.extend(ramp)
        faces.append((offset, offset + 1, offset + 2))
        faces.append((offset, offset + 2, offset + 3))
    mesh = bpy.data.meshes.new(COLLISION_NAME)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    collision = bpy.data.objects.new(COLLISION_NAME + "-colonly", mesh)
    bpy.context.scene.collection.objects.link(collision)
    return collision, sources, len(faces)


def main() -> None:
    options = _options()
    source = Path(options.source).resolve()
    target = Path(options.target).resolve()
    if not source.is_file():
        raise RuntimeError("V3_SOURCE_MISSING: %s" % source)
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    bpy.ops.wm.open_mainfile(filepath=str(source))
    print("MANOR_V3_SOURCE scene=%s objects=%d" % (bpy.context.scene.name, len(bpy.context.scene.objects)))

    exported = _classify()
    _validate_doors()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    collision, collision_sources, collision_triangles = _build_collision(depsgraph)

    for item in exported:
        item.select_set(True)
    collision.select_set(True)
    bpy.context.view_layer.objects.active = collision
    target.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(target), export_format="GLB", use_selection=True, use_active_scene=True,
        export_apply=not options.keep_modifiers, export_extras=True, export_animations=False,
        export_cameras=False, export_lights=False, export_texcoords=True, export_normals=True,
        export_yup=True)
    if hashlib.sha256(source.read_bytes()).hexdigest() != digest:
        raise RuntimeError("MANOR_V3_SOURCE_CHANGED")

    report = {
        "source": str(source), "source_sha256": digest, "target": str(target),
        "target_bytes": target.stat().st_size,
        "blender": bpy.app.version_string,
        "scene": bpy.context.scene.name,
        "visual_objects": len(exported), "meshes": len([o for o in exported if o.type == "MESH"]),
        "modifiers_applied": not options.keep_modifiers,
        "collision_objects": len(collision_sources), "collision_triangles": collision_triangles,
        "walk_ramps": len(WALK_RAMPS), "door_hinges": list(HINGES),
        "excluded_collections": list(EXCLUDED_COLLECTIONS),
        "coordinate_mapping": "Blender (x,y,z) -> Godot (x,z,-y)",
        "source_saved": False,
    }
    if options.report:
        path = Path(options.report).resolve()
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    print("MANOR_V3_EXPORT_READY objects=%d collision_triangles=%d bytes=%d"
          % (len(exported), collision_triangles, report["target_bytes"]))


main()
