import AppKit
import CoreText

enum Theme {
    /// 앱에 포함한 폰트(Resources/fonts)를 등록. 실패하면 시스템 폰트로 대체됨
    static func registerFonts() {
        for n in ["Gaegu-Regular", "Gaegu-Bold"] {
            if let u = Bundle.main.url(forResource: n, withExtension: "ttf") {
                CTFontManagerRegisterFontsForURL(u as CFURL, .process, nil)
            }
        }
    }
    static func font(_ size: CGFloat, bold: Bool = false) -> NSFont {
        NSFont(name: bold ? "Gaegu-Bold" : "Gaegu-Regular", size: size) ?? .systemFont(ofSize: size - 2, weight: bold ? .bold : .regular)
    }
    static let sky = NSColor(red: 0.74, green: 0.88, blue: 0.98, alpha: 1)
    static let purple = NSColor(red: 0.74, green: 0.70, blue: 0.92, alpha: 1)
}

/// 흰 바탕 + 두꺼운 검은 테두리 둥근 상자 (입력칸, 상단 버튼 바)
final class ChromeBox: NSView {
    var radius: CGFloat = 14
    override func draw(_ r: NSRect) {
        let p = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: radius, yRadius: radius)
        NSColor.white.setFill(); p.fill()
        NSColor.black.setStroke(); p.lineWidth = 3; p.stroke()
    }
}

final class FlippedView: NSView { override var isFlipped: Bool { true } }

/// 말풍선: 제목 줄 + 아바타 + 본문. 크기는 글자 길이에 맞춰 직접 계산한다.
final class BubbleView: NSView {
    override var isFlipped: Bool { true }
    let isUser: Bool
    private(set) var text = ""
    private let body = NSTextField(labelWithString: "")
    private var wC: NSLayoutConstraint!, hC: NSLayoutConstraint!, bodyW: NSLayoutConstraint!, bodyH: NSLayoutConstraint!
    private static let pad: CGFloat = 16, head: CGFloat = 36

    init(title: String, avatar: NSImage?, isUser: Bool) {
        self.isUser = isUser
        super.init(frame: .zero)
        wC = widthAnchor.constraint(equalToConstant: 100); hC = heightAnchor.constraint(equalToConstant: 80)
        bodyW = body.widthAnchor.constraint(equalToConstant: 50); bodyH = body.heightAnchor.constraint(equalToConstant: 20)
        translatesAutoresizingMaskIntoConstraints = false
        let t = NSTextField(labelWithString: title)
        t.font = Theme.font(15, bold: true); t.textColor = .black
        body.font = Theme.font(18); body.textColor = .black
        body.lineBreakMode = .byWordWrapping; body.maximumNumberOfLines = 0
        body.isSelectable = true; body.allowsEditingTextAttributes = false
        for v in [t, body] { v.translatesAutoresizingMaskIntoConstraints = false; addSubview(v) }
        var cs: [NSLayoutConstraint] = [wC, hC, bodyW, bodyH,
                  t.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14), t.topAnchor.constraint(equalTo: topAnchor, constant: 7),
                  body.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.pad), body.topAnchor.constraint(equalTo: topAnchor, constant: Self.head + 6)]
        if let avatar {
            let box = NSView(); box.wantsLayer = true; box.translatesAutoresizingMaskIntoConstraints = false
            box.layer?.backgroundColor = Theme.sky.cgColor; box.layer?.cornerRadius = 5
            box.layer?.borderWidth = 1.5; box.layer?.borderColor = NSColor.black.cgColor
            let iv = NSImageView(image: avatar); iv.imageScaling = .scaleProportionallyUpOrDown
            iv.translatesAutoresizingMaskIntoConstraints = false
            box.addSubview(iv); addSubview(box)
            cs += [box.widthAnchor.constraint(equalToConstant: 26), box.heightAnchor.constraint(equalToConstant: 26),
                   box.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10), box.topAnchor.constraint(equalTo: topAnchor, constant: 5),
                   iv.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 2), iv.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -2),
                   iv.topAnchor.constraint(equalTo: box.topAnchor, constant: 2), iv.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -2)]
        }
        NSLayoutConstraint.activate(cs)
    }
    required init?(coder: NSCoder) { fatalError() }

    func set(_ s: String, maxWidth: CGFloat) { text = s; fit(maxWidth) }

    /// 글자 폭에 맞춰 줄이고, maxWidth를 넘으면 줄바꿈
    func fit(_ maxWidth: CGFloat) {
        body.stringValue = text
        let attr = NSAttributedString(string: text, attributes: [.font: body.font!])
        let w = min(max(ceil(attr.size().width) + 4, 80), maxWidth - 2 * Self.pad)
        let h = ceil(body.cell!.cellSize(forBounds: .init(x: 0, y: 0, width: w, height: .greatestFiniteMagnitude)).height)  // 라벨이 실제로 쓰는 높이
        bodyW.constant = w; bodyH.constant = h
        wC.constant = w + 2 * Self.pad; hC.constant = Self.head + 6 + h + 16
        needsDisplay = true
    }

    override func draw(_ r: NSRect) {
        let p = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 14, yRadius: 14)
        NSColor.white.setFill(); p.fill()
        NSColor.black.setStroke(); p.lineWidth = 3; p.stroke()
        let l = NSBezierPath(); l.move(to: .init(x: 2, y: Self.head)); l.line(to: .init(x: bounds.width - 2, y: Self.head))
        l.lineWidth = 2; l.stroke()
    }
}

/// 오른쪽 아래 모서리를 끌어 창 크기 조절 (테두리 없는 창은 기본 조절이 안 됨)
final class ResizeGrip: NSView {
    private var startMouse = NSPoint.zero, startFrame = NSRect.zero
    override func draw(_ r: NSRect) {
        NSColor.black.withAlphaComponent(0.55).setStroke()
        for i in [4, 8, 12] as [CGFloat] {
            let p = NSBezierPath(); p.move(to: .init(x: bounds.maxX - 1, y: bounds.minY + i)); p.line(to: .init(x: bounds.maxX - i, y: bounds.minY + 1))
            p.lineWidth = 2; p.lineCapStyle = .round; p.stroke()
        }
    }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }
    override func mouseDown(with e: NSEvent) { startMouse = NSEvent.mouseLocation; startFrame = window!.frame }
    override func mouseDragged(with e: NSEvent) {
        guard let w = window else { return }
        let m = NSEvent.mouseLocation
        let nw = max(w.minSize.width, startFrame.width + m.x - startMouse.x)
        let nh = max(w.minSize.height, startFrame.height - (m.y - startMouse.y))
        w.setFrame(.init(x: startFrame.minX, y: startFrame.maxY - nh, width: nw, height: nh), display: true)
    }
}

/// 트랙(배경) 없이 손잡이만 그리는 스크롤바
final class ClearScroller: NSScroller {
    override class var isCompatibleWithOverlayScrollers: Bool { true }
    override func drawKnobSlot(in rect: NSRect, highlight: Bool) {}
}
