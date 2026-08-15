import Combine
import Foundation

@MainActor
final class AppController: ObservableObject {
  static let completedSetupKey = "HasCompletedSpotifySetup"

  @Published private(set) var appState: AppState
  @Published private(set) var clientID: String
  @Published var isShowingSetup: Bool

  private let bundle: Bundle
  private let userDefaults: UserDefaults
  private let tokenStore: KeychainTokenStore
  private var shouldPresentSetupOnLaunch: Bool

  init(
    bundle: Bundle = .main,
    userDefaults: UserDefaults = .standard,
    tokenStore: KeychainTokenStore = KeychainTokenStore()
  ) {
    self.bundle = bundle
    self.userDefaults = userDefaults
    self.tokenStore = tokenStore

    do {
      let configuration = try SpotifyConfiguration.from(
        bundle: bundle,
        userDefaults: userDefaults
      )
      clientID = configuration.clientID
      let state = try Self.makeAppState(
        configuration: configuration,
        tokenStore: tokenStore
      )
      appState = state
      isShowingSetup = false
      shouldPresentSetupOnLaunch = !userDefaults.bool(forKey: Self.completedSetupKey)
      Task { await state.refreshAuthenticationStatus() }
    } catch {
      clientID = ""
      appState = AppState(
        authManager: nil,
        configurationError: error.localizedDescription
      )
      isShowingSetup = false
      shouldPresentSetupOnLaunch = true
    }
  }

  func saveClientID(_ clientID: String) throws {
    let configuration = try SpotifyConfiguration(clientID: clientID)
    let didChangeClient = configuration.clientID != self.clientID

    if didChangeClient {
      try tokenStore.delete()
    }

    let state = try Self.makeAppState(
      configuration: configuration,
      tokenStore: tokenStore
    )
    userDefaults.set(configuration.clientID, forKey: SpotifyConfiguration.storedClientIDKey)
    self.clientID = configuration.clientID
    appState = state
    Task { await state.refreshAuthenticationStatus() }
  }

  func showSetup() {
    shouldPresentSetupOnLaunch = false
    isShowingSetup = true
  }

  func presentSetupOnLaunchIfNeeded() async {
    guard shouldPresentSetupOnLaunch else { return }
    shouldPresentSetupOnLaunch = false
    await Task.yield()
    isShowingSetup = true
  }

  func completeSetup() {
    userDefaults.set(true, forKey: Self.completedSetupKey)
    isShowingSetup = false
  }

  private static func makeAppState(
    configuration: SpotifyConfiguration,
    tokenStore: KeychainTokenStore
  ) throws -> AppState {
    let authManager = try SpotifyAuthManager(
      configuration: configuration,
      tokenStore: tokenStore
    )
    let spotifyAPI = try SpotifyAPIClient(tokenProvider: authManager)
    let safariController = try SafariController()
    let discovery = SafariDeviceDiscovery(spotifyAPI: spotifyAPI)
    let coordinator = SpatialAudioCoordinator(
      spotifyAPI: spotifyAPI,
      safariController: safariController,
      deviceDiscovery: discovery
    )
    return AppState(
      authManager: authManager,
      coordinator: coordinator,
      safariController: safariController
    )
  }
}
