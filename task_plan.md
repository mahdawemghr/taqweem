# Task Plan — Taqweem Poster Generator
Goal: Flutter Arabic RTL app → monthly Islamic calendar posters (5 templates, PNG/PDF).
Spec: docs/superpowers/specs/2026-10-12-taqweem-poster-design.md
Plan: docs/superpowers/plans/2026-10-12-taqweem-poster-generator.md
Execution: subagent-driven (ledger: .superpowers/sdd/2026-10-12-taqweem-poster-generator/progress.md). NO git commits (user rule).

## QA & POLISH ROUND (2026-10-14, user request: "test the app, check everything, polish")
- [x] Q1 Run the real app headless (Xvfb, NOT the user's :0 display) + screenshots of every screen/state
- [x] Q2 Audit findings: bugs, visual defects, jank, a11y, RTL, text overflow, small screens, large text
- [x] Q3 Fix everything found; add regression tests
- [x] Q4 Remaining motion done: card->editor Hero, delete fade, picker page scale, stepper tween; template arrows fixed (RTL)
- [x] Q5 Full verify: tests (capped memory!), analyze, linux build; report

## Next Step
(2026-10-14 late) Brand/Motion/Perf round DONE: vector logo + brand kit, app icons + native launch, FitText cache + thumbnail cache, motion system. 906 tests, analyze clean, linux debug build OK. Waiting on USER decisions. Nothing committed.

(older) ALL PLANNED WORK DONE (T1-T21, Shia S1-S6, templates D1-D7; 876 tests, analyze clean, linux debug build OK). Waiting on USER decisions (see ledger PROJECT STATE). Nothing committed by me.

### Phases / Tasks
- [x] T1 Foundation  - [x] T2 Time format  - [x] T3 Models  - [x] T4 CalendarFill  - [x] T5 Validation
- [x] T6 Seed data  - [x] T7 Repository  - [x] T8 State  - [x] T9 Template foundation  - [x] T10 Navy&Gold
- [x] T11 Exporter  - [x] T12 Home  - [x] T13 Setup step  - [x] T14 Grid step  - [x] T15 Texts step
- [x] T16 Export step  - [x] T17 Cream&Gold (review batched after T20)  - [x] T18 Minimal (defects pending combined review)  - [x] T19 Deep Green  - [x] T20 Mosque Blue
- [x] T21 Polish + verify (T21a integration, T21b final)

## NEW (2026-10-13): Shia-only content phase (user requirement; see memory shia-only-content.md)
- [x] S1 Research Shia occasions (first pass, all 12 months; compiled in docs/shia-occasions/COMPILED.md) → docs/shia-occasions/research/
- [~] S2 partial (months 4-6, 7-9 upgraded; 1-3, 10-12 first pass; rate limits) — continue only if user supplies Haqibat pages or asks
- [x] S3 user said "continue" after list+questions (R23)
- [x] S4 Shia occasions DB + grid chips/auto-fill + seed/suggestion cleanup (S4a-c, S6b; 139 entries, 111 verified/28 unverified; 502 tests at that point)
- [x] S5 independent review done (S4 review + data integrity scripts); open items need user decisions
