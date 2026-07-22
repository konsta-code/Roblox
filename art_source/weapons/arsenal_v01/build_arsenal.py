"""Generate the complete original CTFGame weapon pack in Blender.

The pack intentionally uses original silhouettes and names from this project.
Every class receives a disc/launcher, an automatic weapon and a grenade. The
script saves an editable master .blend, exports one FBX per item, renders a
preview per item and writes a machine-readable validation report.
"""

import bpy
import json
import math
import os
from mathutils import Vector


ROOT = os.path.dirname(os.path.abspath(__file__))
EXPORT_DIR = os.path.join(ROOT, "export")
PREVIEW_DIR = os.path.join(ROOT, "previews")
BLEND_PATH = os.path.join(ROOT, "CTFGame_Arsenal_v01.blend")
REPORT_PATH = os.path.join(ROOT, "arsenal_report.json")
os.makedirs(EXPORT_DIR, exist_ok=True)
os.makedirs(PREVIEW_DIR, exist_ok=True)

CLASSES = [
    ("Pathfinder", (0.10, 0.56, 0.88), "LightSpinfusor", "LightAssaultRifle", "ImpactNitron"),
    ("Sentinel", (0.14, 0.72, 0.86), "NovaBlaster", "BXT1Rifle", "GrenadeXL"),
    ("Infiltrator", (0.48, 0.18, 0.78), "StealthSpinfusor", "RhinoSMG", "StickyGrenade"),
    ("Soldier", (0.12, 0.43, 0.86), "Spinfusor", "AssaultRifle", "APGrenade"),
    ("Technician", (0.10, 0.72, 0.38), "Thumper", "TCN4SMG", "TCNGrenade"),
    ("Raider", (0.92, 0.58, 0.10), "ARXBuster", "NJ5SMG", "EMPGrenade"),
    ("Juggernaut", (0.92, 0.31, 0.08), "HeavySpinfusor", "X1LMG", "HeavyAPGrenade"),
    ("Brute", (0.82, 0.12, 0.10), "BruteSpinfusor", "AutoShotgun", "FractalGrenade"),
    ("Doombringer", (0.90, 0.74, 0.08), "SaberLauncher", "Chaingun", "FragGrenade"),
]


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in list(bpy.data.collections):
        if collection.name != "Collection":
            bpy.data.collections.remove(collection)


def material(name, color, metallic=0.55, roughness=0.3, emission=0.0):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    emission_color = bsdf.inputs.get("Emission Color") or bsdf.inputs.get("Emission")
    if emission_color:
        emission_color.default_value = (*color, 1.0)
    emission_strength = bsdf.inputs.get("Emission Strength")
    if emission_strength:
        emission_strength.default_value = emission
    return mat


GRAPHITE = None
STEEL = None
RUBBER = None


def move_to_collection(obj, collection):
    for current in list(obj.users_collection):
        current.objects.unlink(obj)
    collection.objects.link(obj)


def finish(obj, mat, bevel=0.045):
    obj.data.materials.append(mat)
    if bevel > 0:
        modifier = obj.modifiers.new("ProductionBevel", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        modifier.limit_method = "ANGLE"
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def box(collection, name, scale, location, mat, rotation=(0, 0, 0), bevel=0.045):
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.scale = (scale[0] / 2, scale[1] / 2, scale[2] / 2)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    move_to_collection(obj, collection)
    return finish(obj, mat, bevel)


def cylinder(collection, name, radius, depth, location, mat, vertices=16, rotation=(math.pi / 2, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    move_to_collection(obj, collection)
    return finish(obj, mat, 0.028)


def sphere(collection, name, radius, location, mat, segments=16, rings=8):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=radius, location=location)
    obj = bpy.context.object
    obj.name = name
    move_to_collection(obj, collection)
    return finish(obj, mat, 0.018)


def torus(collection, name, major, minor, location, mat, rotation=(math.pi / 2, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=20, minor_segments=6, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    move_to_collection(obj, collection)
    return finish(obj, mat, 0.012)


def add_grip(collection, accent, heavy=False):
    width = 0.44 if heavy else 0.36
    box(collection, "Grip", (width, 0.55, 0.95), (0, 0.72, -0.58), RUBBER, rotation=(math.radians(-16), 0, 0))
    box(collection, "TriggerGuard", (0.48, 0.55, 0.12), (0, 0.20, -0.28), accent, bevel=0.025)
    for index in range(4):
        box(collection, "GripRib_%02d" % index, (width + 0.035, 0.07, 0.09), (0, 0.55 + index * 0.12, -0.55 - index * 0.10), STEEL, bevel=0.012)


def build_launcher(collection, accent, variant, heavy=False):
    width = 1.18 if heavy else 0.92
    length = 3.7 if heavy else 3.2
    box(collection, "Receiver", (width, length, 0.88), (0, 0, 0.10), GRAPHITE, bevel=0.085)
    box(collection, "UpperArmor", (width + 0.12, length * 0.67, 0.25), (0, -0.18, 0.64), accent, bevel=0.055)
    box(collection, "LowerArmor", (width + 0.08, length * 0.58, 0.20), (0, 0.02, -0.39), accent, bevel=0.045)
    cylinder(collection, "EnergyChamber", 0.58 if heavy else 0.48, width + 0.16, (0, -0.50, 0.12), accent, vertices=20, rotation=(0, math.pi / 2, 0))
    torus(collection, "EnergyRingLeft", 0.40 if heavy else 0.33, 0.055, (-(width / 2 + 0.10), -0.50, 0.12), accent, rotation=(0, math.pi / 2, 0))
    torus(collection, "EnergyRingRight", 0.40 if heavy else 0.33, 0.055, ((width / 2 + 0.10), -0.50, 0.12), accent, rotation=(0, math.pi / 2, 0))
    cylinder(collection, "Muzzle", 0.34 if heavy else 0.28, 0.68, (0, -length / 2 - 0.25, 0.07), STEEL)
    cylinder(collection, "MuzzleGlow", 0.19 if heavy else 0.15, 0.73, (0, -length / 2 - 0.28, 0.07), accent)
    box(collection, "TopRail", (0.28, 1.55, 0.22), (0, 0.30, 0.72), STEEL, bevel=0.025)
    add_grip(collection, accent, heavy)
    if "Saber" in variant:
        box(collection, "GuidanceArray", (0.72, 0.82, 0.35), (0, -0.25, 0.84), accent, rotation=(0, 0, math.radians(10)))
        sphere(collection, "GuidanceEye", 0.15, (0, -0.65, 0.96), accent)
    elif "Thumper" in variant or "ARX" in variant:
        cylinder(collection, "Drum", 0.42, 0.92, (0, 0.35, -0.16), STEEL, rotation=(0, math.pi / 2, 0))
    elif "Nova" in variant:
        box(collection, "FluxForkLeft", (0.18, 1.12, 0.26), (-0.41, -1.38, 0.36), accent, rotation=(0, 0, math.radians(-6)))
        box(collection, "FluxForkRight", (0.18, 1.12, 0.26), (0.41, -1.38, 0.36), accent, rotation=(0, 0, math.radians(6)))
    elif "Stealth" in variant:
        box(collection, "SuppressorShroud", (0.74, 1.42, 0.58), (0, -1.42, 0.10), GRAPHITE, bevel=0.12)


def build_automatic(collection, accent, variant, heavy=False):
    width = 1.10 if heavy else 0.78
    length = 3.35 if heavy else 2.75
    box(collection, "Receiver", (width, length, 0.76), (0, 0.05, 0.05), GRAPHITE, bevel=0.075)
    box(collection, "SideArmorLeft", (0.10, length * 0.72, 0.54), (-width / 2 - 0.04, -0.12, 0.12), accent, bevel=0.028)
    box(collection, "SideArmorRight", (0.10, length * 0.72, 0.54), (width / 2 + 0.04, -0.12, 0.12), accent, bevel=0.028)
    barrel_count = 4 if "Chaingun" in variant else (3 if "LMG" in variant else 1)
    for index in range(barrel_count):
        x = (index - (barrel_count - 1) / 2) * 0.18
        z = 0.08 + (0.10 if index % 2 else -0.06)
        cylinder(collection, "Barrel_%02d" % index, 0.075 if barrel_count > 1 else 0.13, 1.75, (x, -length / 2 - 0.78, z), STEEL, vertices=12)
    cylinder(collection, "MuzzleBrake", 0.25 if heavy else 0.19, 0.34, (0, -length / 2 - 1.64, 0.06), accent, vertices=12)
    box(collection, "TopRail", (0.26, 1.55, 0.20), (0, -0.15, 0.59), STEEL, bevel=0.02)
    box(collection, "Stock", (width * 0.82, 1.15, 0.54), (0, length / 2 + 0.48, 0.10), accent, rotation=(math.radians(4), 0, 0), bevel=0.065)
    add_grip(collection, accent, heavy)
    if "BXT" in variant:
        cylinder(collection, "Scope", 0.22, 1.0, (0, -0.05, 0.89), GRAPHITE, vertices=16)
        cylinder(collection, "ScopeLens", 0.17, 0.08, (0, -0.58, 0.89), accent, vertices=16)
    elif "Shotgun" in variant:
        cylinder(collection, "DrumMagazine", 0.48, 0.72, (0, 0.55, -0.33), STEEL, rotation=(0, math.pi / 2, 0))
        box(collection, "HeatShield", (0.82, 1.48, 0.25), (0, -1.34, 0.42), accent, bevel=0.035)
    elif "SMG" in variant:
        box(collection, "CompactMagazine", (0.38, 0.78, 0.58), (0, 0.52, -0.42), STEEL, rotation=(math.radians(-8), 0, 0))
    else:
        box(collection, "Magazine", (0.44, 0.88, 0.64), (0, 0.62, -0.44), STEEL, rotation=(math.radians(-10), 0, 0))


def build_grenade(collection, accent, variant, heavy=False):
    radius = 0.54 if heavy else 0.44
    if "Sticky" in variant:
        cylinder(collection, "Core", radius, 0.62, (0, 0, 0), GRAPHITE, vertices=16, rotation=(0, 0, 0))
        for index in range(4):
            angle = index * math.pi / 2
            box(collection, "Clamp_%02d" % index, (0.18, 0.62, 0.28), (math.cos(angle) * 0.48, math.sin(angle) * 0.48, -0.18), accent, rotation=(0, 0, angle), bevel=0.025)
    elif "Fractal" in variant:
        sphere(collection, "Core", radius, (0, 0, 0), GRAPHITE, segments=20, rings=10)
        for index in range(6):
            angle = index * math.tau / 6
            box(collection, "Shard_%02d" % index, (0.18, 0.58, 0.34), (math.cos(angle) * 0.55, math.sin(angle) * 0.55, 0), accent, rotation=(0, 0, angle), bevel=0.025)
    else:
        sphere(collection, "Core", radius, (0, 0, 0), GRAPHITE, segments=20, rings=10)
        torus(collection, "EnergyBand", radius * 0.78, 0.065, (0, 0, 0), accent, rotation=(0, 0, 0))
        torus(collection, "SafetyBand", radius * 0.78, 0.045, (0, 0, 0), STEEL, rotation=(math.pi / 2, 0, 0))
    cylinder(collection, "Fuse", radius * 0.24, 0.35, (0, 0, radius + 0.14), accent, vertices=12, rotation=(0, 0, 0))
    box(collection, "SafetyLever", (0.20, 0.58, 0.10), (0.18, 0, radius + 0.34), STEEL, rotation=(0, math.radians(8), 0), bevel=0.018)


def look_at(obj, target=(0, 0, 0)):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def setup_render():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 640
    scene.render.resolution_y = 400
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.world.color = (0.012, 0.018, 0.028)
    camera_data = bpy.data.cameras.new("PreviewCameraData")
    camera = bpy.data.objects.new("PreviewCamera", camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera.data.lens = 62
    for name, location, energy, color in [
        ("Key", (4.5, -4.0, 6.0), 1000, (0.68, 0.82, 1.0)),
        ("Rim", (-4.0, 1.5, 4.0), 850, (1.0, 0.35, 0.12)),
        ("Fill", (3.0, 4.0, 2.0), 600, (0.25, 0.45, 1.0)),
    ]:
        data = bpy.data.lights.new(name + "Data", "AREA")
        data.energy = energy
        data.color = color
        data.shape = "DISK"
        data.size = 4.0
        light = bpy.data.objects.new(name, data)
        scene.collection.objects.link(light)
        light.location = location
        look_at(light)
    return camera


def collection_meshes(collection):
    return [obj for obj in collection.objects if obj.type == "MESH"]


def triangle_count(collection):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    total = 0
    for obj in collection_meshes(collection):
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        mesh.calc_loop_triangles()
        total += len(mesh.loop_triangles)
        evaluated.to_mesh_clear()
    return total


def export_collection(collection, asset_name):
    bpy.ops.object.select_all(action="DESELECT")
    meshes = collection_meshes(collection)
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(EXPORT_DIR, asset_name + ".fbx"),
        use_selection=True,
        object_types={"MESH"},
        apply_unit_scale=True,
        bake_space_transform=True,
        add_leaf_bones=False,
        mesh_smooth_type="FACE",
    )


def render_collection(camera, collection, asset_name, kind):
    for candidate in weapon_collections:
        candidate.hide_render = candidate != collection
    if kind == "grenade":
        camera.location = (3.1, -4.4, 2.7)
        camera.data.lens = 68
    else:
        camera.location = (5.6, -7.5, 3.8)
        camera.data.lens = 62
    look_at(camera, (0, 0, 0))
    bpy.context.scene.render.filepath = os.path.join(PREVIEW_DIR, asset_name + ".png")
    bpy.ops.render.render(write_still=True)


clear_scene()
GRAPHITE = material("MAT_Graphite", (0.025, 0.038, 0.055), 0.78, 0.24)
STEEL = material("MAT_Steel", (0.20, 0.24, 0.29), 0.88, 0.20)
RUBBER = material("MAT_Rubber", (0.018, 0.022, 0.028), 0.08, 0.72)

weapon_collections = []
assets = []
for class_name, class_color, disc_name, automatic_name, grenade_name in CLASSES:
    accent = material("MAT_%s_Energy" % class_name, class_color, 0.35, 0.18, 4.0)
    heavy = class_name in {"Juggernaut", "Brute", "Doombringer"}
    for slot, asset_name, builder in [
        ("disc", disc_name, build_launcher),
        ("automatic", automatic_name, build_automatic),
        ("grenade", grenade_name, build_grenade),
    ]:
        collection = bpy.data.collections.new("%s_%s" % (class_name, slot.title()))
        bpy.context.scene.collection.children.link(collection)
        weapon_collections.append(collection)
        builder(collection, accent, asset_name, heavy)
        canonical_name = "%s_%s" % (class_name, asset_name)
        assets.append((canonical_name, class_name, slot, collection))

camera = setup_render()
bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)

report_assets = []
for canonical_name, class_name, slot, collection in assets:
    triangles = triangle_count(collection)
    if triangles <= 0 or triangles > 12000:
        raise RuntimeError("Triangle budget failed for %s: %d" % (canonical_name, triangles))
    export_collection(collection, canonical_name)
    render_collection(camera, collection, canonical_name, slot)
    report_assets.append({
        "name": canonical_name,
        "class": class_name,
        "slot": slot,
        "objects": len(collection_meshes(collection)),
        "triangles": triangles,
        "fbx": "export/%s.fbx" % canonical_name,
        "preview": "previews/%s.png" % canonical_name,
    })

report = {
    "blend": os.path.basename(BLEND_PATH),
    "asset_count": len(report_assets),
    "class_count": len(CLASSES),
    "triangle_budget_per_asset": 12000,
    "assets": report_assets,
}
with open(REPORT_PATH, "w", encoding="utf-8") as handle:
    json.dump(report, handle, indent=2)
print(json.dumps(report, indent=2))
