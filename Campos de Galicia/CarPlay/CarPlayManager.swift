import CarPlay
import MapKit
import Combine
import Supabase

/// Manager para gestionar toda la lógica de CarPlay.
/// Arquitectura simplificada: Root → Provincias → Campos (con paginación) → Detalles
/// Máx 4 niveles de profundidad (límite de CarPlay es 5)
class CarPlayManager: NSObject {

    // MARK: - Properties

    private let interfaceController: CPInterfaceController
    private var rootListTemplate: CPListTemplate?
    private lazy var supabaseClient: SupabaseClient = supabase
    private var locationManager: CLLocationManager

    // Data
    private var allCampos: [CampoModel] = []
    private var camposByProvincia: [(provincia: String, campos: [CampoModel])] = []
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
        Logger.debug("🚗 Configurando interfaz de CarPlay")

        // Placeholder mientras cargan los datos
        let loadingItem = CPListItem(text: "Cargando campos...", detailText: nil)
        let loadingSection = CPListSection(items: [loadingItem])
        let listTemplate = CPListTemplate(title: "Campos de Galicia", sections: [loadingSection])

        // ✅ Botón "Buscar" - el más importante según usuario
        listTemplate.trailingNavigationBarButtons = [
            CPBarButton(title: "Buscar") { [weak self] _ in
                self?.showAllCamposAlphabetical()
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
                    self.buildProvinciaGroups()
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

    private func buildProvinciaGroups() {
        let grouped = Dictionary(grouping: allCampos) { $0.provincia }
        camposByProvincia = grouped
            .sorted { $0.key < $1.key }
            .map { (provincia: $0.key, campos: $0.value.sorted { $0.nombre < $1.nombre }) }
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

        // Sección de navegación principal (Buscar ahora está en el botón de la barra)
        var navigationItems: [CPListItem] = []

        let provinciasItem = CPListItem(text: "Ver por provincias", detailText: "4 provincias")
        provinciasItem.accessoryType = .disclosureIndicator
        provinciasItem.handler = { [weak self] (_: CPSelectableListItem, completion: @escaping () -> Void) in
            self?.showProvinciasMenu()
            completion()
        }
        navigationItems.append(provinciasItem)

        sections.append(CPListSection(items: navigationItems))

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
        }

        rootListTemplate.updateSections(sections)
        Logger.debug("✅ Root list actualizada")
    }

    // MARK: - Lista por provincias

    private func showProvinciasMenu() {
        Logger.debug("📋 Mostrando provincias")
        guard !camposByProvincia.isEmpty else { return }
        let items = camposByProvincia.map { group -> CPListItem in
            let item = CPListItem(text: group.provincia, detailText: "\(group.campos.count) campos")
            item.accessoryType = .disclosureIndicator
            item.handler = { [weak self] (_: CPSelectableListItem, completion: @escaping () -> Void) in
                self?.showCamposForProvincia(group.provincia, campos: group.campos, page: 0)
                completion()
            }
            return item
        }
        let listTemplate = CPListTemplate(title: "Provincias", sections: [CPListSection(items: items)])
        interfaceController.pushTemplate(listTemplate, animated: true)
    }

    // ✅ PAGINACIÓN SEGURA: Ordena alfabéticamente y permite navegar por páginas
    private func showCamposForProvincia(_ provincia: String, campos: [CampoModel], page: Int) {
        Logger.debug("📋 Mostrando campos de \(provincia) - página \(page + 1)")

        // ✅ ORDEN ALFABÉTICO por nombre (no por localidad)
        let sorted = campos.sorted { $0.nombre < $1.nombre }

        let maxItems = CPListTemplate.maximumItemCount
        let pageSize = max(maxItems - 1, 1) // Reservamos 1 para "Más campos..."
        let startIndex = page * pageSize
        let endIndex = min(startIndex + pageSize, sorted.count)
        let pageCampos = Array(sorted[startIndex..<endIndex])
        let hasMore = endIndex < sorted.count

        var items = pageCampos.map { campo -> CPListItem in
            let detail = campo.direccion.isEmpty ? campo.localidad : "\(campo.localidad) · \(campo.direccion)"
            let item = CPListItem(text: campo.nombre, detailText: detail)
            item.handler = { [weak self] (_: CPSelectableListItem, completion: @escaping () -> Void) in
                self?.showCampoDetails(campo)
                completion()
            }
            return item
        }

        // ✅ Botón "Más campos..." si hay más páginas
        if hasMore {
            let remaining = sorted.count - endIndex
            let moreItem = CPListItem(text: "Más campos...", detailText: "\(remaining) restantes")
            moreItem.handler = { [weak self] (_: CPSelectableListItem, completion: @escaping () -> Void) in
                // ✅ PAGINACIÓN SEGURA: Pop, luego push en completion (sin DispatchQueue.main.async)
                self?.interfaceController.popTemplate(animated: false) { [weak self] _, _ in
                    self?.showCamposForProvincia(provincia, campos: campos, page: page + 1)
                    completion()
                }
            }
            items.append(moreItem)
        }

        let totalPages = Int(ceil(Double(sorted.count) / Double(pageSize)))
        let title = totalPages > 1 ? "\(provincia) (\(page + 1)/\(totalPages))" : provincia
        let listTemplate = CPListTemplate(title: title, sections: [CPListSection(items: items)])
        interfaceController.pushTemplate(listTemplate, animated: true)
    }

    // MARK: - Buscar (lista alfabética de todos los campos)

    private func showAllCamposAlphabetical() {
        Logger.debug("🔍 Mostrando búsqueda alfabética")
        let sorted = allCampos.sorted { $0.nombre < $1.nombre }
        let grouped = Dictionary(grouping: sorted) { String($0.nombre.prefix(1)).uppercased() }
        let letters = grouped.keys.sorted()

        let maxItems = CPListTemplate.maximumItemCount
        var allItems: [CPListItem] = []

        for letter in letters {
            guard let campos = grouped[letter] else { continue }
            for campo in campos {
                let item = CPListItem(text: campo.nombre, detailText: "\(campo.localidad), \(campo.provincia)")
                item.handler = { [weak self] (_: CPSelectableListItem, completion: @escaping () -> Void) in
                    self?.showCampoDetails(campo)
                    completion()
                }
                allItems.append(item)
                if allItems.count >= maxItems { break }
            }
            if allItems.count >= maxItems { break }
        }

        let section = CPListSection(items: allItems)
        let listTemplate = CPListTemplate(title: "Todos los campos", sections: [section])
        interfaceController.pushTemplate(listTemplate, animated: true)
    }

    // MARK: - Detalle del Campo (usando CPListTemplate en lugar de CPInformationTemplate)

    private func showCampoDetails(_ campo: CampoModel) {
        Logger.debug("📍 Detalles de: \(campo.nombre)")

        var items: [CPListItem] = []

        // Información del campo como items de lista (más robusto que CPInformationTemplate)
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

        // Botón de navegación como último item
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
        guard let lat = campo.latitud, let lon = campo.longitud else { return }
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
        // Solo actualizar la lista si cambia el resultado (evitar refrescos constantes)
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
