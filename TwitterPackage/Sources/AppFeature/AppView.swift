import ComposableArchitecture
import MainFeature
import Models
import SignInFeature
import SwiftUI
import TwitterClient
import TwitterClientLive

public struct AppView: View {
    @State private var store = Store(initialState: AppFeature.State()) {
        AppFeature()
    } withDependencies: {
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--mock-twitter") {
                $0[TwitterClient.self] = .previewValue
            }
        #endif
    }

    public init() {}

    public var body: some View {
        AppRootView(store: store)
            .asyncImageURLSession(.images)
    }
}

private struct AppRootView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        Group {
            switch store.state {
            case .launchFailed(let message):
                ContentUnavailableView {
                    Label("Couldn't reach Twitter", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try Again") { store.send(.retryButtonTapped) }
                        .buttonStyle(.glassProminent)
                }
            case .launching:
                ProgressView()
            case .main:
                if let store = store.scope(state: \.main, action: \.main) {
                    MainView(store: store)
                }
            case .signIn:
                if let store = store.scope(state: \.signIn, action: \.signIn) {
                    SignInView(store: store)
                }
            }
        }
        .task { store.send(.task) }
    }
}

extension URLSession {
    static let images: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(memoryCapacity: 64 << 20, diskCapacity: 512 << 20)
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: configuration)
    }()
}

#Preview {
    AppView()
}
