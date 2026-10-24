//
//  TwitterApp.swift
//  Twitter
//
//  Created by Sam on 10/23/26.
//

import AppFeature
import SwiftUI

@main
struct TwitterApp: App {
    init() {
        bootstrapTwitter()
    }

    var body: some Scene {
        TwitterScenes()
    }
}
