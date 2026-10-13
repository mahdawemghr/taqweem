# Task Plan — Taqweem Poster Generator
Goal: Flutter Arabic RTL app → monthly Islamic calendar posters (5 templates, PNG/PDF).
Spec: docs/superpowers/specs/2026-10-12-taqweem-poster-design.md
Plan: docs/superpowers/plans/2026-10-12-taqweem-poster-generator.md
Execution: subagent-driven (ledger: .superpowers/sdd/2026-10-12-taqweem-poster-generator/progress.md). NO git commits (user rule).

## Next Step
T21a DONE. Shia S2 source-upgrade passes running (months 1-3, 7-9, 10-12), then S3 (user decisions: single-source items, Eid al-Zahra, Torah/Zabur days, Unity Week, Raghaib; Haqibat pages) → S4 build; then T21b polish (save-error chip Arabic, a11y pass).

### Phases / Tasks
- [x] T1 Foundation  - [x] T2 Time format  - [x] T3 Models  - [x] T4 CalendarFill  - [x] T5 Validation
- [x] T6 Seed data  - [x] T7 Repository  - [x] T8 State  - [x] T9 Template foundation  - [x] T10 Navy&Gold
- [x] T11 Exporter  - [x] T12 Home  - [x] T13 Setup step  - [x] T14 Grid step  - [x] T15 Texts step
- [x] T16 Export step  - [x] T17 Cream&Gold (review batched after T20)  - [x] T18 Minimal (defects pending combined review)  - [x] T19 Deep Green  - [x] T20 Mosque Blue
- [ ] T21 Polish + verify (T21a integration now; T21b final after Shia S4)

## NEW (2026-10-13): Shia-only content phase (user requirement; see memory shia-only-content.md)
- [x] S1 Research Shia occasions (first pass, all 12 months; compiled in docs/shia-occasions/COMPILED.md) → docs/shia-occasions/research/
- [ ] S2 Consolidate + independent cross-check
- [ ] S3 User approval of compiled list + design (gate)
- [ ] S4 Implement DB + grid suggestions + clean seed/suggestions
- [ ] S5 Verify
