# Personal starting worlds — 14 November 2026

The owner's personal Bazaar is **one empty square**, expanded later by buying
shops, stalls, training arenas, social places and similar facilities. This is
separate from the multi-district official island and the future private home.

Version 0.0.10 adds two local starting grounds:

- **Mika / island:** a roughly circular sea island, a 48 m wide empty paved square,
  a grass and palm rim with low dunes, a broad walkable beach and animated surf.
- **Ren / station:** a circular orbital deck, the same 48 m wide empty central
  square, a transparent curved glass dome, structural ribs, perimeter rails,
  stars and a shaded gas giant outside.

These are local test worlds, not granted player-owned venues. No purchases,
stock, stalls, shops, arenas or multiplayer sessions are provisioned. The only
shared game systems are the existing SDK character, motor, camera, input, pause
and ordinary process lifecycle. Official services/population are not instantiated
in personal worlds. The official Festival Park remains the default launch.

```
godot --path games/bazaar -- --world=island
godot --path games/bazaar -- --world=station
```

Only `official`, `island` and `station` are accepted. Unknown world arguments exit
with an error. The shell uses fixed desktop entries, never commands supplied by a
server directory row. Missing installed worlds retain the explanatory preview.

## Geometry and performance boundaries

All new scenery is authored procedural geometry/shaders under the project GPL;
no newly downloaded textures/models are required. The island reuses the existing
bounded grass mesh/shader with 6,500 tufts in spatial MultiMesh chunks. Terrain has
real collision and a level construction pad. Sea color/foam follow the same coast
function, with derivative filtering; no depth/refraction passes. The station uses
one glass shell, combined rib geometry and a closed perimeter collision. There
are no real-time reflection probes, volumetrics, per-pixel lights or idle NPCs.
A single directional shadow light is bounded to 65 m in both worlds.

The SDK motor and approved avatar rig are unchanged. World-specific fall height,
arrival and radial recovery are configured in the game walker; the official
world retains its previous values. Main menu audio preferences remain compatible.

## Validation

Headless physics scenarios passed for both personal worlds: arrival, nine points
across the empty pad, running, pause, fall recovery, beach support / station edge.
The official walkthrough regression also passed. Render checks inspect arrival,
shore/edge, exterior overview and catalogue covers in Compatibility/OpenGL.
The resulting catalogue images show shipped scenery rather than concept art.
Host render timings are not handheld performance acceptance. Delivery evidence
will record the actual installed versions and device checks separately.
