//
//  AppDelegate.swift
//  BlackVoice
//

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var navigation: AppNavigationState?
    private var pendingURL: URL?
    private var queuedAction: AppAction?
    private var isDarwinObserverRegistered = false
    private var openMainWindowHandler: (() -> Void)?

    private(set) var suppressMainWindowOnLaunch = false
    private var didPresentMainWindowOnLaunch = false

    private var lastConsumedAction: AppAction?
    private var lastConsumedAt: Date?

    func applicationWillFinishLaunching(_ notification: Notification) {
        BlackVoiceLog.info(.app, "applicationWillFinishLaunching")
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURL(event:replyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
        registerWidgetActionDarwinObserver()

        if let container = AppActionStore.appGroupContainerURL() {
            BlackVoiceLog.info(.app, "App Group container: \(container.path)")
        } else {
            BlackVoiceLog.error(.app, "App Group container MISSING")
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        BlackVoiceLog.info(.app, "applicationDidFinishLaunching")
        if let pending = AppActionStore.peekPending() {
            BlackVoiceLog.info(.app, "Peek pending on launch: \(pending.rawValue)")
            if pending == .voice || pending == .close {
                suppressMainWindowOnLaunch = true
            }
        }
        Task { @MainActor in consumePendingWidgetAction() }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        Task { @MainActor in deliver(url, source: "application(_:open:)") }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        BlackVoiceLog.debug(.app, "applicationDidBecomeActive")
        Task { @MainActor in consumePendingWidgetAction() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        BlackVoiceLog.info(.app, "applicationShouldHandleReopen hasVisibleWindows=\(flag)")
        if !flag {
            Task { @MainActor in
                if let navigation {
                    navigation.apply(action: .chat)
                } else {
                    BlackVoiceLog.info(.app, "Reopen — navigation nil, calling openMainWindow")
                    openMainWindow()
                }
            }
        }
        return true
    }

    /// 做咩：MenuBar label onAppear 時提早 bind navigation（唔等 RootView）。
    func earlyBind(navigation: AppNavigationState) {
        if self.navigation == nil {
            BlackVoiceLog.info(.app, "earlyBind(navigation:)")
            self.navigation = navigation
        }
    }

    func bind(navigation: AppNavigationState) {
        BlackVoiceLog.info(.app, "bind(navigation:) — RootView appeared")
        self.navigation = navigation
        if let pendingURL {
            navigation.handle(url: pendingURL)
            self.pendingURL = nil
        }
        consumePendingWidgetAction()
    }

    func registerOpenMainWindowHandler(_ handler: @escaping () -> Void) {
        openMainWindowHandler = handler
        BlackVoiceLog.info(.app, "registerOpenMainWindowHandler — ready")
    }

    var canOpenMainWindow: Bool { openMainWindowHandler != nil }

    /// 做咩：SwiftUI openWindow(id: "main") 嘅唯一入口（launch / Widget / Dock reopen 共用）。
    @MainActor
    func openMainWindow() {
        guard let openMainWindowHandler else {
            BlackVoiceLog.error(.app, "openMainWindow — handler nil")
            return
        }
        BlackVoiceLog.info(.app, "openWindow(id: main) invoked")
        openMainWindowHandler()
    }

    func presentMainWindowOnLaunchIfNeeded() {
        guard !didPresentMainWindowOnLaunch else {
            BlackVoiceLog.debug(.app, "presentMainWindowOnLaunchIfNeeded — already presented")
            return
        }
        guard !suppressMainWindowOnLaunch else {
            BlackVoiceLog.info(.app, "presentMainWindowOnLaunchIfNeeded — suppressed (voice/close launch)")
            return
        }
        guard canOpenMainWindow else {
            BlackVoiceLog.error(.app, "presentMainWindowOnLaunchIfNeeded — handler nil")
            return
        }
        didPresentMainWindowOnLaunch = true
        BlackVoiceLog.info(.app, "presentMainWindowOnLaunchIfNeeded — opening main window")
        NSApp.activate(ignoringOtherApps: true)
        openMainWindow()
    }

    @objc private func handleGetURL(event: NSAppleEventDescriptor, replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString) else { return }
        Task { @MainActor in deliver(url, source: "handleGetURL") }
    }

    private func registerWidgetActionDarwinObserver() {
        guard !isDarwinObserverRegistered else { return }
        isDarwinObserverRegistered = true
        BlackVoiceLog.info(.app, "Darwin observer registered")

        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterAddObserver(
            center,
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer else { return }
                let delegate = Unmanaged<AppDelegate>.fromOpaque(observer).takeUnretainedValue()
                Task { @MainActor in
                    BlackVoiceLog.info(.app, "Darwin notify — consumePendingWidgetAction")
                    delegate.consumePendingWidgetAction()
                }
            },
            AppActionStore.darwinNotificationName as CFString,
            nil,
            .deliverImmediately
        )
    }

    @MainActor
    func consumePendingWidgetAction() {
        guard let action = AppActionStore.consumePending() ?? queuedAction else { return }

        if shouldSkipDuplicate(action) { return }
        recordConsumed(action)
        queuedAction = nil
        BlackVoiceLog.info(.app, "consumePendingWidgetAction handling: \(action.rawValue)")

        switch action {
        case .close:
            suppressMainWindowOnLaunch = true
            NSApplication.shared.terminate(nil)
        case .voice:
            suppressMainWindowOnLaunch = true
            if let navigation {
                navigation.applyVoiceMode()
            } else {
                queuedAction = .voice
            }
        default:
            suppressMainWindowOnLaunch = false
            guard let navigation else {
                BlackVoiceLog.info(.app, "Queue action \(action.rawValue) — navigation not ready")
                queuedAction = action
                return
            }
            navigation.apply(action: action)
        }
    }

    @MainActor
    private func shouldSkipDuplicate(_ action: AppAction) -> Bool {
        guard action == lastConsumedAction,
              let lastConsumedAt,
              Date().timeIntervalSince(lastConsumedAt) < 0.35 else { return false }
        BlackVoiceLog.debug(.app, "Skipping duplicate: \(action.rawValue)")
        return true
    }

    @MainActor
    private func recordConsumed(_ action: AppAction) {
        lastConsumedAction = action
        lastConsumedAt = Date()
    }

    @MainActor
    private func deliver(_ url: URL, source: String) {
        BlackVoiceLog.info(.deeplink, "Deliver URL from \(source): \(url.absoluteString)")
        if let navigation {
            navigation.handle(url: url)
            pendingURL = nil
        } else {
            pendingURL = url
        }
    }
}
