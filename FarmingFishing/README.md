# Field & Stream — farming and fishing assets

Original low-poly models for OpenZELD, with warm earth, leafy greens, golden wheat and faceted fish. Minecraft-inspired modular farm blocks use original geometry and materials.

## Preview

Open `Scenes/preview.tscn` in Godot and press **F6**. Right-drag to orbit; scroll to zoom. The rear rows show seeds, four growth stages and harvest items. The front garden grows in 16 seconds. Use **Harvest ripe crops**, **Replant**, **Water / dry**, and **Pause / resume** to exercise the crop lifecycle. Fish tails loop automatically.

The project's existing main scene is unchanged. This pack supplies assets and reusable crop/plot components, not a player inventory or a fishing minigame.

## Models (23 GLB files)

| Files in Models | Contents |
| --- | --- |
| `carrot_seeds`, `wheat_seeds` | Loose seed clusters |
| `carrot_stage_0` … `carrot_stage_3` | Sprout, young foliage, growing root, mature carrot |
| `wheat_stage_0` … `wheat_stage_3` | Sprout, leafy shoots, green heads, golden ripe heads |
| `carrot_harvest`, `wheat_harvest` | Whole lifted carrot and tied wheat bundle |
| `carrot_growing`, `wheat_growing` | Baked 10-second growth animations with four stages |
| `farmland_dry`, `farmland_wet` | One-metre square tilled soil blocks |
| `irrigation_channel` | One-metre water channel with soil banks |
| `fishing_rod`, `fishing_bobber`, `fishing_hook`, `landing_net` | Bamboo rod with reel/line, red-white float, barbed hook and woven net |
| `river_fish`, `salmon` | Two fish variants with baked tail-swim animation |

All assets use metre units and embedded materials, with no external textures. Godot imports them Y-up. Crop origins sit at the soil surface; carrot roots extend underground. Harvest carrots are raised above their origin to expose the entire root. Rod and net origins sit at the bottom of their handles. Farm blocks are 1 × 1 m horizontally and extend about 0.43 m below the surface.

The GLB animations are imported through AnimationPlayer. Play the imported non-RESET animation; set loop mode for swimming. Growth animations are intended to play once and hold their last pose. The standalone GLBs do not automatically start playback.

## Reusable Godot components

Drag `Scenes/farm_plot.tscn` into a level, then add either `carrot_crop.tscn` or `wheat_crop.tscn` as its child at local position zero. The plot provides ground collision. Keep its grid spacing at 1 metre.

```gdscript
$FarmPlot.set_watered(true) # Changes soil and child crop hydration.
$FarmPlot/CarrotCrop.growth_seconds = 120.0
$FarmPlot/CarrotCrop.plant("carrot")
# After maturity:
var loot: Dictionary = $FarmPlot/CarrotCrop.harvest()
# {"item": "carrot", "amount": 1, "seeds": 2}; {} if not ripe.
```

Crop exports: `crop_type`, `growth_seconds`, `watered`, `growing`, `initial_progress`. Signals: `matured` and `harvested(item, amount)`. Four visual stages emerge with a short scale animation. Growth pauses when dry; moisture does not evaporate automatically. Irrigation is a visual model; proximity-based watering is not implemented. Harvest returns data for an inventory to consume. Individual props have no pickup/physics behavior.

## Editable source and rebuilding

`Source/field_and_stream.blend` contains every asset and a rendered presentation layout. `Source/build_assets.py` generates the geometry, animations, GLBs and contact sheet using Blender Python, with deterministic variation. `Source/.gdignore` keeps the source Blender file out of Godot's automatic import pipeline.

Run with Blender 5.2:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python FarmingFishing/Source/build_assets.py
```

Validation: run Godot with `--headless --path . --script res://FarmingFishing/Scripts/validate.gd` after importing the project. It loads all models, checks animation presence and exercises dry/wet growth, maturity, harvesting and replanting. `Scripts/capture.gd` captures the preview using a graphics renderer.
