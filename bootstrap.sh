#!/bin/bash
mkdir CLIApp
cd CLIApp
swift package init --type executable --name CLIApp
cat > Package.swift << EOF
// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CLIApp",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "CLIApp",
            dependencies: [
                .product(name: "Collections", package: "swift-collections")
            ]
        ),
    ]
)
EOF

