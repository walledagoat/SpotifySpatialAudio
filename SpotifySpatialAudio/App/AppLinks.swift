import Foundation

enum AppLinks {
  static let repository = URL(
    string: "https://github.com/walledagoat/SpotifySpatialAudio"
  )!

  static var buyMeACoffee: URL? {
    guard
      let username = Bundle.main.object(
        forInfoDictionaryKey: "BuyMeACoffeeUsername"
      ) as? String
    else {
      return nil
    }

    return buyMeACoffeeURL(username: username)
  }

  static func buyMeACoffeeURL(username: String) -> URL? {
    let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
    guard
      !trimmed.isEmpty,
      trimmed != "your_username",
      trimmed.range(of: "^[A-Za-z0-9._-]+$", options: .regularExpression) != nil
    else {
      return nil
    }

    var components = URLComponents()
    components.scheme = "https"
    components.host = "buymeacoffee.com"
    components.path = "/\(trimmed)"
    return components.url
  }
}
