import Foundation

enum SafariDeviceDiscoveryError: LocalizedError, Equatable {
  case timedOut

  var errorDescription: String? {
    "Safari did not appear as a Spotify Connect device before the discovery timeout."
  }
}

actor SafariDeviceDiscovery {
  private let spotifyAPI: any SpotifyPlaybackAPI
  private let pollInterval: Duration
  private let maximumAttempts: Int
  private var cachedDeviceID: String?

  init(
    spotifyAPI: any SpotifyPlaybackAPI,
    pollInterval: Duration = .seconds(1),
    maximumAttempts: Int = 20
  ) {
    self.spotifyAPI = spotifyAPI
    self.pollInterval = pollInterval
    self.maximumAttempts = maximumAttempts
  }

  func discoverDevice(excluding baselineDeviceIDs: Set<String>) async throws -> SpotifyDevice {
    for attempt in 0..<maximumAttempts {
      let devices = try await spotifyAPI.availableDevices()
      if let device = SafariDeviceSelector.select(
        from: devices,
        excluding: baselineDeviceIDs,
        cachedDeviceID: cachedDeviceID
      ) {
        cachedDeviceID = device.id
        return device
      }

      if attempt < maximumAttempts - 1 {
        try await Task.sleep(for: pollInterval)
      }
    }

    throw SafariDeviceDiscoveryError.timedOut
  }

  func clearSessionCache() {
    cachedDeviceID = nil
  }
}

enum SafariDeviceSelector {
  static func select(
    from devices: [SpotifyDevice],
    excluding baselineDeviceIDs: Set<String>,
    cachedDeviceID: String?
  ) -> SpotifyDevice? {
    let controllable = devices.filter { !$0.isRestricted && $0.id != nil }

    if let cachedDeviceID,
      let cached = controllable.first(where: { $0.id == cachedDeviceID })
    {
      return cached
    }

    let newDevices = controllable.filter { device in
      guard let id = device.id else { return false }
      return !baselineDeviceIDs.contains(id)
    }

    if let browserLike =
      newDevices
      .filter(isBrowserLike)
      .max(by: { score($0) < score($1) })
    {
      return browserLike
    }

    // If exactly one new computer appeared immediately after opening Safari, the
    // new ID is a stronger signal than a display name controlled by Spotify.
    let newComputers = newDevices.filter { $0.type.localizedCaseInsensitiveContains("computer") }
    if newComputers.count == 1 {
      return newComputers[0]
    }

    // Safari may already have been open and therefore present in the baseline.
    return
      controllable
      .filter(isBrowserLike)
      .max(by: { score($0) < score($1) })
  }

  private static func isBrowserLike(_ device: SpotifyDevice) -> Bool {
    let normalizedName = device.name.lowercased()
    return normalizedName.contains("safari")
      || normalizedName.contains("web player")
      || normalizedName.contains("browser")
  }

  private static func score(_ device: SpotifyDevice) -> Int {
    let normalizedName = device.name.lowercased()
    var result = 0
    if normalizedName.contains("safari") { result += 8 }
    if normalizedName.contains("web player") { result += 5 }
    if normalizedName.contains("browser") { result += 3 }
    if device.type.localizedCaseInsensitiveContains("computer") { result += 1 }
    return result
  }
}
