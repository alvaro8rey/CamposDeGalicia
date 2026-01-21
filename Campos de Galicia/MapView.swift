import SwiftUI
import MapKit
import CoreLocation
import Supabase

// MARK: - Models & Helpers

struct MapAnnotationItem: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let campo: CampoModel
    let isFromManualCoordinates: Bool
}

class CampoAnnotation: MKPointAnnotation {
    let annotationItem: MapAnnotationItem
    
    init(annotationItem: MapAnnotationItem) {
        self.annotationItem = annotationItem
        super.init()
        self.coordinate = annotationItem.coordinate
        self.title = annotationItem.title
    }
}

struct Filtros: Equatable {
    var tipo: String? = nil
    var superficie: String? = nil
    var provincia: String? = nil
    var nombre: String? = nil
    var localidad: String? = nil
}

// MARK: - Estilo Liquid Glass

struct LiquidGlassModifier: ViewModifier {
    var color: Color = .primary
    var isCapsule: Bool = false
    
    func body(content: Content) -> some View {
        content
            .padding(isCapsule ? .horizontal : .all, 12)
            .padding(isCapsule ? .vertical : .all, 8)
            .background(.ultraThinMaterial)
            .clipShape(isCapsule ? AnyShape(Capsule()) : AnyShape(Circle()))
            .overlay(
                isCapsule ?
                AnyView(Capsule().stroke(.white.opacity(0.3), lineWidth: 0.5)) :
                AnyView(Circle().stroke(.white.opacity(0.3), lineWidth: 0.5))
            )
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            .foregroundColor(color)
    }
}

extension View {
    func liquidGlass(color: Color = .primary, isCapsule: Bool = false) -> some View {
        self.modifier(LiquidGlassModifier(color: color, isCapsule: isCapsule))
    }
}

// MARK: - View

struct MapaView: View {
    @EnvironmentObject var camposViewModel: CamposViewModel
    
    @Binding var externalIsNavigating: Bool
    
    @State private var region: MKCoordinateRegion
    @State private var isSatelliteView: Bool = false
    @State private var selectedCampo: CampoModel? = nil
    @State private var annotationItems: [MapAnnotationItem] = []
    @State private var showFiltros: Bool = false
    @State private var filtros: Filtros = Filtros()
    
    // Propiedades de búsqueda
    @State private var searchText: String = ""
    @State private var isSearching: Bool = false
    
    // Propiedades para Rutas e Indicaciones
    @State private var route: MKRoute?
    @State private var currentStepIndex: Int = 0
    @State private var showRouteSummary: Bool = false
    @State private var pendingDestination: MapAnnotationItem?
    
    @State private var userTrackingMode: MKUserTrackingMode = .none
    @State private var mapView: MKMapView?

    init(externalIsNavigating: Binding<Bool>) {
        self._externalIsNavigating = externalIsNavigating
        let initialRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 42.75508, longitude: -7.86621),
            span: MKCoordinateSpan(latitudeDelta: 2.5, longitudeDelta: 2.5)
        )
        self._region = State(initialValue: initialRegion)
    }

    @State private var filteredCampos: [CampoModel] = []

    var displayedAnnotations: [MapAnnotationItem] {
        if (externalIsNavigating || showRouteSummary), let dest = pendingDestination {
            return [dest]
        }
        return annotationItems
    }
    
    // Filtro para el buscador (Insensible a acentos y mayúsculas)
    var searchResults: [CampoModel] {
        if searchText.isEmpty { return [] }
        return camposViewModel.campos.filter {
            $0.nombre.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            CustomMapView(
                region: $region,
                isSatelliteView: $isSatelliteView,
                annotations: displayedAnnotations,
                selectedCampo: $selectedCampo,
                userTrackingMode: $userTrackingMode,
                route: $route,
                isNavigating: externalIsNavigating,
                onSelectCampo: { campo in
                    selectedCampo = campo
                },
                onShowSummary: { annotation in
                    prepareRouteSummary(for: annotation)
                },
                mapView: $mapView
            )
            .edgesIgnoringSafeArea(.all)
            .onTapGesture {
                // Cerrar buscador al tocar el mapa
                isSearching = false
                hideKeyboard()
            }

            // MARK: - Buscador Superior
            VStack(spacing: 8) {
                if !externalIsNavigating {
                    VStack(spacing: 0) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            
                            TextField("Buscar campo...", text: $searchText, onEditingChanged: { editing in
                                if editing {
                                    // Si se pincha en el buscador, cerramos cualquier chincheta abierta
                                    deselectAllAnnotations()
                                }
                                withAnimation { isSearching = editing }
                            })
                            .autocorrectionDisabled()
                            
                            if !searchText.isEmpty {
                                Button {
                                    searchText = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 25))
                        .overlay(RoundedRectangle(cornerRadius: 25).stroke(.white.opacity(0.3), lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        
                        // Lista de sugerencias (Altura dinámica ajustada al contenido)
                        if isSearching && !searchResults.isEmpty {
                            let results = Array(searchResults.prefix(5))
                            
                            VStack(alignment: .leading, spacing: 0) {
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 0) {
                                        ForEach(results) { campo in
                                            Button {
                                                selectCampoFromSearch(campo)
                                            } label: {
                                                HStack {
                                                    Image(systemName: "mappin.and.ellipse")
                                                        .foregroundColor(.green)
                                                    VStack(alignment: .leading) {
                                                        Text(campo.nombre)
                                                            .font(.system(size: 16, weight: .medium))
                                                            .foregroundColor(.primary)
                                                        Text(campo.localidad ?? "Galicia")
                                                            .font(.system(size: 13))
                                                            .foregroundColor(.secondary)
                                                    }
                                                    Spacer()
                                                }
                                                .padding(.vertical, 12)
                                                .padding(.horizontal, 16)
                                            }
                                            if campo.id != results.last?.id {
                                                Divider().padding(.horizontal, 16)
                                            }
                                        }
                                    }
                                }
                                // Altura máxima dinámica: se ajusta al número de elementos hasta un máximo de 4.5 filas
                                .frame(maxHeight: CGFloat(results.count) * 65)
                            }
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                } else if let route = route {
                    navigationHeader(route: route)
                }
                
                Spacer()
                
                if showRouteSummary, let route = route, let dest = pendingDestination {
                    routeSummaryCard(route: route, destination: dest)
                }
            }

            // MARK: - Botones Flotantes
            ZStack(alignment: .bottomTrailing) {
                Color.clear
                
                VStack(spacing: 12) {
                    if externalIsNavigating || showRouteSummary {
                        Button {
                            withAnimation {
                                stopNavigation()
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .bold))
                        }
                        .liquidGlass(color: .red)
                    }

                    Button {
                        withAnimation { isSatelliteView.toggle() }
                    } label: {
                        Image(systemName: isSatelliteView ? "map.fill" : "globe.europe.africa.fill")
                            .font(.system(size: 20))
                    }
                    .liquidGlass()

                    Button {
                        showFiltros = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 20, weight: .bold))
                    }
                    .liquidGlass()

                    Button {
                        toggleTracking()
                    } label: {
                        Image(systemName: trackingIcon)
                            .font(.system(size: 20, weight: .bold))
                    }
                    .liquidGlass(color: userTrackingMode == .none ? .primary : .blue)
                }
                .padding(.trailing, 16)
                .padding(.bottom, externalIsNavigating ? 40 : (showRouteSummary ? 220 : 40))
            }
        }
        .navigationBarHidden(true)
        .sheet(item: $selectedCampo) { campo in
            CampoDetalleView(campoID: campo.id)
        }
        .onAppear {
            applyFiltros()
        }
        .onChange(of: externalIsNavigating) { navigating in
            if !navigating {
                resetMapToInitialState()
            }
        }
    }

    // MARK: - Funciones de Búsqueda
    
    private func selectCampoFromSearch(_ campo: CampoModel) {
        // Si hay una ruta marcada o estamos navegando, la detenemos para mostrar todas las chinchetas de nuevo
        if showRouteSummary || externalIsNavigating {
            stopNavigation()
        }
        
        searchText = ""
        isSearching = false
        hideKeyboard()
        
        // Buscamos la chincheta correspondiente al campo seleccionado
        if let annotation = mapView?.annotations.compactMap({ $0 as? CampoAnnotation }).first(where: { $0.annotationItem.campo.id == campo.id }) {
            withAnimation {
                let span = MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                region = MKCoordinateRegion(center: annotation.coordinate, span: span)
                // Seleccionamos la chincheta para abrir su globo de información (callout)
                mapView?.selectAnnotation(annotation, animated: true)
                mapView?.setRegion(region, animated: true)
            }
        } else if let lat = campo.latitud, let lon = campo.longitud {
            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            withAnimation {
                region = MKCoordinateRegion(center: coord, span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005))
                mapView?.setRegion(region, animated: true)
            }
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        // Al ocultar el teclado desde el buscador, también aseguramos que se cierren las chinchetas
        deselectAllAnnotations()
    }

    private func deselectAllAnnotations() {
        if let mapView = self.mapView {
            for annotation in mapView.selectedAnnotations {
                mapView.deselectAnnotation(annotation, animated: true)
            }
        }
    }

    // MARK: - Lógica de Limpieza
    
    private func resetMapToInitialState() {
        if let mapView = self.mapView {
            mapView.removeOverlays(mapView.overlays)
        }
        
        withAnimation(.spring()) {
            self.route = nil
            self.showRouteSummary = false
            self.pendingDestination = nil
            self.userTrackingMode = .none
        }
        
        applyFiltros()
    }

    private func navigationHeader(route: MKRoute) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "arrow.up.right.circle.fill")
                    .font(.title)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading) {
                    let step = route.steps[currentStepIndex]
                    Text(step.instructions)
                        .font(.headline)
                        .lineLimit(2)
                    Text("En \(Int(step.distance)) metros")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                Button {
                    if currentStepIndex < route.steps.count - 1 {
                        currentStepIndex += 1
                    }
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(15)
        .padding()
        .shadow(radius: 5)
    }
    
    private func formatTime(seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes) min"
        } else {
            return "\(minutes) min"
        }
    }
    
    private func routeSummaryCard(route: MKRoute, destination: MapAnnotationItem) -> some View {
        Button {
            // Si se pincha en el contenedor de la ruta, abrimos la info
            selectedCampo = destination.campo
        } label: {
            VStack(spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(destination.title ?? "Destino")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        
                        HStack(spacing: 12) {
                            Label("\(String(format: "%.1f", route.distance / 1000)) km", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Label(formatTime(seconds: route.expectedTravelTime), systemImage: "clock.fill")
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(.green)
                        }
                    }
                    
                    Spacer()
                    
                    Button {
                        startNavigation()
                    } label: {
                        HStack {
                            Image(systemName: "location.fill")
                            Text("Ir")
                                .bold()
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(24)
            .background(.ultraThinMaterial)
            .cornerRadius(24)
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: -5)
        }
        .buttonStyle(PlainButtonStyle()) // Evita el efecto de resaltado de botón estándar
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func prepareRouteSummary(for destination: MapAnnotationItem) {
        let sourceLocation = mapView?.userLocation.location?.coordinate ?? mapView?.centerCoordinate
        guard let sourceCoord = sourceLocation else { return }
        
        mapView?.removeOverlays(mapView?.overlays ?? [])
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: sourceCoord))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination.coordinate))
        request.transportType = .automobile
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let directions = MKDirections(request: request)
            directions.calculate { response, error in
                if let _ = error { return }
                guard let route = response?.routes.first else { return }
                
                DispatchQueue.main.async {
                    withAnimation(.spring()) {
                        self.route = route
                        self.pendingDestination = destination
                        if !self.externalIsNavigating {
                            self.showRouteSummary = true
                        }
                    }
                    
                    if let mapView = self.mapView {
                        mapView.addOverlay(route.polyline)
                        if !self.externalIsNavigating {
                            mapView.setVisibleMapRect(route.polyline.boundingMapRect,
                                                     edgePadding: UIEdgeInsets(top: 80, left: 40, bottom: 320, right: 40),
                                                     animated: true)
                        }
                    }
                }
            }
        }
    }
    
    private func startNavigation() {
        withAnimation(.spring()) {
            self.showRouteSummary = false
            self.externalIsNavigating = true
            self.currentStepIndex = 0
            self.userTrackingMode = .followWithHeading
        }
    }
    
    private func stopNavigation() {
        self.externalIsNavigating = false
        self.showRouteSummary = false
        self.route = nil
        resetMapToInitialState()
    }

    private var trackingIcon: String {
        switch userTrackingMode {
        case .none: return "location"
        case .follow: return "location.fill"
        case .followWithHeading: return "location.north.line.fill"
        @unknown default: return "location"
        }
    }

    private func toggleTracking() {
        if userTrackingMode == .none {
            userTrackingMode = .follow
        } else if userTrackingMode == .follow {
            userTrackingMode = .followWithHeading
        } else {
            userTrackingMode = .none
        }
    }
    
    private func applyFiltros() {
        filteredCampos = camposViewModel.campos
        updateAnnotations()
    }
    
    private func updateAnnotations() {
        var newAnnotations: [MapAnnotationItem] = []
        for campo in filteredCampos {
            if let lat = campo.latitud, let lon = campo.longitud {
                let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                newAnnotations.append(MapAnnotationItem(
                    coordinate: coordinate,
                    title: campo.nombre,
                    subtitle: "Campo de fútbol",
                    campo: campo,
                    isFromManualCoordinates: true
                ))
            }
        }
        self.annotationItems = newAnnotations
    }
}

// MARK: - CustomMapView

struct CustomMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var isSatelliteView: Bool
    var annotations: [MapAnnotationItem]
    @Binding var selectedCampo: CampoModel?
    @Binding var userTrackingMode: MKUserTrackingMode
    @Binding var route: MKRoute?
    var isNavigating: Bool
    let onSelectCampo: (CampoModel) -> Void
    let onShowSummary: (MapAnnotationItem) -> Void
    @Binding var mapView: MKMapView?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: "CampoAnnotation")
        mapView.setRegion(region, animated: false)
        
        // Configuración de la brújula manual para reposicionarla
        mapView.showsCompass = false // Ocultamos la nativa que suele quedar arriba a la derecha
        let compass = MKCompassButton(mapView: mapView)
        compass.compassVisibility = .adaptive
        compass.translatesAutoresizingMaskIntoConstraints = false
        mapView.addSubview(compass)
        
        NSLayoutConstraint.activate([
            // La posicionamos en el margen derecho, pero bajando 90 puntos para evitar el buscador
            compass.trailingAnchor.constraint(equalTo: mapView.trailingAnchor, constant: -12),
            compass.topAnchor.constraint(equalTo: mapView.safeAreaLayoutGuide.topAnchor, constant: 90)
        ])
        
        DispatchQueue.main.async {
            self.mapView = mapView
        }
        
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.mapType = isSatelliteView ? .satellite : .standard
        if uiView.userTrackingMode != userTrackingMode {
            uiView.setUserTrackingMode(userTrackingMode, animated: true)
        }

        let currentAnnos = uiView.annotations.compactMap { $0 as? CampoAnnotation }
        if currentAnnos.count != annotations.count || (annotations.count == 1 && currentAnnos.first?.annotationItem.id != annotations.first?.id) {
            uiView.removeAnnotations(uiView.annotations)
            let newAnnos = annotations.map { CampoAnnotation(annotationItem: $0) }
            uiView.addAnnotations(newAnnos)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: CustomMapView
        private var lastRecalculationDate = Date()
        private var currentDestination: MapAnnotationItem?

        init(_ parent: CustomMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            if parent.isNavigating {
                let region = MKCoordinateRegion(center: userLocation.coordinate,
                                               latitudinalMeters: 300,
                                               longitudinalMeters: 300)
                mapView.setRegion(region, animated: true)
                checkIfRecalculationNeeded(userLocation: userLocation.coordinate)
            }
        }
        
        private func checkIfRecalculationNeeded(userLocation: CLLocationCoordinate2D) {
            guard parent.isNavigating, let currentRoute = parent.route, let destination = currentDestination else { return }
            if Date().timeIntervalSince(lastRecalculationDate) < 15 { return }
            
            let userPoint = MKMapPoint(userLocation)
            var minDistance = Double.greatestFiniteMagnitude
            let points = currentRoute.polyline.points()
            for i in 0..<currentRoute.polyline.pointCount {
                let distance = points[i].distance(to: userPoint)
                if distance < minDistance { minDistance = distance }
            }
            
            if minDistance > 80 {
                lastRecalculationDate = Date()
                DispatchQueue.main.async {
                    self.parent.onShowSummary(destination)
                }
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            guard let campoAnno = annotation as? CampoAnnotation else { return nil }
            let identifier = "CampoAnnotation"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            
            if view == nil {
                view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            } else {
                view?.annotation = annotation
            }
            
            view?.markerTintColor = .systemGreen
            view?.canShowCallout = true
            view?.titleVisibility = .visible
            view?.displayPriority = .defaultLow
            
            let calloutContainer = UIView()
            calloutContainer.translatesAutoresizingMaskIntoConstraints = false
            calloutContainer.backgroundColor = .clear
            
            let stackView = UIStackView()
            stackView.axis = .vertical
            stackView.spacing = 14
            stackView.alignment = .center
            stackView.distribution = .fill
            stackView.translatesAutoresizingMaskIntoConstraints = false
            
            let titleLabel = UILabel()
            titleLabel.text = campoAnno.annotationItem.title?.uppercased() ?? "CAMPO SIN NOMBRE"
            titleLabel.font = .systemFont(ofSize: 14, weight: .black)
            titleLabel.textColor = .label
            titleLabel.textAlignment = .center
            titleLabel.numberOfLines = 2
            
            let detailBtn = UIButton(type: .system)
            var detailConfig = UIButton.Configuration.plain()
            detailConfig.title = "Detalles"
            detailConfig.image = UIImage(systemName: "info.circle.fill")
            detailConfig.imagePadding = 10
            detailConfig.baseForegroundColor = .systemBlue
            detailConfig.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
            detailBtn.configuration = detailConfig
            detailBtn.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.08)
            detailBtn.layer.cornerRadius = 14
            detailBtn.layer.borderWidth = 0.5
            detailBtn.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.2).cgColor
            detailBtn.tag = 1
            detailBtn.addTarget(self, action: #selector(calloutAction(_:)), for: .touchUpInside)
            
            let routeBtn = UIButton(type: .system)
            var routeConfig = UIButton.Configuration.filled()
            routeConfig.title = "Cómo llegar"
            routeConfig.image = UIImage(systemName: "location.north.fill")
            routeConfig.imagePadding = 10
            routeConfig.baseBackgroundColor = .systemGreen
            routeConfig.cornerStyle = .capsule
            routeConfig.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20)
            routeBtn.configuration = routeConfig
            routeBtn.layer.shadowColor = UIColor.systemGreen.cgColor
            routeBtn.layer.shadowOpacity = 0.2
            routeBtn.layer.shadowOffset = CGSize(width: 0, height: 4)
            routeBtn.layer.shadowRadius = 8
            routeBtn.tag = 2
            routeBtn.addTarget(self, action: #selector(calloutAction(_:)), for: .touchUpInside)
            
            stackView.addArrangedSubview(titleLabel)
            stackView.addArrangedSubview(detailBtn)
            stackView.addArrangedSubview(routeBtn)
            calloutContainer.addSubview(stackView)
            
            NSLayoutConstraint.activate([
                stackView.centerXAnchor.constraint(equalTo: calloutContainer.centerXAnchor),
                stackView.centerYAnchor.constraint(equalTo: calloutContainer.centerYAnchor),
                stackView.topAnchor.constraint(equalTo: calloutContainer.topAnchor, constant: 12),
                stackView.bottomAnchor.constraint(equalTo: calloutContainer.bottomAnchor, constant: -12),
                stackView.leadingAnchor.constraint(equalTo: calloutContainer.leadingAnchor, constant: 10),
                stackView.trailingAnchor.constraint(equalTo: calloutContainer.trailingAnchor, constant: -10),
                
                titleLabel.widthAnchor.constraint(equalTo: stackView.widthAnchor),
                detailBtn.widthAnchor.constraint(equalTo: stackView.widthAnchor, multiplier: 1.0),
                routeBtn.widthAnchor.constraint(equalTo: stackView.widthAnchor, multiplier: 1.0),
                
                calloutContainer.widthAnchor.constraint(equalToConstant: 220)
            ])
            
            view?.detailCalloutAccessoryView = calloutContainer
            
            return view
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let annotation = view.annotation as? MKPointAnnotation {
                annotation.title = ""
            }
        }
        
        func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
            if let annotation = view.annotation as? CampoAnnotation {
                annotation.title = annotation.annotationItem.title
            }
        }
        
        @objc func calloutAction(_ sender: UIButton) {
            guard let mapView = self.parent.mapView ?? sender.superview?.superview?.superview as? MKMapView,
                  let annotation = mapView.selectedAnnotations.first as? CampoAnnotation else {
                return
            }
            
            if sender.tag == 1 {
                parent.onSelectCampo(annotation.annotationItem.campo)
            } else if sender.tag == 2 {
                mapView.deselectAnnotation(annotation, animated: true)
                DispatchQueue.main.async {
                    self.currentDestination = annotation.annotationItem
                    self.parent.onShowSummary(annotation.annotationItem)
                }
            }
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 6
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer()
        }
    }
}
