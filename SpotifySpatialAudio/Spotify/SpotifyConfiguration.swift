import Foundation

struct SpotifyConfiguration: Sendable, Equatable {
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

  static func from(bundle: Bundle = .main) throws -> SpotifyConfiguration {
    let clientID = bundle.object(forInfoDictionaryKey: "SpotifyClientID") as? String ?? ""
    return try SpotifyConfiguration(clientID: clientID)
  }
}

enum SpotifyConfigurationError: LocalizedError, Equatable {
  case missingClientID

  var errorDescription: String? {
    switch self {
    case .missingClientID:
      "Add your Spotify client ID to Config/Spotify.xcconfig."
    }
  }
}
