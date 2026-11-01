# Blindy — A Little Further

Three maintenance AIs share one robot to rescue a sapling from an abandoned factory. Six handcrafted campaign levels are planned. Level 1, **Assembly Required**, now has a **164.6-metre required route**, eight ordered teamwork encounters and a factory environment art pass. Level 2, **Handle With Care**, is playable with branching routes, hanging bridges, a freight lift and manual cargo balance. Level 3, **Waterworks**, adds a measured **579.4-metre centreline route**, two pump wings in either order and fourteen checkpoint locations.

## Play

Open `project.godot` in **Godot 4.7** and press **F5**. Desktop rendering uses **Forward+** and targets a dedicated GPU. The lobby offers hosting, joining by IP, and solo testing.

- Host is **head**, second player is **hands/body**, third is **wheel**. The host starts after all three connect.
- Join using the host's LAN IP; use `127.0.0.1` for multiple instances on one computer.
- Networking uses **UDP 28760**, direct IP/LAN. Internet play requires suitable host firewall/router configuration; matchmaking, relay, NAT traversal and integrated voice chat are not included. Use external voice chat.
- Client disconnection pauses an unfinished session. A replacement fills the vacant role and the host resumes. Host migration is not implemented. Completed sessions retain their ending when clients leave.

| Role | Controls | View |
| --- | --- | --- |
| Head | Mouse look | First-person environment, objective and docking markers |
| Hands/body | Space jump, hold E interact, Shift brace; Level 2 J/L counterbalance | Private robot schematic, jump readiness, cargo and interaction prompt |
| Wheel | W/S or Up/Down: throttle/reverse; A/D or Left/Right: steer; release to brake | Private speed, tilt and proximity dashboard |

Solo combines the three roles; **R** restores the checkpoint in solo. The robot now steers rather than strafing: Right/D turns clockwise and Left/A anticlockwise, even in reverse. W/Up drives along its current heading; S/Down reverses. Head look stays relative to the chassis, and the camera follows chassis turns while keeping its horizon level. **Esc** releases the mouse; click captures it. **F3** toggles High/Reduced graphics effects; Reduced disables volumetric fog, SSAO and fixture shadows while retaining Forward+.

## Expanded Level 1

| Area | Required encounters |
| --- | --- |
| Boot Bay | Look around, drive to the marked console, stop and hold E to release the cradle |
| Sorting Aisle | Weave around scrap stacks, operate the sorting gate, reach the bridge console |
| Broken Conveyor | Extend the service bridge, practise jumping, cross a gap, open the shutter, cross the second gap |
| Last Greenhouse | Hold E to release the seal, navigate planting beds, retrieve the sapling |
| Service Lift | Carry the sapling along the return catwalk, restore lift power, follow the shallow ramp and activate departure |

The eight stable encounter IDs are `release`, `sorting`, `bridge`, `shutter`, `seal`, `pickup`, `power`, `departure`. Docking interactions require grounded positioning within a 1.4-metre radius, linear speed below 0.18 m/s and angular speed below 0.15 rad/s. Releasing E or leaving the circle cancels the hold. The seal and power console require 1.5 seconds; other controls require 0.7 seconds. Bridge extension takes two seconds and the gate stays shut until its collision deck is ready.

Checkpoints follow cradle release, precede both gaps, follow sapling pickup and follow lift-power activation. Recovery restores objective, cargo and a safe chassis heading together; checkpoints are in-session only. The host owns rigid-body physics, objective state, bridge extension, cargo and recovery. Clients interpolate position and orientation without simulating a competing body. Snapshots include linear/angular velocity, suspension offsets and recovery/fade state. Clients send role-restricted commands; stale drive/interaction inputs expire after 0.5 seconds.

Cargo is automatically stabilized throughout Level 1. There are no enemies, mandatory timer, cargo damage, limited lives or medals. Manual balance and water loss remain Level 2 mechanics. The intended first-time-play duration still requires human playtesting; the measured route length does not prove a 10–15 minute playtime.

## Level 2 — Handle With Care

Choose **Solo test — Level 2** in the lobby, or select Level 2 before hosting a three-player session. After Level 1 finishes, the host can press **N** to continue with the same connected players, roles and sapling. Solo also supports N. Direct launch: `Godot --path . -- --level=2 --solo`.

The arrival dock introduces **J/L counterbalance** for the hands player; **Shift** braces and slows travel. The route branches into a short, 2.4-metre-wide hanging bridge and a longer service walkway, then rejoins at a powered turntable. A freight lift descends six metres to a lower maintenance deck. Refill the sapling's water, climb back to the upper deck, cross a second hanging bridge and repair the stabilizer at the green terminal.

Both bridges have continuous collision decks and bounded 0.9-degree sway, with visible planks and suspension cables. They do not simulate individual loose planks or full cable physics. Fans are scenery and remain offline. The level has no enemies or mandatory timer. Water spills when cargo leans too far; depletion, falls and sustained tipping return the team to its checkpoint with cargo intact. Checkpoints restore water with a minimum reserve. Repair completes this chapter; Level 3 is now playable through the lobby or N after Level 2.

Only the head sees the environment. Hands receives the balance/water instruments; wheel retains mechanical telemetry. Cinematic turntable/lift movement, cargo state, gates, recovery and completion are host authoritative. Departure between levels waits for connected clients to load before gameplay resumes.

The amber lights, teal shaft, worn steel, background catwalks and machinery are a procedural interpretation of `reference/level-two-concept.png`. Current artwork is simpler than the illustration and is not pixel-identical. Actual engine captures are `output/level-two-overview.png`, `output/level-two-route-choice.png`, `output/level-two-freight.png` and `output/level-two-final-bridge.png`. These external inspection cameras are not available to players.

## Level 3 — Waterworks

Choose **Solo test — Level 3**, or select Level 3 before hosting. Press **N** after finishing Level 2 to continue with the same connected team. Direct launch: `Godot --path . -- --level=3 --solo`. **New Level 3 — replaces saved run** selects a fresh run; **Resume saved Level 3** selects the saved checkpoint, then use Solo or Host. Resume also supports `--level=3 --solo --resume`.

The route measures **579.4 metres along its centreline**, including both wings and return shortcuts, for either pump order. Arrival leads to a central training valve and hub. Wing A requires towing a battery around two corners, docking it, crossing a 14-metre hanging bridge and jumping a 1.5-metre gap before Pump A. Wing B combines discharge jets, a lateral shuttle, a three-metre water lock and Pump B, with a spotlight-guided inspection gallery on the return. Both pumps open the basin ramp. Calibrate the raft valve, rise six metres, cross a 10-metre bridge and activate the surface elevator. Checkpoints occupy fourteen distinct safe locations and can be revisited with updated puzzle progress.

**Valve controls:** stop inside the cyan square, align with its floor arrow, and hold **E for 0.8 seconds** to engage. Release E, then use **J to decrease / L to increase pressure**. Head reads the target on the physical gauge; hands sees current pressure and the three-second continuous hold. A fresh E press disengages. Overshooting resets hold progress. Movement, turning or leaving alignment cancels calibration. Valve targets are fixed; no guessing or randomized combination is required.

**Battery trolley:** stop by the rear coupling and hold E to attach/detach. Coupling limits forward/reverse speed to 2 m/s and disables jumps. The trolley uses a simplified upright rigid body and yaw-articulated pin hitch; it is not a detailed suspension simulation. Detached cargo parks. Docking at the socket is assisted and permanent. Before docking, checkpoint recovery returns the trolley to its starting bay. Trolley routes remain separate from narrow bridges.

**Machinery:** jets cycle 3 seconds safe, 2 seconds amber warning, 2 seconds active; active jets apply capped sideways force. The 4×4 m shuttle travels six metres at 1 m/s and pauses three seconds at each end. The guarded lock raises its platform three metres in eight seconds. The basin raises its raft six metres in fourteen seconds. Tire forces account for supporting-platform velocity. Bridges have continuous collision decks, cable rails, 2.2 m width and bounded 1.2° sway, not individual plank physics or fluid simulation.

The inspection gallery has an automatic head-directed spotlight, reflective arrows, two lighting panels and guarded edges. Only head sees the room and pressure targets; hands and wheel retain private instruments. The repaired stabilizer stays online, Shift braces the chassis, and Level 3 has no passive thirst, cargo damage, enemies or overall timer. The 40–50 minute first-time target requires human playtesting.

**Recovery and saving:** immersion, falls and sustained tipping restore safe robot heading, cargo and checkpoint puzzle state. Interrupted lock/fill travel resets to its low boarding state. Checkpoints autosave one host/solo slot to Godot's `user://waterworks.json`, with atomic replacement and a previous valid `.bak` backup. Saves reconstruct stationary checkpoint states rather than active physics bodies. Reopening requires players to reconnect and take roles again. Unsupported or unreadable saves are not treated as valid resumes. Disk failure leaves the in-session checkpoint active and displays a message. There is no host migration or cross-machine cloud save.

Actual engine views are `output/level-three-overview.png`, `level-three-hub.png`, `level-three-filtration.png`, `level-three-pressure.png` and `level-three-inspection.png`. The external capture cameras are not player features. `reference/level-three-expanded-concept.png` is the planning illustration: the modular engine artwork is simpler and is not an exact illustration reproduction.

## Water appearance and graphics

Level 3 now uses calm, murky blue-green water with world-scale layered ripples, depth absorption, guarded screen-space refraction, grazing-angle reflections, broken contact foam, a restrained raft wake and localized filling spray. Wet bands track the basin and lock waterlines. All detail is procedural; extra texture downloads are not required.

**Maximum** is the default: a 64-step / five-refinement screen-space reflection trace reaches up to 40 metres, with two box-projected static probes providing off-screen fallback. Probe captures exclude water, robot, moving platforms, gates and changing station markers. Visual displacement stays below 4 cm and below coplanar safe walkways. **F3 Reduced** removes reflection tracing, vertex waves and wake/spray particles while retaining probe reflections, refraction, absorption and simpler edge foam. Hands and wheel do not render water or probes.

This is a Level 3 rendering pass. Machinery heights, movement timing, immersion thresholds, saved checkpoints and network snapshot fields remain unchanged. Transparent glass/spray and off-screen moving objects cannot appear in screen-space reflections; the probes approximate static surroundings. This is not fluid simulation.

Before/after 1080p engine captures are `output/water-before-*.png` and `output/water-after-*.png`, covering the same hub, raft and lock cameras at low/high water. `output/water-verification.md` contains measured solo/three-window Maximum-versus-Reduced frame/GPU times, camera-pan captures and known limitations. Raw samples are `output/water-performance-*.json`. Benchmarks use warmed, synchronized static views with VSync disabled and one presented draw per frame; they do not establish whole-level frame rates. Reflection-probe runs currently emit a texture cleanup warning when the application exits; the verification report records the isolated reproduction.

Water checks and capture commands:

```
Godot --path . --script res://tests/water_render_checks.gd -- --no-save
Godot --path . --script res://tests/capture_water.gd -- --no-save
Godot --path . --script res://tests/water_performance.gd -- --solo --no-save
python tests/run_water_clients.py --godot "PATH_TO_GODOT_CONSOLE_EXE"
python tests/run_water_clients.py --godot "PATH_TO_GODOT_CONSOLE_EXE" --benchmark --port 28844
```

The three-client water check physically traverses the lock and raft, then verifies immersion recovery. The benchmark opens three real 1080p windows; run it separately from solo profiling and other GPU workloads. Both use isolated test user data and disable production-slot saves.

## Steering physics

The controller in `scripts/robot.gd` is a single `RigidBody3D` with simplified tire, torso and head collision shapes. Ground-contact tire forces provide acceleration, braking and limited lateral grip. The visible wheel rolls according to signed forward travel; it is not an independently hinged physical wheel. Limited gyroscopic balancing assists the chassis without locking its rotation.

Initial exposed tuning: **80 kg**, **0.61 m tire radius**, **9.81 m/s² gravity**, **6 m/s forward**, **3 m/s reverse**, **3.5 m/s² motor acceleration**, **4.5 m/s² braking**, and **0.95 tire grip coefficient**. Steering rate blends from 100°/s at rest to 45°/s at maximum speed. Actual acceleration and turning vary with contact, slopes, slips and collisions. Opposite throttle brakes before reversing; allow approximately four metres to stop from full speed on flat ground.

Drive/steer forces only apply with tire contact. Jumps target 1.4 m height, retain takeoff momentum and accept 100 ms input buffering plus 80 ms coyote time. Airborne input cannot drive, brake or yaw the chassis. Moderate disturbances can stabilize; staying beyond 55° tilt for one second starts a 0.4-second fade and checkpoint recovery. Falls use the same recovery. Reset clears linear/angular velocity, jump state and suspension.

The hands player's **Shift brace** lowers the effective center of mass from 1.05 m to 0.85 m, increases gyro support and limits speed to 2.5 m/s. Cargo damage remains disabled in Level 1. Gap checkpoints now leave sufficient acceleration room after recovery. The prototype uses the same steering controller; **U/O** orbit its external inspection camera.

The balancing torque uses stiffness 1500, damping 500 and an unbraced torque limit of 700 Nm. These are game handling parameters, not a validated real-world unicycle model. Human playtesting is still needed to judge comfort and difficulty.

## Environment art

The environment uses a reusable generated kit: multi-level catwalks, wall panels, support beams, roller conveyors, maintenance claws, grilles, service cables, giant pipe elbows, planters, amber fixtures and an exit frame. Decorative geometry is batched with MultiMesh; gameplay collisions remain separate and deliberate.

`materials/factory_surface.gdshader` supplies world-scale plate seams, rust, dirt, scratches, metalness, roughness and fine normal detail without downloaded assets. Forward+ adds amber local lights, cool window shafts, teal volumetric atmosphere, glow and ambient occlusion. High/Reduced presets are available with F3. This is an in-engine interpretation of the concept image, not an exact reproduction or a purchased industrial asset pack.

Actual 1080p renders are under `output/factory-*.png`; `factory-overview.png` is an external art inspection view, not a player's camera. `output/factory-performance.json` records short frame-time samples for that view on the available RTX 3050 laptop. Those samples are not a whole-level benchmark and may be limited by display synchronization. Narrative messages are subtitled; sound cues are synthesized placeholders, not recorded dialogue.

### Current cinematic pass — all three levels

Open `output/art-pass/index.html` for matching before/final pictures and the accepted stage gallery. `output/art-pass/verification.md` records checks, current 1080p solo/three-window measurements and remaining rendering limitations. Earlier captures are preserved separately. The darker weathered finish and warm Stage 1 lighting were retained after visual feedback; the cleaner material experiment is not the final look.

`scripts/art_profile.gd` supplies shared fixed-exposure lighting profiles. `scripts/cinematic_kit.gd` adds decorative platform supports, framed machinery, connected pipes, wall bays and planting without gameplay collisions. Repeated geometry uses approximately 24-metre spatial batches. Rotated rail/pipe scaling is corrected. `materials/textures/` contains locally generated 1024-pixel seamless maps and mipmapped resources; the surface shader filters fine detail while preserving broad chipped/rusted weathering. Maximum uses triplanar mapping where needed and explicitly tagged fixture shadows. **Maximum remains the default; F3 Reduced keeps the palette with cheaper effects.**

The added artwork raises measured GPU/frame times. At the matched hub view on the RTX 3050 A laptop, median frame time changed from 6.39 to 9.79 ms in solo Maximum, and 18.84 to 25.48 ms with three rendered windows. Reduced measured 4.46 ms solo and 13.32 ms with three windows. These are short static-view samples, not whole-level frame-rate guarantees. The current report supersedes the older water-only performance numbers.

Capture the current code into a new folder, then rebuild the gallery:

```
Godot --path . --script res://tests/capture_art_pass.gd -- --stage=YOUR_CAPTURE_FOLDER --no-save
python tests/build_art_gallery.py
```

The nine capture viewpoints use fixed filmic exposure and include all levels, low/high basin water, Reduced and an external robot material view. External inspection cameras remain unavailable during normal play. Historical stages are retained screenshots rather than reconstructed by this command.

## Verification

Substitute your Godot console executable for `Godot`:

```
Godot --headless --path . --script res://tests/steering_physics.gd
Godot --headless --path . --script res://tests/level_one_checks.gd
Godot --headless --path . --script res://tests/level_two_checks.gd
Godot --headless --path . --script res://tests/level_three_checks.gd -- --no-save
Godot --path . --script res://tests/waterworks_solo_input.gd -- --no-save
Godot --path . --script res://tests/campaign_solo.gd
Godot --headless --path . --script res://tests/smoke.gd
Godot --path . --script res://tests/solo_input.gd
python tests/run_multiplayer.py --godot "PATH_TO_GODOT_CONSOLE_EXE"
python tests/run_multiplayer.py --godot "PATH_TO_GODOT_CONSOLE_EXE" --level 2 --route short
python tests/run_multiplayer.py --godot "PATH_TO_GODOT_CONSOLE_EXE" --transition
python tests/run_multiplayer.py --godot "PATH_TO_GODOT_CONSOLE_EXE" --level 3 --order ab
python tests/run_multiplayer.py --godot "PATH_TO_GODOT_CONSOLE_EXE" --level 3 --order ba
python tests/run_multiplayer.py --godot "PATH_TO_GODOT_CONSOLE_EXE" --level 3 --transition
Godot --path . --script res://tests/capture_level_three.gd -- --no-save
Godot --path . --script res://tests/capture_level_two.gd
Godot --path . --script res://tests/capture_factory.gd
```

- Expanded progression checks validate route length, all eight encounters, motion/distance guards, hold cancellation, bridge interlock, both gap checkpoints, cargo, lift requirements, role isolation and graphics presets.
- Steering physics checks measure heading-based drive, no strafing, reverse steering, acceleration/braking, grip, bracing, airborne momentum, jump buffering/coyote time, tipping, reset and 30/60/120 Hz consistency.
- The retained prototype has ten movement/cargo checks with momentum-aware braking distances.
- Solo input checks use a graphical window to verify actual mouse capture, GUI focus release, Escape/click recapture, driving holding E at the first lever, arrow-key steering and chassis-relative camera following.
- The integration runner uses three actual Godot processes over localhost UDP, follows route waypoints, jumps the obstacles/gaps, deliberately falls before and after pickup, tips the chassis with cargo after lift-power activation, and verifies synchronized completion. Use `--graphical --boot-only` for a short rendered three-window session, or `--finish-only` for reliable completion/disconnect regression. Logs: `.godot/multiplayer-check/PORT/`. Use `--port NUMBER` to select a free test port. Localhost UDP access is required. Client-to-client relaying is disabled because this architecture routes all commands through the host.
- The capture script creates five first-person area renders and an external robot/environment view, then samples High/Reduced performance at 1080p.

Level 2 verification includes a complete three-client short-route traversal with lower-deck fall recovery and synchronized repair, a solo service-route traversal, three-client campaign handoff, and graphical solo cargo/input checks. These are automated runs; first-time human pacing and bridge difficulty still need playtesting. Use `--level 2 --route service` to run the alternate route with three clients.

Waterworks tests cover both pump orders, fourteen disk checkpoint reloads, corrupt-primary backup recovery, independent-process save/resume, role privacy, real graphical E/J/L input and Level 2 handoff. Add `--hz=30` or `--hz=120` to the Level 3 checks for alternate physics rates. Network tests use three real role-restricted clients and deliberately fall after Pump A. They require localhost UDP access. `--speed 2` accelerates the network test while retaining a 60 Hz simulated physics step; default speed is normal. Test runners disable production-slot saves. A test-only task channel emulates the wheel player announcing the next task; driving, jumping, pressure and interaction commands still come from their assigned clients. Add `--resume-check` for a newly connected team restoring a checkpoint, or `--resume-check --saved-complete --graphical` for the completed-save three-window check.

Launch flags after `--`: `--level=2`, `--level=3`, `--resume`, `--host`, `--join=IP`, `--port=NUMBER`, `--solo`, `--autostart` (host starts at three players).

## Structure and retained work

- `scripts/level_one_layout.gd`: named encounters, docks, gaps and route waypoints.
- `scripts/factory_art.gd`: batched reusable environment kit, lighting and quality presets.
- `scripts/level_one.gd`: authoritative progression, network session, role input and UI.
- `scenes/robot_visual.tscn`: reusable detailed procedural robot. Inspect with `scenes/robot_showcase.tscn` and F6; arrows orbit/zoom, F2 returns to the lobby.
- `scenes/prototype.tscn`: retained one-keyboard cargo balance prototype.

## Next milestones

Playtest Level 1 communication and pacing, refine the art against the reference, add production audio and accessibility/settings, then build The Sleeping City, Return to Safety and A Little Further. Playtest Level 2 balance difficulty and route choices, and Level 3 pacing, pressure communication and machinery difficulty with three people.
