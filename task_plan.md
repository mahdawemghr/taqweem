# Task Plan — Taqweem Poster Generator
Goal: Flutter Arabic RTL app → monthly Islamic calendar posters (5 templates, PNG/PDF).
Spec: docs/superpowers/specs/2026-10-12-taqweem-poster-design.md
Plan: docs/superpowers/plans/2026-10-12-taqweem-poster-generator.md
Execution: subagent-driven (ledger: .superpowers/sdd/2026-10-12-taqweem-poster-generator/progress.md). NO git commits (user rule).

## Next Step
S6: user scans as source+convention (R24): transcribe 4 other posters + compare vs DB → apply main/alt swaps + add scan occasions + review minors → light re-review → T21b polish. S4a-c done (483 tests), reviewed.

### Phases / Tasks
- [x] T1 Foundation  - [x] T2 Time format  - [x] T3 Models  - [x] T4 CalendarFill  - [x] T5 Validation
- [x] T6 Seed data  - [x] T7 Repository  - [x] T8 State  - [x] T9 Template foundation  - [x] T10 Navy&Gold
- [x] T11 Exporter  - [x] T12 Home  - [x] T13 Setup step  - [x] T14 Grid step  - [x] T15 Texts step
- [x] T16 Export step  - [x] T17 Cream&Gold (review batched after T20)  - [x] T18 Minimal (defects pending combined review)  - [x] T19 Deep Green  - [x] T20 Mosque Blue
- [ ] T21 Polish + verify (T21a integration now; T21b final after Shia S4)

## NEW (2026-10-13): Shia-only content phase (user requirement; see memory shia-only-content.md)
- [x] S1 Research Shia occasions (first pass, all 12 months; compiled in docs/shia-occasions/COMPILED.md) → docs/shia-occasions/research/
- [~] S2 partial (months 4-6, 7-9 upgraded; 1-3, 10-12 first pass; rate limits) — continue only if user supplies Haqibat pages or asks
- [x] S3 user said "continue" after list+questions (R23)
- [ ] S4 Implement DB + grid suggestions + clean seed/suggestions
- [ ] S5 Verify
