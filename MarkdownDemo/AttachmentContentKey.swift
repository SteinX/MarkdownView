import UIKit

public protocol AttachmentContentKey: Hashable {}

public struct AttachmentInfo {
    public let view: UIView
    public let contentKey: AnyHashable
    public let charPosition: Int

    public init(view: UIView, contentKey: AnyHashable, charPosition: Int = 0) {
        self.view = view
        self.contentKey = contentKey
        self.charPosition = charPosition
    }
}

extension AttachmentContentKey {
    public var anyKey: AnyHashable {
        AnyHashable(self)
    }
}
