import Foundation
import Testing

@testable import Models

struct UserListParserTests {
    @Test
    func followersPageReadsUsersAndTheBottomCursor() throws {
        let page = TimelineParser.userPage(
            from: try followers([
                user("user-1", id: "1", screenName: "lorenb"),
                user("promoted-user-2", id: "2", screenName: "advertiser"),
                user("user-3", id: "3", screenName: "chockenberry"),
                user("user-1-again", id: "1", screenName: "lorenb"),
                cursor("Top", value: "-1|123"),
                cursor("Bottom", value: "1849|456")
            ])
        )

        #expect(page.users.map(\.screenName) == ["lorenb", "chockenberry"])
        #expect(page.bottomCursor == "1849|456")
    }

    @Test
    func lastPageCursorEndsTheList() throws {
        let page = TimelineParser.userPage(
            from: try followers([user("user-1", id: "1", screenName: "lorenb"), cursor("Bottom", value: "0|789")])
        )

        #expect(page.users.count == 1)
        #expect(page.bottomCursor == nil)
    }

    private func user(_ entryID: String, id: String, screenName: String) -> [String: Any] {
        [
            "entryId": entryID,
            "content": [
                "entryType": "TimelineTimelineItem",
                "itemContent": [
                    "itemType": "TimelineUser",
                    "user_results": [
                        "result": [
                            "__typename": "User", "rest_id": id,
                            "core": ["screen_name": screenName, "name": screenName]
                        ]
                    ]
                ]
            ]
        ]
    }

    private func cursor(_ type: String, value: String) -> [String: Any] {
        [
            "entryId": "cursor-\(type.lowercased())-\(value)",
            "content": ["entryType": "TimelineTimelineCursor", "cursorType": type, "value": value]
        ]
    }

    /// The `Followers` response shape: the timeline under the profile's user result.
    private func followers(_ entries: [[String: Any]]) throws -> Any {
        let root: [String: Any] = [
            "data": [
                "user": [
                    "result": [
                        "__typename": "User",
                        "timeline": [
                            "timeline": [
                                "instructions": [
                                    ["type": "TimelineClearCache"],
                                    ["type": "TimelineAddEntries", "entries": entries]
                                ]
                            ]
                        ]
                    ]
                ]
            ]
        ]
        return try JSONSerialization.jsonObject(with: JSONSerialization.data(withJSONObject: root))
    }
}
