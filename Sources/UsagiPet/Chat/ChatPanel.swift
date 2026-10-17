import AppKit
import WebKit

/// 말풍선 UI(입력칸 + 답변). 실제 ChatGPT는 숨긴 웹뷰가 처리하고, JS 브리지로 입력/답변을 주고받는다.
final class ChatPanel: NSPanel, WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler, NSTextFieldDelegate {
    static let home = URL(string: "https://chatgpt.com")!
    // Google 로그인(disallowed_useragent) 우회용 Safari UA — 1안 검증 대상
    static let safariUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

    private let web: WKWebView
    private let webWindow: NSWindow          // 숨김 웹뷰의 집. 로그인할 때만 보임
    private let scroll = NSScrollView()
    private let list = NSStackView()
    private let doc = FlippedView()
    private let input = NSTextField()
    private let sendBtn = NSButton()
    private var current: BubbleView?         // 받는 중인 답변 말풍선
    private var busy = false
    private let usagiFace = loadUsagiImage()
    private let meFace = NSImage(named: "me") ?? Bundle.main.url(forResource: "me", withExtension: "png").flatMap { NSImage(contentsOf: $0) }
    private var bridgeSource = ""

    init() {
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .default()    // 로그인 쿠키 유지
        web = WKWebView(frame: .init(x: 0, y: 0, width: 420, height: 640), configuration: cfg)
        web.customUserAgent = Self.safariUA
        web.autoresizingMask = [.width, .height]
        if let url = Bundle.main.url(forResource: "bridge", withExtension: "js"), let js = try? String(contentsOf: url) {
            bridgeSource = js
            cfg.userContentController.addUserScript(.init(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        }
        webWindow = NSWindow(contentRect: web.frame, styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        webWindow.contentView = web
        webWindow.title = "ChatGPT (로그인용)"
        webWindow.isReleasedWhenClosed = false
        webWindow.collectionBehavior = [.canJoinAllSpaces]

        let w = Store.d.object(forKey: "chatW") as? CGFloat ?? 380
        let h = Store.d.object(forKey: "chatH") as? CGFloat ?? 480
        super.init(contentRect: .init(x: 0, y: 0, width: w, height: h),
                   styleMask: [.borderless, .resizable, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        minSize = .init(width: 260, height: 220)

        cfg.userContentController.add(self, name: "usagi")
        web.uiDelegate = self
        web.navigationDelegate = self
        web.load(URLRequest(url: Self.home))
        hideWebWindow()

        buildUI()
        NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification, object: self, queue: .main) { [unowned self] _ in
            Store.d.set(frame.width, forKey: "chatW"); Store.d.set(frame.height, forKey: "chatH")
        }
    }

    private func buildUI() {
        // 상단 버튼 바
        let barBox = ChromeBox(); barBox.radius = 12
        let bar = NSStackView(views: [button("새 대화", #selector(newChat)), button("웹 화면", #selector(showWebWindow)), button("닫기", #selector(hide))])
        bar.spacing = 10; bar.translatesAutoresizingMaskIntoConstraints = false
        barBox.addSubview(bar)

        // 말풍선 목록
        list.orientation = .vertical; list.spacing = 10; list.alignment = .leading
        list.translatesAutoresizingMaskIntoConstraints = false
        doc.addSubview(list)
        doc.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = doc
        scroll.drawsBackground = false
        scroll.verticalScroller = ClearScroller()
        scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true; scroll.scrollerStyle = .overlay   // 넘칠 때만 표시
        scroll.contentView.drawsBackground = false

        // 입력칸(ChromeBox) + 보내기 버튼
        let inBox = ChromeBox(); inBox.radius = 18
        input.isBordered = false; input.drawsBackground = false; input.focusRingType = .none
        input.font = Theme.font(19); input.textColor = .black
        input.placeholderString = "우사기에게 물어보기..."
        input.delegate = self; input.target = self; input.action = #selector(submit)
        input.translatesAutoresizingMaskIntoConstraints = false
        sendBtn.isBordered = false; sendBtn.wantsLayer = true
        sendBtn.layer?.backgroundColor = Theme.purple.cgColor; sendBtn.layer?.cornerRadius = 18
        sendBtn.image = NSImage(systemSymbolName: "arrow.up", accessibilityDescription: "보내기")
        sendBtn.contentTintColor = .white; sendBtn.target = self; sendBtn.action = #selector(submit)
        sendBtn.translatesAutoresizingMaskIntoConstraints = false
        inBox.addSubview(input); inBox.addSubview(sendBtn)

        let root = NSView()
        let grip = ResizeGrip()
        for v in [barBox, scroll, inBox, grip] { v.translatesAutoresizingMaskIntoConstraints = false; root.addSubview(v) }
        NSLayoutConstraint.activate([
            barBox.topAnchor.constraint(equalTo: root.topAnchor, constant: 4), barBox.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 8),
            barBox.heightAnchor.constraint(equalToConstant: 34),
            bar.leadingAnchor.constraint(equalTo: barBox.leadingAnchor, constant: 14), bar.trailingAnchor.constraint(equalTo: barBox.trailingAnchor, constant: -14),
            bar.centerYAnchor.constraint(equalTo: barBox.centerYAnchor),
            scroll.topAnchor.constraint(equalTo: barBox.bottomAnchor, constant: 4),
            scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: inBox.topAnchor, constant: -6),
            inBox.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 8), inBox.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -8),
            inBox.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -16), inBox.heightAnchor.constraint(equalToConstant: 52),
            input.leadingAnchor.constraint(equalTo: inBox.leadingAnchor, constant: 18), input.trailingAnchor.constraint(equalTo: sendBtn.leadingAnchor, constant: -8),
            input.centerYAnchor.constraint(equalTo: inBox.centerYAnchor),
            sendBtn.trailingAnchor.constraint(equalTo: inBox.trailingAnchor, constant: -10), sendBtn.centerYAnchor.constraint(equalTo: inBox.centerYAnchor),
            sendBtn.widthAnchor.constraint(equalToConstant: 36), sendBtn.heightAnchor.constraint(equalToConstant: 36),
            grip.trailingAnchor.constraint(equalTo: root.trailingAnchor), grip.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            grip.widthAnchor.constraint(equalToConstant: 16), grip.heightAnchor.constraint(equalToConstant: 16),
            doc.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            list.topAnchor.constraint(equalTo: doc.topAnchor, constant: 6), list.bottomAnchor.constraint(equalTo: doc.bottomAnchor, constant: -6),
            list.leadingAnchor.constraint(equalTo: doc.leadingAnchor, constant: 8), list.trailingAnchor.constraint(equalTo: doc.trailingAnchor, constant: -8),
        ])
        contentView = root
        NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification, object: self, queue: .main) { [unowned self] _ in
            for r in list.arrangedSubviews { (r.subviews.first as? BubbleView)?.fit(maxBubbleWidth) }
        }
    }

    private var maxBubbleWidth: CGFloat { max(120, (frame.width - 16) * 0.92) }

    /// 말풍선 한 줄 추가. 나는 오른쪽, 우사기는 왼쪽
    @discardableResult
    private func addBubble(user: Bool, _ text: String) -> BubbleView {
        let b = BubbleView(title: user ? "나" : "우사기", avatar: user ? meFace : usagiFace, isUser: user)
        let row = NSView(); row.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(b)
        list.addArrangedSubview(row)     // 같은 뷰 계층에 들어간 뒤에 제약을 활성화해야 함
        NSLayoutConstraint.activate([
            b.topAnchor.constraint(equalTo: row.topAnchor), b.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            user ? b.trailingAnchor.constraint(equalTo: row.trailingAnchor) : b.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            row.widthAnchor.constraint(equalTo: list.widthAnchor),
        ])
        b.set(text, maxWidth: maxBubbleWidth)
        scrollToEnd()
        return b
    }

    private func scrollToEnd() {
        DispatchQueue.main.async { [self] in
            doc.layoutSubtreeIfNeeded()
            scroll.contentView.scroll(to: .init(x: 0, y: max(0, doc.frame.height - scroll.contentView.bounds.height)))
            scroll.reflectScrolledClipView(scroll.contentView)
        }
    }

    func control(_ c: NSControl, textView: NSTextView, doCommandBy sel: Selector) -> Bool {
        if sel == #selector(cancelOperation(_:)) { hide(); return true }   // 입력 중 Esc
        return false
    }

    private func button(_ t: String, _ a: Selector) -> NSButton {
        let b = NSButton(title: t, target: self, action: a)
        b.isBordered = false
        b.attributedTitle = NSAttributedString(string: t, attributes: [.font: Theme.font(16, bold: true), .foregroundColor: NSColor.black])
        return b
    }

    // MARK: 전송 / 수신
    @objc private func submit() {
        let text = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !busy else { return }
        input.stringValue = ""
        busy = true; input.isEnabled = false
        addBubble(user: true, text)
        current = addBubble(user: false, "...")
        let js = "window.__usagiSend(\(String(data: try! JSONEncoder().encode(text), encoding: .utf8)!))"
        web.evaluateJavaScript(bridgeSource) { [weak self] _, _ in   // 주입이 빠졌을 때 대비(중복 가드 있음)
            self?.web.evaluateJavaScript(js) { [weak self] _, err in
                if let err { self?.fail("JS 실행 실패: \(err.localizedDescription)") }
            }
        }
    }

    func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {
        guard let d = m.body as? [String: Any], let type = d["type"] as? String else { return }
        let text = d["text"] as? String ?? ""
        switch type {
        case "delta": current?.set(text, maxWidth: maxBubbleWidth); scrollToEnd()
        case "done": finish()
        default: fail(text)
        }
    }

    private func finish() {
        current = nil; busy = false; input.isEnabled = true
        makeFirstResponder(input)
    }

    private func fail(_ msg: String) {
        if let c = current { c.set("[오류] \(msg)", maxWidth: maxBubbleWidth) } else { addBubble(user: false, "[오류] \(msg)") }
        finish(); showWebWindow()          // 로그인 문제일 가능성이 높아 웹 화면을 띄움
    }

    // MARK: 창
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { hide() }   // Esc
    @objc func hide() { orderOut(nil) }                        // 숨기기만 -> 대화 유지
    @objc func newChat() {
        guard !busy else { return }
        list.arrangedSubviews.forEach { $0.removeFromSuperview() }
        web.load(URLRequest(url: Self.home))
    }

    /// 숨김 모드: 투명 + 클릭 통과. 화면엔 안 보이지만 JS는 계속 돌아간다.
    private func hideWebWindow() {
        webWindow.alphaValue = 0; webWindow.ignoresMouseEvents = true
        webWindow.orderFrontRegardless()
        webWindow.makeFirstResponder(web)
    }
    @objc func showWebWindow() {
        webWindow.alphaValue = 1; webWindow.ignoresMouseEvents = false
        webWindow.center(); webWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func toggle(near character: NSRect) {
        if isVisible { hide() } else { place(near: character); makeKeyAndOrderFront(nil); makeFirstResponder(input) }
    }

    /// 여백이 넓은 쪽(좌/우)에 배치, 화면 안으로 보정
    func place(near c: NSRect) {
        let v = (NSScreen.screens.first { $0.frame.intersects(c) } ?? NSScreen.main!).visibleFrame
        let w = frame.width, h = frame.height
        let right = v.maxX - c.maxX >= c.minX - v.minX
        let x = right ? c.maxX + 8 : c.minX - w - 8
        let y = min(max(c.maxY - h, v.minY), v.maxY - h)
        setFrameOrigin(.init(x: x, y: y))
    }

    // MARK: 웹뷰 delegate
    func webView(_ w: WKWebView, createWebViewWith c: WKWebViewConfiguration, for a: WKNavigationAction,
                 windowFeatures f: WKWindowFeatures) -> WKWebView? {
        if let u = a.request.url { NSWorkspace.shared.open(u) }; return nil
    }
    func webView(_ w: WKWebView, decidePolicyFor a: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let host = a.request.url?.host ?? ""
        let own = ["chatgpt.com", "openai.com", "google.com", "gstatic.com", "oaistatic.com"].contains { host.hasSuffix($0) }
        if a.navigationType == .linkActivated, !own, let u = a.request.url {
            NSWorkspace.shared.open(u); decisionHandler(.cancel)
        } else { decisionHandler(.allow) }
    }
    func webView(_ w: WKWebView, runOpenPanelWith p: WKOpenPanelParameters, initiatedByFrame: WKFrameInfo,
                 completionHandler: @escaping ([URL]?) -> Void) {
        let op = NSOpenPanel(); op.allowsMultipleSelection = p.allowsMultipleSelection
        completionHandler(op.runModal() == .OK ? op.urls : nil)
    }
    func webView(_ w: WKWebView, requestMediaCapturePermissionFor o: WKSecurityOrigin, initiatedByFrame f: WKFrameInfo,
                 type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.grant)
    }
}
