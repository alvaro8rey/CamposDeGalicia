import CarPlay
import MapKit
import Combine
import Supabase

/// Manager para gestionar toda la lógica de CarPlay
class CarPlayManager: NSObject {

    // MARK: - Properties

    private let interfaceController: CPInterfaceController
    private weak var window: CPWindow?
    private var mapTemplate: CPMapTemplate?
    private var locationManager: CLLocationManager
    private lazy var supabaseClient: SupabaseClient = supabase
    private var cancellables = Set<AnyCancellable>()
    private weak var mapView: MKMapView?
    private weak var camposTableView: UITableView?

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

    // MARK: - Split View Setup

    private func createSplitView() {
        guard let window = window else {
            Logger.debug("⚠️ CPWindow es nil")
            return
        }

        let containerVC = UIViewController()
        containerVC.overrideUserInterfaceStyle = .dark
        containerVC.view.backgroundColor = .black

        // === Left panel: Table (35%) ===
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = UIColor(white: 0.08, alpha: 1)
        tableView.separatorColor = UIColor(white: 0.2, alpha: 1)
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 0)
        tableView.indicatorStyle = .white
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(CarPlayCampoCell.self, forCellReuseIdentifier: "CampoCell")
        tableView.rowHeight = 40
        // Inset para no quedar debajo del nav bar del CPMapTemplate
        tableView.contentInset = UIEdgeInsets(top: 50, left: 0, bottom: 0, right: 0)
        tableView.scrollIndicatorInsets = UIEdgeInsets(top: 50, left: 0, bottom: 0, right: 0)
        self.camposTableView = tableView

        // === Separator ===
        let separator = UIView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.backgroundColor = UIColor(white: 0.25, alpha: 1)

        // === Right panel: Map (65%) ===
        let mapView = MKMapView(frame: .zero)
        mapView.translatesAutoresizingMaskIntoConstraints = false
        self.mapView = mapView

        containerVC.view.addSubview(tableView)
        containerVC.view.addSubview(separator)
        containerVC.view.addSubview(mapView)

        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: containerVC.view.leadingAnchor),
            tableView.topAnchor.constraint(equalTo: containerVC.view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: containerVC.view.bottomAnchor),
            tableView.widthAnchor.constraint(equalTo: containerVC.view.widthAnchor, multiplier: 0.35),

            separator.leadingAnchor.constraint(equalTo: tableView.trailingAnchor),
            separator.topAnchor.constraint(equalTo: containerVC.view.topAnchor),
            separator.bottomAnchor.constraint(equalTo: containerVC.view.bottomAnchor),
            separator.widthAnchor.constraint(equalToConstant: 1),

            mapView.leadingAnchor.constraint(equalTo: separator.trailingAnchor),
            mapView.topAnchor.constraint(equalTo: containerVC.view.topAnchor),
            mapView.bottomAnchor.constraint(equalTo: containerVC.view.bottomAnchor),
            mapView.trailingAnchor.constraint(equalTo: containerVC.view.trailingAnchor),
        ])

        window.rootViewController = containerVC
        Logger.debug("✅ Split view creado (lista 35% + mapa 65%)")
    }

    // MARK: - Setup

    func setupInterface() {
        Logger.debug("🚗 Configurando interfaz de CarPlay")

        // Crear split view (tabla + mapa)
        createSplitView()

        // Crear el template de mapa
        let mapTemplate = CPMapTemplate()
        mapTemplate.mapDelegate = self
        mapTemplate.automaticallyHidesNavigationBar = false
        self.mapTemplate = mapTemplate

        // Configurar botones del mapa
        setupMapButtons(for: mapTemplate)

        // Establecer como root template
        interfaceController.setRootTemplate(mapTemplate, animated: true) { [weak self] success, error in
            if let error = error {
                Logger.debug("❌ Error al establecer template: \(error.localizedDescription)")
            } else {
                Logger.debug("✅ Template de CarPlay establecido correctamente")
                self?.configureMapView()
            }
        }

        // Cargar todos los campos
        loadAllCampos()
    }

    private func configureMapView() {
        guard let mapView = self.mapView else { return }

        mapView.delegate = self
        mapView.showsUserLocation = true
        mapView.isScrollEnabled = true
        mapView.isZoomEnabled = true
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.isUserInteractionEnabled = true
        mapView.overrideUserInterfaceStyle = .dark
        mapView.pointOfInterestFilter = .excludingAll

        // Centrar en Galicia
        let galiciaCenter = CLLocationCoordinate2D(latitude: 42.8782, longitude: -8.5448)
        let region = MKCoordinateRegion(
            center: galiciaCenter,
            span: MKCoordinateSpan(latitudeDelta: 2.5, longitudeDelta: 2.5)
        )
        mapView.setRegion(region, animated: false)
        Logger.debug("✅ MKMapView configurado (dark mode, interactivo)")
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

        // Mi ubicación
        let locationButton = CPMapButton { [weak self] _ in
            self?.centerOnUserLocation()
        }
        locationButton.image = UIImage(systemName: "location.fill")

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

        mapTemplate.mapButtons = [zoomInButton, zoomOutButton, locationButton, galiciaButton]

        // Botón de búsqueda en nav bar
        mapTemplate.leadingNavigationBarButtons = [
            CPBarButton(title: "Buscar") { [weak self] _ in
                self?.showSearchInterface()
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
                    self.updateCamposTable()
                    self.displayAnnotations(campos: response)
                }

                Logger.debug("✅ Cargados \(self.allCampos.count) campos")
            } catch {
                Logger.debug("❌ Error al cargar campos: \(error)")
            }
        }
    }

    private func updateCamposTable() {
        let grouped = Dictionary(grouping: allCampos) { $0.provincia }
        camposByProvincia = grouped
            .sorted { $0.key < $1.key }
            .map { (provincia: $0.key, campos: $0.value.sorted { $0.nombre < $1.nombre }) }
        camposTableView?.reloadData()
        Logger.debug("✅ Tabla actualizada: \(camposByProvincia.count) provincias")
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

            let annotation = CampoAnnotation(campo: campo)
            annotations.append(annotation)
        }

        mapView.addAnnotations(annotations)
        Logger.debug("✅ \(annotations.count) anotaciones en el mapa")
    }

    // MARK: - Search

    private func showSearchInterface() {
        let searchTemplate = CPSearchTemplate()
        searchTemplate.delegate = self
        interfaceController.pushTemplate(searchTemplate, animated: true)
    }

    // MARK: - Navigation

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

    // MARK: - Campo Detail

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
            items.append(CPInformationItem(title: "Tipo de campo", detail: campo.tipo))
        }

        if !campo.superficie.isEmpty {
            items.append(CPInformationItem(title: "Superficie", detail: campo.superficie))
        }

        // Extras de contribuciones
        if let cantina = campo.tiene_cantina {
            items.append(CPInformationItem(title: "Cantina", detail: cantina ? "Sí" : "No"))
        }

        if let parking = campo.parking {
            items.append(CPInformationItem(title: "Parking", detail: parking ? "Sí" : "No"))
        }

        if let estado = campo.estado_cesped, !estado.isEmpty {
            items.append(CPInformationItem(title: "Estado césped", detail: estado))
        }

        if let medidas = campo.medidas_campo, !medidas.isEmpty {
            items.append(CPInformationItem(title: "Medidas", detail: medidas))
        }

        // Max 10 items en CPInformationTemplate
        let distance = distanceString(to: campo)
        if items.count < 10 {
            items.append(CPInformationItem(title: "Distancia", detail: distance))
        }

        // Botones (max 3)
        let navigateButton = CPTextButton(title: "Navegar", textStyle: .confirm) { [weak self] _ in
            self?.startNavigation(to: campo)
        }

        let showOnMapButton = CPTextButton(title: "Ver en mapa", textStyle: .normal) { [weak self] _ in
            self?.centerMapOnCampo(campo)
            self?.interfaceController.popTemplate(animated: true)
        }

        let infoTemplate = CPInformationTemplate(
            title: campo.nombre,
            layout: .leading,
            items: Array(items.prefix(10)),
            actions: [navigateButton, showOnMapButton]
        )

        interfaceController.pushTemplate(infoTemplate, animated: true)
    }

    private func centerMapOnCampo(_ campo: CampoModel) {
        guard let lat = campo.latitud, let lon = campo.longitud,
              let mapView = self.mapView else { return }

        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
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

// MARK: - UITableViewDataSource & Delegate

extension CarPlayManager: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        return camposByProvincia.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return camposByProvincia[section].campos.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CampoCell", for: indexPath) as! CarPlayCampoCell
        let campo = camposByProvincia[indexPath.section].campos[indexPath.row]
        cell.configure(nombre: campo.nombre, localidad: campo.localidad)
        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let group = camposByProvincia[section]
        return "\(group.provincia) (\(group.campos.count))"
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        header.textLabel?.font = UIFont.boldSystemFont(ofSize: 11)
        header.textLabel?.textColor = .systemGreen
        var bg = UIBackgroundConfiguration.clear()
        bg.backgroundColor = UIColor(white: 0.12, alpha: 1)
        header.backgroundConfiguration = bg
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 24
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let campo = camposByProvincia[indexPath.section].campos[indexPath.row]

        // Centrar mapa en el campo
        centerMapOnCampo(campo)

        // Mostrar detalle
        showCampoDetails(campo)
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
        let region = mapView.region
        let offset = region.span.latitudeDelta * 0.15
        var center = region.center

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

        // Individual campo
        let id = "CampoPin"
        var view = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView
        if view == nil {
            view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
            view?.canShowCallout = true
            view?.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
        } else {
            view?.annotation = annotation
        }
        view?.markerTintColor = .systemGreen
        view?.glyphImage = UIImage(systemName: "sportscourt.fill")
        view?.displayPriority = .defaultLow
        view?.clusteringIdentifier = "campo"
        return view
    }

    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        guard let campoAnnotation = view.annotation as? CampoAnnotation else { return }
        showCampoDetails(campoAnnotation.campo)
    }

    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        // Al seleccionar un cluster, hacer zoom
        if let cluster = view.annotation as? MKClusterAnnotation {
            mapView.showAnnotations(cluster.memberAnnotations, animated: true)
        }
    }
}

// MARK: - Custom Annotation

class CampoAnnotation: NSObject, MKAnnotation {
    let campo: CampoModel
    let coordinate: CLLocationCoordinate2D
    var title: String? { campo.nombre }
    var subtitle: String? { campo.localidad }

    init(campo: CampoModel) {
        self.campo = campo
        self.coordinate = CLLocationCoordinate2D(
            latitude: campo.latitud ?? 0,
            longitude: campo.longitud ?? 0
        )
        super.init()
    }
}

// MARK: - Custom Table Cell

class CarPlayCampoCell: UITableViewCell {

    private let nombreLabel = UILabel()
    private let localidadLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        selectionStyle = .default

        let selectedBg = UIView()
        selectedBg.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.15)
        selectedBackgroundView = selectedBg

        nombreLabel.font = UIFont.boldSystemFont(ofSize: 11)
        nombreLabel.textColor = .white
        nombreLabel.numberOfLines = 1

        localidadLabel.font = UIFont.systemFont(ofSize: 9)
        localidadLabel.textColor = UIColor(white: 0.6, alpha: 1)
        localidadLabel.numberOfLines = 1

        let stack = UIStackView(arrangedSubviews: [nombreLabel, localidadLabel])
        stack.axis = .vertical
        stack.spacing = 1
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(nombre: String, localidad: String) {
        nombreLabel.text = nombre
        localidadLabel.text = localidad
    }
}
