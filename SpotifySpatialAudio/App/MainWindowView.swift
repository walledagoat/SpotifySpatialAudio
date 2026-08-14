import AppKit
import SwiftUI

struct MainWindowView: View {
  @ObservedObject var appState: AppState
  let buyMeACoffeeURL: URL?
  @Environment(\.openURL) private var openURL

  init(
    appState: AppState,
    buyMeACoffeeURL: URL? = AppLinks.buyMeACoffee
  ) {
    _appState = ObservedObject(wrappedValue: appState)
    self.buyMeACoffeeURL = buyMeACoffeeURL
  }

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [
          Color(nsColor: .windowBackgroundColor),
          Color.accentColor.opacity(0.08),
          Color(nsColor: .windowBackgroundColor),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()

      VStack(spacing: 22) {
        header

        HStack(alignment: .top, spacing: 18) {
          controlCard
          stepsCard
        }

        supportBar
      }
      .padding(26)
    }
    .frame(minWidth: 720, minHeight: 520)
  }

  private var header: some View {
    HStack(spacing: 14) {
      ZStack {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(
            LinearGradient(
              colors: [.green, .mint],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )

        Image(systemName: "airpodspro")
          .font(.system(size: 26, weight: .semibold))
          .foregroundStyle(.black.opacity(0.78))
      }
      .frame(width: 52, height: 52)
      .shadow(color: .green.opacity(0.22), radius: 12, y: 6)

      VStack(alignment: .leading, spacing: 3) {
        Text("Spotify Spatial Audio")
          .font(.title2.weight(.bold))

        Text("A native bridge from Spotify Desktop to macOS Spatial Audio")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      Spacer()

      StatusPill(
        title: appState.isAuthenticated ? "Spotify connected" : "Not connected",
        systemImage: appState.isAuthenticated
          ? "checkmark.circle.fill"
          : "person.crop.circle.badge.exclamationmark",
        tint: appState.isAuthenticated ? .green : .orange
      )
    }
  }

  private var controlCard: some View {
    VStack(spacing: 20) {
      ZStack {
        Circle()
          .fill(statusTint.opacity(0.11))
          .frame(width: 136, height: 136)

        Circle()
          .stroke(statusTint.opacity(0.22), lineWidth: 1)
          .frame(width: 116, height: 116)

        Image(systemName: appState.spatialAudioStatusSymbol)
          .font(.system(size: 52, weight: .light))
          .foregroundStyle(statusTint)
          .symbolEffect(.pulse, isActive: isWorking)
      }
      .padding(.top, 4)

      VStack(spacing: 7) {
        Text(appState.spatialAudioStatusText)
          .font(.title3.weight(.semibold))
          .multilineTextAlignment(.center)

        Text(statusDetail)
          .font(.callout)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .frame(maxWidth: 300)
      }

      Spacer(minLength: 0)

      if !appState.isAuthenticated {
        Button {
          Task { await appState.authenticate() }
        } label: {
          Label(connectButtonTitle, systemImage: "link")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryActionButtonStyle(tint: .green))
        .disabled(!appState.canAuthenticate)
      } else if appState.canStopSpatialAudio {
        Button {
          Task { await appState.stopSpatialAudio() }
        } label: {
          Label("Stop Spatial Audio", systemImage: "stop.fill")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryActionButtonStyle(tint: .red))
      } else {
        Button {
          Task { await appState.startSpatialAudio() }
        } label: {
          Label("Start Spatial Audio", systemImage: "waveform")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryActionButtonStyle(tint: .green))
        .disabled(!appState.canStartSpatialAudio)
      }

      if appState.isAuthenticated {
        HStack(spacing: 12) {
          Button("Open Web Player") {
            Task { await appState.openSpotifyWebPlayer() }
          }

          Button("Reconnect") {
            Task { await appState.authenticate() }
          }
          .disabled(!appState.canAuthenticate)
        }
        .buttonStyle(.link)
        .font(.callout)
      }
    }
    .padding(22)
    .frame(maxWidth: .infinity, minHeight: 348)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
    .overlay {
      RoundedRectangle(cornerRadius: 22)
        .stroke(.white.opacity(0.12), lineWidth: 1)
    }
  }

  private var stepsCard: some View {
    VStack(alignment: .leading, spacing: 18) {
      VStack(alignment: .leading, spacing: 5) {
        Text("How it works")
          .font(.title3.weight(.semibold))

        Text("Three steps. No virtual audio drivers.")
          .font(.callout)
          .foregroundStyle(.secondary)
      }

      VStack(alignment: .leading, spacing: 17) {
        StepRow(
          number: 1,
          title: "Play something in Spotify",
          detail: "Start a track in the Spotify desktop app."
        )
        StepRow(
          number: 2,
          title: "Start Spatial Audio",
          detail: "Playback moves securely to Spotify Web Player in Safari."
        )
        StepRow(
          number: 3,
          title: "Enable Spatialize Stereo",
          detail: "Choose your AirPods in Control Center and turn it on."
        )
      }

      Divider()

      Label {
        Text("Audio remains inside Spotify and Safari. This app never captures or processes it.")
          .font(.caption)
          .foregroundStyle(.secondary)
      } icon: {
        Image(systemName: "lock.shield.fill")
          .foregroundStyle(.green)
      }
      .labelStyle(.titleAndIcon)
      .fixedSize(horizontal: false, vertical: true)

      Spacer(minLength: 0)
    }
    .padding(22)
    .frame(width: 316)
    .frame(minHeight: 348)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
    .overlay {
      RoundedRectangle(cornerRadius: 22)
        .stroke(.white.opacity(0.12), lineWidth: 1)
    }
  }

  private var supportBar: some View {
    HStack(spacing: 14) {
      Image(systemName: "heart.fill")
        .foregroundStyle(.pink)

      VStack(alignment: .leading, spacing: 2) {
        Text("Free and open source")
          .font(.callout.weight(.semibold))
        Text("If it improves your listening, you can support future updates.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      Button {
        openURL(AppLinks.repository)
      } label: {
        Label("View on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
      }
      .buttonStyle(SupportButtonStyle(tint: .white.opacity(0.1), foreground: .primary))

      Button {
        guard let url = buyMeACoffeeURL else { return }
        openURL(url)
      } label: {
        Label("Buy me a coffee", systemImage: "cup.and.saucer.fill")
      }
      .buttonStyle(SupportButtonStyle(tint: .yellow, foreground: .black.opacity(0.8)))
      .disabled(buyMeACoffeeURL == nil)
      .help(
        buyMeACoffeeURL == nil
          ? "Add your Buy Me a Coffee username to the app configuration."
          : "Support development on Buy Me a Coffee"
      )
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 13)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
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
        .font(.caption.weight(.bold))
        .foregroundStyle(.black.opacity(0.76))
        .frame(width: 25, height: 25)
        .background(.green, in: Circle())

      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.callout.weight(.semibold))
        Text(detail)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}

private struct StatusPill: View {
  let title: String
  let systemImage: String
  let tint: Color

  var body: some View {
    Label(title, systemImage: systemImage)
      .font(.caption.weight(.semibold))
      .foregroundStyle(tint)
      .padding(.horizontal, 12)
      .padding(.vertical, 7)
      .background(tint.opacity(0.1), in: Capsule())
  }
}

private struct PrimaryActionButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled
  let tint: Color

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.headline)
      .padding(.vertical, 11)
      .padding(.horizontal, 16)
      .foregroundStyle(.white.opacity(isEnabled ? 1 : 0.62))
      .background(
        tint.opacity(isEnabled ? (configuration.isPressed ? 0.72 : 1) : 0.38),
        in: RoundedRectangle(cornerRadius: 11, style: .continuous)
      )
      .scaleEffect(configuration.isPressed ? 0.985 : 1)
  }
}

private struct SupportButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled
  let tint: Color
  let foreground: Color

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.callout.weight(.semibold))
      .padding(.horizontal, 13)
      .padding(.vertical, 8)
      .foregroundStyle(foreground.opacity(isEnabled ? 1 : 0.48))
      .background(
        tint.opacity(isEnabled ? (configuration.isPressed ? 0.74 : 1) : 0.32),
        in: RoundedRectangle(cornerRadius: 9, style: .continuous)
      )
      .scaleEffect(configuration.isPressed ? 0.98 : 1)
  }
}
