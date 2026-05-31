import SafariServices

let appGroupID = "group.com.brine.ebfinder"

enum SharedDefaultsKey {
    static let permissionPingTimestamp = "permission.lastPingTimestamp"
    static let permissionHasAllUrls = "permission.hasAllUrls"
    static let permissionLastOrigin = "permission.lastOrigin"
}

final class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        let request = context.inputItems.first as? NSExtensionItem
        let message = request?.userInfo?[SFExtensionMessageKey]

        handle(message: message)

        let response = NSExtensionItem()
        response.userInfo = [SFExtensionMessageKey: ["ok": true]]
        context.completeRequest(returningItems: [response], completionHandler: nil)
    }

    private func handle(message: Any?) {
        guard
            let dict = message as? [String: Any],
            let type = dict["type"] as? String,
            type == "host-permission-ping",
            let defaults = UserDefaults(suiteName: appGroupID)
        else { return }

        let hasAllUrls = dict["hasAllUrls"] as? Bool ?? false
        let origin = dict["origin"] as? String ?? ""
        defaults.set(Date().timeIntervalSince1970, forKey: SharedDefaultsKey.permissionPingTimestamp)
        defaults.set(hasAllUrls, forKey: SharedDefaultsKey.permissionHasAllUrls)
        defaults.set(origin, forKey: SharedDefaultsKey.permissionLastOrigin)
    }
}
