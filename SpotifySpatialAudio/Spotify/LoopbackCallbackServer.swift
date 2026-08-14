import Darwin
import Foundation
import Network

struct OAuthCallback: Sendable, Equatable {
  let code: String?
  let state: String?
  let error: String?
}

enum LoopbackCallbackError: LocalizedError, Equatable {
  case listenerFailed(String)
  case invalidPort(UInt16)
  case portInUse(UInt16)
  case invalidRequest
  case timedOut
  case cancelled

  var errorDescription: String? {
    switch self {
    case .listenerFailed(let message):
      "The local Spotify callback server could not start: \(message)"
    case .invalidPort(let port):
      "\(port) is not a valid local callback port."
    case .portInUse(let port):
      "Local callback port \(port) is already in use. Quit the original Spotify Spatial Audio app or its ssa-core process, then try again."
    case .invalidRequest:
      "Spotify returned an invalid authorization callback."
    case .timedOut:
      "Spotify authorization timed out."
    case .cancelled:
      "Spotify authorization was cancelled."
    }
  }
}

final class LoopbackCallbackServer: @unchecked Sendable {
  private let queue = DispatchQueue(label: "SpotifySpatialAudio.OAuthLoopback")
  private let lock = NSLock()
  private let configuredPort: UInt16

  private var listener: NWListener?
  private var startContinuation: CheckedContinuation<URL, any Error>?
  private var callbackContinuation: CheckedContinuation<OAuthCallback, any Error>?
  private var pendingCallback: Result<OAuthCallback, any Error>?
  private var hasFinished = false

  init(port: UInt16 = 8888) {
    configuredPort = port
  }

  func start() async throws -> URL {
    try ensurePortIsAvailable(configuredPort)

    let parameters = NWParameters.tcp
    guard let port = NWEndpoint.Port(rawValue: configuredPort) else {
      throw LoopbackCallbackError.invalidPort(configuredPort)
    }
    parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: port)
    let listener: NWListener

    do {
      listener = try NWListener(using: parameters)
    } catch {
      throw LoopbackCallbackError.listenerFailed(error.localizedDescription)
    }

    self.listener = listener
    listener.newConnectionHandler = { [weak self] connection in
      self?.accept(connection)
    }
    listener.stateUpdateHandler = { [weak self, weak listener] state in
      guard let self else { return }
      switch state {
      case .ready:
        guard let port = listener?.port,
          let url = URL(string: "http://127.0.0.1:\(port.rawValue)/callback")
        else {
          self.failStart(LoopbackCallbackError.listenerFailed("No listening port was assigned."))
          return
        }
        self.completeStart(with: url)
      case .failed(let error):
        self.failStart(LoopbackCallbackError.listenerFailed(error.localizedDescription))
        self.finish(
          with: .failure(LoopbackCallbackError.listenerFailed(error.localizedDescription)))
      default:
        break
      }
    }

    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        lock.withLock {
          startContinuation = continuation
          listener.start(queue: queue)
        }
      }
    } onCancel: {
      self.failStart(LoopbackCallbackError.cancelled)
      self.stop()
    }
  }

  func waitForCallback(timeout: Duration = .seconds(180)) async throws -> OAuthCallback {
    let timeoutTask = Task { [weak self] in
      try await Task.sleep(for: timeout)
      self?.finish(with: .failure(LoopbackCallbackError.timedOut))
    }
    defer { timeoutTask.cancel() }

    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        let pending = lock.withLock { () -> Result<OAuthCallback, any Error>? in
          if let pendingCallback {
            self.pendingCallback = nil
            return pendingCallback
          }
          callbackContinuation = continuation
          return nil
        }
        if let pending {
          continuation.resume(with: pending)
        }
      }
    } onCancel: {
      self.finish(with: .failure(LoopbackCallbackError.cancelled))
    }
  }

  func stop() {
    let currentListener = lock.withLock { () -> NWListener? in
      let currentListener = listener
      listener = nil
      return currentListener
    }
    currentListener?.cancel()
  }

  private func accept(_ connection: NWConnection) {
    connection.start(queue: queue)
    receiveRequest(on: connection, accumulated: Data())
  }

  private func ensurePortIsAvailable(_ port: UInt16) throws {
    let descriptor = socket(AF_INET, SOCK_STREAM, 0)
    guard descriptor >= 0 else {
      throw LoopbackCallbackError.listenerFailed(String(cString: strerror(errno)))
    }
    defer { close(descriptor) }

    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = port.bigEndian
    address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

    let result = withUnsafePointer(to: &address) { pointer in
      pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
        Darwin.bind(
          descriptor,
          socketAddress,
          socklen_t(MemoryLayout<sockaddr_in>.size)
        )
      }
    }

    guard result == 0 else {
      let errorCode = errno
      if errorCode == EADDRINUSE {
        throw LoopbackCallbackError.portInUse(port)
      }
      throw LoopbackCallbackError.listenerFailed(String(cString: strerror(errorCode)))
    }
  }

  private func receiveRequest(on connection: NWConnection, accumulated: Data) {
    connection.receive(minimumIncompleteLength: 1, maximumLength: 4_096) {
      [weak self] data, _, isComplete, error in
      guard let self else { return }
      var requestData = accumulated
      if let data {
        requestData.append(data)
      }

      if requestData.count > 16_384 {
        self.respond(
          to: connection, status: "413 Payload Too Large",
          message: "Authorization response was too large.")
        self.finish(with: .failure(LoopbackCallbackError.invalidRequest))
        return
      }

      if requestData.range(of: Data("\r\n\r\n".utf8)) != nil || isComplete {
        self.handle(requestData, from: connection)
      } else if error == nil {
        self.receiveRequest(on: connection, accumulated: requestData)
      } else {
        connection.cancel()
        self.finish(with: .failure(LoopbackCallbackError.invalidRequest))
      }
    }
  }

  private func handle(_ data: Data, from connection: NWConnection) {
    guard let request = String(data: data, encoding: .utf8),
      let firstLine = request.components(separatedBy: "\r\n").first
    else {
      respond(to: connection, status: "400 Bad Request", message: "Invalid authorization response.")
      finish(with: .failure(LoopbackCallbackError.invalidRequest))
      return
    }

    let parts = firstLine.split(separator: " ", maxSplits: 2).map(String.init)
    guard parts.count == 3,
      parts[0] == "GET",
      let components = URLComponents(string: "http://127.0.0.1\(parts[1])"),
      components.path == "/callback"
    else {
      respond(to: connection, status: "404 Not Found", message: "Unknown callback path.")
      return
    }

    let query = (components.queryItems ?? []).reduce(into: [String: String]()) { result, item in
      if result[item.name] == nil {
        result[item.name] = item.value ?? ""
      }
    }
    let callback = OAuthCallback(
      code: query["code"],
      state: query["state"],
      error: query["error"]
    )

    respond(
      to: connection,
      status: "200 OK",
      message: callback.error == nil
        ? "Spotify authorization succeeded. You can close this tab."
        : "Spotify authorization was not completed. You can close this tab."
    )
    finish(with: .success(callback))
  }

  private func respond(to connection: NWConnection, status: String, message: String) {
    let body = """
      <!doctype html><html><head><meta charset="utf-8"><title>Spotify Spatial Audio</title></head>
      <body style="font: -apple-system-body; padding: 3rem"><h1>Spotify Spatial Audio</h1><p>\(message)</p></body></html>
      """
    let response = """
      HTTP/1.1 \(status)\r
      Content-Type: text/html; charset=utf-8\r
      Content-Length: \(body.utf8.count)\r
      Connection: close\r
      \r
      \(body)
      """
    connection.send(
      content: Data(response.utf8),
      completion: .contentProcessed { _ in
        connection.cancel()
      })
  }

  private func completeStart(with url: URL) {
    let continuation = lock.withLock { () -> CheckedContinuation<URL, any Error>? in
      let continuation = startContinuation
      startContinuation = nil
      return continuation
    }
    continuation?.resume(returning: url)
  }

  private func failStart(_ error: any Error) {
    let continuation = lock.withLock { () -> CheckedContinuation<URL, any Error>? in
      let continuation = startContinuation
      startContinuation = nil
      return continuation
    }
    continuation?.resume(throwing: error)
  }

  private func finish(with result: Result<OAuthCallback, any Error>) {
    let continuation = lock.withLock { () -> CheckedContinuation<OAuthCallback, any Error>? in
      guard !hasFinished else { return nil }
      hasFinished = true
      let continuation = callbackContinuation
      callbackContinuation = nil
      if continuation == nil {
        pendingCallback = result
      }
      return continuation
    }
    continuation?.resume(with: result)
    stop()
  }
}
