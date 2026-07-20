import bpy
import math
import os
import json
from mathutils import Vector


OUTPUT_DIR = r"C:\tmp\Spinfusor_Blockout"
BLEND_PATH = os.path.join(OUTPUT_DIR, "WP_Spinfusor_Blockout_v01.blend")
os.makedirs(OUTPUT_DIR, exist_ok=True)


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        pass


def make_material(name, base_color, metallic, roughness, emission=None, emission_strength=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*base_color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission is not None:
        emission_input = bsdf.inputs.get("Emission Color") or bsdf.inputs.get("Emission")
        if emission_input:
            emission_input.default_value = (*emission, 1.0)
        strength_input = bsdf.inputs.get("Emission Strength")
        if strength_input:
            strength_input.default_value = emission_strength
    return mat


def add_modifiers(obj, bevel_width=0.055, bevel_segments=2):
    mirror = obj.modifiers.new("Mirror_X", "MIRROR")
    mirror.use_axis[0] = True
    mirror.use_clip = True
    mirror.use_mirror_merge = True
    mirror.merge_threshold = 0.0001

    bevel = obj.modifiers.new("Bevel_Blockout", "BEVEL")
    bevel.width = bevel_width
    bevel.segments = bevel_segments
    bevel.limit_method = "ANGLE"
    bevel.angle_limit = math.radians(28.0)

    try:
        weighted = obj.modifiers.new("Weighted_Normal", "WEIGHTED_NORMAL")
        weighted.keep_sharp = True
        weighted.weight = 50
    except Exception as exc:
        raise RuntimeError("Weighted-Normal modifier is required but unavailable: %s" % exc)

    for poly in obj.data.polygons:
        poly.use_smooth = True


def append_half_prism_geometry(verts, faces, profile, half_width):
    start = len(verts)
    count = len(profile)
    verts.extend((0.0, y, z) for y, z in profile)
    verts.extend((half_width, y, z) for y, z in profile)

    # Visible outer side. The X=0 face stays open so Mirror_X can merge it.
    faces.append(tuple(start + count + i for i in range(count)))
    for i in range(count):
        nxt = (i + 1) % count
        faces.append((start + i, start + nxt, start + count + nxt, start + count + i))


def create_half_prism(name, profiles, half_width, material, bevel=0.055):
    if profiles and isinstance(profiles[0][0], (int, float)):
        profiles = [profiles]
    verts = []
    faces = []
    for profile in profiles:
        append_half_prism_geometry(verts, faces, profile, half_width)

    mesh = bpy.data.meshes.new(name + "_Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    weapon_collection.objects.link(obj)
    obj.data.materials.append(material)
    add_modifiers(obj, bevel)
    return obj


def create_half_cylinder(name, center_y, center_z, radius, half_width, segments, material, bevel=0.035):
    profile = []
    for index in range(segments):
        angle = (index / segments) * math.tau
        profile.append((center_y + math.cos(angle) * radius, center_z + math.sin(angle) * radius))
    return create_half_prism(name, profile, half_width, material, bevel)


def create_surface_torus(name, center_y, center_z, major_radius, minor_radius, side_offset, minor_segments, major_segments, material):
    verts = []
    faces = []
    rows = minor_segments

    # A complete ring sits on the +X chamber face. Mirror_X creates the matching
    # ring on the opposite side while both retain a shared axle at X=0.
    for major_index in range(major_segments):
        theta = major_index / major_segments * math.tau
        for minor_index in range(minor_segments):
            phi = minor_index / minor_segments * math.tau
            radial = major_radius + minor_radius * math.sin(phi)
            x = side_offset + minor_radius * math.cos(phi)
            y = center_y + math.cos(theta) * radial
            z = center_z + math.sin(theta) * radial
            verts.append((x, y, z))

    for major_index in range(major_segments):
        next_major = (major_index + 1) % major_segments
        for minor_index in range(minor_segments):
            next_minor = (minor_index + 1) % minor_segments
            a = major_index * rows + minor_index
            b = next_major * rows + minor_index
            c = next_major * rows + next_minor
            d = major_index * rows + next_minor
            faces.append((a, b, c, d))

    mesh = bpy.data.meshes.new(name + "_Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    weapon_collection.objects.link(obj)
    obj.data.materials.append(material)
    add_modifiers(obj, bevel_width=0.018, bevel_segments=1)
    return obj


def append_box_geometry(verts, faces, x_min, x_max, y_min, y_max, z_min, z_max):
    start = len(verts)
    verts.extend([
        (x_min, y_min, z_min), (x_max, y_min, z_min),
        (x_max, y_max, z_min), (x_min, y_max, z_min),
        (x_min, y_min, z_max), (x_max, y_min, z_max),
        (x_max, y_max, z_max), (x_min, y_max, z_max),
    ])
    faces.extend([
        (start + 0, start + 1, start + 2, start + 3),
        (start + 4, start + 7, start + 6, start + 5),
        (start + 0, start + 4, start + 5, start + 1),
        (start + 1, start + 5, start + 6, start + 2),
        (start + 2, start + 6, start + 7, start + 3),
        (start + 4, start + 0, start + 3, start + 7),
    ])


def create_muzzle_frame(name, material):
    verts = []
    faces = []
    # Positive-X half: upper/lower beams plus an outer side beam. Mirror_X
    # supplies the negative-X half and leaves a clear central aperture.
    append_box_geometry(verts, faces, 0.0, 0.60, -2.75, -2.48, 0.25, 0.43)
    append_box_geometry(verts, faces, 0.0, 0.60, -2.75, -2.48, -0.43, -0.25)
    append_box_geometry(verts, faces, 0.47, 0.60, -2.75, -2.48, -0.25, 0.25)
    mesh = bpy.data.meshes.new(name + "_Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    weapon_collection.objects.link(obj)
    obj.data.materials.append(material)
    add_modifiers(obj, bevel_width=0.045, bevel_segments=2)
    return obj


def apply_transforms(obj):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.select_set(False)


def set_origin(obj, location):
    bpy.context.scene.cursor.location = location
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR", center="MEDIAN")
    obj.select_set(False)


def look_at(obj, target, up_axis="Y"):
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", up_axis).to_euler()


def add_area_light(name, location, energy, size, color):
    data = bpy.data.lights.new(name + "_Data", type="AREA")
    data.energy = energy
    data.shape = "DISK"
    data.size = size
    data.color = color
    obj = bpy.data.objects.new(name, data)
    render_collection.objects.link(obj)
    obj.location = location
    look_at(obj, (0.0, 0.0, 0.0))
    return obj


def add_camera():
    data = bpy.data.cameras.new("BlockoutCamera_Data")
    obj = bpy.data.objects.new("BlockoutCamera", data)
    render_collection.objects.link(obj)
    bpy.context.scene.camera = obj
    return obj


def evaluated_triangles(obj, depsgraph):
    evaluated = obj.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    mesh.calc_loop_triangles()
    count = len(mesh.loop_triangles)
    evaluated.to_mesh_clear()
    return count


def evaluated_bounds(objects, depsgraph):
    points = []
    for obj in objects:
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        points.extend(evaluated.matrix_world @ vertex.co for vertex in mesh.vertices)
        evaluated.to_mesh_clear()
    mins = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    maxs = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    return mins, maxs, maxs - mins


def render_view(camera, name, location, target, projection, ortho_scale=None, lens=60.0, roll=0.0):
    camera.location = location
    camera.data.type = projection
    if projection == "ORTHO":
        camera.data.ortho_scale = ortho_scale
    else:
        camera.data.lens = lens
    look_at(camera, target)
    if roll:
        camera.rotation_euler.rotate_axis("Z", math.radians(roll))
    scene.render.filepath = os.path.join(OUTPUT_DIR, "WP_Spinfusor_Blockout_%s.png" % name)
    bpy.ops.render.render(write_still=True)


clear_scene()

scene = bpy.context.scene
scene.unit_settings.system = "METRIC"
scene.unit_settings.scale_length = 1.0
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 1400
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.film_transparent = False
scene.render.image_settings.color_depth = "8"
scene.view_settings.look = "AgX - Medium High Contrast"
scene.world.color = (0.025, 0.03, 0.04)

weapon_collection = bpy.data.collections.new("WP_Spinfusor_Blockout")
scene.collection.children.link(weapon_collection)
render_collection = bpy.data.collections.new("RENDER_SETUP")
scene.collection.children.link(render_collection)

graphite = make_material("MAT_Graphite", (0.055, 0.068, 0.082), 0.74, 0.3)
ivory = make_material("MAT_Ivory", (0.63, 0.59, 0.49), 0.58, 0.27)
orange = make_material("MAT_Orange_Emission", (0.52, 0.035, 0.008), 0.28, 0.2, (1.0, 0.055, 0.004), 8.0)

# Major silhouettes only. Weapon length is exactly -2.75 to +2.75 along Y.
main_body = create_half_prism(
    "WP_MainBody",
    [
        (-1.58, 0.42), (-1.38, 0.66), (-0.62, 0.78), (0.48, 0.68),
        (1.08, 0.39), (1.16, 0.10), (1.04, -0.38), (0.52, -0.58),
        (-0.72, -0.60), (-1.48, -0.38),
    ],
    0.54,
    graphite,
    0.07,
)

barrel = create_half_prism(
    "WP_Barrel",
    [(-2.58, 0.21), (-0.72, 0.24), (-0.62, 0.06), (-0.72, -0.20), (-2.58, -0.18)],
    0.27,
    orange,
    0.035,
)

muzzle = create_half_prism(
    "WP_Muzzle",
    [(-2.55, 0.55), (-1.55, 0.50), (-1.22, 0.32), (-1.25, -0.35), (-1.62, -0.55), (-2.55, -0.50)],
    0.55,
    graphite,
    0.065,
)

disc_chamber = create_half_cylinder(
    "WP_DiscChamber", -0.25, 0.07, 0.735, 0.625, 24, graphite, 0.045
)

energy_ring = create_surface_torus(
    "WP_EnergyRing", -0.25, 0.07, 0.545, 0.032, 0.64, 6, 24, orange
)

upper_armor = create_half_prism(
    "WP_UpperArmor",
    [
        (-1.85, 0.48), (-1.50, 0.72), (-0.72, 0.855), (0.24, 0.80),
        (0.86, 0.59), (0.62, 0.42), (-0.32, 0.58), (-1.47, 0.38),
    ],
    0.64,
    ivory,
    0.055,
)

lower_armor = create_half_prism(
    "WP_LowerArmor",
    [
        (-1.88, -0.32), (-1.52, -0.61), (-0.76, -0.855), (0.40, -0.76),
        (0.82, -0.52), (0.52, -0.34), (-0.54, -0.55), (-1.56, -0.27),
    ],
    0.64,
    ivory,
    0.055,
)

grip = create_half_prism(
    "WP_Grip",
    [(0.98, 0.03), (1.34, -0.02), (1.76, -0.47), (1.54, -0.70), (1.22, -0.54), (0.93, -0.20)],
    0.34,
    graphite,
    0.055,
)

rear_brace = create_half_prism(
    "WP_RearBrace",
    [
        [(1.03, 0.56), (2.48, 0.55), (2.75, 0.35), (2.75, 0.16), (2.43, 0.24), (1.02, 0.36)],
        [(2.48, 0.55), (2.75, 0.35), (2.75, -0.34), (2.48, -0.50), (2.35, -0.28), (2.48, 0.25)],
        [(1.06, -0.38), (2.42, -0.50), (2.75, -0.34), (2.72, -0.10), (2.39, -0.22), (1.04, -0.20)],
    ],
    0.53,
    ivory,
    0.055,
)

front_support = create_half_prism(
    "WP_FrontSupport",
    [(0.22, -0.48), (0.55, -0.69), (1.25, -0.57), (1.04, -0.34), (0.56, -0.43)],
    0.59,
    ivory,
    0.05,
)

muzzle_attachment = create_muzzle_frame("WP_MuzzleAttachment", graphite)

weapon_objects = [
    main_body, barrel, muzzle, disc_chamber, energy_ring, upper_armor,
    lower_armor, grip, rear_brace, front_support, muzzle_attachment,
]

for obj in weapon_objects:
    apply_transforms(obj)

# The two rotating modules share their own exact axle at the chamber center.
set_origin(disc_chamber, (0.0, -0.25, 0.07))
set_origin(energy_ring, (0.0, -0.25, 0.07))

# Neutral studio ground and lighting, isolated in RENDER_SETUP.
ground_mat = make_material("MAT_RenderGround", (0.055, 0.06, 0.07), 0.0, 0.72)
bpy.ops.mesh.primitive_plane_add(size=18.0, location=(0.0, 0.0, -0.875))
ground = bpy.context.object
ground.name = "RenderGround"
for collection in list(ground.users_collection):
    collection.objects.unlink(ground)
render_collection.objects.link(ground)
ground.data.materials.append(ground_mat)

add_area_light("Key_Area", (-4.5, -4.0, 6.0), 1250.0, 5.5, (1.0, 0.84, 0.68))
add_area_light("Fill_Area", (5.0, 1.5, 3.0), 900.0, 4.5, (0.42, 0.58, 1.0))
add_area_light("Rim_Area", (0.0, 5.5, 4.5), 1100.0, 3.5, (1.0, 0.28, 0.08))

camera = add_camera()
render_view(camera, "Side", (9.0, 0.0, 0.25), (0.0, 0.0, 0.0), "ORTHO", 6.35)
render_view(camera, "Top", (0.0, 0.0, 10.0), (0.0, 0.0, 0.0), "ORTHO", 6.35, roll=90.0)
render_view(camera, "Front", (0.0, -9.0, 0.05), (0.0, -0.25, 0.0), "ORTHO", 2.2)
render_view(camera, "ThreeQuarter", (7.6, -7.4, 4.8), (0.0, -0.15, 0.0), "PERSP", lens=64.0)

depsgraph = bpy.context.evaluated_depsgraph_get()
triangles_by_object = {obj.name: evaluated_triangles(obj, depsgraph) for obj in weapon_objects}
mins, maxs, dimensions = evaluated_bounds(weapon_objects, depsgraph)

expected_names = {
    "WP_MainBody", "WP_Barrel", "WP_Muzzle", "WP_DiscChamber", "WP_EnergyRing",
    "WP_UpperArmor", "WP_LowerArmor", "WP_Grip", "WP_RearBrace",
    "WP_FrontSupport", "WP_MuzzleAttachment",
}
actual_names = {obj.name for obj in weapon_objects}
modifier_audit = {
    obj.name: [modifier.type for modifier in obj.modifiers]
    for obj in weapon_objects
}

report = {
    "blend_file": BLEND_PATH,
    "object_names_valid": actual_names == expected_names,
    "objects": sorted(actual_names),
    "dimensions_xyz": [round(dimensions.x, 4), round(dimensions.y, 4), round(dimensions.z, 4)],
    "bounds_min_xyz": [round(mins.x, 4), round(mins.y, 4), round(mins.z, 4)],
    "bounds_max_xyz": [round(maxs.x, 4), round(maxs.y, 4), round(maxs.z, 4)],
    "length_along_y": round(dimensions.y, 4),
    "max_width_x": round(dimensions.x, 4),
    "max_height_z": round(dimensions.z, 4),
    "triangles_by_object": triangles_by_object,
    "triangles_total": sum(triangles_by_object.values()),
    "modifier_audit": modifier_audit,
    "disc_origin": [round(value, 4) for value in disc_chamber.location],
    "energy_ring_origin": [round(value, 4) for value in energy_ring.location],
    "materials": [graphite.name, ivory.name, orange.name],
}

if abs(report["length_along_y"] - 5.5) > 0.015:
    raise RuntimeError("Length check failed: %s" % report["length_along_y"])
if report["max_width_x"] > 1.35 + 0.001:
    raise RuntimeError("Width check failed: %s" % report["max_width_x"])
if report["max_height_z"] > 1.75 + 0.001:
    raise RuntimeError("Height check failed: %s" % report["max_height_z"])
if report["triangles_total"] > 8000:
    raise RuntimeError("Triangle budget failed: %s" % report["triangles_total"])
for name, modifiers in modifier_audit.items():
    for required in ("MIRROR", "BEVEL", "WEIGHTED_NORMAL"):
        if required not in modifiers:
            raise RuntimeError("%s missing %s" % (name, required))

with open(os.path.join(OUTPUT_DIR, "blockout_report.json"), "w", encoding="utf-8") as handle:
    json.dump(report, handle, indent=2)

# Save only after all validation checks passed.
bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
print(json.dumps(report, indent=2))
