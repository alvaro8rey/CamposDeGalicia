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
    @State private var distanceToNextStep: Double = 0
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

    // Filtro para el buscador con fuzzy search (Tolerante a errores, acentos y mayúsculas)
    var searchResults: [CampoModel] {
        if searchText.isEmpty { return [] }

        // Normalizar texto de búsqueda
        let normalizedSearch = searchText
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

        // Calcular similitud para cada campo y filtrar
        let camposConSimilitud = camposViewModel.campos.compactMap { campo -> (campo: CampoModel, score: Double)? in
            // Normalizar nombre y localidad del campo
            let normalizedNombre = campo.nombre
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            let normalizedLocalidad = (campo.localidad ?? "")
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

            // Calcular score de similitud (0.0 a 1.0)
            let scoreNombre = calculateMatchScore(search: normalizedSearch, target: normalizedNombre)
            let scoreLocalidad = calculateMatchScore(search: normalizedSearch, target: normalizedLocalidad)

            // Usar el score más alto entre nombre y localidad
            let bestScore = max(scoreNombre, scoreLocalidad)

            // Filtrar los que tienen al menos 50% de similitud
            if bestScore >= 0.5 {
                return (campo, bestScore)
            }
            return nil
        }

        // Ordenar por score descendente (más similares primero)
        let sortedCampos = camposConSimilitud
            .sorted { $0.score > $1.score }
            .map { $0.campo }

        return sortedCampos
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
            self.currentStepIndex = 0
            self.distanceToNextStep = 0
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
                    Text(step.instructions.isEmpty ? "Continúa recto" : step.instructions)
                        .font(.headline)
                        .lineLimit(2)

                    // Mostrar distancia en tiempo real
                    let displayDistance = distanceToNextStep > 0 ? distanceToNextStep : step.distance
                    if displayDistance >= 1000 {
                        Text("En \(String(format: "%.1f", displayDistance / 1000)) km")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("En \(Int(displayDistance)) metros")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()

                // Mostrar paso actual / total
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(currentStepIndex + 1)/\(route.steps.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button {
                        if currentStepIndex < route.steps.count - 1 {
                            currentStepIndex += 1
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                    }
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

    // MARK: - Fuzzy Search Functions

    /// Calcula un score de similitud entre el texto de búsqueda y el objetivo
    /// - Parameters:
    ///   - search: Texto de búsqueda
    ///   - target: Texto objetivo donde buscar
    /// - Returns: Score entre 0.0 (sin similitud) y 1.0 (coincidencia perfecta)
    private func calculateMatchScore(search: String, target: String) -> Double {
        if search.isEmpty || target.isEmpty { return 0.0 }

        let searchNoSpaces = search.replacingOccurrences(of: " ", with: "")
        let targetNoSpaces = target.replacingOccurrences(of: " ", with: "")

        // 1. Coincidencia exacta (sin espacios) = 1.0
        if targetNoSpaces == searchNoSpaces {
            return 1.0
        }

        // 2. Coincidencia exacta con espacios = 0.98
        if target == search {
            return 0.98
        }

        // 3. Target contiene search completo (sin espacios) = 0.95
        if targetNoSpaces.contains(searchNoSpaces) {
            return 0.95
        }

        // 4. Target contiene search con espacios = 0.90
        if target.contains(search) {
            return 0.90
        }

        // 5. Coincidencia de palabras individuales = 0.70-0.85
        let searchWords = search.split(separator: " ").map(String.init)
        let targetWords = target.split(separator: " ").map(String.init)

        if !searchWords.isEmpty {
            var wordMatchCount = 0
            var totalWordSimilarity = 0.0

            for searchWord in searchWords {
                var bestWordMatch = 0.0
                for targetWord in targetWords {
                    if targetWord.contains(searchWord) {
                        bestWordMatch = 0.85
                        break
                    } else {
                        let similarity = stringSimilarity(searchWord, targetWord)
                        bestWordMatch = max(bestWordMatch, similarity)
                    }
                }
                if bestWordMatch >= 0.5 {
                    wordMatchCount += 1
                    totalWordSimilarity += bestWordMatch
                }
            }

            if wordMatchCount == searchWords.count && wordMatchCount > 0 {
                let avgSimilarity = totalWordSimilarity / Double(searchWords.count)
                return avgSimilarity * 0.85 // Reducir un poco el score de palabras
            }
        }

        // 6. Similitud por Levenshtein Distance = 0.0-0.70
        let similarity = stringSimilarity(searchNoSpaces, targetNoSpaces)
        return similarity * 0.70 // Reducir el peso de similitud pura
    }

    /// Búsqueda difusa que tolera errores de escritura, espacios, etc.
    /// - Parameters:
    ///   - search: Texto de búsqueda
    ///   - target: Texto objetivo donde buscar
    ///   - threshold: Umbral de similitud (0.0 a 1.0). Por defecto 0.5 (50%)
    /// - Returns: true si hay coincidencia o similitud suficiente
    private func fuzzyMatch(search: String, target: String, threshold: Double = 0.5) -> Bool {
        // Si está vacío, no filtramos
        if search.isEmpty { return true }

        // 1. Coincidencia exacta (sin espacios)
        let searchNoSpaces = search.replacingOccurrences(of: " ", with: "")
        let targetNoSpaces = target.replacingOccurrences(of: " ", with: "")

        if targetNoSpaces.contains(searchNoSpaces) {
            return true
        }

        // 2. Coincidencia con espacios
        if target.contains(search) {
            return true
        }

        // 3. Coincidencia de palabras individuales
        let searchWords = search.split(separator: " ").map(String.init)
        let targetWords = target.split(separator: " ").map(String.init)

        // Si todas las palabras de búsqueda están en el target
        let allWordsMatch = searchWords.allSatisfy { searchWord in
            targetWords.contains { targetWord in
                targetWord.contains(searchWord) || stringSimilarity(searchWord, targetWord) >= threshold
            }
        }

        if allWordsMatch && !searchWords.isEmpty {
            return true
        }

        // 4. Similitud global usando Levenshtein
        let similarity = stringSimilarity(searchNoSpaces, targetNoSpaces)
        return similarity >= threshold
    }

    /// Calcula la similitud entre dos strings usando Levenshtein Distance
    /// - Returns: Valor entre 0.0 (sin similitud) y 1.0 (idénticos)
    private func stringSimilarity(_ s1: String, _ s2: String) -> Double {
        // Si alguno está vacío
        if s1.isEmpty || s2.isEmpty {
            return s1.isEmpty && s2.isEmpty ? 1.0 : 0.0
        }

        let distance = levenshteinDistance(s1, s2)
        let maxLength = max(s1.count, s2.count)

        // Convertir distancia a similitud (1.0 = idénticos, 0.0 = muy diferentes)
        return 1.0 - (Double(distance) / Double(maxLength))
    }

    /// Algoritmo de Levenshtein Distance - calcula el número mínimo de ediciones
    /// (inserciones, eliminaciones o sustituciones) para transformar s1 en s2
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)

        let m = s1Array.count
        let n = s2Array.count

        // Crear matriz de distancias
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)

        // Inicializar primera fila y columna
        for i in 0...m {
            dp[i][0] = i
        }
        for j in 0...n {
            dp[0][j] = j
        }

        // Calcular distancias
        for i in 1...m {
            for j in 1...n {
                let cost = s1Array[i - 1] == s2Array[j - 1] ? 0 : 1
                dp[i][j] = min(
                    dp[i - 1][j] + 1,      // Eliminación
                    dp[i][j - 1] + 1,      // Inserción
                    dp[i - 1][j - 1] + cost // Sustitución
                )
            }
        }

        return dp[m][n]
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
                // Centrar el mapa en la ubicación del usuario
                DispatchQueue.main.async {
                    let region = MKCoordinateRegion(center: location.coordinate,
                                                   latitudinalMeters: 300,
                                                   longitudinalMeters: 300)
                    self.parent.mapView?.setRegion(region, animated: true)
                }

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
            guard let location = userLocation.location else { return }

            // Solo procesar actualizaciones cuando estamos navegando
            if parent.isNavigating {
                print("📍 Ubicación actualizada: \(location.coordinate.latitude), \(location.coordinate.longitude)")

                // Centrar el mapa en la ubicación del usuario
                let region = MKCoordinateRegion(center: location.coordinate,
                                               latitudinalMeters: 300,
                                               longitudinalMeters: 300)
                mapView.setRegion(region, animated: true)

                // Actualizar paso actual y distancia en tiempo real
                updateCurrentStep(userLocation: location.coordinate)

                // Verificar si necesitamos recalcular la ruta
                checkIfRecalculationNeeded(userLocation: location.coordinate)
            }
            // No hacer nada ni loggear si no estamos navegando
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
