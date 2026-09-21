"""Original solid-blade meadow tiles. Run with Blender --background --python."""
import bpy, math, random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'Adventure/generated'
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
rng = random.Random(73129)
for variant in range(3):
    vertices, faces, colors = [], [], []
    for blade in range(96):
        x, y = rng.uniform(-.68,.68), rng.uniform(-.68,.68)
        angle = rng.random()*math.tau
        width, height = rng.uniform(.009,.022), rng.uniform(.16,.35)
        bend = rng.uniform(.04,.17)
        dx, dy = math.cos(angle), math.sin(angle)
        start = len(vertices)
        for z, w, shift in [(0,width,0), (height*.53,width*.65,bend*.25)]:
            for side in [-1,1]:
                vertices.append((x+dx*side*w-dy*shift,y+dy*side*w+dx*shift,z))
                colors.append((.16+z*.6,.28+z*.95,.045+z*.16,1))
        vertices.append((x-dy*bend,y+dx*bend,height))
        colors.append((.49,.67,.15,1))
        faces.extend([(start,start+1,start+2),(start+1,start+3,start+2),(start+2,start+3,start+4)])
    mesh=bpy.data.meshes.new('MeadowBlades'); mesh.from_pydata(vertices,[],faces); mesh.update()
    color=mesh.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='POINT')
    for i,c in enumerate(colors): color.data[i].color=c
    obj=bpy.data.objects.new('WoodlandGrass_%d'%variant,mesh); bpy.context.collection.objects.link(obj)
    bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True); bpy.context.view_layer.objects.active=obj
    bpy.ops.export_scene.gltf(filepath=str(OUT/('WoodlandGrass_%d.glb'%variant)),use_selection=True,export_format='GLB',export_materials='NONE')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'development/blender/WoodlandGrass.blend'))
