import CarPlay
import MapKit
import Combine
import Supabase

/// Manager para gestionar toda la lógica de CarPlay.
/// Usa CPPointOfInterestTemplate para mostrar campos en un mapa sin necesitar el entitlement de Navigation.
class CarPlayManager: NSObject {

    // MARK: - Properties

    private let interfaceController: CPInterfaceController
    private var poiTemplate: CPPointOfInterestTemplate?
    private lazy var supabaseClient: SupabaseClient = supabase
    private var cancellables = Set<AnyCancellable>()
    private var locationManager: CLLocationManager

    // Data
    private var allCampos: [CampoModel] = []
    private var camposByProvincia: [(provincia: String, campos: [CampoModel])] = []
    private var currentSearchResults: [CampoModel] = []
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

        let poiTemplate = CPPointOfInterestTemplate(title: "Campos de Galicia",
                                                     pointsOfInterest: [],
                                                     selectedIndex: NSNotFound)
        poiTemplate.pointOfInterestDelegate = self
        poiTemplate.leadingNavigationBarButtons = [
            CPBarButton(title: "Buscar") { [weak self] _ in
                self?.showSearchInterface()
            }
        ]
        poiTemplate.trailingNavigationBarButtons = [
            CPBarButton(title: "Lista") { [weak self] _ in
                self?.showProvinciasMenu()
            }
        ]
        self.poiTemplate = poiTemplate

        interfaceController.setRootTemplate(poiTemplate, animated: true) { _, error in
            if let error = error {
                Logger.debug("❌ Error: \(error.localizedDescription)")
            } else {
                Logger.debug("✅ CPPointOfInterestTemplate establecido")
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

    // MARK: - POI Management

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

    // MARK: - Lista: Provincia -> Localidad -> Campos (tres niveles)

    /// Nivel 1: lista de provincias
    private func showProvinciasMenu() {
        Logger.debug("📋 Mostrando provincias")

        guard !camposByProvincia.isEmpty else { return }

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
        let listTemplate = CPListTemplate(title: "Provincias", sections: [section])

        interfaceController.pushTemplate(listTemplate, animated: true)
    }

    /// Nivel 2: localidades de una provincia (con paginación)
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
        let title: String
        if totalPages > 1 {
            title = "\(provincia) (\(page + 1)/\(totalPages))"
        } else {
            title = "\(provincia)"
        }

        let section = CPListSection(items: items)
        let listTemplate = CPListTemplate(title: title, sections: [section])

        interfaceController.pushTemplate(listTemplate, animated: true)
    }

    /// Nivel 3: campos de una localidad (con paginación por seguridad)
    private func showCamposForLocalidad(_ localidad: String, campos: [CampoModel], page: Int = 0) {
        let maxItems = CPListTemplate.maximumItemCount
        let pageSize = max(maxItems - 1, 1)
        let startIndex = page * pageSize
        let endIndex = min(startIndex + pageSize, campos.count)
        let pageCampos = Array(campos[startIndex..<endIndex])
        let hasMore = endIndex < campos.count

        var items = pageCampos.map { campo -> CPListItem in
            let item = CPListItem(
                text: campo.nombre,
                detailText: campo.direccion
            )

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
        let title: String
        if totalPages > 1 {
            title = "\(localidad) (\(page + 1)/\(totalPages))"
        } else {
            title = "\(localidad) (\(campos.count))"
        }

        let section = CPListSection(items: items)
        let listTemplate = CPListTemplate(title: title, sections: [section])

        interfaceController.pushTemplate(listTemplate, animated: true)
    }

    // MARK: - Búsqueda

    private func showSearchInterface() {
        currentSearchResults = []
        let searchTemplate = CPSearchTemplate()
        searchTemplate.delegate = self
        interfaceController.pushTemplate(searchTemplate, animated: true)
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
            let distance = distanceString(to: campo)
            items.append(CPInformationItem(title: "Distancia", detail: distance))
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
              let lon = campo.longitud else {
            return "—"
        }

        let campoLocation = CLLocation(latitude: lat, longitude: lon)
        let distance = userLocation.distance(from: campoLocation)

        if distance < 1000 {
            return String(format: "%.0f m", distance)
        } else {
            return String(format: "%.1f km", distance / 1000)
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

// MARK: - CPSearchTemplateDelegate

extension CarPlayManager: CPSearchTemplateDelegate {
    func searchTemplate(_ searchTemplate: CPSearchTemplate, updatedSearchText searchText: String, completionHandler: @escaping ([CPListItem]) -> Void) {
        guard !searchText.isEmpty else {
            currentSearchResults = []
            completionHandler([])
            return
        }

        let filtered = allCampos.filter { campo in
            campo.nombre.localizedCaseInsensitiveContains(searchText) ||
            campo.localidad.localizedCaseInsensitiveContains(searchText) ||
            campo.provincia.localizedCaseInsensitiveContains(searchText)
        }

        currentSearchResults = Array(filtered.prefix(12))

        let items = currentSearchResults.map { campo -> CPListItem in
            CPListItem(
                text: campo.nombre,
                detailText: "\(campo.localidad), \(campo.provincia)"
            )
        }

        completionHandler(items)
    }

    func searchTemplate(_ searchTemplate: CPSearchTemplate, selectedResult item: CPListItem, completionHandler: @escaping () -> Void) {
        guard let text = item.text,
              let campo = currentSearchResults.first(where: { $0.nombre == text }) else {
            completionHandler()
            return
        }

        Logger.debug("🔍 Resultado seleccionado: \(campo.nombre)")

        interfaceController.popTemplate(animated: true) { [weak self] _, _ in
            self?.showCampoDetails(campo)
        }

        completionHandler()
    }
}

// MARK: - CLLocationManagerDelegate

extension CarPlayManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Actualizar POIs cuando hay nueva ubicación (solo la primera vez)
        if !allCampos.isEmpty && !poisCampos.isEmpty {
            // Ya tenemos POIs, no hace falta actualizar continuamente
        } else if !allCampos.isEmpty {
            updatePOIs()
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }
}
