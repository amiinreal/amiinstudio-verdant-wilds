# Gameplay and visual polish pass

Applied to the existing `godot-music-game-` project, retaining the main Adventure scene, PlayerMesh rig, ENet authority, stable ownership credentials, world streaming, and version 3 saves. `open-zeld` was inspected but is a separate movement prototype.

## Playing

- B opens the building catalog. Search, category/subcategory filters, and persistent favorites narrow the list. Costs show held/required amounts and shortages. Click a model or its name to enter preview mode; selection never spends materials.
- Aim the camera at terrain or a structure. The exact kit model and foundation feet appear as a local, collision-free preview. Green means valid, cyan means a valid connector, red means invalid. Left click places through the server; R rotates; wheel cycles; Shift bypasses connector attraction; right click returns to the catalog; B/Esc exits.
- Delete during preview enters disassembly targeting. Aim, left click, then confirm. The server checks ownership, distance, cooldown, and structural dependents. Successful removal returns 50% (rounded down) of each material. Remove roofs and upper components before their supports.
- E opens inventory; Esc opens the camp menu. Stacks display up to 99 per card with categories and item details. Number keys 1–8 select the compact hotbar. The original aggregate inventory remains authoritative and compatible with saves.
- Axe gathers wood; pickaxe gathers stone; plants use a hand-gather clip. Host rewards occur at the animation impact deadline, with range, tool, obstruction, and depletion checks repeated at impact.
- Craft through the Crafting page. Jobs take time and moving 1.4 m away cancels them without payment. The host revalidates ingredients at completion and grants the result once. The workbench offers a more efficient plank recipe while within 3 m.

## Content and architecture

34 `.tres` building definitions in `data/buildings` reference verified kit scenes and rendered thumbnails. Existing module IDs remain stable. The main source is Medieval Village MegaKit, with five functional catalog additions from the already supplied Fantasy Props kit. Structural modules retain the measured 2 m bay / 3 m storey grid. Connector metadata is exposed by each Resource; decoration supports ungridded positions.

Six recipe Resources live in `data/recipes`. Station, result item, quantity, time, animation, ingredients, and effect type are extensible. No client can submit inventory results.

Blender source: `development/tools/gameplay_actions.py`; generated `generated/GameplayActions.glb`. Nine new clips target the inspected original skeleton: AxeSwing, PickaxeSwing, HammerBuild, GatherPlant, CraftStanding, CraftWorkbench, Pickup, SwimIdle, SwimForward. Existing locomotion and skeleton are preserved. Tools remain attached to `item_socket`. These are initial authored animations, not a complete future carry/sit/sleep/emote library.

Ground vegetation still uses streamed MultiMeshes from all four supplied grass FBXs. A separate deterministic meadow pass preserves existing harvest resource identities. A world mask suppresses grass around static collision, natural solids, and placed floor/foundation footprints, and updates on construction changes. Shader interaction accepts six replicated player positions. No per-blade physics or particle networking is introduced.

River UVs encode downstream distance. Water has scrolling ripples, Fresnel response, depth tint/transparency and shoreline foam. Waterfall mist, splash and looping positional audio accompany the existing falling surface. Shallow-water splashes and expanding ripples are derived locally from replicated player movement. Eleven reusable VFX scene entry points live in `vfx`.

## Validation

Godot 4.7.2 headless runtime checks, actual Forward+ renders, model thumbnail renders, action track resolution, authority/economy regression checks, modular shelter and save/reload tests. `world_check.gd` includes timed reward, duplicate-job, cancellation, station and safe-disassembly coverage. `world_network_check.gd` uses separate localhost host/client processes and reconnects the client; it checks persistent identity, private inventory, authoritative resource state, replicated structures, and streaming reconstruction.

QA scripts write fixtures under `Adventure/qa`; gameplay saves are not used by the checks. Multiplayer capacity remains six; the integration test uses two concurrent peers, not an external six-person Internet session. Screenshots and logs are in `qa/polish*`.

## Practical limits

The water and action clips still warrant hands-on art tuning. The catalog includes storage models, not a new shared-container inventory system. The pass does not add farming, defensive combat, painting, a full carry animation set, matchmaking, or host migration. Grass masks conservatively use world-space footprints; this avoids intersections but can leave extra clearance beside irregular objects. Startup generation is synchronous and additional meadow coverage increases initial generation time.


## Gathering, item UI, swimming and clearing follow-up

- Previously decorative procedural trees and medium rocks now have harvestable resource IDs, while existing IDs and randomized transforms are preserved. Axe/pickaxe targeting ignores incompatible nearby plants. Resource obstruction rays exclude only the chosen target collider.
- Axe, pickaxe and hammer now use corrected grip transforms on the original hand socket.
- **E** toggles inventory; **Esc** opens the camp menu. Inventory and all eight numbered hotbar buttons show rendered item pictures. Number keys retain selection highlighting, and exploration keeps a compact controls panel visible. Use **LMB/Q** for tools; **1** axe, **2** pickaxe, **3** hammer, **6** empty hands for plants.
- **C** clears a 6 m grass patch at your feet, or at the build preview while building. The host checks distance, ownership proximity and cooldown. Cleared patches replicate and persist in existing world saves. Clearing does not flatten terrain or remove roads/water protection; mine trees and rocks before building over them.
- Deep water engages server-controlled buoyancy and swimming movement, using new Blender-authored SwimIdle and SwimForward loops on the original rig. Tools are hidden in water, and swim state/animation replicate to other players. Shallow shores return to walking.
- Follow-up captures: `qa/fixed_grip_axe.png`, `qa/fixed_grip_pickaxe.png`, `qa/fixed_grip_hammer.png`, `qa/swimming.png`, `qa/grass_before.png`, `qa/grass_after.png`.

Follow-up verification: gameplay/persistence regression (`qa/fix-tests2.log`), host/client gathering, swim replication and cleared-grass reconnect checks (`qa/fix-host2.log`, `qa/fix-client2.log`), and E/number-key/search focus checks (`qa/fix-ui.log`).


For the subsequent Blender grass, terrain flattening, unrestricted regions, ground-fitting foundations and peaceful score, see [Woodland update](WOODLAND_UPDATE.md).
