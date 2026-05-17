/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

//
// CameraAccessApp.swift
//
// Main entry point for the CameraAccess sample app demonstrating the Meta Wearables DAT SDK.
// This app shows how to connect to wearable devices (like Ray-Ban Meta smart glasses),
// stream live video from their cameras, and capture photos. It provides a complete example
// of DAT SDK integration including device registration, permissions, and media streaming.
//

import AppIntents
import Foundation
import MWDATCore
import SwiftUI

#if canImport(MWDATMockDevice)
import MWDATMockDevice
#endif

@main
struct CameraAccessApp: App {
  #if canImport(MWDATMockDevice)
  // Debug menu for simulating device connections during development
  @StateObject private var debugMenuViewModel = DebugMenuViewModel(mockDeviceKit: MockDeviceKit.shared)
  #endif
  private let wearables: WearablesInterface
  @StateObject private var wearablesViewModel: WearablesViewModel

  init() {
    do {
      try Wearables.configure()
    } catch {
      #if DEBUG
      NSLog("[CameraAccess] Failed to configure Wearables SDK: \(error)")
      #endif
    }
    let wearables = Wearables.shared
    self.wearables = wearables
    self._wearablesViewModel = StateObject(wrappedValue: WearablesViewModel(wearables: wearables))
  }

  var body: some Scene {
    WindowGroup {
      // Main app view with access to the shared Wearables SDK instance
      // The Wearables.shared singleton provides the core DAT API
      MainAppView(wearables: Wearables.shared, viewModel: wearablesViewModel)
        // Show error alerts for view model failures
        .alert("Error", isPresented: $wearablesViewModel.showError) {
          Button("OK") {
            wearablesViewModel.dismissError()
          }
        } message: {
          Text(wearablesViewModel.errorMessage)
        }
        #if canImport(MWDATMockDevice)
      .sheet(isPresented: $debugMenuViewModel.showDebugMenu) {
        MockDeviceKitView(viewModel: debugMenuViewModel.mockDeviceKitViewModel)
      }
      .overlay {
        DebugMenuView(debugMenuViewModel: debugMenuViewModel)
      }
        #endif

      // Registration view handles the flow for connecting to the glasses via Meta AI
      RegistrationView(viewModel: wearablesViewModel)
    }
  }
}

// MARK: - iOS Shortcuts / AppIntents

extension Notification.Name {
  static let askWhatAmILookingAt = Notification.Name("askWhatAmILookingAt")
}

struct AskVisionIntent: AppIntent {
  static var title: LocalizedStringResource = "Ask What Am I Looking At"
  static var description = IntentDescription(
    "Asks Gemini to describe what the camera sees and speaks the response through your glasses."
  )
  // false: intent runs in the app's background process without bringing it to foreground,
  // so it responds when the screen is off and the app is backgrounded with audio mode active.
  static var openAppWhenRun: Bool = false

  @MainActor
  func perform() async throws -> some IntentResult {
    NotificationCenter.default.post(name: .askWhatAmILookingAt, object: nil)
    return .result()
  }
}

struct VisionClawShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: AskVisionIntent(),
      phrases: [
        "Ask \(.applicationName) what I'm looking at",
        "What am I looking at in \(.applicationName)",
        "Describe what I see in \(.applicationName)"
      ],
      shortTitle: "What Am I Looking At?",
      systemImageName: "eye.circle"
    )
  }
}
