import CarPlay
import MapKit
import Combine
import Supabase

/// Manager para gestionar toda la lógica de CarPlay.
/// Usa CPTabBarTemplate como root con CPPointOfInterestTemplate (mapa) y CPListTemplate (lista).
/// Compatible con el entitlement com.apple.developer.carplay-driving-task.
class CarPlayManager: NSObject {

    // MARK: - Properties

    private let interfaceController: CPInterfaceController
    private var poiTemplate: CPPointOfInterestTemplate?
    private var rootListTemplate: CPListTemplate?
    private lazy var supabaseClient: SupabaseClient = supabase
    private var cancellables = Set<AnyCancellable>()
    private var locationManager: CLLocationManager

    // Data
    private var allCampos: [CampoModel] = []
    private var camposByProvincia: [(provincia: String, campos: [CampoModel])] = []
    private var visitedCampoIds: Set<UUID> = []
    private var poisCampos: [CampoModel] = []

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
        Logger.debug("🚗 Configurando interfaz de CarPlay")

        // Tab 1: Mapa con POIs cercanos
        let poiTemplate = CPPointOfInterestTemplate(title: "Cerca de ti",
                                                     pointsOfInterest: [],
                                                     selectedIndex: NSNotFound)
        poiTemplate.pointOfInterestDelegate = self
        poiTemplate.tabTitle = "Mapa"
        poiTemplate.tabImage = UIImage(systemName: "map.fill")
        self.poiTemplate = poiTemplate

        // Tab 2: Lista por provincias (placeholder mientras carga)
        let loadingItem = CPListItem(text: "Cargando campos...", detailText: nil)
        let loadingSection = CPListSection(items: [loadingItem])
        let listTemplate = CPListTemplate(title: "Campos de Galicia", sections: [loadingSection])
        listTemplate.tabTitle = "Lista"
        listTemplate.tabImage = UIImage(systemName: "list.bullet")
        self.rootListTemplate = listTemplate

        // Root: TabBar con las dos pestañas
        let tabBar = CPTabBarTemplate(templates: [poiTemplate, listTemplate])
        tabBar.delegate = self

        interfaceController.setRootTemplate(tabBar, animated: true) { _, error in
            if let error = error {
                Logger.debug("❌ Error al establecer root template: \(error.localizedDescription)")
            } else {
                Logger.debug("✅ CPTabBarTemplate establecido correctamente")
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
                    self.buildProvinciaGroups()
                    self.updatePOIs()
                    self.updateRootList()
                }

                Logger.debug("✅ Cargados \(response.count) campos, \(self.visitedCampoIds.count) visitados")
            } catch {
                Logger.debug("❌ Error al cargar campos: \(error)")
            }
        }
    }

    private func loadVisitedCampoIds() async {
        guard let userId = supabaseClient.auth.currentUser?.id.uuidString else {
            Logger.debug("⚠️ No hay usuario autenticado para cargar visitas")
            return
        }

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

    private func buildProvinciaGroups() {
        let grouped = Dictionary(grouping: allCampos) { $0.provincia }
        camposByProvincia = grouped
            .sorted { $0.key < $1.key }
            .map { (provincia: $0.key, campos: $0.value.sorted { $0.nombre < $1.nombre }) }
    }

    // MARK: - POI Management (Tab Mapa)

    private func updatePOIs() {
        guard let poiTemplate = self.poiTemplate else { return }

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

        let nearest = Array(sorted.prefix(12))
        poisCampos = nearest

        let pois = nearest.compactMap { campo -> CPPointOfInterest? in
            guard let lat = campo.latitud, let lon = campo.longitud else { return nil }
            let mapItem = MKMapItem(placemark: MKPlacemark(
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)
            ))
            mapItem.name = campo.nombre
            return CPPointOfInterest(
                location: mapItem,
                title: campo.nombre,
                subtitle: campo.localidad,
                summary: campo.provincia,
                detailTitle: campo.nombre,
                detailSubtitle: "\(campo.localidad), \(campo.provincia)",
                detailSummary: campo.direccion.isEmpty ? nil : campo.direccion,
                pinImage: nil
            )
        }

        poiTemplate.setPointsOfInterest(pois, selectedIndex: NSNotFound)
        Logger.debug("✅ \(pois.count) POIs actualizados en el mapa")
    }

    // MARK: - Lista Root (Tab Lista)

    private func updateRootList() {
        guard let rootListTemplate = self.rootListTemplate,
              !camposByProvincia.isEmpty else { return }

        let items = camposByProvincia.map { group -> CPListItem in
            let item = CPListItem(
                text: group.provincia,
                detailText: "\(group.campos.count) campos"
            )
            item.accessoryType = .disclosureIndicator
            item.handler = { [weak self] (_: CPSelectableListItem, completion: @escaping () -> Void) in
                self?.showLocalidadesForProvincia(group.provincia, campos: group.campos)
                completion()
            }
            return item
        }

        let section = CPListSection(items: items)
        rootListTemplate.updateSections([section])
        Logger.debug("✅ Lista raíz actualizada con \(camposByProvincia.count) provincias")
    }

    // MARK: - Lista: Provincia -> Localidad -> Campos (tres niveles)

    private func showLocalidadesForProvincia(_ provincia: String, campos: [CampoModel], page: Int = 0) {
        let grouped = Dictionary(grouping: campos) { $0.localidad }
        let localidades = grouped
            .sorted { $0.key < $1.key }
            .map { (localidad: $0.key, campos: $0.value.sorted { $0.nombre < $1.nombre }) }

        let maxItems = CPListTemplate.maximumItemCount
        let pageSize = max(maxItems - 1, 1)
        let startIndex = page * pageSize
        let endIndex = min(startIndex + pageSize, localidades.count)
        let pageLocalidades = Array(localidades[startIndex..<endIndex])
        let hasMore = endIndex < localidades.count

        Logger.debug("📋 \(provincia) localidades pág \(page + 1): \(startIndex)-\(endIndex) de \(localidades.count)")

        var items = pageLocalidades.map { group -> CPListItem in
            let item = CPListItem(
                text: group.localidad,
                detailText: group.campos.count == 1
                    ? group.campos[0].nombre
                    : "\(group.campos.count) campos"
            )
            item.accessoryType = .disclosureIndicator
            item.handler = { [weak self] (_: CPSelectableListItem, completion: @escaping () -> Void) in
                if group.campos.count == 1 {
                    self?.showCampoDetails(group.campos[0])
                } else {
                    self?.showCamposForLocalidad(group.localidad, campos: group.campos)
                }
                completion()
            }
            return item
        }

        if hasMore {
            let remaining = localidades.count - endIndex
            let moreItem = CPListItem(text: "Más localidades...", detailText: "\(remaining) restantes")
            moreItem.handler = { [weak self] (_: CPSelectableListItem, completion: @escaping () -> Void) in
                self?.interfaceController.popTemplate(animated: false) { _, _ in
                    self?.showLocalidadesForProvincia(provincia, campos: campos, page: page + 1)
                }
                completion()
            }
            items.append(moreItem)
        }

        let totalPages = Int(ceil(Double(localidades.count) / Double(pageSize)))
        let title = totalPages > 1 ? "\(provincia) (\(page + 1)/\(totalPages))" : provincia

        let section = CPListSection(items: items)
        let listTemplate = CPListTemplate(title: title, sections: [section])
        interfaceController.pushTemplate(listTemplate, animated: true)
    }

    private func showCamposForLocalidad(_ localidad: String, campos: [CampoModel], page: Int = 0) {
        let maxItems = CPListTemplate.maximumItemCount
        let pageSize = max(maxItems - 1, 1)
        let startIndex = page * pageSize
        let endIndex = min(startIndex + pageSize, campos.count)
        let pageCampos = Array(campos[startIndex..<endIndex])
        let hasMore = endIndex < campos.count

        var items = pageCampos.map { campo -> CPListItem in
            let item = CPListItem(text: campo.nombre, detailText: campo.direccion)
            item.handler = { [weak self] (_: CPSelectableListItem, completion: @escaping () -> Void) in
                self?.showCampoDetails(campo)
                completion()
            }
            return item
        }

        if hasMore {
            let remaining = campos.count - endIndex
            let moreItem = CPListItem(text: "Más campos...", detailText: "\(remaining) restantes")
            moreItem.handler = { [weak self] (_: CPSelectableListItem, completion: @escaping () -> Void) in
                self?.interfaceController.popTemplate(animated: false) { _, _ in
                    self?.showCamposForLocalidad(localidad, campos: campos, page: page + 1)
                }
                completion()
            }
            items.append(moreItem)
        }

        let totalPages = Int(ceil(Double(campos.count) / Double(pageSize)))
        let title = totalPages > 1 ? "\(localidad) (\(page + 1)/\(totalPages))" : "\(localidad) (\(campos.count))"

        let section = CPListSection(items: items)
        let listTemplate = CPListTemplate(title: title, sections: [section])
        interfaceController.pushTemplate(listTemplate, animated: true)
    }

    // MARK: - Navegación

    private func startNavigation(to campo: CampoModel) {
        guard let lat = campo.latitud, let lon = campo.longitud else { return }

        Logger.debug("🧭 Navegando a: \(campo.nombre)")

        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = campo.nombre

        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])

        AnalyticsManager.shared.trackCustom(
            name: "carplay_navigation_started",
            category: .navigation,
            parameters: ["campo_id": campo.id.uuidString, "campo_name": campo.nombre]
        )
    }

    // MARK: - Detalle del Campo

    private func showCampoDetails(_ campo: CampoModel) {
        Logger.debug("📍 Detalles de: \(campo.nombre)")

        var items: [CPInformationItem] = []

        if !campo.direccion.isEmpty {
            items.append(CPInformationItem(title: "Dirección", detail: campo.direccion))
        }
        items.append(CPInformationItem(title: "Localidad", detail: "\(campo.localidad), \(campo.provincia)"))

        if !campo.codigo_postal.isEmpty {
            items.append(CPInformationItem(title: "Código Postal", detail: campo.codigo_postal))
        }
        if !campo.tipo.isEmpty {
            items.append(CPInformationItem(title: "Tipo", detail: campo.tipo))
        }
        if !campo.superficie.isEmpty {
            items.append(CPInformationItem(title: "Superficie", detail: campo.superficie))
        }
        if let cantina = campo.tiene_cantina {
            items.append(CPInformationItem(title: "Cantina", detail: cantina ? "Sí" : "No"))
        }
        if let parking = campo.parking {
            items.append(CPInformationItem(title: "Parking", detail: parking ? "Sí" : "No"))
        }
        if let estado = campo.estado_cesped, !estado.isEmpty {
            items.append(CPInformationItem(title: "Césped", detail: estado))
        }
        if let medidas = campo.medidas_campo, !medidas.isEmpty {
            items.append(CPInformationItem(title: "Medidas", detail: medidas))
        }
        if items.count < 10 {
            items.append(CPInformationItem(title: "Distancia", detail: distanceString(to: campo)))
        }

        let navigateButton = CPTextButton(title: "Navegar", textStyle: .confirm) { [weak self] _ in
            self?.startNavigation(to: campo)
        }

        let infoTemplate = CPInformationTemplate(
            title: campo.nombre,
            layout: .leading,
            items: Array(items.prefix(10)),
            actions: [navigateButton]
        )

        interfaceController.pushTemplate(infoTemplate, animated: true)
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

// MARK: - CPTabBarTemplateDelegate

extension CarPlayManager: CPTabBarTemplateDelegate {
    func tabBarTemplate(_ tabBarTemplate: CPTabBarTemplate, didSelect selectedTemplate: CPTemplate) {
        // Actualizar POIs al volver a la pestaña del mapa
        if selectedTemplate is CPPointOfInterestTemplate {
            updatePOIs()
        }
    }
}

// MARK: - CPPointOfInterestTemplateDelegate

extension CarPlayManager: CPPointOfInterestTemplateDelegate {
    func pointOfInterestTemplate(_ pointOfInterestTemplate: CPPointOfInterestTemplate,
                                  didSelectPointOfInterest pointOfInterest: CPPointOfInterest) {
        guard let campo = poisCampos.first(where: { $0.nombre == pointOfInterest.title }) else { return }
        showCampoDetails(campo)
    }

    func pointOfInterestTemplate(_ pointOfInterestTemplate: CPPointOfInterestTemplate,
                                  didChangeMapRegion region: MKCoordinateRegion) {
        // No acción necesaria al cambiar la región del mapa
    }
}

// MARK: - CLLocationManagerDelegate

extension CarPlayManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if !allCampos.isEmpty {
            updatePOIs()
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }
}
