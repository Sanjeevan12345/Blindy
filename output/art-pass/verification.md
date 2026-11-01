# Blindy environment pass — verification

Completed 1 November 2026. All displayed pictures are 1920×1080 Godot renders, not generated illustrations. Open [the comparison gallery](index.html).

## Chosen direction

The darker weathered steel and warm lighting in Stage 1 were retained after the user preferred that image over the cleaner material experiment. The original chipped/rusted character remains; filtered fine detail and baked material maps supplement it. The brighter Stage 2 experiment is retained on disk but is not the final look.

Shared profiles now give the three levels amber working areas, cool depth and fixed filmic exposure. Decorative additions include platform fascias and supports, connected railings, framed pump/door assemblies, collared pipes, wall bays and selective planting. Rotated mesh scaling was corrected so rails, cables and pipe segments connect correctly. Pointed plant leaves replace rectangular decoration in the new clusters and greenhouse.

The texture library contains eight locally generated 1024-pixel seamless maps and mipmapped ImageTexture resources in `materials/textures/`. Maximum uses triplanar mapping where needed; Reduced uses dominant-axis mapping. Repeated decorations are split into roughly 24-metre spatial batches. Selected lights carry explicit shadow importance tags. Maximum remains the default; F3 switches to Reduced while keeping the same palette.

New artwork creates no gameplay collisions. Routes, machinery timings, robot design, network messages and save format are preserved. Static water reflection registration includes the finished scenery. Pump target labels and gallery direction signs were adjusted for readability.

## Retained capture sequence

- `00-baseline/`: original matching cameras and baseline benchmark copies.
- `01-lighting/`: warm/cool lighting; the user's preferred reference.
- `02-weathered-correction/`: retained original weathering, added filtered texture detail.
- `03-structures-corrected/`: structural kit with corrected local-axis scaling.
- `04-final-foliage/`: final atmosphere, connected pipes, pointed foliage and integration.

Each stage retains `cameras.json`, fixed exposure 1.0 and the same nine camera views. The hub is captured at low water, with a separate high-water basin view and a matching Reduced hub. The final pump label correction has an additional `level-3-pump-readable.png`; the main matched pump image is retained unchanged for comparison. Inspection-gallery dark/lit views are additional final captures. External robot inspection views are capture tools, unavailable during normal play.

Earlier experimental/superseded folders remain on disk: `02-materials`, `02-materials-refined`, `03-structures`, `04-final`, `04-final-verified`. They are not the final result. The original `04-final` capture attempt encountered a fog-property error; that was fixed before verified captures and checks.

## Measured performance

Godot 4.7.2, Forward+, D3D12, NVIDIA GeForce RTX 3050 A Laptop GPU, 1920×1080. VSync disabled. Matching static hub/lock cameras, paused gameplay, animated water, warmed quality modes and one explicit presented draw per frame. Three-window results use three real, rendered clients and synchronized measurement phases (0.8 s settling, 2.2 s sampling). Values below are medians except the last column. The whole preset changes lighting, atmosphere, materials and water together.

| Mode | View | Preset | Before frame ms | Final frame ms | Before GPU ms | Final GPU ms | Final p95 frame ms |
|---|---|---|---:|---:|---:|---:|---:|
| Solo | Hub | Maximum | 6.39 | 9.79 | 6.11 | 9.46 | 10.48 |
| Solo | Lock | Maximum | 5.40 | 6.79 | 5.10 | 6.48 | 7.05 |
| Solo | Hub | Reduced | 3.87 | 4.46 | 3.57 | 4.11 | 5.01 |
| Solo | Lock | Reduced | 3.65 | 3.87 | 3.37 | 3.52 | 4.38 |
| Three windows · head | Hub | Maximum | 18.84 | 25.48 | 16.82 | 22.99 | 26.59 |
| Three windows · head | Lock | Maximum | 16.99 | 20.37 | 14.94 | 18.36 | 20.91 |
| Three windows · head | Hub | Reduced | 10.65 | 13.32 | 9.16 | 11.18 | 14.04 |
| Three windows · head | Lock | Reduced | 10.26 | 11.39 | 9.12 | 9.47 | 12.91 |

The extra environment detail has a real rendering cost: the Maximum hub frame median rose from 6.39 to 9.79 ms solo and 18.84 to 25.48 ms with three windows. Reduced is useful for one-laptop multiplayer testing. These short, static-view measurements do not establish whole-level frame rates or performance on other computers.

Raw before/after measurements are preserved in the baseline and final folders as `water-performance-solo.json` and `water-performance-three-0.json`. The latest wheel/hands samples are also in `output/water-performance-three-1.json` and `three-2.json`. The earlier `output/water-verification.md` describes the preceding water-only pass; this report supersedes its performance numbers for the current artwork.

## Checks completed for this pass

- Level 1, Level 2 and Level 3 progression/checkpoint checks: zero failures. Waterworks checks exercise branching progression and save/backup recovery.
- Graphical solo input: mouse capture/look, E lever interaction, arrow steering and camera horizon checks passed.
- Water rendering: quality switching, private role views, visual height/state invariants passed.
- Three connected role clients: water-lock boarding/travel, raft ascent and immersion checkpoint recovery passed.
- Three-client Level 2→3 campaign handoff: roles, cargo and synchronized transition passed.
- Final engine captures reviewed for rail/pipe connections, foliage, signs, high/low water, Reduced palette and inspection-gallery darkness. Spotlight/panel lighting remains part of that encounter.
- No whitespace errors from `git diff --check`.

Logs: `.godot/art-level_one_checks.log`, `art-level_two_checks.log`, `art-level_three_checks.log`, `art-water_render_checks.log`, `art-native-input.log`, `art-three-client-traversal.log`, `art-campaign-transition.log` and `art-gallery-capture.log`.

## Remaining limits

This is procedural modular game artwork; some large surfaces and machines remain simpler than the concept illustration. Human visual review and first-time three-player pacing still need playtesting. Screen-space reflections cannot show transparent objects or off-screen moving machinery. Static probes approximate their surroundings. Probe-enabled runs retain the previously isolated seven-texture cleanup warning on application exit; it has not been represented as fixed. Maximum's additional decoration, fog and shadows increase GPU time, especially when rendering three clients on one laptop.

## Reproduce

From the project folder, substitute the installed Godot console executable for `Godot`. Use isolated test user data rather than production saves.

```
Godot --path . --script res://tests/capture_art_pass.gd -- --stage=YOUR_CAPTURE_FOLDER --no-save
Godot --path . --script res://tests/capture_art_gallery.gd -- --no-save
Godot --path . --script res://tests/water_performance.gd -- --solo --no-save
python tests/run_water_clients.py --godot "PATH_TO_GODOT_CONSOLE_EXE" --benchmark --port 28852
python tests/build_art_gallery.py
```

The capture script records the current code, not historical revisions. Existing retained stage images provide the before views. Rebuilding textures is optional: `Godot --headless --path . --script res://tests/bake_art_textures.gd`.
