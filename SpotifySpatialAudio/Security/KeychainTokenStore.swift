import Foundation
import Security

struct KeychainTokenStore: TokenStoring, Sendable {
  private let service: String
  private let account: String

  init(
    service: String = "com.walentinrieder.SpotifySpatialAudio",
    account: String = "spotify-oauth-token"
  ) {
    self.service = service
    self.account = account
  }

  func load() throws -> SpotifyToken? {
    var query = baseQuery
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound {
      return nil
    }
    guard status == errSecSuccess else {
      throw TokenStoreError.keychain(status)
    }
    guard let data = result as? Data else {
      throw TokenStoreError.unexpectedData
    }

    do {
      return try JSONDecoder().decode(SpotifyToken.self, from: data)
    } catch {
      throw TokenStoreError.decoding(error.localizedDescription)
    }
  }

  func save(_ token: SpotifyToken) throws {
    let data: Data
    do {
      data = try JSONEncoder().encode(token)
    } catch {
      throw TokenStoreError.encoding(error.localizedDescription)
    }

    let attributes: [String: Any] = [
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]

    let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
    if updateStatus == errSecSuccess {
      return
    }
    guard updateStatus == errSecItemNotFound else {
      throw TokenStoreError.keychain(updateStatus)
    }

    var item = baseQuery
    for (key, value) in attributes {
      item[key] = value
    }
    let addStatus = SecItemAdd(item as CFDictionary, nil)
    guard addStatus == errSecSuccess else {
      throw TokenStoreError.keychain(addStatus)
    }
  }

  func delete() throws {
    let status = SecItemDelete(baseQuery as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw TokenStoreError.keychain(status)
    }
  }

  private var baseQuery: [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
  }
}
