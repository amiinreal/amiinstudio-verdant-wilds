# Custom roofs and loading

## Building

Open **B → Structure → Custom roofs**. Choose a 2 m panel, aim at a wall's top edge, then left-click to place. **R** rotates it. Aim at the edge of an existing panel to extend sideways, uphill, or join an opposite slope into a ridge. The preview aligns the height automatically. **Shift** bypasses edge attraction for manual grid positioning.

Five pieces are available: 1 m-rise slope, 2 m-rise slope, flat panel, outer corner, and inner corner. Inner corners join sloping edges; start with a slope or outer corner on a wall. Each costs two wood. Collision follows the panel mesh. Ownership, materials, structural support, saving, refunds and multiplayer replication use the existing building system.

The four whole-roof presets are absent from the catalog and the authority rejects new placements of them. Existing saved roofs and village architecture still load, and old player roofs can be disassembled. Every new roof panel needs a connected route to a supporting wall; a detached group cannot support itself.

## Loading

The title menu no longer generates a world. Starting or joining displays a full-screen percentage bar with the current generation stage. Progress covers save loading, terrain, routes, scenery, ecology, nearby models, map and lighting.

Terrain and vegetation generation are cached separately from saved player changes. Cache keys include seed, landscape version and generation-source signatures. Caches contain data only, use temporary files, and are regenerated if unavailable. Editor runs use `.godot/verdant_cache`; exported games use their user-data cache. Nature models load on demand. Road grading skips terrain outside the affected strip.

Observed on this machine: menu initialization 0.3–0.5 seconds; cached world reconstruction approximately 2.4–3 seconds. First-time generation and graphics preparation remain slower (approximately 18 seconds in the rendered cold-cache test). These are development test measurements, not a frame-rate or hardware guarantee.

## Checks

`roof_loading_check.gd` exercises all panel types, roof edge snapping, both owners, unsupported chains, old-save definitions, cache equivalence, and progress completion; it also renders the roof and loading UI.

`world_check.gd` now builds its shelter from individual panels and checks normal economy, saving, removal and gameplay. `world_network_check.gd` places a wall and roof through authority requests and checks replication alongside terrain and reconnect behavior. `phase_smoke.gd` covers the menus and inventory controls.
