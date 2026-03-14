---
name: stx-instruments
description: Instruments-driven workflow for STXMarkdownView streaming performance work. Use when profiling markdown rendering bottlenecks, running Time Profiler/Allocations/Animation Hitches, comparing QuoteHeavy FullComplex DeepNest baselines, profiling the MarkdownDemo app for real-world validation, and deciding GO HOLD or ROLLBACK for optimization slices.
---

# STX Instruments

Two-tier performance workflow for `STXMarkdownView` optimization slices.

- **Tier 1 — Unit Test Benchmarks** (hard quantitative gate). Reproducible numbers from `StreamingPerformanceTests`.
- **Tier 2 — Demo App Profiling** (real-world validation). Instruments traces on the actual `MarkdownDemo` app to catch bottlenecks that synthetic tests miss.

Both tiers are required. A slice that passes Tier 1 but shows regressions in Tier 2 is `HOLD` until investigated.

Read `references/validation-gates.md` before making a final verdict.

---

## Tier 1 — Unit Test Benchmarks

### Run Order

1. Establish baseline with `testStreamingPerformanceSummary_JSON` on the **before** commit.
2. Apply the optimization slice.
3. Run the same test on the **after** commit, same device class and simulator.
4. Compare `ComprehensiveBaseline`, `QuoteHeavy`, `FullComplex`, `DeepNest` against baseline.
5. Apply validation gates (GO / HOLD / ROLLBACK).

### Required Scenarios

| Scenario | Focus | Content Scale |
|----------|-------|---------------|
| `QuoteHeavy` | Recursive quote nesting, code + tables inside quotes | ~70 lines |
| `FullComplex` | Multi-table, mixed block types, images, task lists | ~130 lines |
| `DeepNest` | 3-level nested quotes + lists + code + table | ~60 lines |
| `ComprehensiveBaseline` | **Primary profiling target.** All element types at demo-app complexity: 15×10 table, 4-language code blocks, 3-level quotes with code+table+list, 3-level lists with blocks at each level, images in all contexts, task lists, stress patterns | ~330 lines |

`ComprehensiveBaseline` is the most representative scenario and should be the **primary Instruments profiling target**. The other three scenarios isolate specific subsystems. Treat `p99` as primary metric, `avg` as secondary.

### Content Complexity Coverage

`ComprehensiveBaseline` (`kComprehensiveBaselineDocument`) closes the gap between unit test fixtures and the demo app's `markdownContent` (~300 lines):

| Dimension | Other Fixtures | ComprehensiveBaseline | Demo App |
|-----------|----------------|----------------------|----------|
| Code block languages | 1–2 | 6 (Swift, Rust, JSON, SQL, Python, YAML) | 4 |
| Largest table | 3–4 rows | 15 rows × 10 columns | 15 × 10 |
| List nesting depth | 2–3 levels | 3 levels with blocks at each | 3+ levels |
| Quote nesting depth | 1–3 levels | 3 levels with code+table+list | 2 levels |
| Images | URL placeholders | Block, inline, quote, table, list | Block, inline, nested |
| Stress patterns | None | Long-cell table, table-in-quote-in-list, adjacent code blocks | None |
| Concurrent views | 1 MarkdownView | 1 MarkdownView | Multiple (UITableView cells) |
| Cell reuse | None | None | Full UITableView cell lifecycle |

The remaining gaps (concurrent views, cell reuse) are covered by Tier 2 demo app profiling.

---

## Tier 2 — Demo App Profiling

### When to Run

- After Tier 1 yields `GO` or `HOLD` — confirm the gain is real under production conditions.
- When investigating a suspected bottleneck that unit tests cannot reproduce (cell reuse, scrolling, image loading).
- When an optimization targets attachment pooling, table layout, or image cache — these are exercised much harder by the demo app.

### Profiling Steps

1. Build `MarkdownDemo` for the same simulator used in Tier 1.
2. Launch via Instruments with the **Time Profiler** template.
3. Navigate to the **Chat** tab (UITableView with `ChatBubbleCell`).
4. Tap **Start Stream** — let the full `markdownContent` stream in (~300 lines).
5. During streaming, **scroll up and down** to trigger cell reuse + concurrent layout.
6. Capture 15–20 seconds covering stream start → stream end → post-stream scroll.
7. Stop and save the trace.
8. Repeat with **Allocations** and **Animation Hitches** templates.

Also profile the **Streaming Demo** tab (single `MarkdownView`) as a comparison baseline — this isolates rendering from UITableView overhead.

### What to Look For

**Time Profiler:**
- `layoutSubviews` in `ChatBubbleCell` during scroll — cell layout should not dominate
- `MarkdownRenderer.render` call frequency per cell update cycle
- `Highlightr` attribution time per language — 4 languages means 4× highlighting work
- `TableCellSizeCache` hit vs miss ratio for the 15×10 table
- `AttachmentPool.dequeue` vs `create` ratio — pool should serve most requests
- `MarkdownTextView.layoutSubviews` glyph rect calculations

**Allocations:**
- Transient allocation spikes on each streaming tick (should be decreasing as pool warms)
- `NSAttributedString` creation frequency — incremental update (O7) should reduce this
- Image cache memory footprint under the full content set
- `AttachmentPool` growth curve — should plateau, not grow linearly

**Animation Hitches:**
- Commit phase duration during streaming — should stay under 8ms for 60fps
- Hitch ratio during scroll + simultaneous stream — the hardest scenario
- Frame drops on first appearance of the 15×10 table
- Hitch severity distribution: occasional minor hitches acceptable, sustained major hitches are `HOLD`

---

## Capture Policy

- One optimization slice per iteration.
- Same device class, same simulator family, same benchmark order across Tier 1 and Tier 2.
- Collect all three Instruments templates each round:
  - **Time Profiler** (high frequency)
  - **Allocations**
  - **Animation Hitches**

If `xctrace --launch` cannot execute repo scripts in this environment, run a helper script from `/tmp` that launches the sandbox `xcodebuild test` flow.

---

## Artifacts To Produce Every Iteration

### Tier 1 (always required)
- Full test log with `PERF_JSON_BEGIN` and `PERF_JSON_END` markers.
- Before/after table for `ComprehensiveBaseline`, `QuoteHeavy`, `FullComplex`, `DeepNest` (`avg_ms`, `p99_ms`).

### Tier 2 (when performed)
- Trace files for Time Profiler, Allocations, Animation Hitches.
- Demo app trace analysis notes: top 3 hotspots, pool efficiency, hitch summary.
- Comparison: Streaming Demo tab (single view) vs Chat tab (UITableView) — quantify the overhead delta.

### Verdict (always required)
- Final verdict: `GO`, `HOLD`, or `ROLLBACK` with explicit gate checks per `references/validation-gates.md`.
- If Tier 1 says `GO` but Tier 2 shows concerns, verdict is `HOLD` with investigation notes.

---

## Environment Caveats

- `Allocations` may show restricted-process attach warnings under SIP.
- `--all-processes` Time Profiler exports may be noisy due to simulator dylib overlap.
- When Instruments exports are noisy, use benchmark JSON as hard gate and treat profiler output as directional.
- Demo app streaming uses `StreamingSimulator` (50ms interval, 1–3 random chars/tick). Cell update throttle is 250ms. These timings affect trace patterns but not the optimization verdict.
