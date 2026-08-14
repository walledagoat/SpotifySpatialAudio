import Foundation
import Testing

@testable import SpotifySpatialAudio

struct TokenStoreTests {
  @Test("Token persistence abstraction saves, loads, and deletes")
  func persistenceLifecycle() throws {
    let store: any TokenStoring = InMemoryTokenStore()
    let token = SpotifyToken(
      accessToken: "access",
      refreshToken: "refresh",
      tokenType: "Bearer",
      scope: "user-read-playback-state",
      expiresAt: Date(timeIntervalSince1970: 2_000_000_000)
    )

    #expect(try store.load() == nil)
    try store.save(token)
    #expect(try store.load() == token)
    try store.delete()
    #expect(try store.load() == nil)
  }

  @Test("Token validity honors the refresh leeway")
  func validityLeeway() {
    let now = Date(timeIntervalSince1970: 1_000)
    let token = SpotifyToken(
      accessToken: "access",
      refreshToken: "refresh",
      tokenType: "Bearer",
      scope: nil,
      expiresAt: Date(timeIntervalSince1970: 1_050)
    )

    #expect(token.isValid(at: now, leeway: 30))
    #expect(!token.isValid(at: now, leeway: 60))
  }
}

private final class InMemoryTokenStore: TokenStoring, @unchecked Sendable {
  private let lock = NSLock()
  private var token: SpotifyToken?

  func load() -> SpotifyToken? {
    lock.withLock { token }
  }

  func save(_ token: SpotifyToken) {
    lock.withLock { self.token = token }
  }

  func delete() {
    lock.withLock { token = nil }
  }
}
