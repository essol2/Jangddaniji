import SwiftUI

extension Font {
    /// 학교안심 받아쓰기 Bold — 타이틀, 강조 텍스트
    static func appBold(size: CGFloat) -> Font {
        .custom("HakgyoansimBadasseugiTTF-B", size: size)
    }

    /// 학교안심 받아쓰기 Light — 본문, 설명 텍스트
    static func appRegular(size: CGFloat) -> Font {
        .custom("HakgyoansimBadasseugiTTF-L", size: size)
    }
}
