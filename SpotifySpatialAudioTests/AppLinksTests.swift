import XCTest

@testable import SpotifySpatialAudio

final class AppLinksTests: XCTestCase {
  func testBuyMeACoffeeURLUsesPublicProfilePath() {
    XCTAssertEqual(
      AppLinks.buyMeACoffeeURL(username: "wallemadeit"),
      URL(string: "https://buymeacoffee.com/wallemadeit")
    )
  }

  func testBuyMeACoffeeURLRejectsPlaceholderAndInvalidValues() {
    XCTAssertNil(AppLinks.buyMeACoffeeURL(username: ""))
    XCTAssertNil(AppLinks.buyMeACoffeeURL(username: "your_username"))
    XCTAssertNil(AppLinks.buyMeACoffeeURL(username: "not/a/username"))
  }
}
