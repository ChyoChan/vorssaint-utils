// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Combine
import SwiftUI

/// On-demand translation. Apple stays local; Google is an explicit cloud opt-in.
/// Text and credentials are never logged or written to translation history.
final class TranslationService: NSObject, ObservableObject, NSWindowDelegate {
    static let shared = TranslationService()
    @Published var input = ""
    @Published var source = TranslationLanguageDefaults.source
    @Published var target = TranslationLanguageDefaults.target
    @Published private(set) var output = ""
    @Published private(set) var message: String?
    @Published private(set) var busy = false
    @Published private(set) var copied = false
    @Published private(set) var request: TranslationRequest?
    @Published private(set) var listening = false
    @Published private(set) var presentation: TranslationPresentation = .editor
    @Published private(set) var engine = TranslationEngine(
        rawValue: UserDefaults.standard.string(forKey: DefaultsKey.translationEngine) ?? "") ?? .apple
    var privacyNotice: String { engine == .apple ? strings.privacy : strings.googlePrivacy }
    var engineName: String { engine == .apple ? strings.localEngine : strings.googleEngine }
    private var cloudTask: Task<Void, Never>?
    private var shortcutWasEnabled: Bool?
    private var panel: NSPanel?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var outsideClickMonitor: Any?
    private var localClickMonitor: Any?
    private var menuSubscriptions = Set<AnyCancellable>()
    private var trackingMenus = 0
    private var subscriptions = Set<AnyCancellable>()
    private var detector = TranslationDoubleCopyDetector()
    private var generation = TranslationGeneration()
    private var readInFlight = false
    private var started = false
    private var copyToken = UUID()
    private final class CopyObservation { var changeCount: Int? }
    private var firstCopy: CopyObservation?
    private var strings: TranslationStrings { TranslationStrings(language: L10n.shared.language) }

    func start() {
        guard !started else { return }
        started = true
        Permissions.shared.$accessibility.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.syncWithPreferences()
        }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main).sink { [weak self] _ in self?.syncWithPreferences() }
            .store(in: &subscriptions)
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.sessionDidResignActiveNotification)
            .receive(on: DispatchQueue.main).sink { [weak self] _ in self?.close() }
            .store(in: &subscriptions)
        syncWithPreferences()
    }

    func syncWithPreferences() {
        let enabled = UserDefaults.standard.bool(forKey: DefaultsKey.translationDoubleCopyEnabled)
        let wasEnabled = shortcutWasEnabled
        shortcutWasEnabled = enabled
        let selected = TranslationEngine(rawValue: UserDefaults.standard.string(forKey: DefaultsKey.translationEngine) ?? "") ?? .apple
        if selected != engine { engine = selected; inputDidChange() }
        applyPopupAppearance()
        checkGoogleUsageReminder()
        let supported: Bool
        if #available(macOS 15.0, *) { supported = true } else { supported = false }
        guard enabled, supported else {
            stopListening()
            // Unrelated preference writes must not close the manually opened
            // editor when the double-copy shortcut was already disabled.
            if !supported || wasEnabled == true { close() }
            return
        }
        guard AXIsProcessTrusted() else { stopListening(); return }
        guard globalMonitor == nil else { return }
        // Observation only: neither monitor consumes, rewrites or synthesizes keys.
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.observe(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.observe(event)
            return event
        }
        listening = globalMonitor != nil
    }

    func checkGoogleUsageReminder(at date: Date = Date()) {
        precondition(Thread.isMainThread)
        let defaults = UserDefaults.standard
        let usage = GoogleTranslationUsageStore.shared.snapshot(at: date)
        guard GoogleTranslationUsageReminder.shouldShow(
            usage: usage,
            enabled: defaults.bool(forKey: DefaultsKey.translationGoogleUsageReminderEnabled),
            lastShownMonth: defaults.string(forKey: DefaultsKey.translationGoogleUsageReminderMonth)) else { return }
        // Mark first: saving the month itself triggers another settings refresh.
        defaults.set(usage.month, forKey: DefaultsKey.translationGoogleUsageReminderMonth)
        QuickToolHUD.show(icon: "exclamationmark.triangle", message: strings.googleUsageReminderHUD,
                          dismissAfter: 5)
        if Bundle.main.bundleIdentifier != nil {
            NSAccessibility.post(element: NSApplication.shared, notification: .announcementRequested,
                                 userInfo: [.announcement: strings.googleUsageReminderHUD,
                                            .priority: NSAccessibilityPriorityLevel.medium.rawValue])
        }
    }

    func stop() {
        subscriptions.removeAll()
        stopListening()
        close()
        started = false
    }

    private func stopListening() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
        detector = TranslationDoubleCopyDetector()
        listening = false
    }

    private func observe(_ event: NSEvent) {
        guard !ShortcutCapture.isCapturing else { detector = .init(); return }
        // Do not trigger when copying the result/input from our own translator.
        guard panel?.isKeyWindow != true else { detector = .init(); return }
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        let isCopy = modifiers == .command && event.keyCode == UInt16(kVK_ANSI_C)
        let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0
        if detector.observe(isCopy: isCopy, isRepeat: event.isARepeat, time: event.timestamp, pid: pid) {
            // Give the second native Copy time to publish its pasteboard item.
            // Capture the source PID now; don't read another app's copy later.
            let token = generation.advance()
            let observation = firstCopy
            firstCopy = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
                guard let self, self.generation.accepts(token),
                      NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { return }
                self.useCopiedText(requiringChangeAfter: observation?.changeCount, requiresFreshCopy: true,
                                   presentation: .compact)
            }
        } else if isCopy, !event.isARepeat {
            let observation = CopyObservation()
            firstCopy = observation
            GeneralPasteboardAccess.shared.async(timeout: 0.6, { _ in NSPasteboard.general.changeCount },
                then: { count in observation.changeCount = count })
        } else if !isCopy {
            firstCopy = nil
        }
    }

    func open(_ mode: TranslationPresentation = .editor) {
        guard #available(macOS 15.0, *) else { return }
        let needsResize = panel == nil || presentation != mode
        presentation = mode
        var preferredSize = mode.preferredSize
        if mode == .compact {
            preferredSize.width = TranslationCompactLayout.width(UserDefaults.standard.double(forKey: DefaultsKey.translationPopupWidth))
        }
        if panel == nil {
            let created = TranslationPanel(contentRect: NSRect(origin: .zero, size: preferredSize),
                styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .fullSizeContentView],
                backing: .buffered, defer: false)
            created.title = strings.title
            created.titleVisibility = .hidden
            created.titlebarAppearsTransparent = true
            created.isMovableByWindowBackground = true
            for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
                created.standardWindowButton(button)?.isHidden = true
            }
            created.level = .floating
            created.hidesOnDeactivate = false
            created.isReleasedWhenClosed = false
            created.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            created.delegate = self
            created.contentView = NSHostingView(rootView: TranslationPanelView(model: self))
            panel = created
        }
        guard let panel else { return }
        panel.title = strings.title
        panel.contentMinSize = mode.minimumSize
        panel.contentMaxSize = NSSize(width: mode == .compact ? TranslationCompactLayout.widthRange.upperBound : .greatestFiniteMagnitude,
                                      height: .greatestFiniteMagnitude)
        if needsResize {
            let top = panel.frame.maxY
            let available = panel.screen?.visibleFrame.size ?? preferredSize
            panel.setContentSize(NSSize(width: min(preferredSize.width, available.width),
                                        height: min(preferredSize.height, available.height)))
            panel.setFrameOrigin(NSPoint(x: panel.frame.minX, y: top - panel.frame.height))
        }
        let point = NSEvent.mouseLocation
        let screen = panel.isVisible ? panel.screen :
            (NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main)
        if let frame = screen?.visibleFrame {
            let preferredX = panel.isVisible ? panel.frame.minX : point.x - 100
            let preferredY = panel.isVisible ? panel.frame.minY : point.y - panel.frame.height - 20
            let x = min(max(preferredX, frame.minX), max(frame.minX, frame.maxX - panel.frame.width))
            let y = min(max(preferredY, frame.minY), max(frame.minY, frame.maxY - panel.frame.height))
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        panel.makeKeyAndOrderFront(nil)
        updateDismissMonitors()
    }

    /// Resize only the compact result, keeping its top edge stable and on screen.
    func fitCompactContent(height: CGFloat) {
        guard presentation == .compact, let panel, height.isFinite,
              let screen = panel.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame.insetBy(dx: 8, dy: 8)
        let contentHeight = TranslationCompactLayout.height(for: height, available: visible.height)
        guard abs((panel.contentView?.bounds.height ?? 0) - contentHeight) > 1 else { return }
        resizeCompact(to: NSSize(width: panel.contentView?.bounds.width ?? CGFloat(TranslationCompactLayout.defaultWidth), height: contentHeight))
    }

    func applyPopupAppearance() {
        guard presentation == .compact, let panel, let content = panel.contentView else { return }
        let preferred = CGFloat(TranslationCompactLayout.width(UserDefaults.standard.double(forKey: DefaultsKey.translationPopupWidth)))
        let available = (panel.screen ?? NSScreen.main)?.visibleFrame.width ?? preferred
        let width = min(preferred, available - 16)
        guard abs(content.bounds.width - width) > 1 else { return }
        resizeCompact(to: NSSize(width: width, height: content.bounds.height))
    }

    private func resizeCompact(to size: NSSize) {
        guard let panel, let screen = panel.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame.insetBy(dx: 8, dy: 8)
        let top = panel.frame.maxY
        panel.setContentSize(size)
        let x = min(max(panel.frame.minX, visible.minX), max(visible.minX, visible.maxX - panel.frame.width))
        let y = min(max(top - panel.frame.height, visible.minY), max(visible.minY, visible.maxY - panel.frame.height))
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        guard presentation == .compact, let panel,
              notification.object as? NSWindow === panel, let content = panel.contentView else { return }
        let width = TranslationCompactLayout.width(content.bounds.width.rounded())
        if UserDefaults.standard.double(forKey: DefaultsKey.translationPopupWidth) != width {
            UserDefaults.standard.set(width, forKey: DefaultsKey.translationPopupWidth)
        }
    }

    func close() {
        removeDismissMonitors()
        cloudTask?.cancel()
        cloudTask = nil
        generation.advance()
        request = nil
        busy = false
        input = ""
        output = ""
        message = nil
        copied = false
        copyToken = UUID()
        panel?.orderOut(nil)
        // Release the SwiftUI task/session as well as all sensitive text.
        panel?.contentView = nil
        panel = nil
    }

    func windowWillClose(_ notification: Notification) { close() }

    private func updateDismissMonitors() {
        removeDismissMonitors()
        guard presentation == .compact else { return }
        NotificationCenter.default.publisher(for: NSMenu.didBeginTrackingNotification)
            .sink { [weak self] _ in self?.trackingMenus += 1 }
            .store(in: &menuSubscriptions)
        NotificationCenter.default.publisher(for: NSMenu.didEndTrackingNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                self.trackingMenus = max(0, self.trackingMenus - 1)
            }.store(in: &menuSubscriptions)
        let clicks: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: clicks) { [weak self] event in
            self?.dismissForClick(event, isLocal: true)
            // Observe only: the destination still receives the original click.
            return event
        }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: clicks) { [weak self] event in
            self?.dismissForClick(event, isLocal: false)
        }
    }

    private func dismissForClick(_ event: NSEvent, isLocal: Bool) {
        guard let panel else { return }
        // Native titlebar dragging can also reach the GLOBAL monitor, with
        // this panel's window number. Global delivery alone does not mean the
        // click was outside. Do not dismiss the very window being dragged.
        if !isLocal, event.windowNumber > 0, event.windowNumber == panel.windowNumber { return }
        var inside = false
        if isLocal {
            var window = event.window
            while let current = window {
                if current === panel { inside = true; break }
                window = current.parent ?? current.sheetParent
            }
            // AppKit menu windows need not be children of their originating
            // panel. Never dismiss while choosing a language or a text action.
            if event.window?.level == .popUpMenu { inside = true }
            if event.window == nil { inside = panel.frame.contains(NSEvent.mouseLocation) }
        }
        guard TranslationDismissalPolicy.shouldDismiss(
            presentation: presentation, isVisible: panel.isVisible, clickIsInside: inside,
            menuIsTracking: trackingMenus > 0,
            hasModal: panel.attachedSheet != nil || NSApp.modalWindow != nil,
            isAssistiveKeyboard: !isLocal && AssistiveKeyboard.ownsCocoaPoint(NSEvent.mouseLocation))
        else { return }
        close()
    }

    private func removeDismissMonitors() {
        if let localClickMonitor { NSEvent.removeMonitor(localClickMonitor) }
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        localClickMonitor = nil
        outsideClickMonitor = nil
        menuSubscriptions.removeAll()
        trackingMenus = 0
    }

    func useCopiedText(requiringChangeAfter baseline: Int? = nil, requiresFreshCopy: Bool = false,
                       presentation mode: TranslationPresentation? = nil) {
        guard !readInFlight else { return }
        cloudTask?.cancel()
        cloudTask = nil
        let token = generation.advance()
        request = nil
        busy = true
        message = strings.reading
        output = ""
        readInFlight = true
        GeneralPasteboardAccess.shared.async(timeout: 1.0, { _ -> Result<String, TranslationInputError>? in
            let pasteboard = NSPasteboard.general
            guard !requiresFreshCopy || TranslationTextPlan.isFreshCopy(baseline: baseline, current: pasteboard.changeCount)
            else { return .failure(.empty) }
            let types = Set((pasteboard.types ?? []).map(\.rawValue))
            guard TranslationTextPlan.protectedTypes.isDisjoint(with: types) else {
                return .failure(.sensitive)
            }
            let text = pasteboard.string(forType: .string) ?? ""
            do { return .success(try TranslationTextPlan.validate(text, types: types)) }
            catch let error as TranslationInputError { return .failure(error) }
            catch { return .failure(.empty) }
        }, then: { [weak self] result in
            guard let self, self.generation.accepts(token) else { return }
            self.open(mode ?? self.presentation)
            self.busy = false
            self.message = nil
            switch result {
            case .success(let text):
                self.input = text
                self.translate()
            case .failure(let error): self.message = self.inputMessage(error)
            case nil: self.message = self.strings.failed
            }
        }, didFinish: { [weak self] _ in self?.readInFlight = false })
    }

    func inputDidChange() {
        cloudTask?.cancel()
        cloudTask = nil
        generation.advance()
        request = nil
        output = ""
        busy = false
        message = nil
        copied = false
        copyToken = UUID()
    }

    func setEngine(_ value: TranslationEngine) {
        guard engine != value else { return }
        inputDidChange()
        engine = value
        UserDefaults.standard.set(value.rawValue, forKey: DefaultsKey.translationEngine)
        // Changing engines never silently sends existing text to Google.
        // A fresh Translate click (or double-copy gesture) is required.
    }

    func setSource(_ value: String) {
        guard source != value else { return }
        source = value
        languagesDidChange()
    }

    func setTarget(_ value: String) {
        guard target != value else { return }
        target = value
        languagesDidChange()
    }

    func swapLanguages() {
        guard source != "auto", !busy else { return }
        let originalSource = source
        source = target
        target = originalSource
        if !output.isEmpty { input = output }
        languagesDidChange()
    }

    private func languagesDidChange() {
        inputDidChange()
        if !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { translate() }
    }

    func translate() {
        do { _ = try TranslationTextPlan.validate(input) }
        catch { message = inputMessage(error); return }
        cloudTask?.cancel()
        cloudTask = nil
        generation.advance()
        output = ""
        copied = false
        message = nil
        busy = true
        copyToken = UUID()
        let prepared = TranslationLineBreakCleanup.prepare(input, enabled:
            UserDefaults.standard.bool(forKey: DefaultsKey.translationPDFLineBreakCleanup))
        let pending = TranslationRequest(text: prepared, source: source == "auto" ? nil : source,
                                         target: target, engine: engine)
        request = pending
        guard engine == .google else { return }
        cloudTask = Task { @MainActor [weak self] in
            do {
                let key = try await Task.detached { try TranslationKeychain().load() }.value
                try Task.checkCancellation()
                guard let self, self.request?.id == pending.id else { return }
                guard let key else { throw GoogleTranslationError.missingKey }
                let client = GoogleTranslationClient()
                let translated = try await client.translate(pending, key: key)
                try Task.checkCancellation()
                self.finish(pending.id, result: .success(translated))
            } catch {
                self?.finish(pending.id, result: .failure(error))
            }
        }
    }

    func cancel() {
        cloudTask?.cancel()
        cloudTask = nil
        generation.advance()
        request = nil
        busy = false
        message = nil
    }

    func finish(_ id: UUID, result: Result<String, Error>) {
        guard request?.id == id else { return }
        cloudTask = nil
        busy = false
        switch result {
        case .success(let text): output = text; message = nil
        case .failure(let error):
            if error is CancellationError { message = nil }
            else if error is TranslationUnsupportedPair { message = strings.unsupported }
            else if error is TranslationUnknownSource { message = strings.unknownSource }
            else if let error = error as? GoogleTranslationError { message = strings.googleError(error) }
            else if error is TranslationKeychain.Failure { message = strings.keychainFailed }
            else if error is TranslationInputError { message = inputMessage(error) }
            else { message = strings.failed }
        }
        request = nil
    }

    func copyOutput() {
        guard !output.isEmpty else { return }
        let text = output
        let token = UUID()
        copyToken = token
        // Mark this explicit copy transient so clipboard history doesn't turn
        // the translator into a persistent history through a second feature.
        GeneralPasteboardAccess.shared.async(timeout: 1.0, { _ -> Bool? in
            let item = NSPasteboardItem()
            item.setString(text, forType: .string)
            item.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
            NSPasteboard.general.clearContents()
            return NSPasteboard.general.writeObjects([item])
        }, then: { [weak self] result in
            guard let self, self.copyToken == token else { return }
            self.copied = result == true
            if result != true { self.message = self.strings.failed }
        })
    }

    private func inputMessage(_ error: Error) -> String {
        switch error {
        case TranslationInputError.tooLong: return strings.tooLong
        case TranslationInputError.sensitive: return strings.sensitive
        default: return strings.empty
        }
    }
}

struct TranslationUnsupportedPair: Error {}
struct TranslationUnknownSource: Error {}

private final class TranslationPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { close() }
}
