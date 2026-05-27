import SafariServices
import os

private let logger = Logger(subsystem: "com.brine.ebfinder", category: "Extension")

final class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        let request = context.inputItems.first as? NSExtensionItem
        let profile = request?.userInfo?[SFExtensionProfileKey] as? UUID
        let message = request?.userInfo?[SFExtensionMessageKey]

        logger.info("Received native message: \(String(describing: message), privacy: .public) profile=\(profile?.uuidString ?? "none", privacy: .public)")

        let response = NSExtensionItem()
        response.userInfo = [SFExtensionMessageKey: ["echo": message as Any]]

        context.completeRequest(returningItems: [response], completionHandler: nil)
    }
}
