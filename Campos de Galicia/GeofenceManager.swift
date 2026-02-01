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

    // UserDefaults key para persistir estado
    private let autoCheckinKey = "auto_checkin_enabled"

    // Datos
    private var allCampos: [CampoModel] = []
    private var lastKnownLocation: CLLocation?

    // NUEVO: Sistema de dwell sin timers, usando persistencia en disco
    // Esto permite que funcione incluso si iOS suspende/mata la app
    private let dwellStartTimesKey = "gf_dwell_start_times"
    private let recentlyCheckedInKey = "gf_recently_checked_in"
    private let completedDwellsKey = "gf_completed_dwells"  // Campos que ya completaron dwell y están esperando salida

    // Timer para verificación activa en foreground (mejora UX)
    // En background se usa solo el sistema de persistencia
    private var dwellCheckTimer: Timer?
    private let dwellCheckInterval: TimeInterval = 15 // Verifica cada 15s en foreground

    // Auto-refresh
    private let refreshInterval: TimeInterval = 6 * 60 * 60 // 6h
    private let lastRefreshKey = "gf_last_refresh_ts"
    private var appActiveObserver: NSObjectProtocol?
    private var appBackgroundObserver: NSObjectProtocol?

    override init() {
        super.init()

        // Leer estado guardado de auto check-in
        autoCheckinEnabled = UserDefaults.standard.bool(forKey: autoCheckinKey)

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
            print("📱 App activada - verificando dwells pendientes y activando timer de foreground")
            self?.checkPendingDwells()
            self?.refreshMonitoredRegionsIfNeeded()

            // Iniciar timer de verificación en foreground si hay auto check-in activo
            if self?.autoCheckinEnabled == true {
                self?.startDwellCheckTimer()
            }
        }

        // Observa cuando la app va a background para detener el timer (optimiza batería)
        appBackgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("📱 App yendo a background - deteniendo timer de foreground (se usará sistema de persistencia)")
            self?.stopDwellCheckTimer()
        }

        // Si el auto check-in ya estaba habilitado, iniciar el timer
        if autoCheckinEnabled {
            startDwellCheckTimer()
        }
    }

    deinit {
        stopDwellCheckTimer()
        if let obs = appActiveObserver {
            NotificationCenter.default.removeObserver(obs)
        }
        if let obs = appBackgroundObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    // MARK: - API pública

    /// Activa/desactiva el auto check-in y prepara geovallas.
    func setAutoCheckin(_ enabled: Bool, campos: [CampoModel]) {
        autoCheckinEnabled = enabled

        // Persistir estado en UserDefaults
        UserDefaults.standard.set(enabled, forKey: autoCheckinKey)

        if enabled {
            print("🔔 Auto check-in ACTIVADO - configurando geovallas para \(campos.count) campos")
            allCampos = campos

            // CRÍTICO: Intentar usar la ubicación en caché del sistema antes de registrar geovallas
            // Esto evita el problema de registrar sin ordenar cuando la app arranca
            if let cachedLocation = locationManager.location {
                lastKnownLocation = cachedLocation
                print("📍 Usando ubicación en caché: lat=\(cachedLocation.coordinate.latitude), lon=\(cachedLocation.coordinate.longitude)")
            } else {
                print("⚠️ No hay ubicación en caché - esperando requestLocation()")
            }

            startMonitoringIfAuthorized()

            // Posición puntual para priorizar las más cercanas (una sola vez)
            locationManager.requestLocation()

            // Significant Location Changes: re-prioriza con bajísimo consumo al moverte bastante
            locationManager.startMonitoringSignificantLocationChanges()

            // Refresco en arranque si han pasado >6h
            refreshMonitoredRegionsIfNeeded()

            // Iniciar timer de verificación activa en foreground
            startDwellCheckTimer()
        } else {
            print("🔕 Auto check-in DESACTIVADO - limpiando geovallas")
            stopAllGeofences()
            invalidateAllDwells()
            locationManager.stopMonitoringSignificantLocationChanges()

            // Detener timer de verificación
            stopDwellCheckTimer()
        }
    }

    /// Llamar si cambia la lista de campos.
    func refreshWith(campos: [CampoModel]) {
        allCampos = campos
        guard autoCheckinEnabled else { return }
        // Recalcula las regiones con la última localización conocida (si hay)
        registerGeofences()
    }

    /// Cancela el dwell para un campo (llamar cuando se marca manualmente)
    func cancelPendingDwell(for campoId: UUID) {
        removeDwellStartTime(for: campoId)
        removeCompletedDwell(for: campoId)
        addToRecentlyCheckedIn(campoId)
        print("🛑 Dwell cancelado para campo \(campoId) (marca manual)")
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

        let dwellTimes = getDwellStartTimes()
        print("Dwells pendientes: \(dwellTimes.count)")
        for (idString, timestamp) in dwellTimes {
            guard let id = UUID(uuidString: idString),
                  let campo = allCampos.first(where: { $0.id == id }) else { continue }
            let startTime = Date(timeIntervalSince1970: timestamp)
            let elapsed = Int(Date().timeIntervalSince(startTime))
            let remaining = max(0, Int(dwellSeconds) - elapsed)
            print("  - \(campo.nombre) (transcurridos: \(elapsed)s, restantes: \(remaining)s)")
        }

        let recentlyChecked = getRecentlyCheckedIn()
        print("Campos en recentlyCheckedIn: \(recentlyChecked.count)")
        for idString in recentlyChecked {
            guard let id = UUID(uuidString: idString),
                  let campo = allCampos.first(where: { $0.id == id }) else { continue }
            print("  - \(campo.nombre)")
        }

        let completed = getCompletedDwells()
        print("Dwells completados (esperando salida): \(completed.count)")
        for idString in completed {
            guard let id = UUID(uuidString: idString),
                  let campo = allCampos.first(where: { $0.id == id }) else { continue }
            print("  - \(campo.nombre)")
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
            // SIEMPRE filtrar campos sin coordenadas
            let camposValidos = campos.filter { $0.latitud != nil && $0.longitud != nil }

            let ordered: [CampoModel]
            if let loc = location {
                // Calcular distancias en background
                let camposWithDistances = camposValidos.map { campo -> (campo: CampoModel, distance: Double) in
                    let campoLoc = CLLocation(latitude: campo.latitud!, longitude: campo.longitud!)
                    let distance = loc.distance(from: campoLoc)
                    return (campo, distance)
                }
                // Ordenar por distancia
                ordered = camposWithDistances
                    .sorted { $0.distance < $1.distance }
                    .map { $0.campo }
            } else {
                // Sin ubicación, usar campos válidos sin ordenar
                ordered = camposValidos
            }

            let toMonitor = Array(ordered.prefix(maxRegionsCount))

            // Registrar geofences en main thread (requerido por CLLocationManager)
            await MainActor.run {
                let camposValidos = campos.filter { $0.latitud != nil && $0.longitud != nil }
                let camposSinCoordenadas = campos.count - camposValidos.count

                print("📍 Registrando \(toMonitor.count) geofences de \(camposValidos.count) campos con coordenadas")
                if camposSinCoordenadas > 0 {
                    print("ℹ️ Ignorados \(camposSinCoordenadas) campos sin coordenadas")
                }

                if let loc = location {
                    print("📍 Ubicación actual: lat=\(loc.coordinate.latitude), lon=\(loc.coordinate.longitude)")
                    print("📍 Campos ordenados por distancia (más cercano primero)")
                } else {
                    print("⚠️ No hay ubicación conocida - usando campos sin ordenar por distancia")
                }

                for (index, campo) in toMonitor.enumerated() {
                    guard let lat = campo.latitud, let lon = campo.longitud else {
                        print("⚠️ ADVERTENCIA: Campo \(campo.nombre) no tiene coordenadas - saltando")
                        continue
                    }
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
        // Limpiar toda la persistencia de dwells
        UserDefaults.standard.removeObject(forKey: dwellStartTimesKey)
        UserDefaults.standard.removeObject(forKey: recentlyCheckedInKey)
        UserDefaults.standard.removeObject(forKey: completedDwellsKey)
        print("🗑️ Limpiados todos los dwells persistentes")
    }

    // MARK: - Persistencia de Dwell (sin Timers, funciona en background)

    /// Guarda el timestamp de entrada a una geovalla
    private func saveDwellStartTime(for campoId: UUID, at time: Date) {
        var times = getDwellStartTimes()
        times[campoId.uuidString] = time.timeIntervalSince1970
        UserDefaults.standard.set(times, forKey: dwellStartTimesKey)
        print("💾 Guardado timestamp de entrada para \(campoId): \(time)")
    }

    /// Obtiene todos los timestamps de entrada guardados
    private func getDwellStartTimes() -> [String: TimeInterval] {
        return UserDefaults.standard.dictionary(forKey: dwellStartTimesKey) as? [String: TimeInterval] ?? [:]
    }

    /// Obtiene el timestamp de entrada para un campo específico
    private func getDwellStartTime(for campoId: UUID) -> Date? {
        let times = getDwellStartTimes()
        guard let timestamp = times[campoId.uuidString] else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    /// Elimina el timestamp de entrada
    private func removeDwellStartTime(for campoId: UUID) {
        var times = getDwellStartTimes()
        times.removeValue(forKey: campoId.uuidString)
        UserDefaults.standard.set(times, forKey: dwellStartTimesKey)
    }

    /// Marca un campo como que ya completó el dwell (esperando salida para limpiar)
    private func markDwellCompleted(for campoId: UUID) {
        var completed = getCompletedDwells()
        completed.insert(campoId.uuidString)
        UserDefaults.standard.set(Array(completed), forKey: completedDwellsKey)
    }

    /// Obtiene los campos que ya completaron dwell
    private func getCompletedDwells() -> Set<String> {
        let array = UserDefaults.standard.array(forKey: completedDwellsKey) as? [String] ?? []
        return Set(array)
    }

    /// Limpia el estado de dwell completado
    private func removeCompletedDwell(for campoId: UUID) {
        var completed = getCompletedDwells()
        completed.remove(campoId.uuidString)
        UserDefaults.standard.set(Array(completed), forKey: completedDwellsKey)
    }

    /// Guarda un campo en recently checked in
    private func addToRecentlyCheckedIn(_ campoId: UUID) {
        var recent = getRecentlyCheckedIn()
        recent.insert(campoId.uuidString)
        UserDefaults.standard.set(Array(recent), forKey: recentlyCheckedInKey)
    }

    /// Obtiene los campos en recently checked in
    private func getRecentlyCheckedIn() -> Set<String> {
        let array = UserDefaults.standard.array(forKey: recentlyCheckedInKey) as? [String] ?? []
        return Set(array)
    }

    /// Verifica si un campo está en recently checked in
    private func isRecentlyCheckedIn(_ campoId: UUID) -> Bool {
        return getRecentlyCheckedIn().contains(campoId.uuidString)
    }

    /// Limpia recently checked in para un campo (cuando sale de la geovalla)
    private func removeFromRecentlyCheckedIn(_ campoId: UUID) {
        var recent = getRecentlyCheckedIn()
        recent.remove(campoId.uuidString)
        UserDefaults.standard.set(Array(recent), forKey: recentlyCheckedInKey)
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

    // MARK: - Dwell (Sistema sin Timers, funciona en background)

    /// Inicia el seguimiento de permanencia para un campo (INSIDE)
    private func startDwell(for campo: CampoModel) {
        let id = campo.id

        // Si ya completó el dwell, no hacer nada
        if getCompletedDwells().contains(id.uuidString) {
            print("⏭️ Campo \(campo.nombre) ya completó dwell - esperando salida para limpiar")
            return
        }

        // Si ya se registró recientemente, no duplicar
        if isRecentlyCheckedIn(id) {
            print("⏭️ Campo \(campo.nombre) ya en recentlyCheckedIn - ignorando")
            return
        }

        // Si ya tiene timestamp de inicio, verificar si cumplió el tiempo
        if let startTime = getDwellStartTime(for: id) {
            let elapsed = Date().timeIntervalSince(startTime)
            print("⏱️ Dwell en curso para \(campo.nombre) - Transcurridos: \(Int(elapsed))s de \(Int(dwellSeconds))s")

            if elapsed >= dwellSeconds {
                print("✅ Dwell cumplido para \(campo.nombre) - ejecutando auto check-in")
                completeDwell(for: campo)
            }
            return
        }

        // Primera vez que entra: guardar timestamp
        let now = Date()
        saveDwellStartTime(for: id, at: now)
        print("⏱️ Iniciando dwell para \(campo.nombre) - se completará en \(Int(dwellSeconds))s")
    }

    /// Cancela el dwell al salir de la geovalla (OUTSIDE)
    private func cancelDwell(for campo: CampoModel) {
        let id = campo.id

        // Si ya completó el dwell, verificar si fue hace poco
        if getCompletedDwells().contains(id.uuidString) {
            print("🚪 Saliendo de \(campo.nombre) - dwell ya completado, limpiando estado")
            removeCompletedDwell(for: id)
            removeFromRecentlyCheckedIn(id)
            removeDwellStartTime(for: id)
            return
        }

        // Si estaba en dwell pero no completó, verificar el tiempo antes de cancelar
        if let startTime = getDwellStartTime(for: id) {
            let elapsed = Date().timeIntervalSince(startTime)
            print("🚪 Saliendo de \(campo.nombre) - Tiempo dentro: \(Int(elapsed))s de \(Int(dwellSeconds))s requeridos")

            // Si estuvo dentro el tiempo suficiente justo antes de salir, completar el dwell
            if elapsed >= dwellSeconds {
                print("✅ Cumplió el tiempo justo antes de salir - ejecutando auto check-in")
                completeDwell(for: campo)
                return
            }

            // No cumplió el tiempo, limpiar
            print("❌ No cumplió el tiempo mínimo - cancelando dwell")
            removeDwellStartTime(for: id)
        }

        // Limpiar recentlyCheckedIn al salir
        removeFromRecentlyCheckedIn(id)
    }

    /// Verifica todos los dwells pendientes (llamado al activar app o en eventos de ubicación)
    private func checkPendingDwells() {
        let now = Date()
        let times = getDwellStartTimes()

        print("🔍 Verificando \(times.count) dwells pendientes...")

        for (campoIdString, timestamp) in times {
            guard let campoId = UUID(uuidString: campoIdString),
                  let campo = allCampos.first(where: { $0.id == campoId }) else {
                continue
            }

            let startTime = Date(timeIntervalSince1970: timestamp)
            let elapsed = now.timeIntervalSince(startTime)

            // Si ya completó el dwell, skip
            if getCompletedDwells().contains(campoIdString) {
                continue
            }

            if elapsed >= dwellSeconds {
                print("⏰ Dwell cumplido para \(campo.nombre) (\(Int(elapsed))s) - ejecutando auto check-in")
                completeDwell(for: campo)
            } else {
                print("⏳ Dwell pendiente para \(campo.nombre) - \(Int(elapsed))s / \(Int(dwellSeconds))s")
            }
        }
    }

    // MARK: - Timer de verificación en foreground

    /// Inicia el timer que verifica dwells pendientes periódicamente (solo en foreground)
    /// Esto mejora la UX haciendo el auto check-in más preciso cuando la app está abierta
    private func startDwellCheckTimer() {
        // Evitar duplicados
        stopDwellCheckTimer()

        print("⏰ Iniciando timer de verificación en foreground (cada \(Int(dwellCheckInterval))s)")
        dwellCheckTimer = Timer.scheduledTimer(withTimeInterval: dwellCheckInterval, repeats: true) { [weak self] _ in
            self?.checkPendingDwells()
        }
        // Añadir al run loop común para mayor fiabilidad
        if let timer = dwellCheckTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    /// Detiene el timer de verificación (al ir a background o desactivar auto check-in)
    private func stopDwellCheckTimer() {
        if let timer = dwellCheckTimer {
            timer.invalidate()
            dwellCheckTimer = nil
            print("⏸️ Timer de verificación en foreground detenido")
        }
    }

    /// Completa el dwell y registra la visita automáticamente
    private func completeDwell(for campo: CampoModel) {
        let id = campo.id

        // Evitar ejecuciones duplicadas
        if getCompletedDwells().contains(id.uuidString) {
            print("⏭️ Dwell ya completado para \(campo.nombre) - ignorando")
            return
        }

        if isRecentlyCheckedIn(id) {
            print("⏭️ Campo \(campo.nombre) ya en recentlyCheckedIn - ignorando")
            return
        }

        // Marcar como completado inmediatamente para evitar duplicados
        markDwellCompleted(for: id)
        addToRecentlyCheckedIn(id)

        print("✅ Dwell completado para \(campo.nombre) - Verificando visita en Supabase...")

        // CRÍTICO: Solicitar tiempo de ejecución en background para completar la tarea
        // Esto evita que iOS suspenda la app antes de insertar en Supabase y enviar la notificación
        var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "CompleteDwell-\(campo.nombre)") {
            // Este bloque se ejecuta si se acaba el tiempo (raro, pero posible)
            print("⚠️ Background task expirado para \(campo.nombre)")
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }

        print("🔄 Background task iniciado (ID: \(backgroundTaskID.rawValue)) para procesar dwell de \(campo.nombre)")

        Task { [weak self] in
            guard let self else {
                // Si self es nil, terminar background task
                if backgroundTaskID != .invalid {
                    UIApplication.shared.endBackgroundTask(backgroundTaskID)
                }
                return
            }

            do {
                guard let user = supabase.auth.currentUser else {
                    print("❌ No hay usuario autenticado")
                    if backgroundTaskID != .invalid {
                        UIApplication.shared.endBackgroundTask(backgroundTaskID)
                    }
                    return
                }
                let userId = user.id.uuidString
                let campoId = campo.id.uuidString

                print("🔍 Verificando si campo \(campoId) ya fue visitado alguna vez por usuario \(userId)")

                // 1) ¿Ya hay visita registrada alguna vez? (auto check-in solo para campos nuevos)
                let alreadyVisited = try await self.hasVisit(userId: userId, campoId: campoId)
                if alreadyVisited {
                    print("ℹ️ Campo \(campo.nombre) ya fue visitado previamente; auto check-in solo funciona para campos nuevos.")
                    if backgroundTaskID != .invalid {
                        UIApplication.shared.endBackgroundTask(backgroundTaskID)
                    }
                    return
                }

                // 2) Insertar visita
                print("💾 Insertando nueva visita para \(campo.nombre)...")
                let visita: [String: String] = ["id_usuario": userId, "id_campo": campoId]
                _ = try await supabase.from("visitas").insert(visita).execute()
                print("✅ Visita registrada exitosamente para \(campo.nombre)")

                // Notificación local
                print("📲 Enviando notificación para \(campo.nombre)...")
                await self.notifyAutoCheckin(name: campo.nombre, campoID: campo.id)
                print("✅ Notificación enviada para \(campo.nombre)")

                // Avisar a la app (para refrescar UI/logros)
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .didUpdateVisits, object: nil)
                }

                print("✅ Auto check-in completado exitosamente para \(campo.nombre)")
            } catch {
                print("❌ Error al completar dwell: \(error.localizedDescription)")
                print("❌ Detalles del error: \(error)")
                // Notificar al usuario del error
                await self.notifyAutoCheckinError(name: campo.nombre, error: error)
            }

            // IMPORTANTE: Terminar background task cuando todo esté completo
            if backgroundTaskID != .invalid {
                print("🏁 Background task finalizado (ID: \(backgroundTaskID.rawValue)) para \(campo.nombre)")
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
                backgroundTaskID = .invalid
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
        guard let loc = locations.last else {
            print("⚠️ didUpdateLocations sin ubicación válida")
            return
        }

        let isFirstLocation = lastKnownLocation == nil
        lastKnownLocation = loc
        print("📍 Ubicación actualizada: lat=\(loc.coordinate.latitude), lon=\(loc.coordinate.longitude) (accuracy: \(loc.horizontalAccuracy)m)")

        if isFirstLocation {
            print("✨ Primera ubicación obtenida - re-registrando geovallas ordenadas por distancia")
        }

        if autoCheckinEnabled {
            // Verificar dwells pendientes por si los timers no funcionaron
            checkPendingDwells()

            // Reprioriza por cercanía con esta ubicación
            print("🔄 Re-priorizando geovallas con nueva ubicación...")
            registerGeofences()
            // Y pide estado por si ya estás dentro de alguna recién activada
            for region in manager.monitoredRegions {
                manager.requestState(for: region)
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let clError = error as? CLError
        print("❌ Error ubicación: \(error.localizedDescription)")
        print("   Código: \(clError?.code.rawValue ?? -1)")
        if clError?.code == .locationUnknown {
            print("   → Ubicación aún no disponible, Core Location seguirá intentando")
        }
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

        // CRÍTICO: Verificar dwells pendientes en cada evento
        // Esto permite que el auto check-in funcione incluso si la app estaba suspendida
        checkPendingDwells()

        switch state {
        case .inside:
            // Siempre intentar startDwell, que internamente verificará si debe proceder
            print("✅ Usuario DENTRO de \(campo.nombre) - verificando/iniciando dwell")
            startDwell(for: campo)

        case .outside:
            print("🚪 Usuario FUERA de \(campo.nombre) - cancelando dwell")
            cancelDwell(for: campo)

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

        // Verificar dwells pendientes por si acaso
        checkPendingDwells()

        // Iniciar dwell (la función verificará internamente si debe proceder)
        startDwell(for: campo)
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let campo = campo(for: region.identifier) else {
            print("⚠️ Campo no encontrado para región \(region.identifier)")
            return
        }
        print("🚶‍♂️ didExitRegion: Usuario SALIÓ de \(campo.nombre)")

        // Cancelar dwell (verificará si cumplió el tiempo antes de limpiar)
        cancelDwell(for: campo)
    }
}
