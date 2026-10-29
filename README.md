# Blindy — A Little Further

Three maintenance AIs share one robot to rescue a sapling from an abandoned factory. Six handcrafted campaign levels are planned. Level 1, **Assembly Required**, now has a **164.6-metre required route**, eight ordered teamwork encounters and a factory environment art pass.

## Play

Open `project.godot` in **Godot 4.7** and press **F5**. Desktop rendering uses **Forward+** and targets a dedicated GPU. The lobby offers hosting, joining by IP, and solo testing.

- Host is **head**, second player is **hands/body**, third is **wheel**. The host starts after all three connect.
- Join using the host's LAN IP; use `127.0.0.1` for multiple instances on one computer.
- Networking uses **UDP 28760**, direct IP/LAN. Internet play requires suitable host firewall/router configuration; matchmaking, relay, NAT traversal and integrated voice chat are not included. Use external voice chat.
- Client disconnection pauses an unfinished session. A replacement fills the vacant role and the host resumes. Host migration is not implemented. Completed sessions retain their ending when clients leave.

| Role | Controls | View |
| --- | --- | --- |
| Head | Mouse look | First-person environment, objective and docking markers |
| Hands/body | Space jump, hold E interact, Shift brace | Private robot schematic, jump readiness, cargo and interaction prompt |
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

## Verification

Substitute your Godot console executable for `Godot`:

```
Godot --headless --path . --script res://tests/steering_physics.gd
Godot --headless --path . --script res://tests/level_one_checks.gd
Godot --headless --path . --script res://tests/smoke.gd
Godot --path . --script res://tests/solo_input.gd
python tests/run_multiplayer.py --godot "PATH_TO_GODOT_CONSOLE_EXE"
Godot --path . --script res://tests/capture_factory.gd
```

- Expanded progression checks validate route length, all eight encounters, motion/distance guards, hold cancellation, bridge interlock, both gap checkpoints, cargo, lift requirements, role isolation and graphics presets.
- Steering physics checks measure heading-based drive, no strafing, reverse steering, acceleration/braking, grip, bracing, airborne momentum, jump buffering/coyote time, tipping, reset and 30/60/120 Hz consistency.
- The retained prototype has ten movement/cargo checks with momentum-aware braking distances.
- Solo input checks use a graphical window to verify actual mouse capture, GUI focus release, Escape/click recapture, driving holding E at the first lever, arrow-key steering and chassis-relative camera following.
- The integration runner uses three actual Godot processes over localhost UDP, follows route waypoints, jumps the obstacles/gaps, deliberately falls before and after pickup, tips the chassis with cargo after lift-power activation, and verifies synchronized completion. Use `--graphical --boot-only` for a short rendered three-window session, or `--finish-only` for reliable completion/disconnect regression. Logs: `.godot/multiplayer-check/PORT/`. Use `--port NUMBER` to select a free test port. Localhost UDP access is required. Client-to-client relaying is disabled because this architecture routes all commands through the host.
- The capture script creates five first-person area renders and an external robot/environment view, then samples High/Reduced performance at 1080p.

Launch flags after `--`: `--host`, `--join=IP`, `--port=NUMBER`, `--solo`, `--autostart` (host starts at three players).

## Structure and retained work

- `scripts/level_one_layout.gd`: named encounters, docks, gaps and route waypoints.
- `scripts/factory_art.gd`: batched reusable environment kit, lighting and quality presets.
- `scripts/level_one.gd`: authoritative progression, network session, role input and UI.
- `scenes/robot_visual.tscn`: reusable detailed procedural robot. Inspect with `scenes/robot_showcase.tscn` and F6; arrows orbit/zoom, F2 returns to the lobby.
- `scenes/prototype.tscn`: retained one-keyboard cargo balance prototype.

## Next milestones

Playtest Level 1 communication and pacing, refine the art against the reference, add production audio and accessibility/settings, then build Handle With Care, Waterworks, The Sleeping City, Return to Safety and A Little Further.
