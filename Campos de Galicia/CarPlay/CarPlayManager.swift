import CarPlay
import MapKit
import Combine
import Supabase

/// Manager para gestionar toda la lógica de CarPlay
/// IMPORTANTE: En CarPlay, toda la interacción es a través de templates.
/// El CPWindow es solo para mostrar contenido visual (mapa).
/// Los toques son interceptados por la capa de templates.
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
                Logger.debug("❌ Error al establecer template: \(error.localizedDescription)")
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

        // Centrar en Galicia
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

        // Zoom in
        let zoomInButton = CPMapButton { [weak self] _ in
            guard let mapView = self?.mapView else { return }
            var region = mapView.region
            region.span.latitudeDelta /= 2
            region.span.longitudeDelta /= 2
            mapView.setRegion(region, animated: true)
        }
        zoomInButton.image = UIImage(systemName: "plus.magnifyingglass")

        // Zoom out
        let zoomOutButton = CPMapButton { [weak self] _ in
            guard let mapView = self?.mapView else { return }
            var region = mapView.region
            region.span.latitudeDelta = min(region.span.latitudeDelta * 2, 20)
            region.span.longitudeDelta = min(region.span.longitudeDelta * 2, 20)
            mapView.setRegion(region, animated: true)
        }
        zoomOutButton.image = UIImage(systemName: "minus.magnifyingglass")

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

        mapTemplate.mapButtons = [panButton, zoomInButton, zoomOutButton, galiciaButton]

        // Nav bar: Buscar (izquierda) + Lista (derecha)
        mapTemplate.leadingNavigationBarButtons = [
            CPBarButton(title: "Buscar") { [weak self] _ in
                self?.showSearchInterface()
            }
        ]

        mapTemplate.trailingNavigationBarButtons = [
            CPBarButton(title: "Lista") { [weak self] _ in
                self?.showCamposListByProvincia()
            }
        ]
    }

    // MARK: - Data Loading

    private func loadAllCampos() {
        Task {
            do {
                let response: [CampoModel] = try await supabaseClient
                    .from("campos")
                    .select()
                    .execute()
                    .value

                await MainActor.run {
                    self.allCampos = response
                    self.buildProvinciaGroups()
                    self.displayAnnotations(campos: response)
                }

                Logger.debug("✅ Cargados \(self.allCampos.count) campos")
            } catch {
                Logger.debug("❌ Error al cargar campos: \(error)")
            }
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
                isVisited: false
            )
            let annotation = CampoAnnotation(annotationItem: item)
            annotations.append(annotation)
        }

        mapView.addAnnotations(annotations)
        Logger.debug("✅ \(annotations.count) anotaciones en el mapa")
    }

    // MARK: - Lista por Provincia (CPListTemplate)

    private func showCamposListByProvincia() {
        Logger.debug("📋 Mostrando lista de campos por provincia")

        guard !camposByProvincia.isEmpty else {
            Logger.debug("⚠️ No hay campos para mostrar")
            return
        }

        // Crear secciones por provincia
        let sections = camposByProvincia.map { group -> CPListSection in
            let items = group.campos.map { campo -> CPListItem in
                let distance = distanceString(to: campo)
                let detail = distance != "—" ? "\(campo.localidad) · \(distance)" : campo.localidad
                let item = CPListItem(text: campo.nombre, detailText: detail)

                item.handler = { [weak self] (_: CPSelectableListItem, completion: @escaping () -> Void) in
                    self?.centerMapOnCampo(campo)
                    self?.showCampoDetails(campo)
                    completion()
                }

                return item
            }

            return CPListSection(
                items: items,
                header: "\(group.provincia) (\(group.campos.count))",
                sectionIndexTitle: String(group.provincia.prefix(3))
            )
        }

        let listTemplate = CPListTemplate(title: "Campos de Galicia", sections: sections)

        interfaceController.pushTemplate(listTemplate, animated: true) { success, error in
            if let error = error {
                Logger.debug("❌ Error al mostrar lista: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Búsqueda

    private func showSearchInterface() {
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

        // Info principal
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

        // Extras
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

        // Distancia (si cabe, max 10 items)
        if items.count < 10 {
            let distance = distanceString(to: campo)
            items.append(CPInformationItem(title: "Distancia", detail: distance))
        }

        // Botones
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

    private func centerOnUserLocation() {
        guard let userLocation = locationManager.location,
              let mapView = self.mapView else { return }

        let region = MKCoordinateRegion(
            center: userLocation.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
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
}

// MARK: - CPSearchTemplateDelegate

extension CarPlayManager: CPSearchTemplateDelegate {
    func searchTemplate(_ searchTemplate: CPSearchTemplate, updatedSearchText searchText: String, completionHandler: @escaping ([CPListItem]) -> Void) {
        guard !searchText.isEmpty else {
            completionHandler([])
            return
        }

        let filtered = allCampos.filter { campo in
            campo.nombre.localizedCaseInsensitiveContains(searchText) ||
            campo.localidad.localizedCaseInsensitiveContains(searchText) ||
            campo.provincia.localizedCaseInsensitiveContains(searchText)
        }

        let items = filtered.prefix(12).map { campo -> CPListItem in
            let item = CPListItem(
                text: campo.nombre,
                detailText: "\(campo.localidad), \(campo.provincia)"
            )

            item.handler = { [weak self] (_: CPSelectableListItem, completion: @escaping () -> Void) in
                self?.interfaceController.popTemplate(animated: true) { _, _ in
                    self?.centerMapOnCampo(campo)
                    self?.showCampoDetails(campo)
                }
                completion()
            }

            return item
        }

        completionHandler(Array(items))
    }

    func searchTemplate(_ searchTemplate: CPSearchTemplate, selectedResult item: CPListItem, completionHandler: @escaping () -> Void) {
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
        let id = "CampoPin"
        var view = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView
        if view == nil {
            view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
        } else {
            view?.annotation = annotation
        }
        view?.markerTintColor = .systemGreen
        view?.glyphImage = UIImage(systemName: "sportscourt.fill")
        view?.displayPriority = .defaultLow
        view?.clusteringIdentifier = "campo"
        view?.titleVisibility = .adaptive
        view?.subtitleVisibility = .hidden
        return view
    }
}
