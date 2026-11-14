// swift-tools-version: 5.9
// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Cinder and Crown LLC

import PackageDescription

let package = Package(
    name: "GameRules",
    platforms: [
        .macOS(.v13),
        .iOS(.v17),
    ],
    products: [
        .library(name: "GameRules", targets: ["GameRules"]),
    ],
    targets: [
        .target(name: "GameRules"),
        .testTarget(
            name: "GameRulesTests",
            dependencies: ["GameRules"]
        ),
    ]
)
