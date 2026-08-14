import AppKit
import SwiftUI

@main
@MainActor
struct SpotifySpatialAudioApp: App {
  @StateObject private var appState: AppState

  init() {
    do {
      let configuration = try SpotifyConfiguration.from()
      let authManager = try SpotifyAuthManager(
        configuration: configuration,
        tokenStore: KeychainTokenStore()
      )
      let spotifyAPI = try SpotifyAPIClient(tokenProvider: authManager)
      let safariController = try SafariController()
      let discovery = SafariDeviceDiscovery(spotifyAPI: spotifyAPI)
      let coordinator = SpatialAudioCoordinator(
        spotifyAPI: spotifyAPI,
        safariController: safariController,
        deviceDiscovery: discovery
      )
      let state = AppState(
        authManager: authManager,
        coordinator: coordinator,
        safariController: safariController
      )
      _appState = StateObject(wrappedValue: state)
      Task { await state.refreshAuthenticationStatus() }
    } catch {
      _appState = StateObject(
        wrappedValue: AppState(
          authManager: nil,
          configurationError: error.localizedDescription
        )
      )
    }
  }

  var body: some Scene {
    MenuBarExtra("Spotify Spatial Audio", systemImage: "airpodspro") {
      Text("Spotify Spatial Audio")
        .font(.headline)

      Divider()

      Label(appState.statusText, systemImage: appState.statusSymbol)

      if appState.isAuthenticated {
        Label(
          appState.spatialAudioStatusText,
          systemImage: appState.spatialAudioStatusSymbol
        )

        if appState.canStopSpatialAudio {
          Button("Stop Spatial Audio") {
            Task { await appState.stopSpatialAudio() }
          }
        } else {
          Button("Start Spatial Audio") {
            Task { await appState.startSpatialAudio() }
          }
          .disabled(!appState.canStartSpatialAudio)
        }

        Button("Open Spotify Web Player") {
          Task { await appState.openSpotifyWebPlayer() }
        }
      }

      Button(appState.isAuthenticated ? "Reconnect Spotify" : "Connect Spotify") {
        Task { await appState.authenticate() }
      }
      .disabled(!appState.canAuthenticate)

      Divider()

      Button("Quit") {
        NSApplication.shared.terminate(nil)
      }
      .keyboardShortcut("q")
    }
    .menuBarExtraStyle(.menu)
    .commandsRemoved()
  }
}
