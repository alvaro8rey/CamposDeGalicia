import SwiftUI

struct ContentView: View {
    @EnvironmentObject var camposViewModel: CamposViewModel
    @EnvironmentObject var authViewModel: AuthViewModel

    // Estados para los filtros
    @State private var searchNombre: String = ""
    @State private var searchLocalidad: String = ""
    @State private var selectedProvincia: String = "Todas"
    @State private var isFilterExpanded: Bool = false // Controla si el contenedor de filtros está abierto
    
    // Lista de provincias disponibles
    let provincias = ["Todas", "A Coruña", "Ourense", "Lugo", "Pontevedra"]
    
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
        VStack(spacing: 0) {
            if camposViewModel.isLoading && filteredCampos.isEmpty {
                ProgressView("Cargando campos...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
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
                Text("Mostrados \(camposMostrados) campos")
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
        .navigationTitle("Inicio")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Campos de Galicia")
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
        .background(
            LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.15), Color(UIColor.systemBackground).opacity(0.9)]), startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .onChange(of: camposViewModel.campos) { newCampos in
            print("Campos cambió, actualizando filteredCampos: \(newCampos.count) campos")
            filteredCampos = newCampos
            camposMostrados = filteredCampos.count
        }
        .onChange(of: camposViewModel.errorMessage) { message in
            if let message = message {
                print("Error al cargar campos: \(message)")
            }
        }
        .onAppear {
            filteredCampos = camposViewModel.campos
            camposMostrados = filteredCampos.count
            showOnboarding = !hasSeenOnboarding
        }
        // Cerrar el cover cuando el onboarding marque la flag
        .onChange(of: hasSeenOnboarding) { seen in
            if seen { showOnboarding = false }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView() // Este view marca hasSeenOnboarding = true al terminar
        }
    }

    func applyFilters() {
        filteredCampos = camposViewModel.campos.filter { campo in
            // Normalizar strings para comparación (sin acentos ni diferencias de mayúsculas)
            let normalizedSearchNombre = searchNombre
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            let normalizedCampoNombre = campo.nombre
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

            let normalizedSearchLocalidad = searchLocalidad
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            let normalizedCampoLocalidad = (campo.localidad ?? "")
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

            // Búsqueda con tolerancia a errores (fuzzy search)
            let matchesNombre = searchNombre.isEmpty || fuzzyMatch(
                search: normalizedSearchNombre,
                target: normalizedCampoNombre,
                threshold: 0.5
            )

            let matchesProvincia = selectedProvincia == "Todas" || campo.provincia == selectedProvincia

            let matchesLocalidad = searchLocalidad.isEmpty || fuzzyMatch(
                search: normalizedSearchLocalidad,
                target: normalizedCampoLocalidad,
                threshold: 0.5
            )

            return matchesNombre && matchesProvincia && matchesLocalidad
        }
        withAnimation(.easeInOut) {
            isFilterExpanded = false
            camposMostrados = filteredCampos.count
        }
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
        selectedProvincia = "Todas"
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
            Text("Filtrar:")
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Filtro por nombre
            TextField("Buscar por nombre", text: $searchNombre)
                .padding()
                .background(Color(.secondarySystemFill))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                )

            // Filtro por localidad
            TextField("Buscar por localidad", text: $searchLocalidad)
                .padding()
                .background(Color(.secondarySystemFill))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                )

            // Filtro por provincia
            Text("Provincia:")
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
                
                Picker("Provincia", selection: $selectedProvincia) {
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
                    Text("Aplicar")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.2), radius: 4)
                }

                Button(action: resetAction) {
                    Text("Resetear")
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

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredCampos, id: \.id) { campo in
                    if isGridView {
                        // Vista en cuadrados (tarjetas)
                        NavigationLink(destination: CampoDetalleView(campoID: campo.id)
                            .environmentObject(authViewModel)) {
                            VStack(alignment: .leading, spacing: 8) {
                                let imageURL = (campo.foto_url?.isEmpty == false ? campo.foto_url : nil) ?? defaultImageURL
                                if let url = URL(string: imageURL) {
                                    CachedAsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: UIScreen.main.bounds.width - 40, height: 180)
                                            .cornerRadius(12)
                                            .clipped()
                                    } placeholder: {
                                        Color.gray.opacity(0.3)
                                            .frame(width: UIScreen.main.bounds.width - 40, height: 180)
                                            .cornerRadius(12)
                                    }
                                }

                                Text(campo.nombre)
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)

                                Text("\(campo.localidad), \(campo.provincia)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        // Vista en lista
                        NavigationLink(destination: CampoDetalleView(campoID: campo.id)
                            .environmentObject(authViewModel)) {
                            HStack(spacing: 12) {
                                let imageURL = (campo.foto_url?.isEmpty == false ? campo.foto_url : nil) ?? defaultImageURL
                                if let url = URL(string: imageURL) {
                                    CachedAsyncImage(url: url) { image in
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
    }
}
