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

    // Campos cercanos y búsqueda
    private var nearbyCampos: [CampoModel] = []
    private var allCampos: [CampoModel] = []

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

    // MARK: - MapView Setup

    /// Crea el MKMapView y lo añade al CPWindow
    private func createMapView() {
        guard let window = window else {
            Logger.debug("⚠️ CPWindow es nil - no se puede crear MKMapView")
            return
        }

        let mapView = MKMapView(frame: window.bounds)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.mapView = mapView

        // Crear un view controller para el mapa y asignarlo al CPWindow
        let mapViewController = UIViewController()
        mapViewController.view = mapView
        window.rootViewController = mapViewController

        Logger.debug("✅ MKMapView creado y añadido al CPWindow")
    }

    // MARK: - Setup

    func setupInterface() {
        Logger.debug("🚗 Configurando interfaz de CarPlay")

        // Crear el MKMapView y añadirlo al CPWindow
        createMapView()

        // Crear el template de mapa
        let mapTemplate = CPMapTemplate()
        mapTemplate.mapDelegate = self

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

        // Cargar campos cercanos
        loadNearbyCampos()

        // Cargar todos los campos para búsqueda
        loadAllCampos()
    }

    private func configureMapView() {
        Logger.debug("🔄 Configurando MKMapView...")

        guard let mapView = self.mapView else {
            Logger.debug("⚠️ MKMapView no disponible")
            return
        }

        mapView.delegate = self
        mapView.showsUserLocation = true
        mapView.isScrollEnabled = true
        mapView.isZoomEnabled = true
        mapView.isUserInteractionEnabled = true

        // Centrar en Galicia por defecto
        let galiciaCenter = CLLocationCoordinate2D(latitude: 42.8782, longitude: -8.5448)
        let region = MKCoordinateRegion(
            center: galiciaCenter,
            span: MKCoordinateSpan(latitudeDelta: 2.0, longitudeDelta: 2.0)
        )
        mapView.setRegion(region, animated: false)
        Logger.debug("✅ MKMapView centrado en Galicia")
    }

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    private func setupMapButtons(for mapTemplate: CPMapTemplate) {
        // Botón de pan/desplazar mapa
        let panButton = CPMapButton { [weak self] _ in
            guard let self = self, let template = self.mapTemplate else { return }
            if template.isPanningInterfaceVisible {
                template.dismissPanningInterface(animated: true)
            } else {
                template.showPanningInterface(animated: true)
            }
        }
        panButton.image = UIImage(systemName: "hand.draw")

        // Botón de lista de campos cercanos
        let nearbyButton = CPMapButton { [weak self] _ in
            self?.showNearbyCamposList()
        }
        nearbyButton.image = UIImage(systemName: "list.bullet.rectangle")

        // Botón de mi ubicación
        let locationButton = CPMapButton { [weak self] _ in
            self?.centerOnUserLocation()
        }
        locationButton.image = UIImage(systemName: "location.fill")

        // Botón de zoom in
        let zoomInButton = CPMapButton { [weak self] _ in
            guard let mapView = self?.mapView else { return }
            var region = mapView.region
            region.span.latitudeDelta /= 2
            region.span.longitudeDelta /= 2
            mapView.setRegion(region, animated: true)
        }
        zoomInButton.image = UIImage(systemName: "plus.magnifyingglass")

        // Botón de zoom out
        let zoomOutButton = CPMapButton { [weak self] _ in
            guard let mapView = self?.mapView else { return }
            var region = mapView.region
            region.span.latitudeDelta = min(region.span.latitudeDelta * 2, 20)
            region.span.longitudeDelta = min(region.span.longitudeDelta * 2, 20)
            mapView.setRegion(region, animated: true)
        }
        zoomOutButton.image = UIImage(systemName: "minus.magnifyingglass")

        mapTemplate.mapButtons = [panButton, zoomInButton, zoomOutButton, nearbyButton, locationButton]

        // Configurar botón de búsqueda
        mapTemplate.leadingNavigationBarButtons = [
            CPBarButton(title: "Buscar") { [weak self] _ in
                self?.showSearchInterface()
            }
        ]
    }

    // MARK: - Data Loading

    private func loadNearbyCampos() {
        guard let userLocation = locationManager.location else {
            Logger.debug("⚠️ No hay ubicación del usuario para cargar campos cercanos")
            return
        }

        Task {
            do {
                // Obtener campos cercanos (dentro de 50km)
                let response: [CampoModel] = try await supabaseClient
                    .from("campos")
                    .select()
                    .execute()
                    .value

                // Filtrar y ordenar por distancia
                let campos = response.filter { campo in
                    guard let lat = campo.latitud, let lon = campo.longitud else { return false }
                    let campoLocation = CLLocation(latitude: lat, longitude: lon)
                    let distance = userLocation.distance(from: campoLocation)
                    return distance <= 50000 // 50km
                }.sorted { campo1, campo2 in
                    guard let lat1 = campo1.latitud, let lon1 = campo1.longitud,
                          let lat2 = campo2.latitud, let lon2 = campo2.longitud else {
                        return false
                    }
                    let loc1 = CLLocation(latitude: lat1, longitude: lon1)
                    let loc2 = CLLocation(latitude: lat2, longitude: lon2)
                    return userLocation.distance(from: loc1) < userLocation.distance(from: loc2)
                }

                await MainActor.run {
                    self.nearbyCampos = Array(campos.prefix(10)) // Máximo 10 campos cercanos
                    self.displayCamposOnMap(campos: self.nearbyCampos)
                }

                Logger.debug("✅ Cargados \(self.nearbyCampos.count) campos cercanos en CarPlay")
            } catch {
                Logger.debug("❌ Error al cargar campos cercanos: \(error)")
            }
        }
    }

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
                    // Mostrar todos los campos en el mapa
                    self.displayCamposOnMap(campos: response)
                }

                Logger.debug("✅ Cargados \(self.allCampos.count) campos totales para búsqueda y mapa")
            } catch {
                Logger.debug("❌ Error al cargar todos los campos: \(error)")
            }
        }
    }

    // MARK: - Map Display

    private func displayCamposOnMap(campos: [CampoModel]) {
        guard let mapTemplate = mapTemplate else {
            Logger.debug("⚠️ MapTemplate no disponible")
            return
        }

        if let mapView = self.mapView {
            configureAnnotationsOnMap(mapView: mapView, campos: campos, mapTemplate: mapTemplate)
        } else {
            Logger.debug("⚠️ MKMapView no disponible - mostrando solo POIs")
            displayPOIsOnly(campos: campos, mapTemplate: mapTemplate)
        }
    }

    /// Configura las anotaciones en el mapa una vez que tenemos el MKMapView
    private func configureAnnotationsOnMap(mapView: MKMapView, campos: [CampoModel], mapTemplate: CPMapTemplate) {
        Logger.debug("🗺️ Mostrando \(campos.count) campos en el mapa")

        // Limpiar anotaciones anteriores
        mapView.removeAnnotations(mapView.annotations)

        // Crear anotaciones MKPointAnnotation para el MKMapView
        var mkAnnotations: [MKPointAnnotation] = []

        for campo in campos {
            guard let lat = campo.latitud,
                  let lon = campo.longitud else { continue }

            let annotation = MKPointAnnotation()
            annotation.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            annotation.title = campo.nombre
            annotation.subtitle = campo.localidad

            mkAnnotations.append(annotation)
        }

        // Agregar anotaciones al MKMapView
        mapView.addAnnotations(mkAnnotations)
        Logger.debug("✅ \(mkAnnotations.count) anotaciones agregadas al mapa")

        // Ajustar la región del mapa para mostrar todas las anotaciones
        if !mkAnnotations.isEmpty {
            let coordinates = mkAnnotations.map { $0.coordinate }
            let region = regionForCoordinates(coordinates)
            mapView.setRegion(region, animated: true)
            Logger.debug("✅ Región del mapa ajustada")
        }

        Logger.debug("✅ Anotaciones configuradas en el mapa")
    }

    /// Muestra solo los POIs de CarPlay sin anotaciones en el mapa
    /// Útil cuando el MKMapView no está disponible
    private func displayPOIsOnly(campos: [CampoModel], mapTemplate: CPMapTemplate) {
        // Crear CPPointOfInterest para CarPlay (para interacción)
        var poiAnnotations: [CPPointOfInterest] = []

        for campo in campos {
            guard let lat = campo.latitud,
                  let lon = campo.longitud else { continue }

            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            let location = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
            location.name = campo.nombre

            let poi = CPPointOfInterest(
                location: location,
                title: campo.nombre,
                subtitle: campo.localidad,
                summary: nil,
                detailTitle: nil,
                detailSubtitle: nil,
                detailSummary: nil,
                pinImage: UIImage(systemName: "mappin.circle.fill")
            )

            // Configurar acción al tocar
            poi.primaryButton = CPTextButton(title: "Navegar", textStyle: .normal) { [weak self] _ in
                self?.startNavigation(to: campo)
            }

            poiAnnotations.append(poi)
        }

        Logger.debug("✅ \(poiAnnotations.count) POIs configurados para CarPlay")
    }

    // Helper para calcular región que contenga todas las coordenadas
    private func regionForCoordinates(_ coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            // Región por defecto centrada en Galicia
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 42.8782, longitude: -8.5448),
                span: MKCoordinateSpan(latitudeDelta: 2.0, longitudeDelta: 2.0)
            )
        }

        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coordinate in coordinates {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }

        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let spanLat = (maxLat - minLat) * 1.5  // 1.5x para dar margen
        let spanLon = (maxLon - minLon) * 1.5

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: max(spanLat, 0.1), longitudeDelta: max(spanLon, 0.1))
        )
    }

    // MARK: - List Interface

    private func showNearbyCamposList() {
        Logger.debug("📋 Mostrando lista de campos cercanos")

        guard !nearbyCampos.isEmpty else {
            Logger.debug("⚠️ No hay campos cercanos para mostrar")
            return
        }

        // Crear items de lista
        let listItems = nearbyCampos.map { campo -> CPListItem in
            let distance = distanceString(to: campo)
            let item = CPListItem(
                text: campo.nombre,
                detailText: "\(campo.localidad) • \(distance)"
            )

            item.handler = { [weak self] (item: CPSelectableListItem, completion: @escaping () -> Void) in
                self?.showCampoDetails(campo)
                completion()
            }

            return item
        }

        // Crear sección
        let section = CPListSection(items: listItems)

        // Crear template de lista
        let listTemplate = CPListTemplate(title: "Campos Cercanos", sections: [section])

        // Mostrar template
        interfaceController.pushTemplate(listTemplate, animated: true) { success, error in
            if let error = error {
                Logger.debug("❌ Error al mostrar lista: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Search Interface

    private func showSearchInterface() {
        Logger.debug("🔍 Mostrando interfaz de búsqueda")

        // Crear template de búsqueda
        let searchTemplate = CPSearchTemplate()
        searchTemplate.delegate = self

        // CPSearchTemplate debe usar pushTemplate, no presentTemplate
        interfaceController.pushTemplate(searchTemplate, animated: true) { success, error in
            if let error = error {
                Logger.debug("❌ Error al mostrar búsqueda: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Navigation

    private func startNavigation(to campo: CampoModel) {
        guard let lat = campo.latitud,
              let lon = campo.longitud else {
            Logger.debug("❌ Campo sin coordenadas")
            return
        }

        Logger.debug("🧭 Iniciando navegación a: \(campo.nombre)")

        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = campo.nombre

        // Abrir navegación nativa de Apple Maps
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])

        // Track evento
        AnalyticsManager.shared.trackCustom(
            name: "carplay_navigation_started",
            category: .navigation,
            parameters: ["campo_id": campo.id.uuidString, "campo_name": campo.nombre]
        )
    }

    private func showCampoDetails(_ campo: CampoModel) {
        Logger.debug("📍 Mostrando detalles de: \(campo.nombre)")

        // Crear items informativos
        var items: [CPInformationItem] = []

        items.append(CPInformationItem(title: "Dirección", detail: campo.direccion))
        items.append(CPInformationItem(title: "Localidad", detail: "\(campo.localidad), \(campo.provincia)"))

        if !campo.codigo_postal.isEmpty {
            items.append(CPInformationItem(title: "CP", detail: campo.codigo_postal))
        }

        if !campo.tipo.isEmpty {
            items.append(CPInformationItem(title: "Tipo", detail: campo.tipo))
        }

        if !campo.superficie.isEmpty {
            items.append(CPInformationItem(title: "Superficie", detail: campo.superficie))
        }

        let distance = distanceString(to: campo)
        items.append(CPInformationItem(title: "Distancia", detail: distance))

        // Botón de navegación
        let navigateButton = CPTextButton(title: "Navegar", textStyle: .confirm) { [weak self] _ in
            self?.startNavigation(to: campo)
        }

        let infoTemplate = CPInformationTemplate(
            title: campo.nombre,
            layout: .leading,
            items: items,
            actions: [navigateButton]
        )

        interfaceController.pushTemplate(infoTemplate, animated: true)
    }

    private func centerOnUserLocation() {
        Logger.debug("📍 Centrando en ubicación del usuario")

        guard let userLocation = locationManager.location else {
            Logger.debug("⚠️ No hay ubicación del usuario disponible")
            return
        }

        guard let mapView = self.mapView else {
            Logger.debug("⚠️ MKMapView no disponible")
            return
        }

        let region = MKCoordinateRegion(
            center: userLocation.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
        mapView.setRegion(region, animated: true)
        Logger.debug("✅ Mapa centrado en ubicación del usuario")
    }

    // MARK: - Helper Methods

    private func distanceString(to campo: CampoModel) -> String {
        guard let userLocation = locationManager.location,
              let lat = campo.latitud,
              let lon = campo.longitud else {
            return "Distancia desconocida"
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
                    using routeChoice: CPRouteChoice) {
        Logger.debug("🗺️ Ruta seleccionada")
    }

    func mapTemplate(_ mapTemplate: CPMapTemplate, startedTrip trip: CPTrip, using routeChoice: CPRouteChoice) {
        Logger.debug("🚗 Viaje iniciado")
    }

    func mapTemplate(_ mapTemplate: CPMapTemplate, panWith direction: CPMapTemplate.PanDirection) {
        guard let mapView = self.mapView else { return }
        let region = mapView.region
        let offsetFactor = region.span.latitudeDelta * 0.15
        var center = region.center

        if direction.contains(.up) { center.latitude += offsetFactor }
        if direction.contains(.down) { center.latitude -= offsetFactor }
        if direction.contains(.left) { center.longitude -= offsetFactor }
        if direction.contains(.right) { center.longitude += offsetFactor }

        mapView.setCenter(center, animated: true)
    }

    func mapTemplate(_ mapTemplate: CPMapTemplate, panBeganWith direction: CPMapTemplate.PanDirection) {}
    func mapTemplate(_ mapTemplate: CPMapTemplate, panEndedWith direction: CPMapTemplate.PanDirection) {}
}

// MARK: - CPSearchTemplateDelegate

extension CarPlayManager: CPSearchTemplateDelegate {
    func searchTemplate(_ searchTemplate: CPSearchTemplate, updatedSearchText searchText: String, completionHandler: @escaping ([CPListItem]) -> Void) {
        Logger.debug("🔍 Buscando: \(searchText)")

        // Filtrar campos por nombre o localidad
        let filtered = allCampos.filter { campo in
            campo.nombre.localizedCaseInsensitiveContains(searchText) ||
            campo.localidad.localizedCaseInsensitiveContains(searchText)
        }

        // Crear items de resultados
        let items = filtered.prefix(10).map { campo -> CPListItem in
            let distance = distanceString(to: campo)
            let item = CPListItem(
                text: campo.nombre,
                detailText: "\(campo.localidad) • \(distance)"
            )

            item.handler = { [weak self] (item: CPSelectableListItem, completion: @escaping () -> Void) in
                // Primero cerrar búsqueda, luego mostrar detalle
                self?.interfaceController.popTemplate(animated: true) { _, _ in
                    self?.showCampoDetails(campo)
                }
                completion()
            }

            return item
        }

        completionHandler(Array(items))
    }

    func searchTemplate(_ searchTemplate: CPSearchTemplate, selectedResult item: CPListItem, completionHandler: @escaping () -> Void) {
        Logger.debug("✅ Resultado seleccionado")
        completionHandler()
    }
}

// MARK: - CLLocationManagerDelegate

extension CarPlayManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Actualizar campos cercanos cuando cambia la ubicación
        if let location = locations.last {
            Logger.debug("📍 Ubicación actualizada en CarPlay: \(location.coordinate)")
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Logger.debug("🔐 Estado de autorización de ubicación: \(status.rawValue)")

        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
}

// MARK: - MKMapViewDelegate

extension CarPlayManager: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        // No personalizar la anotación del usuario
        if annotation is MKUserLocation {
            return nil
        }

        let identifier = "CampoAnnotation"
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

        if annotationView == nil {
            annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            annotationView?.canShowCallout = true
        } else {
            annotationView?.annotation = annotation
        }

        // Personalizar el marcador
        annotationView?.markerTintColor = .systemGreen
        annotationView?.glyphImage = UIImage(systemName: "figure.walk")

        return annotationView
    }

    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        Logger.debug("📍 Anotación seleccionada: \(view.annotation?.title ?? "Sin título")")
    }
}
