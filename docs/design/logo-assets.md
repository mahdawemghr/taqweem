# Logo assets (assets/logos/)

Transparent RGBA PNGs cut from the user's AI-generated mock-ups in `templates/`.
Only the decorative title / medallion / emblem artwork was taken; the Arabic body
text in those images is garbled and is **not** used anywhere.

Regenerate (pure Pillow, ~9 s): `python3 -I tool/extract_logos.py`
(add `--sheet /path/sheet.png` for a QA contact sheet: original background,
contrasting background, checkerboard). All boxes and thresholds below are
constants in `tool/extract_logos.py`. Sanity test: `test/assets/logo_assets_test.dart`.

## Assets

| File | Size (px) | Source | Region (orig px) | What it is |
|---|---|---|---|---|
| `title_white.png` | 883x313 | `..._711gqy...jpeg` (navy) | box (270,120)-(1128,380) | White calligraphic «تقويم أهل البيت» with its gold diacritic flourishes (kept in; they are part of the composition) |
| `finial_gold.png` | 203x284 | `..._711gqy...jpeg` | box (1136,95)-(1340,375) | Gold dome/finial outline with crescent, small white inner dome; interior is transparent |
| `title_gold.png` | 601x236 | `..._sg3d2y...jpeg` (dark navy) | box (610,95)-(1186,320) | Metallic gold title with flourishes; gradient kept; the drop shadow is dropped |
| `dome_green.png` | 138x137 | `..._sg3d2y...jpeg` | box (828,338)-(968,486) | Green dome with gold finial and pale base; windows refilled opaque |
| `medallion_emerald.png` | 441x441 | `..._gt9ony...jpeg` | ring centre (896,265), outer r 202 | Gold ring + dark green fill + gold title |
| `medallion_emerald_b.png` | 437x437 | `..._hfx58y...jpeg` | ring centre (896,277), outer r 200 | Variant with thinner double ring and a small seal/tughra at lower left |
| `medallion_ivory.png` | 391x391 | `..._rs2fnp...jpeg` | ring centre (896,256), outer r 179 | Ivory disc, pale blue arabesque, gold «تقويم», navy «أهل البيت», gold + navy rings |
| `title_navy.png` | 312x272 | `..._rs2fnp...jpeg` | disc of r 157 (ring r − 22) | Title lifted out of the ivory medallion: navy «أهل البيت» + gold «تقويم» + flourishes, no arabesque |

Each keyed asset is cropped tight to its alpha bbox and padded by 4 % of its larger side.

## Method / thresholds

* **Keyed assets**: pixel = key + a·(fg − key) for a few reference colours
  ("classes"). The class with the smallest residual gives `a`; `a *= GAIN`
  (1.12–1.2) so stroke interiors become fully opaque; `a < CUTOFF` (0.06–0.08)
  → 0 to kill JPEG noise. Colour is un-premultiplied against the key
  (`fg = key + (px − key)/a`), so edges keep the stroke colour, with no navy halo.
  8-connected components under 30–60 px, or with no pixel ≥ 0.5 alpha, are dropped.
  * title_white / finial: key (11,31,56); classes white (247,248,249), gold (186,163,116).
  * title_gold: key (14,32,55); classes (240,212,172), (210,171,125), (150,108,66).
  * dome: key (12,31,52); six green/white/gold classes; enclosed holes filled.
  * title_navy: key ivory (248,248,242); classes navy (28,38,66), gold-brown
    (168,128,70); alpha remapped from [0.30, 0.80] to [0, 1] to remove the pale arabesque.
* **Medallions**: on 360 rays from an approximate centre, the outermost ring
  pixel within [r−30, r+12] is taken (gold test `R>120 && R−B>45`; ivory: distance
  from ivory > 45). A least-squares circle is fitted, the worst 30 % trimmed, and
  the fit repeated 3 times. The mask is radius+1 with a 1.5 px linear feather.

## Quality notes (honest)

* Edges are clean: no visible halo over navy, emerald, ivory, red or checkerboard.
  Letter counters are transparent and the thin flourish strokes are intact.
* **Resolution is the limit.** The title calligraphy is only ~860 px wide
  (white), ~575 px (gold) or ~270 px (navy), and the medallions are ~400 px.
  On a 1000-px-wide poster, a title shown 500–600 px wide is about 1:1 at 1x, so it
  looks sharp. At the 3x export (1500–1800 px) it is upscaled ~2–3x and will look
  visibly soft: blurry edges, JPEG mush in the gold gradient. The navy title and
  the dome (138 px) are only fit for small display (≤ ~150 px at 1x for the dome).
  A medallion shown ~300 px at 1x becomes ~900 px at 3x, so ~2.2x upscale: soft.
* medallion_ivory: the gold side ornaments of the original are clipped by the
  circle, leaving tiny stubs at 9 and 3 o'clock. A pale ivory band outside the gold
  ring (inside the navy arcs) is part of the disc.
* medallion_emerald: a thin dark bevel/shadow line outside the gold ring is included.
* dome_green: the pale base glow is kept as a soft "shadow"; bottom corners
  are ~82 % transparent rather than 100 %.
* The artwork is AI-generated, so it is not a verified, correct calligraphy of the
  text. It reads correctly as «تقويم أهل البيت», but the diacritic flourishes are decorative.

## Recommendation

For print-quality output, the user should supply the logo as **vector (SVG/PDF)
or a ≥ 2000 px-wide transparent PNG** from the original designer or calligrapher.
Until then, these assets are good for on-screen previews and 1x/2x exports. At 3x
they work, but expect softness.
