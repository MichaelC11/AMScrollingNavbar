import UIKit

/**
 Scrolling Navigation Bar delegate protocol
 */
@objc public protocol CustomScrollingNavigationControllerDelegate: NSObjectProtocol {
    /**
     Called when the state of the navigation bar changes
     */
    @objc optional func scrollingNavigationController(_ controller: CustomScrollingNavigationController, didChangeState state: NavigationBarState)
    
    /**
     Called when the state of the navigation bar is about to change
     */
    @objc optional func scrollingNavigationController(_ controller: CustomScrollingNavigationController, willChangeState state: NavigationBarState)
}

/**
 A customized version of ScrollingNavigationController that allows for scrolling based on multiple views
 */
open class CustomScrollingNavigationController: UINavigationController, UIGestureRecognizerDelegate {
    
    /**
     Returns the `NavigationBarState` of the navigation bar
     */
    open fileprivate(set) var state: NavigationBarState = .expanded {
        willSet {
            if state != newValue {
                scrollingNavbarDelegate?.scrollingNavigationController?(self, willChangeState: newValue)
            }
        }
        didSet {
            navigationBar.isUserInteractionEnabled = (state == .expanded)
            if state != oldValue {
                scrollingNavbarDelegate?.scrollingNavigationController?(self, didChangeState: state)
            }
        }
    }
    
    /**
     Determines whether the navbar should scroll when the content inside the scrollview fits
     the view's size. Defaults to `false`
     */
    open var shouldScrollWhenContentFits = false
    
    /**
     Determines if the navbar should expand once the application becomes active after entering background
     Defaults to `true`
     */
    open var expandOnActive = true
    
    /**
     Determines if the navbar scrolling is enabled.
     Defaults to `true`
     */
    open var scrollingEnabled = true {
        didSet {
            for scrollHandler in self.scrollHandlers {
                scrollHandler.gestureRecognizer?.isEnabled = self.scrollingEnabled
            }
        }
    }
    
    /**
     Determines if we halt content scroll while navbar is scrolling
     Defaults to `true`
     */
    open var haltContentScrollOnNavBarScroll = false
    
    /**
     The delegate for the scrolling navbar controller
     */
    open weak var scrollingNavbarDelegate: CustomScrollingNavigationControllerDelegate?
    
    /**
     An array of `UIView`s that will follow the navbar
     */
    open var followers: [UIView] = []
    
    var previousState: NavigationBarState = .expanded // Used to mark the state before the app goes in background
    
    /**
     Registers an array of `UIView`s that will follow the navbar
     */
    open func registerFollowers(followers: [UIView]) {
        self.followers = followers
    }
    
    /**
     Deregisters the followers (so no `UIView`s will follow the navbar)
     */
    open func deregisterFollowers() {
        self.followers = []
    }
    
    /**
     One time call to set up the handling for App active and App rotate
     */
    open func setup() {
        NotificationCenter.default.removeObserver(self)
        
        NotificationCenter.default.addObserver(self, selector: #selector(ScrollingNavigationController.willResignActive(_:)), name: NSNotification.Name.UIApplicationWillResignActive, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ScrollingNavigationController.didBecomeActive(_:)), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ScrollingNavigationController.didRotate(_:)), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
    }
    
    private var scrollHandlers: [CustomScrollingHandler] = []
    
    private func getScrollHandlerForScrollView(scrollView: UIView?) -> CustomScrollingHandler? {
        for scrollHandler in self.scrollHandlers {
            if scrollHandler.scrollableView == scrollView {
                return scrollHandler
            }
        }
        
        return nil
    }
    
    /**
     Start scrolling
     
     Enables the scrolling by observing a view
     
     - parameter scrollableView: The view with the scrolling content that will be observed
     - parameter delay: The delay expressed in points that determines the scrolling resistance. Defaults to `0`
     - parameter scrollSpeedFactor : This factor determines the speed of the scrolling content toward the navigation bar animation
     */
    open func followScrollView(_ scrollableView: UIView, delay: Double = 0, scrollSpeedFactor: Double = 1) {
        guard self.getScrollHandlerForScrollView(scrollView: scrollableView) == nil else {
            return // Already registered
        }
        
        let scrollHandler = CustomScrollingHandler(scrollNavigationController: self, scrollableView: scrollableView, delay: delay, scrollSpeedFactor: scrollSpeedFactor)
        scrollHandler.gestureRecognizer?.isEnabled = self.scrollingEnabled
        self.scrollHandlers.append(scrollHandler)
    }
    
    /**
     Stops following a particular view
     */
    open func stopFollowingScrollView(scrollView: UIView?) {
        if let activeHandler = self.getScrollHandlerForScrollView(scrollView: scrollView) {
            activeHandler.stopFollowingScrollView()
          
            if let index = self.scrollHandlers.index(of: activeHandler) {
              self.scrollHandlers.remove(at: index)
            }
        }
    }
    
    /**
     Stops following all views
     */
    open func stopFollowingAllScrollViews(showingNavbar: Bool = true, deregisterFollowers: Bool = true) {
        if showingNavbar {
            showNavbar(animated: false)
        }
        
        for scrollHandler in self.scrollHandlers {
            scrollHandler.stopFollowingScrollView()
        }
        self.scrollHandlers = []
        
        if deregisterFollowers {
            self.deregisterFollowers()
        }
    }
    
    /**
     Hide the navigation bar
     
     - parameter animated: If true the scrolling is animated. Defaults to `true`
     - parameter activeScrollView: Optional UIView that will also be adjusted if NavBar hides. Defaults to nil
     - parameter duration: Optional animation duration. Defaults to 0.1
     */
    open func hideNavbar(animated: Bool = true, activeScrollView: UIView? = nil, duration: TimeInterval = 0.1) {
        guard let visibleViewController = self.visibleViewController else { return }
        
        if state == .expanded {
            self.state = .scrolling
            
            let mainWork = {
                if let activeScrollHandler = self.getScrollHandlerForScrollView(scrollView: activeScrollView) {
                    activeScrollHandler.scrollWithDelta(self.fullNavbarHeight)
                } else {
                    self.scrollWithDeltaButWithoutScrollView(self.fullNavbarHeight)
                }
                
                visibleViewController.view.setNeedsLayout()
                
                if self.navigationBar.isTranslucent, let activeScrollHandler = self.getScrollHandlerForScrollView(scrollView: activeScrollView) {
                    let currentOffset = activeScrollHandler.contentOffset
                    activeScrollHandler.scrollView()?.contentOffset = CGPoint(x: currentOffset.x, y: currentOffset.y + self.navbarHeight)
                }
            }
            
            let completionWork = {
                self.state = .collapsed
            }
            
            if animated {
                UIView.animate(withDuration: animated ? duration : 0, animations: { () -> Void in
                    mainWork()
                }) { _ in
                    completionWork()
                }
            } else {
                mainWork()
                completionWork()
            }
            
        } else {
            updateNavbarAlpha()
        }
    }
    
    /**
     Show the navigation bar
     
     - parameter animated: If true the scrolling is animated. Defaults to `true`
     - parameter activeScrollView: Optional UIView that will also be adjusted if NavBar hides. Defaults to nil
     - parameter duration: Optional animation duration. Defaults to 0.1
     */
    open func showNavbar(animated: Bool = true, activeScrollView: UIView? = nil, duration: TimeInterval = 0.1) {
        guard let visibleViewController = self.visibleViewController else { return }
        
        if state == .collapsed {
            self.state = .scrolling
            
            let mainWork = {
                // Note: Assuming we don't call this function in the middle of a PanGesture, we probably don't need?
                //                for scrollHandler in self.scrollHandlers {
                //                    scrollHandler.lastContentOffset = 0
                //                    scrollHandler.delayDistance = -self.fullNavbarHeight
                //                }
                
                if let activeScrollHandler = self.getScrollHandlerForScrollView(scrollView: activeScrollView) {
                    activeScrollHandler.scrollWithDelta(-self.fullNavbarHeight)
                } else {
                    self.scrollWithDeltaButWithoutScrollView(-self.fullNavbarHeight)
                }
                
                visibleViewController.view.setNeedsLayout()
                
                if self.navigationBar.isTranslucent, let activeScrollHandler = self.getScrollHandlerForScrollView(scrollView: activeScrollView) {
                    let currentOffset = activeScrollHandler.contentOffset
                    activeScrollHandler.scrollView()?.contentOffset = CGPoint(x: currentOffset.x, y: currentOffset.y - self.navbarHeight)
                }
            }
            
            let completionWork = {
                self.state = .expanded
            }
            
            if animated {
                UIView.animate(withDuration: animated ? duration : 0.0, animations: {
                    mainWork()
                }) { _ in
                    completionWork()
                }
            } else {
                mainWork()
                completionWork()
            }
            
        } else {
            updateNavbarAlpha()
        }
    }
    
    // MARK: - Rotation handler
    
    func didRotate(_ notification: Notification) {
        showNavbar()
    }
    
    /**
     UIContentContainer protocol method.
     Will show the navigation bar upon rotation or changes in the trait sizes.
     */
    open override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        showNavbar()
    }
    
    // MARK: - Notification handler
    
    func didBecomeActive(_ notification: Notification) {
        if expandOnActive {
            showNavbar(animated: false)
        } else {
            if previousState == .collapsed {
                hideNavbar(animated: false)
            }
        }
    }
    
    func willResignActive(_ notification: Notification) {
        previousState = state
    }
    
    /// Handles when the status bar changes
    func willChangeStatusBar() {
        showNavbar(animated: true)
    }
    
    fileprivate func updateFollowers(_ delta: CGFloat) {
        followers.forEach { $0.transform = $0.transform.translatedBy(x: 0, y: -delta) }
    }
    
    fileprivate func updateSizing(_ delta: CGFloat) {
        guard let topViewController = self.topViewController else { return }
        
        var frame = navigationBar.frame
        
        // Move the navigation bar
        frame.origin = CGPoint(x: frame.origin.x, y: frame.origin.y - delta)
        navigationBar.frame = frame
        
        // Resize the view if the navigation bar is not translucent
        if !navigationBar.isTranslucent {
            let navBarY = navigationBar.frame.origin.y + navigationBar.frame.size.height
            frame = topViewController.view.frame
            frame.origin = CGPoint(x: frame.origin.x, y: navBarY)
            frame.size = CGSize(width: frame.size.width, height: view.frame.size.height - (navBarY) - tabBarOffset)
            topViewController.view.frame = frame
        }
    }
    
    fileprivate func updateNavbarAlpha() {
        guard let navigationItem = visibleViewController?.navigationItem else { return }
        
        let frame = navigationBar.frame
        
        // Change the alpha channel of every item on the navbr
        let alpha = (frame.origin.y + deltaLimit) / frame.size.height
        
        // Hide all the possible titles
        navigationItem.titleView?.alpha = alpha
        navigationBar.tintColor = navigationBar.tintColor.withAlphaComponent(alpha)
        if let titleColor = navigationBar.titleTextAttributes?[NSForegroundColorAttributeName] as? UIColor {
            navigationBar.titleTextAttributes?[NSForegroundColorAttributeName] = titleColor.withAlphaComponent(alpha)
        } else {
            navigationBar.titleTextAttributes?[NSForegroundColorAttributeName] = UIColor.black.withAlphaComponent(alpha)
        }
        
        // Hide all possible button items and navigation items
        func shouldHideView(_ view: UIView) -> Bool {
            let className = view.classForCoder.description()
            return className == "UINavigationButton" ||
                className == "UINavigationItemView" ||
                className == "UIImageView" ||
                className == "UISegmentedControl"
        }
        navigationBar.subviews
            .filter(shouldHideView)
            .forEach { $0.alpha = alpha }
        
        // Hide the left items
        navigationItem.leftBarButtonItem?.customView?.alpha = alpha
        if let leftItems = navigationItem.leftBarButtonItems {
            leftItems.forEach { $0.customView?.alpha = alpha }
        }
        
        // Hide the right items
        navigationItem.rightBarButtonItem?.customView?.alpha = alpha
        if let leftItems = navigationItem.rightBarButtonItems {
            leftItems.forEach { $0.customView?.alpha = alpha }
        }
    }
    
    fileprivate func scrollWithDeltaButWithoutScrollView(_ delta: CGFloat) {
        var scrollDelta = delta
        let frame = navigationBar.frame
        
        // View scrolling up, hide the navbar
        if scrollDelta > 0 {
            // Compute the bar position
            if frame.origin.y - scrollDelta < -self.deltaLimit {
                scrollDelta = frame.origin.y + self.deltaLimit
            }
            
            // Detect when the bar is completely collapsed
            if frame.origin.y <= -self.deltaLimit {
                self.state = .collapsed
            } else {
                self.state = .scrolling
            }
        }
        
        if scrollDelta < 0 {
            // Compute the bar position
            if frame.origin.y - scrollDelta > self.statusBarHeight {
                scrollDelta = frame.origin.y - self.statusBarHeight
            }
            
            // Detect when the bar is completely expanded
            if frame.origin.y >= self.statusBarHeight {
                self.state = .expanded
            } else {
                self.state = .scrolling
            }
        }
        
        self.updateSizing(scrollDelta)
        self.updateNavbarAlpha()
        self.updateFollowers(scrollDelta)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

open class CustomScrollingHandler: NSObject, UIGestureRecognizerDelegate {
    open fileprivate(set) var gestureRecognizer: UIPanGestureRecognizer?
    
    var delayDistance: CGFloat = 0
    var maxDelay: CGFloat = 0
    var scrollableView: UIView?
    var lastContentOffset = CGFloat(0.0)
    var scrollSpeedFactor: CGFloat = 1
    
    unowned var scrollNavigationController: CustomScrollingNavigationController
    
    public init(scrollNavigationController: CustomScrollingNavigationController, scrollableView: UIView, delay: Double = 0, scrollSpeedFactor: Double = 1) {
        self.scrollNavigationController = scrollNavigationController
        
        self.scrollableView = scrollableView
        
        super.init()
        
        self.gestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        self.gestureRecognizer?.maximumNumberOfTouches = 1
        self.gestureRecognizer?.delegate = self
        scrollableView.addGestureRecognizer(self.gestureRecognizer!)
        
        self.maxDelay = CGFloat(delay)
        self.delayDistance = CGFloat(delay)
        self.scrollSpeedFactor = CGFloat(scrollSpeedFactor)
    }
    
    open func stopFollowingScrollView() {
        if let gesture = gestureRecognizer {
            scrollableView?.removeGestureRecognizer(gesture)
        }
        
        scrollableView = .none
        gestureRecognizer = .none
    }
    
    // MARK: - Gesture recognizer
    func handlePan(_ gesture: UIPanGestureRecognizer) {
        if gesture.state != .failed {
            if let superview = scrollableView?.superview {
                let translation = gesture.translation(in: superview)
                let delta = (lastContentOffset - translation.y) / scrollSpeedFactor
                lastContentOffset = translation.y
                
                if shouldScrollWithDelta(delta) {
                    scrollWithDelta(delta)
                }
            }
        }
        
        if gesture.state == .ended || gesture.state == .cancelled || gesture.state == .failed {
            checkForPartialScroll()
            lastContentOffset = 0
        }
    }
    
    // MARK: - UIGestureRecognizerDelegate
    /**
     UIGestureRecognizerDelegate function. Enables the scrolling of both the content and the navigation bar
     */
    open func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    /**
     UIGestureRecognizerDelegate function. Only scrolls the navigation bar with the content when `scrollingEnabled` is true
     */
    open func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return scrollNavigationController.scrollingEnabled
    }
    
    // MARK: - Scrolling functions
    
    fileprivate func shouldScrollWithDelta(_ delta: CGFloat) -> Bool {
        // Check for rubberbanding
        if delta < 0 {
            if let scrollableView = scrollableView , contentOffset.y + scrollableView.frame.size.height > contentSize.height && scrollableView.frame.size.height < contentSize.height {
                // Only if the content is big enough
                return false
            }
        }
        return true
    }
    
    fileprivate func scrollWithDelta(_ delta: CGFloat, ignoreDelay: Bool = false) {
        var scrollDelta = delta
        let frame = self.scrollNavigationController.navigationBar.frame
        
        // View scrolling up, hide the navbar
        if scrollDelta > 0 {
            // Update the delay
            if !ignoreDelay {
                delayDistance -= scrollDelta
                
                // Skip if the delay is not over yet
                if delayDistance > 0 {
                    return
                }
            }
            
            // No need to scroll if the content fits
            if !self.scrollNavigationController.shouldScrollWhenContentFits && self.scrollNavigationController.state != .collapsed &&
                (scrollableView?.frame.size.height)! >= contentSize.height {
                return
            }
            
            // Compute the bar position
            if frame.origin.y - scrollDelta < -self.scrollNavigationController.deltaLimit {
                scrollDelta = frame.origin.y + self.scrollNavigationController.deltaLimit
            }
            
            // Detect when the bar is completely collapsed
            if frame.origin.y <= -self.scrollNavigationController.deltaLimit {
                self.scrollNavigationController.state = .collapsed
                delayDistance = maxDelay
            } else {
                self.scrollNavigationController.state = .scrolling
            }
        }
        
        if scrollDelta < 0 {
            // Update the delay
            if !ignoreDelay {
                delayDistance += scrollDelta
                
                // Skip if the delay is not over yet
                if delayDistance > 0 && maxDelay < contentOffset.y {
                    return
                }
            }
            
            // Compute the bar position
            if frame.origin.y - scrollDelta > self.scrollNavigationController.statusBarHeight {
                scrollDelta = frame.origin.y - self.scrollNavigationController.statusBarHeight
            }
            
            // Detect when the bar is completely expanded
            if frame.origin.y >= self.scrollNavigationController.statusBarHeight {
                self.scrollNavigationController.state = .expanded
                delayDistance = maxDelay
            } else {
                self.scrollNavigationController.state = .scrolling
            }
        }
        
        self.scrollNavigationController.updateSizing(scrollDelta)
        self.scrollNavigationController.updateNavbarAlpha()
        restoreContentOffset(scrollDelta)
        self.scrollNavigationController.updateFollowers(scrollDelta)
    }
    
    fileprivate func restoreContentOffset(_ delta: CGFloat) {
        if (self.scrollNavigationController.navigationBar.isTranslucent && !self.scrollNavigationController.haltContentScrollOnNavBarScroll) || delta == 0 {
            return
        }
        
        // Hold the scroll steady until the navbar appears/disappears
        if let scrollView = scrollView() {
            scrollView.setContentOffset(CGPoint(x: contentOffset.x, y: contentOffset.y - delta), animated: false)
        }
    }
    
    fileprivate func checkForPartialScroll() {
        let frame = self.scrollNavigationController.navigationBar.frame
        var duration = TimeInterval(0)
        var delta = CGFloat(0.0)
        let distance = delta / (frame.size.height / 2)
        
        // Scroll back down
        let threshold = self.scrollNavigationController.statusBarHeight - (frame.size.height / 2)
        if frame.origin.y >= threshold {
            delta = frame.origin.y - self.scrollNavigationController.statusBarHeight
            duration = TimeInterval(abs(distance * 0.2))
            self.scrollNavigationController.state = .expanded
        } else {
            // Scroll up
            delta = frame.origin.y + self.scrollNavigationController.deltaLimit
            duration = TimeInterval(abs(distance * 0.2))
            self.scrollNavigationController.state = .collapsed
        }
        
        delayDistance = maxDelay
        
        UIView.animate(withDuration: duration, delay: 0, options: UIViewAnimationOptions.beginFromCurrentState, animations: {
            self.scrollNavigationController.updateSizing(delta)
            self.scrollNavigationController.updateFollowers(delta)
            self.scrollNavigationController.updateNavbarAlpha()
        }, completion: nil)
    }
}
