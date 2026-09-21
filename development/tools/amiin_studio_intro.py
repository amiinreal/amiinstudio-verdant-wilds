"""Creates the editable Blender source and title-card render for the Amiin Studio intro."""
import bpy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
logo_path = ROOT / "Logo" / "X8y06N.png"
out = ROOT / "Adventure" / "generated"

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 1600
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.film_transparent = False
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.003, 0.008, 0.012, 1)
scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.02
scene.render.filepath = str(out / "amiin_studio_intro.png")
scene.frame_start = 1
scene.frame_end = 132

# Full-screen logo plane; the original raster stays the source texture.
mesh = bpy.data.meshes.new("AmiinStudioLogoPlane")
mesh.from_pydata([(-4,-1.6,0),(4,-1.6,0),(4,1.6,0),(-4,1.6,0)], [], [(0,1,2,3)])
uvs = mesh.uv_layers.new(name="UVMap")
for loop, uv in zip(uvs.data, [(0,0),(1,0),(1,1),(0,1)]):
    loop.uv = uv
logo = bpy.data.objects.new("Amiin Studio Logo", mesh)
bpy.context.collection.objects.link(logo)
mat = bpy.data.materials.new("Original Amiin Studio logo")
mat.use_nodes = True
nodes = mat.node_tree.nodes
links = mat.node_tree.links
for n in list(nodes): nodes.remove(n)
output = nodes.new("ShaderNodeOutputMaterial")
emission = nodes.new("ShaderNodeEmission")
texture = nodes.new("ShaderNodeTexImage")
texture.image = bpy.data.images.load(str(logo_path), check_existing=True)
links.new(texture.outputs["Color"], emission.inputs["Color"])
links.new(emission.outputs["Emission"], output.inputs["Surface"])
emission.inputs["Strength"].default_value = 0.0
logo.data.materials.append(mat)

# Animate a calm reveal: dim, scale in, settle, then a soft glow.
logo.scale = (0.72,0.72,0.72); logo.keyframe_insert("scale", frame=1)
logo.scale = (1.06,1.06,1.06); logo.keyframe_insert("scale", frame=42)
logo.scale = (1.0,1.0,1.0); logo.keyframe_insert("scale", frame=68)
emission.inputs["Strength"].default_value = 0.0; emission.inputs["Strength"].keyframe_insert("default_value", frame=1)
emission.inputs["Strength"].default_value = 1.0; emission.inputs["Strength"].keyframe_insert("default_value", frame=34)
emission.inputs["Strength"].default_value = 1.5; emission.inputs["Strength"].keyframe_insert("default_value", frame=57)
emission.inputs["Strength"].default_value = 1.0; emission.inputs["Strength"].keyframe_insert("default_value", frame=85)

# Two orange light ribbons sweep through the logo during the reveal.
for side in (-1,1):
    curve = bpy.data.curves.new("Warm studio sweep", "CURVE")
    curve.dimensions = "3D"; curve.bevel_depth = .018; curve.bevel_resolution = 3
    spline = curve.splines.new("BEZIER"); spline.bezier_points.add(2)
    for point, co in zip(spline.bezier_points,[(-5,side*.7,.15),(0,0,.15),(5,side*.7,.15)]):
        point.co=co; point.handle_left_type="AUTO"; point.handle_right_type="AUTO"
    obj=bpy.data.objects.new("Logo reveal ribbon",curve); bpy.context.collection.objects.link(obj)
    ribbon=bpy.data.materials.new("Amiin orange glow"); ribbon.diffuse_color=(1,.19,.015,1); ribbon.use_nodes=True
    ribbon.node_tree.nodes.get("Principled BSDF").inputs["Emission Color"].default_value=(1,.06,.005,1)
    ribbon.node_tree.nodes.get("Principled BSDF").inputs["Emission Strength"].default_value=5
    curve.materials.append(ribbon)
    obj.hide_render=True; obj.keyframe_insert("hide_render",frame=1)
    obj.hide_render=False; obj.keyframe_insert("hide_render",frame=23)
    obj.hide_render=False; obj.keyframe_insert("hide_render",frame=70)
    obj.hide_render=True; obj.keyframe_insert("hide_render",frame=90)

camera_data=bpy.data.cameras.new("Title camera")
camera=bpy.data.objects.new("Title camera",camera_data); bpy.context.collection.objects.link(camera)
camera.location=(0,0,10); camera.data.type="ORTHO"; camera.data.ortho_scale=10
scene.camera=camera

# The runtime UI handles the fade; use the settled Blender frame as its title card.
scene.frame_set(100)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "development" / "blender" / "AmiinStudioLogoIntro.blend"))
bpy.ops.render.render(write_still=True)
