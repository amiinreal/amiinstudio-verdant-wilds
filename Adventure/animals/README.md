# Woodland animals

Original Blender-authored ginger kitten, brown/ivory dog, and brown/cream cow.
The runtime files are self-contained **glTF 2.0 binary `.glb`** models. No `.blend`
files, external textures, or Blender installation are needed to run/import them.

## Preview

Open `Adventure/animals/showcase.tscn` in Godot and run the current scene (F6).
Keys **1 / 2 / 3 / 4** select idle / walk / trot / sniff (cow: graze).
**Space** pauses/resumes the animation. Models use meters, Y up, and -Z forward.
Each GLB imports with a Skeleton3D and AnimationPlayer. Enable linear looping
when using a GLB outside the provided animal controller or showcase.

## Game integration

`open_world.gd` creates `WoodlandAnimals` under its generated world root after
terrain/resource placement. A separate seeded RNG selects nine short, level
corridors in distinct habitats: cats near homes, dogs in open village areas,
and cows on the meadow terrace inside each village fence. Routes reject water,
roads, steep slopes, houses, fences, resources, other animal routes, and cooking
fires. Unusable candidates are skipped. Rendering/animation stops beyond
120 meters. Population ownership follows the world root, including rebuilds.

Animals can be hit with **LMB/Q** using the normal tool action, within 3 meters
and in front of the player. The host checks reach, obstacles, tools and cooldowns
at impact. Cows have 60 health; cats/dogs have 30. Axe/pickaxe damage is 30,
hands/hammer damage is 15. Defeated cows yield **three meat**, directly into the
attacker's inventory; cats/dogs do not yield meat. Defeated animals disappear.
Health/depletion is saved and replicated with world state, preventing duplicate
rewards and restoring the same state for late joiners. Animal paths use the
shared session clock. Hitbox areas do not obstruct player movement.

Open inventory with **E/I**, choose **Food**, then select raw meat. Stand within
3 meters of a village or player-built cooking fire and select **Cook at fire**
(also available in Crafting). Cooking takes 4 seconds and consumes 1 raw meat
plus 1 wood for 1 grilled meat. Moving away cancels without consuming ingredients.
Select cooked meat and **Eat one** to restore 40 food, capped at 100. Raw meat
must be cooked; full players do not consume food. **Remove one** discards one item.
New profiles start with no food
items; fullness slowly decreases during play, without starvation damage.
**H** or the inventory checkbox toggles the hotbar; the preference is saved locally.
Inventory categories show only matching owned stacks and refresh after changes.

Runtime walks match authored stance speed, alternate with sniff/graze/idle, and turn at rest.
They do not implement navigation around newly player-built structures.

The walk is a four-beat lateral sequence with 75% stance; trot uses diagonal
pairs. Analytic two-link leg poses hold feet level during each stance. Tail,
ear, body and head motion are baked into the skeleton. The generator authors
all loop endpoints identically. Terrain IK is not implemented; routes are
restricted to gentle ground.

## Rebuild and checks

From the project directory:

```text
blender --background --python development/tools/woodland_animals.py
godot --headless --editor --import
godot --headless --script Adventure/animal_check.gd
godot --headless --script Adventure/animal_world_check.gd
godot --headless --script Adventure/animal_gameplay_check.gd
godot --headless --script Adventure/cooking_check.gd
godot --script Adventure/animal_capture.gd
```

`manifest.json` records current geometry, bone counts, file sizes, and clips.
The Python generator is the editable source of truth and exports only GLBs.
QA captures/logs go to the ignored `Adventure/qa` directory.

The existing Windows Launcher export uses `all_resources`, so it includes these
assets automatically on the next game export. The launcher executable does not
need changing for this asset update. Local project changes do not update an
already published game; that needs the normal game release and signed manifest
publication. Publishing source to GitHub does not itself update the signed launcher game release.

## References

Original geometry and animation; no downloaded third-party models or textures.
Motion principles studied from [Animation Mentor's quadruped walk tutorial](https://www.animationmentor.com/blog/tutorial-how-to-animate-a-quadruped-walk-cycle/).
Format follows [Godot's recommended glTF workflow](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html).
