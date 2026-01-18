//
//  CameraAuthManager.swift
//  SDK
//
//  Created by Dubon Ya'ar on 27/10/2025.
//

import AVFoundation
import Combine
import UIKit

@Observable
public class CameraAuthManager {
    @ObservationIgnored
    public static let shared = CameraAuthManager()

    @ObservationIgnored
    private var cont: CheckedContinuation<AVAuthorizationStatus, Never>?

    private var cancellables = Set<AnyCancellable>()

    public var authStatus: AVAuthorizationStatus {
        didSet {
            cont?.resume(returning: authStatus)
            cont = nil
        }
    }

    public init() {
        authStatus = AVCaptureDevice.authorizationStatus(for: .video)

        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [self] _ in
                authStatus = AVCaptureDevice.authorizationStatus(for: .video)
            }
            .store(in: &cancellables)
    }

    @MainActor
    public func authorize() async -> AVAuthorizationStatus {
        await withCheckedContinuation { cont in
            let state = AVCaptureDevice.authorizationStatus(for: .video)
            authStatus = state
            guard !state.isAuthorized else {
                cont.resume(returning: state)
                return
            }

            self.cont = cont

            if state == .notDetermined {
                AVCaptureDevice.requestAccess(for: .video) { _ in
                    DispatchQueue.main.async {
                        self.authStatus = AVCaptureDevice.authorizationStatus(for: .video)
                    }
                }
            } else if state == .denied {
                if let appSettings = URL(string: UIApplication.openSettingsURLString),
                   UIApplication.shared.canOpenURL(appSettings)
                {
                    UIApplication.shared.open(appSettings, options: [:], completionHandler: nil)
                }
            }
        }
    }
}

public extension AVAuthorizationStatus {
    var isAuthorized: Bool {
        self == .authorized
    }
}
