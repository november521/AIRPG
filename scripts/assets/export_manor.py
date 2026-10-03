"""Export the delivered manor art scene into the game-ready GLB.

Usage (PowerShell 7, Blender 5.2 LTS):

    & "D:\\SteamLibrary\\steamapps\\common\\Blender\\blender.exe" -b --factory-startup `
        --python scripts/assets/export_manor.py -- `
        --source "output/manor_v4/manor_repaired_v4.blend" `
        --target game/presentation/manor/manor.glb `
        --report output/manor_v4/export_report.json

The delivered .blend is read-only input: this script unhides the presentation collections in
memory, adds the walk-collision objects, exports one GLB and never saves the .blend. Coordinate
mapping is unchanged from the earlier structure export: Blender (x, y, z) -> Godot (x, z, -y).

Game contract kept by this export (ADR 0008 and docs/manor-model-import.md):
- the ten `MS_*_Hinge` door roots and their `*_SolidTimberLeaf` children stay in the GLB,
- door handles reach neither the visuals nor the walk mesh,
- one `ManorWalkCollision-colonly` holds the walk mesh,
- the removable floorboards keep their own `-colonly` body so a future pry interaction can free
  the visual root and its collision together.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import bpy
from mathutils import Vector

# Presentation collections. Roof, ceilings and upper walls belong to the exported model; the
# .blend only hides them for its own cutaway overview camera.
VISUAL_COLLECTIONS = (
    "MS_01_Floors", "MS_02_Walls_Lower", "MS_03_Walls_Upper", "MS_04_Doors", "MS_05_Windows",
    "MS_06_Porch", "MS_07_Roof", "MS_08_Ceilings", "MS_09_Cellar", "MS_10_Site",
    "Furniture", "Props", "V3_Architecture", "V3_UpperDecor", "V3_Exterior",
    "V4_EmptyCellar", "V4_ConcealedEntrance",
)
# Artist lighting, cameras, plan annotation, roof sources and review-only rigs never reach the
# game scene: the walk scene owns its own lights.
EXCLUDED_COLLECTIONS = ("MS_11_Lights_Cameras", "MS_12_Plan_Labels", "MS_13_Roof_Source",
                        "V3_Cameras", "V3_Lighting", "V4_Collision_Optional", "Collection")
# Walk collision comes from structure only: furniture, props and wall dressing must not block.
COLLISION_COLLECTIONS = ("MS_01_Floors", "MS_02_Walls_Lower", "MS_03_Walls_Upper", "MS_04_Doors",
                         "MS_05_Windows", "MS_06_Porch", "MS_08_Ceilings", "MS_09_Cellar",
                         "MS_10_Site", "V4_EmptyCellar")
# Detailed treads and board faces stay visible while the walk mesh uses continuous ramps and the
# subfloor, exactly like the earlier structure export.
COLLISION_SKIP_TOKENS = ("Cellar_Tread_", "SideEntry_StoneStep_", "Entry_StoneStep_", "Threshold",
                         "_Boards", "_BrassHandle")
CELLAR_STAIR_VISUAL = "V4_Cellar_Stair"
CELLAR_RAMP = "V4_CellarRamp-colonly"
PRY_ROOT = "V4_PryFloorboards"
PRY_COLLISION = "V4_PryFloorCollision"
# Side entry and front veranda keep the hand-built ramps the walk scene has always used. The
# cellar ramp is taken from the delivered blend instead, because V4 moved and deepened the cellar.
WALK_RAMPS = (
    ((-7.36, 0.99, -0.46), (-6.40, 0.99, 0.0), (-6.40, 2.29, 0.0), (-7.36, 2.29, -0.46)),
    ((4.32, -8.80, -0.46), (6.48, -8.80, -0.46), (6.48, -7.80, 0.02), (4.32, -7.80, 0.02)),
)
HINGES = ("MS_SideEntry_Hinge", "MS_MainEntry_Hinge", "MS_Bathroom_Door_Hinge",
          "MS_DoctorBedroom_Door_Hinge", "MS_DoctorStudy_Door_Hinge", "MS_EmiliaBedroom_Door_Hinge",
          "MS_EmiliaStudy_Door_Hinge", "MS_Kitchen_Door_Hinge", "MS_Reception_Door_Hinge",
          "MS_Reception_Kitchen_Door_Hinge")
COLLISION_NAME = "ManorWalkCollision"
FLOOR_KEYS = ("V4_Cellar_Floor", "MS_Cellar_Floor")


def _options() -> argparse.Namespace:
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--target", required=True)
    parser.add_argument("--report", default="")
    parser.add_argument("--keep-modifiers", action="store_true",
                        help="Skip modifier evaluation; the export keeps base meshes only.")
    return parser.parse_args(raw)


def _collect() -> list:
    scene = bpy.context.scene
    known = {collection.name for collection in scene.collection.children}
    required = [name for name in VISUAL_COLLECTIONS if name in known]
    missing = [name for name in ("MS_01_Floors", "MS_04_Doors", "Furniture", "Props")
               if name not in known]
    if missing:
        raise RuntimeError("MANOR_COLLECTION_MISSING: %s" % ", ".join(missing))
    for name in EXCLUDED_COLLECTIONS:
        collection = bpy.data.collections.get(name)
        if collection is not None:
            collection.hide_viewport = True
            collection.hide_render = True
    selected = []
    for name in required:
        collection = bpy.data.collections[name]
        collection.hide_viewport = False
        collection.hide_render = False
        for item in collection.objects:
            if item.type not in {"MESH", "CURVE", "EMPTY"}:
                continue
            if "_BrassHandle" in item.name:
                continue
            item["manor_collection"] = name
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
        if not any(child.name.endswith("_SolidTimberLeaf") for child in hinge.children_recursive):
            problems.append("%s has no leaf" % hinge_name)
    if problems:
        raise RuntimeError("MANOR_DOOR_BINDING_MISSING: %s" % "; ".join(problems))
    return list(HINGES)


def _triangles(objects, depsgraph, skip=()):
    verts, faces = [], []
    for item in objects:
        if item.type != "MESH" or item.name in skip:
            continue
        evaluated = item.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        mesh.calc_loop_triangles()
        offset = len(verts)
        verts.extend(tuple(item.matrix_world @ vertex.co) for vertex in mesh.vertices)
        faces.extend(tuple(offset + index for index in triangle.vertices)
                     for triangle in mesh.loop_triangles)
        evaluated.to_mesh_clear()
    return verts, faces


def _pry_objects() -> list:
    root = bpy.data.objects.get(PRY_ROOT)
    if root is None:
        return []
    return [item for item in [root] + list(root.children_recursive) if item.type == "MESH"]


def _world_bounds(objects):
    low = [1e9, 1e9, 1e9]
    high = [-1e9, -1e9, -1e9]
    for item in objects:
        for corner in item.bound_box:
            point = item.matrix_world @ Vector(corner)
            for axis in range(3):
                low[axis] = min(low[axis], point[axis])
                high[axis] = max(high[axis], point[axis])
    return low, high


def _link_collision(mesh, name: str):
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def _build_walk_collision(depsgraph, pry: list):
    sources = []
    for name in COLLISION_COLLECTIONS:
        collection = bpy.data.collections.get(name)
        if collection is None:
            continue
        for item in collection.objects:
            if item.type != "MESH" or item.name == CELLAR_STAIR_VISUAL:
                continue
            if any(token in item.name for token in COLLISION_SKIP_TOKENS):
                continue
            sources.append(item)
    verts, faces = _triangles(sources, depsgraph)
    optional = bpy.data.collections.get("V4_Collision_Optional")
    if optional is not None:
        optional.hide_viewport = False
        bpy.context.view_layer.update()
    ramp = bpy.data.objects.get(CELLAR_RAMP)
    if ramp is None:
        raise RuntimeError("MANOR_CELLAR_RAMP_MISSING: %s" % CELLAR_RAMP)
    ramp_verts, ramp_faces = _triangles([ramp], depsgraph)
    offset = len(verts)
    verts.extend(ramp_verts)
    faces.extend(tuple(index + offset for index in face) for face in ramp_faces)
    for walk_ramp in WALK_RAMPS:
        offset = len(verts)
        verts.extend(walk_ramp)
        faces.append((offset, offset + 1, offset + 2))
        faces.append((offset, offset + 2, offset + 3))
    mesh = bpy.data.meshes.new(COLLISION_NAME)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    walk = _link_collision(mesh, COLLISION_NAME + "-colonly")

    # Removable boards keep their own collision body: the pry interaction frees this one together
    # with the visual root, which opens the hole left in the walk mesh above.
    boards = None
    if pry:
        low, high = _world_bounds(pry)
        box_verts = [(low[0], low[1], low[2]), (high[0], low[1], low[2]), (high[0], high[1], low[2]),
                     (low[0], high[1], low[2]), (low[0], low[1], high[2]), (high[0], low[1], high[2]),
                     (high[0], high[1], high[2]), (low[0], high[1], high[2])]
        box_faces = [(0, 2, 1), (0, 3, 2), (4, 5, 6), (4, 6, 7), (0, 1, 5), (0, 5, 4),
                     (1, 2, 6), (1, 6, 5), (2, 3, 7), (2, 7, 6), (3, 0, 4), (3, 4, 7)]
        board_mesh = bpy.data.meshes.new(PRY_COLLISION)
        board_mesh.from_pydata(box_verts, [], box_faces)
        board_mesh.update()
        boards = _link_collision(board_mesh, PRY_COLLISION + "-colonly")
    return walk, boards, len(sources), len(faces)


def main() -> None:
    options = _options()
    source = Path(options.source).resolve()
    target = Path(options.target).resolve()
    if not source.is_file():
        raise RuntimeError("MANOR_SOURCE_MISSING: %s" % source)
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    bpy.ops.wm.open_mainfile(filepath=str(source))
    print("MANOR_SOURCE scene=%s objects=%d" % (bpy.context.scene.name, len(bpy.context.scene.objects)))

    exported = _collect()
    _validate_doors()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    pry = _pry_objects()
    walk, boards, collision_sources, collision_triangles = _build_walk_collision(depsgraph, pry)

    for item in exported:
        item.select_set(True)
    walk.select_set(True)
    if boards is not None:
        boards.select_set(True)
    bpy.context.view_layer.objects.active = walk
    target.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(target), export_format="GLB", use_selection=True, use_active_scene=True,
        export_apply=not options.keep_modifiers, export_extras=True, export_animations=False,
        export_cameras=False, export_lights=False, export_texcoords=True, export_normals=True,
        export_yup=True)
    if hashlib.sha256(source.read_bytes()).hexdigest() != digest:
        raise RuntimeError("MANOR_SOURCE_CHANGED")

    floor = bpy.data.objects.get(FLOOR_KEYS[0]) or bpy.data.objects.get(FLOOR_KEYS[1])
    cellar = None
    if floor is not None:
        low, high = _world_bounds([floor])
        # Blender (x, y, z) -> Godot (x, z, -y)
        cellar = {"godot_min": [round(low[0], 3), round(low[2], 3), round(-high[1], 3)],
                  "godot_max": [round(high[0], 3), round(high[2], 3), round(-low[1], 3)]}
    report = {
        "source": str(source), "source_sha256": digest, "target": str(target),
        "target_bytes": target.stat().st_size,
        "blender": bpy.app.version_string,
        "scene": bpy.context.scene.name,
        "visual_objects": len(exported), "meshes": len([o for o in exported if o.type == "MESH"]),
        "modifiers_applied": not options.keep_modifiers,
        "collections": list(VISUAL_COLLECTIONS),
        "collision_collections": list(COLLISION_COLLECTIONS),
        "collision_objects": collision_sources, "collision_triangles": collision_triangles,
        "walk_ramps": len(WALK_RAMPS) + 1, "cellar_ramp": CELLAR_RAMP,
        "pry_root": PRY_ROOT if pry else "",
        "pry_boards": len(pry), "pry_collision": PRY_COLLISION if boards is not None else "",
        "door_hinges": list(HINGES), "excluded_collections": list(EXCLUDED_COLLECTIONS),
        "cellar_floor_godot": cellar,
        "coordinate_mapping": "Blender (x,y,z) -> Godot (x,z,-y)",
        "source_saved": False,
    }
    if options.report:
        path = Path(options.report).resolve()
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    print("MANOR_EXPORT_READY objects=%d collision_triangles=%d pry=%d bytes=%d"
          % (len(exported), collision_triangles, len(pry), report["target_bytes"]))
    if cellar:
        print("MANOR_CELLAR_GODOT min=%s max=%s" % (cellar["godot_min"], cellar["godot_max"]))


main()
