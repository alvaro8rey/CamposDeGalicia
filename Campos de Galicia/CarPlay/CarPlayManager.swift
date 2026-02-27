import CarPlay
import MapKit
import Combine
import Supabase

/// Manager para gestionar toda la lógica de CarPlay.
/// ✅ SIMPLE: Pantalla principal (cercanos) + botón "Todos" (lista completa)
class CarPlayManager: NSObject {

    // MARK: - Properties

    private let interfaceController: CPInterfaceController
    private var rootListTemplate: CPListTemplate?
    private lazy var supabaseClient: SupabaseClient = supabase
    private var locationManager: CLLocationManager

    // Data
    private var allCampos: [CampoModel] = []
    private var visitedCampoIds: Set<UUID> = []
    private var nearestCampos: [CampoModel] = []

    // MARK: - Initialization

    init(interfaceController: CPInterfaceController) {
        Logger.debug("🚗 CarPlayManager inicializado")
        self.interfaceController = interfaceController
        self.locationManager = CLLocationManager()
        super.init()
        setupLocationManager()
        Logger.debug("✅ CarPlayManager inicialización completa")
    }

    // MARK: - Setup

    func setupInterface() {
        Logger.debug("🚗 Configurando interfaz de CarPlay (SIMPLE)")

        // Placeholder mientras cargan los datos
        let loadingItem = CPListItem(text: "Cargando campos...", detailText: nil)
        let loadingSection = CPListSection(items: [loadingItem])
        let listTemplate = CPListTemplate(title: "Campos de Galicia", sections: [loadingSection])

        // ✅ Botón "Todos" - lista completa de campos con paginación
        listTemplate.trailingNavigationBarButtons = [
            CPBarButton(title: "Todos") { [weak self] _ in
                self?.showAllCamposWithPagination(offset: 0)
            }
        ]

        self.rootListTemplate = listTemplate

        interfaceController.setRootTemplate(listTemplate, animated: true) { _, error in
            if let error = error {
                Logger.debug("❌ Error al establecer root template: \(error.localizedDescription)")
            } else {
                Logger.debug("✅ CPListTemplate establecido como root")
            }
        }

        loadAllCampos()
    }

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    // MARK: - Data Loading

    private func loadAllCampos() {
        Task {
            do {
                async let camposRequest: [CampoModel] = supabaseClient
                    .from("campos")
                    .select()
                    .execute()
                    .value
                async let visitasRequest = loadVisitedCampoIds()

                let response = try await camposRequest
                _ = await visitasRequest

                await MainActor.run {
                    self.allCampos = response
                    self.updateNearestCampos()
                    self.updateRootList()
                }

                Logger.debug("✅ Cargados \(response.count) campos, \(self.visitedCampoIds.count) visitados")
            } catch {
                Logger.debug("❌ Error al cargar campos: \(error)")
            }
        }
    }

    private func loadVisitedCampoIds() async {
        guard let userId = supabaseClient.auth.currentUser?.id.uuidString else { return }
        do {
            let response = try await supabaseClient.from("visitas")
                .select("id_campo")
                .eq("id_usuario", value: userId)
                .execute()
            if let jsonData = try? JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] {
                let ids = jsonData.compactMap { dict -> UUID? in
                    guard let idString = dict["id_campo"] as? String else { return nil }
                    return UUID(uuidString: idString)
                }
                visitedCampoIds = Set(ids)
            }
        } catch {
            Logger.debug("⚠️ Error al cargar visitas: \(error)")
        }
    }

    // MARK: - Nearest Campos

    private func updateNearestCampos() {
        var sorted = allCampos.filter { $0.latitud != nil && $0.longitud != nil }
        if let userLocation = locationManager.location {
            sorted.sort {
                guard let lat1 = $0.latitud, let lon1 = $0.longitud,
                      let lat2 = $1.latitud, let lon2 = $1.longitud else { return false }
                let d1 = userLocation.distance(from: CLLocation(latitude: lat1, longitude: lon1))
                let d2 = userLocation.distance(from: CLLocation(latitude: lat2, longitude: lon2))
                return d1 < d2
            }
        }
        nearestCampos = Array(sorted.prefix(5))
    }

    // MARK: - Root List

    private func updateRootList() {
        guard let rootListTemplate = self.rootListTemplate else { return }
        var sections: [CPListSection] = []

        // Sección "Cerca de mí"
        if !nearestCampos.isEmpty {
            let nearbyItems = nearestCampos.map { campo -> CPListItem in
                let distancia = distanceString(to: campo)
                let detail = distancia == "—"
                    ? campo.localidad
                    : "\(distancia) · \(campo.localidad)"
                let item = CPListItem(text: campo.nombre, detailText: detail)
                item.handler = { [weak self] (_: CPSelectableListItem, completion: @escaping () -> Void) in
                    self?.showCampoDetails(campo)
                    completion()
                }
                return item
            }
            sections.append(CPListSection(items: nearbyItems, header: "Cerca de mí", sectionIndexTitle: nil))
        } else {
            let emptyItem = CPListItem(text: "Activando ubicación...", detailText: "Espera un momento")
            sections.append(CPListSection(items: [emptyItem]))
        }

        rootListTemplate.updateSections(sections)
        Logger.debug("✅ Root list actualizada con \(nearestCampos.count) campos cercanos")
    }

    // MARK: - Todos los campos (con paginación simple)

    private func showAllCamposWithPagination(offset: Int) {
        Logger.debug("📋 Mostrando todos los campos - offset: \(offset)")

        let sorted = allCampos.sorted { $0.nombre < $1.nombre }
        let pageSize = 8
        let start = offset
        let end = min(offset + pageSize, sorted.count)
        let camposPagina = Array(sorted[start..<end])

        var items = camposPagina.map { campo -> CPListItem in
            let item = CPListItem(text: campo.nombre, detailText: "\(campo.localidad), \(campo.provincia)")
            item.handler = { [weak self] (_: CPSelectableListItem, completion: @escaping () -> Void) in
                self?.showCampoDetails(campo)
                completion()
            }
            return item
        }

        // Botón "Ver más" si hay más campos
        if end < sorted.count {
            let remaining = sorted.count - end
            let moreItem = CPListItem(text: "Ver más campos...", detailText: "\(remaining) restantes")
            moreItem.handler = { [weak self] (_: CPSelectableListItem, completion: @escaping () -> Void) in
                // ✅ Hacer pop ANTES de pushear nueva página (evita acumulación)
                self?.interfaceController.popTemplate(animated: false) { [weak self] _, _ in
                    self?.showAllCamposWithPagination(offset: end)
                }
                completion()
            }
            items.append(moreItem)
        }

        let totalPages = Int(ceil(Double(sorted.count) / Double(pageSize)))
        let currentPage = (offset / pageSize) + 1
        let title = "Todos los campos (\(currentPage)/\(totalPages))"
        let listTemplate = CPListTemplate(title: title, sections: [CPListSection(items: items)])
        interfaceController.pushTemplate(listTemplate, animated: true)
        Logger.debug("✅ Mostrando \(items.count) items (offset: \(offset), total: \(sorted.count))")
    }

    // MARK: - Detalle del Campo

    private func showCampoDetails(_ campo: CampoModel) {
        Logger.debug("📍 Detalles de: \(campo.nombre)")

        var items: [CPListItem] = []

        // Información del campo
        if !campo.direccion.isEmpty {
            let item = CPListItem(text: "Dirección", detailText: campo.direccion)
            items.append(item)
        }

        let localidadItem = CPListItem(text: "Localidad", detailText: "\(campo.localidad), \(campo.provincia)")
        items.append(localidadItem)

        if !campo.codigo_postal.isEmpty {
            let item = CPListItem(text: "Código Postal", detailText: campo.codigo_postal)
            items.append(item)
        }

        if !campo.tipo.isEmpty {
            let item = CPListItem(text: "Tipo", detailText: campo.tipo)
            items.append(item)
        }

        if !campo.superficie.isEmpty {
            let item = CPListItem(text: "Superficie", detailText: campo.superficie)
            items.append(item)
        }

        if let cantina = campo.tiene_cantina {
            let item = CPListItem(text: "Cantina", detailText: cantina ? "Sí" : "No")
            items.append(item)
        }

        if let parking = campo.parking {
            let item = CPListItem(text: "Parking", detailText: parking ? "Sí" : "No")
            items.append(item)
        }

        if let estado = campo.estado_cesped, !estado.isEmpty {
            let item = CPListItem(text: "Césped", detailText: estado)
            items.append(item)
        }

        if let medidas = campo.medidas_campo, !medidas.isEmpty {
            let item = CPListItem(text: "Medidas", detailText: medidas)
            items.append(item)
        }

        let distanciaItem = CPListItem(text: "Distancia", detailText: distanceString(to: campo))
        items.append(distanciaItem)

        // Botón de navegación
        let navigateItem = CPListItem(text: "🧭 Navegar", detailText: "Abrir en Maps")
        navigateItem.handler = { [weak self] (_: CPSelectableListItem, completion: @escaping () -> Void) in
            self?.startNavigation(to: campo)
            completion()
        }
        items.append(navigateItem)

        let listTemplate = CPListTemplate(title: campo.nombre, sections: [CPListSection(items: items)])
        interfaceController.pushTemplate(listTemplate, animated: true)
    }

    // MARK: - Navegación

    private func startNavigation(to campo: CampoModel) {
        guard let lat = campo.latitud, let lon = campo.longitud else {
            Logger.debug("⚠️ Campo sin coordenadas")
            return
        }
        Logger.debug("🧭 Navegando a: \(campo.nombre)")

        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = campo.nombre

        DispatchQueue.main.async {
            MKMapItem.openMaps(with: [mapItem], launchOptions: [
                MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
            ])
        }
    }

    // MARK: - Helpers

    private func distanceString(to campo: CampoModel) -> String {
        guard let userLocation = locationManager.location,
              let lat = campo.latitud,
              let lon = campo.longitud else { return "—" }
        let distance = userLocation.distance(from: CLLocation(latitude: lat, longitude: lon))
        return distance < 1000
            ? String(format: "%.0f m", distance)
            : String(format: "%.1f km", distance / 1000)
    }
}

// MARK: - CLLocationManagerDelegate

extension CarPlayManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard !allCampos.isEmpty else { return }
        let previousCount = nearestCampos.count
        updateNearestCampos()
        if nearestCampos.count != previousCount {
            updateRootList()
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }
}
