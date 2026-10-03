"""Build a distributable NPC preview from original procedural geometry.

Usage: blender -b -t 2 --python scripts/assets/build_npc_public.py
This is an engineering placeholder, not an authorized story character.
"""
from pathlib import Path
import math
import bpy
from mathutils import Vector, Quaternion

ROOT = Path(__file__).resolve().parents[2]
TARGET = ROOT / "game/presentation/manor/npc_preview_public.glb"

bpy.ops.wm.read_factory_settings(use_empty=True)

def material(name, color):
    item = bpy.data.materials.new(name)
    item.diffuse_color = (*color, 1)
    item.use_nodes = True
    node = item.node_tree.nodes.get("Principled BSDF")
    node.inputs["Base Color"].default_value = (*color, 1)
    node.inputs["Roughness"].default_value = 0.88
    return item

coat = material("PreviewCoat", (0.085, 0.14, 0.17))
pants = material("PreviewTrousers", (0.085, 0.09, 0.11))
shoes = material("PreviewShoes", (0.035, 0.032, 0.029))
skin = material("PreviewSkin", (0.61, 0.45, 0.34))
hat = material("PreviewHat", (0.052, 0.055, 0.052))
pieces = []

def ellipsoid(name, center, size, surface):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(surface)
    pieces.append(obj)

def segment(name, start, end, radius, surface):
    a, b = Vector(start), Vector(end)
    bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=radius, radius2=radius,
                                   depth=(b-a).length, location=(a+b)*0.5)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = (b-a).to_track_quat("Z", "Y").to_euler()
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    obj.data.materials.append(surface)
    pieces.append(obj)

ellipsoid("CoatBody", (0, 0, 1.12), (.27, .18, .36), coat)
ellipsoid("CoatHips", (0, 0, .85), (.25, .17, .14), coat)
ellipsoid("Face", (0, -.025, 1.64), (.145, .13, .17), skin)
segment("Neck", (0, 0, 1.43), (0, 0, 1.55), .075, skin)
segment("HatCrown", (0, 0, 1.78), (0, 0, 1.87), .135, hat)
ellipsoid("HatBrim", (0, 0, 1.76), (.22, .19, .025), hat)
for side, sign in (("L", 1), ("R", -1)):
    segment("SleeveUpper."+side, (sign*.19, 0, 1.40), (sign*.43, 0, 1.17), .09, coat)
    segment("SleeveLower."+side, (sign*.43, 0, 1.17), (sign*.64, 0, .96), .075, coat)
    ellipsoid("Hand."+side, (sign*.69, 0, .91), (.055, .05, .075), skin)
    segment("TrouserUpper."+side, (sign*.11, 0, .83), (sign*.14, 0, .47), .105, pants)
    segment("TrouserLower."+side, (sign*.14, 0, .47), (sign*.13, 0, .13), .082, pants)
    ellipsoid("Shoe."+side, (sign*.13, -.04, .08), (.105, .17, .07), shoes)

bpy.ops.object.select_all(action="DESELECT")
for obj in pieces:
    obj.select_set(True)
bpy.context.view_layer.objects.active = pieces[0]
bpy.ops.object.join()
mesh = bpy.context.object
mesh.name = "PreviewBody"
mesh.data.name = "PreviewBodyMesh"

armature_data = bpy.data.armatures.new("PreviewHumanoidRig")
armature = bpy.data.objects.new("PreviewHumanoid", armature_data)
bpy.context.collection.objects.link(armature)
bpy.context.view_layer.objects.active = armature
armature.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")

def bone(name, head, tail, parent=None, connected=False):
    item = armature_data.edit_bones.new(name)
    item.head, item.tail = head, tail
    if parent:
        item.parent = armature_data.edit_bones[parent]
        item.use_connect = connected
    return item

bone("Hips", (0, 0, 0.83), (0, 0, 0.96))
bone("Spine", (0, 0, 0.96), (0, 0, 1.25), "Hips", True)
bone("Chest", (0, 0, 1.25), (0, 0, 1.43), "Spine", True)
bone("Neck", (0, 0, 1.43), (0, 0, 1.54), "Chest", True)
bone("Head", (0, 0, 1.54), (0, 0, 1.72), "Neck", True)
for side, sign in (("L", 1), ("R", -1)):
    bone(f"UpperArm.{side}", (sign*.19, 0, 1.40), (sign*.43, 0, 1.17), "Chest")
    bone(f"Forearm.{side}", (sign*.43, 0, 1.17), (sign*.64, 0, .96), f"UpperArm.{side}", True)
    bone(f"Hand.{side}", (sign*.64, 0, .96), (sign*.72, 0, .89), f"Forearm.{side}", True)
    bone(f"Thigh.{side}", (sign*.11, 0, .83), (sign*.14, 0, .47), "Hips")
    bone(f"Shin.{side}", (sign*.14, 0, .47), (sign*.13, 0, .14), f"Thigh.{side}", True)
    bone(f"Foot.{side}", (sign*.13, 0, .14), (sign*.13, -.12, .06), f"Shin.{side}", True)
bpy.ops.object.mode_set(mode="OBJECT")

# Envelope weights are deterministic and avoid heat-weight failures on disconnected GLB parts.
from mathutils.geometry import intersect_point_line
segments = {}
for item in armature.data.bones:
    segments[item.name] = (item.head_local.copy(), item.tail_local.copy())
groups = {name: mesh.vertex_groups.new(name=name) for name in segments}
for vertex in mesh.data.vertices:
    point = vertex.co
    candidates = []
    for name, (head, tail) in segments.items():
        closest, t = intersect_point_line(point, head, tail)
        closest = head + (tail-head)*min(1.0,max(0.0,t))
        distance = (point-closest).length
        if name == "Hips" and point.z > 1.05:
            distance += .3
        candidates.append((distance,name))
    candidates.sort()
    nearest = candidates[:3]
    values = [(name, 1.0 / (distance + .035)**4) for distance,name in nearest]
    total = sum(value for _,value in values)
    for name,value in values:
        weight = value / total
        if weight > .01:
            groups[name].add([vertex.index],weight,"REPLACE")
modifier = mesh.modifiers.new("PreviewSkin", "ARMATURE")
modifier.object = armature
mesh.parent = armature

armature.animation_data_create()
pose = armature.pose.bones
for item in pose:
    item.rotation_mode = "XYZ"

def clip(name, frames):
    action = bpy.data.actions.new(name)
    armature.animation_data.action = action
    for frame, moves in frames:
        for item in pose:
            item.rotation_euler = (0, 0, 0)
            item.location = (0, 0, 0)
            item.scale = (1, 1, 1)
        for bone_name, channels in moves.items():
            item = pose[bone_name]
            if "rotation" in channels:
                item.rotation_euler = channels["rotation"]
            if "location" in channels:
                item.location = channels["location"]
        # Relax the imported A-pose in every clip, then add alternating gait.
        for side, sign in (("L", 1), ("R", -1)):
            name = f"UpperArm.{side}"
            basis = armature.data.bones[name].matrix_local.to_quaternion()
            shoulder = Quaternion((0, 1, 0), sign * .55)
            gait = Quaternion((1, 0, 0), moves.get(name, {}).get("swing", 0))
            pose[name].rotation_euler = (basis.inverted() @ (gait @ shoulder) @ basis).to_euler("XYZ")
        for item in pose:
            item.keyframe_insert(data_path="rotation_euler",frame=frame,group=item.name)
            item.keyframe_insert(data_path="location",frame=frame,group=item.name)
    return action

clip("idle", [(1,{"Chest":{"rotation":(-.015,0,0)}}),
              (31,{"Chest":{"rotation":(.015,0,0)}}),
              (61,{"Chest":{"rotation":(-.015,0,0)}})])
walk_frames=[]
for frame,phase in ((1,0),(9,math.pi/2),(17,math.pi),(25,3*math.pi/2),(33,2*math.pi)):
    swing=math.sin(phase)
    lift=abs(swing)*.018
    walk_frames.append((frame,{
        "Hips":{"location":(0,0,lift)},
        "Chest":{"rotation":(.025*swing,0,.025*swing)},
        "Thigh.L":{"rotation":(.36*swing,0,0)},
        "Thigh.R":{"rotation":(-.36*swing,0,0)},
        "Shin.L":{"rotation":(-.20*max(0,-swing),0,0)},
        "Shin.R":{"rotation":(-.20*max(0,swing),0,0)},
        "UpperArm.L":{"swing":-.22*swing},
        "UpperArm.R":{"swing":.22*swing},
    }))
clip("walk",walk_frames)
clip("talk",[(1,{}),(14,{"Head":{"rotation":(.08,0,-.06)},"Forearm.L":{"rotation":(-.25,0,.12)}}),
             (32,{"Head":{"rotation":(-.04,0,.06)},"Forearm.L":{"rotation":(-.15,0,.04)}}),
             (48,{})])
armature.animation_data.action = None
bpy.ops.object.select_all(action="DESELECT")
mesh.select_set(True)
armature.select_set(True)
bpy.context.view_layer.objects.active = armature
bpy.ops.export_scene.gltf(filepath=str(TARGET),export_format="GLB",use_selection=True,
                          export_animations=True,export_animation_mode="ACTIONS",
                          export_nla_strips=False,export_apply=False)
print("NPC_RIG_READY",TARGET,len(mesh.data.vertices),len(groups))
