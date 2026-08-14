import AppKit
import Foundation

protocol SpotifyAuthenticating: Sendable {
  func isAuthenticated() async -> Bool
  @discardableResult func authenticate() async throws -> SpotifyToken
  func disconnect() async throws
}

protocol SpotifyTokenProviding: Sendable {
  func validAccessToken() async throws -> String
  func forceRefreshAccessToken() async throws -> String
}

protocol AuthorizationURLOpening: Sendable {
  func open(_ url: URL) async -> Bool
}

struct SystemAuthorizationURLOpener: AuthorizationURLOpening, Sendable {
  func open(_ url: URL) async -> Bool {
    await MainActor.run {
      NSWorkspace.shared.open(url)
    }
  }
}

enum SpotifyAuthError: LocalizedError, Equatable {
  case authorizationInProgress
  case invalidAuthorizationURL
  case browserCouldNotOpen
  case stateMismatch
  case authorizationDenied(String)
  case missingAuthorizationCode
  case notAuthenticated
  case tokenRequestFailed(status: Int, message: String?)
  case invalidTokenResponse(String)

  var errorDescription: String? {
    switch self {
    case .authorizationInProgress:
      "Spotify authorization is already in progress."
    case .invalidAuthorizationURL:
      "The Spotify authorization URL could not be created."
    case .browserCouldNotOpen:
      "The browser could not open Spotify authorization."
    case .stateMismatch:
      "Spotify authorization failed its security state check."
    case .authorizationDenied(let reason):
      "Spotify authorization was denied: \(reason)"
    case .missingAuthorizationCode:
      "Spotify did not return an authorization code."
    case .notAuthenticated:
      "Spotify authorization is required."
    case .tokenRequestFailed(let status, let message):
      if let message, !message.isEmpty {
        "Spotify token request failed (\(status)): \(message)"
      } else {
        "Spotify token request failed with status \(status)."
      }
    case .invalidTokenResponse(let message):
      "Spotify returned an invalid token response: \(message)"
    }
  }
}

actor SpotifyAuthManager: SpotifyAuthenticating, SpotifyTokenProviding {
  private let configuration: SpotifyConfiguration
  private let tokenStore: any TokenStoring
  private let dataLoader: any HTTPDataLoading
  private let urlOpener: any AuthorizationURLOpening
  private let accountsBaseURL: URL

  private var authorizationInProgress = false
  private var refreshTask: Task<SpotifyToken, any Error>?

  init(
    configuration: SpotifyConfiguration,
    tokenStore: any TokenStoring,
    dataLoader: any HTTPDataLoading = URLSessionDataLoader(),
    urlOpener: any AuthorizationURLOpening = SystemAuthorizationURLOpener(),
    accountsBaseURL: URL? = URL(string: "https://accounts.spotify.com")
  ) throws {
    guard let accountsBaseURL else {
      throw SpotifyAuthError.invalidAuthorizationURL
    }
    self.configuration = configuration
    self.tokenStore = tokenStore
    self.dataLoader = dataLoader
    self.urlOpener = urlOpener
    self.accountsBaseURL = accountsBaseURL
  }

  func isAuthenticated() -> Bool {
    (try? tokenStore.load()) != nil
  }

  @discardableResult
  func authenticate() async throws -> SpotifyToken {
    guard !authorizationInProgress else {
      throw SpotifyAuthError.authorizationInProgress
    }
    authorizationInProgress = true
    defer { authorizationInProgress = false }

    let pkce = try PKCE.generate()
    let state = try PKCE.generateState()
    let callbackServer = LoopbackCallbackServer()
    let redirectURL = try await callbackServer.start()
    defer { callbackServer.stop() }

    let authorizationURL = try makeAuthorizationURL(
      redirectURL: redirectURL,
      challenge: pkce.challenge,
      state: state
    )
    guard await urlOpener.open(authorizationURL) else {
      throw SpotifyAuthError.browserCouldNotOpen
    }

    let callback = try await callbackServer.waitForCallback()
    guard callback.state == state else {
      throw SpotifyAuthError.stateMismatch
    }
    if let error = callback.error {
      throw SpotifyAuthError.authorizationDenied(error)
    }
    guard let code = callback.code, !code.isEmpty else {
      throw SpotifyAuthError.missingAuthorizationCode
    }

    let token = try await exchangeAuthorizationCode(
      code,
      verifier: pkce.verifier,
      redirectURL: redirectURL
    )
    try tokenStore.save(token)
    return token
  }

  func disconnect() throws {
    try tokenStore.delete()
  }

  func validAccessToken() async throws -> String {
    guard let token = try tokenStore.load() else {
      throw SpotifyAuthError.notAuthenticated
    }
    if token.isValid() {
      return token.accessToken
    }
    return try await refresh(token).accessToken
  }

  func forceRefreshAccessToken() async throws -> String {
    guard let token = try tokenStore.load() else {
      throw SpotifyAuthError.notAuthenticated
    }
    return try await refresh(token).accessToken
  }

  private func makeAuthorizationURL(
    redirectURL: URL,
    challenge: String,
    state: String
  ) throws -> URL {
    var components = URLComponents(
      url: accountsBaseURL.appending(path: "authorize"),
      resolvingAgainstBaseURL: false
    )
    components?.queryItems = [
      URLQueryItem(name: "client_id", value: configuration.clientID),
      URLQueryItem(name: "response_type", value: "code"),
      URLQueryItem(name: "redirect_uri", value: redirectURL.absoluteString),
      URLQueryItem(name: "scope", value: configuration.scopes.joined(separator: " ")),
      URLQueryItem(name: "code_challenge_method", value: "S256"),
      URLQueryItem(name: "code_challenge", value: challenge),
      URLQueryItem(name: "state", value: state),
    ]
    guard let url = components?.url else {
      throw SpotifyAuthError.invalidAuthorizationURL
    }
    return url
  }

  private func exchangeAuthorizationCode(
    _ code: String,
    verifier: String,
    redirectURL: URL
  ) async throws -> SpotifyToken {
    let values = [
      "client_id": configuration.clientID,
      "grant_type": "authorization_code",
      "code": code,
      "redirect_uri": redirectURL.absoluteString,
      "code_verifier": verifier,
    ]
    let response = try await requestToken(values)
    guard let refreshToken = response.refreshToken, !refreshToken.isEmpty else {
      throw SpotifyAuthError.invalidTokenResponse("A refresh token was missing.")
    }
    return response.storedToken(refreshToken: refreshToken)
  }

  private func refresh(_ existingToken: SpotifyToken) async throws -> SpotifyToken {
    if let refreshTask {
      return try await refreshTask.value
    }

    let task = Task { try await performRefresh(existingToken) }
    refreshTask = task
    defer { refreshTask = nil }
    return try await task.value
  }

  private func performRefresh(_ existingToken: SpotifyToken) async throws -> SpotifyToken {
    let response = try await requestToken([
      "client_id": configuration.clientID,
      "grant_type": "refresh_token",
      "refresh_token": existingToken.refreshToken,
    ])
    let refreshedToken = response.storedToken(
      refreshToken: response.refreshToken ?? existingToken.refreshToken,
      fallbackScope: existingToken.scope
    )
    try tokenStore.save(refreshedToken)
    return refreshedToken
  }

  private func requestToken(_ formValues: [String: String]) async throws -> SpotifyTokenResponse {
    var request = URLRequest(url: accountsBaseURL.appending(path: "api/token"))
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.httpBody = FormURLEncoder.encode(formValues)

    let data: Data
    let response: HTTPURLResponse
    do {
      (data, response) = try await dataLoader.data(for: request)
    } catch {
      throw SpotifyAuthError.tokenRequestFailed(status: 0, message: error.localizedDescription)
    }

    guard (200..<300).contains(response.statusCode) else {
      let oauthError = try? JSONDecoder().decode(SpotifyOAuthErrorResponse.self, from: data)
      throw SpotifyAuthError.tokenRequestFailed(
        status: response.statusCode,
        message: oauthError?.errorDescription ?? oauthError?.error
      )
    }

    do {
      return try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
    } catch {
      throw SpotifyAuthError.invalidTokenResponse(error.localizedDescription)
    }
  }
}

private struct SpotifyTokenResponse: Decodable, Sendable {
  let accessToken: String
  let tokenType: String
  let scope: String?
  let expiresIn: TimeInterval
  let refreshToken: String?

  enum CodingKeys: String, CodingKey {
    case accessToken = "access_token"
    case tokenType = "token_type"
    case scope
    case expiresIn = "expires_in"
    case refreshToken = "refresh_token"
  }

  func storedToken(refreshToken: String, fallbackScope: String? = nil) -> SpotifyToken {
    SpotifyToken(
      accessToken: accessToken,
      refreshToken: refreshToken,
      tokenType: tokenType,
      scope: scope ?? fallbackScope,
      expiresAt: .now.addingTimeInterval(max(0, expiresIn))
    )
  }
}

private struct SpotifyOAuthErrorResponse: Decodable, Sendable {
  let error: String
  let errorDescription: String?

  enum CodingKeys: String, CodingKey {
    case error
    case errorDescription = "error_description"
  }
}
