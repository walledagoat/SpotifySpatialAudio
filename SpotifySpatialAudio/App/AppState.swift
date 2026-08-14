import Combine
import Foundation

enum SpatialAudioState: Sendable, Equatable {
  case stopped
  case authorizing
  case waitingForSpotify
  case preparingSafari
  case transferringPlayback
  case active
  case error(String)
}

enum SpotifyAuthenticationState: Sendable, Equatable {
  case checking
  case notAuthenticated
  case authenticating
  case authenticated
  case unavailable(String)
  case error(String)
}

@MainActor
final class AppState: ObservableObject {
  private let authManager: (any SpotifyAuthenticating)?
  private let coordinator: (any SpatialAudioCoordinating)?
  private let safariController: (any SafariControlling)?

  @Published var spatialAudioState: SpatialAudioState = .stopped
  @Published var authenticationState: SpotifyAuthenticationState

  init(
    authManager: (any SpotifyAuthenticating)?,
    coordinator: (any SpatialAudioCoordinating)? = nil,
    safariController: (any SafariControlling)? = nil,
    configurationError: String? = nil
  ) {
    self.authManager = authManager
    self.coordinator = coordinator
    self.safariController = safariController
    if let configurationError {
      authenticationState = .unavailable(configurationError)
    } else {
      authenticationState = .checking
    }
  }

  var statusText: String {
    switch authenticationState {
    case .checking:
      "Checking Spotify authorization…"
    case .notAuthenticated:
      "Spotify authorization required"
    case .authenticating:
      "Authorizing Spotify…"
    case .authenticated:
      "Spotify connected"
    case .unavailable(let message), .error(let message):
      message
    }
  }

  var statusSymbol: String {
    switch authenticationState {
    case .authenticated:
      "checkmark.circle.fill"
    case .checking, .authenticating:
      "clock"
    case .notAuthenticated:
      "person.crop.circle.badge.exclamationmark"
    case .unavailable, .error:
      "exclamationmark.triangle.fill"
    }
  }

  var canAuthenticate: Bool {
    authManager != nil && authenticationState != .authenticating
  }

  var isAuthenticated: Bool {
    authenticationState == .authenticated
  }

  var spatialAudioStatusText: String {
    switch spatialAudioState {
    case .stopped:
      "Spatial Audio stopped"
    case .authorizing:
      "Authorizing Spotify…"
    case .waitingForSpotify:
      "Waiting for Spotify playback"
    case .preparingSafari:
      "Preparing Safari…"
    case .transferringPlayback:
      "Transferring playback…"
    case .active:
      "Spatial Audio active"
    case .error(let message):
      message
    }
  }

  var spatialAudioStatusSymbol: String {
    switch spatialAudioState {
    case .active:
      "waveform.circle.fill"
    case .preparingSafari, .transferringPlayback, .waitingForSpotify, .authorizing:
      "arrow.triangle.2.circlepath"
    case .error:
      "exclamationmark.triangle.fill"
    case .stopped:
      "waveform.circle"
    }
  }

  var canStartSpatialAudio: Bool {
    isAuthenticated && coordinator != nil && spatialAudioState == .stopped
  }

  var canStopSpatialAudio: Bool {
    switch spatialAudioState {
    case .preparingSafari, .transferringPlayback, .active, .error:
      true
    default:
      false
    }
  }

  func refreshAuthenticationStatus() async {
    guard let authManager else { return }
    guard authenticationState != .authenticating else { return }
    authenticationState = .checking
    authenticationState =
      await authManager.isAuthenticated()
      ? .authenticated
      : .notAuthenticated
  }

  func authenticate() async {
    guard let authManager else { return }
    authenticationState = .authenticating
    do {
      try await authManager.authenticate()
      authenticationState = .authenticated
    } catch {
      authenticationState = .error(error.localizedDescription)
    }
  }

  func startSpatialAudio() async {
    guard let coordinator else { return }
    spatialAudioState = .waitingForSpotify
    do {
      try await coordinator.activate { [weak self] state in
        await self?.setSpatialAudioState(state)
      }
    } catch {
      spatialAudioState = .error(error.localizedDescription)
    }
  }

  func stopSpatialAudio() async {
    guard let coordinator else {
      spatialAudioState = .stopped
      return
    }
    await coordinator.stop { [weak self] state in
      await self?.setSpatialAudioState(state)
    }
  }

  func openSpotifyWebPlayer() async {
    guard let safariController else { return }
    do {
      try await safariController.openWebPlayer()
    } catch {
      spatialAudioState = .error(error.localizedDescription)
    }
  }

  private func setSpatialAudioState(_ state: SpatialAudioState) {
    spatialAudioState = state
  }
}
