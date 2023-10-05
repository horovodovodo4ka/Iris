// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Iris",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "Iris",
            targets: ["Iris"]
        ),
        .library(
            name: "IrisAlamofire",
            targets: ["IrisAlamofire"]
        ),
        .library(
            name: "IrisURLSession",
            targets: ["IrisURLSession"]
        ),
        .library(
            name: "IrisDefaults",
            targets: ["IrisDefaults"]
        ),
        .library(
            name: "IrisLogging",
            targets: ["IrisLogging"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire", from: "5.4.0"),
        .package(url: "https://github.com/horovodovodo4ka/astaroth-ios", from: "0.6.0"),
    ],
    targets: [
        .target(
            name: "Iris",
            dependencies: [],
            path: "Iris/Classes/Core"
        ),
        .target(
            name: "IrisAlamofire",
            dependencies: [
                "Iris",
                "IrisLogging",
                "Alamofire"
            ],
            path: "Iris/Classes/Alamofire"
        ),
        .target(
            name: "IrisURLSession",
            dependencies: [
                "Iris",
                "IrisLogging"
            ],
            path: "Iris/Classes/URLSession"
        ),
        .target(
            name: "IrisDefaults",
            dependencies: [
                "Iris"
            ],
            path: "Iris/Classes/Defaults"
        ),
        .target(
            name: "IrisLogging",
            dependencies: [
                "Iris",
                "Astaroth"
            ],
            path: "Iris/Classes/Logging"
        )
    ]
)
