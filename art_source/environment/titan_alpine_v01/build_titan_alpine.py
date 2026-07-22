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
IMPORT_MANIFEST_PATH = os.path.join(ROOT, "roblox_import_manifest.json")
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


def ellipsoid(collection, name, scale, location, mat, rotation=(0, 0, 0), segments=20, rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    move(obj, collection)
    obj.data.materials.append(mat)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def cylinder(collection, name, radius, depth, location, mat, rotation=(0, 0, 0), vertices=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    move(obj, collection)
    obj.data.materials.append(mat)
    bevel = obj.modifiers.new("CylinderBevel", "BEVEL")
    bevel.width = 0.055
    bevel.segments = 2
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def torus(collection, name, major, minor, location, mat, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=28, minor_segments=8, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    move(obj, collection)
    obj.data.materials.append(mat)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def cone(collection, name, radius, depth, location, mat, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=radius, radius2=0.04, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    move(obj, collection)
    obj.data.materials.append(mat)
    return obj


def mountain(collection, name, radii, depth, location, mat, rotation=(0, 0, 0), top_ratio=0.10):
    bpy.ops.mesh.primitive_cone_add(vertices=9, radius1=1, radius2=top_ratio, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.scale = (radii[0], radii[1], 1)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    move(obj, collection)
    obj.data.materials.append(mat)
    bevel = obj.modifiers.new("CragBevel", "BEVEL")
    bevel.width = 0.10
    bevel.segments = 2
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
    """Build one seamless visual ribbon; MapBuilder remains the collision source."""
    half_width = width * S * 0.5
    thickness = 0.42
    vertices = []
    for x_studs, height_studs in profile:
        x = x_studs * S
        z = height_studs * S
        y = lane_y * S
        vertices.extend([
            (x, y - half_width, z),
            (x, y + half_width, z),
            (x, y - half_width, z - thickness),
            (x, y + half_width, z - thickness),
        ])
    faces = []
    top_face_indices = []
    for index in range(len(profile) - 1):
        a = index * 4
        b = (index + 1) * 4
        top_face_indices.append(len(faces))
        faces.extend([
            (a, b, b + 1, a + 1),
            (a + 2, a + 3, b + 3, b + 2),
            (a, a + 2, b + 2, b),
            (a + 1, b + 1, b + 3, a + 3),
        ])
    faces.extend([(0, 1, 3, 2), ((len(profile) - 1) * 4, (len(profile) - 1) * 4 + 2, (len(profile) - 1) * 4 + 3, (len(profile) - 1) * 4 + 1)])
    mesh = bpy.data.meshes.new(prefix + "Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(prefix, mesh)
    collection.objects.link(obj)
    for mat in mats:
        obj.data.materials.append(mat)
    for segment, polygon_index in enumerate(top_face_indices):
        obj.data.polygons[polygon_index].material_index = segment % len(mats)
    bevel = obj.modifiers.new("RouteEdgeSoftening", "BEVEL")
    bevel.width = 0.14
    bevel.segments = 3
    bevel.limit_method = "ANGLE"
    return obj


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
scene.world.use_nodes = True
world_background = scene.world.node_tree.nodes.get("Background")
world_background.inputs["Color"].default_value = (0.035, 0.065, 0.11, 1)
world_background.inputs["Strength"].default_value = 0.48

ice = material("MAT_Ice", (0.44, 0.68, 0.88), 0.05, 0.24)
snow = material("MAT_Snow", (0.88, 0.94, 0.99), 0.0, 0.72)
rock = material("MAT_Rock", (0.28, 0.35, 0.44), 0.0, 0.92)
dark = material("MAT_BaseGraphite", (0.035, 0.075, 0.13), 0.72, 0.26)
red = material("MAT_RedEnergy", (0.72, 0.06, 0.045), 0.36, 0.18, 4.0)
blue = material("MAT_BlueEnergy", (0.04, 0.25, 0.85), 0.36, 0.18, 4.0)
cyan = material("MAT_RouteEnergy", (0.02, 0.65, 0.92), 0.30, 0.18, 3.0)

environment = bpy.data.collections.new("TitanAlpine_Environment")
scene.collection.children.link(environment)

MODULE_PIVOTS = {
    "CoreRoute": (0, 0, 0),
    "NorthFlank": (0, 20, -250),
    "SouthFlank": (0, 20, 250),
    "RedCitadel": (-570, 24, 0),
    "BlueCitadel": (570, 24, 0),
    "WestGlacierVault": (-255, 2, -250),
    "EastGlacierVault": (255, 2, 250),
    "CanyonBackdrop": (0, 0, 0),
}
modules = {}
for module_name in MODULE_PIVOTS:
    module = bpy.data.collections.new("Titan_" + module_name)
    environment.children.link(module)
    modules[module_name] = module

main_profile = [(-535, 24), (-450, -4), (-345, 25), (-235, -12), (-120, 38), (0, -8), (120, 38), (235, -12), (345, 25), (450, -4), (535, 24)]
side_profile = [(-535, 24), (-420, 6), (-320, 28), (-210, -14), (-100, 22), (0, 46), (100, 22), (210, -14), (320, 28), (420, 6), (535, 24)]
rim_profile = [(-535, 24), (-420, 46), (-300, 8), (-170, 58), (0, 20), (170, 58), (300, 8), (420, 46), (535, 24)]
build_route(modules["CoreRoute"], "MainRoute", main_profile, 300, 0, [ice, snow, ice])
for lane_y in (-250, 250):
    module = modules["NorthFlank" if lane_y < 0 else "SouthFlank"]
    build_route(module, "SideRoute_%s" % ("N" if lane_y < 0 else "S"), side_profile, 200, lane_y, [snow, ice])
for lane_y in (-395, 395):
    module = modules["NorthFlank" if lane_y < 0 else "SouthFlank"]
    build_route(module, "RimRoute_%s" % ("N" if lane_y < 0 else "S"), rim_profile, 90, lane_y, [snow])

# Ground catch-bowl and backfield walls.
cube(modules["CanyonBackdrop"], "WorldGround", (1500 * S, 1000 * S, 3.5), (0, 0, -5.2), rock, bevel=0)
ramp(modules["RedCitadel"], "RedBackfield", -740, 62, -605, 0, 880, 0, snow, thickness=4.5)
ramp(modules["BlueCitadel"], "BlueBackfield", 605, 0, 740, 62, 880, 0, snow, thickness=4.5)

for sign, team_name, accent in [(-1, "Red", red), (1, "Blue", blue)]:
    base_collection = modules[team_name + "Citadel"]
    base_x = 570 * sign * S
    cube(base_collection, team_name + "_Platform", (90 * S, 126 * S, 0.55), (base_x, 0, 1.2), accent, bevel=0.12)
    cube(base_collection, team_name + "_Citadel", (54 * S, 76 * S, 2.8), (base_x - sign * 0.55, 0, 2.55), dark, bevel=0.18)
    ellipsoid(base_collection, team_name + "_RearHull", (2.65, 4.25, 1.72), (base_x + sign * 2.6, 0, 2.8), dark)
    ellipsoid(base_collection, team_name + "_RoofCanopy", (3.55, 4.25, 0.48), (base_x - sign * 0.4, 0, 4.35), dark)
    cube(base_collection, team_name + "_Roof", (64 * S, 88 * S, 0.20), (base_x - sign * 0.45, 0, 4.05), accent, bevel=0.08)
    cube(base_collection, team_name + "_FlagSpire", (0.28, 0.28, 5.8), (base_x - sign * 2.0, 0, 4.3), accent, bevel=0.04)
    for side in (-1, 1):
        cube(base_collection, "%s_Wing_%s" % (team_name, side), (34 * S, 0.30, 2.4), (base_x, side * 3.0, 2.5), dark, rotation=(0, 0, math.radians(side * 6)), bevel=0.10)
        cylinder(base_collection, "%s_EnergyPylon_%s" % (team_name, side), 0.22, 3.2, (base_x - sign * 2.1, side * 2.75, 3.3), accent)
    for strip in (-2, -1, 0, 1, 2):
        cube(base_collection, "%s_Facade_%s" % (team_name, strip), (0.12, 0.54, 1.55), (base_x - sign * 3.22, strip * 0.75, 3.05), accent, bevel=0.025)

# Canyon silhouette around the playable routes.
for index in range(24):
    side = -1 if index % 2 == 0 else 1
    x = (-680 + index * 58) * S
    y = side * (455 + (index % 4) * 18) * S
    height = (68 + (index * 17) % 62) * S
    radius_x = 1.9 + (index % 3) * 0.34
    radius_y = 2.5 + (index % 4) * 0.22
    mountain(modules["CanyonBackdrop"], "CanyonSpire_%02d" % index, (radius_x, radius_y), height, (x, y, height * 0.5 - 0.9), rock, rotation=(math.radians(side * (index % 5) * 2), 0, math.radians((index % 7) * 4)))
    mountain(modules["CanyonBackdrop"], "SnowCap_%02d" % index, (radius_x * 0.47, radius_y * 0.47), height * 0.18, (x, y, height * 0.88 - 0.9), snow, rotation=(0, 0, math.radians((index % 7) * 4)), top_ratio=0.18)

# Route beacons and central monuments.
for x_studs in range(-500, 501, 100):
    for y_studs in (-345, -145, 145, 345):
        x, y = x_studs * S, y_studs * S
        lane_collection = modules["NorthFlank" if y_studs < 0 else "SouthFlank"]
        cube(lane_collection, "RoutePost_%d_%d" % (x_studs, y_studs), (0.10, 0.10, 1.5), (x, y, 1.4 + abs(x) * 0.03), dark, bevel=0.02)
        cube(lane_collection, "RouteGlow_%d_%d" % (x_studs, y_studs), (0.18, 0.18, 0.18), (x, y, 2.2 + abs(x) * 0.03), cyan, bevel=0.05)
for side in (-1, 1):
    cube(modules["CoreRoute"], "CoreMonument_%s" % side, (0.45, 0.45, 5.0), (0, side * 5.2, 2.2), dark, rotation=(0, math.radians(45), math.radians(side * 8)), bevel=0.10)
    cube(modules["CoreRoute"], "CoreEnergy_%s" % side, (0.16, 0.16, 4.2), (0, side * 5.2, 2.2), cyan, bevel=0.04)

# Suspended reactor landmark at midfield.
cylinder(modules["CoreRoute"], "TitanReactor_Core", 0.48, 3.8, (0, 0, 4.1), cyan, rotation=(0, math.pi / 2, 0), vertices=32)
for ring_index, radius in enumerate((1.25, 1.72, 2.18)):
    torus(modules["CoreRoute"], "TitanReactor_Ring_%02d" % ring_index, radius, 0.10, (0, 0, 4.1), cyan, rotation=(math.pi / 2, 0, 0))
for arm in range(6):
    angle = arm * math.tau / 6
    cube(modules["CoreRoute"], "TitanReactor_Brace_%02d" % arm, (0.16, 1.75, 0.18), (math.cos(angle) * 1.1, math.sin(angle) * 1.1, 4.1), dark, rotation=(0, 0, angle), bevel=0.03)
cylinder(modules["CoreRoute"], "TitanReactor_SkyBeam", 0.18, 9.0, (0, 0, 8.4), cyan, vertices=16)


def build_ice_vault(collection, prefix, x_studs, z_studs):
    x, y = x_studs * S, z_studs * S
    for side in (-1, 1):
        for layer in range(3):
            ellipsoid(collection, "%s_Wall_%s_%s" % (prefix, side, layer), (3.8 - layer * 0.38, 1.55, 2.35 + layer * 0.28), (x + layer * 0.32, y + side * (3.1 - layer * 0.30), 1.25 + layer * 0.55), ice if layer == 1 else rock, rotation=(0, math.radians(side * (8 + layer * 4)), 0), segments=18, rings=10)
    for roof in range(-2, 3):
        ellipsoid(collection, "%s_Roof_%s" % (prefix, roof), (1.45, 2.9, 1.05), (x + roof * 1.1, y, 3.35 + abs(roof) * 0.10), ice, rotation=(0, math.radians(roof * 5), 0), segments=18, rings=10)
    for fang in range(-4, 5):
        cone(collection, "%s_Icicle_%s" % (prefix, fang), 0.20 + (fang % 2) * 0.05, 1.25 + abs(fang) * 0.10, (x + fang * 0.48, y + ((fang * 37) % 5 - 2) * 0.45, 2.65), ice, rotation=(math.pi, 0, 0))
    for side in (-1, 1):
        cube(collection, "%s_Energy_%s" % (prefix, side), (1.5, 0.08, 0.08), (x, y + side * 2.25, 0.72), cyan, bevel=0.02)


build_ice_vault(modules["WestGlacierVault"], "WestVault", -255, -250)
build_ice_vault(modules["EastGlacierVault"], "EastVault", 255, 250)

# Tiny named origin references survive FBX import and let the Roblox loader
# place every multi-mesh module exactly, regardless of the importer model pivot.
for module_name, pivot in MODULE_PIVOTS.items():
    pivot_blender = (pivot[0] * S, pivot[2] * S, pivot[1] * S)
    cube(modules[module_name], "__PIVOT_" + module_name, (0.035, 0.035, 0.035), pivot_blender, dark, bevel=0)

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

sun_data = bpy.data.lights.new("AlpineSunData", "SUN")
sun_data.energy = 3.2
sun_data.angle = math.radians(18)
sun_data.color = (0.96, 0.82, 0.69)
sun = bpy.data.objects.new("AlpineSun", sun_data)
scene.collection.objects.link(sun)
sun.rotation_euler = (math.radians(28), math.radians(-22), math.radians(-32))

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


def collection_meshes(collection):
    return [obj for obj in collection.all_objects if obj.type == "MESH"]


def triangle_count(meshes):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    total = 0
    for obj in meshes:
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        mesh.calc_loop_triangles()
        total += len(mesh.loop_triangles)
        evaluated.to_mesh_clear()
    return total


def export_meshes(filepath, meshes, pivot_studs=None):
    bpy.ops.object.select_all(action="DESELECT")
    original_locations = {}
    if pivot_studs is not None:
        # Blender axes are X, Roblox-Z, Roblox-Y at 0.05 m/stud.
        pivot = Vector((pivot_studs[0] * S, pivot_studs[2] * S, pivot_studs[1] * S))
        for obj in meshes:
            original_locations[obj.name_full] = obj.location.copy()
            obj.location -= pivot
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.export_scene.fbx(
        filepath=filepath,
        use_selection=True,
        object_types={"MESH"},
        apply_unit_scale=True,
        bake_space_transform=True,
        add_leaf_bones=False,
        mesh_smooth_type="FACE",
    )
    if pivot_studs is not None:
        for obj in meshes:
            obj.location = original_locations[obj.name_full]


meshes = collection_meshes(environment)
export_meshes(FBX_PATH, meshes)
triangle_total = triangle_count(meshes)

module_reports = []
manifest_modules = []
for module_name, pivot in MODULE_PIVOTS.items():
    module_meshes = collection_meshes(modules[module_name])
    module_filename = "Titan_%s.fbx" % module_name
    module_path = os.path.join(EXPORT_DIR, module_filename)
    export_meshes(module_path, module_meshes, pivot)
    module_triangles = triangle_count(module_meshes)
    if module_triangles > 30000:
        raise RuntimeError("Module triangle budget failed for %s: %d" % (module_name, module_triangles))
    module_reports.append({
        "name": module_name,
        "fbx": "export/" + module_filename,
        "objects": len(module_meshes),
        "triangles": module_triangles,
        "pivot_studs": {"x": pivot[0], "y": pivot[1], "z": pivot[2]},
    })
    manifest_modules.append({
        "model_name": "Titan_" + module_name,
        "source_fbx": "export/" + module_filename,
        "workspace_parent": "Workspace/ImportedMap/TitanAlpine",
        "pivot_cframe": [pivot[0], pivot[1], pivot[2]],
        "collision_fidelity": "Hull" if "Citadel" in module_name else "Box",
        "double_sided": False,
        "anchored": True,
        "can_collide": False,
        "cast_shadow": module_name != "CanyonBackdrop",
    })

report = {
    "name": "TITAN ALPINE",
    "blend": os.path.basename(BLEND_PATH),
    "fbx": "export/" + os.path.basename(FBX_PATH),
    "objects": len(meshes),
    "triangles": triangle_total,
    "scale_roblox_studs_per_meter": int(1 / S),
    "module_count": len(module_reports),
    "modules": module_reports,
    "previews": ["previews/TitanAlpine_%s.png" % view[0] for view in views],
}
if triangle_total > 80000:
    raise RuntimeError("Environment triangle budget failed: %d" % triangle_total)
with open(REPORT_PATH, "w", encoding="utf-8") as handle:
    json.dump(report, handle, indent=2)
with open(IMPORT_MANIFEST_PATH, "w", encoding="utf-8") as handle:
    json.dump({
        "pack": "TitanAlpine_v2",
        "studs_per_blender_meter": int(1 / S),
        "gameplay_collision_source": "MapBuilder.server.lua",
        "modules": manifest_modules,
    }, handle, indent=2)
print(json.dumps(report, indent=2))
