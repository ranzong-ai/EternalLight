import Cocoa
import UserNotifications
import ServiceManagement

// 长明 EternalLight — menu-bar toggle for `pmset disablesleep`.
// Icon-only status item: golden lamp (breathing) = always-on, gray lamp = normal sleep.
// Click opens a small panel with the live state and the toggle button.

class PanelController: NSViewController {
    var statusLabel: NSTextField!
    var subLabel: NSTextField!
    var toggleButton: NSButton!
    var onToggle: (() -> Void)?
    var onQuit: (() -> Void)?

    override func loadView() {
        // No app icon inside the panel by design: it is a control, not a showcase.
        // Layout is composed as four groups with tight spacing inside a group and
        // clear air between groups; a hairline separates the footer (quit) group,
        // so the two small notes never blur into one gray block.
        // Type system (v3.8): the Songti title is the identity mark and stays.
        // Everything else is system font; the status line is 13 semibold in
        // labelColor, and EVERY caption (subtitle, state note, auth hint,
        // quit note, quit button) shares one tier: 11 regular, secondaryLabelColor.
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 264, height: 228))

        // Group 1 — identity
        let name = NSTextField(labelWithString: "长明")
        name.font = NSFont(name: "Songti SC Bold", size: 18) ?? NSFont(name: "Songti SC", size: 18) ?? .boldSystemFont(ofSize: 17)
        name.alignment = .center
        name.frame = NSRect(x: 12, y: 198, width: 240, height: 26)
        root.addSubview(name)

        let subtitle = NSTextField(labelWithString: "Eternal Light")
        subtitle.font = .systemFont(ofSize: 11)
        subtitle.textColor = .secondaryLabelColor
        subtitle.alignment = .center
        subtitle.frame = NSRect(x: 12, y: 181, width: 240, height: 16)
        root.addSubview(subtitle)

        // Group 2 — current state
        statusLabel = NSTextField(labelWithString: "—")
        statusLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        statusLabel.alignment = .center
        statusLabel.frame = NSRect(x: 12, y: 152, width: 240, height: 20)
        root.addSubview(statusLabel)

        subLabel = NSTextField(labelWithString: "—")
        subLabel.font = .systemFont(ofSize: 11)
        subLabel.textColor = .secondaryLabelColor
        subLabel.alignment = .center
        subLabel.frame = NSRect(x: 12, y: 132, width: 240, height: 18)
        root.addSubview(subLabel)

        // Group 3 — the action, with its explanation attached
        toggleButton = NSButton(title: "切换", target: self, action: #selector(toggleClicked))
        toggleButton.bezelStyle = .rounded
        toggleButton.controlSize = .large
        toggleButton.frame = NSRect(x: 57, y: 94, width: 150, height: 30)
        root.addSubview(toggleButton)

        // Explains the sudo trust cache in plain words, so neither prompt state
        // surprises the user: asked for a fingerprint, or passed straight through.
        let authHint = NSTextField(labelWithString: "切换时验证指纹；刚验证过会直接通过")
        authHint.font = .systemFont(ofSize: 11)
        authHint.textColor = .secondaryLabelColor
        authHint.alignment = .center
        authHint.frame = NSRect(x: 12, y: 74, width: 240, height: 14)
        root.addSubview(authHint)

        // Group 4 — footer: quit, behind a hairline
        let separator = NSBox()
        separator.boxType = .separator
        separator.frame = NSRect(x: 16, y: 56, width: 232, height: 1)
        root.addSubview(separator)

        let quitNote = NSTextField(labelWithString: "退出不改变当前模式")
        quitNote.font = .systemFont(ofSize: 11)
        quitNote.textColor = .secondaryLabelColor
        quitNote.alignment = .center
        quitNote.frame = NSRect(x: 12, y: 34, width: 240, height: 14)
        root.addSubview(quitNote)

        let quit = NSButton(title: "退出长明", target: self, action: #selector(quitClicked))
        quit.bezelStyle = .inline
        quit.font = .systemFont(ofSize: 11)
        quit.contentTintColor = .secondaryLabelColor
        quit.frame = NSRect(x: 97, y: 10, width: 70, height: 20)
        root.addSubview(quit)

        self.view = root
    }

    @objc func toggleClicked() { onToggle?() }
    @objc func quitClicked() { onQuit?() }

    func update(disabled: Bool) {
        loadViewIfNeeded()
        if disabled {
            statusLabel.stringValue = "当前：常开模式"
            subLabel.stringValue = "合盖、闲置都不睡 · 随时可远程接入"
            toggleButton.title = "切回正常模式"
        } else {
            statusLabel.stringValue = "当前：正常模式"
            subLabel.stringValue = "合盖、闲置都会睡"
            toggleButton.title = "开启常开模式"
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var panel: PanelController!
    var pollTimer: Timer?
    var onImage: NSImage?
    var offImage: NSImage?

    func sleepDisabled() -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        p.arguments = ["-g"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        do { try p.run() } catch { return false }
        p.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let out = String(data: data, encoding: .utf8) ?? ""
        for line in out.split(separator: "\n") {
            if line.lowercased().contains("sleepdisabled") {
                let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
                if let last = parts.last { return last == "1" }
            }
        }
        return false
    }

    func loadImages() {
        // Template glyphs: black + alpha only, the system tints them for light/dark menu bars.
        // Static by design: at 20pt a sway animation is invisible, so state is one variable —
        // solid flame (on) vs the same flame at 35% alpha (off).
        if let url = Bundle.main.url(forResource: "menubar_on", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            img.size = NSSize(width: 20, height: 20)
            img.isTemplate = true
            onImage = img
        }
        if let url = Bundle.main.url(forResource: "menubar_off", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            img.size = NSSize(width: 20, height: 20)
            img.isTemplate = true
            offImage = img
        }
    }

    func applicationDidFinishLaunching(_ note: Notification) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        // Self-register as a login item through the modern service API, so the
        // app appears under 设置 → 登录时打开 with its own name and icon —
        // a hand-written LaunchAgent plist lands in the background-items list
        // instead, shown as a bare executable from an "unidentified developer".
        if SMAppService.mainApp.status != .enabled {
            try? SMAppService.mainApp.register()
        }
        // Self-report the login-item status for remote diagnostics.
        let statusLine = "loginItemStatus=\(SMAppService.mainApp.status.rawValue)\n"
        try? statusLine.write(toFile: "/tmp/eternallight-launch.log", atomically: true, encoding: .utf8)
        loadImages()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let btn = statusItem.button {
            btn.action = #selector(togglePopover)
            btn.target = self
            btn.toolTip = "长明"
        }

        panel = PanelController()
        panel.onToggle = { [weak self] in self?.toggleMode() }
        panel.onQuit = { NSApp.terminate(nil) }
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = panel

        refresh()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in self.refresh() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPopover()
        return false
    }

    @objc func togglePopover() {
        if popover.isShown { popover.performClose(nil) } else { showPopover() }
    }

    func showPopover() {
        guard let btn = statusItem.button else { return }
        refresh()
        popover.show(relativeTo: btn.bounds, of: btn, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    func refresh() {
        let disabled = sleepDisabled()
        DispatchQueue.main.async {
            self.panel.update(disabled: disabled)
            self.statusItem.button?.image = disabled ? self.onImage : self.offImage
        }
    }

    // Touch ID path is available when the user has enabled pam_tid for sudo
    // (one-time setup: /etc/pam.d/sudo_local with an active pam_tid line).
    func touchIDEnabled() -> Bool {
        guard let text = try? String(contentsOfFile: "/etc/pam.d/sudo_local", encoding: .utf8) else { return false }
        return text.contains("pam_tid")
    }

    // Runs pmset through sudo spawned directly from the app process, so sudo
    // inherits the app's GUI audit session and pam_tid can present the Touch ID
    // sheet. (An earlier build routed through /usr/bin/script, whose new pty
    // session made pam_tid decline silently.) No tty is attached: if Touch ID
    // is cancelled or unavailable, sudo exits at once and the caller falls back
    // to the password dialog. A watchdog caps the wait regardless.
    func toggleViaTouchID(target: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        p.arguments = ["/usr/bin/pmset", "disablesleep", target]
        p.standardInput = FileHandle.nullDevice
        var env = ProcessInfo.processInfo.environment
        env["SUDO_ASKPASS"] = "/usr/bin/false"
        p.environment = env
        let outPipe = Pipe()
        let errPipe = Pipe()
        p.standardOutput = outPipe
        p.standardError = errPipe
        do { try p.run() } catch { return }
        DispatchQueue.global().asyncAfter(deadline: .now() + 90) {
            if p.isRunning { p.terminate() }
        }
        p.waitUntilExit()
        // Diagnostic: keep the last attempt's output for inspection.
        let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let log = "status=\(p.terminationStatus)\nstdout:\n\(out)\nstderr:\n\(err)\n"
        try? log.write(toFile: "/tmp/eternallight-sudo.log", atomically: true, encoding: .utf8)
    }

    @objc func toggleMode() {
        let target = sleepDisabled() ? "0" : "1"
        let wantDisabled = target == "1"
        if touchIDEnabled() {
            toggleViaTouchID(target: target)
        }
        if sleepDisabled() != wantDisabled {
            // Touch ID not set up, cancelled or unavailable (e.g. lid closed):
            // fall back to the classic administrator password dialog.
            let script = "do shell script \"pmset disablesleep \(target)\" with administrator privileges"
            var err: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&err)
        }
        refresh()
        postNotification(disabled: sleepDisabled())
    }

    func postNotification(disabled: Bool) {
        let content = UNMutableNotificationContent()
        content.title = "长明"
        content.body = disabled ? "已切到常开模式：合盖、闲置都不睡" : "已切回正常模式：合盖、闲置都会睡"
        content.sound = .default
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
