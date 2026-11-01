"""Build a portable gallery from retained, actual Godot captures and measurements."""
from pathlib import Path
import html
import json

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "output" / "art-pass"
FINAL = "04-final-foliage"
STAGES = [
    ("00-baseline", "0 · Baseline"),
    ("01-lighting", "1 · Lighting — preferred direction"),
    ("02-weathered-correction", "2 · Materials — weathering restored"),
    ("03-structures-corrected", "3 · Structure and environment"),
    (FINAL, "4 · Final integration"),
]
VIEWS = [
    ("level-3-hub", "Waterworks hub · low water"),
    ("level-3-water-high", "Waterworks basin · high water"),
    ("level-3-reduced", "Waterworks hub · Reduced"),
    ("level-3-pump", "Waterworks pump destination"),
    ("robot-materials", "Robot and surface detail · external inspection"),
    ("level-2-arrival", "Level 2 · arrival and bridge"),
    ("level-2-destination", "Level 2 · repair destination"),
    ("level-1-greenhouse", "Level 1 · greenhouse"),
    ("level-1-boot", "Level 1 · boot bay"),
]

def measurements():
    rows = []
    for mode, file in [("Solo", "water-performance-solo.json"),
                       ("Three windows · head", "water-performance-three-0.json")]:
        before = json.loads((OUT / "00-baseline" / file).read_text())
        after = json.loads((OUT / FINAL / file).read_text())
        for old in before:
            new = next(x for x in after if (x["view"], x["quality"]) == (old["view"], old["quality"]))
            rows.append((mode, old["view"].title(), old["quality"], old, new))
    return rows

ROWS = measurements()
table_lines = ["| Mode | View | Preset | Before frame ms | Final frame ms | Before GPU ms | Final GPU ms | Final p95 frame ms |",
               "|---|---|---|---:|---:|---:|---:|---:|"]
html_rows = []
for mode, view, quality, old, new in ROWS:
    values = [old["median_frame_ms"], new["median_frame_ms"], old["median_gpu_ms"], new["median_gpu_ms"], new["p95_frame_ms"]]
    table_lines.append("| " + " | ".join([mode, view, quality] + [f"{v:.2f}" for v in values]) + " |")
    html_rows.append("<tr>" + "".join(f"<td>{html.escape(str(v))}</td>" for v in [mode, view, quality] + [f"{v:.2f}" for v in values]) + "</tr>")

report = """# Blindy environment pass — verification

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

""" + "\n".join(table_lines) + """

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
"""
(OUT / "verification.md").write_text(report, encoding="utf-8")

cards = []
for stem, title in VIEWS:
    cards.append(f'''<section><h2>{html.escape(title)}</h2><div class="pair">
<figure><a href="00-baseline/{stem}.png"><img loading="lazy" src="00-baseline/{stem}.png" alt="Baseline {html.escape(title)}"></a><figcaption>Baseline</figcaption></figure>
<figure><a href="{FINAL}/{stem}.png"><img loading="lazy" src="{FINAL}/{stem}.png" alt="Final {html.escape(title)}"></a><figcaption>Final · weathered direction retained</figcaption></figure></div></section>''')
options = "".join(f'<option value="{path}">{html.escape(label)}</option>' for path, label in STAGES)
extras = "".join(f'<figure><a href="{FINAL}/{name}.png"><img loading="lazy" src="{FINAL}/{name}.png" alt="{label}"></a><figcaption>{label}</figcaption></figure>' for name, label in [
    ("level-3-pump-readable", "Final pump target placement"),
    ("inspection-gallery", "Inspection gallery · spotlight, panels off"),
    ("inspection-gallery-lit", "Inspection gallery · panels on")])
page = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Blindy · Environment pass</title><style>
:root{color-scheme:dark;font-family:system-ui,sans-serif;background:#101d22;color:#e6ecea}body{max-width:1500px;margin:auto;padding:28px}h1{color:#efba68}h2{font-size:1.2rem}p{line-height:1.6;max-width:100ch}a{color:#9ed9d7}section{margin:36px 0;border-top:1px solid #345057;padding-top:14px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:16px}figure{margin:0}img{width:100%;display:block;border-radius:7px}figcaption{padding:8px 0;color:#baccc8}select{font:inherit;background:#21383e;color:white;padding:9px;border:1px solid #6c9698;border-radius:5px;margin-bottom:12px}table{border-collapse:collapse;font-variant-numeric:tabular-nums;font-size:.9rem}th,td{padding:9px;border-bottom:1px solid #345057;text-align:right}th:first-child,td:first-child{text-align:left}.scroll{overflow:auto}.extras{display:grid;grid-template-columns:repeat(3,1fr);gap:15px}@media(max-width:800px){.pair,.extras{grid-template-columns:1fr}body{padding:16px}}
</style><h1>Blindy · Vibrant environment pass</h1>
<p>Actual Godot renders, 1 November 2026. The darker weathered metal and warm lighting you preferred are the final direction. Click any picture for its full 1080p capture. Gameplay routes, collision geometry and progress remain intact.</p>
<p><a href="verification.md">Verification, performance and limitations</a> · <a href="04-final-foliage/cameras.json">Camera records</a></p>
<section><h2>Accepted stages · same Waterworks hub camera</h2><select id="stage" aria-label="Art stage">OPTIONS</select><a id="stageLink" href="00-baseline/level-3-hub.png"><img id="stageImage" src="00-baseline/level-3-hub.png" alt="Selected art stage hub render"></a><p>The cleaner Stage 2 experiment was superseded after your feedback. All earlier captures remain on disk.</p></section>
CARDS
<section><h2>Final encounter readability</h2><div class="extras">EXTRAS</div></section>
<section><h2>Measured rendering cost · milliseconds</h2><p>RTX 3050 A Laptop GPU, 1080p, VSync off, matched warmed static views. Medians except final p95. Three-window values describe the head client while all three clients render. This is not a whole-level frame-rate guarantee.</p><div class="scroll"><table><thead><tr><th>Mode</th><th>View</th><th>Preset</th><th>Before frame</th><th>Final frame</th><th>Before GPU</th><th>Final GPU</th><th>Final p95</th></tr></thead><tbody>ROWS</tbody></table></div><p>Maximum remains the default. F3 Reduced keeps the palette with cheaper water, atmosphere and shadows. Level checks, graphical solo controls, three-client water traversal and campaign handoff passed. Human playtesting remains necessary.</p></section>
<script>document.getElementById('stage').addEventListener('change',e=>{const p=e.target.value+'/level-3-hub.png';document.getElementById('stageImage').src=p;document.getElementById('stageLink').href=p;});</script></html>'''
page = page.replace("OPTIONS", options).replace("CARDS", "\n".join(cards)).replace("EXTRAS", extras).replace("ROWS", "".join(html_rows))
(OUT / "index.html").write_text(page, encoding="utf-8")
for stage, _ in STAGES:
    for stem, _ in VIEWS:
        assert (OUT / stage / f"{stem}.png").is_file(), (stage, stem)
print("Gallery and verification report written; all stage image paths exist.")
