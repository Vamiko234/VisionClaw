import AVFoundation
import Foundation

// Detects volume-down button presses while the app's audio session is active and
// fires a callback. Observation starts/stops with the Gemini session so the button
// behaves normally when VisionClaw is not the active audio session.
//
// Limitation: each press lowers system volume by one step (~6%). There is no public
// iOS API to suppress the volume change without a visible MPVolumeView on screen.
@MainActor
final class VolumeButtonTrigger {
  var onVolumeDown: (() -> Void)?

  private var observation: NSKeyValueObservation?
  private var lastVolume: Float = 0.5
  private var lastTriggerDate: Date = .distantPast
  private let debounce: TimeInterval = 0.5

  func start() {
    let session = AVAudioSession.sharedInstance()
    lastVolume = session.outputVolume

    observation = session.observe(\.outputVolume, options: [.new]) { [weak self] _, change in
      guard let newVolume = change.newValue else { return }
      Task { @MainActor [weak self] in
        guard let self else { return }
        defer { self.lastVolume = newVolume }
        guard newVolume < self.lastVolume else { return }
        let now = Date()
        guard now.timeIntervalSince(self.lastTriggerDate) >= self.debounce else { return }
        self.lastTriggerDate = now
        NSLog("[VolumeButton] Volume down detected (%.2f → %.2f), firing trigger", self.lastVolume, newVolume)
        self.onVolumeDown?()
      }
    }
    NSLog("[VolumeButton] Observation started, current volume: %.2f", lastVolume)
  }

  func stop() {
    observation?.invalidate()
    observation = nil
    NSLog("[VolumeButton] Observation stopped")
  }
}
