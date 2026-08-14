import CryptoKit
import Foundation
import Security

struct PKCECredentials: Sendable, Equatable {
  let verifier: String
  let challenge: String
}

enum PKCEError: LocalizedError, Equatable {
  case randomGenerationFailed(OSStatus)

  var errorDescription: String? {
    switch self {
    case .randomGenerationFailed(let status):
      "Secure random generation failed with status \(status)."
    }
  }
}

enum PKCE {
  static func generate(byteCount: Int = 64) throws -> PKCECredentials {
    var bytes = [UInt8](repeating: 0, count: byteCount)
    let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
    guard status == errSecSuccess else {
      throw PKCEError.randomGenerationFailed(status)
    }

    let verifier = base64URLEncoded(Data(bytes))
    return PKCECredentials(
      verifier: verifier,
      challenge: challenge(for: verifier)
    )
  }

  static func challenge(for verifier: String) -> String {
    let digest = SHA256.hash(data: Data(verifier.utf8))
    return base64URLEncoded(Data(digest))
  }

  static func generateState(byteCount: Int = 32) throws -> String {
    var bytes = [UInt8](repeating: 0, count: byteCount)
    let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
    guard status == errSecSuccess else {
      throw PKCEError.randomGenerationFailed(status)
    }
    return base64URLEncoded(Data(bytes))
  }

  private static func base64URLEncoded(_ data: Data) -> String {
    data.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
}
