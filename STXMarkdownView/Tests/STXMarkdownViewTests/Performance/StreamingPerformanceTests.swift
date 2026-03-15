// StreamingPerformanceTests.swift
// Baseline performance measurements for the streaming rendering hot path.
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║                       USAGE WORKFLOW                                     ║
// ║                                                                           ║
// ║  Step 1 — Run ALL tests BEFORE optimization.                             ║
// ║            XCTest records baseline values in                             ║
// ║            PerformanceBaselines_*.json next to this file.               ║
// ║                                                                           ║
// ║  Step 2 — Implement optimizations.                                        ║
// ║                                                                           ║
// ║  Step 3 — Run tests AFTER optimization.                                   ║
// ║            XCTest compares against stored baselines and flags            ║
// ║            regressions (red) or improvements (displayed in results).     ║
// ║                                                                           ║
// ║  Step 4 — Check XCTAttachments in the test result bundle for the         ║
// ║            per-frame distribution reports (P50/P95/P99).                 ║
// ║            These are stored with lifetime=keepAlways for before/after.   ║
// ╚══════════════════════════════════════════════════════════════════════════╝
//
// MEASUREMENT STRATEGY
// ────────────────────
// All end-to-end "streaming frame" tests drive rendering via the public
// `markdown` property setter with `isStreaming = false`. This triggers
// `renderIfReady()` → `render(with width:)` synchronously — the exact same
// code path as the streaming timer callback (`executeThrottledRender()` →
// `render(with width:)`), minus timer scheduling overhead.
//
// Cache behavior is identical to streaming: the `markdown` didSet always
// clears `cachedDocument`, so every chunk in the loop causes a full AST
// re-parse (measuring bottleneck I5 accurately).
//
// IDENTIFIED BOTTLENECKS COVERED
// ───────────────────────────────
//  I5  — Full AST re-parse every frame (cachedDocument always cleared)
//  I8  — Recursive synchronous layoutIfNeeded in attachment layout pass
//  I14 — systemLayoutSizeFitting per code block per frame (no size cache)
//  I15 — systemLayoutSizeFitting per blockquote per frame
//  I22 — CodeBlockAnalyzer.analyze() on every render regardless of isStreaming
//  I43 — theme.quoted computed property allocates 6 structs on every access
//  I9  — AttachmentPool.accessOrder linear LRU search O(n) per recycle
//  I10 — evictIfNeeded() runs on every recycle even well below capacity

import XCTest
import UIKit
@testable import STXMarkdownView

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Machine-Readable Performance Data (Wave 0)
// ─────────────────────────────────────────────────────────────────────────────

/// Decision thresholds for keep/remove decisions:
/// - regression: >5% slower → flag
/// - improvement: >10% faster → keep
/// - target_p99: 16.67ms = 60 FPS frame budget
private enum PerfThreshold {
    static let regressionPct: Double = 5.0
    static let improvementPct: Double = 10.0
    static let targetP99ms: Double = 16.67
}

private struct DocumentTimingResult: Codable {
    let document: String
    let frames: Int
    let p50_ms: Double
    let p95_ms: Double
    let p99_ms: Double
    let min_ms: Double
    let max_ms: Double
    let avg_ms: Double
    let total_ms: Double
    let frameBudget: FrameBudgetReport
}

private struct FrameBudgetReport: Codable {
    let frameBudgetMs: Double
    let totalFrames: Int
    let overBudgetCount: Int
    let overBudgetRatio: Double
    let overBudgetTimeMs: Double
    let maxFrameTimeMs: Double
    let severity: SeverityDistribution
}

private struct SeverityDistribution: Codable {
    let mild: Int
    let moderate: Int
    let severe: Int
}

private struct PerformanceSummary: Codable {
    let timestamp: String
    let documents: [DocumentTimingResult]
    let thresholds: ThresholdInfo

    struct ThresholdInfo: Codable {
        let regression_pct: Double
        let improvement_pct: Double
        let target_p99_ms: Double
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Streaming Fixture Documents
// ─────────────────────────────────────────────────────────────────────────────
// Three fixtures of increasing complexity, reflecting realistic AI chat output.

/// Scenario 1: Plain text only — no attachment views.
/// Isolates TextKit layout + NSAttributedString overhead.
private let kPlainDocument = """
Here is a detailed summary of our technical discussion today.

The team reached consensus on the following items:

1. We will adopt a new branching strategy starting next sprint
2. Code reviews must be completed within 24 hours of the PR being opened
3. All new features require unit tests with at least 80% coverage
4. Integration tests should run in CI on every push to main

These changes take effect immediately and apply to all active repositories. \
Team leads are responsible for communicating this to their respective squads.
"""

/// Scenario 2: Code block heavy — two fenced code blocks.
/// Exercises bottlenecks I5/I14/I22: AST re-parse + fence scanning +
/// systemLayoutSizeFitting per code block on every streaming frame.
private let kCodeDocument = """
# Optimized Implementation

Here is the refactored version with improved performance characteristics:

```python
def process_items(data, threshold=0.5):
    cache = {}
    results = []
    for item in data:
        key = item.get_key()
        if key not in cache:
            score = compute_score(item)
            cache[key] = score
        if cache[key] >= threshold:
            results.append(item)
    return results
```

The main improvement is using a dictionary cache to avoid redundant \
`compute_score` calls on duplicate keys. The time complexity is reduced \
from O(n·m) to O(n) where m is the number of unique keys.

```swift
func processItems(_ data: [Item], threshold: Double = 0.5) -> [Item] {
    var cache: [String: Double] = [:]
    return data.filter { item in
        let key = item.key
        if cache[key] == nil {
            cache[key] = computeScore(item)
        }
        return (cache[key] ?? 0) >= threshold
    }
}
```
"""

/// Scenario 3: Rich document — heading + blockquote + 2× code block + table.
/// Worst-case streaming scenario. Exercises ALL identified bottlenecks:
/// I5 (AST re-parse) + I8 (recursive layout) + I14/I15 (size fitting) +
/// I22 (fence scan) + I43 (theme.quoted allocation).
private let kRichDocument = """
# Performance Analysis Report

> **Important:** These benchmarks were recorded on production hardware \
> with warm caches. Results may vary across different device generations \
> and OS versions.

## Solution A — Python

```python
def fast_process(items):
    return [transform(x) for x in items if x.is_valid()]
```

## Solution B — Swift

```swift
func fastProcess(_ items: [Item]) -> [Item] {
    items.compactMap { $0.isValid ? transform($0) : nil }
}
```

## Benchmark Results

| Metric         | Solution A | Solution B |
|----------------|------------|------------|
| Time (ms)      | 45         | 12         |
| Memory (MB)    | 8.2        | 4.1        |
| Allocations    | 1,240      | 320        |

Solution **B** is approximately **3.75×** faster with **3.9×** less \
memory usage on a representative production dataset of 10,000 items.
"""

/// Scenario 4: Large table document — 10×6 table with surrounding content.
/// Exercises table layout sizing (MarkdownTableView adaptive layout) at scale.
/// Real AI responses often include data tables with 10+ rows.
private let kLargeTableDocument = """
# Employee Performance Dashboard — Q4 2024

The following table summarizes performance metrics across all departments:

| ID | Name | Role | Department | Score | Status | Joined | Projects | Rating | Notes |
|----|------|------|-----------|-------|--------|--------|----------|--------|-------|
| 001 | Alice Chen | Senior Engineer | Engineering | 95 | Active | 2019-03 | 12 | ⭐⭐⭐⭐⭐ | Tech lead candidate |
| 002 | Bob Martinez | Product Manager | Product | 88 | Active | 2020-01 | 8 | ⭐⭐⭐⭐ | Mentoring two PMs |
| 003 | Carol Wang | Staff Designer | Design | 92 | Active | 2018-06 | 15 | ⭐⭐⭐⭐⭐ | Design system owner |
| 004 | David Kim | DevOps Lead | Infrastructure | 90 | Active | 2019-11 | 10 | ⭐⭐⭐⭐⭐ | On-call champion |
| 005 | Emma Johnson | Data Scientist | Analytics | 87 | Active | 2021-02 | 6 | ⭐⭐⭐⭐ | ML pipeline |
| 006 | Frank Liu | QA Engineer | Quality | 85 | Active | 2020-08 | 9 | ⭐⭐⭐⭐ | Automation lead |
| 007 | Grace Park | Frontend Dev | Engineering | 91 | Active | 2019-05 | 11 | ⭐⭐⭐⭐⭐ | React specialist |
| 008 | Henry Wilson | Backend Dev | Engineering | 89 | On Leave | 2020-03 | 7 | ⭐⭐⭐⭐ | Rust migration |
| 009 | Iris Zhang | UX Researcher | Design | 86 | Active | 2021-01 | 5 | ⭐⭐⭐⭐ | User interviews |
| 010 | Jack Brown | Security Eng | Infrastructure | 93 | Active | 2018-09 | 14 | ⭐⭐⭐⭐⭐ | Zero-trust architect |

> **Note**: Scores above 90 are eligible for the annual excellence award. \
> Employees on leave retain their last recorded score.

Detailed breakdown available in the full quarterly report.
"""

/// Scenario 5: Deeply nested document — 3-level blockquotes + 3-level lists
/// with code blocks and tables inside list items.
/// Exercises recursive rendering (QuoteView with nested MarkdownTextView)
/// and parser traversal depth.
private let kDeepNestDocument = """
# Architecture Decision Record — ADR-042

## Context

The migration requires careful consideration of nested data structures:

> **Level 1 — API Gateway**
>
> The gateway handles initial request validation and routing.
>
> > **Level 2 — Service Mesh**
> >
> > Internal services communicate via gRPC with mTLS:
> >
> > > **Level 3 — Data Layer**
> > >
> > > Each service owns its database schema. Cross-service queries
> > > go through the event bus, never direct DB access.
> > >
> > > This ensures proper **bounded contexts** and prevents
> > > *tight coupling* between services.

### Implementation Plan

- **Phase 1**: Gateway refactoring
  - Extract authentication middleware
  - Implement rate limiting per tenant
    - Token bucket algorithm for API keys
    - Sliding window for OAuth tokens
    - Custom limits for enterprise clients
      ```swift
      struct RateLimiter {
          let strategy: Strategy
          let windowSize: TimeInterval
          let maxRequests: Int

          func shouldAllow(_ request: Request) -> Bool {
              let count = store.count(for: request.key, within: windowSize)
              return count < maxRequests
          }
      }
      ```
- **Phase 2**: Service mesh deployment
  - Configure Envoy sidecars
  - Set up **mutual TLS** between all services
  - Deploy circuit breakers with these thresholds:

    | Service | Timeout | Retry | Circuit Break |
    |---------|---------|-------|--------------|
    | Auth | 200ms | 2 | 5 failures/10s |
    | Users | 500ms | 3 | 10 failures/30s |
    | Orders | 1000ms | 1 | 3 failures/15s |

- **Phase 3**: Data layer migration
  1. Create event schemas
  2. Deploy Kafka topics
  3. Implement CDC connectors
     > **Warning**: CDC connectors must be configured with `snapshot.mode=initial`
     > for the first deployment, then switched to `snapshot.mode=never`.
"""

/// Scenario 6: Mixed content mashup — every element type in a single document.
/// Heading, emphasis, lists, ordered lists, task lists, blockquotes, code blocks,
/// tables, thematic breaks, images, links, strikethrough.
/// Maximum element diversity per document.
private let kMixedContentDocument = """
# Release Notes v2.5.0

*Published on January 15, 2025* — [Full Changelog](https://example.com/changelog)

## ✨ New Features

- **Dark mode support** across all screens
- Added `RTL` layout support for Arabic and Hebrew
- ~Removed legacy OAuth 1.0 flow~ — replaced with OAuth 2.1

### Task List

- [x] Implement **dark mode** toggle in settings
- [x] Update `ColorTheme` protocol with dark variants
- [ ] Add *accessibility audit* for contrast ratios
- [ ] Write migration guide for breaking changes

***

## 🔧 Technical Details

Here is the new theme configuration:

```json
{
  "theme": {
    "mode": "auto",
    "colors": {
      "primary": "#007AFF",
      "background": {
        "light": "#FFFFFF",
        "dark": "#1C1C1E"
      },
      "text": {
        "light": "#000000",
        "dark": "#FFFFFF"
      }
    },
    "borderRadius": 12,
    "fontScale": 1.0
  }
}
```

> The theme system now supports **automatic switching** based on the
> system appearance preference.
>
> Key improvements:
> - 60% faster theme application
> - Zero-flicker transitions
> - Per-component override capability

## 📊 Performance Impact

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| Cold start | 1.2s | 0.8s | **-33%** |
| Theme switch | 450ms | 12ms | **-97%** |
| Memory baseline | 42MB | 38MB | **-10%** |
| Frame drops/min | 8.5 | 0.2 | **-98%** |

## 🖼️ Screenshots

![Dark mode home screen](https://picsum.photos/400/300)

> Before and after comparison:
>
> ![Light mode](https://picsum.photos/200/150)

## 💻 Migration Code

For existing users upgrading from v2.4.x:

```swift
// Before (v2.4)
let theme = LegacyTheme(color: .blue)
view.apply(theme)

// After (v2.5)
let theme = Theme.default.withMode(.auto)
view.applyTheme(theme, animated: true)
```

```sql
-- Database migration for user preferences
ALTER TABLE user_settings ADD COLUMN theme_mode VARCHAR(10) DEFAULT 'auto';
UPDATE user_settings SET theme_mode = 'light' WHERE dark_mode_enabled = false;
UPDATE user_settings SET theme_mode = 'dark' WHERE dark_mode_enabled = true;
ALTER TABLE user_settings DROP COLUMN dark_mode_enabled;
```

***

###### Footer

For questions, contact the **Platform Team** via `#platform-support` on Slack.
"""

/// Scenario 7: Full complexity stress test — combines the heaviest elements
/// from the demo app. This is the ultimate "real-world worst case" fixture.
/// ~150 lines, multiple large tables, nested quotes, code blocks, images, lists.
private let kFullComplexDocument = """
# Comprehensive System Analysis

## Executive Summary

This report covers the **complete architecture review** of our distributed system.
Key findings include *performance bottlenecks*, security gaps, and scaling concerns.

> **Critical Finding**: The authentication service is a single point of failure.
>
> > **Recommendation**: Deploy a **multi-region active-active** configuration
> > with automatic failover. Estimated effort: 3 sprints.
> >
> > > **Risk Assessment**: Without this change, a single region outage
> > > causes **100% authentication failure** across all services.

## Service Inventory

| Service | Language | Instances | CPU (avg) | Memory | RPS | P99 Latency | Health | Owner |
|---------|----------|-----------|-----------|--------|-----|-------------|--------|-------|
| api-gateway | Go | 12 | 45% | 2.1GB | 50k | 15ms | ✅ | Platform |
| auth-service | Rust | 4 | 30% | 512MB | 25k | 8ms | ⚠️ | Security |
| user-service | Java | 8 | 65% | 4.2GB | 15k | 45ms | ✅ | Identity |
| order-service | Go | 6 | 55% | 1.8GB | 10k | 35ms | ✅ | Commerce |
| payment-service | Rust | 3 | 20% | 256MB | 5k | 12ms | ✅ | Payments |
| notification | Python | 4 | 70% | 1.5GB | 8k | 120ms | ⚠️ | Comms |
| analytics | Scala | 2 | 80% | 8.0GB | 2k | 500ms | ❌ | Data |
| search-service | Go | 6 | 40% | 3.2GB | 20k | 25ms | ✅ | Discovery |
| media-service | Node.js | 5 | 35% | 2.0GB | 12k | 80ms | ✅ | Content |
| ml-inference | Python | 3 | 90% | 16GB | 1k | 200ms | ⚠️ | ML Team |

## Critical Path Analysis

### Authentication Flow

```rust
pub async fn authenticate(req: AuthRequest) -> Result<Token, AuthError> {
    // Step 1: Validate credentials
    let user = db::find_user(&req.username)
        .await
        .map_err(|_| AuthError::UserNotFound)?;

    // Step 2: Verify password with Argon2id
    let is_valid = argon2::verify_encoded(
        &user.password_hash,
        req.password.as_bytes()
    )?;

    if !is_valid {
        metrics::increment("auth.failures");
        return Err(AuthError::InvalidCredentials);
    }

    // Step 3: Generate JWT with claims
    let claims = Claims {
        sub: user.id.to_string(),
        exp: Utc::now() + Duration::hours(24),
        roles: user.roles.clone(),
        permissions: resolve_permissions(&user.roles),
    };

    let token = encode(&Header::default(), &claims, &ENCODING_KEY)?;
    metrics::increment("auth.successes");
    Ok(Token::new(token))
}
```

### Load Test Results

- **Baseline** (current production):
  1. Average response time: 45ms
  2. P99 response time: 120ms
  3. Error rate: 0.02%
     > These numbers were collected during peak traffic
     > on a Wednesday afternoon (highest historical load)
- **After optimization**:
  1. Average response time: 12ms
  2. P99 response time: 35ms
  3. Error rate: 0.001%
     ```swift
     // Load test configuration
     let config = LoadTestConfig(
         targetRPS: 100_000,
         duration: .minutes(30),
         rampUp: .minutes(5),
         concurrency: 500
     )
     ```

## Database Schema Changes

```sql
-- New partitioned events table
CREATE TABLE events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type VARCHAR(100) NOT NULL,
    aggregate_id UUID NOT NULL,
    payload JSONB NOT NULL,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    version INTEGER NOT NULL
) PARTITION BY RANGE (created_at);

-- Create monthly partitions
CREATE TABLE events_2025_01 PARTITION OF events
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE events_2025_02 PARTITION OF events
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');

-- Indexes for common query patterns
CREATE INDEX idx_events_aggregate ON events (aggregate_id, version);
CREATE INDEX idx_events_type_time ON events (event_type, created_at DESC);
```

![System Architecture Diagram](https://picsum.photos/800/400)

> **Next Steps**:
>
> | Phase | Timeline | Priority | Status |
> |-------|----------|----------|--------|
> | Auth HA | Sprint 1-3 | P0 | Planning |
> | Analytics rewrite | Sprint 2-5 | P1 | Scoping |
> | ML scaling | Sprint 3-4 | P1 | Blocked |
> | Notification rework | Sprint 4-6 | P2 | Backlog |

- [x] Complete architecture review
- [x] Document all service dependencies
- [ ] Schedule **migration planning** session
- [ ] Create runbooks for each `critical path`
"""

private let kQuoteHeavyDocument = """
# Incident Postmortem - Regional Auth Outage

> ## Timeline Summary
> 
> At 09:12 UTC, users in two regions began seeing intermittent login failures.
> 
> > ### Detection Signals
> > 
> > - API gateway error rate climbed from 0.3% to 14.8% within 4 minutes.
> > - Auth cache hit ratio dropped from 93% to 41%.
> > - Token minting latency crossed 800ms at P99.
> > 
> > ```swift
> > struct AuthHealth {
> >     let p50: Double
> >     let p95: Double
> >     let p99: Double
> >     let errorRate: Double
> > }
> > 
> > func degraded(_ h: AuthHealth) -> Bool {
> >     h.errorRate > 0.05 || h.p99 > 400
> > }
> > ```
> > 
> > | Metric | Baseline | During Incident | Delta |
> > |--------|----------|-----------------|-------|
> > | Error Rate | 0.3% | 14.8% | +14.5% |
> > | P99 Latency | 88ms | 842ms | +754ms |
> > | Cache Hit | 93% | 41% | -52% |
> > 
> > > #### Root Cause Candidate A
> > > 
> > > A malformed issuer list propagated to one shard group and triggered
> > > repeated fallback token validation.
> > > 
> > > ```bash
> > > kubectl -n auth get pods -l app=issuer-sync
> > > kubectl -n auth logs deploy/issuer-sync --tail=200
> > > ```
> > > 
> > > > ##### Containment Step
> > > > 
> > > > Roll back issuer bundle to the previous signed revision and force reload.

> ## Action Items
> 
> > 1. Add checksum gate before distributing issuer bundles.
> > 2. Add shard-level circuit breaker around fallback validation.
> > 3. Add SLO alert for cache hit ratio below 70% for 3 minutes.
> > 
> > | Owner | Item | Priority | ETA |
> > |-------|------|----------|-----|
> > | Security | checksum gate | P0 | 2 days |
> > | Platform | circuit breaker | P0 | 3 days |
> > | SRE | cache hit alert | P1 | 1 day |
> > 
> > ```json
> > {
> >   "incident": "auth-regional-outage",
> >   "status": "mitigated",
> >   "next_review": "2026-03-20T10:00:00Z",
> >   "action_items": 3
> > }
> > ```

Conclusion: apply staged rollout with quote-rich diagnostics enabled and verify
all remediation checkpoints before enabling full traffic.
"""

private let kComprehensiveBaselineDocument = """
# Platform Reliability Baseline **_Q2_** `v3.4` [Runbook](https://internal.example.com/runbooks/platform) ~~draft~~

This fixture models a full production operations brief with mixed markdown features, nested structures, and streaming-friendly complexity.

| Service | Owner | SLO | P50 (ms) | P95 (ms) | P99 (ms) | QPS | Error % | Region | Status |
|---------|-------|-----|----------|----------|----------|-----|---------|--------|--------|
| api-gateway | Edge Team | 99.95% | 12 | 34 | 71 | 12400 | 0.08 | us-east-1 | stable |
| auth-service | Identity Team | 99.99% | 18 | 52 | 109 | 8600 | 0.11 | us-east-1 | monitoring |
| billing-core | FinOps Team | 99.90% | 44 | 130 | 260 | 1700 | 0.21 | us-east-1 | stable |
| ledger-writer | FinOps Team | 99.99% | 27 | 88 | 173 | 2100 | 0.09 | us-west-2 | stable |
| catalog-index | Search Team | 99.90% | 32 | 118 | 242 | 5200 | 0.24 | eu-west-1 | degraded |
| recommendation-api | ML Platform | 99.50% | 58 | 170 | 344 | 7400 | 0.63 | us-central-1 | tuning |
| notification-router | Messaging Team | 99.90% | 21 | 66 | 140 | 9800 | 0.16 | ap-southeast-1 | stable |
| media-transcoder | Media Infra | 99.00% | 95 | 410 | 880 | 460 | 1.20 | eu-central-1 | constrained |
| report-exporter | Data Platform | 99.50% | 74 | 260 | 690 | 280 | 0.70 | us-west-2 | stable |
| audit-stream | Security Ops | 99.99% | 14 | 39 | 95 | 11200 | 0.04 | us-east-1 | stable |
| webhook-dispatcher | Integrations | 99.50% | 49 | 190 | 420 | 3100 | 0.82 | us-east-2 | retrying |
| session-cache | Identity Team | 99.95% | 6 | 14 | 25 | 18800 | 0.03 | us-east-1 | stable |
| feature-flag-proxy | DevEx | 99.90% | 9 | 25 | 56 | 14300 | 0.05 | global | stable |
| incident-timeline | SRE Tooling | 99.00% | 66 | 240 | 610 | 320 | 0.94 | us-west-1 | backfill |
| analytics-ingestor | Data Platform | 99.50% | 36 | 125 | 270 | 6900 | 0.37 | eu-west-1 | recovering |

---

## API and Execution Paths

The backend rollout process combines compile-time safeguards, typed execution plans, and post-deploy verification jobs.

```swift
import Foundation

struct DeploymentStep<T> {
    let name: String
    let transform: (T) throws -> T
}

func executePipeline<T>(
    input: T,
    steps: [DeploymentStep<T>],
    onStep: (String, T) -> Void
) rethrows -> T {
    var current = input
    for step in steps {
        current = try step.transform(current)
        onStep(step.name, current)
    }
    return current
}

let finalPlan = try executePipeline(input: ["canary", "regional"], steps: []) { name, state in
    print("step=\\(name) state=\\(state)")
}
```

```rust
use std::collections::HashMap;

#[derive(Debug)]
struct NodeHealth {
    region: String,
    latency_ms: u32,
    error_rate: f32,
}

impl NodeHealth {
    fn classify(&self) -> &'static str {
        match (self.latency_ms, self.error_rate) {
            (0..=120, r) if r < 0.2 => "healthy",
            (121..=250, r) if r < 0.7 => "watch",
            _ => "critical",
        }
    }
}

fn summarize(nodes: Vec<NodeHealth>) -> HashMap<String, usize> {
    let mut counts = HashMap::new();
    for n in nodes {
        *counts.entry(n.classify().to_string()).or_insert(0) += 1;
    }
    counts
}
```

```json
{
  "deployment": {
    "id": "dep-2026-06-17-1420",
    "strategy": "canary_then_regional",
    "windows": [
      { "region": "us-east-1", "start": "14:20", "durationMin": 30 },
      { "region": "eu-west-1", "start": "15:10", "durationMin": 40 }
    ],
    "guards": {
      "maxErrorRate": 0.5,
      "maxP99Ms": 280,
      "rollbackOn": ["auth_failure_spike", "db_replica_lag"]
    }
  }
}
```

```sql
WITH error_spikes AS (
    SELECT service_name, minute_bucket, error_rate
    FROM svc_minute_metrics
    WHERE minute_bucket >= NOW() - INTERVAL '30 minutes'
      AND error_rate > 0.5
),
candidate_rollbacks AS (
    SELECT d.deploy_id, d.service_name, d.region
    FROM deployments d
    JOIN error_spikes e ON e.service_name = d.service_name
    WHERE d.started_at >= NOW() - INTERVAL '2 hours'
)
SELECT c.deploy_id, c.service_name, c.region
FROM candidate_rollbacks c
WHERE EXISTS (
    SELECT 1 FROM incident_flags f
    WHERE f.service_name = c.service_name
      AND f.flag_type IN ('auth_failure_spike', 'db_replica_lag')
);
```

### Deeply Nested Incident Narrative

> Level 1 summary: **customer impact** was visible in dashboard aggregates and _support ticket velocity_.
>
> > Level 2 analysis: service mesh retries hid early symptoms, but `token.refresh` saturation was measurable.
> >
> > > Level 3 root signal: auth node `use1-auth-04` entered a hot loop after malformed issuer list refresh.
> > >
> > > ```bash
> > > kubectl -n identity get pods -l app=auth-service
> > > kubectl -n identity logs deploy/auth-service --since=20m
> > > kubectl -n identity describe configmap issuer-list
> > > ```
> > >
> > > | Symptom | Before | During |
> > > |---------|--------|--------|
> > > | refresh p99 | 102ms | 711ms |
> > > | token errors | 0.08% | 3.40% |
> > > | retries/request | 1.1 | 4.9 |
> > >
> > > - **Escalation path:** notify SRE primary and identity lead.
> > > - _Mitigation path:_ pin issuer bundle to previous signed revision.
> > > - **_Validation:_** compare canary and baseline using `auth_token_refresh_latency_p99`.

#### Complex Work Plan Lists

1. Prepare cross-region release checklist for baseline migration.
   This paragraph records assumptions about data shape, feature flags, and runtime contracts.
   1. Validate upstream schema compatibility for event consumers.
      This level confirms consumer lag and compatibility gates.
      1. Execute preflight verifier and attach output for audit trail.
         ```bash
         ./bin/preflight --env prod --service billing-core --check schema
         ./bin/preflight --env prod --service billing-core --check permissions
         ```
      2. Review dependency matrix and identify unknown ownership.
         | Dependency | Owner | Action |
         |------------|-------|--------|
         | tax-engine | FinOps | align contract version |
         | invoice-store | Data | verify rollback snapshot |
   2. Coordinate batch migration windows with support and compliance.
      This level captures policy constraints and user communication windows.
      1. Generate customer-facing maintenance note and internal routing plan.
         ```json
         {
           "noticeWindow": "2026-06-18T02:00:00Z",
           "channels": ["status-page", "email", "support-chat"],
           "impact": "intermittent invoice generation delays"
         }
         ```
      2. Build exception list for contractual no-downtime accounts.
         | Account Tier | Constraint | Contact |
         |--------------|------------|---------|
         | Enterprise Platinum | no delay > 30s | csm-platinum@corp |
         | Public Sector | change freeze window | gov-success@corp |
   > Governance reminder: all migrations must include rollback proof and retention verification.
2. Execute phased rollout with hardened observability.
   This paragraph tracks progress markers for each phase and fallback criteria.
   - Canary phase includes synthetic load plus selected production tenants.
     1. Observe canary for 20 minutes with error budget guardrails.
     2. Promote if p99 and error rate remain below thresholds.
   - Regional phase applies weighted routing by stable cohort size.
     1. Expand to 25%, 50%, and 100% traffic in sequence.
     2. Hold for 10 minutes between steps and verify queue depth.
3. Finalize post-release audit and learning backlog.
   > Post-release retro must include architecture, operations, and support stakeholders.
   > Add one action that improves change safety and one that improves diagnosis speed.

1. Mixed nesting validation entry point
   - Region runbook references and operator notes
     1. Ordered remediation sequence for cache divergence
     2. Ordered remediation sequence for stale token grants
   - Region-specific toggles
     1. us-east-1 toggle state matrix
     2. eu-west-1 toggle state matrix
   - Escalation channels
     1. Pager rotation and backup owner
     2. Incident commander handoff checklist

- [x] Confirm migration plan includes **customer impact** statement
- [ ] Verify `feature.payment_retry_v2` default state in all regions
- [x] Archive previous runbooks with change control links
- [ ] Trigger dry-run of rollback automation with _synthetic events_
- [ ] Validate dashboards include `queue.backlog.seconds` and **P99**

##### Images and Inline Rendering

![Architecture Overview](https://via.placeholder.com/800x400.png)

The incident brief links an inline diagram ![Inline Sequence](https://via.placeholder.com/800x400.png) and references **rollback SLA**, _operator runbook_, `incident.timeline`, and ~~deprecated webhook path~~ in one paragraph.

> Evidence packet contains screenshot:
>
> ![Quote Embedded Screenshot](https://via.placeholder.com/800x400.png)

| Artifact | Preview | Notes |
|----------|---------|-------|
| dashboard | ![Dashboard Thumbnail](https://via.placeholder.com/800x400.png) | Captured at 14:42 UTC after rollback |
| queue-depth | ![Queue Snapshot](https://via.placeholder.com/800x400.png) | Shows backlog recovery trajectory |

1. Deployment evidence bundle
   ![List Item Evidence](https://via.placeholder.com/800x400.png)
   Includes links to [timeline](https://status.example.com/incidents/2026-06-17), **metrics dump**, and `build-4821` notes.
2. Compliance evidence bundle
   ![Compliance Packet](https://via.placeholder.com/800x400.png)
   Includes signed approvals, _risk acceptance_, and ~~legacy PDF export~~ migration plan.

###### Stress Pattern Matrix and Edge Cases

1. Nested container stress case
   > Table in quote nested inside list item:
   >
   > | Check | Result | Comment |
   > |-------|--------|---------|
   > | parse depth | pass | renderer handled nested blocks |
   > | layout width | pass | table compressed at narrow width |
   > | reuse hit-rate | watch | warm pool below expected p50 |

2. Quote containing list containing code block
   > - Streaming inspection checkpoints
   >   - validate chunk boundaries around fenced code
   >   - validate quote prefix retention during incremental updates
   >   - sample parser state transitions:
   >
   >     ```swift
   >     let chunks = makeStreamingChunks(from: doc, chunkSize: 35)
   >     for c in chunks {
   >         let ast = renderer.parse(c)
   >         let state = CodeBlockAnalyzer.analyze(c)
   >         _ = renderer.render(ast, attachmentPool: pool, codeBlockState: state, isStreaming: true)
   >     }
   >     ```

3. Long single-line cell stress table

| ID | LongText | Expected |
|----|----------|----------|
| LT-1 | This single line intentionally concatenates service contracts, ownership metadata, and incident tags to force wide measurement without natural wrap opportunities in baseline rendering path alpha-beta-gamma-delta-epsilon-zeta-theta-iota-kappa-lambda. | should wrap or scroll without clipping |
| LT-2 | This single line intentionally includes serialized payload style text {"service":"webhook-dispatcher","region":"us-east-2","retryPolicy":"exp-backoff-7","budget":"strict"} to stress intrinsic sizing and row height reconciliation in table layout pass. | should preserve row stability across frames |
| LT-3 | This single line intentionally mixes URLs https://ops.example.com/a/b/c/d/e/f and inline tokens api.gateway.route.validation.mode=strict while keeping no manual line breaks for difficult text measurement. | should avoid runaway layout time |

---
---
---

```python
def summarize_incident(services):
    unhealthy = [s for s in services if s["errorRate"] > 0.5]
    return {
        "total": len(services),
        "unhealthy": len(unhealthy),
        "regions": sorted({s["region"] for s in services}),
    }
```

```yaml
release:
  id: rel-2026-06-17
  policy: guarded
  approvals:
    - sre-primary
    - product-owner
    - compliance
  rollback:
    trigger:
      maxErrorRate: 0.5
      maxP99Ms: 300
```

Operational chronology for baseline realism:
- 14:20 UTC rollout started in us-east-1 with 5% canary routing.
- 14:24 UTC cache miss spike appeared on auth-service and recommendation-api.
- 14:27 UTC SRE engaged incident commander and froze regional promotions.
- 14:31 UTC issuer list rollback executed with signed artifact pin.
- 14:35 UTC p99 latency dropped below 220ms for auth token refresh.
- 14:42 UTC queue backlog normalized for webhook-dispatcher workers.
- 14:46 UTC customer-facing status updated with mitigation details.
- 14:55 UTC read-only audit export completed for compliance review.
- 15:10 UTC post-incident patch drafted with additional schema guards.
- 15:30 UTC retro scheduled with platform, identity, and support leads.

Extended architecture notes:
- API gateway uses weighted routing and per-tenant policy filters.
- Identity service signs access tokens with regional key rotation.
- Billing and ledger systems share immutable event contracts.
- Recommendation service reads from feature store snapshots.
- Notification router maintains multi-channel fanout queues.
- Analytics ingestor batches events with lossless retry semantics.
- Audit stream remains append-only and encrypted at rest.

Postmortem action matrix:
| Action | Team | Due Date | Type |
|--------|------|----------|------|
| add issuer checksum verification | Identity | 2026-06-20 | prevention |
| add queue age alert in incident dashboard | Messaging | 2026-06-21 | detection |
| add retry jitter cap for webhook dispatcher | Integrations | 2026-06-22 | mitigation |
| add schema drift gate in CI | DevEx | 2026-06-24 | prevention |
| add rollback dry-run in weekly game day | SRE | 2026-06-25 | readiness |

Final verification checklist:
- Ensure all dashboards include links to source metrics and alert definitions.
- Ensure all runbooks list owner, escalation policy, and rollback command.
- Ensure all release notes include customer impact and support contact path.
- Ensure all automated checks run in staging and production shadow mode.
- Ensure all postmortem actions map to measurable reliability outcomes.
"""

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - StreamingPerformanceTests
// ─────────────────────────────────────────────────────────────────────────────

@MainActor
final class StreamingPerformanceTests: XCTestCase {

    private var sut: MarkdownView!
    private var hostWindow: UIWindow!
    private let renderWidth: CGFloat = 342

    override func setUp() {
        super.setUp()
        hostWindow = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        sut = MarkdownView(theme: makeTestTheme())
        sut.frame = CGRect(x: 0, y: 0, width: renderWidth, height: 800)
        sut.preferredMaxLayoutWidth = renderWidth
        sut.isScrollEnabled = false
        hostWindow.addSubview(sut)
        hostWindow.makeKeyAndVisible()
        // Let the window settle before benchmarking.
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
    }

    override func tearDown() {
        sut.cleanUp()
        sut = nil
        hostWindow = nil
        super.tearDown()
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: End-to-End Streaming Frame Time
    // ─────────────────────────────────────────────────────────────────────────
    // Each test simulates a complete streaming session by delivering
    // `chunkSize`-character incremental prefixes of the fixture document.
    // Setting `markdown =` synchronously calls renderIfReady() → render(),
    // followed by layoutIfNeeded() to force the full layout pass (I8).
    //
    // XCTest runs each measure {} block 10× by default and stores the average
    // as the new baseline. Subsequent runs are compared against it.

    /// Baseline: plain text only, no attachment views.
    /// Expected: fast (sub-5ms/frame) — serves as the lower bound.
    func testStreamingFrameTime_PlainText() {
        let chunks = makeStreamingChunks(from: kPlainDocument, chunkSize: 20)
        measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
            for chunk in chunks {
                sut.markdown = chunk
                sut.layoutIfNeeded()
            }
            sut.markdown = "" // reset between measure iterations
        }
    }

    /// Code-block heavy document — two fenced code blocks.
    /// Key bottlenecks: I5 (re-parse), I14 (code block size fitting), I22 (fence scan).
    func testStreamingFrameTime_CodeBlockDocument() {
        let chunks = makeStreamingChunks(from: kCodeDocument, chunkSize: 25)
        let options = XCTMeasureOptions()
        options.iterationCount = 5 // heavier test — 5 iterations is sufficient
        measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()], options: options) {
            for chunk in chunks {
                sut.markdown = chunk
                sut.layoutIfNeeded()
            }
            sut.markdown = ""
        }
    }

    func testStreamingFrameTime_RichDocument() {
        let chunks = makeStreamingChunks(from: kRichDocument, chunkSize: 25)
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()], options: options) {
            for chunk in chunks {
                sut.markdown = chunk
                sut.layoutIfNeeded()
            }
            sut.markdown = ""
        }
    }

    /// 10×10 table — exercises MarkdownTableView adaptive layout at scale.
    func testStreamingFrameTime_LargeTableDocument() {
        let chunks = makeStreamingChunks(from: kLargeTableDocument, chunkSize: 30)
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()], options: options) {
            for chunk in chunks {
                sut.markdown = chunk
                sut.layoutIfNeeded()
            }
            sut.markdown = ""
        }
    }

    /// 3-level nested quotes + lists with code blocks and tables inside.
    func testStreamingFrameTime_DeepNestDocument() {
        let chunks = makeStreamingChunks(from: kDeepNestDocument, chunkSize: 30)
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()], options: options) {
            for chunk in chunks {
                sut.markdown = chunk
                sut.layoutIfNeeded()
            }
            sut.markdown = ""
        }
    }

    /// Every element type in one document — maximum diversity.
    func testStreamingFrameTime_MixedContentDocument() {
        let chunks = makeStreamingChunks(from: kMixedContentDocument, chunkSize: 30)
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()], options: options) {
            for chunk in chunks {
                sut.markdown = chunk
                sut.layoutIfNeeded()
            }
            sut.markdown = ""
        }
    }

    /// Ultimate stress test: ~200 lines, multiple large tables, nested quotes,
    /// code blocks, images, lists. Represents worst-case real-world AI output.
    func testStreamingFrameTime_FullComplexDocument() {
        let chunks = makeStreamingChunks(from: kFullComplexDocument, chunkSize: 30)
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()], options: options) {
            for chunk in chunks {
                sut.markdown = chunk
                sut.layoutIfNeeded()
            }
            sut.markdown = ""
        }
    }

    func testStreamingFrameTime_QuoteHeavyDocument() {
        let chunks = makeStreamingChunks(from: kQuoteHeavyDocument, chunkSize: 28)
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()], options: options) {
            for chunk in chunks {
                sut.markdown = chunk
                sut.layoutIfNeeded()
            }
            sut.markdown = ""
        }
    }

    /// Simulates a long AI conversation: kFullComplexDocument repeated 3×.
    /// Tests pool eviction under sustained streaming with high attachment count.
    func testStreamingFrameTime_ExtendedSession() {
        let extendedDoc = [kFullComplexDocument, kMixedContentDocument, kDeepNestDocument]
            .joined(separator: "\n\n---\n\n")
        let chunks = makeStreamingChunks(from: extendedDoc, chunkSize: 40)
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()], options: options) {
            for chunk in chunks {
                sut.markdown = chunk
                sut.layoutIfNeeded()
            }
            sut.markdown = ""
        }
    }

    func testStreamingFrameTime_ComprehensiveBaseline() {
        let chunks = makeStreamingChunks(from: kComprehensiveBaselineDocument, chunkSize: 35)
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()], options: options) {
            for chunk in chunks {
                sut.markdown = chunk
                sut.layoutIfNeeded()
            }
            sut.markdown = ""
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Per-Frame Timing Distribution (P50 / P95 / P99)
    // ─────────────────────────────────────────────────────────────────────────
    // XCTest measure() reports only the average. These tests manually collect
    // per-frame wall-clock times and attach a distribution report to the test
    // result bundle (lifetime=keepAlways → survives between runs for comparison).
    //
    // These are NOT pass/fail tests. Run before and after optimization, then
    // compare the attached reports in Xcode's test result viewer.

    func testFrameTimingDistribution_PlainText() {
        let chunks = makeStreamingChunks(from: kPlainDocument, chunkSize: 20)
        let report = collectFrameTimingReport(chunks: chunks, label: "PlainText")
        attachReport(report, name: "FrameTimingDistribution_PlainText")
    }

    func testFrameTimingDistribution_CodeBlockDocument() {
        let chunks = makeStreamingChunks(from: kCodeDocument, chunkSize: 25)
        let report = collectFrameTimingReport(chunks: chunks, label: "CodeBlockDocument")
        attachReport(report, name: "FrameTimingDistribution_CodeBlockDocument")
    }

    func testFrameTimingDistribution_RichDocument() {
        let chunks = makeStreamingChunks(from: kRichDocument, chunkSize: 25)
        let report = collectFrameTimingReport(chunks: chunks, label: "RichDocument")
        attachReport(report, name: "FrameTimingDistribution_RichDocument")
    }

    func testFrameTimingDistribution_LargeTableDocument() {
        let chunks = makeStreamingChunks(from: kLargeTableDocument, chunkSize: 30)
        let report = collectFrameTimingReport(chunks: chunks, label: "LargeTableDocument")
        attachReport(report, name: "FrameTimingDistribution_LargeTableDocument")
    }

    func testFrameTimingDistribution_DeepNestDocument() {
        let chunks = makeStreamingChunks(from: kDeepNestDocument, chunkSize: 30)
        let report = collectFrameTimingReport(chunks: chunks, label: "DeepNestDocument")
        attachReport(report, name: "FrameTimingDistribution_DeepNestDocument")
    }

    func testFrameTimingDistribution_MixedContentDocument() {
        let chunks = makeStreamingChunks(from: kMixedContentDocument, chunkSize: 30)
        let report = collectFrameTimingReport(chunks: chunks, label: "MixedContentDocument")
        attachReport(report, name: "FrameTimingDistribution_MixedContentDocument")
    }

    func testFrameTimingDistribution_FullComplexDocument() {
        let chunks = makeStreamingChunks(from: kFullComplexDocument, chunkSize: 30)
        let report = collectFrameTimingReport(chunks: chunks, label: "FullComplexDocument")
        attachReport(report, name: "FrameTimingDistribution_FullComplexDocument")
    }

    func testFrameTimingDistribution_QuoteHeavyDocument() {
        let chunks = makeStreamingChunks(from: kQuoteHeavyDocument, chunkSize: 28)
        let report = collectFrameTimingReport(chunks: chunks, label: "QuoteHeavyDocument")
        attachReport(report, name: "FrameTimingDistribution_QuoteHeavyDocument")
    }

    func testFrameTimingDistribution_ComprehensiveBaseline() {
        let chunks = makeStreamingChunks(from: kComprehensiveBaselineDocument, chunkSize: 35)
        let report = collectFrameTimingReport(chunks: chunks, label: "ComprehensiveBaseline")
        attachReport(report, name: "FrameTimingDistribution_ComprehensiveBaseline")
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Machine-Readable Performance Summary (Wave 0)
    // ─────────────────────────────────────────────────────────────────────────
    // grep "PERF_JSON_BEGIN" / "PERF_JSON_END" in test output to extract JSON.

    func testStreamingPerformanceSummary_JSON() {
        let documents: [(label: String, content: String, chunkSize: Int)] = [
            ("PlainText", kPlainDocument, 20),
            ("CodeBlock", kCodeDocument, 25),
            ("RichDocument", kRichDocument, 25),
            ("LargeTable", kLargeTableDocument, 30),
            ("DeepNest", kDeepNestDocument, 30),
            ("MixedContent", kMixedContentDocument, 30),
            ("FullComplex", kFullComplexDocument, 30),
            ("QuoteHeavy", kQuoteHeavyDocument, 28),
            ("ComprehensiveBaseline", kComprehensiveBaselineDocument, 35),
        ]

        var results: [DocumentTimingResult] = []
        for doc in documents {
            let chunks = makeStreamingChunks(from: doc.content, chunkSize: doc.chunkSize)
            let frameTimes = collectFrameTimingData(chunks: chunks)
            results.append(makeTimingResult(label: doc.label, frameTimes: frameTimes))
        }

        let json = encodePerformanceSummary(results: results)

        print("PERF_JSON_BEGIN")
        print(json)
        print("PERF_JSON_END")

        attachReport(json, name: "PerformanceSummary_JSON")

        for result in results where result.p99_ms > PerfThreshold.targetP99ms {
            print("⚠️  \(result.document) P99 (\(String(format: "%.1f", result.p99_ms))ms) exceeds 60fps budget (\(PerfThreshold.targetP99ms)ms)")
        }
    }

    func testStreamingPerformanceComparison() {
        let baselinePath = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .appendingPathComponent("performance_baseline.json")
            .path

        let documents: [(label: String, content: String, chunkSize: Int)] = [
            ("PlainText", kPlainDocument, 20),
            ("CodeBlock", kCodeDocument, 25),
            ("RichDocument", kRichDocument, 25),
            ("LargeTable", kLargeTableDocument, 30),
            ("DeepNest", kDeepNestDocument, 30),
            ("MixedContent", kMixedContentDocument, 30),
            ("FullComplex", kFullComplexDocument, 30),
            ("QuoteHeavy", kQuoteHeavyDocument, 28),
            ("ComprehensiveBaseline", kComprehensiveBaselineDocument, 35),
        ]

        var results: [DocumentTimingResult] = []
        for doc in documents {
            let chunks = makeStreamingChunks(from: doc.content, chunkSize: doc.chunkSize)
            let frameTimes = collectFrameTimingData(chunks: chunks)
            results.append(makeTimingResult(label: doc.label, frameTimes: frameTimes))
        }

        let comparison = compareWithBaseline(results, baselinePath: baselinePath)
        print(comparison)
        attachReport(comparison, name: "PerformanceComparison")
    }

    func testStreamingObservabilityToggleComparison_FullComplexDocument() {
        let chunks = makeStreamingChunks(from: kFullComplexDocument, chunkSize: 30)

        let disabledRun = collectFrameTimingData(chunks: chunks, statsEnabled: false)
        let enabledRun = collectFrameTimingData(chunks: chunks, statsEnabled: true)

        let disabledResult = makeTimingResult(label: "StatsDisabled", frameTimes: disabledRun.frameTimes)
        let enabledResult = makeTimingResult(label: "StatsEnabled", frameTimes: enabledRun.frameTimes)

        let avgDeltaPct = disabledResult.avg_ms > 0
            ? ((enabledResult.avg_ms - disabledResult.avg_ms) / disabledResult.avg_ms) * 100
            : 0
        let p99DeltaPct = disabledResult.p99_ms > 0
            ? ((enabledResult.p99_ms - disabledResult.p99_ms) / disabledResult.p99_ms) * 100
            : 0

        let report = buildObservabilityToggleReport(
            disabledResult: disabledResult,
            enabledResult: enabledResult,
            disabledStats: disabledRun.stats,
            enabledStats: enabledRun.stats,
            avgDeltaPct: avgDeltaPct,
            p99DeltaPct: p99DeltaPct
        )

        print(report)
        attachReport(report, name: "StreamingObservabilityToggleComparison_FullComplex")

        XCTAssertEqual(disabledRun.stats.markdownAssignments, 0)
        XCTAssertEqual(disabledRun.stats.streamingSchedules, 0)
        XCTAssertEqual(disabledRun.stats.throttledExecutes, 0)
        XCTAssertEqual(disabledRun.stats.renderCalls, 0)
        XCTAssertEqual(disabledRun.stats.renderSkips, 0)

        XCTAssertGreaterThan(enabledRun.stats.markdownAssignments, 0)
        XCTAssertGreaterThan(enabledRun.stats.streamingSchedules, 0)
        XCTAssertGreaterThan(enabledRun.stats.throttledExecutes, 0)
        XCTAssertGreaterThan(enabledRun.stats.renderCalls, 0)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Streaming First-Frame Latency (Bottleneck I4)
    // ─────────────────────────────────────────────────────────────────────────
    // Measures the wall-clock delay between setting `isStreaming=true` and
    // setting the first `markdown` value until the first render appears in
    // the UI. Current throttle implementation has no leading-edge fire —
    // the first frame is always delayed by `throttleInterval` (default 100ms).
    //
    // After I4 fix (leading-edge fire), this should read ~0ms instead of ~100ms.

    func testStreamingFirstFrameLatency() {
        sut.isStreaming = true
        sut.throttleInterval = 0.1 // production default

        let expectFirstRender = expectation(description: "first frame rendered")
        expectFirstRender.assertForOverFulfill = false

        let startTime = CACurrentMediaTime()
        var firstRenderLatency: TimeInterval = 0

        sut.markdown = "Hello, streaming world"

        // Poll at 2ms intervals until text appears in the view.
        let pollTimer = Timer.scheduledTimer(withTimeInterval: 0.002, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            if self.sut.attributedText?.length ?? 0 > 0 {
                firstRenderLatency = CACurrentMediaTime() - startTime
                timer.invalidate()
                expectFirstRender.fulfill()
            }
        }
        RunLoop.main.add(pollTimer, forMode: .common)
        wait(for: [expectFirstRender], timeout: 1.0)

        let report = String(format: """
        ┌─────────────────────────────────────────────
        │ Streaming First-Frame Latency
        ├─────────────────────────────────────────────
        │ throttleInterval : 100 ms
        │ first render at  : %.1f ms
        │ expected after fix (leading-edge): ~0 ms
        └─────────────────────────────────────────────
        """, firstRenderLatency * 1000)
        print(report)
        attachReport(report, name: "StreamingFirstFrameLatency")

        sut.isStreaming = false
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Component Micro-benchmarks
    // ─────────────────────────────────────────────────────────────────────────
    // These isolate individual bottlenecks by calling internal components
    // directly. They are fast enough for 10 default iterations.

    // ── I5: AST Parse Cost ────────────────────────────────────────────────────
    // Document(parsing:) is the most expensive single operation per frame.
    // Bottleneck: called on every streaming tick because cachedDocument is
    // always cleared before render(). After I5 fix, only called when structural
    // block-level content changes.

    func testASTParseTime_PlainDocument() {
        let renderer = MarkdownRenderer(
            theme: makeTestTheme(),
            maxLayoutWidth: renderWidth,
            tableSizeCache: TableCellSizeCache()
        )
        measure(metrics: [XCTClockMetric()]) {
            _ = renderer.parse(kPlainDocument)
        }
    }

    func testASTParseTime_RichDocument() {
        let renderer = MarkdownRenderer(
            theme: makeTestTheme(),
            maxLayoutWidth: renderWidth,
            tableSizeCache: TableCellSizeCache()
        )
        measure(metrics: [XCTClockMetric()]) {
            _ = renderer.parse(kRichDocument)
        }
    }

    func testASTParseTime_LargeTableDocument() {
        let renderer = MarkdownRenderer(
            theme: makeTestTheme(),
            maxLayoutWidth: renderWidth,
            tableSizeCache: TableCellSizeCache()
        )
        measure(metrics: [XCTClockMetric()]) {
            _ = renderer.parse(kLargeTableDocument)
        }
    }

    func testASTParseTime_DeepNestDocument() {
        let renderer = MarkdownRenderer(
            theme: makeTestTheme(),
            maxLayoutWidth: renderWidth,
            tableSizeCache: TableCellSizeCache()
        )
        measure(metrics: [XCTClockMetric()]) {
            _ = renderer.parse(kDeepNestDocument)
        }
    }

    func testASTParseTime_FullComplexDocument() {
        let renderer = MarkdownRenderer(
            theme: makeTestTheme(),
            maxLayoutWidth: renderWidth,
            tableSizeCache: TableCellSizeCache()
        )
        measure(metrics: [XCTClockMetric()]) {
            _ = renderer.parse(kFullComplexDocument)
        }
    }

    func testASTParseTime_ComprehensiveBaseline() {
        let renderer = MarkdownRenderer(
            theme: makeTestTheme(),
            maxLayoutWidth: renderWidth,
            tableSizeCache: TableCellSizeCache()
        )
        measure(metrics: [XCTClockMetric()]) {
            _ = renderer.parse(kComprehensiveBaselineDocument)
        }
    }

    // ── Non-Streaming Table Benchmark (Wave 2) ──────────────────────────────
    // Renders kLargeTableDocument repeatedly at the same width to measure
    // O1 (layout cache) and O3 (cell parse cache) effectiveness.
    // Renders 2-N should benefit from cache hits if caches are working.

    func testNonStreamingTableLayout_CacheEffectiveness() {
        let repeatCount = 50
        var frameTimes: [Double] = []
        frameTimes.reserveCapacity(repeatCount)

        for _ in 0..<repeatCount {
            sut.markdown = ""
            sut.layoutIfNeeded()

            let t0 = CACurrentMediaTime()
            sut.markdown = kLargeTableDocument
            sut.layoutIfNeeded()
            frameTimes.append(CACurrentMediaTime() - t0)
        }

        let cold = frameTimes[0]
        let warm = frameTimes.dropFirst().sorted()
        let warmP50 = warm[warm.count / 2]
        let warmP95 = warm[max(0, min(Int(Double(warm.count) * 0.95), warm.count - 1))]

        let speedup = ((cold - warmP50) / cold) * 100
        let report = """
        ┌─ Non-Streaming Table Cache Effectiveness ──────────
        │ Cold render (1st):      \(String(format: "%.3f", cold * 1000))ms
        │ Warm P50 (renders 2-N): \(String(format: "%.3f", warmP50 * 1000))ms
        │ Warm P95 (renders 2-N): \(String(format: "%.3f", warmP95 * 1000))ms
        │ Speedup (cold→warm):    \(String(format: "%.1f", speedup))%
        │ Renders: \(repeatCount)
        └─────────────────────────────────────────────────────
        """
        print(report)
        attachReport(report, name: "NonStreamingTableCacheEffectiveness")
    }

    func testNonStreamingTableLayout_FullComplex_CacheEffectiveness() {
        let repeatCount = 30
        var frameTimes: [Double] = []
        frameTimes.reserveCapacity(repeatCount)

        for _ in 0..<repeatCount {
            sut.markdown = ""
            sut.layoutIfNeeded()

            let t0 = CACurrentMediaTime()
            sut.markdown = kFullComplexDocument
            sut.layoutIfNeeded()
            frameTimes.append(CACurrentMediaTime() - t0)
        }

        let cold = frameTimes[0]
        let warm = frameTimes.dropFirst().sorted()
        let warmP50 = warm[warm.count / 2]
        let warmP95 = warm[max(0, min(Int(Double(warm.count) * 0.95), warm.count - 1))]

        let speedup = ((cold - warmP50) / cold) * 100
        let report = """
        ┌─ Non-Streaming FullComplex Cache Effectiveness ────
        │ Cold render (1st):      \(String(format: "%.3f", cold * 1000))ms
        │ Warm P50 (renders 2-N): \(String(format: "%.3f", warmP50 * 1000))ms
        │ Warm P95 (renders 2-N): \(String(format: "%.3f", warmP95 * 1000))ms
        │ Speedup (cold→warm):    \(String(format: "%.1f", speedup))%
        │ Renders: \(repeatCount)
        └─────────────────────────────────────────────────────
        """
        print(report)
        attachReport(report, name: "NonStreamingFullComplexCacheEffectiveness")
    }

    func testNonStreamingTableLayout_ComprehensiveBaseline_CacheEffectiveness() {
        let repeatCount = 10
        var frameTimes: [Double] = []

        for _ in 0 ..< repeatCount {
            sut.markdown = ""
            sut.layoutIfNeeded()

            let t0 = CACurrentMediaTime()
            sut.markdown = kComprehensiveBaselineDocument
            sut.layoutIfNeeded()
            frameTimes.append(CACurrentMediaTime() - t0)
        }

        let cold = frameTimes[0]
        let warm = frameTimes.dropFirst().sorted()
        let warmP50 = warm[warm.count / 2]
        let warmP95 = warm[max(0, min(Int(Double(warm.count) * 0.95), warm.count - 1))]

        let speedup = ((cold - warmP50) / cold) * 100
        let report = """
        ┌─ Non-Streaming ComprehensiveBaseline Cache Effectiveness ────
        │ Cold render (1st):      \(String(format: "%.3f", cold * 1000))ms
        │ Warm P50 (renders 2-N): \(String(format: "%.3f", warmP50 * 1000))ms
        │ Warm P95 (renders 2-N): \(String(format: "%.3f", warmP95 * 1000))ms
        │ Speedup (cold→warm):    \(String(format: "%.1f", speedup))%
        │ Renders: \(repeatCount)
        └─────────────────────────────────────────────────────────────────
        """
        print(report)
        attachReport(report, name: "NonStreamingComprehensiveBaselineCacheEffectiveness")
    }

    // ── I22: CodeBlockAnalyzer Fence Scan ────────────────────────────────────
    // Called on every render() regardless of isStreaming value.
    // Splits document into lines and runs state machine — O(lines) per render.
    // After I22 fix, this is gated by `guard isStreaming else { return .empty }`.

    func testCodeBlockAnalyzerTime_RichDocument() {
        measure(metrics: [XCTClockMetric()]) {
            _ = CodeBlockAnalyzer.analyze(kRichDocument)
        }
    }

    func testCodeBlockAnalyzerTime_LargeDocument() {
        let largeDoc = (0..<10).map { _ in kRichDocument }.joined(separator: "\n\n")
        measure(metrics: [XCTClockMetric()]) {
            _ = CodeBlockAnalyzer.analyze(largeDoc)
        }
    }

    func testCodeBlockAnalyzerTime_FullComplexDocument() {
        measure(metrics: [XCTClockMetric()]) {
            _ = CodeBlockAnalyzer.analyze(kFullComplexDocument)
        }
    }

    // ── I43: theme.quoted Allocation Overhead ────────────────────────────────
    // `MarkdownTheme.quoted` is a computed property that allocates a full new
    // MarkdownTheme struct hierarchy on every call (6+ new structs including
    // UIColor.withAlphaComponent). Called N times per blockquote per frame.
    // After I43 fix, this returns a pre-computed cached value.

    func testThemeQuotedAllocationOverhead() {
        let theme = makeTestTheme()
        // 500 accesses simulates ~5 frames × 100 parser traversals with nested quotes.
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            for _ in 0..<500 {
                _ = theme.quoted
            }
        }
    }

    // ── I14/I15: Attachment Size Fitting ────────────────────────────────────
    // systemLayoutSizeFitting() is called for EVERY code block and quote on
    // EVERY streaming frame, even when pool returns an exact-match view.
    // After fix: cached (contentKey → CGSize) so pool hits skip re-fitting.

    func testCodeBlockSizeFitting_Isolated() {
        let theme = makeTestTheme()
        let targetSize = CGSize(width: renderWidth, height: UIView.layoutFittingCompressedSize.height)
        measure(metrics: [XCTClockMetric()]) {
            // 20 iterations simulate 20 streaming frames each with one code block.
            for _ in 0..<20 {
                let view = CodeBlockView(
                    code: "def hello():\n    print('world')\n    return 42",
                    language: "python",
                    theme: theme
                )
                _ = view.systemLayoutSizeFitting(
                    targetSize,
                    withHorizontalFittingPriority: .required,
                    verticalFittingPriority: .fittingSizeLevel
                )
            }
        }
    }

    func testQuoteViewSizeFitting_Isolated() {
        let theme = makeTestTheme()
        let targetSize = CGSize(width: renderWidth, height: UIView.layoutFittingCompressedSize.height)
        let quoteText = NSAttributedString(
            string: "Important: These benchmarks were recorded on production hardware. Results may vary.",
            attributes: [.font: UIFont.systemFont(ofSize: 14)]
        )
        measure(metrics: [XCTClockMetric()]) {
            for _ in 0..<20 {
                let view = QuoteView(
                    attributedText: quoteText,
                    attachments: [:],
                    theme: theme
                )
                view.preferredMaxLayoutWidth = renderWidth
                _ = view.systemLayoutSizeFitting(
                    targetSize,
                    withHorizontalFittingPriority: .required,
                    verticalFittingPriority: .fittingSizeLevel
                )
            }
        }
    }

    // ── Full Renderer Round-trip ─────────────────────────────────────────────
    // Measures combined parse + render (attributedString build + attachment
    // creation + systemLayoutSizeFitting for all blocks).
    // Two variants: cold pool (no reuse available) vs warm pool (pool pre-warmed).

    func testRendererRoundTrip_ColdPool_RichDocument() {
        // Cold: fresh pool each iteration — no attachment reuse.
        measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
            let renderer = MarkdownRenderer(
                theme: makeTestTheme(),
                maxLayoutWidth: renderWidth,
                tableSizeCache: TableCellSizeCache()
            )
            _ = renderer.render(kRichDocument)
        }
    }

    func testRendererRoundTrip_WarmPool_RichDocument() {
        let pool = AttachmentPool()
        let renderer = MarkdownRenderer(
            theme: makeTestTheme(),
            maxLayoutWidth: renderWidth,
            tableSizeCache: TableCellSizeCache()
        )
        let doc = renderer.parse(kRichDocument)
        let state = CodeBlockAnalyzer.analyze(kRichDocument)
        _ = renderer.render(doc, attachmentPool: pool, codeBlockState: state, isStreaming: true)

        measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
            let freshDoc = renderer.parse(kRichDocument)
            _ = renderer.render(freshDoc, attachmentPool: pool, codeBlockState: state, isStreaming: true)
        }
    }

    func testRendererRoundTrip_WarmPool_FullComplexDocument() {
        let pool = AttachmentPool()
        let renderer = MarkdownRenderer(
            theme: makeTestTheme(),
            maxLayoutWidth: renderWidth,
            tableSizeCache: TableCellSizeCache()
        )
        let doc = renderer.parse(kFullComplexDocument)
        let state = CodeBlockAnalyzer.analyze(kFullComplexDocument)
        _ = renderer.render(doc, attachmentPool: pool, codeBlockState: state, isStreaming: true)

        measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
            let freshDoc = renderer.parse(kFullComplexDocument)
            _ = renderer.render(freshDoc, attachmentPool: pool, codeBlockState: state, isStreaming: true)
        }
    }

    func testRendererRoundTrip_WarmPool_ComprehensiveBaseline() {
        let pool = AttachmentPool()
        let renderer = MarkdownRenderer(
            theme: makeTestTheme(),
            maxLayoutWidth: renderWidth,
            tableSizeCache: TableCellSizeCache()
        )
        let doc = renderer.parse(kComprehensiveBaselineDocument)
        let state = CodeBlockAnalyzer.analyze(kComprehensiveBaselineDocument)
        _ = renderer.render(doc, attachmentPool: pool, codeBlockState: state, isStreaming: true)

        measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
            let freshDoc = renderer.parse(kComprehensiveBaselineDocument)
            _ = renderer.render(freshDoc, attachmentPool: pool, codeBlockState: state, isStreaming: true)
        }
    }

    // ── I9/I10: AttachmentPool LRU Operations ───────────────────────────────
    // recycle() calls evictIfNeeded() (O(n) scan) and uses Array.firstIndex
    // (O(n)) for LRU tracking. After fix: O(1) dictionary-backed tracking +
    // lazy eviction gated by count check.

    func testAttachmentPoolRecycleDequeue_SmallPool() {
        // 10-entry pool — simulates typical streaming document with 10 attachments.
        let pool = AttachmentPool()
        let keys = (0..<10).map { TestContentKey(id: "view-\($0)") }
        // Pre-fill the pool.
        for key in keys {
            pool.recycle(UIView(), key: key, isStreaming: false)
        }
        let targetKey = TestContentKey(id: "view-5")
        measure(metrics: [XCTClockMetric()]) {
            for _ in 0..<500 {
                let v = UIView()
                pool.recycle(v, key: targetKey, isStreaming: false)
                _ = pool.dequeue(for: targetKey, isStreaming: false) as (view: UIView, exactMatch: Bool)?
            }
        }
    }

    func testAttachmentPoolRecycleDequeue_LargePool() {
        // 80-entry pool — shows O(n) degradation as pool grows.
        let pool = AttachmentPool()
        let keys = (0..<80).map { TestContentKey(id: "view-\($0)") }
        for key in keys {
            pool.recycle(UIView(), key: key, isStreaming: false)
        }
        let targetKey = TestContentKey(id: "view-40")
        measure(metrics: [XCTClockMetric()]) {
            for _ in 0..<500 {
                let v = UIView()
                pool.recycle(v, key: targetKey, isStreaming: false)
                _ = pool.dequeue(for: targetKey, isStreaming: false) as (view: UIView, exactMatch: Bool)?
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Pool Stats Report (Informational)
    // ─────────────────────────────────────────────────────────────────────────
    // Runs a complete streaming session through MarkdownRenderer + AttachmentPool
    // directly, then dumps pool hit-rate stats as a test attachment.
    // Run before/after optimization to see reuse rate improvement.

    func testPoolHitRateDuringStreamingSession_RichDocument() {
        let pool = AttachmentPool()
        let renderer = MarkdownRenderer(
            theme: makeTestTheme(),
            maxLayoutWidth: renderWidth,
            tableSizeCache: TableCellSizeCache()
        )
        let chunks = makeStreamingChunks(from: kRichDocument, chunkSize: 25)
        for chunk in chunks {
            let doc = renderer.parse(chunk)
            let state = CodeBlockAnalyzer.analyze(chunk)
            _ = renderer.render(doc, attachmentPool: pool, codeBlockState: state, isStreaming: true)
        }
        pool.logStats(context: "RichDocument streaming — \(chunks.count) frames")

        let attachment = XCTAttachment(
            string: "Pool stats logged to console. Session: \(chunks.count) frames of RichDocument."
        )
        attachment.name = "PoolStats_RichDocumentStreaming"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Frame Budget Overrun Tests

    func testFrameBudgetReport_AllUnderBudget() {
        let frameTimes = [0.005, 0.008, 0.010, 0.012, 0.015]
        let report = makeFrameBudgetReport(frameTimes: frameTimes)

        XCTAssertEqual(report.totalFrames, 5)
        XCTAssertEqual(report.overBudgetCount, 0)
        XCTAssertEqual(report.overBudgetRatio, 0)
        XCTAssertEqual(report.overBudgetTimeMs, 0)
        XCTAssertEqual(report.severity.mild, 0)
        XCTAssertEqual(report.severity.moderate, 0)
        XCTAssertEqual(report.severity.severe, 0)
    }

    func testFrameBudgetReport_ClassifiesThresholdBoundaries() {
        let budget = PerfThreshold.targetP99ms / 1000.0
        let frameTimes = [
            budget - 0.0001,       // under budget
            budget + 0.0001,       // mild (1x-2x)
            budget * 2 + 0.0001,   // moderate (2x-4x)
            budget * 4 + 0.0001    // severe (>4x)
        ]
        let report = makeFrameBudgetReport(frameTimes: frameTimes)

        XCTAssertEqual(report.totalFrames, 4)
        XCTAssertEqual(report.overBudgetCount, 3)
        XCTAssertEqual(report.overBudgetRatio, 3.0 / 4.0, accuracy: 0.001)
        XCTAssertEqual(report.severity.mild, 1)
        XCTAssertEqual(report.severity.moderate, 1)
        XCTAssertEqual(report.severity.severe, 1)
    }

    func testFrameBudgetReport_SumsOnlyOverBudgetTime() {
        let budgetSec = PerfThreshold.targetP99ms / 1000.0
        let overBy10ms = budgetSec + 0.010
        let overBy50ms = budgetSec + 0.050
        let underBudget = budgetSec - 0.005
        let frameTimes = [underBudget, overBy10ms, underBudget, overBy50ms]
        let report = makeFrameBudgetReport(frameTimes: frameTimes)

        let expectedOverBudgetMs = 10.0 + 50.0
        XCTAssertEqual(report.overBudgetTimeMs, expectedOverBudgetMs, accuracy: 0.5)
        XCTAssertEqual(report.overBudgetCount, 2)
    }

    func testFrameBudgetReport_ZeroInput() {
        let report = makeFrameBudgetReport(frameTimes: [])

        XCTAssertEqual(report.totalFrames, 0)
        XCTAssertEqual(report.overBudgetCount, 0)
        XCTAssertEqual(report.overBudgetRatio, 0)
        XCTAssertEqual(report.overBudgetTimeMs, 0)
        XCTAssertEqual(report.maxFrameTimeMs, 0)
    }

    func testFrameBudgetReport_SeverityDistribution() {
        let budgetSec = PerfThreshold.targetP99ms / 1000.0
        let frameTimes = [
            budgetSec * 1.5,   // mild
            budgetSec * 1.8,   // mild
            budgetSec * 2.5,   // moderate
            budgetSec * 3.0,   // moderate
            budgetSec * 3.9,   // moderate
            budgetSec * 5.0,   // severe
            budgetSec * 10.0   // severe
        ]
        let report = makeFrameBudgetReport(frameTimes: frameTimes)

        XCTAssertEqual(report.severity.mild, 2)
        XCTAssertEqual(report.severity.moderate, 3)
        XCTAssertEqual(report.severity.severe, 2)
        XCTAssertEqual(report.overBudgetCount, 7)
        XCTAssertEqual(report.overBudgetRatio, 1.0, accuracy: 0.001)
    }

    func testPerformanceSummaryJSON_ContainsFrameBudget() {
        let frameTimes = [0.005, 0.020, 0.050]
        let result = makeTimingResult(label: "TestDoc", frameTimes: frameTimes)

        XCTAssertEqual(result.frameBudget.totalFrames, 3)
        XCTAssertEqual(result.frameBudget.frameBudgetMs, PerfThreshold.targetP99ms)
        XCTAssertTrue(result.frameBudget.overBudgetCount > 0)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try! encoder.encode(result)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("frameBudget"))
        XCTAssertTrue(json.contains("overBudgetCount"))
        XCTAssertTrue(json.contains("severity"))
    }

    func testPoolHitRateDuringStreamingSession_FullComplexDocument() {
        let pool = AttachmentPool()
        let renderer = MarkdownRenderer(
            theme: makeTestTheme(),
            maxLayoutWidth: renderWidth,
            tableSizeCache: TableCellSizeCache()
        )
        let chunks = makeStreamingChunks(from: kFullComplexDocument, chunkSize: 25)
        for chunk in chunks {
            let doc = renderer.parse(chunk)
            let state = CodeBlockAnalyzer.analyze(chunk)
            _ = renderer.render(doc, attachmentPool: pool, codeBlockState: state, isStreaming: true)
        }
        pool.logStats(context: "FullComplexDocument streaming — \(chunks.count) frames")

        let attachment = XCTAttachment(
            string: "Pool stats logged to console. Session: \(chunks.count) frames of FullComplexDocument."
        )
        attachment.name = "PoolStats_FullComplexDocumentStreaming"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testPoolHitRateDuringStreamingSession_ExtendedSession() {
        let pool = AttachmentPool()
        let renderer = MarkdownRenderer(
            theme: makeTestTheme(),
            maxLayoutWidth: renderWidth,
            tableSizeCache: TableCellSizeCache()
        )
        let extendedDoc = [kFullComplexDocument, kMixedContentDocument, kDeepNestDocument]
            .joined(separator: "\n\n---\n\n")
        let chunks = makeStreamingChunks(from: extendedDoc, chunkSize: 40)
        for chunk in chunks {
            let doc = renderer.parse(chunk)
            let state = CodeBlockAnalyzer.analyze(chunk)
            _ = renderer.render(doc, attachmentPool: pool, codeBlockState: state, isStreaming: true)
        }
        pool.logStats(context: "ExtendedSession streaming — \(chunks.count) frames")

        let attachment = XCTAttachment(
            string: "Pool stats logged to console. Session: \(chunks.count) frames of ExtendedSession."
        )
        attachment.name = "PoolStats_ExtendedSessionStreaming"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testPoolHitRateDuringStreamingSession_ComprehensiveBaseline() {
        let pool = AttachmentPool()
        let renderer = MarkdownRenderer(
            theme: makeTestTheme(),
            maxLayoutWidth: renderWidth,
            tableSizeCache: TableCellSizeCache()
        )
        let chunks = makeStreamingChunks(from: kComprehensiveBaselineDocument, chunkSize: 35)
        for chunk in chunks {
            let doc = renderer.parse(chunk)
            let state = CodeBlockAnalyzer.analyze(chunk)
            _ = renderer.render(doc, attachmentPool: pool, codeBlockState: state, isStreaming: true)
        }
        pool.logStats(context: "ComprehensiveBaseline streaming — \(chunks.count) frames")

        let attachment = XCTAttachment(
            string: "Pool stats logged to console. Session: \(chunks.count) frames of ComprehensiveBaseline."
        )
        attachment.name = "PoolStats_ComprehensiveBaselineStreaming"
        attachment.lifetime = .keepAlways
        add(attachment)
    }


    // ─────────────────────────────────────────────────────────────────────────────
    // MARK: - Chat Scenario Profiling
    // ─────────────────────────────────────────────────────────────────────────────

    /// Profiles streaming render cost in a chat scenario with a completed cell present.
    /// Compares per-tick timing WITH vs WITHOUT a completed MarkdownView to isolate
    /// the overhead of UITableView-style multi-cell layout.
    func testChatScenarioStreamingProfile() {
        let width: CGFloat = renderWidth
        let chunkSize = 20
        let chunks = makeStreamingChunks(from: kFullComplexDocument, chunkSize: chunkSize)

        // --- Setup: completed cell (simulates prior chat bubble) ---
        let completedView = MarkdownView()
        completedView.frame = CGRect(x: 0, y: 0, width: width, height: 600)
        completedView.preferredMaxLayoutWidth = width
        completedView.isScrollEnabled = false
        completedView.markdown = kFullComplexDocument
        hostWindow.addSubview(completedView)
        completedView.layoutIfNeeded()

        // --- Streaming view ---
        let streamingView = MarkdownView()
        streamingView.frame = CGRect(x: 0, y: 600, width: width, height: 600)
        streamingView.preferredMaxLayoutWidth = width
        streamingView.isScrollEnabled = false
        hostWindow.addSubview(streamingView)

        // --- Pass 1: WITH completed cell ---
        var withCompletedProfiles: [ChatTickProfile] = []

        for (i, chunk) in chunks.enumerated() {
            let totalStart = CFAbsoluteTimeGetCurrent()
            streamingView.markdown = chunk
            completedView.setNeedsLayout()
            streamingView.setNeedsLayout()
            hostWindow.layoutIfNeeded()
            let totalElapsed = (CFAbsoluteTimeGetCurrent() - totalStart) * 1000

            withCompletedProfiles.append(ChatTickProfile(
                index: i,
                chars: chunk.count,
                total: totalElapsed
            ))
        }

        // --- Reset for Pass 2 ---
        streamingView.cleanUp()
        completedView.removeFromSuperview()

        // --- Pass 2: WITHOUT completed cell ---
        var withoutCompletedProfiles: [ChatTickProfile] = []

        for (i, chunk) in chunks.enumerated() {
            let totalStart = CFAbsoluteTimeGetCurrent()
            streamingView.markdown = chunk
            streamingView.setNeedsLayout()
            hostWindow.layoutIfNeeded()
            let totalElapsed = (CFAbsoluteTimeGetCurrent() - totalStart) * 1000

            withoutCompletedProfiles.append(ChatTickProfile(
                index: i,
                chars: chunk.count,
                total: totalElapsed
            ))
        }

        // --- Build and attach report ---
        let report = buildChatScenarioReport(
            withCompleted: withCompletedProfiles,
            withoutCompleted: withoutCompletedProfiles
        )
        print(report)
        attachReport(report, name: "ChatScenarioProfile")
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Private Helpers
// ─────────────────────────────────────────────────────────────────────────────

private extension StreamingPerformanceTests {

    /// Generates incrementally growing prefix chunks of `fullText`.
    /// Simulates token-by-token AI streaming at approximately `chunkSize`
    /// unicode scalars per token delivery.
    func makeStreamingChunks(from fullText: String, chunkSize: Int) -> [String] {
        let scalars = Array(fullText.unicodeScalars)
        let total = scalars.count
        guard total > 0, chunkSize > 0 else { return [fullText] }
        var chunks: [String] = []
        var end = chunkSize
        while end < total {
            chunks.append(String(String.UnicodeScalarView(scalars[0..<end])))
            end += chunkSize
        }
        chunks.append(fullText) // always include the complete document as final chunk
        return chunks
    }

    func collectFrameTimingReport(chunks: [String], label: String) -> String {
        let frameTimes = collectFrameTimingData(chunks: chunks)
        return buildTimingReport(frameTimes: frameTimes, label: label)
    }

    func collectFrameTimingData(chunks: [String]) -> [Double] {
        var frameTimes: [Double] = []
        frameTimes.reserveCapacity(chunks.count)
        for chunk in chunks {
            let t0 = CACurrentMediaTime()
            sut.markdown = chunk
            sut.layoutIfNeeded()
            frameTimes.append(CACurrentMediaTime() - t0)
        }
        sut.markdown = ""
        return frameTimes
    }

    func makeTimingResult(label: String, frameTimes: [Double]) -> DocumentTimingResult {
        let sorted = frameTimes.sorted()
        let count = sorted.count
        let budget = makeFrameBudgetReport(frameTimes: frameTimes)
        guard count > 0 else {
            return DocumentTimingResult(
                document: label, frames: 0,
                p50_ms: 0, p95_ms: 0, p99_ms: 0,
                min_ms: 0, max_ms: 0, avg_ms: 0, total_ms: 0,
                frameBudget: budget
            )
        }
        let sum = sorted.reduce(0, +)
        return DocumentTimingResult(
            document: label,
            frames: count,
            p50_ms: sorted[count / 2] * 1000,
            p95_ms: sorted[max(0, min(Int(Double(count) * 0.95), count - 1))] * 1000,
            p99_ms: sorted[max(0, min(Int(Double(count) * 0.99), count - 1))] * 1000,
            min_ms: sorted.first! * 1000,
            max_ms: sorted.last! * 1000,
            avg_ms: (sum / Double(count)) * 1000,
            total_ms: sum * 1000,
            frameBudget: budget
        )
    }

    func makeFrameBudgetReport(
        frameTimes: [Double],
        budgetMs: Double = PerfThreshold.targetP99ms
    ) -> FrameBudgetReport {
        let budgetSec = budgetMs / 1000.0
        var overBudgetCount = 0
        var overBudgetTime = 0.0
        var maxTime = 0.0
        var mild = 0
        var moderate = 0
        var severe = 0

        for t in frameTimes {
            if t > maxTime { maxTime = t }
            if t > budgetSec {
                overBudgetCount += 1
                overBudgetTime += (t - budgetSec)
                let ratio = t / budgetSec
                if ratio > 4 {
                    severe += 1
                } else if ratio > 2 {
                    moderate += 1
                } else {
                    mild += 1
                }
            }
        }

        let totalFrames = frameTimes.count
        return FrameBudgetReport(
            frameBudgetMs: budgetMs,
            totalFrames: totalFrames,
            overBudgetCount: overBudgetCount,
            overBudgetRatio: totalFrames > 0 ? Double(overBudgetCount) / Double(totalFrames) : 0,
            overBudgetTimeMs: overBudgetTime * 1000,
            maxFrameTimeMs: maxTime * 1000,
            severity: SeverityDistribution(mild: mild, moderate: moderate, severe: severe)
        )
    }

    func encodePerformanceSummary(results: [DocumentTimingResult]) -> String {
        let summary = PerformanceSummary(
            timestamp: ISO8601DateFormatter().string(from: Date()),
            documents: results,
            thresholds: .init(
                regression_pct: PerfThreshold.regressionPct,
                improvement_pct: PerfThreshold.improvementPct,
                target_p99_ms: PerfThreshold.targetP99ms
            )
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(summary),
              let json = String(data: data, encoding: .utf8) else {
            return "{\"error\": \"Failed to encode performance summary\"}"
        }
        return json
    }

    func compareWithBaseline(
        _ currentResults: [DocumentTimingResult],
        baselinePath: String
    ) -> String {
        guard let baselineData = FileManager.default.contents(atPath: baselinePath),
              let baseline = try? JSONDecoder().decode(PerformanceSummary.self, from: baselineData) else {
            return "No baseline found at \(baselinePath). Run testStreamingPerformanceSummary_JSON to generate one."
        }

        var lines: [String] = ["┌─ Performance Comparison vs Baseline ─────────────────"]
        lines.append("│ Baseline: \(baseline.timestamp)")
        lines.append("├──────────────────────────────────────────────────────")

        let baselineMap = Dictionary(uniqueKeysWithValues: baseline.documents.map { ($0.document, $0) })
        for current in currentResults {
            guard let base = baselineMap[current.document] else {
                lines.append("│ \(current.document): NEW (no baseline)")
                continue
            }
            let deltaP50 = ((current.p50_ms - base.p50_ms) / base.p50_ms) * 100
            let deltaP99 = ((current.p99_ms - base.p99_ms) / base.p99_ms) * 100
            let flag50 = deltaP50 > PerfThreshold.regressionPct ? " REGRESSION" :
                         deltaP50 < -PerfThreshold.improvementPct ? " IMPROVED" : ""
            let flag99 = deltaP99 > PerfThreshold.regressionPct ? " REGRESSION" :
                         deltaP99 < -PerfThreshold.improvementPct ? " IMPROVED" : ""
            lines.append("│ \(current.document)")
            lines.append("│   P50: \(String(format: "%.3f", base.p50_ms))→\(String(format: "%.3f", current.p50_ms))ms (\(String(format: "%+.1f", deltaP50))%)\(flag50)")
            lines.append("│   P99: \(String(format: "%.3f", base.p99_ms))→\(String(format: "%.3f", current.p99_ms))ms (\(String(format: "%+.1f", deltaP99))%)\(flag99)")
        }
        lines.append("└──────────────────────────────────────────────────────")
        let report = lines.joined(separator: "\n")
        print(report)
        return report
    }

    /// Formats a per-frame timing distribution as a human-readable report.
    func buildTimingReport(frameTimes: [Double], label: String) -> String {
        guard !frameTimes.isEmpty else { return "\(label): no frames recorded" }
        let sorted = frameTimes.sorted()
        let count = sorted.count
        let sum = sorted.reduce(0, +)
        let avg = sum / Double(count)
        let p50 = sorted[count / 2]
        let p90 = sorted[max(0, Int(Double(count) * 0.90) - 1)]
        let p95 = sorted[max(0, min(Int(Double(count) * 0.95), count - 1))]
        let p99 = sorted[max(0, min(Int(Double(count) * 0.99), count - 1))]
        let maxT = sorted.last!
        let minT = sorted.first!
        let ms = { (t: Double) in String(format: "%.3f ms", t * 1000) }
        let report = """
        ┌──────────────────────────────────────────────────────────
        │ Frame Timing Distribution — \(label)
        ├──────────────────────────────────────────────────────────
        │ frames  : \(count)
        │ min     : \(ms(minT))
        │ avg     : \(ms(avg))
        │ P50     : \(ms(p50))
        │ P90     : \(ms(p90))
        │ P95     : \(ms(p95))
        │ P99     : \(ms(p99))
        │ max     : \(ms(maxT))
        │ total   : \(ms(sum))
        └──────────────────────────────────────────────────────────
        """
        print(report)
        return report
    }

    /// Attaches `report` to the test result with `lifetime=keepAlways` so it
    /// persists across test runs for before/after comparison.
    func attachReport(_ report: String, name: String) {
        let attachment = XCTAttachment(string: report)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    struct ChatTickProfile {
        let index: Int
        let chars: Int
        let total: Double
    }

    struct ObservabilityToggleRun {
        let frameTimes: [Double]
        let stats: MarkdownView.RenderPipelineStats
    }


    func buildChatScenarioReport(
        withCompleted: [ChatTickProfile],
        withoutCompleted: [ChatTickProfile]
    ) -> String {
        var lines: [String] = []
        lines.append("┌──────────────────────────────────────────────────────────")
        lines.append("│ CHAT SCENARIO STREAMING PROFILE")
        lines.append("├──────────────────────────────────────────────────────────")

        let ms = { (v: Double) in String(format: "%.3f", v) }

        for (label, profiles) in [("WITH completed cell", withCompleted), ("WITHOUT completed cell", withoutCompleted)] {
            lines.append("│")
            lines.append("│ ── \(label) ──")
            lines.append("│ ticks: \(profiles.count)")

            guard !profiles.isEmpty else { continue }

            let totals = profiles.map(\.total).sorted()
            let count = profiles.count

            func percentiles(_ arr: [Double]) -> (p50: Double, p90: Double, p99: Double, maxVal: Double) {
                let p50 = arr[count / 2]
                let p90 = arr[Swift.max(0, Int(Double(count) * 0.9) - 1)]
                let p99 = arr[Swift.max(0, Swift.min(Int(Double(count) * 0.99), count - 1))]
                return (p50, p90, p99, arr.last!)
            }

            let tp = percentiles(totals)

            lines.append("│")
            lines.append("│ Per-tick total:    P50=\(ms(tp.p50))ms  P90=\(ms(tp.p90))ms  P99=\(ms(tp.p99))ms  max=\(ms(tp.maxVal))ms")

            let q1End = count / 4
            let q2End = count / 2
            let q3End = count * 3 / 4

            let quartiles = [
                ("Q1 (0%-25%)", Array(profiles[0..<q1End])),
                ("Q2 (25%-50%)", Array(profiles[q1End..<q2End])),
                ("Q3 (50%-75%)", Array(profiles[q2End..<q3End])),
                ("Q4 (75%-100%)", Array(profiles[q3End..<count]))
            ]

            lines.append("│")
            lines.append("│ Quartile breakdown (by tick index, shows growth):")
            for (qLabel, qProfiles) in quartiles {
                guard !qProfiles.isEmpty else { continue }
                let avgTotal = qProfiles.map(\.total).reduce(0, +) / Double(qProfiles.count)
                let avgChars = qProfiles.map(\.chars).reduce(0, +) / qProfiles.count
                lines.append("│   \(qLabel): avg=\(ms(avgTotal))ms ~\(avgChars) chars")
            }

            let overBudget = profiles.filter { $0.total > 16.67 }
            lines.append("│")
            lines.append("│ Over-budget (>16.67ms): \(overBudget.count)/\(count) ticks (\(String(format: "%.1f", Double(overBudget.count) / Double(count) * 100))%)")

            let top5 = profiles.sorted(by: { $0.total > $1.total }).prefix(5)
            lines.append("│ Top 5 slowest ticks:")
            for t in top5 {
                lines.append("│   tick[\(t.index)] \(ms(t.total))ms (\(t.chars) chars)")
            }
        }

        lines.append("├──────────────────────────────────────────────────────────")
        lines.append("│ COMPARISON")
        lines.append("├──────────────────────────────────────────────────────────")

        if !withCompleted.isEmpty && !withoutCompleted.isEmpty {
            let avgWith = withCompleted.map(\.total).reduce(0, +) / Double(withCompleted.count)
            let avgWithout = withoutCompleted.map(\.total).reduce(0, +) / Double(withoutCompleted.count)
            let overhead = avgWith - avgWithout
            let overheadPct = avgWithout > 0 ? (overhead / avgWithout) * 100 : 0
            lines.append("│ Avg per-tick WITH:    \(ms(avgWith))ms")
            lines.append("│ Avg per-tick WITHOUT: \(ms(avgWithout))ms")
            lines.append("│ Completed-cell overhead: \(String(format: "%+.3f", overhead))ms (\(String(format: "%+.1f", overheadPct))%)")
        }

        lines.append("└──────────────────────────────────────────────────────────")
        return lines.joined(separator: "\n")
    }

    func collectFrameTimingData(chunks: [String], statsEnabled: Bool) -> ObservabilityToggleRun {
        let originalIsStreaming = sut.isStreaming
        let originalThrottleInterval = sut.throttleInterval

        sut.isStreaming = true
        sut.throttleInterval = 0.001
        sut.isRenderPipelineStatsEnabled = statsEnabled
        sut.resetRenderPipelineStats()

        var frameTimes: [Double] = []
        frameTimes.reserveCapacity(chunks.count)
        for chunk in chunks {
            let t0 = CACurrentMediaTime()
            sut.markdown = chunk
            RunLoop.main.run(until: Date().addingTimeInterval(sut.throttleInterval * 2))
            sut.layoutIfNeeded()
            frameTimes.append(CACurrentMediaTime() - t0)
        }
        RunLoop.main.run(until: Date().addingTimeInterval(sut.throttleInterval * 2))

        let stats = sut.renderPipelineStats
        sut.markdown = ""
        sut.isStreaming = originalIsStreaming
        sut.throttleInterval = originalThrottleInterval
        sut.isRenderPipelineStatsEnabled = false
        sut.resetRenderPipelineStats()

        return ObservabilityToggleRun(frameTimes: frameTimes, stats: stats)
    }

    func buildObservabilityToggleReport(
        disabledResult: DocumentTimingResult,
        enabledResult: DocumentTimingResult,
        disabledStats: MarkdownView.RenderPipelineStats,
        enabledStats: MarkdownView.RenderPipelineStats,
        avgDeltaPct: Double,
        p99DeltaPct: Double
    ) -> String {
        let report = """
        ┌──────────────────────────────────────────────────────────
        │ STREAMING OBSERVABILITY TOGGLE COMPARISON (FullComplex)
        ├──────────────────────────────────────────────────────────
        │ Stats Disabled: avg=\(String(format: "%.3f", disabledResult.avg_ms))ms p99=\(String(format: "%.3f", disabledResult.p99_ms))ms frames=\(disabledResult.frames)
        │ Stats Enabled : avg=\(String(format: "%.3f", enabledResult.avg_ms))ms p99=\(String(format: "%.3f", enabledResult.p99_ms))ms frames=\(enabledResult.frames)
        │ Delta (enabled - disabled): avg=\(String(format: "%+.2f", avgDeltaPct))% p99=\(String(format: "%+.2f", p99DeltaPct))%
        ├──────────────────────────────────────────────────────────
        │ Collector snapshot when disabled
        │ assignments=\(disabledStats.markdownAssignments) schedules=\(disabledStats.streamingSchedules) executes=\(disabledStats.throttledExecutes)
        │ renderCalls=\(disabledStats.renderCalls) renderSkips=\(disabledStats.renderSkips) widthUnavailable=\(disabledStats.widthUnavailable)
        ├──────────────────────────────────────────────────────────
        │ Collector snapshot when enabled
        │ assignments=\(enabledStats.markdownAssignments) schedules=\(enabledStats.streamingSchedules) executes=\(enabledStats.throttledExecutes)
        │ renderCalls=\(enabledStats.renderCalls) renderSkips=\(enabledStats.renderSkips) widthUnavailable=\(enabledStats.widthUnavailable)
        └──────────────────────────────────────────────────────────
        """
        return report
    }
}
