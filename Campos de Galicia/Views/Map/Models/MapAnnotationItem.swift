import SwiftUI
import MapKit
import CoreLocation

// MARK: - Map Annotation Models

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
