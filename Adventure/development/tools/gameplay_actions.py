"""Additive gameplay poses authored on the inspected, unmodified PlayerMesh rig."""
import bpy, math
from pathlib import Path
from mathutils import Quaternion
root=Path(__file__).resolve().parents[3]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(root/'PlayerMesh/hero_male.glb'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
print('INSPECTED_RIG',rig.name,[b.name for b in rig.data.bones])
rig.animation_data_clear()
for a in list(bpy.data.actions): bpy.data.actions.remove(a)
base={b.name:(b.location.copy(),b.rotation_quaternion.copy(),b.scale.copy()) for b in rig.pose.bones}
specs={'AxeSwing':(0.8,{'bicep.R':(-1.5,0,-.3),'forearm.R':(-.8,0,0),'torso':(0,0,-.22)}),'PickaxeSwing':(.9,{'bicep.R':(-2,0,-.2),'bicep.L':(-1.3,0,.3),'forearm.R':(-.5,0,0)}),'HammerBuild':(.65,{'bicep.R':(-1.1,0,-.3),'forearm.R':(-1,0,0)}),'GatherPlant':(.8,{'torso':(.55,0,0),'bicep.R':(-.8,0,-.3),'forearm.R':(-.45,0,0)}),'CraftStanding':(2.4,{'bicep.R':(-.7,0,-.3),'bicep.L':(-.7,0,.3),'forearm.R':(-1,0,0),'forearm.L':(-1,0,0)}),'CraftWorkbench':(2.4,{'torso':(.2,0,0),'bicep.R':(-.9,0,-.2),'bicep.L':(-.9,0,.2),'forearm.R':(-.7,0,0)}),'Pickup':(.8,{'torso':(.45,0,0),'bicep.R':(-.8,0,0)})}
for name,(duration,poses) in specs.items():
 action=bpy.data.actions.new(name); action.use_fake_user=True; rig.animation_data_create(); rig.animation_data.action=action
 frames=[(0,0),(int(duration*30*.3),1),(int(duration*30*.55),.18),(int(duration*30),0)]
 for frame,weight in frames:
  for bone in rig.pose.bones:
   loc,rot,scale=base[bone.name]; bone.location=loc; bone.scale=scale; bone.rotation_mode='QUATERNION'; q=rot.copy()
   if bone.name in poses:
    for axis,angle in zip([(1,0,0),(0,1,0),(0,0,1)],poses[bone.name]): q=q@Quaternion(axis,angle*weight)
   bone.rotation_quaternion=q
   bone.keyframe_insert('rotation_quaternion',frame=frame,group=bone.name)
   bone.keyframe_insert('location',frame=frame,group=bone.name)
   bone.keyframe_insert('scale',frame=frame,group=bone.name)
 rig.animation_data.action=None
# Swimming loops use the same rig and keep the original skin and rest transforms.
for name,moving in [('SwimIdle',False),('SwimForward',True)]:
 action=bpy.data.actions.new(name); action.use_fake_user=True; rig.animation_data.action=action
 for frame in range(0,49,6):
  phase=frame/48*math.tau
  for bone in rig.pose.bones:
   loc,rot,scale=base[bone.name]; bone.location=loc; bone.scale=scale; bone.rotation_mode='QUATERNION'; q=rot.copy()
   angles=None
   if bone.name=='torso': angles=(.18 if moving else .08,0,0)
   if bone.name=='bicep.R': angles=(-.7+math.sin(phase)*(.8 if moving else .15),0,-.5)
   if bone.name=='bicep.L': angles=(-.7+math.sin(phase+math.pi)*(.8 if moving else .15),0,.5)
   if bone.name.startswith('forearm'): angles=(-.7,0,0)
   if bone.name=='thigh.R': angles=(math.sin(phase)*.32,0,0)
   if bone.name=='thigh.L': angles=(math.sin(phase+math.pi)*.32,0,0)
   if bone.name.startswith('shin'): angles=(.2+abs(math.sin(phase))*.2,0,0)
   if angles:
    for axis,angle in zip([(1,0,0),(0,1,0),(0,0,1)],angles): q=q@Quaternion(axis,angle)
   bone.rotation_quaternion=q
   for channel in ['rotation_quaternion','location','scale']: bone.keyframe_insert(channel,frame=frame,group=bone.name)
 rig.animation_data.action=None
bpy.context.scene.render.fps=30
bpy.ops.export_scene.gltf(filepath=str(root/'Adventure/generated/GameplayActions.glb'),export_format='GLB',export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True)
print('GAMEPLAY_ACTIONS_EXPORTED',list(specs))
