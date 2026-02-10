import CarPlay
import MapKit
import Combine
import Supabase

/// Manager para gestionar toda la lógica de CarPlay.
/// En CarPlay, toda la interacción es a través de templates.
/// El CPWindow es solo para mostrar contenido visual (mapa).
class CarPlayManager: NSObject {

    // MARK: - Properties

    private let interfaceController: CPInterfaceController
    private weak var window: CPWindow?
    private var mapTemplate: CPMapTemplate?
    private var locationManager: CLLocationManager
    private lazy var supabaseClient: SupabaseClient = supabase
    private var cancellables = Set<AnyCancellable>()
    private weak var mapView: MKMapView?

    // Data
    private var allCampos: [CampoModel] = []
    private var camposByProvincia: [(provincia: String, campos: [CampoModel])] = []
    private var currentSearchResults: [CampoModel] = []
    private var visitedCampoIds: Set<UUID> = []

    // MARK: - Initialization

    init(interfaceController: CPInterfaceController, window: CPWindow?) {
        Logger.debug("🚗 CarPlayManager inicializado")
        self.interfaceController = interfaceController
        self.window = window
        self.locationManager = CLLocationManager()
        super.init()

        setupLocationManager()
        Logger.debug("✅ CarPlayManager inicialización completa")
    }

    // MARK: - Map Setup

    private func createMapView() {
        guard let window = window else {
            Logger.debug("⚠️ CPWindow es nil")
            return
        }

        let mapView = MKMapView(frame: window.bounds)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.mapView = mapView

        let mapVC = UIViewController()
        mapVC.overrideUserInterfaceStyle = .dark
        mapVC.view = mapView
        window.rootViewController = mapVC

        Logger.debug("✅ MKMapView creado a pantalla completa")
    }

    // MARK: - Setup

    func setupInterface() {
        Logger.debug("🚗 Configurando interfaz de CarPlay")

        createMapView()

        let mapTemplate = CPMapTemplate()
        mapTemplate.mapDelegate = self
        mapTemplate.automaticallyHidesNavigationBar = false
        self.mapTemplate = mapTemplate

        setupMapButtons(for: mapTemplate)

        interfaceController.setRootTemplate(mapTemplate, animated: true) { [weak self] success, error in
            if let error = error {
                Logger.debug("❌ Error: \(error.localizedDescription)")
            } else {
                Logger.debug("✅ Template de CarPlay establecido")
                self?.configureMapView()
            }
        }

        loadAllCampos()
    }

    private func configureMapView() {
        guard let mapView = self.mapView else { return }

        mapView.delegate = self
        mapView.showsUserLocation = true
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.overrideUserInterfaceStyle = .dark
        mapView.pointOfInterestFilter = .excludingAll

        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 42.8782, longitude: -8.5448),
            span: MKCoordinateSpan(latitudeDelta: 2.5, longitudeDelta: 2.5)
        )
        mapView.setRegion(region, animated: false)
        Logger.debug("✅ MKMapView configurado")
    }

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    private func setupMapButtons(for mapTemplate: CPMapTemplate) {
        // Zoom in
        let zoomInButton = CPMapButton { [weak self] _ in
            self?.zoomIn()
        }
        zoomInButton.image = UIImage(systemName: "plus")

        // Zoom out
        let zoomOutButton = CPMapButton { [weak self] _ in
            self?.zoomOut()
        }
        zoomOutButton.image = UIImage(systemName: "minus")

        // Pan (flechas direccionales)
        let panButton = CPMapButton { [weak self] _ in
            guard let template = self?.mapTemplate else { return }
            if template.isPanningInterfaceVisible {
                template.dismissPanningInterface(animated: true)
            } else {
                template.showPanningInterface(animated: true)
            }
        }
        panButton.image = UIImage(systemName: "arrow.up.and.down.and.arrow.left.and.right")

        // Ver toda Galicia
        let galiciaButton = CPMapButton { [weak self] _ in
            guard let mapView = self?.mapView else { return }
            let region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 42.8782, longitude: -8.5448),
                span: MKCoordinateSpan(latitudeDelta: 2.5, longitudeDelta: 2.5)
            )
            mapView.setRegion(region, animated: true)
        }
        galiciaButton.image = UIImage(systemName: "map")

        mapTemplate.mapButtons = [zoomInButton, zoomOutButton, panButton, galiciaButton]

        setDefaultNavBar()
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
                    self.displayAnnotations(campos: response)
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

    // MARK: - Map Annotations

    private func displayAnnotations(campos: [CampoModel]) {
        guard let mapView = self.mapView else { return }

        mapView.removeAnnotations(mapView.annotations)

        var annotations: [CampoAnnotation] = []
        for campo in campos {
            guard let lat = campo.latitud,
                  let lon = campo.longitud,
                  lat >= -90, lat <= 90,
                  lon >= -180, lon <= 180 else { continue }

            let item = MapAnnotationItem(
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                title: campo.nombre,
                subtitle: campo.localidad,
                campo: campo,
                isFromManualCoordinates: false,
                isVisited: visitedCampoIds.contains(campo.id)
            )
            let annotation = CampoAnnotation(annotationItem: item)
            annotations.append(annotation)
        }

        mapView.addAnnotations(annotations)
        Logger.debug("✅ \(annotations.count) anotaciones en el mapa")
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
                    let campo = group.campos[0]
                    self?.centerMapOnCampo(campo)
                    self?.showCampoDetails(campo)
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
                self?.centerMapOnCampo(campo)
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

        let showOnMapButton = CPTextButton(title: "Ver en mapa", textStyle: .normal) { [weak self] _ in
            self?.centerMapOnCampo(campo)
            self?.interfaceController.popToRootTemplate(animated: true)
        }

        let infoTemplate = CPInformationTemplate(
            title: campo.nombre,
            layout: .leading,
            items: Array(items.prefix(10)),
            actions: [navigateButton, showOnMapButton]
        )

        interfaceController.pushTemplate(infoTemplate, animated: true)
    }

    // MARK: - Zoom

    private func zoomIn() {
        guard let mapView = self.mapView else { return }
        var region = mapView.region
        region.span.latitudeDelta = max(region.span.latitudeDelta / 2, 0.002)
        region.span.longitudeDelta = max(region.span.longitudeDelta / 2, 0.002)
        mapView.setRegion(region, animated: true)
    }

    private func zoomOut() {
        guard let mapView = self.mapView else { return }
        var region = mapView.region
        region.span.latitudeDelta = min(region.span.latitudeDelta * 2, 20)
        region.span.longitudeDelta = min(region.span.longitudeDelta * 2, 20)
        mapView.setRegion(region, animated: true)
    }

    // MARK: - Nav Bar (normal vs panning)

    private func setDefaultNavBar() {
        guard let mapTemplate = self.mapTemplate else { return }
        mapTemplate.leadingNavigationBarButtons = [
            CPBarButton(title: "Buscar") { [weak self] _ in
                self?.showSearchInterface()
            }
        ]
        mapTemplate.trailingNavigationBarButtons = [
            CPBarButton(title: "Lista") { [weak self] _ in
                self?.showProvinciasMenu()
            }
        ]
    }

    private func setPanningNavBar() {
        guard let mapTemplate = self.mapTemplate else { return }
        mapTemplate.leadingNavigationBarButtons = [
            CPBarButton(title: "+") { [weak self] _ in
                self?.zoomIn()
            },
            CPBarButton(title: "−") { [weak self] _ in
                self?.zoomOut()
            }
        ]
        mapTemplate.trailingNavigationBarButtons = [
            CPBarButton(title: "Hecho") { [weak self] _ in
                self?.mapTemplate?.dismissPanningInterface(animated: true)
            }
        ]
    }

    // MARK: - Map Control

    private func centerMapOnCampo(_ campo: CampoModel) {
        guard let lat = campo.latitud, let lon = campo.longitud,
              let mapView = self.mapView else { return }

        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        mapView.setRegion(region, animated: true)
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

// MARK: - CPMapTemplateDelegate

extension CarPlayManager: CPMapTemplateDelegate {
    func mapTemplate(_ mapTemplate: CPMapTemplate,
                    selectedPreviewFor trip: CPTrip,
                    using routeChoice: CPRouteChoice) {}

    func mapTemplate(_ mapTemplate: CPMapTemplate, startedTrip trip: CPTrip, using routeChoice: CPRouteChoice) {}

    func mapTemplate(_ mapTemplate: CPMapTemplate, panWith direction: CPMapTemplate.PanDirection) {
        guard let mapView = self.mapView else { return }
        let offset = mapView.region.span.latitudeDelta * 0.2
        var center = mapView.region.center

        if direction.contains(.up) { center.latitude += offset }
        if direction.contains(.down) { center.latitude -= offset }
        if direction.contains(.left) { center.longitude -= offset }
        if direction.contains(.right) { center.longitude += offset }

        mapView.setCenter(center, animated: true)
    }

    func mapTemplate(_ mapTemplate: CPMapTemplate, panBeganWith direction: CPMapTemplate.PanDirection) {}
    func mapTemplate(_ mapTemplate: CPMapTemplate, panEndedWith direction: CPMapTemplate.PanDirection) {}

    func mapTemplateDidShowPanningInterface(_ mapTemplate: CPMapTemplate) {
        Logger.debug("🗺️ Panning activado - mostrando zoom en nav bar")
        setPanningNavBar()
    }

    func mapTemplateDidDismissPanningInterface(_ mapTemplate: CPMapTemplate) {
        Logger.debug("🗺️ Panning desactivado - restaurando nav bar")
        setDefaultNavBar()
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
        // Buscar el campo correspondiente al resultado seleccionado
        guard let text = item.text,
              let campo = currentSearchResults.first(where: { $0.nombre == text }) else {
            completionHandler()
            return
        }

        Logger.debug("🔍 Resultado seleccionado: \(campo.nombre)")

        // Cerrar búsqueda, centrar mapa, mostrar detalle
        interfaceController.popTemplate(animated: true) { [weak self] _, _ in
            self?.centerMapOnCampo(campo)
            self?.showCampoDetails(campo)
        }

        completionHandler()
    }
}

// MARK: - CLLocationManagerDelegate

extension CarPlayManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {}

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }
}

// MARK: - MKMapViewDelegate

extension CarPlayManager: MKMapViewDelegate {

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation { return nil }

        // Cluster
        if let cluster = annotation as? MKClusterAnnotation {
            let id = "CampoCluster"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView
            if view == nil {
                view = MKMarkerAnnotationView(annotation: cluster, reuseIdentifier: id)
            } else {
                view?.annotation = cluster
            }
            view?.markerTintColor = .systemGreen
            view?.glyphText = "\(cluster.memberAnnotations.count)"
            view?.titleVisibility = .hidden
            view?.subtitleVisibility = .hidden
            return view
        }

        // Individual
        let campoAnno = annotation as? CampoAnnotation
        let isVisited = campoAnno?.annotationItem.isVisited ?? false
        let id = isVisited ? "CampoPinVisited" : "CampoPin"

        var view = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView
        if view == nil {
            view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
        } else {
            view?.annotation = annotation
        }

        if isVisited {
            view?.markerTintColor = .systemOrange
            view?.glyphImage = UIImage(systemName: "checkmark.circle.fill")
        } else {
            view?.markerTintColor = .systemGreen
            view?.glyphImage = UIImage(systemName: "sportscourt.fill")
        }
        view?.displayPriority = .defaultLow
        view?.clusteringIdentifier = "campo"
        view?.titleVisibility = .adaptive
        view?.subtitleVisibility = .hidden
        return view
    }
}
