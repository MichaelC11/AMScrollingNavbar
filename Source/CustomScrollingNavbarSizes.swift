import UIKit
import WebKit

/**
 Implements the main functions providing constants values and computed ones
 */
extension CustomScrollingNavigationController {
    open var fullNavbarHeight: CGFloat {
        return navbarHeight + statusBarHeight
    }
    
    open var navbarHeight: CGFloat {
        return navigationBar.frame.size.height
    }
    
    open var statusBarHeight: CGFloat {
        return CGFloat.minimum(20, UIApplication.shared.statusBarFrame.size.height)
    }
    
    open var tabBarOffset: CGFloat {
        // Only account for the tab bar if a tab bar controller is present and the bar is not translucent
        if let tabBarController = tabBarController {
            return tabBarController.tabBar.isTranslucent ? 0 : tabBarController.tabBar.frame.height
        }
        return 0
    }
    
    open var deltaLimit: CGFloat {
        return navbarHeight - statusBarHeight
    }
}

extension CustomScrollingHandler {
    func scrollView() -> UIScrollView? {
        if let webView = self.scrollableView as? UIWebView {
            return webView.scrollView
        } else if let wkWebView = self.scrollableView as? WKWebView {
            return wkWebView.scrollView
        } else {
            return scrollableView as? UIScrollView
        }
    }
    
    var contentOffset: CGPoint {
        return scrollView()?.contentOffset ?? CGPoint.zero
    }
    
    var contentSize: CGSize {
        return scrollView()?.contentSize ?? CGSize.zero
    }
}
