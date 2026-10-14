# Taqweem brand kit — «تقويم أهل البيت»

The logo is the user's own calligraphy, traced into true vector outlines
(`tool/vectorize_logos.py`), so it stays sharp at any size.

| File | Use |
|---|---|
| `svg/title_gold.svg`, `svg/title_two_tone.svg` | calligraphic title only (dark backgrounds) |
| `svg/medallion_emerald.svg`, `svg/medallion_emerald_double.svg` | gold-ringed emerald medallion (app icon basis) |
| `svg/medallion_ivory.svg` | medallion for light backgrounds |
| `png/*.png` | 2048 px renders of the same artwork (transparent) |

**Colours:** emerald `#08342C` · deep emerald `#082623` · gold `#C9A45E` · light gold `#D8B977` · ivory `#F9F9F4` · navy `#142139` · white `#FBFDFD`.

**Clear space:** keep at least ¼ of the medallion's width free on every side. **Minimum size:** medallion 24 px, title 96 px wide. Never stretch, recolour outside the palette, or place on busy backgrounds.

**In code:** `BrandTitle`, `BrandMedallion`, `BrandMark` (`lib/brand/brand_logo.dart`).
**Regenerate PNGs:** `flutter test --run-skipped --tags brand-export test/brand/brand_export_test.dart`.
