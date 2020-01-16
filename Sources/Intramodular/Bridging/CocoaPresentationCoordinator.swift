//
// Copyright (c) Vatsal Manot
//

import Swift
import SwiftUI

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

public class CocoaPresentationCoordinator: NSObject {
    private let presentation: CocoaPresentation?
    
    public private(set) weak var presentingCoordinator: CocoaPresentationCoordinator?
    public private(set) var presentedCoordinator: CocoaPresentationCoordinator?
    
    var topMostCoordinator: CocoaPresentationCoordinator {
        var coordinator = self
        
        while let nextCoordinator = coordinator.presentedCoordinator {
            coordinator = nextCoordinator
        }
        
        return coordinator
    }
    
    var topMostPresentedCoordinator: CocoaPresentationCoordinator? {
        presentedCoordinator?.topMostCoordinator
    }
    
    var onDidAttemptToDismiss: [CocoaPresentation.DidAttemptToDismissCallback] = []
    var transitioningDelegate: UIViewControllerTransitioningDelegate?
    
    weak var viewController: UIViewController?
    
    override init() {
        self.presentation = nil
        self.presentingCoordinator = nil
        
        super.init()
     
        self.presentingCoordinator = self
    }
    
    init(
        presentation: CocoaPresentation? = nil,
        presentingCoordinator: CocoaPresentationCoordinator? = nil
    ) {
        self.presentation = presentation
        self.presentingCoordinator = presentingCoordinator
    }
    
    func present(
        _ presentation: CocoaPresentation,
        animated: Bool = true,
        completion: @escaping () -> () = { }
    ) {
        if let viewController = viewController?.presentedViewController as? CocoaHostingController<AnyPresentationView>, viewController.modalViewPresentationStyle == presentation.style {
            viewController.rootView.content = presentation.content()
            return
        }
        
        let presentationCoordinator = CocoaPresentationCoordinator(
            presentation: presentation,
            presentingCoordinator: self
        )
        
        let viewControllerToBePresented = CocoaHostingController(
            presentation: presentation,
            presentationCoordinator: presentationCoordinator
        )
        
        presentedCoordinator = presentationCoordinator
        
        viewControllerToBePresented.presentationController?.delegate = presentationCoordinator
        
        self.viewController?.present(
            viewControllerToBePresented,
            animated: animated,
            completion: completion
        )
    }
    
    func dismissPresented() {
        guard
            let viewController = viewController,
            let presentedCoordinator = presentedCoordinator,
            let presentation = presentedCoordinator.presentation,
            viewController.presentedViewController != nil,
            presentation.shouldDismiss() else {
                return
        }
        
        viewController.dismiss(animated: true) {
            presentation.onDismiss?()
            self.presentedCoordinator = nil
        }
    }
    
    func dismissSelf() {
        presentingCoordinator?.dismissPresented()
    }
}

// MARK: - Protocol Implementations -

extension CocoaPresentationCoordinator: DynamicViewPresenter {
    public var isPresented: Bool {
        return presentedCoordinator != nil
    }
    
    public func present<V: View>(
        _ view: V,
        onDismiss: (() -> Void)?,
        style: ModalViewPresentationStyle
    ) {
        topMostCoordinator.present(CocoaPresentation(
            content: { view },
            shouldDismiss: { true },
            onDismiss: onDismiss,
            resetBinding: { },
            style: style,
            environment: nil
        ))
    }
    
    public func dismiss() {
        topMostPresentedCoordinator?.dismissSelf()
    }
    
    public func dismiss(viewNamed name: ViewName) {
        var coordinator = self
        
        while let presentedCoordinator = coordinator.presentedCoordinator {
            if (presentedCoordinator.viewController as? CocoaHostingController<AnyPresentationView>)?.rootViewContentName == name {
                presentedCoordinator.dismissSelf()
                break
            } else {
                coordinator = presentedCoordinator
            }
        }
    }
}

extension CocoaPresentationCoordinator: UIAdaptivePresentationControllerDelegate {
    public func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        if let presentation = presentation {
            return .init(presentation.style)
        } else {
            return .automatic
        }
    }
    
    public func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        presentation?.shouldDismiss() ?? true
    }
    
    public func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        for callback in onDidAttemptToDismiss {
            callback.action()
        }
    }
    
    public func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
        
    }
    
    public func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        presentation?.onDismiss?()
        
        presentingCoordinator?.presentedCoordinator = nil
    }
}

#endif
