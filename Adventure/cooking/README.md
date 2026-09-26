# Campfire cooking

Three original Blender-authored GLBs: `cooking_fire.glb`, `raw_meat.glb`, and
`cooked_meat.glb`. Rebuild with:

```text
blender --background --python development/tools/cooking_assets.py
```

Each village gets a cooking fire on clear, dry ground. The build catalog also
offers **Crafting → Cooking → Cooking fire** for 8 wood and 8 stone. Stand within
3 meters, then choose **Cook at fire** on raw meat in inventory, or **Grilled meat**
in Crafting. One raw meat plus one wood cooks for 4 seconds into one grilled meat.
The host checks ingredients and station range again at completion. Walking away
cancels the action. Eating grilled meat consumes one item and restores 40 food.

The map marks cooking fires orange and living animals green. Food inventory
details display the actual food model in a small 3D preview.

Run `showcase.tscn` for an art preview. `Adventure/cooking_capture.gd` captures
the props, a village fire in-game, and the food inventory into `Adventure/qa`.
`Adventure/cooking_check.gd` tests recipe completion, cancellation, duplicate
reward prevention, station restrictions, model loading, and habitat clearance.
