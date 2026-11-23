// File: App/ArkadTraderApp.swift
// App entry point. Shows the launch screen until the saved sign-in has been checked.

import SwiftUI
import Firebase

@main
struct ArkadTraderApp: App {
    @StateObject private var authService = FirebaseAuthService.shared
    @State private var isLaunching = true
    @AppStorage(AppAppearance.storageKey) private var appearance: String = AppAppearance.system.rawValue

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if isLaunching {
                    LaunchScreenView()
                        .transition(.opacity)
                } else {
                    ContentView()
                        .environmentObject(authService)
                        .transition(.opacity)
                }
            }
            .preferredColorScheme(AppAppearance(rawValue: appearance)?.colorScheme)
            .task { await finishLaunch() }
        }
    }

    /// Waits for Firebase's first auth answer (which loads the signed-in user's profile),
    /// but never longer than `maxWait`, and keeps the logo up long enough not to flash.
    private func finishLaunch() async {
        let minimumDisplay: TimeInterval = 0.8
        let maxWait: TimeInterval = 6
        let start = Date()

        while authService.isLoading && Date().timeIntervalSince(start) < maxWait {
            try? await Task.sleep(for: .milliseconds(100))
        }

        let remaining = minimumDisplay - Date().timeIntervalSince(start)
        if remaining > 0 {
            try? await Task.sleep(for: .seconds(remaining))
        }

        withAnimation(.easeOut(duration: 0.35)) {
            isLaunching = false
        }
    }
}

struct LaunchScreenView: View {
    @State private var appeared = false
    @State private var showSpinner = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 32) {
                ArkadLogo(height: 80)
                    .frame(maxWidth: 240)
                    .scaleEffect(appeared ? 1 : 0.94)
                    .opacity(appeared ? 1 : 0)

                ProgressView()
                    .tint(.goldText)
                    .opacity(showSpinner ? 1 : 0)
            }
            .padding(.horizontal, 48)

            VStack {
                Spacer()
                Text(AppInfo.versionLine)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 24)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
            // Only show a spinner if loading actually takes a moment
            withAnimation(.easeIn(duration: 0.3).delay(1.2)) { showSpinner = true }
        }
    }
}

/// Version and copyright read from the app bundle and the current date
enum AppInfo {
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    /// "Version 1.0 (1)"
    static var versionLine: String { "Version \(version) (\(build))" }

    /// "© 2026 Arkad"
    static var copyright: String { "© \(Calendar.current.component(.year, from: Date())) Arkad" }

    /// The one address used by Contact Support and the Help Center. Confirm before release.
    static let supportEmail = "support@arkadtrader.com"

    /// Lowest iOS version the app runs on, read from the built Info.plist
    /// (falls back to the project's IPHONEOS_DEPLOYMENT_TARGET).
    static var minimumIOSVersion: String {
        Bundle.main.infoDictionary?["MinimumOSVersion"] as? String ?? "18.5"
    }
}

#Preview {
    LaunchScreenView()
}
