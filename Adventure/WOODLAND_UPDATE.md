# Woodland grass and terrain update

Implemented in the existing `godot-music-game-` project. The supplied woodland screenshot guides the short grass and rolling terrain; the game still uses its existing character and building kits.

- **V** levels the ground at your feet, or at the visible build preview. It creates a level center approximately 12 m across, feathering into the surrounding ground over a 24 m diameter. The host chooses the elevation; vertices, collision, vegetation and multiplayer clients update together. Terrain changes persist in the existing world save.
- **C** clears a 6 m square of grass. Flattening also clears the center of the site.
- **B** opens building. Foundations automatically choose the highest corner of the slope (or the water surface), keep the floor horizontal and extend their four supports down to the terrain. Ground-floor pieces also work without supporting walls; upper floors retain structural requirements. Roads, water and landmark regions no longer have blanket placement exclusions.
- Natural obstacles still need gathering, and another player's structures cannot be overwritten. Flatten before construction: terraforming keeps 17 m away from existing player pieces and avoids authored buildings/bridges. Extremely steep areas requiring more than 8 m of height change in one stroke are refused. Foundation supports can span up to 12 m.
- All queued trees, including the Elder Crown, and the camp's fallen logs now register as harvestable resources.
- Settings includes a peaceful music volume slider; zero mutes. The original 80-second harp-and-pad loop uses synthesized notes, with no external samples.

## Assets and rendering

`development/blender/WoodlandGrass.blend` is the editable Blender source. `development/tools/woodland_grass.py` rebuilds it and exports three GLB variants into `Adventure/generated`. The Blender source directory is excluded from Godot import so the game does not require Blender to launch.

The new renderer replaces old grass batches. Each variant contains 96 curved, tapered, solid blades. Grass streams in 16 m chunks near the camera, bends around players, moves in the wind, fades at distance, and uses the same terrain triangles and clearing mask as gameplay. No individual grass collision bodies are created.

New worlds use landscape version 2: broad woodland bowls, rolling meadow hills and a more broken mountain ridge. Existing saves without this version field regenerate their original version 1 terrain, preserving old buildings and resource locations. Both versions receive the new grass and building tools.

## Validation

`world_check.gd`: existing gameplay, economy, building, persistence and swimming regression suite.

`woodland_check.gd`: Blender import, looping audio, host flattening, terrain/collision agreement, save/reload/reset, out-of-range rejection, ground floors and extended foundations; also captures game images when run with a renderer.

`world_network_check.gd`: two real ENet peers, gathering/building, terrain replication, swimming and reconnect persistence.

`phase_smoke.gd`: all menu pages, inventory and number-key hotbar selection.
