# Bazaar 0.0.19 on handheld

[Matched views](before-after.jpg) show the fountain, shop district, beach and
observatory in 0.0.18 and 0.0.19. [Arrival](festival-arrival.jpg) shows the
ordinary gameplay camera and HUD on Odin 2. The [counter detail](market-detail.jpg)
is a separate 800 × 450 service-menu check with fixture inventory.

The [capture script](../../../games/bazaar/tests/art_review.gd) used the same
camera transforms on both builds. Godot reported 1920 × 1080 on the physical
displays. Each draw-call count describes a single captured frame.

| View | Device | 0.0.18 | 0.0.19 |
| --- | --- | ---: | ---: |
| Fountain | Odin 2 | 905 | 857 |
| Shops | Odin 2 | 285 | 282 |
| Counter | Odin 2 | 300 | 294 |
| Island | Flip 2 | 67 | 60 |
| Shore | Flip 2 | 24 | 22 |
| Station | Odin 2 | 62 | 63 |

Both installations point to the ARM64 export with SHA-256
`a1b1bf0db4c65baa7c5ce32630b8b112582352f6cec463ba4f9b7e239b533fc2`.
An abrupt headless frame-limit exit reported an outstanding resource on both
devices. Each installed pack also started all three worlds under the pinned
Godot runtime and exited via the game's normal leave handler without diagnostics.
