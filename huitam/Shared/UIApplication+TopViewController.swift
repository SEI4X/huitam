import UIKit

extension UIApplication {
    var huitamTopViewController: UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController?
            .huitamTopPresentedViewController
    }
}

private extension UIViewController {
    var huitamTopPresentedViewController: UIViewController {
        if let navigationController = self as? UINavigationController,
           let visibleViewController = navigationController.visibleViewController {
            return visibleViewController.huitamTopPresentedViewController
        }

        if let tabBarController = self as? UITabBarController,
           let selectedViewController = tabBarController.selectedViewController {
            return selectedViewController.huitamTopPresentedViewController
        }

        if let presentedViewController {
            return presentedViewController.huitamTopPresentedViewController
        }

        return self
    }
}
