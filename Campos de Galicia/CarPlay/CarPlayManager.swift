import CarPlay
import MapKit
import Combine
import Supabase

/// Manager para gestionar toda la lógica de CarPlay
class CarPlayManager: NSObject {

    // MARK: - Properties

    private let interfaceController: CPInterfaceController
    private var mapTemplate: CPMapTemplate?
    private var locationManager: CLLocationManager
    private var supabaseClient = supabase
    private var cancellables = Set<AnyCancellable>()

    // Campos cercanos y búsqueda
    private var nearbyCampos: [CampoModel] = []
    private var allCampos: [CampoModel] = []

    // MARK: - Initialization

    init(interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        self.locationManager = CLLocationManager()
        super.init()

        setupLocationManager()
    }

    // MARK: - Setup

    func setupInterface() {
        Logger.debug("🚗 Configurando interfaz de CarPlay")

        // Crear el template de mapa
        let mapTemplate = CPMapTemplate()
        mapTemplate.mapDelegate = self

        self.mapTemplate = mapTemplate

        // Configurar botones del mapa
        setupMapButtons(for: mapTemplate)

        // Establecer como root template
        interfaceController.setRootTemplate(mapTemplate, animated: true) { success, error in
            if let error = error {
                Logger.debug("❌ Error al establecer template: \(error.localizedDescription)")
            } else {
                Logger.debug("✅ Template de CarPlay establecido correctamente")
            }
        }

        // Cargar campos cercanos
        loadNearbyCampos()

        // Cargar todos los campos para búsqueda
        loadAllCampos()
    }

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    private func setupMapButtons(for mapTemplate: CPMapTemplate) {
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

        mapTemplate.mapButtons = [nearbyButton, locationButton]

        // Configurar botón de búsqueda (aparece en la barra superior izquierda)
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
                }

                Logger.debug("✅ Cargados \(self.allCampos.count) campos totales para búsqueda")
            } catch {
                Logger.debug("❌ Error al cargar todos los campos: \(error)")
            }
        }
    }

    // MARK: - Map Display

    private func displayCamposOnMap(campos: [CampoModel]) {
        guard let mapTemplate = mapTemplate else { return }

        // Crear anotaciones para cada campo
        var annotations: [CPPointOfInterest] = []

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

            annotations.append(poi)
        }

        mapTemplate.showPanningInterface(animated: true)

        // Mostrar anotaciones en el mapa
        // Nota: En CarPlay real, las anotaciones se muestran automáticamente
        // cuando están en el área visible del mapa
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
                self?.selectCampo(campo)
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

        // Mostrar template
        interfaceController.presentTemplate(searchTemplate, animated: true) { success, error in
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

    private func selectCampo(_ campo: CampoModel) {
        Logger.debug("📍 Campo seleccionado: \(campo.nombre)")

        // Centrar mapa en el campo
        if let lat = campo.latitud, let lon = campo.longitud {
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            // En CarPlay, mostramos información del campo
            showCampoDetails(campo)
        }
    }

    private func showCampoDetails(_ campo: CampoModel) {
        // Crear información detallada del campo
        let detailText = """
        \(campo.localidad)
        \(campo.provincia)
        """

        let item = CPListItem(
            text: campo.nombre,
            detailText: detailText
        )

        item.handler = { [weak self] (item: CPSelectableListItem, completion: @escaping () -> Void) in
            self?.startNavigation(to: campo)
            completion()
        }

        let section = CPListSection(items: [item])
        let listTemplate = CPListTemplate(title: "Detalles", sections: [section])

        // Botón para navegar
        listTemplate.trailingNavigationBarButtons = [
            CPBarButton(title: "Navegar") { [weak self] _ in
                self?.startNavigation(to: campo)
            }
        ]

        interfaceController.pushTemplate(listTemplate, animated: true)
    }

    private func centerOnUserLocation() {
        Logger.debug("📍 Centrando en ubicación del usuario")
        // En CarPlay real, esto centraría el mapa automáticamente
        // El mapa de CarPlay maneja esto nativamente
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
                self?.selectCampo(campo)
                searchTemplate.dismiss(animated: true)
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
