import SwiftUI

/// Vista de la sección de detalles del campo
struct CampoDetailsSection: View {
    let campo: CampoModel
    let contribucionAprobada: ContribucionAprobada?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
                Text("Detalles")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }

            VStack(alignment: .leading, spacing: 10) {
                DetailRow(label: "Superficie:", value: campo.superficie)
                DetailRow(label: "Tipo de campo:", value: campo.tipo)

                if let contribucion = contribucionAprobada {
                    OptionalDetailRow(label: "Tiene cantina:", value: contribucion.tiene_cantina.map { $0 ? "Sí" : "No" })
                    OptionalDetailRow(label: "Aforo de la grada:", value: contribucion.aforo_grada.map { "\($0)" })
                    OptionalDetailRow(label: "Medidas del campo:", value: contribucion.medidas_campo)
                    OptionalDetailRow(label: "Tipo de iluminación:", value: contribucion.tipo_iluminacion)
                    OptionalDetailRow(label: "Estado del césped:", value: contribucion.estado_cesped)
                    OptionalDetailRow(label: "Accesibilidad:", value: contribucion.accesibilidad)
                    OptionalDetailRow(label: "Notas adicionales:", value: contribucion.notas)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }
}

/// Helper para mostrar una fila opcional
struct OptionalDetailRow: View {
    let label: String
    let value: String?

    var body: some View {
        if let value = value {
            DetailRow(label: label, value: value)
        }
    }
}
