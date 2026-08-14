import Foundation

protocol HTTPDataLoading: Sendable {
  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionDataLoader: HTTPDataLoading, Sendable {
  private let session: URLSession

  init(session: URLSession = .shared) {
    self.session = session
  }

  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw HTTPDataLoaderError.invalidResponse
    }
    return (data, httpResponse)
  }
}

enum HTTPDataLoaderError: LocalizedError {
  case invalidResponse

  var errorDescription: String? {
    "The server returned a non-HTTP response."
  }
}
