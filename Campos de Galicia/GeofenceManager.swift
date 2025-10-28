import Foundation
import CoreLocation
import UserNotifications
import Supabase
import UIKit

/// Administra geovallas y auto check-in con permanencia (dwell) sin usar GPS continuo.
/// - Usa requestLocation() puntualmente y Significant Location Changes (muy bajo consumo) para priorizar las 20 geovallas más cercanas.
/// - El dwell se activa al entrar/estar dentro de la región. Si al completar los 120s ya estaba visitado **hoy**, no inserta.
/// - Radio: 500 m. Dwell: 120 s.
final class GeofenceManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    // Estado público (solo lectura desde fuera)
    @Published private(set) var autoCheckinEnabled: Bool = false

    // Core Location
    private let locationManager = CLLocationManager()

    // Config
    private let regionRadius: CLLocationDistance = 50
    private let dwellSeconds: TimeInterval = 120
    private let maxRegions: Int = 20

    // Datos
    private var allCampos: [CampoModel] = []
    private var lastKnownLocation: CLLocation?
    private var pendingDwells: [UUID: Timer] = [:]
    private var recentlyCheckedIn: Set<UUID> = []   // Evita múltiples registros mientras permaneces en el área

    // Auto-refresh
    private let refreshInterval: TimeInterval = 6 * 60 * 60 // 6h
    private let lastRefreshKey = "gf_last_refresh_ts"
    private var appActiveObserver: NSObjectProtocol?

    override init() {
        super.init()
        locationManager.delegate = self
        // No activamos GPS continuo -> optimiza batería
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.pausesLocationUpdatesAutomatically = true
        locationManager.allowsBackgroundLocationUpdates = true

        // Observa cuando la app vuelve a primer plano para refrescar geovallas si toca
        appActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshMonitoredRegionsIfNeeded()
        }
    }

    deinit {
        if let obs = appActiveObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    // MARK: - API pública

    /// Activa/desactiva el auto check-in y prepara geovallas.
    func setAutoCheckin(_ enabled: Bool, campos: [CampoModel]) {
        autoCheckinEnabled = enabled

        if enabled {
            allCampos = campos
            startMonitoringIfAuthorized()

            // Posición puntual para priorizar las más cercanas (una sola vez)
            locationManager.requestLocation()

            // Significant Location Changes: re-prioriza con bajísimo consumo al moverte bastante
            locationManager.startMonitoringSignificantLocationChanges()

            // Refresco en arranque si han pasado >6h
            refreshMonitoredRegionsIfNeeded()
        } else {
            stopAllGeofences()
            invalidateAllDwells()
            recentlyCheckedIn.removeAll()
            locationManager.stopMonitoringSignificantLocationChanges()
        }
    }

    /// Llamar si cambia la lista de campos.
    func refreshWith(campos: [CampoModel]) {
        allCampos = campos
        guard autoCheckinEnabled else { return }
        // Recalcula las regiones con la última localización conocida (si hay)
        registerGeofences()
    }

    // MARK: - CoreLocation: autorización y registro

    private func startMonitoringIfAuthorized() {
        let status = locationManager.authorizationStatus
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            registerGeofences()
        case .notDetermined:
            // Para que funcione también en background, lo ideal es Always. Si el usuario solo da WhenInUse,
            // seguirá funcionando mientras la app esté en foreground (y algunas transiciones).
            locationManager.requestAlwaysAuthorization()
        case .denied, .restricted:
            stopAllGeofences()
        @unknown default:
            stopAllGeofences()
        }
    }

    /// Registra hasta 20 geofences priorizando por cercanía si tenemos `lastKnownLocation`.
    private func registerGeofences() {
        stopAllGeofences()

        // Ordena por distancia a la última ubicación si la tenemos
        let ordered: [CampoModel]
        if let loc = lastKnownLocation {
            ordered = allCampos
                .sorted { a, b in
                    guard let alat = a.latitud, let alon = a.longitud,
                          let blat = b.latitud, let blon = b.longitud else { return false }
                    let da = loc.distance(from: CLLocation(latitude: alat, longitude: alon))
                    let db = loc.distance(from: CLLocation(latitude: blat, longitude: blon))
                    return da < db
                }
        } else {
            // Sin ubicación, registra primeros 20 como fallback
            ordered = allCampos
        }

        let toMonitor = Array(ordered.prefix(maxRegions))
        print("📍 Registrando \(toMonitor.count) geofences")

        for campo in toMonitor {
            guard let lat = campo.latitud, let lon = campo.longitud else { continue }
            let region = CLCircularRegion(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                radius: regionRadius,
                identifier: campo.id.uuidString
            )
            region.notifyOnEntry = true
            region.notifyOnExit = true
            locationManager.startMonitoring(for: region)
            print("➡️ startMonitoring \(campo.id) radio=\(Int(regionRadius))m")
        }

        // Solicita estado inicial para disparar .inside si ya estás dentro al arrancar
        for region in locationManager.monitoredRegions {
            locationManager.requestState(for: region)
        }

        // Marca último refresh
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastRefreshKey)
    }

    private func stopAllGeofences() {
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
        print("🛑 Paradas todas las geovallas")
    }

    private func invalidateAllDwells() {
        pendingDwells.values.forEach { $0.invalidate() }
        pendingDwells.removeAll()
    }

    // Refresca geovallas si han pasado > refreshInterval o cambió el día
    private func refreshMonitoredRegionsIfNeeded() {
        guard autoCheckinEnabled else { return }
        let now = Date()
        let ts = UserDefaults.standard.double(forKey: lastRefreshKey)
        let last = ts > 0 ? Date(timeIntervalSince1970: ts) : .distantPast

        let calendar = Calendar.current
        let dayChanged = !calendar.isDate(last, inSameDayAs: now)
        let timeElapsed = now.timeIntervalSince(last) > refreshInterval

        if dayChanged || timeElapsed {
            print("🔄 Geovallas refrescadas automáticamente (dayChanged=\(dayChanged), timeElapsed=\(timeElapsed))")
            registerGeofences()
        }
    }

    // MARK: - Dwell

    private func startDwell(for campo: CampoModel) {
        let id = campo.id
        // Si ya se disparó recientemente (o ya hay dwell corriendo), no duplicar
        if recentlyCheckedIn.contains(id) { return }
        if pendingDwells[id] != nil { return }

        print("⏱️ Empezando dwell para \(campo.nombre)")
        let timer = Timer.scheduledTimer(withTimeInterval: dwellSeconds, repeats: false) { [weak self] _ in
            self?.completeDwell(for: campo)
        }
        // Añade a run loop común para mayor fiabilidad
        RunLoop.main.add(timer, forMode: .common)
        pendingDwells[id] = timer
    }

    private func cancelDwell(for campo: CampoModel) {
        if let t = pendingDwells.removeValue(forKey: campo.id) {
            t.invalidate()
            print("🛑 Cancel dwell \(campo.nombre)")
        }
    }

    private func completeDwell(for campo: CampoModel) {
        // El dwell se ha cumplido; valida en Supabase antes de insertar
        pendingDwells.removeValue(forKey: campo.id)
        Task { [weak self] in
            guard let self else { return }
            do {
                guard let user = supabase.auth.currentUser else { return }
                let userId = user.id.uuidString
                let campoId = campo.id.uuidString

                // 1) ¿Ya hay visita HOY?
                let alreadyToday = try await self.hasVisitToday(userId: userId, campoId: campoId)
                if alreadyToday {
                    print("ℹ️ Ya existía visita HOY para \(campo.nombre); no se duplica.")
                    self.recentlyCheckedIn.insert(campo.id)
                    return
                }

                // 2) Insertar visita
                let visita: [String: String] = ["id_usuario": userId, "id_campo": campoId]
                _ = try await supabase.from("visitas").insert(visita).execute()
                print("✅ Visita registrada para \(campo.nombre)")

                // Evita repetir mientras sigas dentro
                self.recentlyCheckedIn.insert(campo.id)

                // Notificación local
                await self.notifyAutoCheckin(name: campo.nombre)

                // Avisar a la app (para refrescar UI/logros)
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .didUpdateVisits, object: nil)
                }
            } catch {
                print("❌ Error al completar dwell: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Supabase helpers

    /// Comprueba si existe ya una visita **hoy** para (usuario, campo).
    private func hasVisitToday(userId: String, campoId: String) async throws -> Bool {
        // Comienzo del día local -> ISO8601 en UTC para comparar con `created_at` (que suele guardarse en UTC)
        let startOfDayLocal = Calendar.current.startOfDay(for: Date())
        let isoUTC = iso8601UTCString(from: startOfDayLocal)

        let resp = try await supabase
            .from("visitas")
            .select("id, created_at", head: false, count: .exact)
            .eq("id_usuario", value: userId)
            .eq("id_campo", value: campoId)
            .gte("created_at", value: isoUTC)
            .limit(1)
            .execute()

        if let json = try? JSONSerialization.jsonObject(with: resp.data) as? [[String: Any]] {
            return !json.isEmpty
        }
        return false
    }

    /// Convierte fecha local a string ISO8601 en UTC (ej. "2025-01-08T00:00:00Z")
    private func iso8601UTCString(from date: Date) -> String {
        let utc = TimeZone(secondsFromGMT: 0)!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = utc
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)

        let formatter = ISO8601DateFormatter()
        formatter.timeZone = utc
        formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTime]
        return formatter.string(from: cal.date(from: comps)!)
    }

    @MainActor
    private func notifyAutoCheckin(name: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Visita registrada"
        content.body = "Has estado 2 minutos en \(name). ¡Visita confirmada! ✅"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req) { err in
            if let err { print("❌ Notif auto-checkin: \(err.localizedDescription)") }
        }
    }

    // MARK: - Helpers

    private func campo(for idString: String) -> CampoModel? {
        guard let id = UUID(uuidString: idString) else { return nil }
        return allCampos.first { $0.id == id }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("🔐 Location auth status: \(status.rawValue)")
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            if autoCheckinEnabled { registerGeofences() }
        case .denied, .restricted:
            stopAllGeofences()
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Se llamará tras requestLocation() y también con Significant Location Changes.
        if let loc = locations.last {
            lastKnownLocation = loc
            if autoCheckinEnabled {
                // Reprioriza por cercanía con esta ubicación
                registerGeofences()
                // Y pide estado por si ya estás dentro de alguna recién activada
                for region in manager.monitoredRegions {
                    manager.requestState(for: region)
                }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Error ubicación: \(error.localizedDescription)")
    }

    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        print("✅ didStartMonitoring: \(region.identifier)")
        // Consultamos estado inicial para disparar .inside si ya está dentro al iniciar
        manager.requestState(for: region)
    }

    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        guard let campo = campo(for: region.identifier) else { return }
        switch state {
        case .inside:
            if !recentlyCheckedIn.contains(campo.id) {
                startDwell(for: campo)
            }
        case .outside:
            cancelDwell(for: campo)
            recentlyCheckedIn.remove(campo.id)
        case .unknown:
            break
        @unknown default:
            break
        }
        print("ℹ️ didDetermineState=\(state.rawValue): \(region.identifier)")
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let campo = campo(for: region.identifier) else { return }
        if !recentlyCheckedIn.contains(campo.id) {
            startDwell(for: campo)
        }
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let campo = campo(for: region.identifier) else { return }
        cancelDwell(for: campo)
        recentlyCheckedIn.remove(campo.id)
    }
}
