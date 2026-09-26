"""Blender-authored cooking fire and food props, exported as self-contained GLB."""
import bpy, math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'Adventure/cooking'; OUT.mkdir(parents=True,exist_ok=True)

def mat(name,color,metal=0,emission=0):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Metallic'].default_value=metal; p.inputs['Roughness'].default_value=.72
    if emission: p.inputs['Emission Color'].default_value=(*color,1); p.inputs['Emission Strength'].default_value=emission
    return m
stone=mat('River stone',(.25,.29,.29)); wood=mat('Split hardwood',(.22,.10,.04)); end=mat('End grain',(.58,.34,.15))
iron=mat('Forged iron',(.07,.085,.09),.7); ember=mat('Embers',(1,.20,.02),0,2)
flame=mat('Warm flames',(1,.53,.06),0,1.5); raw=mat('Fresh meat',(.60,.19,.16)); fat=mat('Ivory fat',(.94,.77,.58))
roast=mat('Roasted meat',(.29,.10,.035)); sear=mat('Grill marks',(.07,.025,.012)); board=mat('Serving board',(.46,.25,.10))
def clear():
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
def finish(o,name,material):
    o.name=name; o.data.materials.append(material)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    for p in o.data.polygons:p.use_smooth=True
    return o
def ell(name,pos,scale,m):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12,location=pos); o=bpy.context.object; o.scale=scale
    return finish(o,name,m)
def rod(name,a,b,r,m):
    a,b=Vector(a),Vector(b); d=b-a
    bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=r,depth=d.length,location=(a+b)/2)
    o=bpy.context.object; o.rotation_mode='QUATERNION'; o.rotation_quaternion=d.to_track_quat('Z','Y')
    return finish(o,name,m)
def cube(name,pos,scale,m,bevel=.02):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos);o=bpy.context.object;o.scale=scale;finish(o,name,m)
    mod=o.modifiers.new('Rounded edges','BEVEL');mod.width=bevel;mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name)
    return o
def steak(cooked=False,offset=(0,0,0),scale=1):
    x,y,z=offset;m=roast if cooked else raw
    ell('Meat fat',(x,y,z+.045*scale),(.19*scale,.135*scale,.052*scale),fat)
    ell('Meat',(x,y,z+.060*scale),(.173*scale,.116*scale,.045*scale),m)
    ell('Bone',(x+.105*scale,y+.018*scale,z+.097*scale),(.027*scale,.023*scale,.010*scale),fat)
    if cooked:
        for i in range(4):
            o=cube('Sear stripe',(x+(-.09+i*.045)*scale,y,z+.098*scale),(.012*scale,.14*scale,.004*scale),sear,.004)
            o.rotation_euler.z=-.28
def export(name):
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',export_animations=False,export_yup=True)
clear()
for i in range(12):
    a=i*math.tau/12
    o=ell('Hearth stone',(math.cos(a)*.64,math.sin(a)*.64,.12),(.17,.13,.12),stone);o.rotation_euler.z=a+.3
for y,turn in [(-.13,.25),(.13,-.25)]:
    a=Vector((-.42,y,.14));b=Vector((.42,y,.14));rod('Firewood',a,b,.085,wood)
    rod('End grain',a-Vector((.003,0,0)),a+Vector((.003,0,0)),.074,end)
    rod('End grain',b-Vector((.003,0,0)),b+Vector((.003,0,0)),.074,end)
for i in range(9):
    a=i*2.4;r=.12+.17*(i%3)/2
    ell('Coal',(math.cos(a)*r,math.sin(a)*r,.15),(.075,.055,.035),ember)
    o=ell('Flame',(math.cos(a)*r,math.sin(a)*r,.24),(.045,.055,.10+(i%3)*.02),flame);o.rotation_euler.y=.18*math.sin(a)
for x in [-.48,.48]:
    for y in [-.35,.35]:rod('Grill leg',(x*1.12,y*1.2,.06),(x,y,.76),.021,iron)
for x in [-.5,.5]:rod('Grill frame',(x,-.38,.77),(x,.38,.77),.026,iron)
for y in [-.38,.38]:rod('Grill frame',(-.5,y,.77),(.5,y,.77),.026,iron)
for i in range(12):
    x=-.44+i*.08;rod('Cooking grate',(x,-.36,.77),(x,.36,.77),.012,iron)
steak(True,(-.19,0,.78),1)
steak(True,(.21,.05,.78),.85)
rod('Handle',(.53,-.18,.76),(.76,-.18,.76),.018,iron)
rod('Handle',(.53,.18,.76),(.76,.18,.76),.018,iron)
rod('Wooden grip',(.76,-.20,.76),(.76,.20,.76),.03,wood)
export('cooking_fire')
clear();steak(False);export('raw_meat')
clear();cube('Serving board',(0,0,.015),(.48,.35,.03),board,.025);steak(True,(0,0,.035));export('cooked_meat')
print('COOKING_ASSETS_EXPORTED')
