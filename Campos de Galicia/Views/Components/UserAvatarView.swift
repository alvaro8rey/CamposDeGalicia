import SwiftUI

/// Vista reutilizable para mostrar el avatar del usuario
/// Muestra la foto de perfil si existe, o la inicial del nombre si no
struct UserAvatarView: View {
    let avatarURL: String?
    let userName: String
    let size: CGFloat

    init(avatarURL: String?, userName: String, size: CGFloat = 40) {
        self.avatarURL = avatarURL
        self.userName = userName
        self.size = size
    }

    var body: some View {
        Group {
            if let avatarURL = avatarURL, let url = URL(string: avatarURL) {
                // Mostrar foto de perfil
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                } placeholder: {
                    // Mientras carga, mostrar inicial
                    initialView
                }
            } else {
                // Sin foto, mostrar inicial
                initialView
            }
        }
    }

    private var initialView: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.blue.opacity(0.3), .purple.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            Text(userName.prefix(1).uppercased())
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundColor(.blue)
        }
    }
}

// MARK: - Preview
struct UserAvatarView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Con foto de perfil
            UserAvatarView(
                avatarURL: "https://via.placeholder.com/150",
                userName: "Juan",
                size: 40
            )

            // Sin foto (inicial)
            UserAvatarView(
                avatarURL: nil,
                userName: "María",
                size: 40
            )

            // Diferentes tamaños
            HStack(spacing: 10) {
                UserAvatarView(avatarURL: nil, userName: "A", size: 30)
                UserAvatarView(avatarURL: nil, userName: "B", size: 40)
                UserAvatarView(avatarURL: nil, userName: "C", size: 60)
                UserAvatarView(avatarURL: nil, userName: "D", size: 80)
            }
        }
        .padding()
    }
}
