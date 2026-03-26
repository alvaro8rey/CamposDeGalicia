import SwiftUI
import Supabase

struct ContentView: View {
    @EnvironmentObject var camposViewModel: CamposViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var localizationManager: LocalizationManager
    @EnvironmentObject var geofenceManager: GeofenceManager
    @Environment(\.colorScheme) var colorScheme

    // Búsqueda unificada
    @State private var searchText: String = ""
    @State private var filterDebounceTask: Task<Void, Never>?
    @FocusState private var isSearchFocused: Bool

    // Lista de campos y estado de carga gestionados por el view model
    @Binding var distanciaPredeterminada: Double

    // Binding para navegación desde notificaciones
    @Binding var notificationCampoID: UUID?

    // Lista de campos filtrada
    @State private var filteredCampos: [CampoModel] = []

    // Estado para controlar la vista (predeterminada como lista)
    @State private var isGridView: Bool = false

    // Estado para el conteo de campos mostrados
    @State private var camposMostrados: Int = 0

    // Onboarding
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @State private var showOnboarding: Bool = false

    // Sugerir campo
    @State private var showSugerirCampo: Bool = false

    private var hasActiveFilters: Bool {
        !searchText.isEmpty
    }

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(colorScheme == .dark ? 0.1 : 0.05),
                    Color.green.opacity(colorScheme == .dark ? 0.1 : 0.05)
                ]),
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                if camposViewModel.isLoading && filteredCampos.isEmpty {
                    if isGridView {
                        SkeletonGridView()
                    } else {
                        LoadingView(message: L(.loadingCampos), style: .skeleton)
                    }
                } else {
                    // MARK: - Search Bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(isSearchFocused ? .blue : .secondary)
                            .font(.subheadline)

                        TextField(L(.contentSearchByName), text: $searchText)
                            .textFieldStyle(.plain)
                            .font(.body)
                            .focused($isSearchFocused)

                        if !searchText.isEmpty {
                            Button {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    searchText = ""
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.subheadline)
                            }
                            .transition(.scale.combined(with: .opacity))
                        }

                        Divider()
                            .frame(height: 18)

                        Button {
                            HapticFeedback.light()
                            showSugerirCampo = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSearchFocused ? Color.blue.opacity(0.4) : Color.gray.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .animation(.easeInOut(duration: 0.2), value: isSearchFocused)

                    // MARK: - Campo Count
                    HStack {
                        Text(L(.contentShownFields, camposMostrados))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 4)

                    // MARK: - Campo List
                    CampoListView(
                        filteredCampos: filteredCampos,
                        isGridView: isGridView,
                        onRefresh: {
                            await camposViewModel.refreshCampos()
                        }
                    )
                    .ignoresSafeArea(.container, edges: .bottom)
                    .environmentObject(authViewModel)
                }
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
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    HapticFeedback.light()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isGridView.toggle()
                    }
                } label: {
                    Image(systemName: isGridView ? "list.bullet" : "square.grid.2x2")
                        .font(.body)
                        .foregroundColor(.blue)
                }
            }
        }
        .onChange(of: searchText) { _, _ in
            applyFiltersDebounced()
        }
        .onChange(of: camposViewModel.campos) { oldCampos, newCampos in
            Logger.debug("Campos cambió, actualizando filteredCampos: \(newCampos.count) campos")
            if hasActiveFilters {
                applyFilters()
            } else {
                filteredCampos = sortCamposAlphabetically(newCampos)
                camposMostrados = filteredCampos.count
            }
        }
        .onChange(of: camposViewModel.errorMessage) { oldMessage, message in
            if let message = message {
                Logger.debug("Error al cargar campos: \(message)")
            }
        }
        .onAppear {
            filteredCampos = sortCamposAlphabetically(camposViewModel.campos)
            camposMostrados = filteredCampos.count
            showOnboarding = !hasSeenOnboarding
            AnalyticsManager.shared.trackScreen("home")
        }
        .onChange(of: isGridView) { _, newValue in
            AnalyticsManager.shared.trackButton(
                name: newValue ? "grid_view" : "list_view",
                screen: "home"
            )
        }
        .onChange(of: hasSeenOnboarding) { wasSeen, seen in
            if seen { showOnboarding = false }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView()
        }
        .sheet(isPresented: $showSugerirCampo) {
            NavigationView {
                SugerirCampoView()
                    .environmentObject(localizationManager)
                    .environmentObject(authViewModel)
            }
        }
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

    // MARK: - Filtering

    private func applyFiltersDebounced() {
        filterDebounceTask?.cancel()
        filterDebounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            applyFilters()
        }
    }

    func applyFilters() {
        if !hasActiveFilters {
            filteredCampos = sortCamposAlphabetically(camposViewModel.campos)
            camposMostrados = filteredCampos.count
            return
        }

        // ✅ FIX: Mover cálculo de Levenshtein a background thread para evitar congelación de UI
        let searchText = self.searchText
        let campos = camposViewModel.campos

        Task(priority: .userInitiated) {
            let normalizedSearch = searchText
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

            // Cálculo pesado en background thread
            let camposConSimilitud = campos.compactMap { campo -> (campo: CampoModel, score: Double)? in
                let normalizedNombre = campo.nombre
                    .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                let normalizedLocalidad = (campo.localidad ?? "")
                    .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

                // Buscar en nombre y localidad, quedarse con el mejor score
                let scoreNombre = self.calculateMatchScore(search: normalizedSearch, target: normalizedNombre)
                let scoreLocalidad = self.calculateMatchScore(search: normalizedSearch, target: normalizedLocalidad)
                let bestScore = max(scoreNombre, scoreLocalidad)

                // Umbral mínimo del 50%
                if bestScore >= 0.5 {
                    return (campo, bestScore)
                }

                return nil
            }

            let sorted = camposConSimilitud
                .sorted { $0.score > $1.score }
                .map { $0.campo }

            // Solo actualizar UI en main thread
            await MainActor.run {
                self.filteredCampos = sorted
                self.camposMostrados = sorted.count
                AnalyticsManager.shared.trackSearch(query: searchText, resultsCount: sorted.count)
            }
        }
    }

    private func calculateMatchScore(search: String, target: String) -> Double {
        if search.isEmpty || target.isEmpty { return 0.0 }

        let searchNoSpaces = search.replacingOccurrences(of: " ", with: "")
        let targetNoSpaces = target.replacingOccurrences(of: " ", with: "")

        if targetNoSpaces == searchNoSpaces { return 1.0 }
        if target == search { return 0.98 }
        if targetNoSpaces.contains(searchNoSpaces) { return 0.95 }
        if target.contains(search) { return 0.90 }

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
                return avgSimilarity * 0.85
            }
        }

        let similarity = stringSimilarity(searchNoSpaces, targetNoSpaces)
        return similarity * 0.70
    }

    private func stringSimilarity(_ s1: String, _ s2: String) -> Double {
        if s1.isEmpty || s2.isEmpty {
            return s1.isEmpty && s2.isEmpty ? 1.0 : 0.0
        }
        let distance = levenshteinDistance(s1, s2)
        let maxLength = max(s1.count, s2.count)
        return 1.0 - (Double(distance) / Double(maxLength))
    }

    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let m = s1Array.count
        let n = s2Array.count

        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in 0...m { dp[i][0] = i }
        for j in 0...n { dp[0][j] = j }

        for i in 1...m {
            for j in 1...n {
                let cost = s1Array[i - 1] == s2Array[j - 1] ? 0 : 1
                dp[i][j] = min(
                    dp[i - 1][j] + 1,
                    dp[i][j - 1] + 1,
                    dp[i - 1][j - 1] + cost
                )
            }
        }
        return dp[m][n]
    }

    private func sortCamposAlphabetically(_ campos: [CampoModel]) -> [CampoModel] {
        return campos.sorted { campo1, campo2 in
            let nombre1 = campo1.nombre.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            let nombre2 = campo2.nombre.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            return nombre1 < nombre2
        }
    }
}

// MARK: - Campo List View

struct CampoListView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    let filteredCampos: [CampoModel]
    let isGridView: Bool
    let onRefresh: () async -> Void

    private let defaultImageURL = "https://ooqdrhkzsexjnmnvpwqw.supabase.co/storage/v1/object/public/fotos-campos/sin-imagen.png"

    @State private var visitedCampoIds: Set<UUID> = []

    var body: some View {
        ScrollView {
            if isGridView {
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
                                .background(.ultraThinMaterial)
                                .cornerRadius(14)
                                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)

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
                            .background(.ultraThinMaterial)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .ignoresSafeArea(.all, edges: .bottom)
        .scrollDismissesKeyboard(.interactively)
        .refreshable {
            await onRefresh()
        }
        .background(Color.clear)
        .onAppear {
            loadVisitedCampos()
        }
        .onChange(of: authViewModel.isAuthenticated) { _, isAuthenticated in
            if !isAuthenticated {
                visitedCampoIds = []
            } else {
                loadVisitedCampos()
            }
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
