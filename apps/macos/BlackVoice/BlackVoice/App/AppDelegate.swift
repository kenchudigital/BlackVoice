//
//  AppDelegate.swift
//  BlackVoice
//

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var navigation: AppNavigationState?
    var chatViewModel: ChatViewModel?
    private var pendingURL: URL?
    private var queuedAction: AppAction?
    private var isDarwinObserverRegistered = false
    private var openMainWindowHandler: (() -> Void)?

    private(set) var suppressMainWindowOnLaunch = false
    private var didPresentMainWindowOnLaunch = false

    private var lastConsumedAction: AppAction?
    private var lastConsumedAt: Date?
    private var isVoiceActionInFlight = false

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
                if chatViewModel?.isListening == true || VoiceRecordingStore.isRecording() {
                    BlackVoiceLog.info(.app, "Reopen suppressed — voice recording active")
                    return
                }
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
    func earlyBind(navigation: AppNavigationState, chatViewModel: ChatViewModel) {
        if self.navigation == nil {
            BlackVoiceLog.info(.app, "earlyBind(navigation:chatViewModel:)")
            self.navigation = navigation
        }
        self.chatViewModel = chatViewModel
        consumePendingWidgetAction()
    }

    func bind(navigation: AppNavigationState, chatViewModel: ChatViewModel) {
        BlackVoiceLog.info(.app, "bind(navigation:chatViewModel:) — RootView appeared")
        self.navigation = navigation
        self.chatViewModel = chatViewModel
        if let pendingURL {
            if let action = AppAction(url: pendingURL), action == .voice {
                performBackgroundVoiceAction()
            } else {
                navigation.handle(url: pendingURL)
            }
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
            if chatViewModel?.isListening == true, shouldSkipVoiceStopDebounce() {
                BlackVoiceLog.info(.app, "consumePendingWidgetAction — voice stop debounced (still recording)")
                return
            }
            performBackgroundVoiceAction()
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
    func performBackgroundVoiceAction() {
        suppressMainWindowOnLaunch = true

        guard !isVoiceActionInFlight else {
            BlackVoiceLog.info(.app, "performBackgroundVoiceAction — skipped (already in flight)")
            return
        }

        BlackVoiceLog.info(.app, "performBackgroundVoiceAction — hide window + toggle voice (store=\(VoiceRecordingStore.isRecording()))")

        guard let navigation else {
            queuedAction = .voice
            return
        }
        navigation.applyVoiceBackgroundMode()

        guard let chatViewModel else {
            queuedAction = .voice
            return
        }

        isVoiceActionInFlight = true
        Task { @MainActor in
            defer { isVoiceActionInFlight = false }
            await chatViewModel.toggleVoiceSessionFromWidget()
            navigation.ensureMainWindowsHidden()
            BlackVoiceLog.info(.app, "performBackgroundVoiceAction — done (store=\(VoiceRecordingStore.isRecording()), isListening=\(chatViewModel.isListening))")
        }
    }

    @MainActor
    private func shouldSkipVoiceStopDebounce() -> Bool {
        guard let chatViewModel else { return false }
        return !chatViewModel.canStopWidgetVoiceYet
    }

    @MainActor
    private func shouldSkipDuplicate(_ action: AppAction) -> Bool {
        guard action == lastConsumedAction,
              let lastConsumedAt,
              Date().timeIntervalSince(lastConsumedAt) < 0.5 else { return false }
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
        if let action = AppAction(url: url), action == .voice {
            performBackgroundVoiceAction()
            pendingURL = nil
            return
        }
        if let navigation {
            navigation.handle(url: url)
            pendingURL = nil
        } else {
            pendingURL = url
        }
    }
}
