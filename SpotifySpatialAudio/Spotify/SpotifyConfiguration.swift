import Foundation

struct SpotifyConfiguration: Sendable, Equatable {
  static let storedClientIDKey = "SpotifyClientID"

  static let defaultScopes = [
    "user-read-playback-state",
    "user-modify-playback-state",
  ]

  let clientID: String
  let scopes: [String]

  init(clientID: String, scopes: [String] = Self.defaultScopes) throws {
    let trimmedClientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedClientID.isEmpty else {
      throw SpotifyConfigurationError.missingClientID
    }

    self.clientID = trimmedClientID
    self.scopes = scopes
  }

  static func from(
    bundle: Bundle = .main,
    userDefaults: UserDefaults = .standard
  ) throws -> SpotifyConfiguration {
    let storedClientID = userDefaults.string(forKey: storedClientIDKey) ?? ""
    let bundledClientID = bundle.object(forInfoDictionaryKey: "SpotifyClientID") as? String ?? ""
    let clientID =
      storedClientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      ? bundledClientID
      : storedClientID
    return try SpotifyConfiguration(clientID: clientID)
  }
}

enum SpotifyConfigurationError: LocalizedError, Equatable {
  case missingClientID

  var errorDescription: String? {
    switch self {
    case .missingClientID:
      "Open Setup Guide and add your Spotify client ID."
    }
  }
}
