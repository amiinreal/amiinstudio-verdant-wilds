"""Run with Blender --background --python build_assets.py. Original low-poly assets."""
import bpy, math, random
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
random.seed(41)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
MAT = {}
for name, color in {
    'soil': '#68452e', 'wet': '#392c24', 'earth': '#885c39', 'clay': '#a97647',
    'green': '#548b36', 'leaf': '#86b947', 'darkleaf': '#386942',
    'gold': '#e7b64f', 'lightgold': '#ffe192', 'straw': '#ac7b37',
    'orange': '#ee792d', 'lightorange': '#ffad45', 'seed': '#765334',
    'wood': '#885738', 'grip': '#3f342d', 'metal': '#adbabc',
    'line': '#eee3bd', 'red': '#d66042', 'white': '#f5e8cd',
    'fish': '#63a9a0', 'belly': '#c7dbc0', 'fin': '#377780',
    'salmon': '#d18a76', 'salmonfin': '#914f51', 'eye': '#172b31',
    'water': '#429fa8', 'grass': '#7f9a5c', 'board': '#203e3e',
}.items():
    m = bpy.data.materials.new(name)
    srgb = tuple(int(color[i:i+2], 16)/255 for i in (1,3,5))
    rgb = tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in srgb)
    m.diffuse_color = (*rgb, 1)
    m.use_nodes = True
    m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (*rgb, 1)
    m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = .85
    MAT[name] = m

assets = {}
current = None
def finish(o, name, material, parent=None):
    o.name = name
    if material: o.data.materials.append(MAT[material])
    o.parent = parent or current
    return o

def empty(name, parent=None):
    o = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(o)
    o.parent = parent
    return o

def start(name):
    global current
    current = empty(name)
    assets[name] = current
    return current

def box(name, p, scale, mat, parent=None):
    verts=[(p[0]+x*scale[0]/2,p[1]+y*scale[1]/2,p[2]+z*scale[2]/2) for x,y,z in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
    return mesh_obj(name,verts,[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],mat,parent)

def mesh_obj(name,verts,faces,mat,parent=None):
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    o=bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(o)
    return finish(o,name,mat,parent)

def ico(name, p, scale, mat, parent=None):
    t=(1+math.sqrt(5))/2
    coords=[(-1,t,0),(1,t,0),(-1,-t,0),(1,-t,0),(0,-1,t),(0,1,t),(0,-1,-t),(0,1,-t),(t,0,-1),(t,0,1),(-t,0,-1),(-t,0,1)]
    verts=[tuple(Vector(v).normalized()[i]*scale[i] for i in range(3)) for v in coords]
    faces=[(0,11,5),(0,5,1),(0,1,7),(0,7,10),(0,10,11),(1,5,9),(5,11,4),(11,10,2),(10,7,6),(7,1,8),(3,9,4),(3,4,2),(3,2,6),(3,6,8),(3,8,9),(4,9,5),(2,4,11),(6,2,10),(8,6,7),(9,8,1)]
    o=mesh_obj(name,verts,faces,mat,parent)
    o.location=p
    return o

def rod(name, a, b, r, mat, r2=None, parent=None, vertices=6):
    a,b = Vector(a),Vector(b)
    q=(b-a).to_track_quat('Z','Y')
    verts=[]
    for center,radius in [(a,r),(b,r if r2 is None else r2)]:
        for i in range(vertices):
            ang=i*math.tau/vertices
            verts.append(center+q@Vector((math.cos(ang)*radius,math.sin(ang)*radius,0)))
    faces=[tuple(reversed(range(vertices))),tuple(range(vertices,vertices*2))]
    for i in range(vertices):
        j=(i+1)%vertices
        faces.append((i,j,j+vertices,i+vertices))
    return mesh_obj(name,verts,faces,mat,parent)

def leaf(name, a, b, width, mat, parent=None):
    a,b=Vector(a),Vector(b)
    d=b-a
    side=d.cross(Vector((0,0,1)))
    if side.length < .001: side=Vector((1,0,0))
    side.normalize()
    mid=a+d*.48
    verts=[a,mid+side*width,b,mid-side*width,mid+Vector((0,0,width*.3))]
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],[(0,1,4),(1,2,4),(2,3,4),(3,0,4)])
    mesh.update()
    o=bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(o)
    return finish(o,name,mat,parent)

def carrot(stage=3, harvest=False):
    h=[.12,.27,.43,.62][stage]
    radius=[.018,.045,.073,.11][stage]
    top=.49 if harvest else .055
    if stage>0 or harvest:
        rod('Tapered_root',(0,0,top-(.48 if harvest else .32)*(stage+1)/4),(0,0,top),.007,'orange',radius,vertices=7)
        ico('Shoulder',(0,0,top-.02),(radius,radius,.075*(stage+1)/4),'lightorange')
        if stage==3:
            for i in range(3):
                rod('Root_ridge',(-radius*.5,-radius*.7,top-.06-i*.057),(radius*.5,-radius*.7,top-.06-i*.057),.008,'orange')
    for i in range(3+stage*2):
        ang=i*2.399
        end=(math.cos(ang)*h*.43,math.sin(ang)*h*.43,top+h*(.68+.28*(i%3)/2))
        rod('Leaf_stem',(0,0,top),end,.007,'green',.003)
        leaf('Carrot_frond',(0,0,top+h*.14),end,h*.10,'leaf' if i%2 else 'green')
        if stage>0:
            for f in [.38,.58,.77]:
                center=Vector((0,0,top)).lerp(Vector(end),f)
                for side in [-1,1]:
                    tip=center+Vector((math.cos(ang+side*.85)*h*.18,math.sin(ang+side*.85)*h*.18,h*.08))
                    leaf('Feathery_leaf',center,tip,h*.046,'leaf' if i%2 else 'green')

def wheat(stage=3):
    for i in range(7 if stage>1 else 4):
        ang=i*2.399
        x,y=math.cos(ang)*.11,math.sin(ang)*.11
        h=[.14,.35,.63,.88][stage]*(.85+.15*(i%3)/2)
        mat='gold' if stage==3 else 'green'
        rod('Wheat_stem',(x,y,0),(x,y,h),.009,mat,.005)
        for j in range(2 if stage<2 else 3):
            base=(x,y,h*(.15+j*.18))
            tip=(x+math.cos(ang+j*2)*h*.29,y+math.sin(ang+j*2)*h*.29,h*(.46+j*.16))
            leaf('Blade',base,tip,.025 if stage else .012,mat)
        if stage>=2:
            for k in range(5):
                for sign in [-1,1]:
                    p=(x+sign*.029,y,h-.13+k*.04)
                    grain=ico('Kernel',p,(.028,.026,.055),'lightgold' if stage==3 and k%2 else mat)
                    grain.rotation_euler.y=sign*.4
                    rod('Awn',p,(p[0]+sign*.024,y,p[2]+.09),.0025,mat,.0008)

for crop,fn in [('carrot',carrot),('wheat',wheat)]:
    start(crop+'_seeds')
    for i in range(7):
        a=i*2.399
        ico('Seed',(math.cos(a)*.065,math.sin(a)*.065,.018+(i%2)*.012),(.018,.012,.027) if crop=='carrot' else (.025,.017,.044),'seed' if crop=='carrot' else 'gold')
    for s in range(4):
        start(f'{crop}_stage_{s}')
        fn(s)
    start(crop+'_harvest')
    fn(3,True) if crop=='carrot' else fn(3)
    if crop=='wheat':
        for z in [.22,.25]: rod('Twine',(-.14,0,z),(.14,0,z),.014,'line')
    root=start(crop+'_growing')
    for s in range(4):
        pivot=empty(f'Stage_{s}',root)
        current=pivot
        fn(s)
        # Discrete stage changes plus a short emergence animation at every transition.
        for frame,scale in [(1,.0001),(s*60+1,.0001),(s*60+2,.55),(s*60+16,1),(s*60+60,1),(s*60+61,.0001)]:
            if s==3 and frame==241: scale=1
            pivot.scale=(scale,)*3
            pivot.keyframe_insert(data_path='scale',frame=frame,group='Grow')
        pivot.animation_data.action.name=f'{crop}_Grow_stage_{s}'
    current=root

for wet in [False,True]:
    start('farmland_wet' if wet else 'farmland_dry')
    box('Earth_block',(0,0,-.23),(1,1,.40),'earth')
    box('Soil_surface',(0,0,-.035),(1,1,.055),'wet' if wet else 'soil')
    for x in [-.375,-.125,.125,.375]:
        box('Tilled_ridge',(x,0,-.005),(.145,.96,.055),'wet' if wet else 'soil')
    for i in range(12):
        side=-1 if i%2 else 1
        box('Earth_fleck',((i//2-2.5)*.15,side*.501,-.16-(i%3)*.07),(.065,.004,.035),'clay')
start('irrigation_channel')
box('Channel_base',(0,0,-.33),(1,1,.2),'earth')
box('Water',(0,0,-.10),(.76,1,.025),'water')
for x in [-.44,.44]: box('Bank',(x,0,-.16),(.12,1,.30),'soil')

start('fishing_bobber')
ico('Float_bottom',(0,0,.08),(.065,.065,.095),'white')
ico('Float_top',(0,0,.16),(.065,.065,.065),'red')
rod('Antenna',(0,0,.18),(0,0,.32),.009,'wood')
start('fishing_hook')
points=[(0,0,.19),(0,0,.025),(.016,0,0),(.046,0,0),(.06,0,.025),(.06,0,.07)]
for a,b in zip(points,points[1:]): rod('Hook',a,b,.007,'metal')
rod('Barb',points[-1],(.04,0,.05),.007,'metal',0)

start('fishing_rod')
rod('Cork_grip',(0,0,0),(0,0,.38),.042,'grip',.034)
for z in [.04,.32,.40]: rod('Ferrule',(0,0,z),(0,0,z+.025),.044,'metal')
for a,b,r in [((0,0,.38),(.05,0,1.05),.024),((.05,0,1.05),(.17,0,1.7),.017),((.17,0,1.7),(.37,0,2.2),.01)]: rod('Bamboo',a,b,r,'wood',r*.6)
rod('Reel_axle',(0,-.06,.26),(0,.06,.26),.055,'metal')
rod('Reel_spool',(0,-.075,.26),(0,-.025,.26),.083,'grip')
rod('Crank',(0,-.09,.26),(.09,-.09,.26),.009,'metal')
rod('Crank_grip',(.09,-.09,.26),(.09,-.14,.26),.018,'wood')
for z,x in [(.75,.028),(1.3,.096),(1.75,.19),(2.18,.365)]:
    rod('Line_guide',(x,0,z),(x,.045,z),.009,'metal')
rod('Fishing_line',(.37,.045,2.2),(.56,.045,.50),.0025,'line')

start('landing_net')
rod('Handle',(0,0,0),(0,0,.85),.025,'wood')
N=16
ring=[(math.cos(i*math.tau/N)*.25,0,1.1+math.sin(i*math.tau/N)*.32) for i in range(N)]
for i in range(N):
    rod('Rim',ring[i],ring[(i+1)%N],.015,'wood')
    rod('Net_cord',ring[i],(ring[i][0]*.38,-.27,1.1+(ring[i][2]-1.1)*.38),.0035,'line')
for t in [.3,.6,1]:
    loop=[(p[0]*(1-t*.62),-.27*t,1.1+(p[2]-1.1)*(1-t*.62)) for p in ring]
    for i in range(N): rod('Net_weave',loop[i],loop[(i+1)%N],.003,'line')

for name,body,fin in [('river_fish','fish','fin'),('salmon','salmon','salmonfin')]:
    root=start(name)
    ico('Body',(0,0,.18),(.33,.095,.15),body)
    ico('Belly',(0,-.012,.14),(.26,.087,.091),'belly')
    ico('Head',(-.25,0,.19),(.14,.086,.105),body)
    for y in [-.077,.077]:
        ico('Eye',(-.29,y,.225),(.025,.013,.025),'eye')
        ico('Eye_glint',(-.296,y*1.13,.233),(.007,.004,.007),'white')
        leaf('Pectoral',(-.12,y,.15),(.03,y*2,.08),.045,fin)
    mesh_obj('Dorsal',[(-.13,0,.27),(.02,0,.42),(.17,0,.29)],[(0,1,2)],fin)
    tail=empty('Tail',root)
    tail.location=(.27,0,.18)
    mesh_obj('Forked_tail',[(0,0,0),(.22,0,.16),(.17,0,0),(.22,0,-.16)],[(0,1,2),(0,2,3)],fin,tail)
    for f,a in [(1,-.3),(9,.3),(17,-.3)]:
        tail.rotation_euler.z=a
        tail.keyframe_insert(data_path='rotation_euler',frame=f)
    tail.animation_data.action.name='Swim'
    for i in range(7): ico('Speckle',(-.15+i*.055,-.086,.22+(i%2)*.03),(.013,.006,.010),fin)

# Export every prop as a self-contained, portable glTF binary in metres.
bpy.context.view_layer.update()
# Collapse static pieces by parent; retain independently animated stage and tail pivots.
for root in assets.values():
    groups={}
    for obj in root.children_recursive:
        if obj.type=='MESH': groups.setdefault(obj.parent,[]).append(obj)
    for parent,objects in groups.items():
        verts,faces,indices,materials=[],[],[],[]
        for obj in objects:
            offset=len(verts)
            verts.extend([obj.matrix_basis@v.co for v in obj.data.vertices])
            mat=obj.data.materials[0]
            if mat not in materials: materials.append(mat)
            faces.extend([tuple(offset+i for i in poly.vertices) for poly in obj.data.polygons])
            indices.extend([materials.index(mat)]*len(obj.data.polygons))
        merged=mesh_obj(parent.name+'_Mesh',verts,faces,None,parent)
        for mat in materials: merged.data.materials.append(mat)
        for poly,index in zip(merged.data.polygons,indices): poly.material_index=index
        for obj in objects: bpy.data.objects.remove(obj,do_unlink=True)
bpy.context.scene.render.fps=24
for name,root in assets.items():
    bpy.ops.object.select_all(action='DESELECT')
    root.select_set(True)
    for child in root.children_recursive: child.select_set(True)
    bpy.context.view_layer.objects.active=root
    bpy.context.scene.frame_start=1
    bpy.context.scene.frame_end=241 if name.endswith('growing') else 17
    bpy.context.scene.frame_set(1)
    bpy.ops.export_scene.gltf(filepath=str(ROOT/'Models'/f'{name}.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='SCENE',export_frame_range=True,export_force_sampling=True)

# A composed contact sheet is also the editable Blender source file.
bpy.context.scene.frame_set(220)
for root in assets.values():
    if root.name.endswith('growing'): root.hide_render=True
    for child in root.children_recursive:
        if root.name.endswith('growing'): child.hide_render=True

def text_obj(body,p,size=.18,mat='white'):
    bpy.ops.object.text_add(location=p)
    o=bpy.context.object
    o.data.body=body
    o.data.size=size
    o.data.extrude=.0005
    o.data.materials.append(MAT[mat])
    return o

for crop,y in [('carrot',2),('wheat',.1)]:
    text_obj(crop.upper()+' / SEED TO HARVEST',(-3.7,y+.75,.015),.18)
    for idx,key in enumerate([crop+'_seeds']+[f'{crop}_stage_{s}' for s in range(4)]+[crop+'_harvest']):
        root=assets[key]
        root.location=(-3.35+idx*1.28,y,0)
        if idx==0: root.scale=(2,2,2)
        text_obj(['SEEDS','SPROUT','YOUNG','GROWING','MATURE','HARVEST'][idx],(-3.65+idx*1.28,y-.52,.015),.105,'lightgold')
for i,key in enumerate(['farmland_dry','farmland_wet','irrigation_channel']):
    assets[key].location=(-3.1+i*1.35,-1.65,.43)
    text_obj(['DRY SOIL','WATERED SOIL','IRRIGATION'][i],(-3.6+i*1.35,-2.28,.015),.10,'lightgold')
for i,key in enumerate(['river_fish','salmon']):
    assets[key].location=(1.35+i*1.5,-1.65,.13)
    assets[key].scale=(1.5,)*3
    text_obj(['RIVER FISH','SALMON'][i],(.93+i*1.5,-2.28,.015),.11,'lightgold')
for i,key in enumerate(['fishing_rod','landing_net','fishing_bobber','fishing_hook']):
    assets[key].location=(-2.7+i*1.8,-3.7,.10)
    assets[key].rotation_euler=(math.radians(-65),0,math.radians(-25))
    if i==0: assets[key].scale=(.65,)*3
    if i>=2: assets[key].scale=(2.5,)*3
    text_obj(['FISHING ROD','LANDING NET','BOBBER','HOOK'][i],(-3.3+i*1.8,-4.55,.015),.12,'lightgold')
current=None
box('Display_base',(0,-.8,-.30),(9.3,9.2,.3),'board')
text_obj('FIELD & STREAM',(-3.7,3.42,.02),.46)
text_obj('OPENZELD  /  FARMING + FISHING ASSET COLLECTION',(-3.7,3.12,.02),.12,'lightgold')
world=bpy.context.scene.world or bpy.data.worlds.new('World')
bpy.context.scene.world=world
world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.17,.23,.24,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.65
bpy.ops.object.light_add(type='AREA',location=(-3,-4,9))
bpy.context.object.data.energy=1400
bpy.context.object.data.shape='DISK'
bpy.context.object.data.size=7
bpy.ops.object.camera_add(location=(5,-9,16))
camera=bpy.context.object
camera.rotation_euler=(Vector((0,-.6,0))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO'
camera.data.ortho_scale=13.2
bpy.context.scene.camera=camera
scene=bpy.context.scene
scene.render.engine='CYCLES'
scene.cycles.samples=24
scene.render.resolution_x=1500
scene.render.resolution_y=1500
scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
scene.render.filepath=str(ROOT/'asset_preview.png')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'Source'/'field_and_stream.blend'))
bpy.ops.render.render(write_still=True)
print('ASSET_BUILD_OK',len(assets))
