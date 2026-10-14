# Brand kit

- **Source:** the calligraphy in the user's Gemini mock-ups, traced by `tool/vectorize_logos.py` (own tracer: 4× alpha upscale → marching squares → RDP → Bézier fit; no external tools).
- **Output:** `lib/brand/logo_paths.dart` (generated — do not hand-edit), parsed once by `lib/brand/svg_path.dart` into cached `ui.Path`s, painted by `BrandLogoPainter` (`shouldRepaint` false). Widgets: `BrandTitle`, `BrandMedallion`, `BrandMark`.
- **Templates using it:** navy_calligraphy, midnight_dome, emerald_mihrab, emerald_garden, ivory_medallion (raster title/medallion removed; the dome and finial stay raster). Only these five goldens changed.
- **Kit files:** `brand/svg`, `brand/png` (2048 px), `brand/README.md` (colours, clear space, minimum size).
- **Result:** logos are crisp at ×4 / A3 export (previously 575–860 px rasters).
