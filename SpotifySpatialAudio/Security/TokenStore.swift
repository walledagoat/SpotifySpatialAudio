import Foundation

struct SpotifyToken: Codable, Sendable, Equatable {
  let accessToken: String
  let refreshToken: String
  let tokenType: String
  let scope: String?
  let expiresAt: Date

  func isValid(at date: Date = .now, leeway: TimeInterval = 60) -> Bool {
    expiresAt.timeIntervalSince(date) > leeway
  }
}

protocol TokenStoring: Sendable {
  func load() throws -> SpotifyToken?
  func save(_ token: SpotifyToken) throws
  func delete() throws
}

enum TokenStoreError: LocalizedError, Equatable {
  case unexpectedData
  case keychain(OSStatus)
  case encoding(String)
  case decoding(String)

  var errorDescription: String? {
    switch self {
    case .unexpectedData:
      "The Keychain returned data in an unexpected format."
    case .keychain(let status):
      "The Keychain operation failed with status \(status)."
    case .encoding(let message):
      "The Spotify token could not be encoded: \(message)"
    case .decoding(let message):
      "The saved Spotify token could not be decoded: \(message)"
    }
  }
}
