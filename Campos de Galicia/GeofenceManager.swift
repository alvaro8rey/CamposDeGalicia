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
    private let regionRadius: CLLocationDistance = 500
    private let dwellSeconds: TimeInterval = 120
    private let maxRegions: Int = 20

    // Datos
    private var allCampos: [CampoModel] = []
    private var lastKnownLocation: CLLocation?
    private var pendingDwells: [UUID: Timer] = [:]
    private var dwellStartTimes: [UUID: Date] = [:]  // Timestamp de entrada para verificación alternativa
    private var recentlyCheckedIn: Set<UUID> = []   // Evita múltiples registros mientras permaneces en el área

    // Auto-refresh
    private let refreshInterval: TimeInterval = 6 * 60 * 60 // 6h
    private let lastRefreshKey = "gf_last_refresh_ts"
    private var appActiveObserver: NSObjectProtocol?

    override init() {
        super.init()
        locationManager.delegate = self
        // No activamos GPS continuo -> optimiza batería
        // Usamos precisión de 10m para mejor detección de geovallas (balance consumo/precisión)
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.pausesLocationUpdatesAutomatically = true
        locationManager.allowsBackgroundLocationUpdates = true

        // Observa cuando la app vuelve a primer plano para refrescar geovallas si toca
        appActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("📱 App activada - verificando dwells pendientes")
            self?.checkPendingDwells()
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
            print("🔔 Auto check-in ACTIVADO - configurando geovallas para \(campos.count) campos")
            allCampos = campos
            startMonitoringIfAuthorized()

            // Posición puntual para priorizar las más cercanas (una sola vez)
            locationManager.requestLocation()

            // Significant Location Changes: re-prioriza con bajísimo consumo al moverte bastante
            locationManager.startMonitoringSignificantLocationChanges()

            // Refresco en arranque si han pasado >6h
            refreshMonitoredRegionsIfNeeded()
        } else {
            print("🔕 Auto check-in DESACTIVADO - limpiando geovallas")
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

    /// Cancela el temporizador de dwell para un campo (llamar cuando se marca manualmente)
    func cancelPendingDwell(for campoId: UUID) {
        if let timer = pendingDwells.removeValue(forKey: campoId) {
            timer.invalidate()
            print("🛑 Dwell cancelado para campo \(campoId) (marca manual)")
        }
        // Marcar como recientemente visitado para evitar que se reactive
        recentlyCheckedIn.insert(campoId)
    }

    /// Diagnóstico: Muestra el estado actual del sistema de geovallas
    func printDiagnostics() {
        print("\n━━━ DIAGNÓSTICO AUTO CHECK-IN ━━━")
        print("Estado: \(autoCheckinEnabled ? "✅ ACTIVADO" : "❌ DESACTIVADO")")
        print("Ubicación conocida: \(lastKnownLocation != nil ? "✅ Sí" : "❌ No")")
        if let loc = lastKnownLocation {
            print("  - Lat: \(loc.coordinate.latitude), Lon: \(loc.coordinate.longitude)")
        }
        print("Regiones monitorizadas: \(locationManager.monitoredRegions.count)/20")
        for region in locationManager.monitoredRegions {
            if let campo = campo(for: region.identifier) {
                print("  - \(campo.nombre) (ID: \(region.identifier))")
            }
        }
        print("Dwells pendientes: \(pendingDwells.count)")
        for (id, _) in pendingDwells {
            if let campo = allCampos.first(where: { $0.id == id }) {
                let elapsed = dwellStartTimes[id].map { Int(Date().timeIntervalSince($0)) } ?? 0
                let remaining = max(0, Int(dwellSeconds) - elapsed)
                print("  - \(campo.nombre) (transcurridos: \(elapsed)s, restantes: \(remaining)s)")
            }
        }
        print("Campos en recentlyCheckedIn: \(recentlyCheckedIn.count)")
        for id in recentlyCheckedIn {
            if let campo = allCampos.first(where: { $0.id == id }) {
                print("  - \(campo.nombre)")
            }
        }
        print("Autorización ubicación: \(locationManager.authorizationStatus.rawValue)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
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

        // Capturar valores para background thread
        let campos = allCampos
        let location = lastKnownLocation
        let maxRegionsCount = maxRegions

        // Mover cálculos de distancia a background thread
        Task.detached(priority: .utility) {
            let ordered: [CampoModel]
            if let loc = location {
                // Calcular distancias en background
                let camposWithDistances = campos.compactMap { campo -> (campo: CampoModel, distance: Double)? in
                    guard let alat = campo.latitud, let alon = campo.longitud else { return nil }
                    let distance = loc.distance(from: CLLocation(latitude: alat, longitude: alon))
                    return (campo, distance)
                }
                // Ordenar por distancia
                ordered = camposWithDistances
                    .sorted { $0.distance < $1.distance }
                    .map { $0.campo }
            } else {
                // Sin ubicación, usar todos los campos
                ordered = campos
            }

            let toMonitor = Array(ordered.prefix(maxRegionsCount))

            // Registrar geofences en main thread (requerido por CLLocationManager)
            await MainActor.run {
                print("📍 Registrando \(toMonitor.count) geofences de \(campos.count) campos totales")

                if let loc = location {
                    print("📍 Ubicación actual: lat=\(loc.coordinate.latitude), lon=\(loc.coordinate.longitude)")
                } else {
                    print("⚠️ No hay ubicación conocida - usando todos los campos sin priorizar")
                }

                for (index, campo) in toMonitor.enumerated() {
                    guard let lat = campo.latitud, let lon = campo.longitud else { continue }
                    let campoLoc = CLLocation(latitude: lat, longitude: lon)
                    let distance = location?.distance(from: campoLoc) ?? 0

                    let region = CLCircularRegion(
                        center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                        radius: self.regionRadius,
                        identifier: campo.id.uuidString
                    )
                    region.notifyOnEntry = true
                    region.notifyOnExit = true
                    self.locationManager.startMonitoring(for: region)

                    let distanceStr = location != nil ? "\(Int(distance))m" : "?"
                    print("  \(index+1). \(campo.nombre) - Distancia: \(distanceStr) - Radio: \(Int(self.regionRadius))m")
                }

                // Solicita estado inicial para disparar .inside si ya estás dentro al arrancar
                for region in self.locationManager.monitoredRegions {
                    self.locationManager.requestState(for: region)
                }

                print("✅ Total de regiones monitorizadas: \(self.locationManager.monitoredRegions.count)")

                // Marca último refresh
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: self.lastRefreshKey)
            }
        }
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
        dwellStartTimes.removeAll()
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
        if recentlyCheckedIn.contains(id) {
            print("⏭️ Campo \(campo.nombre) ya marcado en recentlyCheckedIn - ignorando dwell")
            return
        }
        if pendingDwells[id] != nil {
            print("⏭️ Ya hay dwell en curso para \(campo.nombre) - ignorando")
            return
        }

        let now = Date()
        dwellStartTimes[id] = now
        print("⏱️ Empezando dwell de \(Int(dwellSeconds))s para \(campo.nombre) (ID: \(id)) - Inicio: \(now)")

        let timer = Timer.scheduledTimer(withTimeInterval: dwellSeconds, repeats: false) { [weak self] _ in
            self?.completeDwell(for: campo)
        }
        // Añade a run loop común para mayor fiabilidad
        RunLoop.main.add(timer, forMode: .common)
        pendingDwells[id] = timer

        // IMPORTANTE: Programar verificación alternativa usando background task
        // para casos donde el timer no funcione en background
        scheduleBackgroundVerification(for: campo)
    }

    private func cancelDwell(for campo: CampoModel) {
        if let t = pendingDwells.removeValue(forKey: campo.id) {
            t.invalidate()
            print("🛑 Cancel dwell \(campo.nombre)")
        }
        dwellStartTimes.removeValue(forKey: campo.id)
    }

    /// Programa una verificación en background por si el timer no funciona
    private func scheduleBackgroundVerification(for campo: CampoModel) {
        // Esta función se llamará cuando volvamos a recibir actualizaciones de ubicación
        // o cuando se detecte de nuevo el estado de la región
        print("📝 Programada verificación alternativa para \(campo.nombre)")
    }

    /// Verifica si algún campo ha cumplido el dwell time sin que se haya disparado el timer
    private func checkPendingDwells() {
        let now = Date()
        for (campoId, startTime) in dwellStartTimes {
            let elapsed = now.timeIntervalSince(startTime)
            if elapsed >= dwellSeconds {
                // El tiempo ha pasado, verificar si el timer no se disparó
                if pendingDwells[campoId] != nil {
                    print("⚠️ Timer no se disparó para campo \(campoId) - ejecutando manualmente")
                    if let campo = allCampos.first(where: { $0.id == campoId }) {
                        completeDwell(for: campo)
                    }
                }
            }
        }
    }

    private func completeDwell(for campo: CampoModel) {
        // El dwell se ha cumplido; valida en Supabase antes de insertar
        pendingDwells.removeValue(forKey: campo.id)
        dwellStartTimes.removeValue(forKey: campo.id)
        print("✅ Dwell completado para \(campo.nombre) - Verificando visita en Supabase...")

        Task { [weak self] in
            guard let self else { return }
            do {
                guard let user = supabase.auth.currentUser else {
                    print("❌ No hay usuario autenticado")
                    return
                }
                let userId = user.id.uuidString
                let campoId = campo.id.uuidString

                print("🔍 Verificando si campo \(campoId) ya fue visitado alguna vez por usuario \(userId)")

                // 1) ¿Ya hay visita registrada alguna vez? (auto check-in solo para campos nuevos)
                let alreadyVisited = try await self.hasVisit(userId: userId, campoId: campoId)
                if alreadyVisited {
                    print("ℹ️ Campo \(campo.nombre) ya fue visitado previamente; auto check-in solo funciona para campos nuevos.")
                    self.recentlyCheckedIn.insert(campo.id)
                    return
                }

                // 2) Insertar visita
                print("💾 Insertando nueva visita para \(campo.nombre)...")
                let visita: [String: String] = ["id_usuario": userId, "id_campo": campoId]
                _ = try await supabase.from("visitas").insert(visita).execute()
                print("✅ Visita registrada exitosamente para \(campo.nombre)")

                // Evita repetir mientras sigas dentro
                self.recentlyCheckedIn.insert(campo.id)

                // Notificación local
                await self.notifyAutoCheckin(name: campo.nombre, campoID: campo.id)

                // Avisar a la app (para refrescar UI/logros)
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .didUpdateVisits, object: nil)
                }
            } catch {
                print("❌ Error al completar dwell: \(error.localizedDescription)")
                print("❌ Detalles del error: \(error)")
                // Notificar al usuario del error
                await self.notifyAutoCheckinError(name: campo.nombre, error: error)
            }
        }
    }

    // MARK: - Supabase helpers

    /// Comprueba si existe ya una visita para (usuario, campo) en cualquier momento (histórico).
    /// El auto check-in solo debe registrar campos que NUNCA han sido visitados.
    private func hasVisit(userId: String, campoId: String) async throws -> Bool {
        print("🔍 Verificando si existe alguna visita histórica para campo \(campoId)")

        let resp = try await supabase
            .from("visitas")
            .select("id", head: false, count: .exact)
            .eq("id_usuario", value: userId)
            .eq("id_campo", value: campoId)
            .limit(1)
            .execute()

        if let json = try? JSONSerialization.jsonObject(with: resp.data) as? [[String: Any]] {
            let hasVisited = !json.isEmpty
            print(hasVisited ? "✅ Campo ya visitado previamente - NO se hará auto check-in" : "ℹ️ Campo nunca visitado - se permitirá auto check-in")
            return hasVisited
        }
        print("⚠️ Error al parsear respuesta de visitas")
        return false
    }

    @MainActor
    private func notifyAutoCheckin(name: String, campoID: UUID) async {
        let content = UNMutableNotificationContent()
        content.title = L(.notifAutoCheckinTitle)
        content.body = L(.notifAutoCheckinBody, name)
        content.sound = .default

        // Agregar datos para deep linking
        content.userInfo = [
            "type": "autoCheckin",
            "campoID": campoID.uuidString,
            "campoName": name
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req) { err in
            if let err { print("❌ Notif auto-checkin: \(err.localizedDescription)") }
        }
    }

    @MainActor
    private func notifyAutoCheckinError(name: String, error: Error) async {
        let content = UNMutableNotificationContent()
        content.title = L(.notifAutoCheckinErrorTitle)
        content.body = L(.notifAutoCheckinErrorBody, name)
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req) { err in
            if let err { print("❌ Notif error auto-checkin: \(err.localizedDescription)") }
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
            print("📍 Ubicación actualizada: lat=\(loc.coordinate.latitude), lon=\(loc.coordinate.longitude)")

            if autoCheckinEnabled {
                // Verificar dwells pendientes por si los timers no funcionaron
                checkPendingDwells()

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
        guard let campo = campo(for: region.identifier) else {
            print("⚠️ Campo no encontrado para región \(region.identifier)")
            return
        }
        print("📍 didDetermineState: \(state.rawValue == 1 ? "INSIDE" : state.rawValue == 2 ? "OUTSIDE" : "UNKNOWN") para \(campo.nombre)")

        // Verificar dwells pendientes por si los timers no funcionaron
        checkPendingDwells()

        switch state {
        case .inside:
            if !recentlyCheckedIn.contains(campo.id) {
                print("✅ Usuario DENTRO de \(campo.nombre) - iniciando dwell")
                startDwell(for: campo)
            } else {
                print("ℹ️ Usuario DENTRO de \(campo.nombre) pero ya está en recentlyCheckedIn")
            }
        case .outside:
            print("🚪 Usuario FUERA de \(campo.nombre) - cancelando dwell")
            cancelDwell(for: campo)
            recentlyCheckedIn.remove(campo.id)
        case .unknown:
            print("❓ Estado desconocido para \(campo.nombre)")
            break
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let campo = campo(for: region.identifier) else {
            print("⚠️ Campo no encontrado para región \(region.identifier)")
            return
        }
        print("🚶 didEnterRegion: Usuario ENTRÓ en \(campo.nombre)")
        if !recentlyCheckedIn.contains(campo.id) {
            startDwell(for: campo)
        } else {
            print("ℹ️ Campo \(campo.nombre) ya está en recentlyCheckedIn - no iniciando dwell")
        }
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let campo = campo(for: region.identifier) else {
            print("⚠️ Campo no encontrado para región \(region.identifier)")
            return
        }
        print("🚶‍♂️ didExitRegion: Usuario SALIÓ de \(campo.nombre)")
        cancelDwell(for: campo)
        recentlyCheckedIn.remove(campo.id)
        print("🗑️ Campo \(campo.nombre) removido de recentlyCheckedIn")
    }
}
