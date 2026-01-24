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
    let isVisited: Bool
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

// Identificador de cluster para agrupar anotaciones
extension CampoAnnotation {
    override var clusteringIdentifier: String? {
        get { "CampoCluster" }
        set { }
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
    @EnvironmentObject var authViewModel: AuthViewModel

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
    @State private var distanceToNextStep: Double = 0
    @State private var showRouteSummary: Bool = false
    @State private var pendingDestination: MapAnnotationItem?

    @State private var userTrackingMode: MKUserTrackingMode = .none
    @State private var mapView: MKMapView?

    // Campos visitados por el usuario
    @State private var visitedCampoIds: Set<UUID> = []

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

    // Filtro para el buscador optimizado (Tolerante a errores, acentos y mayúsculas)
    var searchResults: [CampoModel] {
        if searchText.isEmpty { return [] }

        // No buscar si el texto es muy corto (menos de 2 caracteres)
        guard searchText.count >= 2 else { return [] }

        // Normalizar texto de búsqueda
        let normalizedSearch = searchText
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

        // 1. Búsqueda rápida: coincidencia exacta en nombre o localidad
        let exactMatches = camposViewModel.campos.filter { campo in
            let normalizedNombre = campo.nombre
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            let normalizedLocalidad = (campo.localidad ?? "")
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

            return normalizedNombre.contains(normalizedSearch) || normalizedLocalidad.contains(normalizedSearch)
        }

        // Si tenemos suficientes resultados exactos, devolver solo esos (ordenados por relevancia)
        if exactMatches.count >= 5 {
            return exactMatches.sorted { campo1, campo2 in
                let nombre1 = campo1.nombre.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                let nombre2 = campo2.nombre.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

                // Priorizar si el nombre empieza con la búsqueda
                let starts1 = nombre1.hasPrefix(normalizedSearch)
                let starts2 = nombre2.hasPrefix(normalizedSearch)
                if starts1 != starts2 { return starts1 }

                // Si no, ordenar por longitud (más cortos primero)
                return nombre1.count < nombre2.count
            }
        }

        // 2. Si no hay suficientes resultados exactos, hacer búsqueda fuzzy solo en los primeros 100 campos
        let camposToSearch = Array(camposViewModel.campos.prefix(100))
        let fuzzyMatches = camposToSearch.compactMap { campo -> (campo: CampoModel, score: Double)? in
            let normalizedNombre = campo.nombre
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            let normalizedLocalidad = (campo.localidad ?? "")
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

            // Usar solo fuzzyMatch simplificado (sin Levenshtein completo)
            let matchesNombre = simpleFuzzyMatch(search: normalizedSearch, target: normalizedNombre)
            let matchesLocalidad = simpleFuzzyMatch(search: normalizedSearch, target: normalizedLocalidad)

            if matchesNombre || matchesLocalidad {
                // Score simple basado en si empieza con el texto de búsqueda
                let score: Double
                if normalizedNombre.hasPrefix(normalizedSearch) {
                    score = 1.0
                } else if normalizedLocalidad.hasPrefix(normalizedSearch) {
                    score = 0.9
                } else if normalizedNombre.contains(normalizedSearch) {
                    score = 0.8
                } else if normalizedLocalidad.contains(normalizedSearch) {
                    score = 0.7
                } else {
                    score = 0.6
                }
                return (campo, score)
            }
            return nil
        }

        // Combinar resultados y ordenar
        let allMatches = (exactMatches.map { ($0, 1.0) } + fuzzyMatches)
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }

        // Eliminar duplicados manteniendo el orden
        var seen = Set<UUID>()
        return allMatches.filter { campo in
            if seen.contains(campo.id) {
                return false
            } else {
                seen.insert(campo.id)
                return true
            }
        }
    }

    // Búsqueda fuzzy simplificada (sin Levenshtein)
    private func simpleFuzzyMatch(search: String, target: String) -> Bool {
        if search.isEmpty { return true }
        if target.isEmpty { return false }

        // Verificar si todas las palabras de búsqueda están en el target
        let searchWords = search.split(separator: " ").map(String.init)
        return searchWords.allSatisfy { word in
            target.contains(word)
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
                currentStepIndex: $currentStepIndex,
                distanceToNextStep: $distanceToNextStep,
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
                    .liquidGlass(color: trackingIconColor)
                    .overlay(
                        // Indicador de orientación activa (detrás del botón)
                        userTrackingMode == .followWithHeading ?
                        Circle()
                            .stroke(trackingIconColor, lineWidth: 2)
                            .frame(width: 50, height: 50)
                            .opacity(0.6) : nil
                    )
                }
                .padding(.trailing, 16)
                .padding(.bottom, externalIsNavigating ? 40 : (showRouteSummary ? 280 : 40))
            }
        }
        .navigationBarHidden(true)
        .sheet(item: $selectedCampo) { campo in
            CampoDetalleView(campoID: campo.id)
        }
        .onAppear {
            applyFiltros()
            loadVisitedCampos()
        }
        .onChange(of: externalIsNavigating) { wasNavigating, navigating in
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
            // 🎯 Animación suave de zoom y selección
            withAnimation(.easeInOut(duration: 0.5)) {
                let span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                region = MKCoordinateRegion(center: annotation.coordinate, span: span)
            }

            // Aplicar región primero
            mapView?.setRegion(region, animated: true)

            // Seleccionar annotation con delay para mejor visual
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.mapView?.selectAnnotation(annotation, animated: true)
            }
        } else if let lat = campo.latitud, let lon = campo.longitud {
            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            withAnimation(.easeInOut(duration: 0.5)) {
                region = MKCoordinateRegion(center: coord, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
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
            self.currentStepIndex = 0
            self.distanceToNextStep = 0
        }

        applyFiltros()
    }

    private func navigationHeader(route: MKRoute) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // 🎯 Icono de dirección más grande y animado
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 50, height: 50)

                    Image(systemName: directionIcon(for: route.steps[currentStepIndex]))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    let step = route.steps[currentStepIndex]
                    Text(step.instructions.isEmpty ? "Continúa recto" : step.instructions)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    // Mostrar distancia en tiempo real con mejor formato
                    let displayDistance = distanceToNextStep > 0 ? distanceToNextStep : step.distance
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundColor(.green)

                        if displayDistance >= 1000 {
                            Text("\(String(format: "%.1f", displayDistance / 1000)) km")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        } else {
                            Text("\(Int(displayDistance)) m")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Spacer()

                // Contador de pasos
                VStack(spacing: 4) {
                    Text("\(currentStepIndex + 1)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.blue)
                    Text("de \(route.steps.count)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
    }

    // Helper para elegir icono según el tipo de maniobra
    private func directionIcon(for step: MKRoute.Step) -> String {
        let instruction = step.instructions.lowercased()
        if instruction.contains("gira a la derecha") || instruction.contains("derecha") {
            return "arrow.turn.up.right"
        } else if instruction.contains("gira a la izquierda") || instruction.contains("izquierda") {
            return "arrow.turn.up.left"
        } else if instruction.contains("continúa") || instruction.contains("recto") {
            return "arrow.up"
        } else if instruction.contains("rotonda") {
            return "arrow.triangle.turn.up.right.circle"
        } else {
            return "arrow.up.circle.fill"
        }
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
        VStack(spacing: 0) {
            // 📍 Header con nombre del destino
            Button {
                selectedCampo = destination.campo
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.green)
                                .font(.title3)

                            Text(destination.title ?? "Destino")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.primary)
                        }

                        Text(destination.campo.localidad ?? "Galicia")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding(20)
            }
            .buttonStyle(PlainButtonStyle())

            Divider()
                .padding(.horizontal, 20)

            // 📊 Información de la ruta
            HStack(spacing: 20) {
                // Distancia
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "road.lanes")
                            .foregroundColor(.blue)
                        Text("\(String(format: "%.1f", route.distance / 1000))")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    Text("kilómetros")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 40)

                // Tiempo estimado
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.green)
                        Text(formatTimeShort(seconds: route.expectedTravelTime))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    Text("minutos aprox.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)

            // 🚀 Botón de iniciar
            Button {
                startNavigation()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Iniciar navegación")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: -8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func formatTimeShort(seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(minutes)"
        }
    }

    private func prepareRouteSummary(for destination: MapAnnotationItem) {
        guard let userLocation = mapView?.userLocation.location?.coordinate else {
            return
        }

        mapView?.removeOverlays(mapView?.overlays ?? [])

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: userLocation))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination.coordinate))
        request.transportType = .automobile

        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            if let error = error {
                print("❌ Error calculando ruta: \(error.localizedDescription)")
                return
            }
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

                print("✅ Ruta \(self.externalIsNavigating ? "recalculada" : "calculada") - Distancia: \(String(format: "%.1f", route.distance / 1000)) km, Pasos: \(route.steps.count)")
            }
        }
    }
    
    private func startNavigation() {
        print("🚀 Iniciando navegación...")
        print("📍 Ubicación del usuario: \(mapView?.userLocation.location?.coordinate.latitude ?? 0), \(mapView?.userLocation.location?.coordinate.longitude ?? 0)")
        print("🎯 Destino: \(pendingDestination?.title ?? "desconocido")")

        withAnimation(.spring()) {
            self.showRouteSummary = false
            self.externalIsNavigating = true
            self.currentStepIndex = 0
            self.distanceToNextStep = 0
            self.userTrackingMode = .followWithHeading
        }

        // Pasar el destino al Coordinator para que pueda recalcular rutas
        if let mapView = self.mapView, let destination = pendingDestination {
            print("✅ Configurando destino en Coordinator")
            (mapView.delegate as? CustomMapView.Coordinator)?.setCurrentDestination(destination)
        }

        print("🧭 User tracking mode: \(userTrackingMode == .followWithHeading ? "followWithHeading" : "otro")")
    }
    
    private func stopNavigation() {
        print("🛑 Deteniendo navegación...")
        self.externalIsNavigating = false
        self.showRouteSummary = false
        self.route = nil
        self.currentStepIndex = 0
        self.distanceToNextStep = 0

        // Detener actualizaciones de ubicación
        if let mapView = self.mapView {
            (mapView.delegate as? CustomMapView.Coordinator)?.stopLocationUpdates()
        }

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

    private var trackingIconColor: Color {
        switch userTrackingMode {
        case .none: return .primary
        case .follow: return .blue
        case .followWithHeading: return .green
        @unknown default: return .primary
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
                let isVisited = visitedCampoIds.contains(campo.id)
                newAnnotations.append(MapAnnotationItem(
                    coordinate: coordinate,
                    title: campo.nombre,
                    subtitle: "Campo de fútbol",
                    campo: campo,
                    isFromManualCoordinates: true,
                    isVisited: isVisited
                ))
            }
        }
        self.annotationItems = newAnnotations
    }

    private func loadVisitedCampos() {
        guard let userId = authViewModel.user?.id.uuidString else { return }

        Task {
            do {
                let response = try await supabase.from("visitas")
                    .select("id_campo")
                    .eq("id_usuario", value: userId)
                    .execute()

                if let jsonData = try? JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] {
                    let ids = jsonData.compactMap { dict -> UUID? in
                        guard let idString = dict["id_campo"] as? String else { return nil }
                        return UUID(uuidString: idString)
                    }
                    visitedCampoIds = Set(ids)
                    updateAnnotations()
                }
            } catch {
                Logger.error("Error loading visited campos: \(error.localizedDescription)")
            }
        }
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
    @Binding var currentStepIndex: Int
    @Binding var distanceToNextStep: Double
    var isNavigating: Bool
    let onSelectCampo: (CampoModel) -> Void
    let onShowSummary: (MapAnnotationItem) -> Void
    @Binding var mapView: MKMapView?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.showsTraffic = false
        mapView.showsBuildings = true
        mapView.showsScale = true
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

        // Siempre usar tracking nativo de MapKit (sin restricciones)
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

    class Coordinator: NSObject, MKMapViewDelegate, CLLocationManagerDelegate {
        var parent: CustomMapView
        private var lastRecalculationDate = Date()
        private var currentDestination: MapAnnotationItem?
        private var locationManager: CLLocationManager?

        init(_ parent: CustomMapView) {
            self.parent = parent
            super.init()
            setupLocationManager()
        }

        private func setupLocationManager() {
            locationManager = CLLocationManager()
            locationManager?.delegate = self
            locationManager?.desiredAccuracy = kCLLocationAccuracyBestForNavigation
            locationManager?.distanceFilter = 5 // Actualizar cada 5 metros
            locationManager?.activityType = .automotiveNavigation
            locationManager?.allowsBackgroundLocationUpdates = true
            locationManager?.pausesLocationUpdatesAutomatically = false
            print("📱 Location Manager configurado para navegación")
        }

        func setCurrentDestination(_ destination: MapAnnotationItem) {
            self.currentDestination = destination
            // Iniciar actualizaciones de ubicación para navegación
            print("🚀 Iniciando actualizaciones de ubicación continuas...")
            locationManager?.startUpdatingLocation()
            locationManager?.startUpdatingHeading()
        }

        func stopLocationUpdates() {
            print("🛑 Deteniendo actualizaciones de ubicación")
            locationManager?.stopUpdatingLocation()
            locationManager?.stopUpdatingHeading()
        }

        // MARK: - CLLocationManagerDelegate
        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let location = locations.last else { return }
            print("📍 CLLocationManager actualizó ubicación: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            print("   Precisión: \(location.horizontalAccuracy)m, Velocidad: \(location.speed)m/s")

            if parent.isNavigating {
                print("✅ Navegando - procesando ubicación")

                // Actualizar paso actual y distancia en tiempo real
                updateCurrentStep(userLocation: location.coordinate)

                // Verificar si necesitamos recalcular la ruta
                checkIfRecalculationNeeded(userLocation: location.coordinate)
            }
        }

        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            print("❌ Error en location manager: \(error.localizedDescription)")
        }

        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            // ✅ OPTIMIZACIÓN: Ya no procesamos aquí porque CLLocationManager lo hace mejor
            // Este método se mantiene para compatibilidad pero no duplica lógica
        }
        
        private func updateCurrentStep(userLocation: CLLocationCoordinate2D) {
            guard let currentRoute = parent.route, parent.currentStepIndex < currentRoute.steps.count else { return }

            let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)

            // Calcular la distancia total recorrida hasta el paso actual
            var distanceToStepStart: CLLocationDistance = 0
            for i in 0..<parent.currentStepIndex {
                distanceToStepStart += currentRoute.steps[i].distance
            }

            // Encontrar el punto más cercano en la polyline de la ruta
            let userPoint = MKMapPoint(userLocation)
            let polyline = currentRoute.polyline
            let points = polyline.points()
            var closestDistance = Double.greatestFiniteMagnitude
            var closestIndex = 0

            for i in 0..<polyline.pointCount {
                let distance = points[i].distance(to: userPoint)
                if distance < closestDistance {
                    closestDistance = distance
                    closestIndex = i
                }
            }

            // Calcular la distancia desde el usuario hasta el final del paso actual
            let currentStep = currentRoute.steps[parent.currentStepIndex]
            var remainingDistanceInStep = currentStep.distance

            // Calcular qué fracción del paso hemos completado
            if closestIndex < polyline.pointCount - 1 {
                var distanceAlongPolyline: CLLocationDistance = 0
                for i in 0..<closestIndex {
                    if i + 1 < polyline.pointCount {
                        let point1 = points[i]
                        let point2 = points[i + 1]
                        distanceAlongPolyline += point1.distance(to: point2)
                    }
                }

                let distanceCoveredInStep = max(0, distanceAlongPolyline - distanceToStepStart)
                remainingDistanceInStep = max(0, currentStep.distance - distanceCoveredInStep)
            }

            // Actualizar la distancia en el UI
            DispatchQueue.main.async {
                self.parent.distanceToNextStep = remainingDistanceInStep
            }

            // Avanzar al siguiente paso si hemos completado el 90% del paso actual
            if remainingDistanceInStep < currentStep.distance * 0.1 && parent.currentStepIndex < currentRoute.steps.count - 1 {
                DispatchQueue.main.async {
                    withAnimation {
                        self.parent.currentStepIndex += 1
                    }
                }
            }
        }

        private func checkIfRecalculationNeeded(userLocation: CLLocationCoordinate2D) {
            guard parent.isNavigating, let currentRoute = parent.route, let destination = currentDestination else {
                print("⚠️ No se puede verificar recalculación: isNavigating=\(parent.isNavigating), route=\(parent.route != nil), destination=\(currentDestination != nil)")
                return
            }

            // Reducir tiempo entre recalculaciones de 15 a 5 segundos
            let timeSinceLastRecalc = Date().timeIntervalSince(lastRecalculationDate)
            if timeSinceLastRecalc < 5 {
                print("⏳ Muy pronto para recalcular (pasaron \(String(format: "%.1f", timeSinceLastRecalc))s)")
                return
            }

            let userPoint = MKMapPoint(userLocation)
            var minDistance = Double.greatestFiniteMagnitude
            let points = currentRoute.polyline.points()
            for i in 0..<currentRoute.polyline.pointCount {
                let distance = points[i].distance(to: userPoint)
                if distance < minDistance { minDistance = distance }
            }

            print("📏 Distancia mínima a la ruta: \(String(format: "%.1f", minDistance))m")

            // Recalcular si te desvías más de 30 metros de la ruta (antes 50m)
            if minDistance > 30 {
                print("🔄 RECALCULANDO RUTA - Usuario se desvió \(String(format: "%.1f", minDistance))m de la ruta")
                lastRecalculationDate = Date()
                DispatchQueue.main.async {
                    // Resetear el índice del paso actual al recalcular
                    self.parent.currentStepIndex = 0
                    self.parent.distanceToNextStep = 0
                    self.parent.onShowSummary(destination)
                }
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }

            // Manejar cluster annotations
            if let cluster = annotation as? MKClusterAnnotation {
                let identifier = "ClusterAnnotation"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

                if view == nil {
                    view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                } else {
                    view?.annotation = annotation
                }

                view?.markerTintColor = .systemBlue
                view?.glyphText = "\(cluster.memberAnnotations.count)"
                view?.displayPriority = .required
                view?.titleVisibility = .hidden
                view?.subtitleVisibility = .hidden

                return view
            }

            guard let campoAnno = annotation as? CampoAnnotation else { return nil }
            let identifier = "CampoAnnotation"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

            if view == nil {
                view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            } else {
                view?.annotation = annotation
            }

            // 🎨 Marker personalizado con efecto glow
            // Color diferente si ya está visitado
            if campoAnno.annotationItem.isVisited {
                view?.markerTintColor = .systemOrange
                view?.glyphImage = UIImage(systemName: "checkmark.circle.fill")
            } else {
                view?.markerTintColor = .systemGreen
                view?.glyphImage = UIImage(systemName: "soccerball")
            }
            view?.canShowCallout = true
            view?.displayPriority = .required
            view?.animatesWhenAdded = true
            view?.clusteringIdentifier = "CampoCluster"

            // ✅ FIX: Eliminar el título del annotation para evitar espacio vacío
            campoAnno.title = nil
            campoAnno.subtitle = nil

            // 🎨 NUEVO DISEÑO: Card moderno con glassmorphism
            let calloutContainer = UIView()
            calloutContainer.translatesAutoresizingMaskIntoConstraints = false
            calloutContainer.layer.cornerRadius = 20
            calloutContainer.layer.cornerCurve = .continuous
            calloutContainer.clipsToBounds = true

            // Efecto blur de fondo
            let blurEffect = UIBlurEffect(style: .systemUltraThinMaterial)
            let blurView = UIVisualEffectView(effect: blurEffect)
            blurView.translatesAutoresizingMaskIntoConstraints = false
            blurView.layer.cornerRadius = 20
            blurView.layer.cornerCurve = .continuous
            blurView.clipsToBounds = true
            calloutContainer.addSubview(blurView)

            // Stack principal vertical
            let mainStack = UIStackView()
            mainStack.axis = .vertical
            mainStack.spacing = 12
            mainStack.alignment = .fill
            mainStack.distribution = .fill
            mainStack.translatesAutoresizingMaskIntoConstraints = false

            // Título del campo
            let titleLabel = UILabel()
            titleLabel.text = campoAnno.annotationItem.title ?? "Campo sin nombre"
            titleLabel.font = .systemFont(ofSize: 16, weight: .bold)
            titleLabel.textColor = .label
            titleLabel.textAlignment = .center
            titleLabel.numberOfLines = 2

            // Stack horizontal para los botones
            let buttonsStack = UIStackView()
            buttonsStack.axis = .horizontal
            buttonsStack.spacing = 10
            buttonsStack.alignment = .fill
            buttonsStack.distribution = .fillEqually
            buttonsStack.translatesAutoresizingMaskIntoConstraints = false

            // 🔵 Botón Info (más compacto)
            let detailBtn = createCalloutButton(
                icon: "info.circle.fill",
                color: .systemBlue,
                tag: 1
            )

            // 🟢 Botón Ruta (más compacto)
            let routeBtn = createCalloutButton(
                icon: "arrow.triangle.turn.up.right.diamond.fill",
                color: .systemGreen,
                tag: 2
            )

            buttonsStack.addArrangedSubview(detailBtn)
            buttonsStack.addArrangedSubview(routeBtn)

            mainStack.addArrangedSubview(titleLabel)
            mainStack.addArrangedSubview(buttonsStack)

            calloutContainer.addSubview(mainStack)

            // Border sutil para profundidad
            calloutContainer.layer.borderWidth = 1
            calloutContainer.layer.borderColor = UIColor.separator.withAlphaComponent(0.2).cgColor

            // Sombra elegante
            calloutContainer.layer.shadowColor = UIColor.black.cgColor
            calloutContainer.layer.shadowOpacity = 0.12
            calloutContainer.layer.shadowOffset = CGSize(width: 0, height: 8)
            calloutContainer.layer.shadowRadius = 16

            NSLayoutConstraint.activate([
                // Blur view
                blurView.topAnchor.constraint(equalTo: calloutContainer.topAnchor),
                blurView.leadingAnchor.constraint(equalTo: calloutContainer.leadingAnchor),
                blurView.trailingAnchor.constraint(equalTo: calloutContainer.trailingAnchor),
                blurView.bottomAnchor.constraint(equalTo: calloutContainer.bottomAnchor),

                // Main stack
                mainStack.topAnchor.constraint(equalTo: calloutContainer.topAnchor, constant: 14),
                mainStack.leadingAnchor.constraint(equalTo: calloutContainer.leadingAnchor, constant: 14),
                mainStack.trailingAnchor.constraint(equalTo: calloutContainer.trailingAnchor, constant: -14),
                mainStack.bottomAnchor.constraint(equalTo: calloutContainer.bottomAnchor, constant: -14),

                // Botones con altura fija
                buttonsStack.heightAnchor.constraint(equalToConstant: 44),

                // Ancho del container
                calloutContainer.widthAnchor.constraint(equalToConstant: 240)
            ])

            view?.detailCalloutAccessoryView = calloutContainer

            return view
        }

        // 🎨 Helper para crear botones del callout
        private func createCalloutButton(icon: String, color: UIColor, tag: Int) -> UIButton {
            let button = UIButton(type: .system)
            button.translatesAutoresizingMaskIntoConstraints = false

            // Configuración visual
            var config = UIButton.Configuration.filled()
            config.image = UIImage(systemName: icon)
            config.baseBackgroundColor = color
            config.baseForegroundColor = .white
            config.cornerStyle = .medium
            config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
            config.imagePlacement = .all

            button.configuration = config
            button.tag = tag
            button.addTarget(self, action: #selector(calloutAction(_:)), for: .touchUpInside)

            // Efecto de sombra
            button.layer.shadowColor = color.cgColor
            button.layer.shadowOpacity = 0.3
            button.layer.shadowOffset = CGSize(width: 0, height: 4)
            button.layer.shadowRadius = 8

            // Animación al tocar
            button.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)
            button.addTarget(self, action: #selector(buttonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])

            return button
        }

        @objc private func buttonTouchDown(_ sender: UIButton) {
            UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseInOut) {
                sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            }
        }

        @objc private func buttonTouchUp(_ sender: UIButton) {
            UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseInOut) {
                sender.transform = .identity
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
                // Guardar el destino antes de calcular la ruta
                self.currentDestination = annotation.annotationItem
                DispatchQueue.main.async {
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
