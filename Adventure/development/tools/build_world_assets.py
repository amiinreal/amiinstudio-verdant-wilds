"""Stylized gap assets, produced in Blender. Gameplay remains in GDScript."""
import bpy, math, random, sys
from pathlib import Path
from mathutils import Vector

HERE=Path(__file__).resolve()
OUT=(HERE.parents[2]/'generated') if HERE.parent.name=='tools' else (HERE.parent/'Adventure'/'generated')
OUT.mkdir(parents=True,exist_ok=True)
random.seed(431)
def material(name,color,rough=.86):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    shader=m.node_tree.nodes.get('Principled BSDF'); shader.inputs['Base Color'].default_value=(*color,1); shader.inputs['Roughness'].default_value=rough
    return m
wood=material('Warm oak',(.30,.16,.075)); edge=material('Cut timber',(.43,.26,.12)); metal=material('Forged iron',(.19,.23,.24),.47)
rope=material('Hemp',(.43,.35,.19)); stone=[material('Weathered stone '+str(i),c) for i,c in enumerate([(.31,.36,.33),(.38,.42,.36),(.42,.45,.38),(.26,.30,.29)])]
def clear():
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
def beam(name,a,b,width,depth,mat,bevel=.025):
    a,b=Vector(a),Vector(b)
    bpy.ops.mesh.primitive_cube_add(size=1,location=(a+b)/2); o=bpy.context.object; o.name=name
    o.dimensions=(width,depth,(b-a).length); o.rotation_mode='QUATERNION'; o.rotation_quaternion=(b-a).to_track_quat('Z','Y')
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); o.data.materials.append(mat)
    if bevel:
        mod=o.modifiers.new('Soft worked edges','BEVEL'); mod.width=bevel; mod.segments=2
        o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
    return o
def export(name):
    for o in list(bpy.context.scene.objects):
        if o.type!='MESH': continue
        bpy.context.view_layer.objects.active=o; o.select_set(True)
        for mod in list(o.modifiers): bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    bpy.ops.object.select_all(action='SELECT')
    meshes=[o for o in bpy.context.selected_objects if o.type=='MESH']
    if meshes:
        bpy.context.view_layer.objects.active=meshes[0]
        bpy.ops.object.join()
        bpy.context.object.name=name
        bpy.context.scene.cursor.location=(0,0,0)
        bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_materials='EXPORT')
    print('ASSET_EXPORTED',name)
def mesh(name,verts,faces,mats):
    data=bpy.data.meshes.new(name); data.from_pydata(verts,[],faces); data.update(); obj=bpy.data.objects.new(name,data); bpy.context.collection.objects.link(obj)
    for m in mats: data.materials.append(m)
    for poly in data.polygons: poly.material_index=random.randrange(len(mats))
    return obj

clear()
# Grip origin is near the base of the handle. A compact bevelled working hammer.
beam('Ash handle',(0,0,-.10),(0,0,.48),.055,.045,edge,.012)
beam('Iron hammer head',(-.16,0,.43),(.16,0,.43),.13,.12,metal,.025)
beam('Handle collar',(0,0,.30),(0,0,.38),.072,.061,metal,.012)
export('BuildingHammer')

for variant in range(4):
    clear(); verts=[]; faces=[]; columns=12; height=12+variant*2; width=22+variant*3
    # A broad rock formation with broken ledges and a readable mountain-scale silhouette.
    for level in range(5):
        for j in range(columns+1):
            x=(j/columns-.5)*width
            z=height*level/4 + (random.uniform(-1,1) if level else 0)
            taper=.5+math.sin(j/columns*math.pi)*.5
            z*=taper
            y=(level%2)*.8+random.uniform(-.5,.5)-level*.6
            verts.append((x,y,z))
    for level in range(4):
        for j in range(columns):
            a=level*(columns+1)+j; b=a+columns+1
            faces.extend([(a,a+1,b+1),(a,b+1,b)])
    # Back and upper mass close the formation rather than a visible thin facade.
    base=len(verts); verts.extend([(-width/2,8,0),(width/2,8,0),(width/2,6,height*.5),(-width/2,6,height*.5)])
    faces.extend([(0,base,base+1,columns),(0,4*(columns+1),base+3,base),(columns,base+1,base+2,5*(columns+1)-1)])
    for j in range(columns): faces.append((4*(columns+1)+j,4*(columns+1)+j+1,base+2,base+3))
    faces.append((base,base+3,base+2,base+1))
    mesh('Cliff formation',verts,faces,stone); export('CliffFormation_'+str(variant+1))

clear()
verts=[]; faces=[]; segments=16; rings=6
for depth in range(rings):
    for radius in [3.6,5.0]:
        for j in range(segments+1):
            theta=j/segments*math.pi; r=radius+(random.uniform(-.15,.15) if depth else 0)
            verts.append((math.cos(theta)*r,depth*3.5,math.sin(theta)*r*1.1))
stride=(segments+1)*2
for depth in range(rings-1):
    for side in range(2):
        for j in range(segments):
            a=depth*stride+side*(segments+1)+j; b=a+stride
            faces.append((a,b,b+1,a+1) if side==0 else (a,a+1,b+1,b))
for depth in [0,rings-1]:
    for j in range(segments):
        a=depth*stride+j; b=a+segments+1; faces.append((a,a+1,b+1,b))
mesh('Cave arch and interior',verts,faces,stone); export('HollowrootCave')

for family,length,width in [('Wood',36,6),('Rope',32,4),('Stone',38,8)]:
    clear()
    def sag(y): return -math.sin((y/length+.5)*math.pi) if family=='Rope' else 0
    for i in range(int(length/.5)+1):
        y=-length/2+i*.5; z=sag(y)
        beam('Deck plank' if family!='Stone' else 'Dressed paving',(-width/2,y,z-.08),(width/2,y,z-.08),.44,.16,edge if family!='Stone' else stone[i%3],.018)
    for side in [-1,1]:
        x=side*(width/2-.15)
        if family=='Wood':
            beam('Main bearer',(x,-length/2,-.5),(x,length/2,-.5),.35,.48,wood,.05)
            for y in range(-18,19,6):
                beam('Railing post',(x,y,-.3),(x,y,1.2),.17,.17,wood)
                beam('Pier',(x,y,-6),(x,y,-.4),.38,.38,wood,.035)
                if y<18:
                    beam('Top rail',(x,y,1.03),(x,y+6,1.03),.15,.15,edge)
                    beam('Cross brace',(x,y,.2),(x,y+6,.85),.10,.10,wood)
        elif family=='Rope':
            for y in [-length/2,length/2]: beam('Anchor post',(x,y,-1),(x,y,1.8),.23,.23,wood,.04)
            for i in range(32):
                y=-length/2+i
                beam('Hand rope',(x,y,sag(y)+1.0),(x,y+1,sag(y+1)+1.0),.055,.055,rope,.012)
                if i%2==0: beam('Hanger',(x,y,sag(y)),(x,y,sag(y)+1),.033,.033,rope,.005)
        else:
            for i in range(19):
                y=-19+i*2
                beam('Parapet',(x,y,0),(x,y,1.0),.45,1.92,stone[i%3],.08)
            # Real open arch profiles, with abutments at either bank.
            verts=[]; faces=[]
            for i in range(21):
                y=-19+i*1.9; z=-7+6.2*math.sin(i/20*math.pi)
                verts.extend([(x-.38,y,z),(x+.38,y,z),(x-.38,y,z+.72),(x+.38,y,z+.72)])
            for i in range(20):
                a=i*4; b=a+4; faces.extend([(a,b,b+1,a+1),(a+2,a+3,b+3,b+2),(a,a+2,b+2,b),(a+1,b+1,b+3,a+3)])
            mesh('Masonry arch',verts,faces,stone)
    export('Bridge_'+family)

clear()
# Rotor only: village-kit tower and roof form the mill body in Godot.
beam('Rotor hub',(0,-.28,0),(0,.28,0),.45,.45,wood,.08)
for angle in [0,math.pi/2,math.pi,math.pi*1.5]:
    direction=Vector((math.cos(angle),0,math.sin(angle))); side=Vector((-math.sin(angle),0,math.cos(angle)))
    beam('Sail spar',direction*.3,direction*4.4,.13,.13,wood,.025)
    for i in range(9):
        center=direction*(1.2+i*.35)
        beam('Sail lath',center-side*.55,center+side*.55,.22,.045,edge,.018)
export('WindmillRotor')
print('BLENDER_ASSETS_COMPLETE')
