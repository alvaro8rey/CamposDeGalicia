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
    var clusteringIdentifier: String? {
        get { "CampoCluster" }
        set { }
    }
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
    @EnvironmentObject var localizationManager: LocalizationManager
    @EnvironmentObject var geofenceManager: GeofenceManager

    @Binding var externalIsNavigating: Bool

    @State private var region: MKCoordinateRegion
    @State private var isSatelliteView: Bool = false
    @State private var selectedCampo: CampoModel? = nil
    @State private var annotationItems: [MapAnnotationItem] = []

    // Propiedades de búsqueda
    @State private var searchText: String = ""
    @State private var isSearching: Bool = false

    // Propiedades para Rutas e Indicaciones
    @State private var route: MKRoute?
    @State private var currentStepIndex: Int = 0
    @State private var distanceToNextStep: Double = 0
    @State private var showRouteSummary: Bool = false
    @State private var pendingDestination: MapAnnotationItem?
    @State private var traveledCoordinates: [CLLocationCoordinate2D] = [] // Para rastrear el camino recorrido

    @State private var userTrackingMode: MKUserTrackingMode = .none
    @State private var mapView: MKMapView?

    // Campos visitados por el usuario
    @State private var visitedCampoIds: Set<UUID> = []

    // Filtro para mostrar solo visitados
    @State private var showOnlyVisited: Bool = false

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
                isNavigating: $externalIsNavigating,
                visitedCampoIds: $visitedCampoIds,
                userId: authViewModel.user?.id.uuidString,
                onSelectCampo: { campo in
                    selectedCampo = campo
                },
                onShowSummary: { annotation in
                    prepareRouteSummary(for: annotation)
                },
                onUpdateAnnotations: {
                    updateAnnotations()
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

                            TextField(L(.mapSearchPlaceholder), text: $searchText, onEditingChanged: { editing in
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
                            HapticFeedback.light()
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
                        HapticFeedback.light()
                        withAnimation { isSatelliteView.toggle() }
                    } label: {
                        Image(systemName: isSatelliteView ? "map.fill" : "globe.europe.africa.fill")
                            .font(.system(size: 20))
                    }
                    .liquidGlass()

                    Button {
                        HapticFeedback.light()
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
                .padding(.bottom, externalIsNavigating ? 60 : (showRouteSummary ? 280 : 60))
            }

            // MARK: - Botón de Filtro Visitados (esquina superior izquierda, discreto)
            if !externalIsNavigating && !showRouteSummary && !isSearching {
                VStack {
                    HStack {
                        Button {
                            HapticFeedback.light()
                            withAnimation {
                                showOnlyVisited.toggle()
                                applyFiltros()
                            }
                        } label: {
                            Image(systemName: showOnlyVisited ? "checkmark.circle.fill" : "checkmark.circle")
                                .font(.system(size: 18))
                        }
                        .liquidGlass(color: showOnlyVisited ? .orange : .primary)
                        .padding(.leading, 16)
                        .padding(.top, 80)
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(item: $selectedCampo) { campo in
            CampoDetalleView(campoID: campo.id)
                .environmentObject(camposViewModel)
                .environmentObject(authViewModel)
                .environmentObject(geofenceManager)
                .environmentObject(localizationManager)
        }
        .onAppear {
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
            self.traveledCoordinates = [] // Limpiar coordenadas recorridas
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
                        .rotationEffect(.degrees(0))
                        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: currentStepIndex)
                }

                VStack(alignment: .leading, spacing: 4) {
                    // 🎯 Lógica mejorada: mostrar "sigue recto" solo si la maniobra está lejos
                    let displayInstruction = getDisplayInstruction(for: route)

                    Text(displayInstruction)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .transition(.opacity.combined(with: .move(edge: .leading)))

                    // Mostrar distancia restante en tiempo real
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundColor(.green)

                        if distanceToNextStep >= 1000 {
                            Text(String(format: "En %.1f km", distanceToNextStep / 1000))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                                .transition(.opacity)
                        } else if distanceToNextStep > 0 {
                            Text(String(format: "En %d m", Int(distanceToNextStep)))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                                .transition(.opacity)
                        } else {
                            // Si la distancia es 0, mostrar "Ahora"
                            Text("Ahora")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.green)
                                .transition(.opacity)
                        }
                    }
                }
                Spacer()

                // Contador de pasos
                VStack(spacing: 4) {
                    Text("\(currentStepIndex + 1)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.blue)
                        .contentTransition(.numericText())
                    Text("\(L(.mapOf)) \(route.steps.count)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Barra de progreso visual
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Fondo de la barra
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)

                    // Progreso
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .green],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: geometry.size.width * CGFloat(currentStepIndex + 1) / CGFloat(max(1, route.steps.count)),
                            height: 6
                        )
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: currentStepIndex)
                }
            }
            .frame(height: 6)
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

    // 🎯 Helper mejorado: decidir qué instrucción mostrar según la distancia
    private func getDisplayInstruction(for route: MKRoute) -> String {
        guard currentStepIndex < route.steps.count else {
            return L(.mapContinueStraight)
        }

        let currentStep = route.steps[currentStepIndex]
        let instruction = currentStep.instructions.lowercased()

        // Si la distancia a la próxima maniobra es mayor a 1.5 km (~1500m)
        // mostrar solo "Sigue recto" en lugar de la instrucción específica
        if distanceToNextStep > 1500 {
            // Verificar si la instrucción actual es una maniobra importante
            let isImportantManeuver = instruction.contains("toma") ||
                                     instruction.contains("salida") ||
                                     instruction.contains("gira") ||
                                     instruction.contains("derecha") ||
                                     instruction.contains("izquierda") ||
                                     instruction.contains("rotonda")

            if isImportantManeuver {
                // Si es una maniobra importante pero está lejos, mostrar la indicación de seguir recto
                return L(.mapContinueStraight)
            }
        }

        // Si la maniobra está cerca (< 1.5 km) o no es importante, mostrar la instrucción original
        return currentStep.instructions.isEmpty ? L(.mapContinueStraight) : currentStep.instructions
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
                HapticFeedback.light()
                selectedCampo = destination.campo
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.green)
                                .font(.title3)

                            Text(destination.title ?? L(.mapDestination))
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
                    Text(L(.mapKilometers))
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
                    Text(L(.mapMinutesApprox))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)

            // 🚀 Botón de iniciar
            Button {
                HapticFeedback.medium()
                startNavigation()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text(L(.mapStartNavigation))
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

                print("✅ [PrepareRoute] Ruta \(self.externalIsNavigating ? "recalculada" : "calculada") - Distancia: \(String(format: "%.1f", route.distance / 1000)) km, Pasos: \(route.steps.count)")

                // ✅ Si estamos navegando, encontrar el paso correcto basado en la ubicación actual
                if self.externalIsNavigating, route.steps.count > 0,
                   let currentUserLocation = self.mapView?.userLocation.location?.coordinate {

                    let userCLLocation = CLLocation(latitude: currentUserLocation.latitude, longitude: currentUserLocation.longitude)

                    // 🎯 Encontrar el paso correcto: aquel cuyo final esté más adelante que la posición actual
                    var correctStepIndex = 0
                    var minDistanceToStepEnd = Double.greatestFiniteMagnitude

                    for stepIndex in 0..<route.steps.count {
                        let stepEndCoordinate = self.calculateStepEndCoordinate(route: route, stepIndex: stepIndex)
                        let endLocation = CLLocation(latitude: stepEndCoordinate.latitude, longitude: stepEndCoordinate.longitude)
                        let distanceToEnd = userCLLocation.distance(from: endLocation)

                        // Saltar pasos con distancia 0 o negativos (ya completados)
                        if route.steps[stepIndex].distance < 5 {
                            print("⏭️ [PrepareRoute] Saltando paso \(stepIndex + 1) (distancia del paso: \(String(format: "%.0f", route.steps[stepIndex].distance))m)")
                            continue
                        }

                        // El primer paso válido con distancia hacia adelante es el correcto
                        if distanceToEnd < minDistanceToStepEnd && distanceToEnd > 0 {
                            correctStepIndex = stepIndex
                            minDistanceToStepEnd = distanceToEnd
                            break
                        }
                    }

                    // Calcular distancia al paso correcto
                    let correctStepEndCoordinate = self.calculateStepEndCoordinate(route: route, stepIndex: correctStepIndex)
                    let endLocation = CLLocation(latitude: correctStepEndCoordinate.latitude, longitude: correctStepEndCoordinate.longitude)
                    let newDistance = userCLLocation.distance(from: endLocation)

                    print("📏 [PrepareRoute] Paso correcto después de recalcular: \(correctStepIndex + 1), Distancia: \(String(format: "%.0f", newDistance))m")

                    // Actualizar al paso correcto en el Coordinator
                    if let coordinator = (self.mapView?.delegate as? CustomMapView.Coordinator) {
                        coordinator.setCorrectStepAfterRecalculation(correctStepIndex)
                    }

                    self.distanceToNextStep = newDistance
                    print("✅ [PrepareRoute] Distancia UI actualizada: \(String(format: "%.0f", newDistance))m")
                }
            }
        }
    }
    
    private func startNavigation() {
        print("🚀 [StartNav] Iniciando navegación...")
        print("📍 [StartNav] Ubicación del usuario: \(mapView?.userLocation.location?.coordinate.latitude ?? 0), \(mapView?.userLocation.location?.coordinate.longitude ?? 0)")
        print("🎯 [StartNav] Destino: \(pendingDestination?.title ?? "desconocido")")

        withAnimation(.spring()) {
            self.showRouteSummary = false
            self.externalIsNavigating = true
            self.currentStepIndex = 0
            self.userTrackingMode = .followWithHeading

            // Calcular distancia inicial al primer paso
            if let route = self.route,
               let userLocation = mapView?.userLocation.location?.coordinate,
               route.steps.count > 0 {
                let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)

                // Calcular distancia al final del primer paso
                let firstStepEndCoordinate = calculateStepEndCoordinate(route: route, stepIndex: 0)
                let endLocation = CLLocation(latitude: firstStepEndCoordinate.latitude, longitude: firstStepEndCoordinate.longitude)
                self.distanceToNextStep = userCLLocation.distance(from: endLocation)

                print("📏 [StartNav] Distancia inicial al paso 1: \(String(format: "%.0f", self.distanceToNextStep))m")
                print("   Primer paso: \(route.steps[0].instructions)")
            } else {
                self.distanceToNextStep = 0
                print("⚠️ [StartNav] No se pudo calcular distancia inicial")
            }
        }

        // Pasar el destino al Coordinator para que pueda recalcular rutas
        if let mapView = self.mapView, let destination = pendingDestination {
            print("✅ [StartNav] Configurando destino en Coordinator y activando actualizaciones de ubicación")
            (mapView.delegate as? CustomMapView.Coordinator)?.setCurrentDestination(destination)
        }

        print("🧭 [StartNav] User tracking mode: \(userTrackingMode == .followWithHeading ? "followWithHeading" : "otro")")
    }

    // Helper para calcular la coordenada al final de un paso específico
    private func calculateStepEndCoordinate(route: MKRoute, stepIndex: Int) -> CLLocationCoordinate2D {
        // Calcular la distancia total hasta el final del paso
        var distanceToEndOfStep: CLLocationDistance = 0
        for i in 0...stepIndex {
            distanceToEndOfStep += route.steps[i].distance
        }

        // Encontrar el punto en la polyline que corresponde al final del paso
        let polyline = route.polyline
        let points = polyline.points()
        var accumulatedDistance: CLLocationDistance = 0

        for i in 0..<polyline.pointCount - 1 {
            let point1 = points[i]
            let point2 = points[i + 1]
            let segmentDistance = point1.distance(to: point2)

            if accumulatedDistance + segmentDistance >= distanceToEndOfStep {
                // Este segmento contiene el final del paso
                let remainingInSegment = distanceToEndOfStep - accumulatedDistance
                let fraction = remainingInSegment / segmentDistance

                let lat = point1.coordinate.latitude + (point2.coordinate.latitude - point1.coordinate.latitude) * fraction
                let lon = point1.coordinate.longitude + (point2.coordinate.longitude - point1.coordinate.longitude) * fraction
                return CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
            accumulatedDistance += segmentDistance
        }

        // Si no encontramos el punto, devolver el último punto de la polyline
        return points[polyline.pointCount - 1].coordinate
    }
    
    private func stopNavigation() {
        print("🛑 Deteniendo navegación...")
        self.externalIsNavigating = false
        self.showRouteSummary = false
        self.route = nil
        self.currentStepIndex = 0
        self.distanceToNextStep = 0
        self.traveledCoordinates = [] // Limpiar coordenadas recorridas

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
        if showOnlyVisited {
            filteredCampos = camposViewModel.campos.filter { visitedCampoIds.contains($0.id) }
        } else {
            filteredCampos = camposViewModel.campos
        }
        updateAnnotations()
    }
    
    func updateAnnotations() {
        var newAnnotations: [MapAnnotationItem] = []
        for campo in filteredCampos {
            if let lat = campo.latitud, let lon = campo.longitud {
                let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                let isVisited = visitedCampoIds.contains(campo.id)
                newAnnotations.append(MapAnnotationItem(
                    coordinate: coordinate,
                    title: campo.nombre,
                    subtitle: L(.mapFootballField),
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
                    applyFiltros()
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
    @Binding var isNavigating: Bool
    @Binding var visitedCampoIds: Set<UUID>
    var userId: String?
    let onSelectCampo: (CampoModel) -> Void
    let onShowSummary: (MapAnnotationItem) -> Void
    let onUpdateAnnotations: () -> Void
    @Binding var mapView: MKMapView?

    // Clase auxiliar para guardar referencias a constraints
    class MapViewContext {
        var compassTopConstraint: NSLayoutConstraint?
    }

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

        // Guardar el constraint del top para poder ajustarlo dinámicamente
        let compassTopConstraint = compass.topAnchor.constraint(equalTo: mapView.safeAreaLayoutGuide.topAnchor, constant: 90)
        context.coordinator.mapViewContext.compassTopConstraint = compassTopConstraint

        NSLayoutConstraint.activate([
            // La posicionamos en el margen derecho
            compass.trailingAnchor.constraint(equalTo: mapView.trailingAnchor, constant: -12),
            compassTopConstraint
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

        // Ajustar posición de la brújula según si hay navegación activa
        if let compassTopConstraint = context.coordinator.mapViewContext.compassTopConstraint {
            // Cuando hay navegación, bajar la brújula para que no choque con el header
            let topOffset: CGFloat = isNavigating ? 150 : 90
            if compassTopConstraint.constant != topOffset {
                compassTopConstraint.constant = topOffset
                UIView.animate(withDuration: 0.3) {
                    uiView.layoutIfNeeded()
                }
            }
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
        let mapViewContext = MapViewContext()
        private var justRecalculated = false // Flag para evitar avances inmediatos después de recalcular
        private var lastPolylineUpdateIndex = 0 // Índice del último punto donde actualizamos la polyline

        init(_ parent: CustomMapView) {
            self.parent = parent
            super.init()
            setupLocationManager()
        }

        private func setupLocationManager() {
            locationManager = CLLocationManager()
            locationManager?.delegate = self
            locationManager?.desiredAccuracy = kCLLocationAccuracyBestForNavigation
            locationManager?.distanceFilter = kCLDistanceFilterNone // Actualizar continuamente sin filtro de distancia
            locationManager?.activityType = .automotiveNavigation
            locationManager?.allowsBackgroundLocationUpdates = true
            locationManager?.pausesLocationUpdatesAutomatically = false
            print("📱 Location Manager configurado para navegación continua")
        }

        func setCurrentDestination(_ destination: MapAnnotationItem) {
            self.currentDestination = destination
            // Resetear índice de polyline para nueva navegación
            self.lastPolylineUpdateIndex = 0
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

        func setCorrectStepAfterRecalculation(_ stepIndex: Int) {
            DispatchQueue.main.async {
                let previousStep = self.parent.currentStepIndex
                self.parent.currentStepIndex = stepIndex
                print("   Paso actualizado después de recalcular: \(previousStep + 1) → \(stepIndex + 1)")

                // Activar flag para evitar avances inmediatos
                self.justRecalculated = true
                print("   Flag 'justRecalculated' activado para evitar avances inmediatos")

                // Resetear índice de polyline para empezar desde el inicio
                self.lastPolylineUpdateIndex = 0
            }
        }

        // MARK: - CLLocationManagerDelegate
        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let location = locations.last else { return }
            print("📍 [CLLocationManager] Ubicación actualizada: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            print("   Precisión: \(location.horizontalAccuracy)m, Velocidad: \(location.speed)m/s")
            print("   Estado navegación: \(parent.isNavigating ? "NAVEGANDO" : "NO navegando")")

            if parent.isNavigating {
                print("✅ [CLLocationManager] Procesando ubicación durante navegación")
                print("   Paso actual: \(parent.currentStepIndex + 1), Distancia actual: \(String(format: "%.0f", parent.distanceToNextStep))m")

                // Actualizar paso actual y distancia en tiempo real
                updateCurrentStep(userLocation: location.coordinate, source: "CLLocationManager")

                // Verificar si necesitamos recalcular la ruta
                checkIfRecalculationNeeded(userLocation: location.coordinate)
            } else {
                print("⚠️ [CLLocationManager] No navegando - actualización ignorada")
            }
        }

        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            print("❌ Error en location manager: \(error.localizedDescription)")
        }

        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            // ⚠️ NO procesar ubicaciones aquí para evitar doble procesamiento
            // CLLocationManager ya maneja todas las actualizaciones durante navegación
            guard let location = userLocation.location else { return }
            print("🗺️ [MapView] Ubicación del punto azul actualizada: \(location.coordinate.latitude), \(location.coordinate.longitude)")

            if parent.isNavigating {
                print("   [MapView] Navegando - procesamiento delegado a CLLocationManager")
            }
        }
        
        private func updateCurrentStep(userLocation: CLLocationCoordinate2D, source: String) {
            guard let currentRoute = parent.route, parent.currentStepIndex < currentRoute.steps.count else { return }

            let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)

            // Calcular la distancia total hasta el FINAL del paso actual
            var distanceToEndOfCurrentStep: CLLocationDistance = 0
            for i in 0...parent.currentStepIndex {
                distanceToEndOfCurrentStep += currentRoute.steps[i].distance
            }

            print("📊 [\(source)] Paso \(parent.currentStepIndex + 1)/\(currentRoute.steps.count) - Distancia total hasta fin del paso: \(String(format: "%.0f", distanceToEndOfCurrentStep))m")

            // Encontrar el punto en la polyline que corresponde al final del paso actual
            let polyline = currentRoute.polyline
            let points = polyline.points()
            var accumulatedDistance: CLLocationDistance = 0
            var endOfStepCoordinate: CLLocationCoordinate2D?

            for i in 0..<polyline.pointCount - 1 {
                let point1 = points[i]
                let point2 = points[i + 1]
                let segmentDistance = point1.distance(to: point2)

                if accumulatedDistance + segmentDistance >= distanceToEndOfCurrentStep {
                    // Este segmento contiene el final del paso actual
                    // Interpolar la posición exacta para mayor precisión
                    let remainingInSegment = distanceToEndOfCurrentStep - accumulatedDistance
                    let fraction = segmentDistance > 0 ? remainingInSegment / segmentDistance : 0

                    let lat = point1.coordinate.latitude + (point2.coordinate.latitude - point1.coordinate.latitude) * fraction
                    let lon = point1.coordinate.longitude + (point2.coordinate.longitude - point1.coordinate.longitude) * fraction
                    endOfStepCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    break
                }
                accumulatedDistance += segmentDistance
            }

            // Si no encontramos el punto, usar el último punto de la polyline
            if endOfStepCoordinate == nil {
                endOfStepCoordinate = points[polyline.pointCount - 1].coordinate
            }

            // Calcular la distancia directa desde el usuario hasta el final del paso
            guard let endCoord = endOfStepCoordinate else { return }
            let endLocation = CLLocation(latitude: endCoord.latitude, longitude: endCoord.longitude)
            let remainingDistance = userCLLocation.distance(from: endLocation)

            print("📍 [\(source)] Distancia restante desde ubicación actual hasta fin del paso: \(String(format: "%.0f", remainingDistance))m")

            // 🎯 Actualizar la polyline para borrar el camino recorrido
            updatePolylineToRemoveTraveledPath(userLocation: userLocation, currentRoute: currentRoute)

            // Actualizar la distancia en el UI
            let previousDistance = parent.distanceToNextStep
            DispatchQueue.main.async {
                let newDistance = max(0, remainingDistance)

                // 🎯 FIX: Si acabamos de recalcular, NO permitir que la distancia SUBA
                // Solo actualizar si la nueva distancia es menor (usuario se acerca)
                if self.justRecalculated && newDistance > previousDistance {
                    print("⏸️ [\(source)] Acabamos de recalcular - Ignorando aumento de distancia: \(String(format: "%.0f", previousDistance))m → \(String(format: "%.0f", newDistance))m")
                    self.justRecalculated = false // Resetear flag para próximas actualizaciones
                } else {
                    // Actualización normal: permitir cambios de distancia
                    self.parent.distanceToNextStep = newDistance
                    print("✅ [\(source)] Distancia UI: \(String(format: "%.0f", previousDistance))m → \(String(format: "%.0f", newDistance))m")

                    // Si la distancia bajó después de un recálculo, resetear el flag
                    if self.justRecalculated {
                        self.justRecalculated = false
                        print("   Flag 'justRecalculated' reseteado (distancia bajó correctamente)")
                    }
                }
            }

            // Avanzar al siguiente paso si estamos muy cerca del final (menos de 15 metros)
            // PERO: No avanzar si acabamos de recalcular la ruta (evitar saltos inmediatos)
            // Nota: El flag justRecalculated se maneja en el bloque anterior al actualizar la distancia
            if remainingDistance < 15 && parent.currentStepIndex < currentRoute.steps.count - 1 && !justRecalculated {
                print("➡️ [\(source)] Avanzando al paso \(parent.currentStepIndex + 2)/\(currentRoute.steps.count) (distancia < 15m)")
                DispatchQueue.main.async {
                    // Feedback háptico al avanzar de paso
                    HapticFeedback.medium()

                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        self.parent.currentStepIndex += 1
                        // Recalcular distancia para el nuevo paso
                        if let userLocation = self.parent.mapView?.userLocation.location {
                            self.updateCurrentStep(userLocation: userLocation.coordinate, source: "\(source)-NextStep")
                        }
                    }
                }
            }
        }

        // 🎯 Nueva función: Actualizar polyline para borrar el camino recorrido
        private func updatePolylineToRemoveTraveledPath(userLocation: CLLocationCoordinate2D, currentRoute: MKRoute) {
            guard let mapView = parent.mapView else { return }

            let polyline = currentRoute.polyline
            let points = polyline.points()
            let userPoint = MKMapPoint(userLocation)

            // Encontrar el punto más cercano en la polyline al usuario
            var closestIndex = 0
            var minDistance = Double.greatestFiniteMagnitude

            // Optimización: verificar cada 3 puntos para rutas largas
            let step = max(1, polyline.pointCount / 200)
            for i in stride(from: 0, to: polyline.pointCount, by: step) {
                let distance = points[i].distance(to: userPoint)
                if distance < minDistance {
                    minDistance = distance
                    closestIndex = i
                }
            }

            // Buscar más finamente alrededor del punto más cercano
            let searchRange = max(0, closestIndex - step)..<min(polyline.pointCount, closestIndex + step)
            for i in searchRange {
                let distance = points[i].distance(to: userPoint)
                if distance < minDistance {
                    minDistance = distance
                    closestIndex = i
                }
            }

            // 🎯 IMPORTANTE: El closestIndex nunca debe retroceder (solo puede avanzar o quedarse igual)
            // Esto evita recreaciones innecesarias que causan parpadeos
            if closestIndex < lastPolylineUpdateIndex {
                closestIndex = lastPolylineUpdateIndex
            }

            // Calcular cuántos puntos hemos avanzado desde la última actualización
            let pointsAdvanced = closestIndex - lastPolylineUpdateIndex

            // Actualizar si hemos avanzado al menos 8 puntos (más fluido que el 5% anterior)
            // O si la distancia en metros es significativa (más de 20 metros)
            let shouldUpdate: Bool
            if pointsAdvanced > 0 && closestIndex < polyline.pointCount - 1 {
                // Calcular distancia real en metros entre el último update y la posición actual
                let lastPoint = points[lastPolylineUpdateIndex]
                let currentPoint = points[closestIndex]
                let distanceInMeters = lastPoint.distance(to: currentPoint)

                // Actualizar si avanzamos 8+ puntos O más de 20 metros
                shouldUpdate = pointsAdvanced >= 8 || distanceInMeters >= 20
            } else {
                shouldUpdate = false
            }

            if shouldUpdate {
                // Crear nueva polyline solo con los puntos restantes
                let remainingPoints = UnsafeMutablePointer<MKMapPoint>.allocate(capacity: polyline.pointCount - closestIndex)
                for i in closestIndex..<polyline.pointCount {
                    remainingPoints[i - closestIndex] = points[i]
                }

                let newPolyline = MKPolyline(points: remainingPoints, count: polyline.pointCount - closestIndex)
                remainingPoints.deallocate()

                // 🎯 CRÍTICO: Agregar PRIMERO la nueva polyline, LUEGO eliminar la vieja
                // Esto evita que haya un frame sin polyline (causa del parpadeo)
                DispatchQueue.main.async {
                    // 1. Agregar la nueva polyline PRIMERO
                    mapView.addOverlay(newPolyline)

                    // 2. LUEGO eliminar las polylines viejas (dejando solo la nueva)
                    let overlaysToRemove = mapView.overlays.filter { overlay in
                        overlay is MKPolyline && overlay !== newPolyline
                    }
                    mapView.removeOverlays(overlaysToRemove)

                    print("🗑️ Polyline actualizada - Puntos eliminados: \(pointsAdvanced), Puntos restantes: \(polyline.pointCount - closestIndex)")
                }

                // Actualizar el índice de la última actualización
                lastPolylineUpdateIndex = closestIndex
            }
        }

        private func checkIfRecalculationNeeded(userLocation: CLLocationCoordinate2D) {
            guard parent.isNavigating, let currentRoute = parent.route, let destination = currentDestination else {
                return
            }

            // Calcular distancia mínima a la ruta usando todos los puntos de la polyline
            let userPoint = MKMapPoint(userLocation)
            var minDistance = Double.greatestFiniteMagnitude
            let points = currentRoute.polyline.points()

            // Optimización: verificar solo cada 5 puntos para rutas muy largas
            let step = max(1, currentRoute.polyline.pointCount / 100)
            for i in stride(from: 0, to: currentRoute.polyline.pointCount, by: step) {
                let distance = points[i].distance(to: userPoint)
                if distance < minDistance { minDistance = distance }
            }

            print("📏 [RecalculoCheck] Distancia a la ruta: \(String(format: "%.0f", minDistance))m")

            // Recalcular si te desvías más de 50 metros de la ruta (tolerante con imprecisión GPS)
            if minDistance > 50 {
                print("🔄 [RecalculoCheck] INICIANDO RECÁLCULO - Desviación de \(String(format: "%.0f", minDistance))m")
                print("   Paso actual antes de recalcular: \(parent.currentStepIndex + 1), Distancia actual: \(String(format: "%.0f", parent.distanceToNextStep))m")
                lastRecalculationDate = Date()

                // Feedback háptico para indicar recalculación
                HapticFeedback.light()

                DispatchQueue.main.async {
                    // ✅ NO resetear el paso aquí - se calculará automáticamente en prepareRouteSummary
                    // basado en la ubicación actual del usuario
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

                // Ancho del container (ajustado para 2 botones)
                calloutContainer.widthAnchor.constraint(equalToConstant: 250)
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

        // MARK: - Detectar cuando el usuario arrastra el mapa manualmente
        func mapView(_ mapView: MKMapView, didChange mode: MKUserTrackingMode, animated: Bool) {
            // Sincronizar el estado cuando el MapKit cambia el tracking mode
            // (esto ocurre automáticamente cuando el usuario arrastra el mapa)
            if parent.userTrackingMode != mode {
                print("📍 Usuario arrastró el mapa - Reseteando botón de ubicación")
                DispatchQueue.main.async {
                    self.parent.userTrackingMode = mode
                }
            }
        }
    }
}
