import Foundation
import Testing

@testable import SpotifySpatialAudio

struct SpotifyResponseDecodingTests {
  @Test("Available device response decodes Spotify snake-case fields")
  func devicesResponse() throws {
    let json = try #require(
      #"""
      {
        "devices": [
          {
            "id": "safari-device",
            "is_active": false,
            "is_private_session": false,
            "is_restricted": false,
            "name": "Web Player (Safari)",
            "type": "Computer",
            "volume_percent": 73,
            "supports_volume": true
          }
        ]
      }
      """#.data(using: .utf8))

    let response = try JSONDecoder().decode(SpotifyDevicesResponse.self, from: json)
    let device = try #require(response.devices.first)

    #expect(device.id == "safari-device")
    #expect(device.name == "Web Player (Safari)")
    #expect(device.volumePercent == 73)
    #expect(device.supportsVolume)
    #expect(!device.isRestricted)
  }

  @Test("Playback response decodes the active item and device")
  func playbackResponse() throws {
    let json = try #require(
      #"""
      {
        "device": {
          "id": "desktop-device",
          "is_active": true,
          "is_private_session": false,
          "is_restricted": false,
          "name": "MacBook Pro",
          "type": "Computer",
          "volume_percent": 42,
          "supports_volume": true
        },
        "repeat_state": "off",
        "shuffle_state": false,
        "timestamp": 1710000000000,
        "progress_ms": 12000,
        "is_playing": true,
        "item": {
          "id": "track-id",
          "name": "Test Track",
          "type": "track",
          "uri": "spotify:track:track-id",
          "duration_ms": 200000,
          "artists": [
            {"id": "artist-id", "name": "Test Artist", "uri": "spotify:artist:artist-id"}
          ]
        },
        "currently_playing_type": "track"
      }
      """#.data(using: .utf8))

    let playback = try JSONDecoder().decode(SpotifyPlaybackState.self, from: json)

    #expect(playback.isPlaying)
    #expect(playback.device?.isActive == true)
    #expect(playback.item?.name == "Test Track")
    #expect(playback.item?.artists?.first?.name == "Test Artist")
    #expect(playback.progressMS == 12_000)
  }

  @Test("Playback response accepts no current item")
  func nilPlaybackItem() throws {
    let json = try #require(
      #"""
      {
        "device": null,
        "repeat_state": "off",
        "shuffle_state": false,
        "timestamp": 1710000000000,
        "progress_ms": null,
        "is_playing": false,
        "item": null,
        "currently_playing_type": "unknown"
      }
      """#.data(using: .utf8))

    let playback = try JSONDecoder().decode(SpotifyPlaybackState.self, from: json)

    #expect(!playback.isPlaying)
    #expect(playback.item == nil)
    #expect(playback.device == nil)
  }
}
