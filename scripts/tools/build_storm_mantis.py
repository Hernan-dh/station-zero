"""Rebuild the Storm Mantis source and glTF with Blender's bundled Python.
blender -b --python scripts/tools/build_storm_mantis.py
Coordinates: Z up, -Y forward; glTF exports Y up, +Z forward.
The model origin is the centre of the hovering body, not the ground.
"""
import bpy
import math
import random
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'resources/models/storm_mantis'
OUT.mkdir(parents=True, exist_ok=True)
random.seed(91)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)


def mat(name, color, rough=.5, emission=0.0, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, alpha)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Roughness'].default_value = rough
    p.inputs['Alpha'].default_value = alpha
    if emission:
        p.inputs['Emission Color'].default_value = (*color, 1)
        p.inputs['Emission Strength'].default_value = emission
    if alpha < 1.0:
        m.surface_render_method = 'BLENDED'
        m.use_backface_culling = False
    return m


shell = mat('Violet chitin shell', (.115, .052, .185), .38)
shell_dark = mat('Deep violet joints', (.045, .020, .075), .55)
shell_light = mat('Pale violet plates', (.245, .130, .350), .32)
edge = mat('Iridescent edge', (.42, .26, .58), .28)
eye = mat('Cyan compound eyes', (.10, .82, 1.0), .16, 2.6)
vein = mat('Electric wing veins', (.14, .46, 1.0), .22, 1.8)
membrane = mat('Storm wing membrane', (.06, .12, .46), .30, .65, .58)
spark = mat('Crackling plasma', (.72, .92, 1.0), .12, 6.0)
claw = mat('Obsidian talons', (.055, .040, .075), .30)
parts = []


def finish(o, name, material, joint='thorax'):
    o.name = name
    o.data.materials.append(material)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if joint:
        g = o.vertex_groups.new(name=joint)
        g.add(list(range(len(o.data.vertices))), 1.0, 'REPLACE')
    parts.append(o)
    return o


def ell(name, loc, scale, material, joint='thorax', smooth=True, sub=2, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, radius=1, location=loc)
    o = bpy.context.object
    o.scale = scale
    o.rotation_euler = rotation
    finish(o, name, material, joint)
    if smooth:
        for p in o.data.polygons:
            p.use_smooth = True
    return o


def tube(name, points, radii, material, joint='thorax', sides=8):
    verts, faces = [], []
    for i, pt in enumerate(points):
        tangent = Vector(points[min(i + 1, len(points) - 1)]) - Vector(points[max(0, i - 1)])
        q = tangent.to_track_quat('Z', 'Y')
        for j in range(sides):
            a = j * math.tau / sides
            v = q @ Vector((math.cos(a) * radii[i], math.sin(a) * radii[i], 0)) + Vector(pt)
            verts.append(v)
    for i in range(len(points) - 1):
        for j in range(sides):
            a = i * sides + j
            b = i * sides + (j + 1) % sides
            faces.append((a, b, b + sides, a + sides))
    faces.extend([tuple(reversed(range(sides))), tuple((len(points) - 1) * sides + j for j in range(sides))])
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    return finish(o, name, material, joint)


def plate(name, loc, scale, material, joint='thorax', rotation=(0, 0, 0)):
    n = 7
    verts = []
    for z, r in [(0, .86), (.18, 1)]:
        for i in range(n):
            a = math.tau * i / n
            rr = r * random.uniform(.9, 1.08)
            verts.append((math.cos(a) * rr, math.sin(a) * rr, z + random.uniform(-.04, .04)))
    verts.extend([(-.14, -.22, .48), (.14, .30, .40)])
    faces = [tuple(reversed(range(n)))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, j + n, i + n))
        faces.append((i + n, j + n, 2 * n if i < 4 else 2 * n + 1))
    faces.extend([(n + 4, 2 * n + 1, 2 * n), (n, 2 * n, 2 * n + 1)])
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    o.location = loc
    o.scale = scale
    o.rotation_euler = rotation
    return finish(o, name, material, joint)


class WingFrame:
    def __init__(self, root, span, chord, length, width, camber=.07):
        self.root = Vector(root)
        self.span = Vector(span).normalized()
        self.chord = Vector(chord)
        self.chord = (self.chord - self.span * self.chord.dot(self.span)).normalized()
        self.normal = self.span.cross(self.chord).normalized()
        self.length = length
        self.width = width
        self.camber = camber

    def point(self, u, v, lift=0.0):
        w = self.width * (0.22 + 0.78 * math.sin(math.pi * u) ** 0.6)
        centre = self.root + self.span * (self.length * u) + self.normal * (self.camber * math.sin(math.pi * u))
        return centre + self.chord * (w * v) + self.normal * lift


def wing(name, side, frame, material, joint, thickness=.022, nu=12, nv=4):
    top, bottom = [], []
    for i in range(nu + 1):
        u = i / nu
        row_top, row_bot = [], []
        for j in range(nv + 1):
            v = -1.0 + 2.0 * j / nv
            lift = thickness * (1.0 - v * v)
            row_top.append(frame.point(u, v, lift))
            row_bot.append(frame.point(u, v, -lift))
        top.append(row_top)
        bottom.append(row_bot)
    verts = []
    for row in top:
        verts.extend(row)
    offset = (nu + 1) * (nv + 1)
    for row in bottom:
        verts.extend(row)

    def ti(i, j):
        return i * (nv + 1) + j

    def bi(i, j):
        return offset + i * (nv + 1) + j

    faces = []
    for i in range(nu):
        for j in range(nv):
            faces.append((ti(i, j), ti(i + 1, j), ti(i + 1, j + 1), ti(i, j + 1)))
            faces.append((bi(i, j + 1), bi(i + 1, j + 1), bi(i + 1, j), bi(i, j)))
    for i in range(nu):
        faces.append((ti(i, 0), bi(i, 0), bi(i + 1, 0), ti(i + 1, 0)))
        faces.append((ti(i + 1, nv), bi(i + 1, nv), bi(i, nv), ti(i, nv)))
    for j in range(nv):
        faces.append((ti(0, j + 1), bi(0, j + 1), bi(0, j), ti(0, j)))
        faces.append((ti(nu, j), bi(nu, j), bi(nu, j + 1), ti(nu, j + 1)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    finish(o, name, material, joint)
    for p in o.data.polygons:
        p.use_smooth = True
    # Leading-edge spar and radiating veins.
    spar = [frame.point(u, -1.0, .012) for u in [0.0, .25, .5, .75, 1.0]]
    tube(name + ' spar', spar, [.030, .024, .018, .012, .004], vein, joint)
    for v in (-0.5, 0.0, 0.5):
        rib = [frame.point(u, v, .014) for u in [0.08, .32, .60, .88]]
        tube(name + ' rib', rib, [.014, .011, .008, .004], vein, joint)
    for u in (0.42, 0.68):
        cross = [frame.point(u, v, .012) for v in (-0.9, -0.45, 0.0, 0.45, 0.9)]
        tube(name + ' crossvein', cross, [.010, .009, .008, .009, .010], vein, joint)
    return o


# Slender thorax and segmented abdomen, floating horizontally.
ell('Thorax core', (0, -.04, .05), (.30, .52, .30), shell, sub=3)
ell('Thorax underside', (0, .02, -.14), (.25, .40, .16), shell_dark)
ell('Waist', (0, .40, .01), (.20, .20, .18), shell_dark)
for i in range(6):
    y = .46 + i * .205
    z = -.02 - i * .052
    r = 1.0 - i * .075
    ell('Abdomen segment', (0, y, z), (.245 * r, .155, .205 * r), shell if i % 2 == 0 else shell_light)
    tube('Abdomen dorsal spine', [(0, y - .02, z + .17 * r), (0, y + .06, z + .26 * r), (0, y + .15, z + .30 * r)],
         [.045, .028, .003], edge, 'abdomen')
    ell('Abdomen joint glow', (0, y - .10, z + .07), (.045, .040, .050), spark, 'abdomen', sub=1)
ell('Tail spike', (0, 1.72, -.36), (.075, .16, .075), edge, 'abdomen')
ell('Tail plasma', (0, 1.80, -.40), (.045, .07, .045), spark, 'abdomen', sub=1)

# Head, crown, compound eyes and swept antennae.
ell('Neck', (0, -.47, .11), (.16, .18, .16), shell_dark, 'head')
ell('Head capsule', (0, -.74, .19), (.25, .31, .22), shell, 'head', sub=3)
plate('Crown crest', (0, -.66, .38), (.22, .26, .30), shell_light, 'head', rotation=(.55, 0, 0))
for s in (-1, 1):
    ell('Compound eye', (s * .175, -.80, .26), (.105, .115, .155), eye, 'head', rotation=(0, 0, s * .22))
    ell('Eye socket', (s * .185, -.74, .26), (.09, .08, .13), shell_dark, 'head')
    ell('Eye pupil', (s * .20, -.885, .29), (.045, .045, .075), claw, 'head', sub=1)
    tube('Mandible', [(s * .09, -.93, .10), (s * .12, -1.03, .04), (s * .06, -1.09, .01)],
         [.045, .028, .004], claw, 'head')
    tube('Antenna stalk', [(s * .11, -.88, .36), (s * .30, -.72, .62), (s * .52, -.42, .86), (s * .66, -.18, .92)],
         [.028, .020, .013, .004], shell_light, 'head')
    for k in range(3):
        p = Vector((s * (.30 + .08 * k), -.66 + .12 * k, .66 + .10 * k))
        tube('Antenna barb', [p, p + Vector((s * .10, .04, .10)), p + Vector((s * .17, .10, .16))],
             [.012, .008, .002], edge, 'head')

# Four energy wings, raised and swept back like the concept panel.
wing_specs = [
    ('Forewing', .78, .20, .62, 1.72, .56),
    ('Hindwing', .74, .40, .34, 1.16, .40),
]
for side in (-1, 1):
    suffix = 'L' if side < 0 else 'R'
    for idx, (label, sx, sy, sz, length, width) in enumerate(wing_specs):
        root = (side * .20, -.02 + idx * .16, .22 - idx * .04)
        span = (side * sx, sy, sz)
        chord = (side * .10, .95, -.16 - idx * .10)
        frame = WingFrame(root, span, chord, length, width, camber=.06 + idx * .02)
        joint = 'wing_fore_' + suffix if idx == 0 else 'wing_hind_' + suffix
        wing('Wing membrane', side, frame, membrane, joint)
        # Bright plasma beads along the wing root and tip.
        ell('Wing root plasma', frame.point(.06, -.35, .02), (.055, .05, .055), spark, joint, sub=1)
        ell('Wingtip plasma', frame.point(.97, 0.0, .01), (.04, .04, .04), spark, joint, sub=1)
    # Shoulder armour where the wings meet the body.
    for idx in range(2):
        plate('Wing shoulder plate', (side * (.22 + idx * .02), -.05 + idx * .15, .27 - idx * .04),
              (.15, .18, .16), shell_light, 'thorax', rotation=(0, side * .5, 0))

# Raptorial scythe arms folded in front of the thorax.
for side in (-1, 1):
    suffix = 'L' if side < 0 else 'R'
    joint = 'arm_' + suffix
    shoulder = (side * .27, -.30, .10)
    elbow = (side * .60, -.70, .20)
    wrist = (side * .50, -1.16, -.02)
    ell('Arm shoulder', shoulder, (.13, .13, .13), shell, joint)
    tube('Arm upper', [shoulder, elbow], [.10, .075], shell_dark, joint)
    ell('Arm elbow', elbow, (.085, .085, .085), shell_dark, joint)
    tube('Arm forearm', [elbow, wrist], [.075, .055], shell, joint)
    ell('Arm wrist', wrist, (.065, .065, .065), shell_dark, joint)
    # Long curved scythe blade with serrated inner teeth.
    blade = [wrist, (side * .55, -1.52, -.14), (side * .62, -1.90, -.30), (side * .66, -2.18, -.40)]
    tube('Scythe blade', blade, [.055, .045, .028, .002], edge, joint, 6)
    for k in range(5):
        t = .18 + k * .15
        base = Vector(wrist).lerp(Vector(blade[3]), t)
        tip = base + Vector((side * -.14, -.10, -.02))
        tube('Scythe tooth', [base, tip], [.026, .002], claw, joint, 5)
    tube('Arm elbow spur', [elbow, (side * .80, -.60, .34), (side * .90, -.48, .42)],
         [.055, .035, .002], edge, joint)

# Two pairs of folded walking legs dangling beneath the body.
leg_specs = [
    ('leg1', -.06, .30, .10, .55, .02, -.52),
    ('leg2', .34, .42, .55, .58, .46, -.58),
]
for side in (-1, 1):
    suffix = 'L' if side < 0 else 'R'
    for label, hip_y, knee_y, foot_y, knee_x, _pad, foot_z in leg_specs:
        joint = label + '_' + suffix
        hip = (side * .24, hip_y, -.14)
        knee = (side * knee_x, knee_y, -.48)
        foot = (side * (.42 if label == 'leg1' else .40), foot_y, foot_z - .28)
        ell('Leg hip', hip, (.075, .075, .075), shell_dark, joint)
        tube('Leg femur', [hip, knee], [.060, .038], shell, joint, 6)
        ell('Leg knee', knee, (.050, .050, .050), shell_light, joint, sub=1)
        tube('Leg tibia', [knee, foot], [.038, .016], shell_dark, joint, 6)
        tube('Leg claw', [foot, (foot[0] + side * .04, foot[1] - .10, foot[2] - .12)],
             [.020, .002], claw, joint, 5)

# Plasma nodules clustered at the joints for the electric read.
for side in (-1, 1):
    ell('Shoulder plasma', (side * .27, -.31, .12), (.045, .045, .045), spark, 'arm_' + ('L' if side < 0 else 'R'), sub=1)
    ell('Abdomen plasma', (side * .10, .55, .10), (.035, .035, .035), spark, 'abdomen', sub=1)

# One weighted mesh and one skeleton. Armour plates stay rigid on their limbs.
bpy.ops.object.select_all(action='DESELECT')
for p in parts:
    p.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
mesh = bpy.context.object
mesh.name = 'StormMantisMesh'
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

armdata = bpy.data.armatures.new('StormMantisSkeleton')
rig = bpy.data.objects.new('StormMantisRig', armdata)
bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
mesh.select_set(False)
rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
bones = {
    'root': ((0, 0, -.55), (0, 0, .05), None),
    'thorax': ((0, .18, -.02), (0, -.42, .06), 'root'),
    'abdomen': ((0, .40, .02), (0, 1.62, -.33), 'thorax'),
    'head': ((0, -.50, .12), (0, -.96, .20), 'thorax'),
}
for side in (-1, 1):
    suffix = 'L' if side < 0 else 'R'
    bones['wing_fore_' + suffix] = ((side * .20, -.02, .22), (side * 1.42, .30, 1.14), 'thorax')
    bones['wing_hind_' + suffix] = ((side * .20, .14, .18), (side * 1.06, .58, .62), 'thorax')
    bones['arm_' + suffix] = ((side * .27, -.30, .10), (side * .50, -1.16, -.02), 'thorax')
    bones['leg1_' + suffix] = ((side * .24, -.06, -.14), (side * .42, .30, -.80), 'thorax')
    bones['leg2_' + suffix] = ((side * .24, .34, -.14), (side * .40, .76, -.86), 'abdomen')
for name, (head, tail, parent) in bones.items():
    b = armdata.edit_bones.new(name)
    b.head = head
    b.tail = tail
    if parent:
        b.parent = armdata.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')
mod = mesh.modifiers.new('Rigid chitin skin', 'ARMATURE')
mod.object = rig
mesh.parent = rig
for b in rig.pose.bones:
    b.rotation_mode = 'XYZ'

scene = bpy.context.scene
scene.render.fps = 24
wing_bones = [n for n in bones if n.startswith('wing_')]
leg_bones = [n for n in bones if n.startswith('leg')]
for clip, duration in [('Idle', 96), ('Flight', 32)]:
    rig.animation_data_create()
    rig.animation_data.action = None
    action = bpy.data.actions.new(clip)
    rig.animation_data.action = action
    for f in range(1, duration + 2, 2):
        t = (f - 1) / duration * math.tau
        for name in bones:
            p = rig.pose.bones[name]
            p.rotation_euler = (0, 0, 0)
            p.location = (0, 0, 0)
            p.scale = (1, 1, 1)
            if clip == 'Idle':
                if name == 'root':
                    p.location.z = .045 * math.sin(t)
                if name == 'thorax':
                    p.rotation_euler.x = .025 * math.sin(t + .3)
                if name == 'abdomen':
                    p.rotation_euler.x = .05 * math.sin(t + .9)
                    p.rotation_euler.z = .03 * math.sin(t * .5)
                if name == 'head':
                    p.rotation_euler.x = .05 * math.sin(t + .5)
                if name.startswith('wing_'):
                    side = 1 if name.endswith('R') else -1
                    fore = name.startswith('wing_fore')
                    amp = .13 if fore else .10
                    p.rotation_euler.z = side * amp * math.sin(t * 2.0 + (.0 if fore else .5))
                    p.rotation_euler.x = .05 * math.sin(t * 2.0 + 1.1)
                if name.startswith('arm_'):
                    p.rotation_euler.x = .045 * math.sin(t + .6)
            else:
                if name == 'root':
                    p.location.z = .075 * math.sin(t * 2.0)
                if name == 'thorax':
                    p.rotation_euler.x = .10 + .04 * math.sin(t * 2.0)
                if name == 'abdomen':
                    p.rotation_euler.x = -.06 + .05 * math.sin(t * 2.0 + .6)
                    p.rotation_euler.z = .04 * math.sin(t)
                if name == 'head':
                    p.rotation_euler.x = -.08 + .04 * math.sin(t * 2.0)
                if name.startswith('wing_'):
                    side = 1 if name.endswith('R') else -1
                    fore = name.startswith('wing_fore')
                    amp = .58 if fore else .48
                    p.rotation_euler.z = side * amp * math.sin(t * 2.0 + (.0 if fore else .35))
                    p.rotation_euler.x = .12 * math.sin(t * 2.0 + 1.2)
                if name.startswith('arm_'):
                    p.rotation_euler.x = -.16 + .05 * math.sin(t * 2.0 + .4)
                if name.startswith('leg'):
                    p.rotation_euler.x = .10 * math.sin(t * 2.0 + (0 if name.endswith('R') else math.pi))
            p.keyframe_insert('rotation_euler', frame=f, group=name)
            p.keyframe_insert('location', frame=f, group=name)
            p.keyframe_insert('scale', frame=f, group=name)
    track = rig.animation_data.nla_tracks.new()
    track.name = clip
    track.strips.new(clip, 1, action)
    rig.animation_data.action = None
    track.mute = True

for p in rig.pose.bones:
    p.rotation_euler = (0, 0, 0)
    p.location = (0, 0, 0)
    p.scale = (1, 1, 1)
for track in rig.animation_data.nla_tracks:
    track.mute = False
scene.frame_set(1)
scene.frame_end = 96

source = OUT / 'source'
source.mkdir(exist_ok=True)
(source / '.gdignore').touch()
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(source / 'storm_mantis.blend'))
bpy.ops.export_scene.gltf(
    filepath=str(OUT / 'storm_mantis.glb'),
    export_format='GLB',
    export_animations=True,
    export_animation_mode='NLA_TRACKS',
    export_force_sampling=True,
    export_anim_slide_to_zero=True,
)
print('STORM_MANTIS_BUILT', len(mesh.data.vertices), 'vertices', len(mesh.data.polygons), 'faces')
