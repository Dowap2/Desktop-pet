import AppKit

enum Store {
    static let d = UserDefaults.standard

    static var size: CGFloat {
        get { d.object(forKey: "size") as? CGFloat ?? 160 }
        set { d.set(newValue, forKey: "size") }
    }

    static var origin: NSPoint? {
        get { (d.string(forKey: "origin")).map(NSPointFromString) }
        set { d.set(newValue.map(NSStringFromPoint), forKey: "origin") }
    }

    /// 저장 위치가 어느 화면에도 안 보이면 주 모니터 오른쪽 아래로 보정
    static func validOrigin(size: CGFloat) -> NSPoint {
        if let o = origin,
           NSScreen.screens.contains(where: { $0.visibleFrame.intersects(NSRect(origin: o, size: .init(width: size, height: size))) }) {
            return o
        }
        let v = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        return NSPoint(x: v.maxX - size - 24, y: v.minY + 24)
    }
}
