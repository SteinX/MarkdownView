// DisplayPipelineHitchTests.swift
// Phase 2: CADisplayLink-based display pipeline hitch detection
//
// These tests feed markdown chunks via Timer.scheduledTimer in .common RunLoop mode
// while monitoring frame delivery via CADisplayLink. Any gap > 1.5× the expected
// frame duration is counted as a "frame drop" (display pipeline hitch).
//
// IMPORTANT: These tests are opt-in and NOT CI-gated.
// Run with: RUN_DISPLAY_PIPELINE_TESTS=1
// They MUST be run on a real device or booted simulator with GPU; results on
// headless CI are not reliable for display pipeline measurements.
//
// swiftlint:disable file_length function_body_length type_body_length

import XCTest
import UIKit
@testable import STXMarkdownView

// MARK: - HitchResult

/// Captures the outcome of a CADisplayLink monitoring session.
private struct HitchResult {
    /// Number of frame gaps exceeding 1.5× expected frame duration
    let hitchCount: Int
    /// Total time lost to hitches (sum of gap - expectedDuration for each hitch)
    let hitchTimeMs: Double
    /// Maximum single-frame gap observed (ms)
    let maxGapMs: Double
    /// Total monitoring wall-clock time (ms)
    let totalMonitoredMs: Double
    /// Ratio of hitch time to total monitored time
    var hitchTimeRatio: Double {
        guard totalMonitoredMs > 0 else { return 0 }
        return hitchTimeMs / totalMonitoredMs
    }
    /// All individual frame gaps (ms) for analysis
    let frameGaps: [Double]
}

// MARK: - FrameDropDetector

/// Monitors display pipeline frame delivery using CADisplayLink.
/// Counts "hitches" when the gap between consecutive frames exceeds
/// 1.5× the display's natural frame duration.
private final class FrameDropDetector: NSObject {
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var gaps: [Double] = [] // milliseconds
    private var startTime: CFTimeInterval = 0
    private var endTime: CFTimeInterval = 0
    private var hitchThresholdMultiplier: Double = 1.5

    /// Start monitoring frame delivery.
    func startMonitoring() {
        gaps.removeAll()
        lastTimestamp = 0
        startTime = CACurrentMediaTime()

        let link = CADisplayLink(target: self, selector: #selector(frameCallback(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    /// Stop monitoring and return the hitch result.
    func stopMonitoring() -> HitchResult {
        endTime = CACurrentMediaTime()

        // Capture frame duration BEFORE invalidating the link
        let linkDurationMs: Double? = displayLink.map { $0.duration * 1000.0 }

        displayLink?.invalidate()
        displayLink = nil

        let totalMs = (endTime - startTime) * 1000.0

        let expectedDurationMs: Double
        if let duration = linkDurationMs, duration > 0 {
            expectedDurationMs = duration
        } else {
            let sortedGaps = gaps.sorted()
            if sortedGaps.count > 2 {
                expectedDurationMs = sortedGaps[sortedGaps.count / 2]
            } else {
                expectedDurationMs = 16.67
            }
        }

        let hitchThresholdMs = expectedDurationMs * hitchThresholdMultiplier
        var hitchCount = 0
        var hitchTimeMs = 0.0
        var maxGapMs = 0.0

        for gap in gaps {
            if gap > maxGapMs { maxGapMs = gap }
            if gap > hitchThresholdMs {
                hitchCount += 1
                hitchTimeMs += (gap - expectedDurationMs)
            }
        }

        return HitchResult(
            hitchCount: hitchCount,
            hitchTimeMs: hitchTimeMs,
            maxGapMs: maxGapMs,
            totalMonitoredMs: totalMs,
            frameGaps: gaps
        )
    }

    @objc private func frameCallback(_ link: CADisplayLink) {
        let now = link.timestamp
        if lastTimestamp > 0 {
            let gapMs = (now - lastTimestamp) * 1000.0
            gaps.append(gapMs)
        }
        lastTimestamp = now
    }
}

// MARK: - Test Fixtures (subset from StreamingPerformanceTests)

// Plain text — no attachments, minimal render cost
private let kHitchTestPlainDocument = """
This is a simple plain text document used for display pipeline testing.

It contains multiple paragraphs of regular text with no special formatting,
no code blocks, no tables, and no images. The purpose is to establish a
baseline for frame delivery during streaming of trivial content.

Each paragraph is separated by a blank line, which creates distinct blocks
in the markdown AST. This helps verify that even basic text streaming does
not introduce frame drops in the display pipeline.

The final paragraph concludes the document with some additional text to
ensure we have enough content for meaningful chunk-based streaming.
"""

// Full complex — stress test with all element types
private let kHitchTestFullComplexDocument = """
# Architecture Decision Record

## Overview

This document covers the **complete system architecture** with *emphasis* on ~~deprecated~~ patterns.

> **Critical Note**: The following architecture has been reviewed and approved.
>
> > **Sub-note**: Nested quotes test recursive rendering performance.
> >
> > > **Deep note**: Third level nesting with `inline code` and **bold**.

## Service Inventory

| Service | Port | Protocol | Status | Region | CPU | Memory | Disk | Replicas | Version |
|---------|------|----------|--------|--------|-----|--------|------|----------|---------|
| api-gateway | 8080 | HTTPS | Active | us-east-1 | 4 cores | 8GB | 100GB | 3 | v2.1.0 |
| auth-service | 8081 | gRPC | Active | us-east-1 | 2 cores | 4GB | 50GB | 2 | v1.5.3 |
| user-service | 8082 | REST | Degraded | eu-west-1 | 4 cores | 16GB | 200GB | 4 | v3.0.1 |
| notification | 8083 | WebSocket | Active | ap-south-1 | 1 core | 2GB | 20GB | 1 | v1.0.0 |
| analytics | 8084 | GraphQL | Active | us-west-2 | 8 cores | 32GB | 500GB | 2 | v2.3.0 |
| payment | 8085 | HTTPS | Active | eu-west-1 | 4 cores | 8GB | 100GB | 3 | v4.1.2 |
| search | 8086 | REST | Maintenance | us-east-1 | 16 cores | 64GB | 1TB | 5 | v1.8.0 |
| cdn-origin | 8087 | HTTP/2 | Active | global | 2 cores | 4GB | 2TB | 8 | v1.2.1 |

## Authentication Flow

```rust
pub async fn authenticate(req: AuthRequest) -> Result<AuthResponse, AuthError> {
    let credentials = validate_credentials(&req.username, &req.password)?;
    let token_pair = generate_token_pair(&credentials).await?;

    if req.requires_mfa {
        let mfa_challenge = create_mfa_challenge(&credentials).await?;
        return Ok(AuthResponse::MfaRequired {
            challenge_id: mfa_challenge.id,
            expires_at: mfa_challenge.expires_at,
        });
    }

    audit_log::record(AuditEvent::Login {
        user_id: credentials.user_id,
        ip_addr: req.remote_addr,
        timestamp: Utc::now(),
    }).await?;

    Ok(AuthResponse::Success {
        access_token: token_pair.access,
        refresh_token: token_pair.refresh,
        expires_in: token_pair.ttl,
    })
}
```

## Deployment Checklist

1. **Pre-deployment**
   - [ ] Run full test suite
   - [ ] Check dependency vulnerabilities
   - [ ] Review migration scripts
2. **Deployment**
   - [ ] Scale down to 1 replica
   - [ ] Apply database migrations
   > **Warning**: Always backup before migration
   >
   > ```sql
   > SELECT pg_dump('production_db');
   > ```
3. **Post-deployment**
   - [ ] Verify health endpoints
   - [ ] Scale back to target replicas
   - [x] Update monitoring dashboards

## Database Schema

```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(512) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    metadata JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_created ON users(created_at DESC);
```

---

## Metrics Summary

> | Metric | Value | Target | Status |
> |--------|-------|--------|--------|
> | P99 Latency | 45ms | <50ms | OK |
> | Error Rate | 0.02% | <0.1% | OK |
> | Throughput | 12k rps | >10k | OK |
> | Availability | 99.97% | >99.9% | OK |

![System Architecture](https://example.com/architecture-diagram.png)

*Last updated: 2024-01-15*
"""

// Large table — stress test for table layout calculations
private let kHitchTestLargeTableDocument = """
# Employee Directory

| ID | First Name | Last Name | Department | Title | Location | Salary | Start Date | Manager | Status |
|----|-----------|-----------|------------|-------|----------|--------|------------|---------|--------|
| 001 | Alice | Johnson | Engineering | Senior Engineer | San Francisco | $185,000 | 2019-03-15 | Bob Smith | Active |
| 002 | Bob | Smith | Engineering | Engineering Manager | San Francisco | $210,000 | 2017-06-01 | Carol White | Active |
| 003 | Carol | White | Engineering | VP Engineering | San Francisco | $280,000 | 2015-01-10 | Dave Brown | Active |
| 004 | Dave | Brown | Executive | CTO | New York | $350,000 | 2014-08-20 | - | Active |
| 005 | Eve | Davis | Design | Lead Designer | London | $145,000 | 2020-02-28 | Frank Lee | Active |
| 006 | Frank | Lee | Design | Design Manager | London | $175,000 | 2018-11-05 | Carol White | Active |
| 007 | Grace | Wilson | Marketing | Marketing Lead | Berlin | $130,000 | 2021-04-12 | Helen Clark | Active |
| 008 | Helen | Clark | Marketing | CMO | New York | $260,000 | 2016-09-30 | Dave Brown | Active |
| 009 | Ivan | Taylor | Sales | Sales Rep | Tokyo | $95,000 | 2022-01-18 | Julia Adams | Active |
| 010 | Julia | Adams | Sales | Sales Director | New York | $195,000 | 2019-07-22 | Dave Brown | Active |

> This directory is updated quarterly. Contact HR for corrections.
"""

// MARK: - DisplayPipelineHitchTests

@MainActor
final class DisplayPipelineHitchTests: XCTestCase {
    private var window: UIWindow!
    private var sut: MarkdownView!
    private let renderWidth: CGFloat = 342

    override func setUp() {
        super.setUp()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        sut = MarkdownView()
        sut.frame = CGRect(x: 16, y: 0, width: renderWidth, height: 800)
        sut.preferredMaxLayoutWidth = renderWidth
        window.addSubview(sut)
        window.makeKeyAndVisible()
    }

    override func tearDown() {
        sut.cleanUp()
        sut.removeFromSuperview()
        sut = nil
        window = nil
        super.tearDown()
    }

    // MARK: - Opt-in Skip

    private func skipUnlessDisplayPipelineEnabled() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["RUN_DISPLAY_PIPELINE_TESTS"] == "1",
            "Display pipeline tests are opt-in. Set RUN_DISPLAY_PIPELINE_TESTS=1 to enable."
        )
    }

    // MARK: - Tests

    /// Plain text streaming should produce zero or near-zero frame drops.
    func testDisplayPipeline_PlainText_NoHitches() throws {
        try skipUnlessDisplayPipelineEnabled()

        let result = runDisplayPipelineTest(
            document: kHitchTestPlainDocument,
            chunkSize: 20,
            chunkIntervalMs: 100,
            timeoutSeconds: 15
        )

        // Plain text should be trivial to render — expect 0 hitches
        attachHitchReport(result, name: "PlainText_DisplayPipeline")
        XCTAssertEqual(result.hitchCount, 0,
                       "Plain text streaming should produce 0 display pipeline hitches, got \(result.hitchCount)")
    }

    /// Full complex document — measure hitch count and ratio for the stress case.
    func testDisplayPipeline_FullComplex_MeasureHitches() throws {
        try skipUnlessDisplayPipelineEnabled()

        let result = runDisplayPipelineTest(
            document: kHitchTestFullComplexDocument,
            chunkSize: 30,
            chunkIntervalMs: 100,
            timeoutSeconds: 30
        )

        attachHitchReport(result, name: "FullComplex_DisplayPipeline")

        // Log metrics for comparison — not asserting a hard threshold since
        // display pipeline results vary by device/simulator
        print("""
        DISPLAY_PIPELINE: FullComplex
          hitchCount: \(result.hitchCount)
          hitchTimeMs: \(String(format: "%.2f", result.hitchTimeMs))
          hitchTimeRatio: \(String(format: "%.4f", result.hitchTimeRatio))
          maxGapMs: \(String(format: "%.2f", result.maxGapMs))
          totalMonitoredMs: \(String(format: "%.0f", result.totalMonitoredMs))
          totalFrames: \(result.frameGaps.count)
        """)

        // Soft assertion: hitch ratio should be < 20% (very generous for simulator)
        XCTAssertLessThan(result.hitchTimeRatio, 0.20,
                          "FullComplex hitch time ratio \(String(format: "%.2f%%", result.hitchTimeRatio * 100)) exceeds 20% threshold")
    }

    /// Large table stress test — tables are the heaviest render path.
    func testDisplayPipeline_LargeTable_StressTest() throws {
        try skipUnlessDisplayPipelineEnabled()

        let result = runDisplayPipelineTest(
            document: kHitchTestLargeTableDocument,
            chunkSize: 30,
            chunkIntervalMs: 100,
            timeoutSeconds: 20
        )

        attachHitchReport(result, name: "LargeTable_DisplayPipeline")

        print("""
        DISPLAY_PIPELINE: LargeTable
          hitchCount: \(result.hitchCount)
          hitchTimeMs: \(String(format: "%.2f", result.hitchTimeMs))
          hitchTimeRatio: \(String(format: "%.4f", result.hitchTimeRatio))
          maxGapMs: \(String(format: "%.2f", result.maxGapMs))
          totalMonitoredMs: \(String(format: "%.0f", result.totalMonitoredMs))
          totalFrames: \(result.frameGaps.count)
        """)

        // Tables are expensive; log for tracking, soft threshold
        XCTAssertLessThan(result.hitchTimeRatio, 0.30,
                          "LargeTable hitch time ratio \(String(format: "%.2f%%", result.hitchTimeRatio * 100)) exceeds 30% threshold")
    }

    // MARK: - Private Helpers

    /// Runs a full display pipeline test: feeds markdown chunks via Timer while
    /// monitoring frame delivery via CADisplayLink.
    ///
    /// - Parameters:
    ///   - document: Full markdown text to stream
    ///   - chunkSize: Number of unicode scalars per chunk
    ///   - chunkIntervalMs: Milliseconds between chunk deliveries
    ///   - timeoutSeconds: Maximum wait time
    /// - Returns: HitchResult with frame gap analysis
    private func runDisplayPipelineTest(
        document: String,
        chunkSize: Int,
        chunkIntervalMs: Int,
        timeoutSeconds: TimeInterval
    ) -> HitchResult {
        let chunks = makeStreamingChunks(from: document, chunkSize: chunkSize)
        let detector = FrameDropDetector()
        let expectation = XCTestExpectation(description: "Streaming complete")

        var chunkIndex = 0
        var accumulated = ""

        // Start streaming mode
        sut.isStreaming = true

        // Start frame monitoring
        detector.startMonitoring()

        // Feed chunks via Timer in .common mode so CADisplayLink also fires
        let interval = TimeInterval(chunkIntervalMs) / 1000.0
        nonisolated(unsafe) let markdownView = sut!
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { t in
            MainActor.assumeIsolated {
                if chunkIndex < chunks.count {
                    accumulated += chunks[chunkIndex]
                    markdownView.markdown = accumulated
                    markdownView.layoutIfNeeded()
                    chunkIndex += 1
                } else {
                    t.invalidate()
                    markdownView.isStreaming = false
                    markdownView.markdown = accumulated
                    markdownView.layoutIfNeeded()
                    expectation.fulfill()
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)

        wait(for: [expectation], timeout: timeoutSeconds)

        return detector.stopMonitoring()
    }

    /// Split document into unicode scalar-based chunks.
    private func makeStreamingChunks(from text: String, chunkSize: Int) -> [String] {
        var chunks: [String] = []
        let scalars = Array(text.unicodeScalars)
        var i = 0
        while i < scalars.count {
            let end = min(i + chunkSize, scalars.count)
            let slice = scalars[i..<end]
            chunks.append(String(String.UnicodeScalarView(slice)))
            i = end
        }
        return chunks
    }

    /// Attach a human-readable hitch report as XCTAttachment.
    private func attachHitchReport(_ result: HitchResult, name: String) {
        let report = """
        Display Pipeline Hitch Report: \(name)
        ========================================
        Hitch Count:     \(result.hitchCount)
        Hitch Time:      \(String(format: "%.2f", result.hitchTimeMs)) ms
        Hitch Ratio:     \(String(format: "%.4f", result.hitchTimeRatio)) (\(String(format: "%.2f%%", result.hitchTimeRatio * 100)))
        Max Gap:         \(String(format: "%.2f", result.maxGapMs)) ms
        Total Monitored: \(String(format: "%.0f", result.totalMonitoredMs)) ms
        Total Frames:    \(result.frameGaps.count)
        ========================================
        Frame Gap Distribution:
          < 20ms:   \(result.frameGaps.filter { $0 < 20 }.count)
          20-33ms:  \(result.frameGaps.filter { $0 >= 20 && $0 < 33 }.count)
          33-50ms:  \(result.frameGaps.filter { $0 >= 33 && $0 < 50 }.count)
          50-100ms: \(result.frameGaps.filter { $0 >= 50 && $0 < 100 }.count)
          > 100ms:  \(result.frameGaps.filter { $0 >= 100 }.count)
        """

        let attachment = XCTAttachment(string: report)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

// swiftlint:enable file_length function_body_length type_body_length
