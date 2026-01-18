

import SwiftUI

struct JSActionShowRenewalDialog: JSActionProtocol {
    func perform(parameters: [String: Any]) async throws -> [String: Any]? {
        return await withCheckedContinuation { _ in

            // continuation.resume(returning: "aaa")
        }
    }
}
