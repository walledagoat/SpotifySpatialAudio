import Foundation

typealias SpatialAudioStatusHandler = @Sendable (SpatialAudioState) async -> Void

protocol SpatialAudioCoordinating: Sendable {
  func activate(status: @escaping SpatialAudioStatusHandler) async throws
  func stop(status: @escaping SpatialAudioStatusHandler) async
}

enum SpatialAudioCoordinatorError: LocalizedError, Equatable {
  case activationInProgress
  case noPlayback
  case missingDeviceID
  case transferCouldNotBeVerified

  var errorDescription: String? {
    switch self {
    case .activationInProgress:
      "Spatial Audio activation is already in progress."
    case .noPlayback:
      "Start playback in Spotify Desktop before enabling Spatial Audio."
    case .missingDeviceID:
      "Spotify returned a Safari device without a usable device ID."
    case .transferCouldNotBeVerified:
      "Spotify did not confirm that playback moved to Safari."
    }
  }
}

actor SpatialAudioCoordinator: SpatialAudioCoordinating {
  private let spotifyAPI: any SpotifyPlaybackAPI
  private let safariController: any SafariControlling
  private let deviceDiscovery: SafariDeviceDiscovery
  private let verificationInterval: Duration
  private let verificationAttempts: Int

  private var activationInProgress = false

  init(
    spotifyAPI: any SpotifyPlaybackAPI,
    safariController: any SafariControlling,
    deviceDiscovery: SafariDeviceDiscovery,
    verificationInterval: Duration = .seconds(1),
    verificationAttempts: Int = 10
  ) {
    self.spotifyAPI = spotifyAPI
    self.safariController = safariController
    self.deviceDiscovery = deviceDiscovery
    self.verificationInterval = verificationInterval
    self.verificationAttempts = verificationAttempts
  }

  func activate(status: @escaping SpatialAudioStatusHandler) async throws {
    guard !activationInProgress else {
      throw SpatialAudioCoordinatorError.activationInProgress
    }
    activationInProgress = true
    defer { activationInProgress = false }

    let initialPlayback = try await spotifyAPI.currentPlayback()
    guard let initialPlayback, initialPlayback.isPlaying else {
      throw SpatialAudioCoordinatorError.noPlayback
    }

    let baselineDevices = try await spotifyAPI.availableDevices()
    let baselineIDs = Set(baselineDevices.compactMap(\.id))

    await status(.preparingSafari)
    try await safariController.openWebPlayer()

    let safariDevice = try await deviceDiscovery.discoverDevice(excluding: baselineIDs)
    guard let safariDeviceID = safariDevice.id else {
      throw SpatialAudioCoordinatorError.missingDeviceID
    }

    await status(.transferringPlayback)
    try await spotifyAPI.transferPlayback(to: safariDeviceID, play: true)

    var verified = false
    for attempt in 0..<verificationAttempts {
      let playback = try await spotifyAPI.currentPlayback()
      if playback?.device?.id == safariDeviceID, playback?.isPlaying == true {
        verified = true
        break
      }
      if attempt < verificationAttempts - 1 {
        try await Task.sleep(for: verificationInterval)
      }
    }
    guard verified else {
      throw SpatialAudioCoordinatorError.transferCouldNotBeVerified
    }

    // Transfer with play=true is verified first. No synthetic Space keypress is used.
    // Minimization is best-effort because denying Automation should not stop audio.
    try? await safariController.minimizeWebPlayer()
    await status(.active)
  }

  func stop(status: @escaping SpatialAudioStatusHandler) async {
    await deviceDiscovery.clearSessionCache()
    await status(.stopped)
  }
}
