import CoreLocation
import Foundation

@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationService()
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
    }

    /// Pide permiso (si hace falta) y devuelve una localización puntual (o nil si no se pudo).
    func requestCurrentLocation() async -> CLLocation? {
        // 1) Permisos
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
            // esperaremos al delegate para continuar
        case .denied, .restricted:
            return nil
        default:
            break
        }

        // 2) Solicitar ubicación puntual
        return await withCheckedContinuation { (continuation: CheckedContinuation<CLLocation?, Never>) in
            self.continuation = continuation
            self.manager.requestLocation()
            // fallback por si tarda demasiado (10s)
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                guard let self else { return }
                if let cont = self.continuation {
                    self.continuation = nil
                    cont.resume(returning: nil)
                }
            }
        }
    }

    // MARK: CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            // Nada: requestLocation lo dispara el caller
        } else if status == .denied || status == .restricted {
            continuation?.resume(returning: nil)
            continuation = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard continuation != nil else { return }
        // Coge la más reciente y razonable
        let best = locations
            .filter { $0.horizontalAccuracy >= 0 }
            .sorted { $0.timestamp > $1.timestamp }
            .first
        continuation?.resume(returning: best)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(returning: nil)
        continuation = nil
    }
}
