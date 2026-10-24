import Foundation
import SwiftUI
import Testing

@testable import TwitterUI

struct TwitterUIDesignTests {
    @Test(arguments: [
        (0, "0"),
        (999, "999"),
        (1_234, "1,234"),
        (9_999, "9,999"),
        (10_000, "10K"),
        (12_345, "12.3K"),
        (12_399, "12.3K"),
        (123_456, "123.4K"),
        (999_999, "999.9K"),
        (1_000_000, "1M"),
        (1_299_999, "1.2M"),
        (2_500_000_000, "2.5B")
    ])
    func compactTruncatesAboveTenThousand(value: Int, expected: String) {
        #expect(value.compact(locale: Locale(identifier: "en_US")) == expected)
    }

    @Test
    func metricsGrowWithWidthAndDynamicType() {
        let widths: [CGFloat] = [320, 393, 480, 700]
        let sizes: [DynamicTypeSize] = [.small, .large, .xxLarge, .accessibility1]

        let byWidth = widths.map { TweetMetrics(width: $0, dynamicTypeSize: .large) }
        let byType = sizes.map { TweetMetrics(width: 393, dynamicTypeSize: $0) }
        for metrics in [byWidth, byType] {
            for (smaller, larger) in zip(metrics, metrics.dropFirst()) {
                #expect(smaller.bodySize < larger.bodySize)
                #expect(smaller.avatarSize < larger.avatarSize)
            }
        }
        for metrics in byWidth + byType {
            #expect(metrics.gutter > 0)
        }
    }

    @Test
    func chirpRegistersFromTheBundle() {
        TwitterFont.register()
        #expect(TwitterFont.isAvailable)
    }
}
