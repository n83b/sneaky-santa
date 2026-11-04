// swift-tools-version: 5.9

// Swift Playgrounds app project for Sneaky Santa.
// Open the SneakySanta.swiftpm folder in Swift Playgrounds on iPad (or in Xcode on a Mac).

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "Sneaky Santa",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .iOSApplication(
            name: "Sneaky Santa",
            targets: ["AppModule"],
            bundleIdentifier: "com.n83b.sneakysanta",
            displayVersion: "1.0",
            bundleVersion: "1",
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .landscapeRight,
                .landscapeLeft,
                .portrait,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "."
        )
    ]
)
