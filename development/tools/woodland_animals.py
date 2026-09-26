"""Original Verdant Wilds animals. Run with Blender --background --python this_file.
Produces self-contained, skinned GLBs; no .blend files required by the game.
Coordinates: Blender +Y forward, +Z up; glTF/Godot -Z forward, +Y up.
"""
import bpy, math, json, sys
from pathlib import Path
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'Adventure/animals'
OUT.mkdir(parents=True, exist_ok=True)
TAU = math.tau

def material(name, color, rough=.8):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    bs = m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = (*color, 1)
    bs.inputs['Roughness'].default_value = rough
    m.use_backface_culling = True
    return m

def build(kind):
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    for action in list(bpy.data.actions): bpy.data.actions.remove(action)
    cow = kind == 'cow'; cat = kind == 'cat'
    # Models are authored in meters; proportions are deliberately species-specific.
    width, length, height = ((.44,.73,.82) if cow else (.21,.27,.28) if cat else (.27,.44,.44))
    head_y = length * .91
    head_z = height + (.18 if cow else .18 if cat else .17)
    coat = material('Coat', (.86,.53,.26) if cat else (.48,.29,.17) if cow else (.58,.33,.15))
    cream = material('Warm ivory', (.93,.84,.65))
    dark = material('Cinnamon markings', (.32,.15,.065))
    pink = material('Rose', (.76,.43,.40))
    black = material('Nose and pupils', (.016,.024,.022),.28)
    iris = material('Amber eyes', (.58,.34,.055),.26)
    hoof = material('Hooves', (.09,.075,.064))
    pieces=[]; bones={}; legs={}
    def bone(name, a, b, parent=None): bones[name]=(Vector(a),Vector(b),parent)
    bone('body',(0,0,height),(0,.22,height))
    neck_start=Vector((0,length*.48,height-.045)); neck_end=Vector((0,head_y-.09,head_z-.10))
    bone('neck',neck_start,neck_end,'body')
    bone('head',neck_end,(0,head_y+.12,head_z),'neck')
    def bind(o, name, mat, bone_name):
        o.name=name; o.data.materials.append(mat)
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        group=o.vertex_groups.new(name=bone_name); group.add(list(range(len(o.data.vertices))),1,'REPLACE')
        for p in o.data.polygons: p.use_smooth=True
        pieces.append(o); return o
    def ell(name, p, size, mat=coat, joint='body', seg=24, rings=16):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=seg,ring_count=rings,location=p)
        o=bpy.context.object; o.scale=size
        return bind(o,name,mat,joint)
    def link(name,a,b,r1,r2,mat=coat,joint='body'):
        a,b=Vector(a),Vector(b); d=b-a
        bpy.ops.mesh.primitive_cone_add(vertices=12,radius1=r1,radius2=r2,depth=d.length,location=(a+b)/2)
        o=bpy.context.object; o.rotation_mode='QUATERNION'; o.rotation_quaternion=d.to_track_quat('Z','Y')
        return bind(o,name,mat,joint)
    def ear(name,side):
        x=side*(width*.79 if cat else width*.65); z=head_z+(.16 if cow else .17 if cat else .12)
        bone(name,(x,head_y,z),(x*1.5,head_y,z+.15),'head')
        if cat:
            verts=[(x-side*.085,head_y-.045,z),(x+side*.085,head_y-.045,z),(x+side*.035,head_y-.015,z+.145),
                   (x-side*.07,head_y+.050,z),(x+side*.07,head_y+.050,z),(x+side*.030,head_y+.035,z+.135)]
            mesh=bpy.data.meshes.new(name); mesh.from_pydata(verts,[],[(0,2,1),(3,4,5),(0,1,4,3),(1,2,5,4),(2,0,3,5)]); mesh.update()
            o=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(o)
            bpy.ops.object.select_all(action='DESELECT'); bpy.context.view_layer.objects.active=o; o.select_set(True); bind(o,name,coat,name)
            bevel=o.modifiers.new('Soft ear edges','BEVEL'); bevel.width=.018; bevel.segments=3
            bpy.ops.object.modifier_apply(modifier=bevel.name)
            inner=ell(name+' inner',(x+side*.014,head_y+.050,z+.044),(.043,.010,.054),pink,name)
        elif cow:
            o=ell(name,(x+side*.17,head_y-.02,z-.02),(.20,.095,.057),coat,name); o.rotation_euler.y=side*.22
            ell(name+' inner',(x+side*.17,head_y+.055,z-.005),(.13,.02,.034),pink,name)
        else:
            o=ell(name,(x+side*.06,head_y-.045,z-.10),(.085,.115,.235),dark,name); o.rotation_euler.y=side*-.23
    ell('Barrel',(0,-.06,height),(width,length,width*.88))
    ell('Shoulders',(0,length*.50,height+.025),(width*.95,length*.53,width*1.06))
    ell('Haunches',(0,-length*.60,height-.01),(width*.98,length*.40,width*.95))
    ell('Chest bib',(0,length*.65,height-.085),(width*.82,length*.34,width*.85),cream)
    neck_mesh=link('Neck',neck_start,neck_end,width*.77,width*.63,coat,'neck')
    neck_mesh.vertex_groups.clear()
    lower=neck_mesh.vertex_groups.new(name='body'); upper=neck_mesh.vertex_groups.new(name='head')
    axis=neck_end-neck_start
    for vertex in neck_mesh.data.vertices:
        p=neck_mesh.matrix_world @ vertex.co
        weight=max(0,min(1,(p-neck_start).dot(axis)/axis.length_squared))
        lower.add([vertex.index],1-weight,'REPLACE'); upper.add([vertex.index],weight,'REPLACE')
    ell('Face',(0,head_y,head_z),(width*1.38,width*.99,width*1.15) if cat else (width*1.02,width*.99,width*.92),coat,'head',32,20)
    if cow:
        ell('Broad muzzle',(0,head_y+.34,head_z-.12),(.31,.19,.18),pink,'head')
        for side in [-1,1]:
            ell('Nostril',(side*.135,head_y+.516,head_z-.085),(.026,.013,.020),dark,'head')
            ell('Horn',(side*.23,head_y-.055,head_z+.37),(.075,.075,.135),cream,'head')
        ell('Udder',(0,-length*.48,height-.34),(.19,.23,.12),pink)
        for x in [-.10,.10]:
            for y in [-.47,-.30]: ell('Teat',(x,y,height-.45),(.032,.032,.063),pink)
    elif cat:
        my=head_y+width*.985
        for side in [-1,1]:
            ell('Soft cheek',(side*.060,my,head_z-.075),(.079,.036,.055),cream,'head')
        ell('Button nose',(0,my+.037,head_z-.054),(.022,.012,.015),pink,'head')
        link('Mouth center',(0,my+.036,head_z-.064),(0,my+.034,head_z-.086),.003,.003,dark,'head')
        for side in [-1,1]:
            link('Little smile',(0,my+.034,head_z-.086),(side*.020,my+.033,head_z-.090),.0025,.002,dark,'head')
    else:
        my=head_y+width*.96
        for side in [-1,1]: ell('Muzzle cushion',(side*width*.25,my,head_z-.055),(width*.42,width*.48,width*.34),cream,'head')
        ell('Nose',(0,my+width*.41,head_z-.017),(width*.23,width*.13,width*.15),pink if cat else black,'head')
        link('Mouth center',(0,my+width*.39,head_z-.043),(0,my+width*.39,head_z-.080),.005,.004,dark,'head')
    for side in [-1,1]:
        ex=side*width*.52; ey=head_y+width*.926 if cat else head_y+width*.865; ez=head_z+(.025 if cat else .052)
        ell('Velvet eye',(ex,ey,ez),(width*.225,.020,width*.28) if cat else (width*.17,.021,width*.22),black,'head')
        ell('Catchlight',(ex-width*.047,ey+.020,ez+width*.068),(width*.052,.008,width*.052),cream,'head',16,10)
        ell('Small catchlight',(ex+width*.05,ey+.020,ez-width*.05),(width*.023,.005,width*.023),cream,'head',12,8)
        ear('ear.L' if side<0 else 'ear.R',side)
        if cat:
            for i in range(2):
                link('Whisker',(side*.11,head_y+.226,head_z-.074-i*.016),(side*.20,head_y+.212,head_z-.056-i*.030),.0015,.0007,dark,'head')
    # Merge the overlapping sculpt volumes into a continuous smooth torso.
    core=[o for o in pieces if o.name in ['Barrel','Shoulders','Haunches','Chest bib']]
    bpy.ops.object.select_all(action='DESELECT')
    for o in core: o.select_set(True); pieces.remove(o)
    bpy.context.view_layer.objects.active=core[0]; bpy.ops.object.join(); torso=bpy.context.object
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    remesh=torso.modifiers.new('Continuous sculpt','REMESH'); remesh.mode='VOXEL'; remesh.voxel_size=width*.070; remesh.use_smooth_shade=True
    bpy.ops.object.modifier_apply(modifier=remesh.name)
    smooth=torso.modifiers.new('Polished contours','SMOOTH'); smooth.factor=1.1; smooth.iterations=5
    bpy.ops.object.modifier_apply(modifier=smooth.name)
    dec=torso.modifiers.new('Game topology','DECIMATE'); dec.ratio=.35
    bpy.ops.object.modifier_apply(modifier=dec.name)
    torso.data.materials.clear()
    for mat in [coat,cream,dark]: torso.data.materials.append(mat)
    torso.vertex_groups.clear(); group=torso.vertex_groups.new(name='body'); group.add(list(range(len(torso.data.vertices))),1,'REPLACE')
    for poly in torso.data.polygons:
        p=poly.center; poly.use_smooth=True; poly.material_index=0
        if cow:
            # Softly irregular islands made from surface regions, with no raised patches.
            field=math.sin(p.y*8+math.sin(p.z*13))+math.cos(p.z*11+p.x*4)*.7
            if field>.45: poly.material_index=1
        elif cat:
            if p.z < height-.11: poly.material_index=1
        if p.y>length*.55 and p.z<height: poly.material_index=1
    pieces.append(torso)
    # Articulated limbs, joint bulbs, shaped paws / split cloven hooves.
    radius=.089 if cow else .043 if cat else .064
    for front in [True,False]:
        for side in [-1,1]:
            name=('front' if front else 'rear')+('.L' if side<0 else '.R')
            x=side*width*.70; y=length*(.65 if front else -.65)
            hip=Vector((x,y,height-.03)); foot=Vector((x,y,.08 if cow else .038))
            knee=hip.lerp(foot,.53); knee.y += -.06 if front else .08
            bone(name,hip,knee,'body'); bone(name+'.shin',knee,foot,name)
            bone(name+'.foot',foot,foot+Vector((0,.10,0)),name+'.shin')
            legs[name]=(hip,knee,foot,front)
            ell('Muscle '+name,hip.lerp(knee,.20),(radius*1.65,radius*1.65,(hip-knee).length*.43),coat,name)
            link('Upper '+name,hip,knee,radius*1.30,radius,coat,name)
            ell('Joint '+name,knee,(radius*1.05,)*3,coat,name+'.shin')
            link('Lower '+name,knee,foot,radius*.80,radius*.60,cream,name+'.shin')
            if cow:
                for s in [-1,1]: ell('Cloven hoof',(x+s*.039,y+.025,.067),(.036,.09,.067),hoof,name+'.foot')
            else:
                ell('Paw '+name,(x,y+.035,.042),(radius*1.28,radius*1.85,.042),cream,name+'.foot')
                for s in [-1,0,1]: ell('Toe',(x+s*radius*.60,y+.075,.028),(radius*.43,radius*.57,.025),cream,name+'.foot',12,8)
    tail_pts=[(0,-length*.85,height+.08)]
    if cow: tail_pts += [(0,-length*1.10,height-.14),(0,-length*1.15,height-.43),(0,-length*1.17,height-.67)]
    elif cat: tail_pts += [(0,-length*1.40,height+.14),(0,-length*1.61,height+.33),(0,-length*1.26,height+.43),(0,-length*.98,height+.34)]
    else: tail_pts += [(0,-length*1.28,height+.17),(0,-length*1.57,height+.35),(0,-length*1.78,height+.39)]
    for i in range(len(tail_pts)-1):
        bn='tail.%d'%i; bone(bn,tail_pts[i],tail_pts[i+1],'body' if i==0 else 'tail.%d'%(i-1))
    curve=bpy.data.curves.new('Soft curved tail','CURVE'); curve.dimensions='3D'
    curve.resolution_u=10; curve.bevel_depth=.027 if cow else .053 if cat else .062; curve.bevel_resolution=3; curve.use_fill_caps=True
    spline=curve.splines.new('BEZIER'); spline.bezier_points.add(len(tail_pts)-1)
    for i,p in enumerate(tail_pts):
        point=spline.bezier_points[i]; point.co=p; point.handle_left_type='AUTO'; point.handle_right_type='AUTO'; point.radius=1-i*.15
    tail=bpy.data.objects.new('Tail',curve); bpy.context.collection.objects.link(tail)
    bpy.ops.object.select_all(action='DESELECT'); tail.select_set(True); bpy.context.view_layer.objects.active=tail; bpy.ops.object.convert(target='MESH')
    tail=bpy.context.object; bind(tail,'Tail',coat,'tail.0'); tail.vertex_groups.clear()
    groups=[tail.vertex_groups.new(name='tail.%d'%i) for i in range(len(tail_pts)-1)]
    for vertex in tail.data.vertices:
        best=(1e9,0,0)
        for i in range(len(tail_pts)-1):
            a=Vector(tail_pts[i]); d=Vector(tail_pts[i+1])-a
            t=max(0,min(1,(vertex.co-a).dot(d)/d.length_squared)); distance=(vertex.co-a-d*t).length_squared
            if distance<best[0]: best=(distance,i,t)
        _,i,t=best
        # Blend only near the next bend, keeping the root attached to the body.
        w=max(0,(t-.5)*.8) if i<len(groups)-1 else 0
        groups[i].add([vertex.index],1-w,'REPLACE')
        if w: groups[i+1].add([vertex.index],w,'REPLACE')
    tip_radius=curve.bevel_depth*(1-(len(tail_pts)-1)*.15)
    ell('Tail tip',tail_pts[-1],(tip_radius,)*3,coat,'tail.%d'%(len(tail_pts)-2))
    if cow: ell('Tail tassel',tail_pts[-1],(.065,.058,.12),dark,'tail.2')
    # A single skinned mesh keeps each character inexpensive to instance.
    bpy.ops.object.select_all(action='DESELECT')
    for o in pieces: o.select_set(True)
    bpy.context.view_layer.objects.active=pieces[0]; bpy.ops.object.join(); mesh=bpy.context.object; mesh.name=kind.title()+'Mesh'
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    bpy.ops.object.select_all(action='DESELECT')
    armdata=bpy.data.armatures.new(kind.title()+'Skeleton'); arm=bpy.data.objects.new(kind.title()+'Rig',armdata); bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active=arm; arm.select_set(True); bpy.ops.object.mode_set(mode='EDIT')
    for name,(a,b,parent) in bones.items():
        eb=armdata.edit_bones.new(name); eb.head=a; eb.tail=b
        if parent: eb.parent=armdata.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT')
    mesh.parent=arm; mod=mesh.modifiers.new('Skin','ARMATURE'); mod.object=arm
    for pb in arm.pose.bones: pb.rotation_mode='QUATERNION'
    scene=bpy.context.scene; scene.render.fps=30
    def orient(name,a,b):
        pb=arm.pose.bones[name]
        q=(b-a).to_track_quat('Y','Z')
        pb.matrix=Matrix.Translation(a) @ q.to_matrix().to_4x4()
        bpy.context.view_layer.update()
    for clip,seconds in [('idle',4),('walk',1.6 if cow else 1.1),('trot',.85 if cow else .66),('graze' if cow else 'sniff',4)]:
        arm.animation_data_create(); action=bpy.data.actions.new(clip); arm.animation_data.action=action
        frames=round(seconds*30); scene.frame_start=1; scene.frame_end=frames+1
        for f in range(frames+1):
            scene.frame_set(f+1); t=f/frames; wave=math.sin(TAU*t)
            for pb in arm.pose.bones: pb.matrix_basis=Matrix.Identity(4)
            moving=clip in ('walk','trot'); stride=(.43 if cow else .16 if cat else .32)*(1.5 if clip=='trot' else 1)
            bob=(.010 if cow else .006)*math.cos(TAU*t*2) if moving else .004*wave
            arm.pose.bones['body'].location.y=bob # bone-local Y is horizontal; set matrix translation below
            arm.pose.bones['body'].matrix=Matrix.Translation((0,0,bob)) @ armdata.bones['body'].matrix_local
            bpy.context.view_layer.update()
            head=arm.pose.bones['head']; head.rotation_mode='XYZ'
            head.rotation_euler.x= -.08*math.sin(TAU*t+1) if moving else -.06*wave
            if clip in ('graze','sniff'):
                head.rotation_euler.x=-.65*(.5-.5*math.cos(TAU*t))
            bpy.context.view_layer.update()
            if clip in ('graze','sniff'):
                dip=.5-.5*math.cos(TAU*t)
                target=neck_end+Vector((0,width*.50*dip,-(head_z-width*.75)*dip))
                if cat: target=neck_end+Vector((0,.06*dip,-.12*dip))
                # Translate the head with a blended neck skin: no inherited scale/shear.
                head.matrix=Matrix.Translation(target) @ Matrix.Rotation(-.30*dip,4,'X') @ armdata.bones['head'].matrix_local.to_3x3().to_4x4()
                bpy.context.view_layer.update()
            for name,(hip,knee,foot,front) in legs.items():
                target=foot.copy(); h=hip+Vector((0,0,bob))
                if moving:
                    # Lateral-sequence four-beat walk; diagonal pairs for trot.
                    phase={'rear.L':0,'front.L':.25,'rear.R':.5,'front.R':.75}[name]
                    if clip=='trot': phase={'rear.L':0,'front.R':0,'rear.R':.5,'front.L':.5}[name]
                    p=(t+phase)%1; stance=.75 if clip=='walk' else .55
                    if p<stance: target.y += stride*(.5-p/stance)
                    else:
                        u=(p-stance)/(1-stance); target.y += stride*(-.5+u)
                        target.z += (.095 if cow else .055)*math.sin(math.pi*u)
                # Analytic two-link IK keeps the foot level during stance.
                a=(knee-hip).length; b=(foot-knee).length; delta=target-h; dist=min(delta.length,a+b-.0001); direction=delta.normalized()
                along=(a*a-b*b+dist*dist)/(2*dist)
                bend=Vector((0,-1 if front else 1,0)); bend=(bend-direction*bend.dot(direction)).normalized()
                joint=h+direction*along+bend*math.sqrt(max(0,a*a-along*along))
                orient(name,h,joint); orient(name+'.shin',joint,target)
                pb=arm.pose.bones[name+'.foot']; pb.matrix=Matrix.Translation(target-foot) @ armdata.bones[name+'.foot'].matrix_local
                bpy.context.view_layer.update()
            for i in range(len(tail_pts)-1):
                pb=arm.pose.bones['tail.%d'%i]; pb.rotation_mode='XYZ'; pb.rotation_euler.y=(.08 if cow else .17 if cat else .30)*math.sin(TAU*t*(2 if moving else 1)-i*.5)
            for name in ['ear.L','ear.R']:
                pb=arm.pose.bones[name]; pb.rotation_mode='XYZ'; pb.rotation_euler.x=.04*math.sin(TAU*t*2+(0 if name.endswith('L') else .8))
            for pb in arm.pose.bones:
                pb.keyframe_insert('location',frame=f+1)
                pb.keyframe_insert('rotation_euler' if pb.rotation_mode=='XYZ' else 'rotation_quaternion',frame=f+1)
                pb.keyframe_insert('scale',frame=f+1)
        arm.animation_data.action=None
        track=arm.animation_data.nla_tracks.new(); track.name=clip
        strip=track.strips.new(clip,1,action); strip.name=clip
        track.mute=True
    for track in arm.animation_data.nla_tracks: track.mute=False
    bpy.ops.object.select_all(action='DESELECT'); mesh.select_set(True); arm.select_set(True); bpy.context.view_layer.objects.active=arm
    bpy.ops.export_scene.gltf(filepath=str(OUT/(kind+'.glb')),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_skins=True,export_yup=True)
    triangles=sum(len(p.vertices)-2 for p in mesh.data.polygons)
    return {'species':kind,'triangles':triangles,'bones':len(bones),'clips':[t.name for t in arm.animation_data.nla_tracks],'bytes':(OUT/(kind+'.glb')).stat().st_size}

requested=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ['cat','dog','cow']
if not requested or any(k not in ['cat','dog','cow'] for k in requested): raise ValueError('Expected cat, dog, or cow')
previous=json.loads((OUT/'manifest.json').read_text())['animals'] if (OUT/'manifest.json').exists() else []
updated={row['species']:row for row in previous}
for kind in requested: updated[kind]=build(kind)
stats=[updated[kind] for kind in ['cat','dog','cow'] if kind in updated]
(OUT/'manifest.json').write_text(json.dumps({'generator':'development/tools/woodland_animals.py','units':'meters','forward':'-Z','animals':stats},indent=2)+'\n')
print('ANIMALS_EXPORTED',json.dumps(stats))
