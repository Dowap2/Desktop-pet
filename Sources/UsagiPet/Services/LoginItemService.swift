import Foundation
import ServiceManagement

enum LoginItemService {
    static var isOn: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ on: Bool) {
        try? on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
    }

    /// 첫 실행 때만 기본값 켜짐
    static func enableOnFirstLaunch() {
        guard !UserDefaults.standard.bool(forKey: "launched") else { return }
        UserDefaults.standard.set(true, forKey: "launched")
        set(true)
    }
}
