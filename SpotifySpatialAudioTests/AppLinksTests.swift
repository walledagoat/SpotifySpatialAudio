import Foundation
import Testing

@testable import SpotifySpatialAudio

struct AppLinksTests {
  @Test("Buy Me a Coffee uses a public profile path")
  func buyMeACoffeeURLUsesPublicProfilePath() {
    #expect(
      AppLinks.buyMeACoffeeURL(username: "wallemadeit")
        == URL(string: "https://buymeacoffee.com/wallemadeit")
    )
  }

  @Test("Buy Me a Coffee rejects placeholders and invalid values")
  func buyMeACoffeeURLRejectsPlaceholderAndInvalidValues() {
    #expect(AppLinks.buyMeACoffeeURL(username: "") == nil)
    #expect(AppLinks.buyMeACoffeeURL(username: "your_username") == nil)
    #expect(AppLinks.buyMeACoffeeURL(username: "not/a/username") == nil)
  }
}
