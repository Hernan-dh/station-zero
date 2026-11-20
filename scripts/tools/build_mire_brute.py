"""Rebuild the Mire Brute source and glTF with Blender's bundled Python.
blender -b --python scripts/tools/build_mire_brute.py
Coordinates: Z up, -Y forward; glTF exports Y up, +Z forward.
"""
import bpy
import math
import random
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'resources/models/mire_brute'
OUT.mkdir(parents=True, exist_ok=True)
random.seed(57)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)


def mat(name, color, rough=.8, emission=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Roughness'].default_value = rough
    if emission:
        p.inputs['Emission Color'].default_value = (*color, 1)
        p.inputs['Emission Strength'].default_value = emission
    return m

hide = mat('Creased charcoal hide', (.052, .046, .060))
fold = mat('Deep folds and sockets', (.025, .032, .022))
plates = [mat('Basalt carapace %02d' % i, c) for i, c in enumerate([
    (.105,.093,.115), (.15,.137,.15), (.075,.068,.082), (.18,.165,.17), (.12,.105,.145)])]
edge = mat('Weathered horn', (.43,.405,.29))
bone = mat('Old ivory claws', (.64,.63,.39))
moss = mat('Olive lichen', (.065,.095,.023))
acid = mat('Bioluminescent venom', (.19,.64,.008), .32, 1.15)
bright = mat('Venom highlights and eyes', (.4,.95,.025), .26, 1.7)
sac = mat('Toxic gland membrane', (.22,.40,.025), .38)
parts = []


def finish(o, name, material, joint='chest'):
    o.name = name
    o.data.materials.append(material)
    # Apply geometry transforms before assigning rigid skin weights.
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if joint:
        g = o.vertex_groups.new(name=joint)
        g.add(list(range(len(o.data.vertices))), 1.0, 'REPLACE')
    parts.append(o)
    return o


def ell(name, loc, scale, material, joint='chest', smooth=False, sub=2):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, radius=1, location=loc)
    o = bpy.context.object
    o.scale = scale
    finish(o, name, material, joint)
    if smooth:
        for p in o.data.polygons: p.use_smooth = True
    return o


def tube(name, points, radii, material, joint='chest', sides=8):
    verts, faces = [], []
    for i, pt in enumerate(points):
        tangent = Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)])
        q = tangent.to_track_quat('Z','Y')
        for j in range(sides):
            a = j*math.tau/sides
            v = q @ Vector((math.cos(a)*radii[i], math.sin(a)*radii[i], 0)) + Vector(pt)
            verts.append(v)
    for i in range(len(points)-1):
        for j in range(sides):
            a=i*sides+j; b=i*sides+(j+1)%sides
            faces.append((a,b,b+sides,a+sides))
    faces.extend([tuple(reversed(range(sides))), tuple((len(points)-1)*sides+j for j in range(sides))])
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces); mesh.update()
    o = bpy.data.objects.new(name, mesh); bpy.context.collection.objects.link(o)
    return finish(o, name, material, joint)


def plate(name, loc, scale, joint='chest', rotation=(0,0,0), material=None):
    # Uneven thick perimeter, a broken shoulder and a raised central ridge.
    n = 7
    verts=[]
    for z, r in [(0,.86),(.16,1)]:
        for i in range(n):
            a=math.tau*i/n
            rr=r*random.uniform(.89,1.10)
            verts.append((math.cos(a)*rr, math.sin(a)*rr,z+random.uniform(-.045,.045)))
    verts.extend([(-.13,-.19,.50),(.13,.30,.42)])
    faces=[tuple(reversed(range(n)))]
    for i in range(n):
        j=(i+1)%n
        faces.append((i,j,j+n,i+n))
        faces.append((i+n,j+n,2*n if i<4 else 2*n+1))
    faces.extend([(n+4,2*n+1,2*n),(n,2*n,2*n+1)])
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(verts,[],faces); mesh.update()
    o=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(o)
    o.location=loc; o.scale=scale; o.rotation_euler=rotation
    return finish(o,name,material or random.choice(plates),joint)

# Massive sloping torso; short hips behind a high shoulder girdle.
ell('Hunched torso', (0,.25,1.68), (1.02,1.28,.99), hide, smooth=True, sub=3)
ell('Shoulder mass', (0,-.31,2.02), (1.24,.83,.80), hide, smooth=True)
ell('Haunch', (0,1.03,1.25), (.88,.85,.78), hide, 'hips', smooth=True)
for i in range(5):
    y=-.66+i*.34
    plate('Overlapping spine shield', (0,y,2.52-abs(y-.15)*.10), (.69,.53,.63), rotation=(.12,0,.05*(-1)**i))
    tube('Dorsal thorn',[(0,y+.08,2.66),(0,y+.30,3.05),(0,y+.45,3.18)], [.16,.11,.005],plates[2])
for s in [-1,1]:
    # Lower rib folds expose venom through the armored shell.
    for i in range(4):
        ell('Belly rib', (s*.67,-.12+i*.32,1.28),(.18,.19,.47),fold)
        tube('Venom between ribs',[(s*.80,-.10+i*.32,1.16),(s*.86,-.12+i*.32,1.45),(s*.82,-.15+i*.32,1.64)],[.033,.045,.025],acid)
    for row in range(4):
        for i in range(3):
            plate('Flank shingle',(s*(.65+row*.13),.15+i*.45,2.31-row*.23),(.40,.43,.40),rotation=(0,s*(.45+row*.32),s*.1))
    # Hind legs folded under the body, oversized front arms carry the weight.
    for label, a,b,c,rad in [
        ('Arm',(s*1.03,-.43,2.05),(s*1.43,-.70,1.18),(s*1.56,-1.32,.39),.43),
        ('Leg',(s*.65,1.04,1.31),(s*1.12,1.28,.64),(s*1.14,.68,.25),.34)]:
        j=label.lower()+('_L' if s<0 else '_R')
        ell(label+' shoulder',a,(rad*1.3,rad*1.3,rad*1.4),hide,j,smooth=True)
        tube(label+' sinew',[a,b,c],[rad,rad*.84,rad*.72],hide,j,10)
        ell(label+' elbow',b,(rad,rad,rad),fold,j)
        for t in [.18,.50,.76]:
            p=Vector(a).lerp(Vector(b),t)
            p.x+=s*.13
            plate(label+' layered armor',p,(rad*1.12,rad*1.15,rad),j,rotation=(.32,s*.62,-s*.3))
        for t in [.26,.64]:
            p=Vector(b).lerp(Vector(c),t); p.z+=.13
            plate(label+' forearm shield',p,(rad*.9,rad*1.3,rad*.8),j,rotation=(.60,s*.30,0))
        ell(label+' broad palm',c,(rad*1.1,rad*1.2,.23),hide,j)
        plate(label+' knuckle shield',(c[0],c[1],c[2]+.13),(rad*1.2,rad,.48),j)
        for finger in range(3):
            x=c[0]+(finger-1)*rad*.62
            y=c[1]-.21
            length=.45 if label=='Arm' else .32
            tube(label+' thick digit',[(x,y,c[2]),(x,y-.22,.18),(x,y-.34,.15)],[.13,.115,.09],plates[1],j)
            tube(label+' hooked talon',[(x,y-.29,.19),(x,y-.43,.16),(x,y-length-.17,.055)],[.095,.065,.002],bone,j)
        # Outward elbow spur.
        tube(label+' spur',[b,(b[0]+s*.34,b[1]+.12,b[2]+.15),(b[0]+s*.47,b[1]+.28,b[2]+.30)],[.14,.09,.003],edge,j)
    # Shoulder fans wrap the exposed upper arm in thick stone scales.
    for q in range(3):
        plate('Shoulder mantle',(s*(1.10+q*.10),-.48,2.29-q*.20),(.43,.50,.40),'arm_'+('L' if s<0 else 'R'),rotation=(.18,s*(.5+q*.3),s*.2))
    # Rear shell follows the round haunch instead of ending at the spine.
    for q in range(3):
        plate('Rear carapace',(s*.42,1.36+q*.12,2.07-q*.23),(.45,.49,.36),'hips',rotation=(-.5-q*.25,s*.25,0))
    # Green shoulder glands: organic swollen membranes surrounded by rock petals.
    for k,(y,z,r) in enumerate([(-.42,2.28,.37),(.25,2.43,.32),(.93,2.24,.24)]):
        x=s*(1.01 if k<2 else .84)
        ell('Swollen toxin gland',(x,y,z),(r,r*.92,r),sac,sub=3,smooth=True)
        ell('Luminous gland heart',(x+s*r*.20,y-.08,z+.08),(r*.83,r*.74,r*.75),acid,smooth=True)
        # Dark pores avoid a featureless neon ball.
        for q in range(3):
            p=(x+s*(.10+.065*q),y-.20+q*.13,z+.17)
            ell('Gland pore',p,(.065,.06,.055),fold)
        for q in range(4):
            a=q*math.tau/4
            plate('Gland armor rim',(x+math.cos(a)*r*.85,y+math.sin(a)*r*.85,z-.13),(.18,.23,.22),rotation=(0,s*.5,a))
        for q in range(3):
            ell('Gland blister',(x+s*r*.62,y+(q-1)*.11,z+.15),(.06,.065,.07),bright,smooth=True,sub=1)
# Crocodilian skull pushed forward; separate jaw and a dark visible gape.
ell('Neck',(0,-.93,1.98),(.72,.65,.63),fold,'head')
ell('Long angular skull',(0,-1.31,2.06),(.67,.82,.49),plates[2],'head',sub=2)
ell('Mouth interior',(0,-1.77,1.79),(.51,.49,.25),fold,'head')
ell('Venom tongue',(0,-1.87,1.66),(.33,.32,.055),acid,'jaw')
ell('Lower jaw',(0,-1.64,1.52),(.51,.63,.15),plates[2],'jaw')
plate('Snout roof',(0,-1.77,2.06),(.53,.58,.38),'head',rotation=(.10,0,0),material=plates[1])
for s in [-1,1]:
    plate('Cheek armor',(s*.49,-1.26,1.98),(.30,.55,.46),'head',rotation=(0,s*.9,s*.1))
    ell('Deep eye socket',(s*.50,-1.59,2.17),(.19,.25,.14),fold,'head')
    o=ell('Narrow venom eye',(s*.555,-1.68,2.18),(.065,.155,.065),bright,'head',smooth=True)
    o.rotation_euler[0]=-.25
    plate('Heavy brow',(s*.46,-1.49,2.29),(.26,.43,.27),'head',rotation=(.1,s*.35,s*.3))
    tube('Swept temple horn',[(s*.49,-1.00,2.30),(s*.68,-.77,2.67),(s*.58,-.51,2.87)],[.19,.12,.002],plates[3],'head')
    for i in range(7):
        y=-2.10+i*.14
        x=s*(.30+(.16*math.sin(i/6*math.pi)))
        top=1.96+(.05 if i>3 else 0)
        length=.24+(.11 if i in [1,4] else 0)
        tube('Upper interlocking fang',[(x,y,top),(x*.96,y-.035,top-.12),(x*.91,y-.02,top-length)],[.072,.048,.002],bone,'head')
        if i<6:
            tube('Lower venom stained tooth',[(x,y+.06,1.58),(x*.96,y+.04,1.70),(x*.94,y+.05,1.81)],[.06,.037,.002],acid if i%3==0 else bone,'jaw')
    ell('Nostril',(s*.25,-2.211,2.08),(.075,.027,.045),fold,'head')
    # Crawling root tendrils over the rear shell.
    for i in range(3):
        y=.25+i*.38
        tube('Twisted bog root',[(s*.56,y,2.53),(s*.88,y+.16,2.80),(s*.99,y+.43,2.98),(s*.80,y+.55,3.05),(s*.68,y+.43,2.91)],[.10,.085,.063,.037,.003],moss)
# Tall clustered ruptured vents on the back.
for x,y,r,h in [(0,.45,.23,.61),(-.34,.78,.17,.42),(.28,1.02,.19,.44)]:
    z=2.60
    tube('Ruptured toxin chimney',[(x,y,z-.08),(x-.04,y,z+h*.60),(x+.04,y,z+h)],[r*1.25,r,r*.78],plates[2])
    ell('Chimney venom opening',(x+.04,y,z+h), (r*.69,r*.69,.055),bright)
    for i in range(3):
        a=i*math.tau/3
        tube('Broken vent tooth',[(x+math.cos(a)*r*.8,y+math.sin(a)*r*.8,z+h-.12),(x+math.cos(a)*r,y+math.sin(a)*r,z+h+.11)],[.065,.003],edge)
# Sparse lichen chips across armor, deliberately subdued beside the glands.
for i in range(32):
    x=random.uniform(-.8,.8); y=random.uniform(-.3,1.5)
    z=2.59-abs(x)*.24-abs(y-.2)*.14
    ell('Lichen fleck',(x,y,z),(.055,.085,.024),moss,sub=1)

# One weighted mesh, one skeleton. Each armor segment follows its limb without bending stone.
bpy.ops.object.select_all(action='DESELECT')
for p in parts: p.select_set(True)
bpy.context.view_layer.objects.active=parts[0]
bpy.ops.object.join()
mesh=bpy.context.object; mesh.name='MireBruteMesh'
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
armdata=bpy.data.armatures.new('MireBruteSkeleton')
rig=bpy.data.objects.new('MireBruteRig',armdata); bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active=rig; mesh.select_set(False); rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
bones={
    'root':((0,0,0),(0,0,.5),None),
    'chest':((0,.2,1.45),(0,.2,2.25),'root'),
    'hips':((0,.75,1.25),(0,1.05,1.65),'chest'),
    'head':((0,-.83,2.02),(0,-1.65,2.02),'chest'),
    'jaw':((0,-1.14,1.59),(0,-1.90,1.54),'head'),
}
for s,side in [(-1,'L'),(1,'R')]:
    bones['arm_'+side]=((s*1.03,-.43,2.05),(s*1.56,-1.32,.39),'chest')
    bones['leg_'+side]=((s*.65,1.04,1.31),(s*1.14,.68,.25),'hips')
for name,(head,tail,parent) in bones.items():
    b=armdata.edit_bones.new(name); b.head=head; b.tail=tail
    if parent: b.parent=armdata.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')
mod=mesh.modifiers.new('Rigid carapace skin','ARMATURE'); mod.object=rig
mesh.parent=rig
for b in rig.pose.bones: b.rotation_mode='XYZ'
scene=bpy.context.scene; scene.render.fps=24
# Two named reusable clips, baked to glTF by NLA tracks.
for clip,duration in [('Idle',96),('Lumber',48)]:
    rig.animation_data_create(); rig.animation_data.action=None
    action=bpy.data.actions.new(clip); rig.animation_data.action=action
    for f in range(1,duration+2,4):
        t=(f-1)/duration*math.tau
        for name in bones:
            p=rig.pose.bones[name]; p.rotation_euler=(0,0,0); p.location=(0,0,0)
            if clip=='Idle':
                if name=='chest': p.scale=(1+.012*math.sin(t),1+.012*math.sin(t),1+.018*math.sin(t))
                if name=='head': p.rotation_euler.x=.018*math.sin(t+.5)
                if name=='jaw': p.rotation_euler.x=.035+.028*math.sin(t+.4)
            else:
                if name=='chest': p.location.z=.055*math.cos(t*2); p.rotation_euler.y=.035*math.sin(t)
                if name.startswith(('arm','leg')):
                    phase=0 if name.endswith('L') else math.pi
                    if name.startswith('leg'): phase+=math.pi
                    p.rotation_euler.x=.12*math.sin(t+phase)
                if name=='head': p.rotation_euler.x=.035*math.cos(t*2)
            p.keyframe_insert('rotation_euler',frame=f,group=name)
            p.keyframe_insert('location',frame=f,group=name)
            p.keyframe_insert('scale',frame=f,group=name)
    track=rig.animation_data.nla_tracks.new(); track.name=clip
    track.strips.new(clip,1,action)
    rig.animation_data.action=None
    track.mute=True
# Reset the default pose before saving and export each NLA track independently.
for p in rig.pose.bones:
    p.rotation_euler=(0,0,0); p.location=(0,0,0); p.scale=(1,1,1)
for track in rig.animation_data.nla_tracks: track.mute=False
scene.frame_set(1)
scene.frame_end=96
source = OUT / 'source'
source.mkdir(exist_ok=True)
(source / '.gdignore').touch()
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(source/'mire_brute.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'mire_brute.glb'),export_format='GLB',export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_anim_slide_to_zero=True)
print('MIRE_BRUTE_BUILT',len(mesh.data.vertices),'vertices',len(mesh.data.polygons),'faces')
