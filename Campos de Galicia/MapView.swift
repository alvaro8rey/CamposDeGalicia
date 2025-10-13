import SwiftUI
import MapKit
import CoreLocation
import Supabase

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
        self.subtitle = annotationItem.subtitle
    }
}

struct CachedCoordinate: Codable {
    let latitude: Double
    let longitude: Double
}

struct Filtros: Equatable {
    var tipo: String? = nil
    var superficie: String? = nil
    var provincia: String? = nil
    var nombre: String? = nil
    var localidad: String? = nil
}

struct MapaView: View {
    @State private var region: MKCoordinateRegion
    @State private var isSatelliteView: Bool = false
    @State private var selectedCampo: CampoModel? = nil
    @State private var annotationItems: [MapAnnotationItem] = []
    @State private var showFiltros: Bool = false
    @State private var filtros: Filtros = Filtros()
    @State private var showOnlyVisited: Bool = false
    @State private var visitedCampoIds: Set<String> = []
    @State private var isLoadingVisited: Bool = false
    @State private var errorMessage: String? = nil
    @State private var userTrackingMode: MKUserTrackingMode = .none
    
    let campos: [CampoModel]
    private let geocoder = CLGeocoder()
    private let cache = UserDefaults.standard
    
    var isUserAuthenticated: Bool {
        return supabase.auth.currentUser != nil
    }
    
    init(campos: [CampoModel]) {
        self.campos = campos
        self._filteredCampos = State(initialValue: campos)
        let initialRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 42.5, longitude: -8.5),
            span: MKCoordinateSpan(latitudeDelta: 2, longitudeDelta: 2)
        )
        self._region = State(initialValue: initialRegion)
    }

    @State private var filteredCampos: [CampoModel]
    @State private var mapView: MKMapView?

    var body: some View {
        ZStack {
            CustomMapView(
                region: $region,
                isSatelliteView: $isSatelliteView,
                annotations: annotationItems,
                selectedCampo: $selectedCampo,
                userTrackingMode: $userTrackingMode,
                onSelectCampo: { campo in
                    selectedCampo = campo
                },
                mapView: $mapView
            )
            .edgesIgnoringSafeArea(.all)
            .cornerRadius(10)
            .shadow(radius: 5)

            VStack {
                Text("Explora los campos de Galicia en el mapa y selecciona uno para ver más detalles.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground).opacity(0.9))
                    .cornerRadius(8)
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    .padding(.top, 10)
                    .padding(.horizontal)

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }

                Spacer()

                HStack(alignment: .bottom, spacing: 0) {
                    // Botón de filtros (Izquierda)
                    Button(action: {
                        showFiltros = true
                    }) {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundColor(.white)
                    }
                    .frame(width: 40, height: 40)
                    .background(Color.black.opacity(0.8))
                    .clipShape(Circle())
                    .shadow(radius: 3)
                    .padding(.leading, 20)

                    Spacer()

                    // Botones agrupados en el lado derecho
                    VStack(spacing: 10) {
                        if isUserAuthenticated {
                            Button(action: {
                                showOnlyVisited.toggle()
                            }) {
                                Image(systemName: showOnlyVisited ? "eye.fill" : "eye.slash.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                                    .foregroundColor(.white)
                            }
                            .frame(width: 40, height: 40)
                            .background(Color.black.opacity(0.8))
                            .clipShape(Circle())
                            .shadow(radius: 3)
                            .disabled(isLoadingVisited)
                            .onChange(of: showOnlyVisited) { _ in
                                applyFiltros()
                            }
                        }

                        Button(action: {
                            withAnimation {
                                isSatelliteView.toggle()
                            }
                        }) {
                            Image(systemName: isSatelliteView ? "map.fill" : "globe.europe.africa.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .foregroundColor(.white)
                        }
                        .frame(width: 40, height: 40)
                        .background(Color.black.opacity(0.8))
                        .clipShape(Circle())
                        .shadow(radius: 3)

                        Button(action: {
                            print("Centrar button pressed")
                            if let userLocation = CustomMapView.Coordinator.lastUserLocation {
                                print("User location found: \(userLocation.coordinate.latitude), \(userLocation.coordinate.longitude)")
                                let newRegion = MKCoordinateRegion(
                                    center: userLocation.coordinate,
                                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                                )
                                print("New region calculated: \(newRegion.center.latitude), \(newRegion.center.longitude)")
                                withAnimation {
                                    region = newRegion
                                }
                                if let mapView = mapView {
                                    print("MapView region before set: \(mapView.region.center.latitude), \(mapView.region.center.longitude)")
                                    // Deshabilitar temporariamente las anotaciones para evitar conflictos
                                    mapView.removeAnnotations(mapView.annotations)
                                    mapView.setRegion(newRegion, animated: true)
                                    print("MapView region after set: \(mapView.region.center.latitude), \(mapView.region.center.longitude)")
                                    // Restaurar anotaciones
                                    let annotations = annotationItems.map { item -> CampoAnnotation in
                                        return CampoAnnotation(annotationItem: item)
                                    }
                                    mapView.addAnnotations(annotations)
                                } else {
                                    print("MapView reference is nil")
                                }
                                // Intentar usar userTrackingMode temporalmente
                                userTrackingMode = .follow
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    if let mapView = mapView {
                                        print("Restoring userTrackingMode to: \(userTrackingMode.rawValue) after centering")
                                        mapView.userTrackingMode = .none
                                    }
                                }
                            } else {
                                print("User location not available")
                            }
                            print("Current userTrackingMode: \(userTrackingMode.rawValue)")
                        }) {
                            Image(systemName: "location.north.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .foregroundColor(.white)
                        }
                        .frame(width: 40, height: 40)
                        .background(Color.black.opacity(0.8))
                        .clipShape(Circle())
                        .shadow(radius: 3)
                    }
                    .padding(.trailing, 20)
                }
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("Mapa")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Mapa")
                    .font(.title3)
                    .foregroundColor(.primary)
            }
        }
        .sheet(item: $selectedCampo) { campo in
            CampoDetalleView(campo: campo)
        }
        .sheet(isPresented: $showFiltros) {
            FiltrosView(filtros: $filtros, onApply: { newFiltros in
                filtros = newFiltros
                applyFiltros()
            })
        }
        .onAppear {
            Task {
                await loadVisitedCampos()
                applyFiltros()
            }
        }
        .onChange(of: campos) { _ in
            applyFiltros()
        }
        .onChange(of: filtros) { _ in
            applyFiltros()
        }
        .onReceive(NotificationCenter.default.publisher(for: .didUpdateVisits)) { _ in
            Task {
                await loadVisitedCampos()
                applyFiltros()
            }
        }
    }
    
    private func applyFiltros() {
        filteredCampos = campos.filter { campo in
            var matches = true
            
            if let tipo = filtros.tipo, !tipo.isEmpty {
                matches = matches && campo.tipo.compare(tipo, options: .caseInsensitive) == .orderedSame
            }
            
            if let superficie = filtros.superficie, !superficie.isEmpty {
                matches = matches && campo.superficie.compare(superficie, options: .caseInsensitive) == .orderedSame
            }
            
            if let provincia = filtros.provincia, !provincia.isEmpty {
                matches = matches && campo.provincia.compare(provincia, options: .caseInsensitive) == .orderedSame
            }
            
            if let nombre = filtros.nombre, !nombre.isEmpty {
                matches = matches && campo.nombre.localizedCaseInsensitiveContains(nombre)
            }
            
            if let localidad = filtros.localidad, !localidad.isEmpty {
                matches = matches && campo.localidad.localizedCaseInsensitiveContains(localidad)
            }
            
            if showOnlyVisited {
                matches = matches && visitedCampoIds.contains(campo.id.uuidString.lowercased())
            }
            
            return matches
        }
        
        print("Campos filtrados: \(filteredCampos.map { $0.nombre })")
        updateAnnotations()
    }
    
    private func loadVisitedCampos() async {
           isLoadingVisited = true
           errorMessage = nil
           
           guard let user = supabase.auth.currentUser else {
               print("Usuario no autenticado, no se cargan campos visitados")
               visitedCampoIds = []
               isLoadingVisited = false
               errorMessage = "Inicia sesión para ver campos visitados"
               return
           }
           
           do {
               let visitasResponse = try await supabase.from("visitas")
                   .select("id_campo")
                   .eq("id_usuario", value: user.id.uuidString)
                   .execute()
               let visitaData = visitasResponse.data
               let jsonObject = try JSONSerialization.jsonObject(with: visitaData, options: [])
               if let array = jsonObject as? [[String: Any]] {
                   let campoIds = array.compactMap { $0["id_campo"] as? String }
                   visitedCampoIds = Set(campoIds.map { $0.lowercased() })
                   print("Campos visitados cargados: \(visitedCampoIds)")
               } else {
                   print("Formato de datos de visitas inesperado")
                   errorMessage = "Error: Formato de datos de visitas inesperado"
               }
           } catch {
               print("Error al cargar campos visitados: \(error.localizedDescription)")
               errorMessage = "Error al cargar campos visitados: \(error.localizedDescription)"
               visitedCampoIds = []
           }
           isLoadingVisited = false
       }
    
    private func updateAnnotations() {
        annotationItems.removeAll()
        
        Task {
            for campo in filteredCampos {
                if let lat = campo.latitud, let lon = campo.longitud,
                   lat >= -90 && lat <= 90, lon >= -180 && lon <= 180 {
                    let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    let annotation = MapAnnotationItem(
                        coordinate: coordinate,
                        title: campo.nombre,
                        subtitle: "\(campo.localidad), \(campo.provincia)",
                        campo: campo,
                        isFromManualCoordinates: true
                    )
                    DispatchQueue.main.async {
                        annotationItems.append(annotation)
                        updateRegion(with: annotationItems)
                    }
                    print("Añadida anotación para \(campo.nombre) con coordenadas explícitas: \(lat), \(lon)")
                } else {
                    print("Ignorando \(campo.nombre): sin coordenadas explícitas")
                }
            }
            print("Procesamiento de anotaciones completado. Total de anotaciones: \(annotationItems.count)")
        }
    }
    
    private func updateRegion(with annotations: [MapAnnotationItem]) {
        let validCoordinates = annotations.map { $0.coordinate }
        
        guard !validCoordinates.isEmpty else {
            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 42.5, longitude: -8.5),
                span: MKCoordinateSpan(latitudeDelta: 2, longitudeDelta: 2)
            )
            return
        }

        let minLat = validCoordinates.map { $0.latitude }.min() ?? 42.5
        let maxLat = validCoordinates.map { $0.latitude }.max() ?? 42.5
        let minLon = validCoordinates.map { $0.longitude }.min() ?? -8.5
        let maxLon = validCoordinates.map { $0.longitude }.max() ?? -8.5

        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let latDelta = (maxLat - minLat) * 2.0
        let lonDelta = (maxLon - minLon) * 2.0
        
        let span = MKCoordinateSpan(
            latitudeDelta: max(latDelta, 0.01),
            longitudeDelta: max(lonDelta, 0.01)
        )
        
        region = MKCoordinateRegion(center: center, span: span)
    }
}

struct CustomMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var isSatelliteView: Bool
    var annotations: [MapAnnotationItem]
    @Binding var selectedCampo: CampoModel?
    @Binding var userTrackingMode: MKUserTrackingMode
    let onSelectCampo: (CampoModel) -> Void
    @Binding var mapView: MKMapView?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.region = region
        mapView.mapType = isSatelliteView ? .satellite : .standard
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.showsUserLocation = true // Muestra la ubicación del usuario
        mapView.userTrackingMode = userTrackingMode
        self.mapView = mapView // Asignar la referencia
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        print("updateUIView called with region: \(uiView.region.center.latitude), \(uiView.region.center.longitude)") // Depuración
        uiView.mapType = isSatelliteView ? .satellite : .standard
        uiView.region = region
        print("Setting userTrackingMode to: \(userTrackingMode.rawValue)") // Depuración
        uiView.userTrackingMode = userTrackingMode

        // Eliminar anotaciones antiguas
        uiView.removeAnnotations(uiView.annotations)
        
        // Añadir todas las anotaciones
        let annotations = self.annotations.map { item -> CampoAnnotation in
            return CampoAnnotation(annotationItem: item)
        }
        uiView.addAnnotations(annotations)
        
        // Asegurarse de que todas las anotaciones sean visibles
        if !annotations.isEmpty {
            let coordinates = annotations.map { $0.coordinate }
            let rect = coordinates.reduce(MKMapRect.null) { rect, coordinate in
                let point = MKMapPoint(coordinate)
                let annotationRect = MKMapRect(x: point.x, y: point.y, width: 0.1, height: 0.1)
                return rect.union(annotationRect)
            }
            let paddedRect = uiView.mapRectThatFits(rect, edgePadding: UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50))
            uiView.setVisibleMapRect(paddedRect, animated: false)
            
            // Forzar visibilidad de todas las anotaciones
            for annotation in annotations {
                if let view = uiView.view(for: annotation) {
                    view.isHidden = false
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: CustomMapView
        static var lastUserLocation: CLLocation?
        var lastLocationUpdate: Date?

        init(_ parent: CustomMapView) {
            self.parent = parent
            super.init()
        }

        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            Coordinator.lastUserLocation = userLocation.location
            if lastLocationUpdate == nil || Date().timeIntervalSince(lastLocationUpdate!) > 5 {
                lastLocationUpdate = Date()
                print("User location updated: \(userLocation.coordinate.latitude), \(userLocation.coordinate.longitude)")
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let campoAnnotation = annotation as? CampoAnnotation else { return nil }

            let identifier = "CampoAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.markerTintColor = .blue
                annotationView?.canShowCallout = true
                let detailButton = UIButton(type: .detailDisclosure)
                detailButton.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
                print("Creando botón para anotación: \(annotation.title ?? "Sin título")")
                annotationView?.rightCalloutAccessoryView = detailButton
                annotationView?.displayPriority = .required
                annotationView?.collisionMode = .none
            } else {
                annotationView?.annotation = annotation
                annotationView?.markerTintColor = .blue
                let detailButton = UIButton(type: .detailDisclosure)
                detailButton.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
                print("Reutilizando botón para anotación: \(annotation.title ?? "Sin título")")
                annotationView?.rightCalloutAccessoryView = detailButton
                annotationView?.displayPriority = .required
                annotationView?.collisionMode = .none
            }

            return annotationView
        }

        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
            print("calloutAccessoryControlTapped ejecutado")
            if let campoAnnotation = view.annotation as? CampoAnnotation {
                let item = campoAnnotation.annotationItem
                print("Botón tocado para campo: \(item.campo.nombre)")
                DispatchQueue.main.async {
                    self.parent.onSelectCampo(item.campo)
                    self.parent.selectedCampo = item.campo
                    print("selectedCampo actualizado: \(self.parent.selectedCampo?.nombre ?? "Ninguno")")
                }
            } else {
                print("No se pudo encontrar la anotación correspondiente")
            }
        }
    }
}

struct FiltrosView: View {
    @Binding var filtros: Filtros
    let onApply: (Filtros) -> Void
    @Environment(\.dismiss) var dismiss
    
    private let tipos = ["", "Fútbol 11", "Fútbol 7", "Fútbol Sala"]
    private let superficies = ["", "Hierba Natural", "Hierba Artificial", "Tierra"]
    private let provincias = ["", "A Coruña", "Lugo", "Ourense", "Pontevedra"]
    
    @State private var selectedTipo: String = ""
    @State private var selectedSuperficie: String = ""
    @State private var selectedProvincia: String = ""
    @State private var nombre: String = ""
    @State private var localidad: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Filtros de Campos")
                    .font(.headline)
                    .foregroundColor(.blue)) {
                    TextField("Nombre del campo", text: $nombre)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                    
                    TextField("Localidad", text: $localidad)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                    
                    Picker("Tipo de campo", selection: $selectedTipo) {
                        ForEach(tipos, id: \.self) { tipo in
                            Text(tipo.isEmpty ? "Todos" : tipo).tag(tipo)
                        }
                    }
                    
                    Picker("Superficie", selection: $selectedSuperficie) {
                        ForEach(superficies, id: \.self) { superficie in
                            Text(superficie.isEmpty ? "Todas" : superficie).tag(superficie)
                        }
                    }
                    
                    Picker("Provincia", selection: $selectedProvincia) {
                        ForEach(provincias, id: \.self) { provincia in
                            Text(provincia.isEmpty ? "Todas" : provincia).tag(provincia)
                        }
                    }
                }
            }
            .background(Color(.systemBackground))
            .scrollContentBackground(.hidden)
            .navigationTitle("Filtros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
                ToolbarItem(placement: .automatic) {
                    Button("Restablecer") {
                        selectedTipo = ""
                        selectedSuperficie = ""
                        selectedProvincia = ""
                        nombre = ""
                        localidad = ""
                        filtros = Filtros()
                        onApply(filtros)
                    }
                    .foregroundColor(.gray)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Aplicar") {
                        filtros = Filtros(
                            tipo: selectedTipo.isEmpty ? nil : selectedTipo,
                            superficie: selectedSuperficie.isEmpty ? nil : selectedSuperficie,
                            provincia: selectedProvincia.isEmpty ? nil : selectedProvincia,
                            nombre: nombre.isEmpty ? nil : nombre,
                            localidad: localidad.isEmpty ? nil : localidad
                        )
                        onApply(filtros)
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
            .onAppear {
                selectedTipo = filtros.tipo ?? ""
                selectedSuperficie = filtros.superficie ?? ""
                selectedProvincia = filtros.provincia ?? ""
                nombre = filtros.nombre ?? ""
                localidad = filtros.localidad ?? ""
            }
        }
        .accentColor(.blue)
    }
}
