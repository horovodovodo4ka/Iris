// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Iris",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "IrisCore",
            targets: ["IrisCore"]
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
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "IrisCore",
            dependencies: [
                //                .target(name: "")
            ],
            path: "Iris/Classes/Core"
        ),
        .target(
            name: "IrisAlamofire",
            dependencies: [
                "IrisCore",
                "IrisLogging",
                "Alamofire"
            ],
            path: "Iris/Classes/Alamofire"
        ),
        .target(
            name: "IrisURLSession",
            dependencies: [
                "IrisCore",
                "IrisLogging"
            ],
            path: "Iris/Classes/URLSession"
        ),
        .target(
            name: "IrisDefaults",
            dependencies: [
                "IrisCore"
            ],
            path: "Iris/Classes/Defaults"
        ),
        .target(
            name: "IrisLogging",
            dependencies: [
                "IrisCore",
                "Astaroth"
            ],
            path: "Iris/Classes/Logging"
        )
    ]
)
