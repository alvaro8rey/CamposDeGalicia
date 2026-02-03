import SwiftUI
import Supabase

struct ContentView: View {
    @EnvironmentObject var camposViewModel: CamposViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var localizationManager: LocalizationManager
    @EnvironmentObject var geofenceManager: GeofenceManager
    @Environment(\.colorScheme) var colorScheme

    // Estados para los filtros
    @State private var searchNombre: String = ""
    @State private var searchLocalidad: String = ""
    @State private var selectedProvincia: String = ""
    @State private var isFilterExpanded: Bool = false // Controla si el contenedor de filtros está abierto

    // Lista de provincias disponibles
    var provincias: [String] {
        [L(.contentAllProvinces), L(.provinceACoruna), L(.provinceOurense), L(.provinceLugo), L(.provincePontevedra)]
    }

    // Lista de campos y estado de carga gestionados por el view model
    @Binding var distanciaPredeterminada: Double // Añadimos el binding

    // Binding para navegación desde notificaciones
    @Binding var notificationCampoID: UUID?

    // Lista de campos filtrada
    @State private var filteredCampos: [CampoModel] = []

    // Estado para controlar la vista (predeterminada como lista)
    @State private var isGridView: Bool = false // False para vista de lista, True para vista en cuadrados

    // Estado para el conteo de campos mostrados
    @State private var camposMostrados: Int = 0

    // Onboarding
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @State private var showOnboarding: Bool = false

    // Computed property para saber si hay filtros activos
    private var hasActiveFilters: Bool {
        !searchNombre.isEmpty ||
        !searchLocalidad.isEmpty ||
        selectedProvincia != L(.contentAllProvinces)
    }

    var body: some View {
        ZStack {
            // Fondo que se extiende por completo
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(colorScheme == .dark ? 0.1 : 0.05),
                    Color.green.opacity(colorScheme == .dark ? 0.1 : 0.05)
                ]),
                startPoint: .top, endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)

            // Contenido
            VStack(spacing: 0) {
                if camposViewModel.isLoading && filteredCampos.isEmpty {
                    // Usar skeleton loading para mejor UX
                    if isGridView {
                        SkeletonGridView()
                    } else {
                        LoadingView(message: L(.loadingCampos), style: .skeleton)
                    }
                } else {
                    // Barra de botones y filtros
                    FilterBarView(
                        isGridView: $isGridView,
                        isFilterExpanded: $isFilterExpanded,
                        hasActiveFilters: hasActiveFilters
                    )

                    // Contenedor de filtros colapsable
                    if isFilterExpanded {
                        FiltersView(
                            searchNombre: $searchNombre,
                            searchLocalidad: $searchLocalidad,
                            selectedProvincia: $selectedProvincia,
                            provincias: provincias,
                            applyAction: applyFilters,
                            resetAction: resetFilters
                        )
                        .padding(.top, 4)
                    }

                    // Texto con el conteo de campos mostrados
                    HStack {
                        Text(L(.contentShownFields, camposMostrados))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, isFilterExpanded ? 12 : 8)
                    .padding(.bottom, 4)

                    // Lista de campos filtrada
                    CampoListView(
                        filteredCampos: filteredCampos,
                        isGridView: isGridView,
                        isFilterExpanded: $isFilterExpanded,
                        onRefresh: {
                            await camposViewModel.refreshCampos()
                        }
                    )
                    .environmentObject(authViewModel)
                }
                Spacer()
            }
        }
        .navigationTitle(L(.contentHome))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(L(.appName))
                    .font(.title3)
                    .foregroundColor(.primary)
            }
        }
        .onChange(of: camposViewModel.campos) { oldCampos, newCampos in
            print("Campos cambió, actualizando filteredCampos: \(newCampos.count) campos")
            // Si no hay filtros activos, ordenar alfabéticamente
            if hasActiveFilters {
                applyFilters()
            } else {
                filteredCampos = sortCamposAlphabetically(newCampos)
                camposMostrados = filteredCampos.count
            }
        }
        .onChange(of: camposViewModel.errorMessage) { oldMessage, message in
            if let message = message {
                print("Error al cargar campos: \(message)")
            }
        }
        .onAppear {
            // Inicializar provincia predeterminada
            if selectedProvincia.isEmpty {
                selectedProvincia = L(.contentAllProvinces)
            }
            filteredCampos = sortCamposAlphabetically(camposViewModel.campos)
            camposMostrados = filteredCampos.count
            showOnboarding = !hasSeenOnboarding
        }
        // Cerrar el cover cuando el onboarding marque la flag
        .onChange(of: hasSeenOnboarding) { wasSeen, seen in
            if seen { showOnboarding = false }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView() // Este view marca hasSeenOnboarding = true al terminar
        }
        // NavigationLink invisible para navegación desde notificaciones
        .background(
            NavigationLink(
                destination: notificationCampoID.map {
                    CampoDetalleView(campoID: $0)
                        .environmentObject(camposViewModel)
                        .environmentObject(authViewModel)
                        .environmentObject(geofenceManager)
                        .environmentObject(localizationManager)
                },
                isActive: Binding(
                    get: { notificationCampoID != nil },
                    set: { if !$0 { notificationCampoID = nil } }
                )
            ) {
                EmptyView()
            }
            .hidden()
        )
    }

    func applyFilters() {
        // Si no hay filtros activos, ordenar alfabéticamente
        if !hasActiveFilters {
            filteredCampos = sortCamposAlphabetically(camposViewModel.campos)
            withAnimation(.easeInOut) {
                isFilterExpanded = false
                camposMostrados = filteredCampos.count
            }
            return
        }

        // Calcular similitud para cada campo y filtrar
        let camposConSimilitud = camposViewModel.campos.compactMap { campo -> (campo: CampoModel, score: Double)? in
            // Normalizar strings para comparación (sin acentos ni diferencias de mayúsculas)
            let normalizedSearchNombre = searchNombre
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            let normalizedCampoNombre = campo.nombre
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

            let normalizedSearchLocalidad = searchLocalidad
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            let normalizedCampoLocalidad = (campo.localidad ?? "")
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

            // Verificar provincia primero
            let matchesProvincia = selectedProvincia == L(.contentAllProvinces) || campo.provincia == selectedProvincia
            if !matchesProvincia {
                return nil
            }

            // Calcular scores de similitud
            let scoreNombre = searchNombre.isEmpty ? 1.0 : calculateMatchScore(
                search: normalizedSearchNombre,
                target: normalizedCampoNombre
            )

            let scoreLocalidad = searchLocalidad.isEmpty ? 1.0 : calculateMatchScore(
                search: normalizedSearchLocalidad,
                target: normalizedCampoLocalidad
            )

            // Filtrar los que cumplen el umbral (50%)
            if (searchNombre.isEmpty || scoreNombre >= 0.5) &&
               (searchLocalidad.isEmpty || scoreLocalidad >= 0.5) {
                // Score combinado (promedio ponderado)
                let combinedScore = (scoreNombre + scoreLocalidad) / 2.0
                return (campo, combinedScore)
            }

            return nil
        }

        // Ordenar por score descendente (más similares primero)
        filteredCampos = camposConSimilitud
            .sorted { $0.score > $1.score }
            .map { $0.campo }

        withAnimation(.easeInOut) {
            isFilterExpanded = false
            camposMostrados = filteredCampos.count
        }
    }

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

    func resetFilters() {
        searchNombre = ""
        searchLocalidad = ""
        selectedProvincia = L(.contentAllProvinces)
        filteredCampos = sortCamposAlphabetically(camposViewModel.campos)
        camposMostrados = filteredCampos.count
    }

    /// Ordena los campos alfabéticamente por nombre, ignorando tildes y diferencias de mayúsculas
    private func sortCamposAlphabetically(_ campos: [CampoModel]) -> [CampoModel] {
        return campos.sorted { campo1, campo2 in
            let nombre1 = campo1.nombre.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            let nombre2 = campo2.nombre.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            return nombre1 < nombre2
        }
    }
}

// Subcomponente para la barra de botones de vista y filtros
struct FilterBarView: View {
    @Binding var isGridView: Bool
    @Binding var isFilterExpanded: Bool
    let hasActiveFilters: Bool

    var body: some View {
        HStack(spacing: 16) {
            Button(action: {
                HapticFeedback.light()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isGridView = true
                }
            }) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.title3)
                    .foregroundColor(isGridView ? .blue : .secondary)
                    .frame(width: 44, height: 44)
                    .background(isGridView ? Color.blue.opacity(0.15) : Color.clear)
                    .clipShape(Circle())
            }

            Button(action: {
                HapticFeedback.light()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isGridView = false
                }
            }) {
                Image(systemName: "line.3.horizontal")
                    .font(.title3)
                    .foregroundColor(!isGridView ? .blue : .secondary)
                    .frame(width: 44, height: 44)
                    .background(!isGridView ? Color.blue.opacity(0.15) : Color.clear)
                    .clipShape(Circle())
            }

            Spacer()

            // Botón de filtros (solo ícono)
            Button(action: {
                HapticFeedback.light()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isFilterExpanded.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "line.horizontal.3.decrease.circle.fill")
                        .font(.title3)
                    Text(L(.contentFilterLabel))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor((isFilterExpanded || hasActiveFilters) ? .blue : .secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background((isFilterExpanded || hasActiveFilters) ? Color.blue.opacity(0.15) : Color.clear)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            .ultraThinMaterial
        )
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }
}

// Subcomponente para el contenedor de filtros
struct FiltersView: View {
    @Binding var searchNombre: String
    @Binding var searchLocalidad: String
    @Binding var selectedProvincia: String
    let provincias: [String]
    let applyAction: () -> Void
    let resetAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(L(.contentFilterLabel))
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }

            // Filtro por nombre con icono
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField(L(.contentSearchByName), text: $searchNombre)
            }
            .padding(14)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )

            // Filtro por localidad con icono
            HStack(spacing: 12) {
                Image(systemName: "mappin.circle")
                    .foregroundColor(.secondary)
                TextField(L(.contentSearchByLocation), text: $searchLocalidad)
            }
            .padding(14)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )

            // Filtro por provincia
            VStack(alignment: .leading, spacing: 8) {
                Text(L(.contentProvince))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                Picker(L(.contentProvince), selection: $selectedProvincia) {
                    ForEach(provincias, id: \.self) { provincia in
                        Text(provincia).tag(provincia)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .padding(14)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            }

            // Botones de aplicar y resetear
            HStack(spacing: 12) {
                Button(action: {
                    HapticFeedback.medium()
                    applyAction()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text(L(.contentApply))
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }

                Button(action: {
                    HapticFeedback.light()
                    resetAction()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                        Text(L(.contentReset))
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.tertiarySystemBackground))
                    .foregroundColor(.secondary)
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            .padding(.top, 4)
        }
        .padding(18)
        .background(
            .ultraThinMaterial
        )
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 12)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// Subcomponente para la lista de campos
struct CampoListView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    let filteredCampos: [CampoModel]
    let isGridView: Bool
    @Binding var isFilterExpanded: Bool
    let onRefresh: () async -> Void

    // URL de la imagen predeterminada de Supabase
    private let defaultImageURL = "https://ooqdrhkzsexjnmnvpwqw.supabase.co/storage/v1/object/public/fotos-campos/sin-imagen.png"

    // Campos visitados por el usuario
    @State private var visitedCampoIds: Set<UUID> = []

    var body: some View {
        ScrollView {
            if isGridView {
                // Vista en cuadrados (2 columnas)
                let screenWidth = UIScreen.main.bounds.width
                let horizontalPadding: CGFloat = 12 * 2
                let gridSpacing: CGFloat = 16
                let itemWidth = (screenWidth - horizontalPadding - gridSpacing) / 2

                let columns = [
                    GridItem(.fixed(itemWidth), spacing: gridSpacing),
                    GridItem(.fixed(itemWidth), spacing: gridSpacing)
                ]

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(filteredCampos, id: \.id) { campo in
                        NavigationLink(destination: CampoDetalleView(campoID: campo.id)
                            .environmentObject(authViewModel)) {
                            ZStack(alignment: .topTrailing) {
                                VStack(alignment: .leading, spacing: 0) {
                                    // Imagen con tamaño fijo
                                    let imageURL = (campo.foto_url?.isEmpty == false ? campo.foto_url : nil) ?? defaultImageURL
                                    if let url = URL(string: imageURL) {
                                        CachedAsyncImage(
                                            url: url,
                                            targetSize: CGSize(width: 400, height: 400)
                                        ) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: itemWidth, height: 110)
                                                .clipped()
                                        } placeholder: {
                                            Color.gray.opacity(0.3)
                                                .frame(width: itemWidth, height: 110)
                                        }
                                    }

                                    // Textos con altura fija
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(campo.nombre)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true)

                                        HStack(spacing: 3) {
                                            Image(systemName: "mappin.circle")
                                                .font(.system(size: 9))
                                                .foregroundColor(.secondary)
                                            Text("\(campo.localidad ?? ""), \(campo.provincia)")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    .frame(height: 44, alignment: .top)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                }
                                .frame(width: itemWidth, height: 162)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(14)
                                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)

                                // Indicador de campo visitado
                                if visitedCampoIds.contains(campo.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(.orange)
                                        .background(
                                            Circle()
                                                .fill(Color.white)
                                                .frame(width: 18, height: 18)
                                        )
                                        .padding(8)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 40)
            } else {
                // Vista en lista con diseño mejorado
                LazyVStack(spacing: 12) {
                    ForEach(filteredCampos, id: \.id) { campo in
                        NavigationLink(destination: CampoDetalleView(campoID: campo.id)
                            .environmentObject(authViewModel)) {
                            HStack(spacing: 14) {
                                let imageURL = (campo.foto_url?.isEmpty == false ? campo.foto_url : nil) ?? defaultImageURL
                                if let url = URL(string: imageURL) {
                                    ZStack(alignment: .topTrailing) {
                                        CachedAsyncImage(
                                            url: url,
                                            targetSize: CGSize(width: 120, height: 120)
                                        ) { image in
                                            image
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 70, height: 70)
                                                .cornerRadius(12)
                                                .clipped()
                                        } placeholder: {
                                            Color.gray.opacity(0.3)
                                                .frame(width: 70, height: 70)
                                                .cornerRadius(12)
                                        }

                                        // Indicador de campo visitado
                                        if visitedCampoIds.contains(campo.id) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(.orange)
                                                .background(
                                                    Circle()
                                                        .fill(Color.white)
                                                        .frame(width: 16, height: 16)
                                                )
                                                .offset(x: 6, y: -6)
                                        }
                                    }
                                }
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(campo.nombre)
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.primary)
                                        .lineLimit(2)

                                    HStack(spacing: 4) {
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("\(campo.localidad ?? ""), \(campo.provincia)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(16)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .refreshable {
            await onRefresh()
        }
        .background(Color.clear)
        .simultaneousGesture(
            DragGesture(minimumDistance: 10)
                .onChanged { _ in
                    // Cerrar el desplegable de filtros al detectar scroll
                    if isFilterExpanded {
                        withAnimation(.easeOut(duration: 0.3)) {
                            isFilterExpanded = false
                        }
                    }
                }
        )
        .onAppear {
            loadVisitedCampos()
        }
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
                }
            } catch {
                Logger.error("Error loading visited campos: \(error.localizedDescription)")
            }
        }
    }
}
