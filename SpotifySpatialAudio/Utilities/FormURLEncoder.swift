import Foundation

enum FormURLEncoder {
  static func encode(_ values: [String: String]) -> Data {
    values
      .sorted { $0.key < $1.key }
      .map { "\(escape($0.key))=\(escape($0.value))" }
      .joined(separator: "&")
      .data(using: .utf8) ?? Data()
  }

  private static func escape(_ value: String) -> String {
    let unreserved = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~".utf8)
    return value.utf8.map { byte in
      if unreserved.contains(byte) {
        return String(UnicodeScalar(byte))
      }
      if byte == 0x20 {
        return "+"
      }
      return String(format: "%%%02X", byte)
    }.joined()
  }
}
