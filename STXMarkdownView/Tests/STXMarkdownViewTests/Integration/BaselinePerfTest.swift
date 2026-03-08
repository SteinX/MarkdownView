// BaselinePerfTest.swift
// Minimal self-contained streaming performance baseline test.
// Uses ONLY pre-optimization public API: MarkdownView, markdown, isStreaming,
// preferredMaxLayoutWidth, layoutIfNeeded, cleanUp, makeTestTheme().
// Outputs JSON results delimited by BASELINE_JSON_BEGIN / BASELINE_JSON_END.

import XCTest
import UIKit
@testable import STXMarkdownView

// MARK: - Fixture Documents

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

// MARK: - Codable Result Types

private struct BaselineTimingResult: Codable {
    let document: String
    let frames: Int
    let p50ms: Double
    let p95ms: Double
    let p99ms: Double
    let minMs: Double
    let maxMs: Double
    let avgMs: Double
    let totalMs: Double
    let frameBudget: BaselineFrameBudgetReport
}

private struct BaselineFrameBudgetReport: Codable {
    let frameBudgetMs: Double
    let totalFrames: Int
    let overBudgetCount: Int
    let overBudgetRatio: Double
    let overBudgetTimeMs: Double
    let maxFrameTimeMs: Double
    let severity: BaselineSeverityDistribution
}

private struct BaselineSeverityDistribution: Codable {
    let mild: Int
    let moderate: Int
    let severe: Int
}

private struct BaselineSummary: Codable {
    let timestamp: String
    let label: String
    let documents: [BaselineTimingResult]
}

// MARK: - BaselinePerfTest

@MainActor
final class BaselinePerfTest: XCTestCase {

    private var sut: MarkdownView!
    private var hostWindow: UIWindow!

    override func setUp() {
        super.setUp()
        hostWindow = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        hostWindow.isHidden = false

        sut = MarkdownView(theme: makeTestTheme())
        sut.frame = CGRect(x: 0, y: 0, width: 342, height: 800)
        sut.preferredMaxLayoutWidth = 342
        sut.isScrollEnabled = false
        hostWindow.addSubview(sut)

        // Let RunLoop settle
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
    }

    override func tearDown() {
        sut.cleanUp()
        sut.removeFromSuperview()
        sut = nil
        hostWindow.isHidden = true
        hostWindow = nil
        super.tearDown()
    }

    // MARK: - Main Baseline Test

    func testStreamingBaseline_JSON() {
        let documents: [(String, String)] = [
            ("PlainText", kPlainDocument),
            ("CodeBlock", kCodeDocument),
            ("RichDocument", kRichDocument),
            ("LargeTable", kLargeTableDocument),
            ("DeepNest", kDeepNestDocument),
            ("MixedContent", kMixedContentDocument),
            ("FullComplex", kFullComplexDocument)
        ]

        var results: [BaselineTimingResult] = []

        for (label, content) in documents {
            // Reset
            sut.isStreaming = false
            sut.markdown = ""
            sut.layoutIfNeeded()
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))

            // Make streaming chunks
            let chunks = makeStreamingChunks(from: content, chunkSize: 25)

            // Collect frame times
            let frameTimes = collectFrameTimingData(chunks: chunks)

            // Compute stats
            let result = makeTimingResult(label: label, frameTimes: frameTimes)
            results.append(result)

            // Reset for next
            sut.isStreaming = false
            sut.markdown = ""
            sut.layoutIfNeeded()
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        }

        // Encode and print
        let summary = BaselineSummary(
            timestamp: ISO8601DateFormatter().string(from: Date()),
            label: "post-optimization",
            documents: results
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(summary),
              let json = String(data: data, encoding: .utf8) else {
            XCTFail("Failed to encode baseline summary")
            return
        }

        print("BASELINE_JSON_BEGIN")
        print(json)
        print("BASELINE_JSON_END")
    }

    // MARK: - Helpers

    private func makeStreamingChunks(from text: String, chunkSize: Int) -> [String] {
        var chunks: [String] = []
        let scalars = Array(text.unicodeScalars)
        var index = 0
        while index < scalars.count {
            index = min(index + chunkSize, scalars.count)
            let prefix = String(String.UnicodeScalarView(scalars[0..<index]))
            chunks.append(prefix)
        }
        return chunks
    }

    private func collectFrameTimingData(chunks: [String]) -> [Double] {
        // Non-streaming forces synchronous render per chunk (throttle timer would defer rendering otherwise)
        sut.isStreaming = false
        sut.markdown = ""
        sut.layoutIfNeeded()

        var frameTimes: [Double] = []

        for chunk in chunks {
            let start = CACurrentMediaTime()
            sut.markdown = chunk
            sut.layoutIfNeeded()
            let elapsed = CACurrentMediaTime() - start
            frameTimes.append(elapsed)
        }

        return frameTimes
    }

    private func makeTimingResult(label: String, frameTimes: [Double]) -> BaselineTimingResult {
        let sorted = frameTimes.sorted()
        let count = sorted.count
        let budget = makeFrameBudgetReport(frameTimes: frameTimes)
        guard count > 0 else {
            return BaselineTimingResult(
                document: label, frames: 0,
                p50ms: 0, p95ms: 0, p99ms: 0,
                minMs: 0, maxMs: 0, avgMs: 0, totalMs: 0,
                frameBudget: budget
            )
        }

        let p50 = sorted[count / 2]
        let p95 = sorted[min(Int(Double(count) * 0.95), count - 1)]
        let p99 = sorted[min(Int(Double(count) * 0.99), count - 1)]
        let total = sorted.reduce(0, +)
        let avg = total / Double(count)

        return BaselineTimingResult(
            document: label,
            frames: count,
            p50ms: round(p50 * 1_000_000) / 1_000,
            p95ms: round(p95 * 1_000_000) / 1_000,
            p99ms: round(p99 * 1_000_000) / 1_000,
            minMs: round(sorted[0] * 1_000_000) / 1_000,
            maxMs: round(sorted[count - 1] * 1_000_000) / 1_000,
            avgMs: round(avg * 1_000_000) / 1_000,
            totalMs: round(total * 1_000_000) / 1_000,
            frameBudget: budget
        )
    }

    private func makeFrameBudgetReport(
        frameTimes: [Double],
        budgetMs: Double = 16.67
    ) -> BaselineFrameBudgetReport {
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
        return BaselineFrameBudgetReport(
            frameBudgetMs: budgetMs,
            totalFrames: totalFrames,
            overBudgetCount: overBudgetCount,
            overBudgetRatio: totalFrames > 0 ? Double(overBudgetCount) / Double(totalFrames) : 0,
            overBudgetTimeMs: overBudgetTime * 1000,
            maxFrameTimeMs: maxTime * 1000,
            severity: BaselineSeverityDistribution(mild: mild, moderate: moderate, severe: severe)
        )
    }
}
