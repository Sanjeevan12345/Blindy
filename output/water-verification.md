# Waterworks water verification

Measured on the available NVIDIA GeForce RTX 3050 A Laptop GPU, Godot 4.7.2 Forward+, D3D12, at 1920×1080.

## Render measurements

| Session | View | Preset | Median frame (ms) | 95th percentile frame (ms) | Median GPU (ms) |
| --- | --- | --- | ---: | ---: | ---: |
| Solo | hub | Maximum | 6.39 | 6.54 | 6.11 |
| Solo | lock | Maximum | 5.40 | 5.62 | 5.10 |
| Solo | hub | Reduced | 3.87 | 4.03 | 3.57 |
| Solo | lock | Reduced | 3.65 | 3.77 | 3.37 |
| Three windows / head | hub | Maximum | 18.84 | 19.10 | 16.82 |
| Three windows / head | lock | Maximum | 16.99 | 17.43 | 14.94 |
| Three windows / head | hub | Reduced | 10.65 | 11.34 | 9.16 |
| Three windows / head | lock | Reduced | 10.26 | 11.04 | 9.12 |

These are short static-view render samples, not whole-level FPS guarantees. VSync was disabled, the normal render loop was disabled in the benchmark only, and exactly one explicit draw presented each frame. Both views and presets were warmed before synchronized 3-second windows (0.8 seconds settling, 2.2 seconds sampling). Gameplay simulation was stopped, water normals animated, and the head HUD was hidden. All three windows rendered at 1080p throughout matching time windows. Preset differences include the existing fog/SSAO settings as well as water effects.

The hands and wheel samples confirm `water_visible: false` in both presets. Their raw measurements are in `water-performance-three-1.json` and `water-performance-three-2.json`.

## Visual comparisons

[Before — hub, high water](D:/Games/Blindy/output/water-before-hub-high.png) · [After — same view](D:/Games/Blindy/output/water-after-hub-high.png) · [Reduced — same view](D:/Games/Blindy/output/water-reduced-hub-high.png)

[Filling detail](D:/Games/Blindy/output/water-after-fill-detail.png) · [Pan left](D:/Games/Blindy/output/water-after-pan-left.png) · [Pan right](D:/Games/Blindy/output/water-after-pan-right.png)

Matching before/after hub, raft and lock views at low/high water are saved as `water-before-*.png` and `water-after-*.png`. The guarded lock platform covers most of its water surface; this pass preserves that geometry.

## Verification

- Render checks: 18 checks passed, including physical F3 input, default Maximum, private views, static-capture exclusions, synchronized time, filling particles, recovery and unchanged snapshot/save interfaces.
- Existing Waterworks progression, fourteen checkpoint reloads, backup recovery and immersion checks passed.
- Three real ENet role clients physically operated/rode the lock and basin raft, then recovered from immersion with cargo and checkpoint state preserved.
- Solo and three rendered-client benchmarks completed successfully.

## Limits

Screen-space reflections cannot include off-screen or transparent objects. Static probes approximate off-screen factory structure and exclude moving machinery. Foam and spray are visual approximations, with no fluid or new buoyancy simulation. Waves stay below the gameplay plane (up to 2.75 cm), preventing high water from drawing over coplanar safe walkways.

On this Godot/D3D12 configuration, reflection-probe runs report seven texture-RID cleanup warnings at application shutdown. An isolated probe-only rendering test reproduces the warning with a plain opaque water material; removing probes eliminates it. All recorded runs completed without shader or gameplay errors. This warning is not claimed fixed.
