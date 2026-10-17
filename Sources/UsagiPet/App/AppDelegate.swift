import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let character = CharacterPanel()
    let chat = ChatPanel()
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let toggleItem = NSMenuItem(), loginItem = NSMenuItem()

    func applicationDidFinishLaunching(_ n: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMainMenu()
        character.view.onClick = { [unowned self] in chat.toggle(near: character.frame) }
        character.view.onMove = { [unowned self] in if chat.isVisible { chat.place(near: character.frame) } }
        character.orderFrontRegardless()
        LoginItemService.enableOnFirstLaunch()
        setupStatusItem()
    }

    func setupStatusItem() {
        item.button?.title = "🐰"
        let m = NSMenu()
        toggleItem.action = #selector(toggleVisible); toggleItem.target = self
        m.addItem(toggleItem)
        let sizes = NSMenu()
        for (t, s) in [("작게", 120), ("보통", 160), ("크게", 220)] {
            let i = NSMenuItem(title: t, action: #selector(setSize(_:)), keyEquivalent: ""); i.target = self; i.tag = s
            sizes.addItem(i)
        }
        let sz = NSMenuItem(title: "크기", action: nil, keyEquivalent: ""); sz.submenu = sizes
        m.addItem(sz)
        loginItem.title = "로그인 시 실행"; loginItem.action = #selector(toggleLogin); loginItem.target = self
        m.addItem(loginItem)
        let r = NSMenuItem(title: "위치 초기화", action: #selector(resetPos), keyEquivalent: ""); r.target = self
        m.addItem(r)
        m.addItem(.separator())
        m.addItem(withTitle: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        m.delegate = self
        item.menu = m
        character.view.menu_ = m
    }

    @objc func toggleVisible() {
        if character.isVisible { chat.hide(); character.orderOut(nil) } else { character.orderFrontRegardless() }
    }
    @objc func setSize(_ i: NSMenuItem) { character.resize(CGFloat(i.tag)); character.view.onMove() }
    @objc func toggleLogin() { LoginItemService.set(!LoginItemService.isOn) }
    @objc func resetPos() { character.resetPosition() }

    /// 액세서리 앱엔 메뉴바가 없어 Cmd+C/V가 안 먹으므로 Edit 메뉴만 둠
    func setupMainMenu() {
        let main = NSMenu(), edit = NSMenu(title: "Edit")
        for (t, a, k) in [("Cut", "cut:", "x"), ("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] {
            edit.addItem(withTitle: t, action: Selector(a), keyEquivalent: k)
        }
        let e = NSMenuItem(); e.submenu = edit
        main.addItem(e)
        NSApp.mainMenu = main
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        toggleItem.title = character.isVisible ? "우사기 숨기기" : "우사기 보이기"
        loginItem.state = LoginItemService.isOn ? .on : .off
    }
}
