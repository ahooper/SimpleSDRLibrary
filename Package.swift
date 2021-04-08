// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SimpleSDRLibrary",
    platforms: [
       .macOS(.v10_14),
    ],
    products: [
        .library(
            name: "SimpleSDRLibrary",
            targets: ["SimpleSDRC", "SimpleSDRLibrary"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "SimpleSDRC",
            dependencies: [],
            path: "Sources/SimpleSDRC",
            cSettings: [
                .headerSearchPath("Sources/SimpleSDRC/include")
            ]
        ),
        .systemLibrary(name: "Crspsdrapi", pkgConfig: "mirsdrapi-rsp"),
            // https://www.sdrplay.com/downloads/
            // MacOS Legacy API 2.13 RSP Control Library + Driver
        .target(
            name: "SimpleSDRLibrary",
            dependencies: ["SimpleSDRC", "Crspsdrapi"]),
        .testTarget(
            name: "SimpleSDRLibraryTests",
            dependencies: ["SimpleSDRLibrary", "SimpleSDRC", "Crspsdrapi"])
    ]
)
