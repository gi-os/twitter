import SafariServices
import SwiftUI

/// Safari's own view of a page, for a single stack where there's no room for a web panel beside the content.
package struct SafariView: UIViewControllerRepresentable {
    let url: URL

    package init(url: URL) {
        self.url = url
    }

    package func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.dismissButtonStyle = .close
        controller.delegate = context.coordinator
        return controller
    }

    package func updateUIViewController(_ controller: SFSafariViewController, context: Context) {
        context.coordinator.dismiss = context.environment.dismiss
    }

    package func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    package final class Coordinator: NSObject, @preconcurrency SFSafariViewControllerDelegate {
        var dismiss: DismissAction?

        package func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            dismiss?()
        }
    }
}
