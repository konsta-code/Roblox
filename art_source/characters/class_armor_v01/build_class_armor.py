"""Generate nine original modular class armor sets for CTFGame."""

import bpy
import json
import math
import os
from mathutils import Vector


ROOT = os.path.dirname(os.path.abspath(__file__))
EXPORT_DIR = os.path.join(ROOT, "export")
PREVIEW_DIR = os.path.join(ROOT, "previews")
BLEND_PATH = os.path.join(ROOT, "CTFGame_ClassArmor_v01.blend")
REPORT_PATH = os.path.join(ROOT, "class_armor_report.json")
os.makedirs(EXPORT_DIR, exist_ok=True)
os.makedirs(PREVIEW_DIR, exist_ok=True)

CLASSES = [
    ("Pathfinder", "Light", (0.10, 0.56, 0.88), "Aero fins and compact jetpack"),
    ("Sentinel", "Light", (0.14, 0.72, 0.86), "Sensor visor and rangefinder"),
    ("Infiltrator", "Light", (0.48, 0.18, 0.78), "Low profile cloak nodes"),
    ("Soldier", "Medium", (0.12, 0.43, 0.86), "Balanced segmented plates"),
    ("Technician", "Medium", (0.10, 0.72, 0.38), "Repair pack and utility pods"),
    ("Raider", "Medium", (0.92, 0.58, 0.10), "EMP coils and strike plates"),
    ("Juggernaut", "Heavy", (0.92, 0.31, 0.08), "Siege pauldrons and reactor"),
    ("Brute", "Heavy", (0.82, 0.12, 0.10), "Ram armor and shock nodes"),
    ("Doombringer", "Heavy", (0.90, 0.74, 0.08), "Fortress plating and shield emitters"),
]


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in list(bpy.data.collections):
        if collection.name != "Collection":
            bpy.data.collections.remove(collection)


def material(name, color, metallic, roughness, emission=0.0):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
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


def finish(obj, mat, bevel=0.055):
    obj.data.materials.append(mat)
    modifier = obj.modifiers.new("ArmorBevel", "BEVEL")
    modifier.width = bevel
    modifier.segments = 2
    modifier.limit_method = "ANGLE"
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def box(collection, name, size, location, mat, rotation=(0, 0, 0), bevel=0.055):
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.scale = tuple(value / 2 for value in size)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    move(obj, collection)
    return finish(obj, mat, bevel)


def cylinder(collection, name, radius, depth, location, mat, rotation=(0, 0, 0), vertices=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    move(obj, collection)
    return finish(obj, mat, 0.035)


def sphere(collection, name, scale, location, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    move(obj, collection)
    return finish(obj, mat, 0.025)


def build_armor(collection, class_name, weight, accent):
    heavy = weight == "Heavy"
    medium = weight == "Medium"
    plate = 1.28 if heavy else (1.08 if medium else 0.88)
    dark = bpy.data.materials["MAT_Carbon"]
    steel = bpy.data.materials["MAT_Steel"]

    # Helmet and illuminated visor.
    sphere(collection, "Helmet", (0.58 + (0.08 if heavy else 0), 0.50, 0.46), (0, 0, 2.40), dark)
    box(collection, "Visor", (0.88, 0.12, 0.22), (0, -0.48, 2.40), accent, bevel=0.035)
    box(collection, "HelmetCrest", (0.24, 0.55, 0.16), (0, 0.02, 2.86), accent, rotation=(0, math.radians(-8), 0), bevel=0.025)

    # Chest, back and abdomen remain modular for R15 fitting.
    box(collection, "ChestPlate", (plate, 0.48, 1.18), (0, -0.34, 1.42), accent, rotation=(math.radians(-4), 0, 0), bevel=0.10)
    box(collection, "ChestCore", (0.38, 0.12, 0.48), (0, -0.61, 1.45), steel, bevel=0.035)
    box(collection, "BackPlate", (plate * 0.92, 0.42, 1.05), (0, 0.35, 1.43), dark, bevel=0.085)
    box(collection, "Abdomen", (plate * 0.70, 0.42, 0.52), (0, -0.18, 0.72), steel, bevel=0.065)

    shoulder_size = 0.58 if heavy else (0.46 if medium else 0.34)
    for side in (-1, 1):
        sphere(collection, "Shoulder_%s" % ("L" if side < 0 else "R"), (shoulder_size, 0.45, 0.34), (side * (0.82 if heavy else 0.70), 0, 1.65), accent)
        box(collection, "Forearm_%s" % ("L" if side < 0 else "R"), (0.34 if heavy else 0.27, 0.38, 0.72), (side * 0.90, -0.05, 0.73), dark, bevel=0.055)
        box(collection, "Shin_%s" % ("L" if side < 0 else "R"), (0.38 if heavy else 0.30, 0.40, 0.84), (side * 0.38, -0.08, -0.58), accent, bevel=0.065)
        box(collection, "Boot_%s" % ("L" if side < 0 else "R"), (0.46, 0.72, 0.30), (side * 0.38, -0.14, -1.16), dark, bevel=0.065)

    # Two jet nozzles are common visual language across all classes.
    for side in (-1, 1):
        cylinder(collection, "JetNozzle_%s" % ("L" if side < 0 else "R"), 0.18 if heavy else 0.14, 0.48, (side * 0.38, 0.59, 1.18), steel, rotation=(math.pi / 2, 0, 0), vertices=12)
        cylinder(collection, "JetGlow_%s" % ("L" if side < 0 else "R"), 0.10, 0.50, (side * 0.38, 0.62, 1.18), accent, rotation=(math.pi / 2, 0, 0), vertices=12)

    if class_name == "Pathfinder":
        for side in (-1, 1):
            box(collection, "AeroFin_%s" % side, (0.12, 0.78, 0.72), (side * 0.66, 0.52, 1.52), accent, rotation=(0, math.radians(side * 18), 0), bevel=0.025)
    elif class_name == "Sentinel":
        cylinder(collection, "Rangefinder", 0.13, 0.48, (0.48, -0.34, 2.62), accent, rotation=(math.pi / 2, 0, 0), vertices=12)
    elif class_name == "Infiltrator":
        for index in range(5):
            box(collection, "CloakNode_%02d" % index, (0.14, 0.10, 0.14), ((index - 2) * 0.22, -0.61, 1.12), accent, bevel=0.025)
    elif class_name == "Technician":
        box(collection, "RepairPack", (0.78, 0.55, 0.92), (0, 0.60, 1.28), accent, bevel=0.09)
        for side in (-1, 1):
            cylinder(collection, "ToolPod_%s" % side, 0.15, 0.76, (side * 0.52, 0.46, 1.10), steel, vertices=12)
    elif class_name == "Raider":
        for side in (-1, 1):
            cylinder(collection, "EMPCoil_%s" % side, 0.24, 0.16, (side * 0.53, -0.52, 1.32), accent, rotation=(math.pi / 2, 0, 0), vertices=16)
    elif class_name == "Juggernaut":
        sphere(collection, "SiegeReactor", (0.43, 0.25, 0.43), (0, 0.58, 1.56), accent)
    elif class_name == "Brute":
        box(collection, "RamPlate", (1.44, 0.28, 0.44), (0, -0.56, 1.78), accent, bevel=0.10)
        for side in (-1, 1):
            sphere(collection, "ShockNode_%s" % side, (0.22, 0.15, 0.22), (side * 0.54, -0.58, 1.25), accent)
    elif class_name == "Doombringer":
        for side in (-1, 1):
            cylinder(collection, "ShieldEmitter_%s" % side, 0.27, 0.18, (side * 0.62, -0.48, 1.52), accent, rotation=(math.pi / 2, 0, 0), vertices=16)


def look_at(obj, target=(0, 0, 0.8)):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def setup_render():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 520
    scene.render.resolution_y = 650
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.world.color = (0.012, 0.018, 0.028)
    camera_data = bpy.data.cameras.new("ArmorCameraData")
    camera = bpy.data.objects.new("ArmorCamera", camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera.location = (5.4, -8.2, 4.3)
    camera.data.lens = 68
    look_at(camera)
    for name, location, energy, color in [
        ("Key", (4, -4, 7), 1100, (0.68, 0.82, 1.0)),
        ("Rim", (-4, 2, 5), 950, (1.0, 0.30, 0.10)),
        ("Fill", (2, 4, 3), 500, (0.24, 0.44, 1.0)),
    ]:
        data = bpy.data.lights.new(name + "Data", "AREA")
        data.energy = energy
        data.color = color
        data.size = 4
        light = bpy.data.objects.new(name, data)
        scene.collection.objects.link(light)
        light.location = location
        look_at(light)
    return camera


def meshes(collection):
    return [obj for obj in collection.objects if obj.type == "MESH"]


def triangles(collection):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    total = 0
    for obj in meshes(collection):
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        mesh.calc_loop_triangles()
        total += len(mesh.loop_triangles)
        evaluated.to_mesh_clear()
    return total


def export(collection, class_name):
    bpy.ops.object.select_all(action="DESELECT")
    parts = meshes(collection)
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(EXPORT_DIR, class_name + "_Armor.fbx"),
        use_selection=True,
        object_types={"MESH"},
        apply_unit_scale=True,
        bake_space_transform=True,
        add_leaf_bones=False,
        mesh_smooth_type="FACE",
    )


clear_scene()
material("MAT_Carbon", (0.018, 0.027, 0.040), 0.72, 0.28)
material("MAT_Steel", (0.17, 0.22, 0.28), 0.90, 0.20)
collections = []
definitions = []
for class_name, weight, color, description in CLASSES:
    accent = material("MAT_%s" % class_name, color, 0.42, 0.20, 3.0)
    collection = bpy.data.collections.new(class_name + "_Armor")
    bpy.context.scene.collection.children.link(collection)
    collections.append(collection)
    build_armor(collection, class_name, weight, accent)
    definitions.append((class_name, weight, description, collection))

camera = setup_render()
bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
report = []
for class_name, weight, description, collection in definitions:
    count = triangles(collection)
    if count <= 0 or count > 10000:
        raise RuntimeError("Triangle budget failed for %s: %d" % (class_name, count))
    export(collection, class_name)
    for candidate in collections:
        candidate.hide_render = candidate != collection
    bpy.context.scene.render.filepath = os.path.join(PREVIEW_DIR, class_name + "_Armor.png")
    bpy.ops.render.render(write_still=True)
    report.append({
        "class": class_name,
        "weight": weight,
        "description": description,
        "objects": len(meshes(collection)),
        "triangles": count,
        "fbx": "export/%s_Armor.fbx" % class_name,
        "preview": "previews/%s_Armor.png" % class_name,
    })

payload = {"blend": os.path.basename(BLEND_PATH), "class_count": len(report), "assets": report}
with open(REPORT_PATH, "w", encoding="utf-8") as handle:
    json.dump(payload, handle, indent=2)
print(json.dumps(payload, indent=2))
