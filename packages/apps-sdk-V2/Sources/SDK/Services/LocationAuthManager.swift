//
//  LocationAuthManager.swift
//  SDK
//
//  Created by Dubon Ya'ar on 27/10/2025.
//

import Combine
import CoreLocation
import UIKit

@Observable
class LocationAuthManager: NSObject, CLLocationManagerDelegate {
    @ObservationIgnored
    static let shared = LocationAuthManager()

    @ObservationIgnored
    private var cont: CheckedContinuation<CLAuthorizationStatus, Never>?

    @ObservationIgnored
    private var locationManager: CLLocationManager?

    private var cancellables = Set<AnyCancellable>()

    var authStatus: CLAuthorizationStatus = CLLocationManager().authorizationStatus {
        didSet {
            cont?.resume(returning: authStatus)
            cont = nil
        }
    }

    @MainActor
    func authorize(accuracy: CLAccuracyAuthorization = .fullAccuracy) async -> CLAuthorizationStatus {
        await withCheckedContinuation { cont in
            let manager = CLLocationManager()
            locationManager = manager
            manager.delegate = self

            let state = manager.authorizationStatus
            authStatus = state

            guard !state.isAuthorized else {
                cont.resume(returning: state)
                return
            }

            self.cont = cont

            if state == .notDetermined {
                manager.requestWhenInUseAuthorization()
            } else if state == .denied || state == .restricted {
                if let appSettings = URL(string: UIApplication.openSettingsURLString),
                   UIApplication.shared.canOpenURL(appSettings)
                {
                    UIApplication.shared.open(appSettings, options: [:], completionHandler: nil)
                }
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if authStatus.rawValue != manager.authorizationStatus.rawValue {
            authStatus = manager.authorizationStatus
        }
    }
}

extension CLAuthorizationStatus {
    var isAuthorized: Bool {
        switch self {
        case .authorizedAlways, .authorizedWhenInUse:
            true
        default:
            false
        }
    }
}
