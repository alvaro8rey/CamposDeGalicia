import SwiftUI
import MapKit
import CoreLocation
import Supabase

// MARK: - Map View

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

    // ✅ NUEVO: Campo preseleccionado desde otra vista
    let preselectedCampoId: UUID?

    init(externalIsNavigating: Binding<Bool>, preselectedCampoId: UUID? = nil) {
        self._externalIsNavigating = externalIsNavigating
        self.preselectedCampoId = preselectedCampoId
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
                }
                // ❌ DESHABILITADO: Header de navegación activa
                /*
                else if let route = route {
                    navigationHeader(route: route)
                }
                */

                Spacer()
                
                if showRouteSummary, let route = route, let dest = pendingDestination {
                    routeSummaryCard(route: route, destination: dest)
                }
            }

            // MARK: - Botones Flotantes
            ZStack(alignment: .bottomTrailing) {
                Color.clear

                VStack(spacing: 12) {
                    // ❌ DESHABILITADO: Botón para detener navegación
                    /*
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
                    */

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
                .padding(.bottom, externalIsNavigating ? 40 : (showRouteSummary ? 280 : 40))
            }

            // MARK: - Botón de Filtro Visitados (esquina superior izquierda, discreto)
            if !externalIsNavigating && !showRouteSummary && !isSearching && authViewModel.isAuthenticated {
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
            applyFiltros()

            // ✅ NUEVO: Si hay un campo preseleccionado, seleccionarlo y centrarlo
            if let campoId = preselectedCampoId {
                if let campo = camposViewModel.campos.first(where: { $0.id == campoId }) {
                    // Delay para asegurar que el mapa está renderizado
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.selectCampoFromSearch(campo)
                    }
                }
            }
        }
        .onChange(of: authViewModel.isAuthenticated) { _, isAuthenticated in
            if !isAuthenticated {
                visitedCampoIds = []
                showOnlyVisited = false
                applyFiltros()
            } else {
                loadVisitedCampos()
            }
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

    // ❌ DESHABILITADO: UI de navegación activa
    /*
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
    */

    // ❌ DESHABILITADO: Helpers de navegación
    /*
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
    */

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

            // 🚀 Botón de iniciar (abre Maps externo)
            Button {
                HapticFeedback.medium()
                openInExternalMaps()
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
                Logger.debug("❌ Error calculando ruta: \(error.localizedDescription)")
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

                Logger.debug("✅ [PrepareRoute] Ruta \(self.externalIsNavigating ? "recalculada" : "calculada") - Distancia: \(String(format: "%.1f", route.distance / 1000)) km, Pasos: \(route.steps.count)")

                // ❌ DESHABILITADO: Lógica de navegación paso a paso
                /*
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
                            Logger.debug("⏭️ [PrepareRoute] Saltando paso \(stepIndex + 1) (distancia del paso: \(String(format: "%.0f", route.steps[stepIndex].distance))m)")
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

                    Logger.debug("📏 [PrepareRoute] Paso correcto después de recalcular: \(correctStepIndex + 1), Distancia: \(String(format: "%.0f", newDistance))m")

                    // Actualizar al paso correcto en el Coordinator
                    if let coordinator = (self.mapView?.delegate as? CustomMapView.Coordinator) {
                        coordinator.setCorrectStepAfterRecalculation(correctStepIndex)
                    }

                    self.distanceToNextStep = newDistance
                    Logger.debug("✅ [PrepareRoute] Distancia UI actualizada: \(String(format: "%.0f", newDistance))m")
                }
                */
            }
        }
    }
    
    // ✅ NUEVO: Abrir ruta en Maps externo (Google Maps o Apple Maps)
    private func openInExternalMaps() {
        guard let destination = pendingDestination else { return }
        guard let lat = destination.campo.latitud, let lon = destination.campo.longitud else { return }

        // Intentar abrir en Google Maps primero
        let googleMapsURL = URL(string: "comgooglemaps://?saddr=&daddr=\(lat),\(lon)&directionsmode=driving")
        if let url = googleMapsURL, UIApplication.shared.canOpenURL(url) {
            Logger.debug("📍 Abriendo ruta en Google Maps")
            UIApplication.shared.open(url)
        } else {
            // Si no tiene Google Maps, abrir en Apple Maps
            Logger.debug("📍 Abriendo ruta en Apple Maps")
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
            mapItem.name = destination.campo.nombre
            mapItem.openInMaps(launchOptions: [
                MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
            ])
        }
    }

    // ❌ DESHABILITADO: Navegación interna (no funciona perfectamente)
    /*
    private func startNavigation() {
        Logger.debug("🚀 [StartNav] Iniciando navegación...")
        Logger.debug("📍 [StartNav] Ubicación del usuario: \(mapView?.userLocation.location?.coordinate.latitude ?? 0), \(mapView?.userLocation.location?.coordinate.longitude ?? 0)")
        Logger.debug("🎯 [StartNav] Destino: \(pendingDestination?.title ?? "desconocido")")

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

                Logger.debug("📏 [StartNav] Distancia inicial al paso 1: \(String(format: "%.0f", self.distanceToNextStep))m")
                Logger.debug("   Primer paso: \(route.steps[0].instructions)")
            } else {
                self.distanceToNextStep = 0
                Logger.debug("⚠️ [StartNav] No se pudo calcular distancia inicial")
            }
        }

        // Pasar el destino al Coordinator para que pueda recalcular rutas
        if let mapView = self.mapView, let destination = pendingDestination {
            Logger.debug("✅ [StartNav] Configurando destino en Coordinator y activando actualizaciones de ubicación")
            (mapView.delegate as? CustomMapView.Coordinator)?.setCurrentDestination(destination)
        }

        Logger.debug("🧭 [StartNav] User tracking mode: \(userTrackingMode == .followWithHeading ? "followWithHeading" : "otro")")
    }
    */

    // ❌ DESHABILITADO: Helper para calcular coordenada al final de un paso
    /*
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
    */

    // ❌ DESHABILITADO: Función para detener navegación
    /*
    private func stopNavigation() {
        Logger.debug("🛑 Deteniendo navegación...")
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
    */

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

