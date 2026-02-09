import SwiftUI
import MapKit
import CoreLocation

// MARK: - Custom Map View

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
        mapView.showsCompass = false
        let compass = MKCompassButton(mapView: mapView)
        compass.compassVisibility = .adaptive
        compass.translatesAutoresizingMaskIntoConstraints = false
        mapView.addSubview(compass)

        let compassTopConstraint = compass.topAnchor.constraint(equalTo: mapView.safeAreaLayoutGuide.topAnchor, constant: 90)
        context.coordinator.mapViewContext.compassTopConstraint = compassTopConstraint

        NSLayoutConstraint.activate([
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

        if uiView.userTrackingMode != userTrackingMode {
            uiView.setUserTrackingMode(userTrackingMode, animated: true)
        }

        // Ajustar posición de la brújula según si hay navegación activa
        if let compassTopConstraint = context.coordinator.mapViewContext.compassTopConstraint {
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
        private var justRecalculated = false
        private var lastPolylineUpdateIndex = 0

        init(_ parent: CustomMapView) {
            self.parent = parent
            super.init()
            setupLocationManager()
        }

        private func setupLocationManager() {
            locationManager = CLLocationManager()
            locationManager?.delegate = self
            locationManager?.desiredAccuracy = kCLLocationAccuracyBestForNavigation
            locationManager?.distanceFilter = kCLDistanceFilterNone
            locationManager?.activityType = .automotiveNavigation
            locationManager?.allowsBackgroundLocationUpdates = true
            locationManager?.pausesLocationUpdatesAutomatically = false
            Logger.debug("📱 Location Manager configurado para navegación continua")
        }

        func setCurrentDestination(_ destination: MapAnnotationItem) {
            self.currentDestination = destination
            self.lastPolylineUpdateIndex = 0
            Logger.debug("🚀 Iniciando actualizaciones de ubicación continuas...")
            locationManager?.startUpdatingLocation()
            locationManager?.startUpdatingHeading()
        }

        func stopLocationUpdates() {
            Logger.debug("🛑 Deteniendo actualizaciones de ubicación")
            locationManager?.stopUpdatingLocation()
            locationManager?.stopUpdatingHeading()
        }

        func setCorrectStepAfterRecalculation(_ stepIndex: Int) {
            DispatchQueue.main.async {
                let previousStep = self.parent.currentStepIndex
                self.parent.currentStepIndex = stepIndex
                Logger.debug("   Paso actualizado después de recalcular: \(previousStep + 1) → \(stepIndex + 1)")
                self.justRecalculated = true
                Logger.debug("   Flag 'justRecalculated' activado para evitar avances inmediatos")
                self.lastPolylineUpdateIndex = 0
            }
        }

        // MARK: - CLLocationManagerDelegate
        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let location = locations.last else { return }
            Logger.debug("📍 [CLLocationManager] Ubicación actualizada: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            Logger.debug("   Precisión: \(location.horizontalAccuracy)m, Velocidad: \(location.speed)m/s")
            Logger.debug("   Estado navegación: \(parent.isNavigating ? "NAVEGANDO" : "NO navegando")")

            if parent.isNavigating {
                Logger.debug("✅ [CLLocationManager] Procesando ubicación durante navegación")
                Logger.debug("   Paso actual: \(parent.currentStepIndex + 1), Distancia actual: \(String(format: "%.0f", parent.distanceToNextStep))m")
                updateCurrentStep(userLocation: location.coordinate, source: "CLLocationManager")
                checkIfRecalculationNeeded(userLocation: location.coordinate)
            } else {
                Logger.debug("⚠️ [CLLocationManager] No navegando - actualización ignorada")
            }
        }

        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            Logger.debug("❌ Error en location manager: \(error.localizedDescription)")
        }

        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            guard let location = userLocation.location else { return }
            Logger.debug("🗺️ [MapView] Ubicación del punto azul actualizada: \(location.coordinate.latitude), \(location.coordinate.longitude)")

            if parent.isNavigating {
                Logger.debug("   [MapView] Navegando - procesamiento delegado a CLLocationManager")
            }
        }

        private func updateCurrentStep(userLocation: CLLocationCoordinate2D, source: String) {
            guard let currentRoute = parent.route, parent.currentStepIndex < currentRoute.steps.count else { return }

            let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
            var distanceToEndOfCurrentStep: CLLocationDistance = 0
            for i in 0...parent.currentStepIndex {
                distanceToEndOfCurrentStep += currentRoute.steps[i].distance
            }

            Logger.debug("📊 [\(source)] Paso \(parent.currentStepIndex + 1)/\(currentRoute.steps.count) - Distancia total hasta fin del paso: \(String(format: "%.0f", distanceToEndOfCurrentStep))m")

            let polyline = currentRoute.polyline
            let points = polyline.points()
            var accumulatedDistance: CLLocationDistance = 0
            var endOfStepCoordinate: CLLocationCoordinate2D?

            for i in 0..<polyline.pointCount - 1 {
                let point1 = points[i]
                let point2 = points[i + 1]
                let segmentDistance = point1.distance(to: point2)

                if accumulatedDistance + segmentDistance >= distanceToEndOfCurrentStep {
                    let remainingInSegment = distanceToEndOfCurrentStep - accumulatedDistance
                    let fraction = segmentDistance > 0 ? remainingInSegment / segmentDistance : 0

                    let lat = point1.coordinate.latitude + (point2.coordinate.latitude - point1.coordinate.latitude) * fraction
                    let lon = point1.coordinate.longitude + (point2.coordinate.longitude - point1.coordinate.longitude) * fraction
                    endOfStepCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    break
                }
                accumulatedDistance += segmentDistance
            }

            if endOfStepCoordinate == nil {
                endOfStepCoordinate = points[polyline.pointCount - 1].coordinate
            }

            guard let endCoord = endOfStepCoordinate else { return }
            let endLocation = CLLocation(latitude: endCoord.latitude, longitude: endCoord.longitude)
            let remainingDistance = userCLLocation.distance(from: endLocation)

            Logger.debug("📍 [\(source)] Distancia restante desde ubicación actual hasta fin del paso: \(String(format: "%.0f", remainingDistance))m")

            updatePolylineToRemoveTraveledPath(userLocation: userLocation, currentRoute: currentRoute)

            let previousDistance = parent.distanceToNextStep
            DispatchQueue.main.async {
                let newDistance = max(0, remainingDistance)

                if self.justRecalculated && newDistance > previousDistance {
                    Logger.debug("⏸️ [\(source)] Acabamos de recalcular - Ignorando aumento de distancia: \(String(format: "%.0f", previousDistance))m → \(String(format: "%.0f", newDistance))m")
                    self.justRecalculated = false
                } else {
                    self.parent.distanceToNextStep = newDistance
                    Logger.debug("✅ [\(source)] Distancia UI: \(String(format: "%.0f", previousDistance))m → \(String(format: "%.0f", newDistance))m")

                    if self.justRecalculated {
                        self.justRecalculated = false
                        Logger.debug("   Flag 'justRecalculated' reseteado (distancia bajó correctamente)")
                    }
                }
            }

            if remainingDistance < 15 && parent.currentStepIndex < currentRoute.steps.count - 1 && !justRecalculated {
                Logger.debug("➡️ [\(source)] Avanzando al paso \(parent.currentStepIndex + 2)/\(currentRoute.steps.count) (distancia < 15m)")
                DispatchQueue.main.async {
                    HapticFeedback.medium()

                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        self.parent.currentStepIndex += 1
                        if let userLocation = self.parent.mapView?.userLocation.location {
                            self.updateCurrentStep(userLocation: userLocation.coordinate, source: "\(source)-NextStep")
                        }
                    }
                }
            }
        }

        private func updatePolylineToRemoveTraveledPath(userLocation: CLLocationCoordinate2D, currentRoute: MKRoute) {
            guard let mapView = parent.mapView else { return }

            let polyline = currentRoute.polyline
            let points = polyline.points()
            let userPoint = MKMapPoint(userLocation)

            var closestIndex = 0
            var minDistance = Double.greatestFiniteMagnitude

            let step = max(1, polyline.pointCount / 200)
            for i in stride(from: 0, to: polyline.pointCount, by: step) {
                let distance = points[i].distance(to: userPoint)
                if distance < minDistance {
                    minDistance = distance
                    closestIndex = i
                }
            }

            let searchRange = max(0, closestIndex - step)..<min(polyline.pointCount, closestIndex + step)
            for i in searchRange {
                let distance = points[i].distance(to: userPoint)
                if distance < minDistance {
                    minDistance = distance
                    closestIndex = i
                }
            }

            if closestIndex < lastPolylineUpdateIndex {
                closestIndex = lastPolylineUpdateIndex
            }

            let pointsAdvanced = closestIndex - lastPolylineUpdateIndex

            let shouldUpdate: Bool
            if pointsAdvanced > 0 && closestIndex < polyline.pointCount - 1 {
                let lastPoint = points[lastPolylineUpdateIndex]
                let currentPoint = points[closestIndex]
                let distanceInMeters = lastPoint.distance(to: currentPoint)
                shouldUpdate = pointsAdvanced >= 8 || distanceInMeters >= 20
            } else {
                shouldUpdate = false
            }

            if shouldUpdate {
                let remainingPoints = UnsafeMutablePointer<MKMapPoint>.allocate(capacity: polyline.pointCount - closestIndex)
                for i in closestIndex..<polyline.pointCount {
                    remainingPoints[i - closestIndex] = points[i]
                }

                let newPolyline = MKPolyline(points: remainingPoints, count: polyline.pointCount - closestIndex)
                remainingPoints.deallocate()

                DispatchQueue.main.async {
                    mapView.addOverlay(newPolyline)
                    let overlaysToRemove = mapView.overlays.filter { overlay in
                        overlay is MKPolyline && overlay !== newPolyline
                    }
                    mapView.removeOverlays(overlaysToRemove)
                    Logger.debug("🗑️ Polyline actualizada - Puntos eliminados: \(pointsAdvanced), Puntos restantes: \(polyline.pointCount - closestIndex)")
                }

                lastPolylineUpdateIndex = closestIndex
            }
        }

        private func checkIfRecalculationNeeded(userLocation: CLLocationCoordinate2D) {
            guard parent.isNavigating, let currentRoute = parent.route, let destination = currentDestination else {
                return
            }

            let userPoint = MKMapPoint(userLocation)
            var minDistance = Double.greatestFiniteMagnitude
            let points = currentRoute.polyline.points()

            let step = max(1, currentRoute.polyline.pointCount / 100)
            for i in stride(from: 0, to: currentRoute.polyline.pointCount, by: step) {
                let distance = points[i].distance(to: userPoint)
                if distance < minDistance { minDistance = distance }
            }

            Logger.debug("📏 [RecalculoCheck] Distancia a la ruta: \(String(format: "%.0f", minDistance))m")

            if minDistance > 50 {
                Logger.debug("🔄 [RecalculoCheck] INICIANDO RECÁLCULO - Desviación de \(String(format: "%.0f", minDistance))m")
                Logger.debug("   Paso actual antes de recalcular: \(parent.currentStepIndex + 1), Distancia actual: \(String(format: "%.0f", parent.distanceToNextStep))m")
                lastRecalculationDate = Date()

                HapticFeedback.light()

                DispatchQueue.main.async {
                    self.parent.onShowSummary(destination)
                }
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }

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

            campoAnno.title = nil
            campoAnno.subtitle = nil

            let calloutContainer = UIView()
            calloutContainer.translatesAutoresizingMaskIntoConstraints = false
            calloutContainer.layer.cornerRadius = 20
            calloutContainer.layer.cornerCurve = .continuous
            calloutContainer.clipsToBounds = true

            let blurEffect = UIBlurEffect(style: .systemUltraThinMaterial)
            let blurView = UIVisualEffectView(effect: blurEffect)
            blurView.translatesAutoresizingMaskIntoConstraints = false
            blurView.layer.cornerRadius = 20
            blurView.layer.cornerCurve = .continuous
            blurView.clipsToBounds = true
            calloutContainer.addSubview(blurView)

            let mainStack = UIStackView()
            mainStack.axis = .vertical
            mainStack.spacing = 12
            mainStack.alignment = .fill
            mainStack.distribution = .fill
            mainStack.translatesAutoresizingMaskIntoConstraints = false

            let titleLabel = UILabel()
            titleLabel.text = campoAnno.annotationItem.title ?? "Campo sin nombre"
            titleLabel.font = .systemFont(ofSize: 16, weight: .bold)
            titleLabel.textColor = .label
            titleLabel.textAlignment = .center
            titleLabel.numberOfLines = 2

            let buttonsStack = UIStackView()
            buttonsStack.axis = .horizontal
            buttonsStack.spacing = 10
            buttonsStack.alignment = .fill
            buttonsStack.distribution = .fillEqually
            buttonsStack.translatesAutoresizingMaskIntoConstraints = false

            let detailBtn = createCalloutButton(
                icon: "info.circle.fill",
                color: .systemBlue,
                tag: 1
            )

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

            calloutContainer.layer.borderWidth = 1
            calloutContainer.layer.borderColor = UIColor.separator.withAlphaComponent(0.2).cgColor

            calloutContainer.layer.shadowColor = UIColor.black.cgColor
            calloutContainer.layer.shadowOpacity = 0.12
            calloutContainer.layer.shadowOffset = CGSize(width: 0, height: 8)
            calloutContainer.layer.shadowRadius = 16

            NSLayoutConstraint.activate([
                blurView.topAnchor.constraint(equalTo: calloutContainer.topAnchor),
                blurView.leadingAnchor.constraint(equalTo: calloutContainer.leadingAnchor),
                blurView.trailingAnchor.constraint(equalTo: calloutContainer.trailingAnchor),
                blurView.bottomAnchor.constraint(equalTo: calloutContainer.bottomAnchor),

                mainStack.topAnchor.constraint(equalTo: calloutContainer.topAnchor, constant: 14),
                mainStack.leadingAnchor.constraint(equalTo: calloutContainer.leadingAnchor, constant: 14),
                mainStack.trailingAnchor.constraint(equalTo: calloutContainer.trailingAnchor, constant: -14),
                mainStack.bottomAnchor.constraint(equalTo: calloutContainer.bottomAnchor, constant: -14),

                buttonsStack.heightAnchor.constraint(equalToConstant: 44),
                calloutContainer.widthAnchor.constraint(equalToConstant: 250)
            ])

            view?.detailCalloutAccessoryView = calloutContainer

            return view
        }

        private func createCalloutButton(icon: String, color: UIColor, tag: Int) -> UIButton {
            let button = UIButton(type: .system)
            button.translatesAutoresizingMaskIntoConstraints = false

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

            button.layer.shadowColor = color.cgColor
            button.layer.shadowOpacity = 0.3
            button.layer.shadowOffset = CGSize(width: 0, height: 4)
            button.layer.shadowRadius = 8

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

        func mapView(_ mapView: MKMapView, didChange mode: MKUserTrackingMode, animated: Bool) {
            if parent.userTrackingMode != mode {
                Logger.debug("📍 Usuario arrastró el mapa - Reseteando botón de ubicación")
                DispatchQueue.main.async {
                    self.parent.userTrackingMode = mode
                }
            }
        }
    }
}
