import Testing

@testable import SpotifySpatialAudio

struct SafariDeviceSelectorTests {
  @Test("A newly appeared computer is preferred without relying on its name")
  func newComputerDevice() {
    let desktop = device(id: "desktop", name: "My Mac", type: "Computer")
    let renamedSafari = device(id: "new-browser", name: "Walentin's Player", type: "Computer")

    let selected = SafariDeviceSelector.select(
      from: [desktop, renamedSafari],
      excluding: ["desktop"],
      cachedDeviceID: nil
    )

    #expect(selected?.id == "new-browser")
  }

  @Test("A valid session cache wins over display-name heuristics")
  func cachedDevice() {
    let cached = device(id: "cached", name: "Renamed device", type: "Computer")
    let namedFallback = device(id: "fallback", name: "Web Player (Safari)", type: "Computer")

    let selected = SafariDeviceSelector.select(
      from: [namedFallback, cached],
      excluding: [],
      cachedDeviceID: "cached"
    )

    #expect(selected?.id == "cached")
  }

  @Test("Restricted devices are never selected")
  func restrictedDevice() {
    let restricted = device(
      id: "restricted",
      name: "Web Player (Safari)",
      type: "Computer",
      isRestricted: true
    )

    let selected = SafariDeviceSelector.select(
      from: [restricted],
      excluding: [],
      cachedDeviceID: nil
    )

    #expect(selected == nil)
  }

  private func device(
    id: String,
    name: String,
    type: String,
    isRestricted: Bool = false
  ) -> SpotifyDevice {
    SpotifyDevice(
      id: id,
      isActive: false,
      isPrivateSession: false,
      isRestricted: isRestricted,
      name: name,
      type: type,
      volumePercent: nil,
      supportsVolume: false
    )
  }
}
