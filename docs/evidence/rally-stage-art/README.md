# Micro Rally stage art preview

[Matched screenshots](before-after.jpg) show three routes at fixed checkpoints,
with the same camera, time, weather and competitors in each pair. The OpenGL
frames were captured at 900 × 506. The Linux export was also run in Vulkan
Mobile, and both Windows exports started headless under Wine.

The weather regression passed all twelve presets. Geometry, road projection
and vehicle support passed on Redstone Quarry and Pinecrest Pass. The spatial
batching test needs a graphical renderer to read the MultiMesh transforms.
It passed on OpenGL.

The existing accelerated cup simulations finish with 5 of 16 cars in the
quarry and 4 of 16 on the pass. The suite expects at least 14 on each. Repeating
both simulations on the unmodified 497bd2b branch produced byte-identical
reports, including finish times, progress, recoveries and saved stage counts.
