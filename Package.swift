// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "otracker",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "otracker",
            targets: ["otracker"]),
    ],
    dependencies: [
        .package(url: "https://github.com/davedelong/DDMathParser", from: "3.1.0"),
        .package(url: "https://github.com/WenchaoD/FSCalendar", from: "2.8.4"),
        .package(url: "https://github.com/ChartsOrg/Charts", from: "5.1.0")
    ],
    targets: [
        .target(
            name: "otracker",
            dependencies: [
                .product(name: "DDMathParser", package: "DDMathParser"),
                .product(name: "FSCalendar", package: "FSCalendar"),
                .product(name: "DGCharts", package: "Charts")
            ]),
        .testTarget(
            name: "otrackerTests",
            dependencies: ["otracker"]),
    ]
) 