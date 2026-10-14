# Motion

Tokens live in `lib/core/motion.dart` (`Motion.instant/quick/base/emphasised/reveal`, curves, `Motion.of(context, d)` → zero when the platform's reduce-motion is on). Widgets in `lib/core/motion_widgets.dart`.

**Rules:** transform + opacity only; 90–360 ms (launch reveal ≤ 1.1 s); nothing loops (so `pumpAndSettle` terminates); never animate a poster; no blur/backdrop filters; no `Opacity` around big subtrees (`FadeTransition` instead); built-in Flutter animation only.

| Where | What |
|---|---|
| Launch (`features/splash/launch_reveal.dart`) | emerald overlay continues the native splash: medallion fades in, calligraphy wiped right→left, one gold shimmer, overlay fades onto Home. Once per process; skipped with reduce-motion. Never blocks startup. |
| Editor steps | `FadeThrough`: old step fades out (90 ms) and is removed before the new one is built (160 ms, 8 px rise) — one heavy step at a time. |
| Save indicator | spinner ↔ ✓ cross-scale/fade. |
| Day grid | 600 ms gold tint on rows changed by auto-fill / time shift (overlay opacity only). |
| Home | empty-state illustration one-shot entrance; FAB shrinks to its icon while scrolling down; state switch uses `Motion.base`. |
| Export | success "stamp" (check scales in, holds, fades); failure dialog shakes once. |

**Tests:** `test/core/motion_test.dart`. The suite runs with motion off (`test/flutter_test_config.dart`); `TAQWEEM_MOTION=1 flutter test` runs it with motion on.

**Also:** card thumbnail Hero into the editor mini preview, card delete fade-out, template-picker page scaling, stepper colour tween.
