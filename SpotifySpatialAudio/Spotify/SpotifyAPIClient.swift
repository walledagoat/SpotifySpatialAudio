import Foundation

protocol SpotifyPlaybackAPI: Sendable {
  func availableDevices() async throws -> [SpotifyDevice]
  func currentPlayback() async throws -> SpotifyPlaybackState?
  func transferPlayback(to deviceID: String, play: Bool?) async throws
  func resumePlayback(on deviceID: String?) async throws
}

enum SpotifyAPIError: LocalizedError, Sendable, Equatable {
  case authentication(String)
  case unauthorized
  case forbidden(String?)
  case notFound(String?)
  case rateLimited(retryAfter: TimeInterval)
  case httpStatus(Int, String?)
  case invalidResponse
  case network(String)
  case encoding(String)
  case decoding(String)

  var errorDescription: String? {
    switch self {
    case .authentication(let message):
      "Spotify authentication failed: \(message)"
    case .unauthorized:
      "Spotify authorization has expired. Reconnect Spotify."
    case .forbidden(let message):
      message ?? "Spotify refused this playback operation. Spotify Premium may be required."
    case .notFound(let message):
      message ?? "Spotify has no active playback device."
    case .rateLimited(let retryAfter):
      "Spotify rate-limited the request. Try again in \(Int(retryAfter.rounded(.up))) seconds."
    case .httpStatus(let status, let message):
      message ?? "Spotify returned HTTP status \(status)."
    case .invalidResponse:
      "Spotify returned an invalid response."
    case .network(let message):
      "Spotify could not be reached: \(message)"
    case .encoding(let message):
      "The Spotify request could not be encoded: \(message)"
    case .decoding(let message):
      "The Spotify response could not be decoded: \(message)"
    }
  }
}

actor SpotifyAPIClient {
  private let tokenProvider: any SpotifyTokenProviding
  private let dataLoader: any HTTPDataLoading
  private let apiBaseURL: URL
  private let maximumRateLimitRetries: Int

  init(
    tokenProvider: any SpotifyTokenProviding,
    dataLoader: any HTTPDataLoading = URLSessionDataLoader(),
    apiBaseURL: URL? = URL(string: "https://api.spotify.com/v1"),
    maximumRateLimitRetries: Int = 2
  ) throws {
    guard let apiBaseURL else {
      throw SpotifyAPIError.invalidResponse
    }
    self.tokenProvider = tokenProvider
    self.dataLoader = dataLoader
    self.apiBaseURL = apiBaseURL
    self.maximumRateLimitRetries = maximumRateLimitRetries
  }

  func availableDevices() async throws -> [SpotifyDevice] {
    let data = try await request(path: "me/player/devices")
    do {
      return try JSONDecoder().decode(SpotifyDevicesResponse.self, from: data).devices
    } catch {
      throw SpotifyAPIError.decoding(error.localizedDescription)
    }
  }

  func currentPlayback() async throws -> SpotifyPlaybackState? {
    let data = try await request(path: "me/player", allowsEmptyResponse: true)
    guard !data.isEmpty else { return nil }
    do {
      return try JSONDecoder().decode(SpotifyPlaybackState.self, from: data)
    } catch {
      throw SpotifyAPIError.decoding(error.localizedDescription)
    }
  }

  func transferPlayback(to deviceID: String, play: Bool? = nil) async throws {
    struct TransferBody: Encodable {
      let deviceIDs: [String]
      let play: Bool?

      enum CodingKeys: String, CodingKey {
        case deviceIDs = "device_ids"
        case play
      }
    }

    let body: Data
    do {
      body = try JSONEncoder().encode(TransferBody(deviceIDs: [deviceID], play: play))
    } catch {
      throw SpotifyAPIError.encoding(error.localizedDescription)
    }
    _ = try await request(
      path: "me/player",
      method: "PUT",
      body: body,
      allowsEmptyResponse: true
    )
  }

  func resumePlayback(on deviceID: String? = nil) async throws {
    var queryItems: [URLQueryItem] = []
    if let deviceID {
      queryItems.append(URLQueryItem(name: "device_id", value: deviceID))
    }
    _ = try await request(
      path: "me/player/play",
      method: "PUT",
      queryItems: queryItems,
      allowsEmptyResponse: true
    )
  }

  private func request(
    path: String,
    method: String = "GET",
    queryItems: [URLQueryItem] = [],
    body: Data? = nil,
    allowsEmptyResponse: Bool = false
  ) async throws -> Data {
    let accessToken: String
    do {
      accessToken = try await tokenProvider.validAccessToken()
    } catch {
      throw SpotifyAPIError.authentication(error.localizedDescription)
    }

    var request = try makeRequest(
      path: path,
      method: method,
      queryItems: queryItems,
      body: body,
      accessToken: accessToken
    )
    var didRefresh = false
    var rateLimitRetries = 0

    while true {
      let data: Data
      let response: HTTPURLResponse
      do {
        (data, response) = try await dataLoader.data(for: request)
      } catch {
        throw SpotifyAPIError.network(error.localizedDescription)
      }

      if (200..<300).contains(response.statusCode) {
        if !allowsEmptyResponse && data.isEmpty {
          throw SpotifyAPIError.invalidResponse
        }
        return data
      }

      if response.statusCode == 401, !didRefresh {
        do {
          let refreshedToken = try await tokenProvider.forceRefreshAccessToken()
          request.setValue("Bearer \(refreshedToken)", forHTTPHeaderField: "Authorization")
          didRefresh = true
          continue
        } catch {
          throw SpotifyAPIError.authentication(error.localizedDescription)
        }
      }

      if response.statusCode == 429 {
        let retryAfter = Self.retryAfter(from: response)
        if rateLimitRetries < maximumRateLimitRetries {
          rateLimitRetries += 1
          try await Task.sleep(for: .seconds(retryAfter))
          continue
        }
        throw SpotifyAPIError.rateLimited(retryAfter: retryAfter)
      }

      let message = Self.errorMessage(from: data)
      switch response.statusCode {
      case 401:
        throw SpotifyAPIError.unauthorized
      case 403:
        throw SpotifyAPIError.forbidden(message)
      case 404:
        throw SpotifyAPIError.notFound(message)
      default:
        throw SpotifyAPIError.httpStatus(response.statusCode, message)
      }
    }
  }

  private func makeRequest(
    path: String,
    method: String,
    queryItems: [URLQueryItem],
    body: Data?,
    accessToken: String
  ) throws -> URLRequest {
    var components = URLComponents(
      url: apiBaseURL.appending(path: path),
      resolvingAgainstBaseURL: false
    )
    if !queryItems.isEmpty {
      components?.queryItems = queryItems
    }
    guard let url = components?.url else {
      throw SpotifyAPIError.invalidResponse
    }

    var request = URLRequest(url: url)
    request.httpMethod = method
    request.httpBody = body
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if body != nil {
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    return request
  }

  private static func retryAfter(from response: HTTPURLResponse) -> TimeInterval {
    guard let header = response.value(forHTTPHeaderField: "Retry-After"),
      let seconds = TimeInterval(header),
      seconds >= 0
    else {
      return 1
    }
    return seconds
  }

  private static func errorMessage(from data: Data) -> String? {
    (try? JSONDecoder().decode(SpotifyWebAPIErrorEnvelope.self, from: data))?.error.message
  }
}

extension SpotifyAPIClient: SpotifyPlaybackAPI {}

private struct SpotifyWebAPIErrorEnvelope: Decodable {
  struct APIError: Decodable {
    let status: Int
    let message: String
  }

  let error: APIError
}
