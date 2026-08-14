import Foundation
import Testing

@testable import SpotifySpatialAudio

struct PKCETests {
  @Test("RFC 7636 S256 challenge vector")
  func rfcChallengeVector() {
    let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
    #expect(PKCE.challenge(for: verifier) == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
  }

  @Test("Generated verifier is URL-safe and within the PKCE length range")
  func generatedVerifier() throws {
    let credentials = try PKCE.generate()
    let allowed = CharacterSet(
      charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")

    #expect((43...128).contains(credentials.verifier.count))
    #expect(credentials.verifier.unicodeScalars.allSatisfy(allowed.contains))
    #expect(credentials.challenge == PKCE.challenge(for: credentials.verifier))
    #expect(!credentials.challenge.contains("="))
  }

  @Test("OAuth state values are independent and URL-safe")
  func stateGeneration() throws {
    let first = try PKCE.generateState()
    let second = try PKCE.generateState()

    #expect(first != second)
    #expect(!first.contains("+"))
    #expect(!first.contains("/"))
    #expect(!first.contains("="))
  }
}
