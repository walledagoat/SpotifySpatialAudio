import Foundation

struct SpotifyDevicesResponse: Codable, Sendable, Equatable {
  let devices: [SpotifyDevice]
}

struct SpotifyDevice: Codable, Sendable, Equatable, Identifiable {
  let id: String?
  let isActive: Bool
  let isPrivateSession: Bool
  let isRestricted: Bool
  let name: String
  let type: String
  let volumePercent: Int?
  let supportsVolume: Bool

  enum CodingKeys: String, CodingKey {
    case id
    case isActive = "is_active"
    case isPrivateSession = "is_private_session"
    case isRestricted = "is_restricted"
    case name
    case type
    case volumePercent = "volume_percent"
    case supportsVolume = "supports_volume"
  }
}

struct SpotifyPlaybackState: Codable, Sendable, Equatable {
  let device: SpotifyDevice?
  let repeatState: String?
  let shuffleState: Bool?
  let timestamp: Int?
  let progressMS: Int?
  let isPlaying: Bool
  let item: SpotifyPlayableItem?
  let currentlyPlayingType: String?

  enum CodingKeys: String, CodingKey {
    case device
    case repeatState = "repeat_state"
    case shuffleState = "shuffle_state"
    case timestamp
    case progressMS = "progress_ms"
    case isPlaying = "is_playing"
    case item
    case currentlyPlayingType = "currently_playing_type"
  }
}

struct SpotifyPlayableItem: Codable, Sendable, Equatable, Identifiable {
  let id: String?
  let name: String
  let type: String
  let uri: String
  let durationMS: Int?
  let artists: [SpotifyArtist]?

  enum CodingKeys: String, CodingKey {
    case id
    case name
    case type
    case uri
    case durationMS = "duration_ms"
    case artists
  }
}

struct SpotifyArtist: Codable, Sendable, Equatable, Identifiable {
  let id: String?
  let name: String
  let uri: String
}
