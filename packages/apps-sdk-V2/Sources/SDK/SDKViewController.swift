//
//  SDKViewWrapperViewController.swift
//  ImageGenerator
//
//  Created by Dubon Ya'ar on 22/01/2025.
//
//

import SwiftUI
import UIKit

public class SDKViewController: UIViewController {
    let sdk: TheSDK
    let page: SDK.Page
    let initialPayload: [String: Any]?
    let opaque: Bool
    let backgroundColor: Color?
    let callback: SDKViewDismissCallback?
    let autoDismiss: Bool
    let ignoreSafeArea: Bool
    let overridLocale: String?

    public init(sdk: TheSDK,
                page: Page,
                initialPayload: [String: Any]? = nil,
                opaque: Bool = true,
                backgroundColor: Color? = nil,
                ignoreSafeArea: Bool = false,
                overridLocale: String? = nil,
                autoDismiss: Bool = true,
                _ callback: SDKViewDismissCallback? = nil)
    {
        self.sdk = sdk
        self.page = page
        self.initialPayload = initialPayload
        self.opaque = opaque
        self.backgroundColor = backgroundColor
        self.ignoreSafeArea = ignoreSafeArea
        self.callback = callback
        self.autoDismiss = autoDismiss
        self.overridLocale = overridLocale
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        let sdkView = SDKView(model: sdk, page: page, show: .init(get: {
            true
        }, set: { _ in
            if self.autoDismiss {
                DispatchQueue.main.async {
                    self.dismiss(animated: true)
                }
            }

        }), initialPayload: initialPayload,
        opeque: opaque,
        backgroundColor: backgroundColor,
        ignoreSafeArea: ignoreSafeArea,
        overrideLocale: overridLocale,
        callback)
            .ignoresSafeArea()

        let subVC = UIHostingController(rootView: sdkView)
        view.addSubview(subVC.view)
        addChild(subVC)

        subVC.view.translatesAutoresizingMaskIntoConstraints = false
        subVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        subVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        subVC.view.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        subVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }
}

// class B: UIHostingController<ModifiedContent<SDKView, _SafeAreaRegionsIgnoringLayout>> {
//    init(callback: @escaping () -> Void) {
//        let sdkView = SDKView(model: (UIApplication.shared.delegate as! AppDelegate).sdk, page: .splash, show: .init(get: {
//            true
//        }, set: { _ in
//            callback()
//        }))
//        .ignoresSafeArea()
//
//        super.init(rootView: sdkView as! ModifiedContent<SDKView, _SafeAreaRegionsIgnoringLayout>)
//    }
//
//    @MainActor @preconcurrency dynamic required init?(coder aDecoder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
// }
