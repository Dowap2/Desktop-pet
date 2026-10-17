import AppKit

/// 우사기 이미지. usagi.gif(클릭 시 재생) 우선, 없으면 usagi.png, 둘 다 없으면 임시 도형.
func loadUsagiImage() -> NSImage {
    for ext in ["gif", "png"] {
        if let url = Bundle.main.url(forResource: "usagi", withExtension: ext),
           let img = NSImage(contentsOf: url) { return img }
    }
    return NSImage(size: .init(width: 200, height: 200), flipped: false) { r in
        NSColor.white.setFill(); NSBezierPath(ovalIn: r.insetBy(dx: 10, dy: 10)).fill()
        NSColor.gray.setStroke(); NSBezierPath(ovalIn: r.insetBy(dx: 10, dy: 10)).stroke()
        ("우사기" as NSString).draw(at: .init(x: 62, y: 90), withAttributes: [.font: NSFont.systemFont(ofSize: 24)])
        return true
    }
}

final class CharacterView: NSView {
    var onClick: () -> Void = {}
    var onMove: () -> Void = {}
    private var downMouse = NSPoint.zero
    private var downOrigin = NSPoint.zero
    private var moved = false
    private let iv = NSImageView()
    private var playGen = 0

    override init(frame: NSRect) {
        super.init(frame: frame)
        iv.frame = bounds
        iv.image = loadUsagiImage()
        iv.animates = false                      // 평소엔 첫 프레임 정지
        iv.imageScaling = .scaleProportionallyUpOrDown
        iv.autoresizingMask = [.width, .height]
        addSubview(iv)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func hitTest(_ p: NSPoint) -> NSView? { frame.contains(p) ? self : nil }
    override func acceptsFirstMouse(for e: NSEvent?) -> Bool { true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }

    var menu_: NSMenu?
    override func rightMouseDown(with e: NSEvent) {   // 메뉴바 아이콘이 안 보일 때를 위한 우클릭 메뉴
        if let m = menu_ { NSMenu.popUpContextMenu(m, with: e, for: self) }
    }

    override func mouseDown(with e: NSEvent) {
        downMouse = NSEvent.mouseLocation
        downOrigin = window!.frame.origin
        moved = false
    }
    override func mouseDragged(with e: NSEvent) {
        let m = NSEvent.mouseLocation
        let dx = m.x - downMouse.x, dy = m.y - downMouse.y
        if !moved && hypot(dx, dy) <= 4 { return }   // 4pt 이하는 클릭
        moved = true
        window!.setFrameOrigin(.init(x: downOrigin.x + dx, y: downOrigin.y + dy))
        onMove()
    }
    override func mouseUp(with e: NSEvent) {
        if moved { Store.origin = window!.frame.origin } else { play(); onClick() }
    }

    /// 클릭 시 GIF를 한 바퀴만 재생하고 첫 프레임으로 복귀 (PNG면 아무 일 없음)
    private func play() {
        guard let rep = iv.image?.representations.first as? NSBitmapImageRep,
              let n = (rep.value(forProperty: .frameCount) as? Int), n > 1 else { return }
        var total = 0.0
        for i in 0..<n {
            rep.setProperty(.currentFrame, withValue: i)
            total += (rep.value(forProperty: .currentFrameDuration) as? Double) ?? 0.1
        }
        rep.setProperty(.currentFrame, withValue: 0)
        playGen += 1
        let gen = playGen
        iv.animates = true
        DispatchQueue.main.asyncAfter(deadline: .now() + total) { [weak self] in
            guard let self, gen == playGen else { return }   // 연타 시 마지막 클릭 기준
            iv.animates = false
            rep.setProperty(.currentFrame, withValue: 0)
            iv.image = iv.image                                // 다시 그리기
        }
    }
}

final class CharacterPanel: NSPanel {
    let view: CharacterView

    init() {
        let s = Store.size
        view = CharacterView(frame: .init(x: 0, y: 0, width: s, height: s))
        super.init(contentRect: .init(origin: Store.validOrigin(size: s), size: .init(width: s, height: s)),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        contentView = view
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
    }

    func resize(_ s: CGFloat) {
        Store.size = s
        var f = frame; f.size = .init(width: s, height: s)
        setFrame(f, display: true)
        view.window?.invalidateCursorRects(for: view)
    }

    func resetPosition() {
        Store.origin = nil
        setFrameOrigin(Store.validOrigin(size: frame.width))
        view.onMove()
    }
}
