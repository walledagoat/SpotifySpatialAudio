// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "SpotifySpatialAudio",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(
      name: "SpotifySpatialAudio",
      targets: ["SpotifySpatialAudio"]
    )
  ],
  targets: [
    .executableTarget(
      name: "SpotifySpatialAudio",
      path: "SpotifySpatialAudio",
      exclude: ["Resources/Info.plist", "Resources/SpotifySpatialAudio.entitlements"]
    ),
    .testTarget(
      name: "SpotifySpatialAudioTests",
      dependencies: ["SpotifySpatialAudio"],
      path: "SpotifySpatialAudioTests"
    ),
  ]
)
