// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "STXMarkdownView",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "STXMarkdownView",
            targets: ["STXMarkdownView"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown", from: "0.7.3")
    ],
    targets: [
        .target(
            name: "STXMarkdownView",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown")
            ],
            path: "Sources/STXMarkdownView"
        )
    ]
)
