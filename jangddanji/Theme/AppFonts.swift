import SwiftUI

extension Font {
    /// 제주돌담체 커스텀 폰트
    static func jejuDoldam(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("EF_jejudoldam", size: size).weight(weight)
    }
}
