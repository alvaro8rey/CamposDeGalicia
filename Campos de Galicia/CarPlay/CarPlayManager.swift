import CarPlay
import MapKit
import Combine
import Supabase

/// Manager para gestionar toda la lógica de CarPlay.
/// Compatible con el entitlement com.apple.developer.carplay-driving-task.
/// Arquitectura: CPListTemplate como root con sección "Cerca de mí" y botones Buscar/Lista.
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
        listTemplate.leadingNavigationBarButtons = [
            CPBarButton(title: "Buscar") { [weak self] _ in
                guard let self = self else { return }
                self.interfaceController.popToRootTemplate(animated: false) { [weak self] _, _ in
                    self?.showAllCamposAlphabetical()
                }
            }
        ]
        listTemplate.trailingNavigationBarButtons = [
            CPBarButton(title: "Lista") { [weak self] _ in
                guard let self = self else { return }
                self.interfaceController.popToRootTemplate(animated: false) { [weak self] _, _ in
                    self?.showProvinciasMenu()
                }
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

    // MARK: - Root List (Cerca de mí)

    private func updateRootList() {
        guard let rootListTemplate = self.rootListTemplate else { return }
        var sections: [CPListSection] = []

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
                self?.showLocalidadesForProvincia(group.provincia, campos: group.campos)
                completion()
            }
            return item
        }
        let listTemplate = CPListTemplate(title: "Provincias", sections: [CPListSection(items: items)])
        interfaceController.pushTemplate(listTemplate, animated: true)
    }

    // MARK: - Lista: Provincia -> Localidad -> Campos

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

        var items = pageLocalidades.map { group -> CPListItem in
            let item = CPListItem(
                text: group.localidad,
                detailText: group.campos.count == 1 ? group.campos[0].nombre : "\(group.campos.count) campos"
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
        let listTemplate = CPListTemplate(title: title, sections: [CPListSection(items: items)])
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
        let listTemplate = CPListTemplate(title: title, sections: [CPListSection(items: items)])
        interfaceController.pushTemplate(listTemplate, animated: true)
    }

    // MARK: - Buscar (lista alfabética de todos los campos)

    private func showAllCamposAlphabetical() {
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
        items.append(CPInformationItem(title: "Distancia", detail: distanceString(to: campo)))

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
