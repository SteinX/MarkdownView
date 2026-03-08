// swiftlint:disable file_length function_body_length type_body_length
import XCTest
import UIKit
@testable import STXMarkdownView

// MARK: - Memory Measurement

private func getMemoryFootprint() -> UInt64 {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(
        MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size
    )
    let kr = withUnsafeMutablePointer(to: &info) { infoPtr in
        infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), intPtr, &count)
        }
    }
    return kr == KERN_SUCCESS ? UInt64(info.phys_footprint) : 0
}

private func drainMemory() {
    autoreleasepool { }
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
}

// MARK: - Codable Report

private struct MemoryReport: Codable {
    let document: String
    let blockCount: Int
    let mode: String
    let baselineBytes: UInt64
    let peakBytes: UInt64
    let steadyStateBytes: UInt64
    let peakDeltaMB: Double
    let steadyStateDeltaMB: Double
    let bytesPerBlock: Double
}

private struct MemorySummary: Codable {
    let timestamp: String
    let reports: [MemoryReport]
}

// MARK: - Synthetic Document Generator

private func generateSyntheticDocument(blockCount: Int) -> String {
    var blocks: [String] = []
    var blockIndex = 0

    while blockIndex < blockCount {
        let kind = blockIndex % 10

        switch kind {
        case 0:
            let level = (blockIndex % 3) + 1
            let prefix = String(repeating: "#", count: level)
            blocks.append("\(prefix) Section \(blockIndex)")
            blockIndex += 1

        case 1:
            blocks.append("""
            Paragraph \(blockIndex) with **bold**, *italic*, `inline code`, and [a link](https://example.com). \
            This text is long enough to exercise attributed string building across multiple style runs.
            """)
            blockIndex += 1

        case 2:
            blocks.append("""
            ```swift
            func compute\(blockIndex)(_ values: [Int]) -> Int {
                return values.reduce(0, +)
            }
            ```
            """)
            blockIndex += 1

        case 3:
            blocks.append("""
            | Col A | Col B | Col C | Col D |
            |-------|-------|-------|-------|
            | R\(blockIndex)-1 | data | \(Int.random(in: 100...999)) | value |
            | R\(blockIndex)-2 | data | \(Int.random(in: 100...999)) | value |
            | R\(blockIndex)-3 | data | \(Int.random(in: 100...999)) | value |
            """)
            blockIndex += 1

        case 4:
            blocks.append("""
            > Blockquote \(blockIndex): nested content with **emphasis**.
            >
            > > Deeper level with `code` inside.
            """)
            blockIndex += 1

        case 5:
            blocks.append("![Image \(blockIndex)](https://placehold.co/200x100.png)")
            blockIndex += 1

        case 6:
            blocks.append("---")
            blockIndex += 1

        case 7:
            blocks.append("""
            - Item \(blockIndex)-A with **bold**
              - Nested item with `code`
                - Deep nested
            - Item \(blockIndex)-B
            """)
            blockIndex += 1

        case 8:
            blocks.append("""
            ```json
            {
                "id": \(blockIndex),
                "name": "entry_\(blockIndex)",
                "values": [1, 2, 3, 4, 5]
            }
            ```
            """)
            blockIndex += 1

        case 9:
            blocks.append("""
            - [x] Task \(blockIndex) completed
            - [ ] Task \(blockIndex + 1) pending
            """)
            blockIndex += 1

        default:
            blockIndex += 1
        }
    }

    return blocks.joined(separator: "\n\n")
}

private let kSmallDoc = generateSyntheticDocument(blockCount: 50)
private let kMediumDoc = generateSyntheticDocument(blockCount: 100)
private let kLargeDoc = generateSyntheticDocument(blockCount: 200)

// MARK: - Tests

@MainActor
final class MemoryFootprintTests: XCTestCase {

    private var window: UIWindow!
    private var sut: MarkdownView!
    private let renderWidth: CGFloat = 342

    override func setUp() {
        super.setUp()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        sut = MarkdownView()
        sut.frame = CGRect(x: 0, y: 0, width: renderWidth, height: 844)
        sut.preferredMaxLayoutWidth = renderWidth
        window.addSubview(sut)
        window.makeKeyAndVisible()
        sut.layoutIfNeeded()
        drainMemory()
    }

    override func tearDown() {
        sut.cleanUp()
        sut.removeFromSuperview()
        sut = nil
        window = nil
        drainMemory()
        super.tearDown()
    }

    // MARK: - Static Rendering

    func testMemoryFootprint_Static_SmallDoc_50Blocks() {
        let report = measureStaticMemory(document: kSmallDoc, label: "SmallDoc_50", blockCount: 50)
        attachMemoryReport(report)
        assertMemoryBounds(report, maxSteadyMB: 60, maxBytesPerBlock: 1_000_000)
    }

    func testMemoryFootprint_Static_MediumDoc_100Blocks() {
        let report = measureStaticMemory(document: kMediumDoc, label: "MediumDoc_100", blockCount: 100)
        attachMemoryReport(report)
        assertMemoryBounds(report, maxSteadyMB: 100, maxBytesPerBlock: 850_000)
    }

    func testMemoryFootprint_Static_LargeDoc_200Blocks() {
        let report = measureStaticMemory(document: kLargeDoc, label: "LargeDoc_200", blockCount: 200)
        attachMemoryReport(report)
        assertMemoryBounds(report, maxSteadyMB: 200, maxBytesPerBlock: 800_000)
    }

    // MARK: - Streaming Rendering

    func testMemoryFootprint_Streaming_SmallDoc_50Blocks() {
        let report = measureStreamingMemory(document: kSmallDoc, label: "SmallDoc_50_streaming", blockCount: 50, chunkSize: 30)
        attachMemoryReport(report)
        assertMemoryBounds(report, maxSteadyMB: 50, maxBytesPerBlock: 800_000)
    }

    func testMemoryFootprint_Streaming_MediumDoc_100Blocks() {
        let report = measureStreamingMemory(document: kMediumDoc, label: "MediumDoc_100_streaming", blockCount: 100, chunkSize: 30)
        attachMemoryReport(report)
        assertMemoryBounds(report, maxSteadyMB: 80, maxBytesPerBlock: 700_000)
    }

    func testMemoryFootprint_Streaming_LargeDoc_200Blocks() {
        let report = measureStreamingMemory(document: kLargeDoc, label: "LargeDoc_200_streaming", blockCount: 200, chunkSize: 30)
        attachMemoryReport(report)
        assertMemoryBounds(report, maxSteadyMB: 180, maxBytesPerBlock: 700_000)
    }

    // MARK: - JSON Summary

    func testMemoryFootprintSummary_JSON() {
        let configs: [(doc: String, label: String, blocks: Int, chunk: Int?)] = [
            (kSmallDoc, "SmallDoc_50", 50, nil),
            (kMediumDoc, "MediumDoc_100", 100, nil),
            (kLargeDoc, "LargeDoc_200", 200, nil),
            (kSmallDoc, "SmallDoc_50_streaming", 50, 30),
            (kMediumDoc, "MediumDoc_100_streaming", 100, 30),
            (kLargeDoc, "LargeDoc_200_streaming", 200, 30),
        ]

        var reports: [MemoryReport] = []
        for config in configs {
            sut.cleanUp()
            drainMemory()

            if let chunk = config.chunk {
                reports.append(measureStreamingMemory(document: config.doc, label: config.label, blockCount: config.blocks, chunkSize: chunk))
            } else {
                reports.append(measureStaticMemory(document: config.doc, label: config.label, blockCount: config.blocks))
            }
        }

        let formatter = ISO8601DateFormatter()
        let summary = MemorySummary(
            timestamp: formatter.string(from: Date()),
            reports: reports
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(summary),
              let json = String(data: data, encoding: .utf8) else {
            XCTFail("Failed to encode memory summary")
            return
        }

        print("\nMEMORY_JSON_BEGIN")
        print(json)
        print("MEMORY_JSON_END\n")
    }

    // MARK: - Helpers

    private func measureStaticMemory(document: String, label: String, blockCount: Int) -> MemoryReport {
        drainMemory()
        let baseline = getMemoryFootprint()

        sut.markdown = document
        sut.layoutIfNeeded()
        drainMemory()

        let peak = getMemoryFootprint()

        drainMemory()
        let steadyState = getMemoryFootprint()

        let peakDelta = peak > baseline ? peak - baseline : 0
        let steadyDelta = steadyState > baseline ? steadyState - baseline : 0

        return MemoryReport(
            document: label,
            blockCount: blockCount,
            mode: "static",
            baselineBytes: baseline,
            peakBytes: peak,
            steadyStateBytes: steadyState,
            peakDeltaMB: Double(peakDelta) / 1_048_576.0,
            steadyStateDeltaMB: Double(steadyDelta) / 1_048_576.0,
            bytesPerBlock: blockCount > 0 ? Double(steadyDelta) / Double(blockCount) : 0
        )
    }

    private func measureStreamingMemory(document: String, label: String, blockCount: Int, chunkSize: Int) -> MemoryReport {
        let chunks = makeStreamingChunks(from: document, chunkSize: chunkSize)

        drainMemory()
        let baseline = getMemoryFootprint()
        var peakFootprint: UInt64 = baseline

        sut.isStreaming = true
        var accumulated = ""

        for chunk in chunks {
            accumulated += chunk
            sut.markdown = accumulated
            sut.layoutIfNeeded()

            let current = getMemoryFootprint()
            if current > peakFootprint { peakFootprint = current }
        }

        sut.isStreaming = false
        sut.markdown = accumulated
        sut.layoutIfNeeded()
        drainMemory()

        let steadyState = getMemoryFootprint()
        if steadyState > peakFootprint { peakFootprint = steadyState }

        let peakDelta = peakFootprint > baseline ? peakFootprint - baseline : 0
        let steadyDelta = steadyState > baseline ? steadyState - baseline : 0

        return MemoryReport(
            document: label,
            blockCount: blockCount,
            mode: "streaming",
            baselineBytes: baseline,
            peakBytes: peakFootprint,
            steadyStateBytes: steadyState,
            peakDeltaMB: Double(peakDelta) / 1_048_576.0,
            steadyStateDeltaMB: Double(steadyDelta) / 1_048_576.0,
            bytesPerBlock: blockCount > 0 ? Double(steadyDelta) / Double(blockCount) : 0
        )
    }

    private func makeStreamingChunks(from text: String, chunkSize: Int) -> [String] {
        let scalars = Array(text.unicodeScalars)
        var chunks: [String] = []
        var i = 0
        while i < scalars.count {
            let end = min(i + chunkSize, scalars.count)
            let chunk = String(String.UnicodeScalarView(scalars[i..<end]))
            chunks.append(chunk)
            i = end
        }
        return chunks
    }

    private func attachMemoryReport(_ report: MemoryReport) {
        let text = """
        Document: \(report.document)
        Mode: \(report.mode)
        Blocks: \(report.blockCount)
        Baseline: \(formatBytes(report.baselineBytes))
        Peak: \(formatBytes(report.peakBytes)) (Δ \(String(format: "%.2f", report.peakDeltaMB)) MB)
        Steady: \(formatBytes(report.steadyStateBytes)) (Δ \(String(format: "%.2f", report.steadyStateDeltaMB)) MB)
        Per Block: \(formatBytes(UInt64(report.bytesPerBlock)))
        """
        let attachment = XCTAttachment(string: text)
        attachment.name = "Memory: \(report.document)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        if bytes >= 1_048_576 {
            return String(format: "%.2f MB", Double(bytes) / 1_048_576.0)
        } else if bytes >= 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024.0)
        }
        return "\(bytes) B"
    }

    private func assertMemoryBounds(
        _ report: MemoryReport,
        maxSteadyMB: Double,
        maxBytesPerBlock: Double,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertGreaterThan(report.steadyStateBytes, 0,
                             "Should have measurable memory usage",
                             file: file, line: line)
        XCTAssertLessThan(report.steadyStateDeltaMB, maxSteadyMB,
                          "\(report.document): steady-state \(String(format: "%.1f", report.steadyStateDeltaMB)) MB exceeds \(maxSteadyMB) MB ceiling",
                          file: file, line: line)
        XCTAssertLessThan(report.bytesPerBlock, maxBytesPerBlock,
                          "\(report.document): \(String(format: "%.0f", report.bytesPerBlock)) bytes/block exceeds \(String(format: "%.0f", maxBytesPerBlock)) ceiling",
                          file: file, line: line)
    }
}
// swiftlint:enable file_length function_body_length type_body_length
