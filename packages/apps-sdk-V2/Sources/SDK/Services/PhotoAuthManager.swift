//
//  PhotoAuthManager.swift
//  PhotoTool
//
//  Created by Dubon Ya'ar on 12/10/2025.
//

import Combine

import Photos
import UIKit

@Observable
@MainActor
public class PhotoGalleryAuthManager {
    @ObservationIgnored
    public static let shared = PhotoGalleryAuthManager()

    @ObservationIgnored
    private var cont: CheckedContinuation<PHAuthorizationStatus, Never>?

    private var cancellables = Set<AnyCancellable>()

    var authStatus: PHAuthorizationStatus {
        didSet {
            cont?.resume(returning: authStatus)
            cont = nil
        }
    }

    private init() {
        authStatus = PHPhotoLibrary.authorizationStatus()

        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [self] _ in
                authStatus = PHPhotoLibrary.authorizationStatus()
            }
            .store(in: &cancellables)
    }

    public func authorize(accessLevel: PHAccessLevel = .readWrite) async -> PHAuthorizationStatus {
        await withCheckedContinuation { cont in
            let state = PHPhotoLibrary.authorizationStatus(for: accessLevel)
            authStatus = state
            guard !state.anyAuthorized else {
                cont.resume(returning: state)
                return
            }

            self.cont = cont

            if state == .notDetermined {
                PHPhotoLibrary.requestAuthorization(for: .readWrite) { newState in
                    DispatchQueue.main.async {
                        self.authStatus = newState
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

public extension PHAuthorizationStatus {
    var anyAuthorized: Bool {
        switch self {
        case .authorized, .limited, .restricted:
            true
        default:
            false
        }
    }
}
