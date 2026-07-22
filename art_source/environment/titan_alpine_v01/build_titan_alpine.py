"""Create an editable Blender environment source for the Titan Alpine arena."""

import bpy
import json
import math
import os
from mathutils import Vector


ROOT = os.path.dirname(os.path.abspath(__file__))
EXPORT_DIR = os.path.join(ROOT, "export")
PREVIEW_DIR = os.path.join(ROOT, "previews")
BLEND_PATH = os.path.join(ROOT, "CTFGame_TitanAlpine_v01.blend")
FBX_PATH = os.path.join(EXPORT_DIR, "CTFGame_TitanAlpine_v01.fbx")
REPORT_PATH = os.path.join(ROOT, "environment_report.json")
S = 0.05  # 20 Roblox studs -> one Blender meter.
os.makedirs(EXPORT_DIR, exist_ok=True)
os.makedirs(PREVIEW_DIR, exist_ok=True)


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in list(bpy.data.collections):
        if collection.name != "Collection":
            bpy.data.collections.remove(collection)


def material(name, color, metallic=0.0, roughness=0.65, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    emission_color = bsdf.inputs.get("Emission Color") or bsdf.inputs.get("Emission")
    if emission_color:
        emission_color.default_value = (*color, 1)
    emission_strength = bsdf.inputs.get("Emission Strength")
    if emission_strength:
        emission_strength.default_value = emission
    return mat


def move(obj, collection):
    for current in list(obj.users_collection):
        current.objects.unlink(obj)
    collection.objects.link(obj)


def cube(collection, name, size, location, mat, rotation=(0, 0, 0), bevel=0.08):
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.scale = tuple(value / 2 for value in size)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    move(obj, collection)
    obj.data.materials.append(mat)
    if bevel > 0:
        modifier = obj.modifiers.new("EnvironmentBevel", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        modifier.limit_method = "ANGLE"
    return obj


def ramp(collection, name, x0, h0, x1, h1, width, lane_y, mat, thickness=3.5):
    run = (x1 - x0) * S
    rise = (h1 - h0) * S
    length = math.sqrt(run * run + rise * rise)
    angle = math.atan2(rise, run)
    mid_x = (x0 + x1) * 0.5 * S
    mid_z = (h0 + h1) * 0.5 * S - thickness * 0.5 * math.cos(angle)
    return cube(
        collection,
        name,
        (length, width * S, thickness),
        (mid_x, lane_y * S, mid_z),
        mat,
        rotation=(0, -angle, 0),
        bevel=0.10,
    )


def build_route(collection, prefix, profile, width, lane_y, mats):
    for index in range(len(profile) - 1):
        a, b = profile[index], profile[index + 1]
        ramp(collection, "%s_%02d" % (prefix, index + 1), a[0], a[1], b[0], b[1], width, lane_y, mats[index % len(mats)])


def look_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


clear_scene()
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 1100
scene.render.resolution_y = 700
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.view_settings.look = "AgX - Medium High Contrast"
scene.world.color = (0.018, 0.028, 0.045)

ice = material("MAT_Ice", (0.34, 0.56, 0.76), 0.05, 0.24)
snow = material("MAT_Snow", (0.78, 0.88, 0.96), 0.0, 0.72)
rock = material("MAT_Rock", (0.20, 0.25, 0.31), 0.0, 0.92)
dark = material("MAT_BaseGraphite", (0.025, 0.045, 0.075), 0.72, 0.26)
red = material("MAT_RedEnergy", (0.72, 0.06, 0.045), 0.36, 0.18, 4.0)
blue = material("MAT_BlueEnergy", (0.04, 0.25, 0.85), 0.36, 0.18, 4.0)
cyan = material("MAT_RouteEnergy", (0.02, 0.65, 0.92), 0.30, 0.18, 3.0)

environment = bpy.data.collections.new("TitanAlpine_Environment")
scene.collection.children.link(environment)

main_profile = [(-535, 24), (-450, -4), (-345, 25), (-235, -12), (-120, 38), (0, -8), (120, 38), (235, -12), (345, 25), (450, -4), (535, 24)]
side_profile = [(-535, 24), (-420, 6), (-320, 28), (-210, -14), (-100, 22), (0, 46), (100, 22), (210, -14), (320, 28), (420, 6), (535, 24)]
rim_profile = [(-535, 24), (-420, 46), (-300, 8), (-170, 58), (0, 20), (170, 58), (300, 8), (420, 46), (535, 24)]
build_route(environment, "MainRoute", main_profile, 300, 0, [ice, snow, ice])
for lane_y in (-250, 250):
    build_route(environment, "SideRoute_%s" % ("N" if lane_y < 0 else "S"), side_profile, 200, lane_y, [snow, ice])
for lane_y in (-395, 395):
    build_route(environment, "RimRoute_%s" % ("N" if lane_y < 0 else "S"), rim_profile, 90, lane_y, [snow])

# Ground catch-bowl and backfield walls.
cube(environment, "WorldGround", (1500 * S, 1000 * S, 3.5), (0, 0, -5.2), rock, bevel=0)
ramp(environment, "RedBackfield", -740, 62, -605, 0, 880, 0, snow, thickness=4.5)
ramp(environment, "BlueBackfield", 605, 0, 740, 62, 880, 0, snow, thickness=4.5)

for sign, team_name, accent in [(-1, "Red", red), (1, "Blue", blue)]:
    base_x = 570 * sign * S
    cube(environment, team_name + "_Platform", (90 * S, 126 * S, 0.55), (base_x, 0, 1.2), accent, bevel=0.12)
    cube(environment, team_name + "_Citadel", (54 * S, 76 * S, 2.8), (base_x - sign * 0.55, 0, 2.55), dark, bevel=0.18)
    cube(environment, team_name + "_Roof", (64 * S, 88 * S, 0.20), (base_x - sign * 0.45, 0, 4.05), accent, bevel=0.08)
    cube(environment, team_name + "_FlagSpire", (0.28, 0.28, 5.8), (base_x - sign * 2.0, 0, 4.3), accent, bevel=0.04)
    for side in (-1, 1):
        cube(environment, "%s_Wing_%s" % (team_name, side), (34 * S, 0.30, 2.4), (base_x, side * 3.0, 2.5), dark, rotation=(0, 0, math.radians(side * 6)), bevel=0.10)

# Canyon silhouette around the playable routes.
for index in range(24):
    side = -1 if index % 2 == 0 else 1
    x = (-680 + index * 58) * S
    y = side * (455 + (index % 4) * 18) * S
    height = (68 + (index * 17) % 62) * S
    cube(environment, "CanyonSpire_%02d" % index, (1.6 + (index % 3) * 0.35, 2.2, height), (x, y, height * 0.5 - 0.8), rock, rotation=(math.radians(side * (index % 5) * 2), 0, math.radians((index % 7) * 4)), bevel=0.16)
    cube(environment, "SnowCap_%02d" % index, (1.25, 1.75, 0.28), (x, y, height - 0.72), snow, bevel=0.10)

# Route beacons and central monuments.
for x_studs in range(-500, 501, 100):
    for y_studs in (-345, -145, 145, 345):
        x, y = x_studs * S, y_studs * S
        cube(environment, "RoutePost_%d_%d" % (x_studs, y_studs), (0.10, 0.10, 1.5), (x, y, 1.4 + abs(x) * 0.03), dark, bevel=0.02)
        cube(environment, "RouteGlow_%d_%d" % (x_studs, y_studs), (0.18, 0.18, 0.18), (x, y, 2.2 + abs(x) * 0.03), cyan, bevel=0.05)
for side in (-1, 1):
    cube(environment, "CoreMonument_%s" % side, (0.45, 0.45, 5.0), (0, side * 5.2, 2.2), dark, rotation=(0, math.radians(45), math.radians(side * 8)), bevel=0.10)
    cube(environment, "CoreEnergy_%s" % side, (0.16, 0.16, 4.2), (0, side * 5.2, 2.2), cyan, bevel=0.04)

# Lighting and cameras.
for name, location, energy, size, color in [
    ("SunKey", (-35, -40, 65), 1800, 25, (0.92, 0.80, 0.68)),
    ("SkyFill", (35, 20, 45), 1300, 28, (0.34, 0.52, 1.0)),
    ("Rim", (0, 50, 30), 900, 20, (0.25, 0.72, 1.0)),
]:
    data = bpy.data.lights.new(name + "Data", "AREA")
    data.energy = energy
    data.shape = "DISK"
    data.size = size
    data.color = color
    light = bpy.data.objects.new(name, data)
    scene.collection.objects.link(light)
    light.location = location
    look_at(light, (0, 0, 0))

camera_data = bpy.data.cameras.new("EnvironmentCameraData")
camera = bpy.data.objects.new("EnvironmentCamera", camera_data)
scene.collection.objects.link(camera)
scene.camera = camera

views = [
    ("Aerial", (54, -64, 58), (0, 0, 0), 56),
    ("CoreRoute", (0, -28, 9), (0, 2, 1), 62),
    ("RedApproach", (-38, -15, 9), (-28, 0, 2), 60),
    ("BlueApproach", (38, 15, 9), (28, 0, 2), 60),
]
for name, location, target, lens in views:
    camera.location = location
    camera.data.lens = lens
    look_at(camera, target)
    scene.render.filepath = os.path.join(PREVIEW_DIR, "TitanAlpine_%s.png" % name)
    bpy.ops.render.render(write_still=True)

bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
bpy.ops.object.select_all(action="DESELECT")
meshes = [obj for obj in environment.objects if obj.type == "MESH"]
for obj in meshes:
    obj.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.export_scene.fbx(filepath=FBX_PATH, use_selection=True, object_types={"MESH"}, apply_unit_scale=True, bake_space_transform=True, add_leaf_bones=False, mesh_smooth_type="FACE")

depsgraph = bpy.context.evaluated_depsgraph_get()
triangle_total = 0
for obj in meshes:
    evaluated = obj.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    mesh.calc_loop_triangles()
    triangle_total += len(mesh.loop_triangles)
    evaluated.to_mesh_clear()
report = {
    "name": "TITAN ALPINE",
    "blend": os.path.basename(BLEND_PATH),
    "fbx": "export/" + os.path.basename(FBX_PATH),
    "objects": len(meshes),
    "triangles": triangle_total,
    "scale_roblox_studs_per_meter": int(1 / S),
    "previews": ["previews/TitanAlpine_%s.png" % view[0] for view in views],
}
if triangle_total > 80000:
    raise RuntimeError("Environment triangle budget failed: %d" % triangle_total)
with open(REPORT_PATH, "w", encoding="utf-8") as handle:
    json.dump(report, handle, indent=2)
print(json.dumps(report, indent=2))
