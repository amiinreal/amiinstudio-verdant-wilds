# Resonant Wilds

A self-contained procedural island for OpenZELD, built with the original Styled Nature MegaKit glTF assets. All additions live in this folder. Existing game scenes, player scripts, input bindings, main-scene selection, and kit source assets are unchanged.

## Open and play

1. In your existing Godot project, open **`styled Nature megaKit/ProceduralWorld/preview.tscn`**.
2. Press **F6** (Run Current Scene).
3. Click **Explore on foot**, or press **Tab**.

**F5 still runs your existing game.** This preview has its own first-person explorer; it does not replace your existing character.

| Control | Action |
| --- | --- |
| WASD / mouse | Walk / look |
| Shift / Space | Run / jump |
| Tab | Switch between walking and island overview |
| Escape | Release cursor to use the seed field |
| Left click in the world | Capture cursor while walking |
| Right drag / mouse wheel | Rotate / zoom the overview |
| E near a clearing | Toggle its glow and play an original synthesized bell |
| Seed field + Generate island | Rebuild the island from an integer seed |

## What the world contains

- A 224-metre terrain tile with an irregular island coast, gently rolling interior, raised outer hills, lake, and animated ocean water.
- Pinewatch pine forest, autumn-colored Whisperwood, Sunmeadow, and the Stillwater lakeside region.
- Six music clearings connected by six spokes and a continuous walking loop. Routes and gathering areas stay level across seeds.
- Six player spawn markers in the central gathering area.
- Original kit trees, flowering bushes, ferns, mushrooms, flowers, grasses, clover, rocks, and stone paving, retaining imported textures and mesh transforms.
- At the default seed/density: approximately 5,000 kit placements, including 300 scattered trees plus six landmark trees. Counts vary by seed.
- Terrain collision, simplified tree-trunk and boulder collision, slope and shoreline exclusions, and clear walking corridors.
- Vegetation grouped by asset and spatial cell using Godot MultiMeshes. Small plants stop rendering at a distance; imported mesh LODs are retained.
- Overview map, adjustable seed, on-foot preview, and six resonance hooks.

This is a finite island generator with repeatable seeds. It does not implement endless chunk streaming, online sessions, navigation meshes, swimming, or full music puzzles. The exploration preview returns you to the central gathering area if you enter deep water. Terrain and water are generated; vegetation and stone props come from the kit.

## Customize in the Inspector

Open `world.tscn` and select **ResonantWilds**, or select **World** in `preview.tscn`.

| Setting | Default | Purpose |
| --- | --- | --- |
| World Seed | 73129 | Reproduce or change terrain and placements |
| World Size | 224 | 160–360 metres; scales the layout and kit assets together |
| Terrain Resolution | 160 | Grid subdivisions; higher means smoother terrain and more triangles |
| Vegetation Density | 1.2 | 0.25–2.0; adjusts tree spacing and ground-cover attempts |
| Generate On Ready | On | Generate when the scene enters the tree, including editor preview |
| Create Collisions | On | Generate terrain and simplified solid-prop collision |
| Rebuild island | Button | Apply Inspector changes immediately |

The generated children are intentionally not serialized into the scene. The compact generator recreates them when opened or run. Regeneration is synchronous; expect a brief pause (roughly one second on the machine used for validation). The reusable world has no environment, camera, UI, or input actions; these live in the separate preview.

## Later integration into the game

Instance `world.tscn` into a future level when you choose to integrate it. Keep the world's scale uniform. The following API uses **world-local coordinates**:

```gdscript
# Spawn index wraps across six safe starting positions.
player.global_transform = world.global_transform * world.get_spawn_transform(player_index)

# Height and biome for a world-local X/Z position.
var height: float = world.sample_height(Vector2(x, z))
var biome: String = world.biome_at(Vector2(x, z))

# Stable site IDs: Wind, Light, Water, Earth, Spirit, Nature (0–5).
world.set_resonance(site_id, true)
world.resonance_changed.connect(on_resonance_changed)
world.world_generated.connect(on_world_generated)
```

For future multiplayer, synchronize the seed **and all generation settings** before generating, using the same generator version, Godot version, and kit assets on every peer. Deterministic generation is a foundation for networking, not a networking implementation. Replicate authoritative puzzle state separately and call `set_resonance()` to display it. Regeneration clears resonance state and recreates site nodes; reconnect any references to generated nodes after `world_generated`.

## Files

- `world.tscn` / `world.gd`: reusable world and generator.
- `water.gdshader`: animated water material.
- `preview.tscn` / `preview.gd`: standalone environment and exploration interface.
- `explorer.gd` / `map.gd`: preview movement and map drawing.
- `validate.gd`: deterministic generation, multiple seeds/sizes, route continuity, ground collisions, and resonance checks.
- `validate_preview.gd`: preview cameras, physical walking, bell playback creation, and seed controls.
- `capture_preview.gd`: optional graphical QA; writes the two preview PNGs here and quits.
- `preview_overview.png` / `preview_ground.png`: renders from the actual Godot scene.
- `source_baseline.json`: hashes of the original project configuration, scenes, and scripts used to verify they stayed unchanged.

## Validation commands

From the project root, using your Godot executable:

```powershell
& '<Godot.exe>' --headless --path . --script 'res://styled Nature megaKit/ProceduralWorld/validate.gd'
& '<Godot.exe>' --headless --path . --script 'res://styled Nature megaKit/ProceduralWorld/validate_preview.gd'
```

Tested with Godot 4.7.2. Visual QA used your project's D3D12 Forward Plus renderer; a Compatibility-renderer smoke check also completed. Forward Plus provides the intended lighting, fog, and material appearance. Godot may update its normal import/cache data when loading new files.

Implementation references: [Godot MultiMesh](https://docs.godotengine.org/en/stable/classes/class_multimesh.html), [SurfaceTool](https://docs.godotengine.org/en/stable/classes/class_surfacetool.html).
