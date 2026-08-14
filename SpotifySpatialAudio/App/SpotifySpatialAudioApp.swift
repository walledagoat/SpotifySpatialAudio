import AppKit
import SwiftUI

@main
@MainActor
struct SpotifySpatialAudioApp: App {
  @NSApplicationDelegateAdaptor(SpotifySpatialAudioAppDelegate.self)
  private var appDelegate
  @StateObject private var controller: AppController

  init() {
    _controller = StateObject(wrappedValue: AppController())
  }

  var body: some Scene {
    Window("Spotify Spatial Audio", id: "main") {
      MainWindowView(
        appState: controller.appState,
        onShowSetup: controller.showSetup
      )
      .sheet(isPresented: $controller.isShowingSetup) {
        SetupGuideView(controller: controller)
      }
      .task {
        await controller.presentSetupOnLaunchIfNeeded()
      }
    }
    .defaultSize(width: 760, height: 560)

    MenuBarExtra("Spotify Spatial Audio", systemImage: "airpodspro") {
      MenuBarContentView(controller: controller)
    }
    .menuBarExtraStyle(.menu)
    .commandsRemoved()
  }
}

private struct MenuBarContentView: View {
  @ObservedObject var controller: AppController
  @Environment(\.openWindow) private var openWindow

  private var appState: AppState {
    controller.appState
  }

  var body: some View {
    Button("Open Spotify Spatial Audio") {
      openWindow(id: "main")
      DispatchQueue.main.async {
        NSApplication.shared.activate(ignoringOtherApps: true)
      }
    }
    .keyboardShortcut("o")

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
    } else {
      Button("Connect Spotify") {
        Task { await appState.authenticate() }
      }
      .disabled(!appState.canAuthenticate)
    }

    Divider()

    Button("Setup Guide…") {
      openWindow(id: "main")
      controller.showSetup()
      DispatchQueue.main.async {
        NSApplication.shared.activate(ignoringOtherApps: true)
      }
    }

    Divider()

    Button("Quit") {
      NSApplication.shared.terminate(nil)
    }
    .keyboardShortcut("q")
  }
}
