# Validation Gates

## Tier 1 — Unit Test Benchmarks (Hard Gate)

### GO

- `ComprehensiveBaseline` must not regress on `p99` (it is the primary scenario).
- At least 2 of 4 scenarios (`ComprehensiveBaseline`, `QuoteHeavy`, `FullComplex`, `DeepNest`) improve on `p99` by at least 8 percent and 1.0ms.
- No scenario regresses by more than 3 percent or 0.5ms on `p99`.
- Frame stability improves, or remains within noise while `p99` improves.

### HOLD

- Hotspot movement appears in profiling, but `p99` gain is below the GO threshold.
- Improvement only appears in one scenario.
- `ComprehensiveBaseline` regresses by 1–5 percent on `p99` while other scenarios improve.
- Tier 1 says GO but Tier 2 raises concerns (see below).

### ROLLBACK

- `ComprehensiveBaseline`, `FullComplex`, or `DeepNest` regresses by more than 5 percent or 0.75ms on `p99`.
- Frame pacing materially worsens.
- Memory churn materially worsens without `p99` benefit.

---

## Tier 2 — Demo App Profiling (Qualitative Gate)

Tier 2 cannot promote a HOLD to GO. It can only demote a GO to HOLD.

### Pass (confirms GO)

- No new sustained hitches during streaming in the Chat tab.
- `AttachmentPool` dequeue rate ≥ 80% (pool is working, not creating new views constantly).
- The 15×10 table renders without visible frame drops on first appearance.
- Scroll + stream simultaneously: hitch ratio does not worsen vs baseline trace.
- Memory footprint delta ≤ 5% vs baseline trace (no leaked allocations from the optimization).

### Concern (demotes GO → HOLD)

- New hitch cluster appears during scroll + stream that was not present in baseline.
- `AttachmentPool` dequeue rate drops below 60% (pool invalidation too aggressive).
- Image loading latency increases (visible as delayed image appearance during stream).
- Cell reuse overhead increases: `prepareForReuse` or `layoutSubviews` appears in top-5 Time Profiler hotspots where it did not before.

### Red Flag (demotes to ROLLBACK)

- Crash or visual corruption in the demo app.
- Memory growth that does not plateau (leak).
- Hitch ratio > 10% during normal streaming (no scroll) — unusable.

---

## Lane Priority (Global First)

When multiple lanes are close, prioritize in this order:

1. Text layout or typesetter path
2. Shared parser or render path
3. Attachment reconcile path
4. Quote-specific path

---

## Required Evidence Per Iteration

### Tier 1 (always)
- One full run log showing `testStreamingPerformanceSummary_JSON` and JSON markers.
- Before/after table for `ComprehensiveBaseline`, `QuoteHeavy`, `FullComplex`, and `DeepNest` with `avg_ms` and `p99_ms`.

### Tier 2 (when performed)
- Trace files for `Time Profiler`, `Allocations`, and `Animation Hitches`.
- Top-3 hotspot summary from Time Profiler (Chat tab, streaming + scroll).
- Pool efficiency note: dequeue rate, pool size plateau.
- Hitch summary: count, severity, clustering.

### Verdict (always)
- Final verdict: `GO`, `HOLD`, or `ROLLBACK`, with threshold checks for each scenario (`ComprehensiveBaseline` is the primary gate).
- If Tier 2 performed: explicit pass/concern/red-flag assessment with trace evidence.

---

## Environment Notes

- If `xctrace --launch` cannot execute repo scripts because of permission restrictions, execute a helper script from `/tmp`.
- If all-process Time Profiler exports are dominated by simulator dylib overlap noise, use benchmark JSON as the hard gate and treat profile output as directional.
- If Allocations shows SIP restricted-process attach warnings, do not use it as the sole gate.
- Demo app `StreamingSimulator` runs at 50ms intervals with 1–3 random chars/tick. Cell update and table update are both throttled at 250ms. These timings affect trace shape but not the optimization verdict.
