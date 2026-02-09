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
        print("========== CARPLAY MANAGER INIT ==========")
        self.interfaceController = interfaceController
        self.window = window
        self.locationManager = CLLocationManager()
        super.init()

        setupLocationManager()
        print("========== CARPLAY MANAGER INIT COMPLETE ==========")
    }

    // MARK: - MapView Access

    /// Obtiene el MKMapView del CPWindow después de que el template esté configurado
    /// Ahora con reintentos para manejar el timing del sistema
    private func getMapView(retryCount: Int = 0, maxRetries: Int = 5, completion: @escaping (MKMapView?) -> Void) {
        guard let window = window else {
            print("⚠️ CPWindow es nil")
            completion(nil)
            return
        }

        // El MKMapView es creado automáticamente por el sistema cuando asignamos el CPMapTemplate
        // Lo encontramos en la jerarquía de vistas del CPWindow
        if let mapView = findMapView(in: window) {
            self.mapView = mapView
            print("✅ MKMapView encontrado en la jerarquía de vistas (intento \(retryCount + 1))")
            completion(mapView)
            return
        }

        // Si no se encuentra y aún hay reintentos disponibles, intentar de nuevo
        if retryCount < maxRetries {
            print("⏳ MKMapView no encontrado, reintentando en 0.2s... (intento \(retryCount + 1)/\(maxRetries))")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.getMapView(retryCount: retryCount + 1, maxRetries: maxRetries, completion: completion)
            }
        } else {
            print("⚠️ No se pudo encontrar MKMapView después de \(maxRetries) intentos")
            completion(nil)
        }
    }

    /// Busca recursivamente un MKMapView en la jerarquía de vistas
    private func findMapView(in view: UIView) -> MKMapView? {
        if let mapView = view as? MKMapView {
            return mapView
        }

        for subview in view.subviews {
            if let mapView = findMapView(in: subview) {
                return mapView
            }
        }

        return nil
    }

    // MARK: - Setup

    func setupInterface() {
        print("========== SETUP INTERFACE CARPLAY ==========")
        Logger.debug("🚗 Configurando interfaz de CarPlay")

        // Crear el template de mapa
        let mapTemplate = CPMapTemplate()
        mapTemplate.mapDelegate = self

        self.mapTemplate = mapTemplate

        // Configurar botones del mapa
        setupMapButtons(for: mapTemplate)

        // Establecer como root template
        interfaceController.setRootTemplate(mapTemplate, animated: true) { [weak self] success, error in
            if let error = error {
                print("========== ERROR AL ESTABLECER TEMPLATE: \(error.localizedDescription) ==========")
                Logger.debug("❌ Error al establecer template: \(error.localizedDescription)")
            } else {
                print("========== TEMPLATE DE CARPLAY ESTABLECIDO CORRECTAMENTE ==========")
                Logger.debug("✅ Template de CarPlay establecido correctamente")

                // Ahora que el template está configurado, obtener el MKMapView
                // que el sistema creó automáticamente
                // Usamos el nuevo método con reintentos para manejar el timing
                self?.configureMapView()
            }
        }

        // Cargar campos cercanos
        loadNearbyCampos()

        // Cargar todos los campos para búsqueda
        loadAllCampos()
    }

    private func configureMapView() {
        print("🔄 Iniciando configuración de MKMapView...")

        // Usar el nuevo método con reintentos
        getMapView { [weak self] mapView in
            guard let mapView = mapView, let self = self else {
                print("⚠️ No se pudo obtener el MKMapView - CarPlay continuará sin mapa personalizado")
                // No hacer crash, simplemente continuar sin configurar el mapa
                return
            }

            print("🗺️ Configurando MKMapView...")
            mapView.delegate = self
            mapView.showsUserLocation = true

            // Centrar en Galicia por defecto
            let galiciaCenter = CLLocationCoordinate2D(latitude: 42.8782, longitude: -8.5448)
            let region = MKCoordinateRegion(
                center: galiciaCenter,
                span: MKCoordinateSpan(latitudeDelta: 2.0, longitudeDelta: 2.0)
            )
            mapView.setRegion(region, animated: false)
            print("✅ MKMapView centrado en Galicia")
        }
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
        guard let mapTemplate = mapTemplate else {
            print("⚠️ MapTemplate no disponible")
            return
        }

        // Si ya tenemos el mapView, usarlo directamente
        if let mapView = self.mapView {
            configureAnnotationsOnMap(mapView: mapView, campos: campos, mapTemplate: mapTemplate)
            return
        }

        // Si no tenemos el mapView aún, intentar obtenerlo
        print("🔄 Obteniendo MKMapView para mostrar campos...")
        getMapView { [weak self] mapView in
            guard let mapView = mapView, let self = self else {
                print("⚠️ No se pudo obtener el MKMapView para mostrar campos - continuando sin anotaciones visuales")
                // Aún podemos mostrar POIs de CarPlay sin el mapa visual
                self?.displayPOIsOnly(campos: campos, mapTemplate: mapTemplate)
                return
            }

            self.configureAnnotationsOnMap(mapView: mapView, campos: campos, mapTemplate: mapTemplate)
        }
    }

    /// Configura las anotaciones en el mapa una vez que tenemos el MKMapView
    private func configureAnnotationsOnMap(mapView: MKMapView, campos: [CampoModel], mapTemplate: CPMapTemplate) {
        print("🗺️ Mostrando \(campos.count) campos en el mapa")

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
        print("✅ \(mkAnnotations.count) anotaciones agregadas al mapa")

        // Ajustar la región del mapa para mostrar todas las anotaciones
        if !mkAnnotations.isEmpty {
            let coordinates = mkAnnotations.map { $0.coordinate }
            let region = regionForCoordinates(coordinates)
            mapView.setRegion(region, animated: true)
            print("✅ Región del mapa ajustada")
        }

        // Habilitar interfaz de panning en CarPlay
        mapTemplate.showPanningInterface(animated: true)

        // Mostrar también POIs de CarPlay
        displayPOIsOnly(campos: campos, mapTemplate: mapTemplate)
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

        print("✅ \(poiAnnotations.count) POIs configurados para CarPlay")
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

        guard let userLocation = locationManager.location else {
            Logger.debug("⚠️ No hay ubicación del usuario disponible")
            return
        }

        // Si ya tenemos el mapView, usarlo directamente
        if let mapView = self.mapView {
            let region = MKCoordinateRegion(
                center: userLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
            mapView.setRegion(region, animated: true)
            Logger.debug("✅ Mapa centrado en ubicación del usuario")
            return
        }

        // Si no, intentar obtenerlo
        getMapView { [weak self] mapView in
            guard let mapView = mapView else {
                Logger.debug("⚠️ No se pudo obtener el MKMapView")
                return
            }

            let region = MKCoordinateRegion(
                center: userLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
            mapView.setRegion(region, animated: true)
            Logger.debug("✅ Mapa centrado en ubicación del usuario")
        }
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
                self?.interfaceController.dismissTemplate(animated: true)
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
