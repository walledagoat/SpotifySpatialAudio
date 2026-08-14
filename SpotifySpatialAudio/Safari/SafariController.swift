import AppKit
import Foundation

protocol SafariControlling: Sendable {
  @MainActor func openWebPlayer() async throws
  @MainActor func minimizeWebPlayer() throws
}

enum SafariControllerError: LocalizedError, Equatable {
  case safariNotInstalled
  case invalidWebPlayerURL
  case launchFailed(String)
  case automationFailed(String)

  var errorDescription: String? {
    switch self {
    case .safariNotInstalled:
      "Safari could not be found on this Mac."
    case .invalidWebPlayerURL:
      "The Spotify Web Player URL is invalid."
    case .launchFailed(let message):
      "Safari could not open Spotify: \(message)"
    case .automationFailed(let message):
      "Safari could not minimize the Spotify Web Player: \(message)"
    }
  }
}

@MainActor
final class SafariController: SafariControlling {
  private let workspace: NSWorkspace
  private let webPlayerURL: URL

  init(
    workspace: NSWorkspace = .shared,
    webPlayerURL: URL? = URL(string: "https://open.spotify.com/")
  ) throws {
    guard let webPlayerURL else {
      throw SafariControllerError.invalidWebPlayerURL
    }
    self.workspace = workspace
    self.webPlayerURL = webPlayerURL
  }

  func openWebPlayer() async throws {
    guard let safariURL = workspace.urlForApplication(withBundleIdentifier: "com.apple.Safari")
    else {
      throw SafariControllerError.safariNotInstalled
    }

    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = true
    configuration.addsToRecentItems = false

    do {
      try await withCheckedThrowingContinuation {
        (continuation: CheckedContinuation<Void, any Error>) in
        workspace.open(
          [webPlayerURL],
          withApplicationAt: safariURL,
          configuration: configuration
        ) { application, error in
          if let error {
            continuation.resume(throwing: error)
          } else if application == nil {
            continuation.resume(
              throwing: SafariControllerError.launchFailed("No Safari process was returned.")
            )
          } else {
            continuation.resume(returning: ())
          }
        }
      }
    } catch let error as SafariControllerError {
      throw error
    } catch {
      throw SafariControllerError.launchFailed(error.localizedDescription)
    }
  }

  func minimizeWebPlayer() throws {
    // This targets only a window containing an open.spotify.com tab. It deliberately
    // avoids synthetic key events and leaves all other Safari windows untouched.
    let source = """
      tell application "Safari"
          repeat with candidateWindow in windows
              repeat with candidateTab in tabs of candidateWindow
                  if URL of candidateTab starts with "https://open.spotify.com" then
                      set miniaturized of candidateWindow to true
                      return
                  end if
              end repeat
          end repeat
      end tell
      """

    guard let script = NSAppleScript(source: source) else {
      throw SafariControllerError.automationFailed(
        "The Safari automation script could not be created.")
    }
    var errorInfo: NSDictionary?
    script.executeAndReturnError(&errorInfo)
    if let errorInfo {
      let message =
        errorInfo[NSAppleScript.errorMessage] as? String
        ?? "macOS denied the automation request."
      throw SafariControllerError.automationFailed(message)
    }
  }
}
