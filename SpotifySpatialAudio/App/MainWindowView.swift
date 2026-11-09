import AppKit
import SwiftUI

struct MainWindowView: View {
  @ObservedObject var appState: AppState
  let buyMeACoffeeURL: URL?
  let onShowSetup: () -> Void
  @Environment(\.openURL) private var openURL

  init(
    appState: AppState,
    buyMeACoffeeURL: URL? = AppLinks.buyMeACoffee,
    onShowSetup: @escaping () -> Void = {}
  ) {
    _appState = ObservedObject(wrappedValue: appState)
    self.buyMeACoffeeURL = buyMeACoffeeURL
    self.onShowSetup = onShowSetup
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 26) {
        introduction
        Divider()
        adaptiveContent
        privacyNote
      }
      .padding(32)
      .frame(maxWidth: 900)
      .frame(maxWidth: .infinity)
    }
    .frame(minWidth: 640, minHeight: 500)
    .toolbar {
      ToolbarItemGroup(placement: .primaryAction) {
        Button(action: onShowSetup) {
          Label("Setup Guide", systemImage: "questionmark.circle")
        }
        .labelStyle(.iconOnly)
        .help("Open Setup Guide")
        .accessibilityLabel("Open Setup Guide")

        Button {
          openURL(AppLinks.repository)
        } label: {
          Label("View on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
        }
        .labelStyle(.iconOnly)
        .help("View Spotify Spatial Audio on GitHub")
        .accessibilityLabel("View on GitHub")

        Button {
          guard let url = buyMeACoffeeURL else { return }
          openURL(url)
        } label: {
          Label("Buy me a coffee", systemImage: "cup.and.saucer.fill")
        }
        .labelStyle(.iconOnly)
        .disabled(buyMeACoffeeURL == nil)
        .help(
          buyMeACoffeeURL == nil
            ? "Add your Buy Me a Coffee username to the app configuration."
            : "Support development on Buy Me a Coffee"
        )
        .accessibilityLabel("Buy me a coffee")
      }
    }
  }

  private var introduction: some View {
    HStack(alignment: .center, spacing: 18) {
      Image(systemName: "airpodspro")
        .font(.system(size: 28, weight: .medium))
        .foregroundStyle(.green)
        .frame(width: 48, height: 48)
        .background(.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

      VStack(alignment: .leading, spacing: 4) {
        Text("Spatial Audio for Spotify")
          .font(.title2.weight(.semibold))

        Text("Move Spotify playback to Safari, where macOS can spatialize it for your AirPods.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer(minLength: 20)

      Label(
        appState.isAuthenticated ? "Connected" : "Not connected",
        systemImage: appState.isAuthenticated
          ? "checkmark.circle.fill"
          : "person.crop.circle.badge.exclamationmark"
      )
      .font(.callout.weight(.medium))
      .foregroundStyle(appState.isAuthenticated ? .green : .orange)
      .accessibilityLabel(
        appState.isAuthenticated ? "Spotify connected" : "Spotify not connected"
      )
    }
  }

  @ViewBuilder
  private var adaptiveContent: some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .top, spacing: 36) {
        playerControl
          .frame(width: 328)
        setupGuide
          .frame(width: 300)
      }

      VStack(spacing: 28) {
        playerControl
        setupGuide
      }
    }
  }

  private var playerControl: some View {
    VStack(spacing: 20) {
      ZStack {
        Circle()
          .fill(statusTint.opacity(0.1))

        Circle()
          .stroke(statusTint.opacity(0.22), lineWidth: 1)
          .padding(16)

        Image(systemName: appState.spatialAudioStatusSymbol)
          .font(.system(size: 48, weight: .light))
          .foregroundStyle(statusTint)
          .symbolEffect(.pulse, isActive: isWorking)
      }
      .frame(width: 128, height: 128)
      .accessibilityHidden(true)

      VStack(spacing: 6) {
        Text(appState.spatialAudioStatusText)
          .font(.title3.weight(.semibold))
          .multilineTextAlignment(.center)

        Text(statusDetail)
          .font(.callout)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .frame(maxWidth: 330)
          .fixedSize(horizontal: false, vertical: true)
      }

      primaryAction
        .frame(maxWidth: 360)

      if appState.isAuthenticated {
        HStack(spacing: 16) {
          Button("Open Web Player", systemImage: "safari") {
            Task { await appState.openSpotifyWebPlayer() }
          }

          Button("Reconnect", systemImage: "arrow.clockwise") {
            Task { await appState.authenticate() }
          }
          .disabled(!appState.canAuthenticate)
        }
        .buttonStyle(.borderless)
      }
    }
    .frame(maxWidth: .infinity)
  }

  @ViewBuilder
  private var primaryAction: some View {
    if !appState.isAuthenticated {
      Button {
        Task { await appState.authenticate() }
      } label: {
        Label(connectButtonTitle, systemImage: "link")
          .frame(maxWidth: .infinity)
      }
      .nativePrimaryButton(tint: .green)
      .disabled(!appState.canAuthenticate)
    } else if appState.canStopSpatialAudio {
      Button {
        Task { await appState.stopSpatialAudio() }
      } label: {
        Label("Stop Spatial Audio", systemImage: "stop.fill")
          .frame(maxWidth: .infinity)
      }
      .nativePrimaryButton(tint: .red)
    } else {
      Button {
        Task { await appState.startSpatialAudio() }
      } label: {
        Label("Start Spatial Audio", systemImage: "waveform")
          .frame(maxWidth: .infinity)
      }
      .nativePrimaryButton(tint: .green)
      .disabled(!appState.canStartSpatialAudio)
    }
  }

  private var setupGuide: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label("How It Works", systemImage: "list.number")
        .font(.headline)

      GroupBox {
        VStack(alignment: .leading, spacing: 0) {
          StepRow(
            number: 1,
            title: "Play something in Spotify",
            detail: "Start a track in the Spotify desktop app."
          )
          .padding(.vertical, 10)

          Divider()

          StepRow(
            number: 2,
            title: "Start Spatial Audio",
            detail: "Playback moves securely to Spotify Web Player in Safari."
          )
          .padding(.vertical, 10)

          Divider()

          StepRow(
            number: 3,
            title: "Enable Spatialize Stereo",
            detail: "Choose your AirPods in Control Center and turn it on."
          )
          .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var privacyNote: some View {
    Label {
      Text("Audio stays inside Spotify and Safari. This app never captures or processes it.")
    } icon: {
      Image(systemName: "lock.shield.fill")
        .foregroundStyle(.green)
    }
    .font(.footnote)
    .foregroundStyle(.secondary)
    .frame(maxWidth: .infinity, alignment: .center)
  }

  private var isWorking: Bool {
    return switch appState.spatialAudioState {
    case .authorizing, .waitingForSpotify, .preparingSafari, .transferringPlayback:
      true
    case .stopped, .active, .error:
      appState.authenticationState == .authenticating
    }
  }

  private var statusTint: Color {
    return switch appState.spatialAudioState {
    case .active:
      .green
    case .error:
      .red
    case .authorizing, .waitingForSpotify, .preparingSafari, .transferringPlayback:
      .blue
    case .stopped:
      appState.isAuthenticated ? .secondary : .orange
    }
  }

  private var statusDetail: String {
    if !appState.isAuthenticated {
      return appState.statusText
    }

    return switch appState.spatialAudioState {
    case .stopped:
      "Start a track in Spotify Desktop, then press the button below."
    case .authorizing:
      "Complete Spotify authorization in your browser."
    case .waitingForSpotify:
      "Looking for active playback from Spotify Desktop."
    case .preparingSafari:
      "Opening Spotify Web Player as a spatial-audio-capable output."
    case .transferringPlayback:
      "Moving your current session without interrupting the track."
    case .active:
      "Playback is running through Safari. Enable Spatialize Stereo in Control Center."
    case .error:
      "Review the message above, then stop and try again."
    }
  }

  private var connectButtonTitle: String {
    appState.authenticationState == .authenticating
      ? "Connecting…"
      : "Connect Spotify"
  }
}

private struct StepRow: View {
  let number: Int
  let title: String
  let detail: String

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Text("\(number)")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .frame(width: 22, height: 22)
        .background(.quaternary, in: Circle())

      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.callout.weight(.medium))
        Text(detail)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

extension View {
  @ViewBuilder
  fileprivate func nativePrimaryButton(tint: Color) -> some View {
    if #available(macOS 26.0, *) {
      controlSize(.extraLarge)
        .buttonStyle(.glassProminent)
        .tint(tint)
    } else {
      controlSize(.large)
        .buttonStyle(.borderedProminent)
        .tint(tint)
    }
  }
}
