> Current exploration/building controls and this pass: [POLISH_PASS.md](POLISH_PASS.md). The older music-game notes below describe earlier development.

# The Resonant Wilds — playable music adventure

This is the new adventure in **godot-music-game-**. The earlier isolated island demo remains in `styled Nature megaKit/ProceduralWorld`; the game now starts from `Adventure/main.tscn`. The separate `open-zeld` project was not modified by this upgrade.

## Play now

Open **Adventure/main.tscn** in Godot and press **F6**. It is also configured as this project's main scene for F5. If your already-open editor has not reloaded the changed project settings, F6 runs the correct scene directly.

Choose **Begin solo**, **Host an expedition**, or **Join expedition**. The first shrine is directly in front of your traveler. Play **1, 2, 3** to restore it and watch both routes to the next islands rise from the sea.

This is a playable adventure prototype: seven regions, real progression, musical abilities, cooperative puzzles, and direct-connect multiplayer. It is a finite procedural archipelago, with new seeds and melodies for subsequent expeditions.

## Controls

| Control | Action |
| --- | --- |
| WASD / mouse | Move / turn third-person camera |
| Space | Jump |
| 1–5 | Play pentatonic instrument notes (DO, RE, MI, SOL, LA) |
| Q | Hear the nearby shrine's clue |
| E | Inspect a shrine; restore health and set a checkpoint at a solved shrine |
| R | Echo the last four played notes (play a phrase first) |
| J | Songbook: learned abilities and progression |
| M | Map: islands, unlocked crossings, and travelers |
| H | Recall to your last checkpoint |
| Escape | Open / close the menu |

The world continues while menus are open. Solo/host progress is saved automatically after shrine completion and treasure collection. **Continue save** restores that expedition's unlocked world and shared memories, starting you at camp. Client progress belongs to the host's expedition.

## Adventure flow

1. **Firstlight Camp:** answer three notes to learn Bloom and grow both first crossings.
2. **Canopy of Winds:** reverse the displayed/heard phrase. Learn Gust and unlock a route to Stonewake.
3. **The Sunken Choir:** restore a descending melody. Learn Reveal and open the other Stonewake route.
4. **Stonewake Crossing:** both wind and water voices are required. Restore its canon to learn Ward and raise the northern crossings.
5. **Lanternwood:** Discord sentinels patrol the memories. Ward silences them; completing the shrine restores the grove and its Heart crossing.
6. **Echo Observatory:** the phrase needs an answering voice. Play all four notes, then press R; the Echo repeats them and completes the puzzle. Online friends can also share one correctly ordered phrase between different players.
7. **Heart of the World:** all six earlier voices are required. Play the final five-note melody to finish the expedition. The host or solo player can then start a new seed with **Begin the next expedition**.

The two early regions and the two northern regions are parallel branches. A full connected path exists once the corresponding songs are restored; later shrines enforce their prerequisites on the host.

### Music changes gameplay

| Learned song | Keys | Effect |
| --- | --- | --- |
| Bloom | 1 · 2 · 3 | Heals travelers within 12 metres by 20 health; its introductory shrine grows the first bridges |
| Gust | 5 · 3 · 1 | Launches your traveler on an updraft |
| Reveal | 2 · 4 · 2 | Makes hidden memories visible and collectible for 15 seconds |
| Ward | 1 · 3 · 5 | Silences Discord sentinels for 8 seconds |

Abilities have a short cooldown. Visible golden memories give shared progression and heal their collector. One memory per island is hidden until Reveal. A shrine awards three shared memories and a checkpoint. Falling or losing all health returns you to a checkpoint without losing progress. Solved northern shrines remove their local sentinels.

Instrument sounds and the looping soundtrack are synthesized in code. New musical layers enter as more voices return. No downloaded songs or licensed music are needed.

## Online multiplayer

- **Capacity:** one host plus up to five clients (six travelers total).
- **Same computer:** launch a second instance, host in one, and join `127.0.0.1` with the same UDP port in the other.
- **Same LAN:** join the host computer's LAN address, using the same port.
- **Internet:** join a reachable host address. A residential host normally needs the selected **UDP** port forwarded on its router and allowed by its firewall. The default is **27840**. No router or security settings were changed for this project.
- **No account service, public matchmaking, NAT relay, or automatic host migration** is included. These are direct ENet connections; leaving the host ends its online session.

The host owns character movement, shrine progression, rewards, pickups, damage, and ability checks. Clients send bounded movement input and note requests; they do not supply player positions or roll rewards. All peers regenerate the same base world from the host's seed. State snapshots replicate players, health, checkpoints, shared unlocks, temporary Reveal/Ward effects, and late-join state. Client visuals interpolate received positions; client-side movement prediction is not implemented, so latency is more noticeable on distant Internet connections.

After completion, starting the next expedition regenerates the world on connected clients as well. The new expedition resets all checkpoints and unlocks while retaining the party.

This structure follows Godot's [high-level multiplayer](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html) and [ENet peer](https://docs.godotengine.org/en/stable/classes/class_enetmultiplayerpeer.html) APIs. Internet hosting requirements are described in the same official networking guide.

## Files and customization

| File | Responsibility |
| --- | --- |
| `rules.gd` | Region layout, connection graph, melody generation, prerequisites, spell recipes |
| `world.gd` | Seven procedural terrain meshes, original kit vegetation, bridges, shrines, treasure, sentinels |
| `session.gd` | Authoritative gameplay, ENet networking, save/load, progression |
| `player.gd` | Traveler body, generated character model, movement, interpolation |
| `audio.gd` | Synthesized instrument voices and adaptive soundtrack |
| `main.gd` / `main.tscn` | Scene composition, camera, controls, lighting |
| `hud.gd` / `map.gd` | Solo/Host/Join menu, gameplay HUD, songbook, map |
| `water.gdshader` | Animated ocean surface |
| `qa/` | Renders and validation reports |

Original Nature MegaKit glTF geometry and textures are used for trees, plants, flowers, rocks, and paving. Terrain, bridge decks, shrine runes, and traveler models are generated by the game. The original kit assets are unchanged. `project.before-adventure.txt` preserves the new project's configuration from before the adventure was installed.

Terrain placement and melodies are deterministic for a seed with the same game/Godot/assets version. The world uses spatially grouped MultiMeshes and distance culling for small vegetation. Generation is synchronous at expedition load; it is not an infinite streaming world.

## Validation

Tested with Godot 4.7.2, including D3D12 Forward Plus renders.

- End-to-end solo rules: all seven shrines, prerequisite rejection, wrong-note rejection, all four abilities, solo Echo completion, one-time treasure rewards, checkpoint/progression reset, and next expedition.
- Deterministic kit placement and actual physics collision on all eight restored bridge decks.
- Server-controlled physical movement and rejection of non-finite movement input.
- Separate local host and two client processes: shared seed, authoritative client movement, shared song completion, roster updates, and late joining into an unlocked world.
- Additional network coverage checks expedition regeneration, temporary ability state, and disconnect cleanup.
- Visual checks: title/online form, third-person scene, map, and songbook at 1280×800.

The multiplayer tests use localhost; connectivity between different external networks has not been tested. The code permits six players; the live integration test uses three.

Run `validate.gd` with Godot's `--headless --path <project> --script res://Adventure/validate.gd`. It does not modify player saves. `network_probe.gd` accepts roles `host`, `lead`, and `observer`, followed by a port, after `--`; launch all three processes to reproduce the network check. `capture.gd` generates screenshots in `Adventure/qa` and exits. These helpers are development tools, not gameplay scenes.
