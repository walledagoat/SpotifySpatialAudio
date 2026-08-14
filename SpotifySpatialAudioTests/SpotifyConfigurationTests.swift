import Foundation
import Testing

@testable import SpotifySpatialAudio

struct SpotifyConfigurationTests {
  @Test("Client IDs are trimmed before use")
  func trimsClientID() throws {
    let configuration = try SpotifyConfiguration(clientID: "  public-client-id\n")

    #expect(configuration.clientID == "public-client-id")
  }

  @Test("A missing Client ID points users to the setup guide")
  func missingClientIDMessage() {
    #expect(throws: SpotifyConfigurationError.missingClientID) {
      try SpotifyConfiguration(clientID: "   ")
    }
    #expect(
      SpotifyConfigurationError.missingClientID.errorDescription
        == "Open Setup Guide and add your Spotify client ID."
    )
  }

  @Test("A Client ID saved by onboarding overrides build configuration")
  func storedClientIDWins() throws {
    let suiteName = "SpotifyConfigurationTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set("saved-client-id", forKey: SpotifyConfiguration.storedClientIDKey)

    let configuration = try SpotifyConfiguration.from(
      bundle: .main,
      userDefaults: defaults
    )

    #expect(configuration.clientID == "saved-client-id")
  }
}
