import AppKit
import SwiftUI

private enum SetupStep: Int, CaseIterable {
  case welcome
  case dashboard
  case redirectURI
  case clientID
  case connect
  case ready

  var title: String {
    switch self {
    case .welcome:
      "Welcome"
    case .dashboard:
      "Create App"
    case .redirectURI:
      "Redirect URI"
    case .clientID:
      "Client ID"
    case .connect:
      "Connect"
    case .ready:
      "Ready"
    }
  }
}

struct SetupGuideView: View {
  static let redirectURI = "http://127.0.0.1:8888/callback"

  @ObservedObject var controller: AppController
  @Environment(\.openURL) private var openURL
  @State private var currentStep: SetupStep = .welcome
  @State private var draftClientID = ""
  @State private var errorMessage: String?
  @State private var copiedRedirectURI = false

  init(controller: AppController) {
    self.controller = controller
  }

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()

      stepContent
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 38)
        .padding(.vertical, 26)

      Divider()
      navigationBar
    }
    .frame(minWidth: 760, minHeight: 680)
    .onAppear {
      draftClientID = controller.clientID
    }
  }

  private var header: some View {
    VStack(spacing: 15) {
      HStack {
        VStack(alignment: .leading, spacing: 3) {
          Text("Spotify Setup Guide")
            .font(.title2.weight(.semibold))
          Text("About 3 minutes · your Client ID is public and stays on this Mac")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()

        Text("Step \(currentStep.rawValue + 1) of \(SetupStep.allCases.count)")
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
      }

      HStack(spacing: 8) {
        ForEach(SetupStep.allCases, id: \.rawValue) { step in
          Capsule()
            .fill(
              step.rawValue <= currentStep.rawValue ? Color.green : Color.secondary.opacity(0.18)
            )
            .frame(height: 5)
            .accessibilityLabel(step.title)
            .accessibilityValue(
              step.rawValue <= currentStep.rawValue ? "Completed" : "Not completed")
        }
      }
    }
    .padding(.horizontal, 28)
    .padding(.vertical, 20)
  }

  @ViewBuilder
  private var stepContent: some View {
    switch currentStep {
    case .welcome:
      welcomeStep
    case .dashboard:
      dashboardStep
    case .redirectURI:
      redirectStep
    case .clientID:
      clientIDStep
    case .connect:
      ConnectSpotifySetupStep(appState: controller.appState)
    case .ready:
      readyStep
    }
  }

  private var welcomeStep: some View {
    SetupPage(
      icon: "airpodspro",
      tint: .green,
      title: "Let’s get Spatial Audio working",
      detail:
        "Spotify requires every installation to use a free developer app. This guide walks you through creating one—no client secret, coding, or paid developer membership required."
    ) {
      VStack(spacing: 14) {
        SetupSummaryRow(
          icon: "person.crop.circle.badge.checkmark",
          title: "Your Spotify account",
          detail: "Used only to create the developer app and approve playback access."
        )
        SetupSummaryRow(
          icon: "key.horizontal",
          title: "One public Client ID",
          detail: "Paste it here once. It is stored locally in app preferences."
        )
        SetupSummaryRow(
          icon: "lock.shield",
          title: "No client secret",
          detail: "Authorization uses PKCE and tokens stay in macOS Keychain."
        )
      }
      .frame(maxWidth: 520)
    }
  }

  private var dashboardStep: some View {
    SetupPage(
      icon: "macwindow",
      tint: .green,
      title: "Create a Spotify developer app",
      detail:
        "Open the Spotify Developer Dashboard, sign in, choose Create app, and use the values shown below."
    ) {
      HStack(alignment: .top, spacing: 14) {
        TutorialScreenshot(
          name: "spotify-dashboard",
          title: "1. Choose Create app",
          cropAlignment: .top
        )

        TutorialScreenshot(
          name: "create-app-details",
          title: "2. Enter the app details",
          cropAlignment: .top
        )
      }
      .frame(maxWidth: 640)

      Button("Open Spotify Developer Dashboard", systemImage: "arrow.up.right.square") {
        guard let url = URL(string: "https://developer.spotify.com/dashboard") else { return }
        openURL(url)
      }
      .controlSize(.large)

      Text("Suggested app name: Spatial Audio for macOS")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private var redirectStep: some View {
    SetupPage(
      icon: "arrow.triangle.turn.up.right.diamond",
      tint: .blue,
      title: "Add the exact redirect URI",
      detail:
        "In your app’s settings, add this loopback address under Redirect URIs and select Web API. Spotify accepts 127.0.0.1 for native apps."
    ) {
      TutorialScreenshot(
        name: "redirect-uri-and-web-api",
        title: "Add the URI, then select only Web API",
        screenshotHeight: 205,
        verticalOffset: 70
      )
      .frame(maxWidth: 570)

      HStack(spacing: 10) {
        Text(Self.redirectURI)
          .font(.system(.body, design: .monospaced))
          .textSelection(.enabled)

        Button(
          copiedRedirectURI ? "Copied" : "Copy",
          systemImage: copiedRedirectURI ? "checkmark" : "doc.on.doc"
        ) {
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(Self.redirectURI, forType: .string)
          copiedRedirectURI = true
        }
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .background(.quaternary.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))

      Label(
        "Use 127.0.0.1—not localhost—and keep port 8888.", systemImage: "exclamationmark.circle"
      )
      .font(.caption)
      .foregroundStyle(.secondary)
    }
  }

  private var clientIDStep: some View {
    SetupPage(
      icon: "key.horizontal",
      tint: .orange,
      title: "Paste your Client ID",
      detail:
        "Open Basic Information, copy the Client ID, and paste it below. Do not copy or create a client secret."
    ) {
      SpotifyDashboardIllustration(kind: .clientID)

      VStack(alignment: .leading, spacing: 7) {
        Text("Spotify Client ID")
          .font(.caption.weight(.medium))

        TextField("Paste the Client ID here", text: $draftClientID)
          .textFieldStyle(.roundedBorder)
          .font(.system(.body, design: .monospaced))
          .onSubmit(saveClientIDAndContinue)

        if let errorMessage {
          Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.red)
        } else {
          Text("The value is saved in your user preferences and is never uploaded anywhere else.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: 520)
    }
  }

  private var readyStep: some View {
    SetupPage(
      icon: "checkmark.seal.fill",
      tint: .green,
      title: "You’re ready",
      detail:
        "Start a song in Spotify Desktop, return to this app, and choose Start Spatial Audio. Safari opens briefly while playback moves."
    ) {
      VStack(spacing: 12) {
        ReadyInstructionRow(number: 1, text: "Play a track in Spotify Desktop")
        ReadyInstructionRow(number: 2, text: "Choose Start Spatial Audio")
        ReadyInstructionRow(number: 3, text: "Enable Spatialize Stereo in Control Center")
      }
      .frame(maxWidth: 480)

      Label(
        "You can reopen this guide anytime from the ? button in the toolbar.",
        systemImage: "questionmark.circle"
      )
      .font(.caption)
      .foregroundStyle(.secondary)
    }
  }

  private var navigationBar: some View {
    HStack {
      Button("Back", systemImage: "chevron.left") {
        move(by: -1)
      }
      .disabled(currentStep == .welcome)

      Spacer()

      if currentStep == .clientID {
        Button("Save and Continue", systemImage: "chevron.right") {
          saveClientIDAndContinue()
        }
        .tutorialPrimaryButton()
        .disabled(draftClientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      } else if currentStep == .connect {
        Button("Continue", systemImage: "chevron.right") {
          move(by: 1)
        }
        .tutorialPrimaryButton()
        .disabled(!controller.appState.isAuthenticated)
      } else if currentStep == .ready {
        Button("Finish", systemImage: "checkmark") {
          controller.completeSetup()
        }
        .tutorialPrimaryButton()
      } else {
        Button("Continue", systemImage: "chevron.right") {
          move(by: 1)
        }
        .tutorialPrimaryButton()
      }
    }
    .padding(.horizontal, 28)
    .padding(.vertical, 18)
  }

  private func move(by offset: Int) {
    guard let next = SetupStep(rawValue: currentStep.rawValue + offset) else { return }
    withAnimation(.snappy) {
      currentStep = next
      errorMessage = nil
    }
  }

  private func saveClientIDAndContinue() {
    do {
      try controller.saveClientID(draftClientID)
      draftClientID = controller.clientID
      move(by: 1)
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

private struct ConnectSpotifySetupStep: View {
  @ObservedObject var appState: AppState

  var body: some View {
    SetupPage(
      icon: appState.isAuthenticated ? "checkmark.circle.fill" : "link.circle",
      tint: appState.isAuthenticated ? .green : .blue,
      title: appState.isAuthenticated ? "Spotify is connected" : "Connect your Spotify account",
      detail: appState.isAuthenticated
        ? "Authorization succeeded. Your tokens are encrypted in macOS Keychain."
        : "Spotify opens in your browser. Approve the two playback permissions, then return here."
    ) {
      SpotifyDashboardIllustration(kind: .authorization)

      if appState.isAuthenticated {
        Label("Connected", systemImage: "checkmark.circle.fill")
          .font(.headline)
          .foregroundStyle(.green)
      } else {
        Button("Connect Spotify", systemImage: "link") {
          Task { await appState.authenticate() }
        }
        .tutorialPrimaryButton(tint: .green)
        .disabled(!appState.canAuthenticate)

        Text(appState.statusText)
          .font(.caption)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
    }
  }
}

private struct SetupPage<Content: View>: View {
  let icon: String
  let tint: Color
  let title: String
  let detail: String
  let content: Content

  init(
    icon: String,
    tint: Color,
    title: String,
    detail: String,
    @ViewBuilder content: () -> Content
  ) {
    self.icon = icon
    self.tint = tint
    self.title = title
    self.detail = detail
    self.content = content()
  }

  var body: some View {
    VStack(spacing: 18) {
      Image(systemName: icon)
        .font(.system(size: 30, weight: .medium))
        .foregroundStyle(tint)
        .frame(width: 58, height: 58)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 15))

      VStack(spacing: 7) {
        Text(title)
          .font(.title2.weight(.semibold))
        Text(detail)
          .font(.callout)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .frame(maxWidth: 590)
          .fixedSize(horizontal: false, vertical: true)
      }

      content
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
  }
}

private struct TutorialScreenshot: View {
  let name: String
  let title: String
  var screenshotHeight: CGFloat = 165
  var cropAlignment: Alignment = .center
  var verticalOffset: CGFloat = 0

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      Text(title)
        .font(.caption.weight(.semibold))

      GeometryReader { proxy in
        Group {
          if let screenshot {
            Image(nsImage: screenshot)
              .resizable()
              .scaledToFill()
              .offset(y: verticalOffset)
          } else {
            ContentUnavailableView(
              "Screenshot unavailable",
              systemImage: "photo.badge.exclamationmark"
            )
          }
        }
        .frame(
          width: proxy.size.width,
          height: proxy.size.height,
          alignment: cropAlignment
        )
        .clipped()
      }
      .frame(height: screenshotHeight)
      .background(Color(nsColor: .controlBackgroundColor))
      .clipShape(RoundedRectangle(cornerRadius: 11))
      .overlay {
        RoundedRectangle(cornerRadius: 11)
          .stroke(.separator.opacity(0.8), lineWidth: 1)
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Spotify Developer Dashboard screenshot: \(title)")
  }

  private var screenshot: NSImage? {
    #if SWIFT_PACKAGE
      let resourceBundle = Bundle.module
    #else
      let resourceBundle = Bundle.main
    #endif

    let urls = [
      resourceBundle.url(
        forResource: name,
        withExtension: "png",
        subdirectory: "SetupGuide"
      ),
      resourceBundle.url(forResource: name, withExtension: "png"),
    ]

    return urls.compactMap { $0 }.lazy.compactMap(NSImage.init(contentsOf:)).first
  }
}

private struct SetupSummaryRow: View {
  let icon: String
  let title: String
  let detail: String

  var body: some View {
    HStack(spacing: 14) {
      Image(systemName: icon)
        .font(.title3)
        .foregroundStyle(.green)
        .frame(width: 30)

      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.callout.weight(.semibold))
        Text(detail)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()
    }
    .padding(14)
    .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
  }
}

private struct ReadyInstructionRow: View {
  let number: Int
  let text: String

  var body: some View {
    HStack(spacing: 12) {
      Text("\(number)")
        .font(.caption.weight(.bold))
        .foregroundStyle(.black.opacity(0.75))
        .frame(width: 26, height: 26)
        .background(.green, in: Circle())
      Text(text)
        .font(.callout.weight(.medium))
      Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
  }
}

private enum SpotifyDashboardIllustrationKind {
  case createApp
  case redirectURI
  case clientID
  case authorization
}

private struct SpotifyDashboardIllustration: View {
  let kind: SpotifyDashboardIllustrationKind

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 7) {
        Circle().fill(.red.opacity(0.75)).frame(width: 8, height: 8)
        Circle().fill(.yellow.opacity(0.75)).frame(width: 8, height: 8)
        Circle().fill(.green.opacity(0.75)).frame(width: 8, height: 8)

        Text("developer.spotify.com/dashboard")
          .font(.system(size: 10, design: .monospaced))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 10)
          .padding(.vertical, 4)
          .background(.black.opacity(0.14), in: Capsule())

        Spacer()
      }
      .padding(.horizontal, 12)
      .frame(height: 32)
      .background(.black.opacity(0.2))

      illustrationContent
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(18)
    }
    .frame(width: 500, height: 205)
    .background(Color(nsColor: .controlBackgroundColor))
    .clipShape(RoundedRectangle(cornerRadius: 13))
    .overlay {
      RoundedRectangle(cornerRadius: 13)
        .stroke(.separator.opacity(0.8), lineWidth: 1)
    }
    .accessibilityLabel("Visual guide for the Spotify Developer Dashboard")
  }

  @ViewBuilder
  private var illustrationContent: some View {
    switch kind {
    case .createApp:
      HStack {
        VStack(alignment: .leading, spacing: 7) {
          Label("Spotify for Developers", systemImage: "waveform.circle.fill")
            .foregroundStyle(.green)
            .font(.caption.weight(.semibold))
          Text("Your apps")
            .font(.title3.weight(.semibold))
          Text("Create an app to get a Client ID.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        HighlightedMockButton(title: "Create app", icon: "plus")
      }

    case .redirectURI:
      VStack(alignment: .leading, spacing: 10) {
        Text("Redirect URIs")
          .font(.caption.weight(.semibold))
        HStack {
          Text(SetupGuideView.redirectURI)
            .font(.system(size: 11, design: .monospaced))
          Spacer()
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.green)
        }
        .padding(10)
        .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
          RoundedRectangle(cornerRadius: 8).stroke(.blue, lineWidth: 2)
        }
        Label("Web API", systemImage: "checkmark.square.fill")
          .font(.caption)
          .foregroundStyle(.green)
      }

    case .clientID:
      VStack(alignment: .leading, spacing: 10) {
        Text("Basic Information")
          .font(.caption.weight(.semibold))
        Text("Client ID")
          .font(.caption2)
          .foregroundStyle(.secondary)
        HStack {
          Text("1a2b3c4d5e6f…")
            .font(.system(size: 13, design: .monospaced))
          Spacer()
          Label("Copy", systemImage: "doc.on.doc")
            .font(.caption.weight(.medium))
            .foregroundStyle(.blue)
        }
        .padding(12)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
          RoundedRectangle(cornerRadius: 8).stroke(.orange, lineWidth: 2)
        }
        Text("Never use the Client secret")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }

    case .authorization:
      VStack(spacing: 12) {
        Image(systemName: "waveform.circle.fill")
          .font(.system(size: 30))
          .foregroundStyle(.green)
        Text("Spotify Spatial Audio wants to connect")
          .font(.callout.weight(.semibold))
        HStack(spacing: 16) {
          Label("Read playback", systemImage: "checkmark")
          Label("Control playback", systemImage: "checkmark")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
      }
    }
  }
}

private struct HighlightedMockButton: View {
  let title: String
  let icon: String

  var body: some View {
    Label(title, systemImage: icon)
      .font(.caption.weight(.semibold))
      .foregroundStyle(.black)
      .padding(.horizontal, 14)
      .padding(.vertical, 9)
      .background(.green, in: Capsule())
      .overlay {
        Capsule().stroke(.white.opacity(0.8), lineWidth: 3)
      }
      .shadow(color: .green.opacity(0.45), radius: 10)
  }
}

extension View {
  @ViewBuilder
  fileprivate func tutorialPrimaryButton(tint: Color = .accentColor) -> some View {
    if #available(macOS 26.0, *) {
      buttonStyle(.glassProminent)
        .tint(tint)
        .controlSize(.large)
    } else {
      buttonStyle(.borderedProminent)
        .tint(tint)
        .controlSize(.large)
    }
  }
}
