import CoreLocation
import Foundation

@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationService()
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var continuationResumed = false  // ✅ FIX: Flag para evitar double resume

    private override init() {
        super.init()
        manager.delegate = self
        // Usar precisión óptima para validación de visitas
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
    }

    /// Pide permiso (si hace falta) y devuelve una localización puntual (o nil si no se pudo).
    func requestCurrentLocation() async -> CLLocation? {
        // 1) Verificar permisos actuales
        let status = manager.authorizationStatus

        switch status {
        case .notDetermined:
            // Pedir permisos y esperar respuesta
            return await requestPermissionsAndLocation()

        case .denied, .restricted:
            // Sin permisos, no podemos hacer nada
            Logger.warning("❌ LocationService: Permisos denegados o restringidos")
            return nil

        case .authorizedWhenInUse, .authorizedAlways:
            // Permisos OK, intentar obtener ubicación
            // Primero verificar si hay una ubicación reciente cacheada (< 10 segundos)
            if let lastLocation = manager.location,
               Date().timeIntervalSince(lastLocation.timestamp) < 10,
               lastLocation.horizontalAccuracy >= 0 {
                Logger.debug("✅ LocationService: Usando ubicación cacheada (\(lastLocation.horizontalAccuracy)m de precisión)")
                return lastLocation
            }

            // Si no hay cache válida, solicitar nueva ubicación
            return await requestLocation()

        @unknown default:
            Logger.warning("⚠️ LocationService: Estado de autorización desconocido")
            return nil
        }
    }

    /// Solicita permisos y espera la ubicación
    private func requestPermissionsAndLocation() async -> CLLocation? {
        Logger.debug("📍 LocationService: Solicitando permisos...")

        continuationResumed = false  // ✅ Reset flag

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.requestWhenInUseAuthorization()

            // Timeout de 5 segundos para que el usuario responda
            timeoutTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if let cont = self.continuation, !self.continuationResumed {
                    Logger.warning("⏱️ LocationService: Timeout esperando permisos")
                    self.continuationResumed = true
                    self.continuation = nil
                    cont.resume(returning: nil)
                }
            }
        }
    }

    /// Solicita la ubicación actual
    private func requestLocation() async -> CLLocation? {
        Logger.debug("📍 LocationService: Solicitando ubicación...")

        continuationResumed = false  // ✅ Reset flag

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            self.manager.requestLocation()

            // Timeout reducido a 3 segundos
            timeoutTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if let cont = self.continuation, !self.continuationResumed {
                    Logger.warning("⏱️ LocationService: Timeout obteniendo ubicación")
                    self.continuationResumed = true
                    self.continuation = nil
                    cont.resume(returning: nil)
                }
            }
        }
    }

    /// Cancela el timeout actual si existe
    private func cancelTimeout() {
        timeoutTask?.cancel()
        timeoutTask = nil
    }

    // MARK: CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Logger.debug("🔐 LocationService: Cambio de autorización: \(status.rawValue)")

        guard let continuation = self.continuation, !continuationResumed else { return }

        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            // Permisos concedidos, ahora solicitar ubicación
            Logger.info("✅ LocationService: Permisos concedidos, solicitando ubicación...")
            cancelTimeout()
            manager.requestLocation()

        case .denied, .restricted:
            // Permisos denegados
            Logger.warning("❌ LocationService: Permisos denegados")
            cancelTimeout()
            continuationResumed = true
            self.continuation = nil
            continuation.resume(returning: nil)

        case .notDetermined:
            // Aún esperando respuesta del usuario
            break

        @unknown default:
            Logger.warning("⚠️ LocationService: Estado desconocido")
            cancelTimeout()
            continuationResumed = true
            self.continuation = nil
            continuation.resume(returning: nil)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let continuation = self.continuation, !continuationResumed else { return }

        cancelTimeout()

        // Obtener la ubicación más reciente con mejor precisión
        let best = locations
            .filter { $0.horizontalAccuracy >= 0 }
            .sorted { loc1, loc2 in
                // Priorizar: más reciente y mejor precisión
                if abs(loc1.timestamp.timeIntervalSince(loc2.timestamp)) < 1 {
                    return loc1.horizontalAccuracy < loc2.horizontalAccuracy
                }
                return loc1.timestamp > loc2.timestamp
            }
            .first

        if let location = best {
            Logger.info("✅ LocationService: Ubicación obtenida (precisión: \(location.horizontalAccuracy)m)")
        } else {
            Logger.warning("⚠️ LocationService: No se encontró ubicación válida")
        }

        continuationResumed = true
        self.continuation = nil
        continuation.resume(returning: best)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Logger.error("❌ LocationService: Error obteniendo ubicación: \(error.localizedDescription)")

        guard let continuation = self.continuation, !continuationResumed else { return }

        // ✅ FIX: Mostrar error al usuario
        let errorCode = (error as NSError).code
        let errorMessage: String

        switch errorCode {
        case 0: // kCLErrorLocationUnknown
            errorMessage = "No se pudo determinar tu ubicación. Intenta de nuevo."
        case 1: // kCLErrorDenied
            errorMessage = "Permisos de ubicación denegados. Actívalos en Ajustes."
        default:
            errorMessage = "Error al obtener ubicación: \(error.localizedDescription)"
        }

        ToastManager.shared.error(errorMessage)

        cancelTimeout()
        continuationResumed = true
        self.continuation = nil
        continuation.resume(returning: nil)
    }
}
