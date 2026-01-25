import SwiftUI
import Supabase

struct ContentView: View {
    @EnvironmentObject var camposViewModel: CamposViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var localizationManager: LocalizationManager
    @Environment(\.colorScheme) var colorScheme

    // Estados para los filtros
    @State private var searchNombre: String = ""
    @State private var searchLocalidad: String = ""
    @State private var selectedProvincia: String = ""
    @State private var isFilterExpanded: Bool = false // Controla si el contenedor de filtros está abierto

    // Lista de provincias disponibles
    var provincias: [String] {
        [L(.contentAllProvinces), "A Coruña", "Ourense", "Lugo", "Pontevedra"]
    }
    
    // Lista de campos y estado de carga gestionados por el view model
    @Binding var distanciaPredeterminada: Double // Añadimos el binding
    
    // Lista de campos filtrada
    @State private var filteredCampos: [CampoModel] = []
    
    // Estado para controlar la vista (predeterminada como lista)
    @State private var isGridView: Bool = false // False para vista de lista, True para vista en cuadrados
    
    // Estado para el conteo de campos mostrados
    @State private var camposMostrados: Int = 0

    // Onboarding
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @State private var showOnboarding: Bool = false

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
                        isFilterExpanded: $isFilterExpanded
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
                    }

                    // Texto con el conteo de campos mostrados
                    Text(L(.contentShownFields, camposMostrados))
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                        .padding(.top, 8) // Aumentamos la separación superior
                        .padding(.bottom, 4)

                    // Lista de campos filtrada
                    CampoListView(
                        filteredCampos: filteredCampos,
                        isGridView: isGridView,
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
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task {
                        await camposViewModel.refreshCampos()
                        filteredCampos = camposViewModel.campos
                        camposMostrados = filteredCampos.count
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(camposViewModel.isLoading)
            }
        }
        .onChange(of: camposViewModel.campos) { oldCampos, newCampos in
            print("Campos cambió, actualizando filteredCampos: \(newCampos.count) campos")
            filteredCampos = newCampos
            camposMostrados = filteredCampos.count
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
            filteredCampos = camposViewModel.campos
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
    }

    func applyFilters() {
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
        filteredCampos = camposViewModel.campos
        camposMostrados = filteredCampos.count
    }
}

// Subcomponente para la barra de botones de vista y filtros
struct FilterBarView: View {
    @Binding var isGridView: Bool
    @Binding var isFilterExpanded: Bool

    var body: some View {
        HStack(spacing: 20) {
            Button(action: {
                withAnimation(.easeInOut) {
                    isGridView = true
                }
            }) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.title2)
                    .foregroundColor(isGridView ? .blue : .secondary)
                    .padding(10)
                    .background(isGridView ? Color.blue.opacity(0.1) : Color.clear)
                    .clipShape(Circle())
            }

            Button(action: {
                withAnimation(.easeInOut) {
                    isGridView = false
                }
            }) {
                Image(systemName: "line.3.horizontal")
                    .font(.title2)
                    .foregroundColor(!isGridView ? .blue : .secondary)
                    .padding(10)
                    .background(!isGridView ? Color.blue.opacity(0.1) : Color.clear)
                    .clipShape(Circle())
            }

            Spacer()

            // Botón de filtros (solo ícono)
            Button(action: {
                withAnimation(.easeInOut) {
                    isFilterExpanded.toggle()
                }
            }) {
                Image(systemName: "line.horizontal.3.decrease.circle.fill")
                    .font(.title2)
                    .foregroundColor(isFilterExpanded ? .blue : .secondary)
                    .padding(10)
                    .background(isFilterExpanded ? Color.blue.opacity(0.1) : Color.clear)
                    .clipShape(Circle())
            }
        }
        .padding()
        .background(
            LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.1), Color(UIColor.secondarySystemBackground).opacity(0.8)]), startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
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
        VStack(spacing: 12) {
            Text(L(.contentFilterLabel))
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Filtro por nombre
            TextField(L(.contentSearchByName), text: $searchNombre)
                .padding()
                .background(Color(.secondarySystemFill))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                )

            // Filtro por localidad
            TextField(L(.contentSearchByLocation), text: $searchLocalidad)
                .padding()
                .background(Color(.secondarySystemFill))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                )

            // Filtro por provincia
            Text(L(.contentProvince))
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ZStack(alignment: .leading) {
                Color(.secondarySystemFill)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                    )

                Picker(L(.contentProvince), selection: $selectedProvincia) {
                    ForEach(provincias, id: \.self) { provincia in
                        Text(provincia).tag(provincia)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .padding(.horizontal)
                .padding(.vertical, 10)
                .foregroundColor(.secondary)
                .frame(minHeight: 44)
            }
            .frame(maxWidth: .infinity)

            // Botones de aplicar y resetear
            HStack(spacing: 10) {
                Button(action: applyAction) {
                    Text(L(.contentApply))
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.2), radius: 4)
                }

                Button(action: resetAction) {
                    Text(L(.contentReset))
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.2), radius: 4)
                }
            }
        }
        .padding()
        .background(
            LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.1), Color(UIColor.systemBackground).opacity(0.95)]), startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
    }
}

// Subcomponente para la lista de campos
struct CampoListView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    let filteredCampos: [CampoModel]
    let isGridView: Bool
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

                LazyVGrid(columns: columns, spacing: 16) {
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
                                                .frame(width: itemWidth, height: 100)
                                                .clipped()
                                        } placeholder: {
                                            Color.gray.opacity(0.3)
                                                .frame(width: itemWidth, height: 100)
                                        }
                                    }

                                    // Textos con altura fija
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(campo.nombre)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true)

                                        Text("\(campo.localidad ?? ""), \(campo.provincia)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    .frame(height: 42, alignment: .top)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                }
                                .frame(width: itemWidth, height: 148)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(10)
                                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)

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
                                        .padding(6)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
            } else {
                // Vista en lista
                LazyVStack(spacing: 0) {
                    ForEach(filteredCampos, id: \.id) { campo in
                        NavigationLink(destination: CampoDetalleView(campoID: campo.id)
                            .environmentObject(authViewModel)) {
                            HStack(spacing: 12) {
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
                                                .frame(width: 60, height: 60)
                                                .cornerRadius(10)
                                                .clipped()
                                        } placeholder: {
                                            Color.gray.opacity(0.3)
                                                .frame(width: 60, height: 60)
                                                .cornerRadius(10)
                                        }

                                        // Indicador de campo visitado
                                        if visitedCampoIds.contains(campo.id) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 18))
                                                .foregroundColor(.orange)
                                                .background(
                                                    Circle()
                                                        .fill(Color.white)
                                                        .frame(width: 14, height: 14)
                                                )
                                                .offset(x: 4, y: -4)
                                        }
                                    }
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(campo.nombre)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text("\(campo.localidad), \(campo.provincia)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding()
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .refreshable {
            await onRefresh()
        }
        .background(Color.clear)
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
