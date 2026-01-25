import Foundation
import SwiftUI

/// Idiomas soportados
enum Language: String, CaseIterable {
    case spanish = "es"
    case galician = "gl"

    var displayName: String {
        switch self {
        case .spanish: return "Español"
        case .galician: return "Galego"
        }
    }

    var flag: String {
        switch self {
        case .spanish: return "🇪🇸"
        case .galician: return "🏴"
        }
    }
}

/// Keys de localización
enum LocalizedKey: String {
    // MARK: - General
    case appName = "app.name"
    case cancel = "general.cancel"
    case save = "general.save"
    case ok = "general.ok"
    case send = "general.send"
    case next = "general.next"
    case skip = "general.skip"
    case start = "general.start"
    case loading = "general.loading"
    case error = "general.error"
    case success = "general.success"

    // MARK: - Onboarding
    case onboardingWelcomeTitle = "onboarding.welcome.title"
    case onboardingWelcomeMessage = "onboarding.welcome.message"
    case onboardingMissionsTitle = "onboarding.missions.title"
    case onboardingMissionsBullet1 = "onboarding.missions.bullet1"
    case onboardingMissionsBullet2 = "onboarding.missions.bullet2"
    case onboardingMissionsBullet3 = "onboarding.missions.bullet3"
    case onboardingAutoCheckinTitle = "onboarding.autocheckin.title"
    case onboardingAutoCheckinMessage = "onboarding.autocheckin.message"
    case onboardingAutoCheckinBullet1 = "onboarding.autocheckin.bullet1"
    case onboardingAutoCheckinBullet2 = "onboarding.autocheckin.bullet2"
    case onboardingAutoCheckinBullet3 = "onboarding.autocheckin.bullet3"
    case onboardingAutoCheckinBullet4 = "onboarding.autocheckin.bullet4"
    case onboardingNotificationsTitle = "onboarding.notifications.title"
    case onboardingNotificationsMessage = "onboarding.notifications.message"
    case onboardingNotificationsButton = "onboarding.notifications.button"
    case onboardingLocationTitle = "onboarding.location.title"
    case onboardingLocationMessage = "onboarding.location.message"
    case onboardingLocationButton = "onboarding.location.button"
    case onboardingPermissionsGranted = "onboarding.permissions.granted"
    case onboardingPermissionsDenied = "onboarding.permissions.denied"
    case onboardingPermissionsNotDetermined = "onboarding.permissions.notdetermined"
    case onboardingPermissionsUnknown = "onboarding.permissions.unknown"
    case onboardingLocationServicesDisabled = "onboarding.location.services.disabled"
    case onboardingOpenSettings = "onboarding.open.settings"

    // MARK: - Auth
    case loginTitle = "auth.login.title"
    case loginSubtitle = "auth.login.subtitle"
    case loginEmail = "auth.login.email"
    case loginPassword = "auth.login.password"
    case loginButton = "auth.login.button"
    case loginLoading = "auth.login.loading"
    case loginForgotPassword = "auth.login.forgot"
    case loginNoAccount = "auth.login.noaccount"
    case loginCreateAccount = "auth.login.create"
    case loginError = "auth.login.error"

    case registerTitle = "auth.register.title"
    case registerSubtitle = "auth.register.subtitle"
    case registerName = "auth.register.name"
    case registerSurname = "auth.register.surname"
    case registerProfilePhoto = "auth.register.photo"
    case registerSelectPhoto = "auth.register.selectphoto"
    case registerChangePhoto = "auth.register.changephoto"
    case registerButton = "auth.register.button"
    case registerLoading = "auth.register.loading"

    // MARK: - Campo Detail
    case campoLoading = "campo.loading"
    case campoNoCoordinates = "campo.no.coordinates"
    case campoLocationDenied = "campo.location.denied"
    case campoLocationNeeded = "campo.location.needed"
    case campoLocationError = "campo.location.error"
    case campoGPSWeak = "campo.gps.weak"
    case campoTooFar = "campo.too.far"
    case campoVisitSuccess = "campo.visit.success"
    case campoVisitSuccessTitle = "campo.visit.success.title"
    case campoVisitError = "campo.visit.error"
    case campoUnvisitSuccess = "campo.unvisit.success"
    case campoUnvisitError = "campo.unvisit.error"

    // MARK: - Logros
    case logrosTitle = "logros.title"
    case logrosPending = "logros.pending"
    case logrosCompleted = "logros.completed"
    case logrosLoading = "logros.loading"
    case logrosAllCompleted = "logros.all.completed"
    case logrosAllCompletedMessage = "logros.all.completed.message"
    case logrosNone = "logros.none"
    case logrosNoneMessage = "logros.none.message"
    case logrosProgressTitle = "logros.progress.title"
    case logrosProgressCampos = "logros.progress.campos"
    case logrosProgressProvincias = "logros.progress.provincias"
    case logrosProgressRacha = "logros.progress.racha"
    case logrosProgressReviews = "logros.progress.reviews"
    case logrosCamposVisitados = "logros.campos.visitados"
    case logrosRachasDiarias = "logros.rachas.diarias"
    case logrosReseñas = "logros.reseñas"
    case logrosOtros = "logros.otros"

    // MARK: - Daily Reward
    case dailyRewardTitle = "daily.reward.title"
    case dailyRewardClaimed = "daily.reward.claimed"
    case dailyRewardClaim = "daily.reward.claim"
    case dailyRewardDay = "daily.reward.day"
    case dailyRewardStreak = "daily.reward.streak"
    case dailyRewardProcessing = "daily.reward.processing"
    case dailyRewardNotificationTitle = "daily.reward.notification.title"
    case dailyRewardNotificationBody = "daily.reward.notification.body"

    // MARK: - Notifications
    case notifDisabledTitle = "notif.disabled.title"
    case notifDisabledMessage = "notif.disabled.message"
    case notifGoToSettings = "notif.go.settings"
    case notifAutoCheckinTitle = "notif.autocheckin.title"
    case notifAutoCheckinBody = "notif.autocheckin.body"
    case notifAutoCheckinErrorTitle = "notif.autocheckin.error.title"
    case notifAutoCheckinErrorBody = "notif.autocheckin.error.body"

    // MARK: - Reviews
    case reviewAdd = "review.add"
    case reviewEdit = "review.edit"
    case reviewYourRating = "review.your.rating"
    case reviewYourOpinion = "review.your.opinion"
    case reviewPlaceholder = "review.placeholder"
    case reviewGuidelines = "review.guidelines"
    case reviewPhotosOptional = "review.photos.optional"
    case reviewPhotosHelp = "review.photos.help"
    case reviewAnonymous = "review.anonymous"
    case reviewAnonymousHelp = "review.anonymous.help"
    case reviewPublish = "review.publish"
    case reviewPublishing = "review.publishing"
    case reviewUpdating = "review.updating"
    case reviewPublished = "review.published"
    case reviewUpdated = "review.updated"
    case reviewRatingVeryBad = "review.rating.verybad"
    case reviewRatingBad = "review.rating.bad"
    case reviewRatingRegular = "review.rating.regular"
    case reviewRatingGood = "review.rating.good"
    case reviewRatingExcellent = "review.rating.excellent"

    // MARK: - Contribuciones
    case contribucionTitle = "contribucion.title"
    case contribucionHelp = "contribucion.help"
    case contribucionAddPhotos = "contribucion.add.photos"
    case contribucionCantina = "contribucion.cantina"
    case contribucionAforo = "contribucion.aforo"
    case contribucionMedidas = "contribucion.medidas"
    case contribucionIluminacion = "contribucion.iluminacion"
    case contribucionIluminacionNatural = "contribucion.iluminacion.natural"
    case contribucionIluminacionArtificial = "contribucion.iluminacion.artificial"
    case contribucionCesped = "contribucion.cesped"
    case contribucionCespedBueno = "contribucion.cesped.bueno"
    case contribucionCespedRegular = "contribucion.cesped.regular"
    case contribucionCespedMalo = "contribucion.cesped.malo"
    case contribucionAccesibilidad = "contribucion.accesibilidad"
    case contribucionAccesibilidadSi = "contribucion.accesibilidad.si"
    case contribucionAccesibilidadNo = "contribucion.accesibilidad.no"
    case contribucionSuccess = "contribucion.success"
    case contribucionError = "contribucion.error"
    case contribucionSelect = "contribucion.select"

    // MARK: - Toast Messages
    case toastVisited = "toast.visited"
    case toastUnvisited = "toast.unvisited"
    case toastXPGained = "toast.xp.gained"
    case toastLevelUp = "toast.levelup"
    case toastAchievement = "toast.achievement"

    // MARK: - Profile
    case profileLanguage = "profile.language"
    case profileLanguageTitle = "profile.language.title"
    case profileLanguageMessage = "profile.language.message"

    // MARK: - Empty States
    case emptyNoData = "empty.nodata"

    // MARK: - Loading Messages
    case loadingCampos = "loading.campos"
    case loadingCampoInfo = "loading.campo.info"
    case loadingLogros = "loading.logros"
    case loadingLocation = "loading.location"
}

/// Manager de localización centralizado
@MainActor
class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published var currentLanguage: Language {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "app_language")
            objectWillChange.send()
        }
    }

    private init() {
        let savedLang = UserDefaults.standard.string(forKey: "app_language") ?? Language.spanish.rawValue
        self.currentLanguage = Language(rawValue: savedLang) ?? .spanish
    }

    /// Obtiene la traducción para una key
    nonisolated func localized(_ key: LocalizedKey, _ args: CVarArg...) -> String {
        // Leer idioma actual desde UserDefaults (thread-safe)
        let savedLang = UserDefaults.standard.string(forKey: "app_language") ?? Language.spanish.rawValue
        let currentLang = Language(rawValue: savedLang) ?? .spanish

        let format = translations[currentLang]?[key] ?? key.rawValue
        if args.isEmpty {
            return format
        }
        return String(format: format, arguments: args)
    }

    /// Diccionario de traducciones
    let translations: [Language: [LocalizedKey: String]] = [
        // MARK: - Español
        .spanish: [
            // General
            .appName: "Campos de Galicia",
            .cancel: "Cancelar",
            .save: "Guardar",
            .ok: "OK",
            .send: "Enviar",
            .next: "Siguiente",
            .skip: "Saltar",
            .start: "Empezar",
            .loading: "Cargando...",
            .error: "Error",
            .success: "Éxito",

            // Onboarding
            .onboardingWelcomeTitle: "¡Bienvenido a Campos de Galicia!",
            .onboardingWelcomeMessage: "Descubre los campos de fútbol de toda Galicia. Visita, explora y colecciona ubicaciones reales mientras ganas XP.",
            .onboardingMissionsTitle: "Misiones y XP",
            .onboardingMissionsBullet1: "Marca campos como visitados cuando estés cerca del campo (500m).",
            .onboardingMissionsBullet2: "Completa misiones visitando campos y manteniendo rachas diarias.",
            .onboardingMissionsBullet3: "Gana XP y sube de nivel. ¡Explora Galicia y progresa!",
            .onboardingAutoCheckinTitle: "Auto Check-in",
            .onboardingAutoCheckinMessage: "El auto check-in registra tu visita automáticamente cuando estés cerca de un campo (500m) y permanezcas allí 2 minutos.",
            .onboardingAutoCheckinBullet1: "Funciona en segundo plano con muy bajo consumo de batería.",
            .onboardingAutoCheckinBullet2: "No rastrea tu ubicación constantemente.",
            .onboardingAutoCheckinBullet3: "Requiere permanencia de 2 minutos en el área.",
            .onboardingAutoCheckinBullet4: "Solo se registra una vez por campo.",
            .onboardingNotificationsTitle: "Notificaciones",
            .onboardingNotificationsMessage: "Te avisaremos cuando tu recompensa diaria esté lista y cuando visites un campo automáticamente.",
            .onboardingNotificationsButton: "Permitir Notificaciones",
            .onboardingLocationTitle: "Permitir ubicación",
            .onboardingLocationMessage: "Necesitamos tu ubicación solo para verificar que visitas los campos de verdad y registrar tus logros.",
            .onboardingLocationButton: "Permitir Ubicación",
            .onboardingPermissionsGranted: "Permisos otorgados",
            .onboardingPermissionsDenied: "Permisos denegados",
            .onboardingPermissionsNotDetermined: "Permiso no determinado",
            .onboardingPermissionsUnknown: "Estado desconocido",
            .onboardingLocationServicesDisabled: "Servicios de localización desactivados",
            .onboardingOpenSettings: "Abrir Ajustes",

            // Auth
            .loginTitle: "Campos de Galicia",
            .loginSubtitle: "Descubre los campos de fútbol de Galicia",
            .loginEmail: "Correo Electrónico",
            .loginPassword: "Contraseña",
            .loginButton: "Iniciar Sesión",
            .loginLoading: "Iniciando sesión...",
            .loginForgotPassword: "¿Olvidaste tu contraseña?",
            .loginNoAccount: "¿No tienes cuenta?",
            .loginCreateAccount: "Crear cuenta",
            .loginError: "Error al iniciar sesión: %@",

            .registerTitle: "Crear Cuenta",
            .registerSubtitle: "Únete a la comunidad de Campos de Galicia",
            .registerName: "Nombre",
            .registerSurname: "Apellidos",
            .registerProfilePhoto: "Foto de perfil (opcional)",
            .registerSelectPhoto: "Seleccionar foto",
            .registerChangePhoto: "Cambiar foto",
            .registerButton: "Crear cuenta",
            .registerLoading: "Creando cuenta...",

            // Campo Detail
            .campoLoading: "Cargando información del campo...",
            .campoNoCoordinates: "Este campo aún no tiene coordenadas. Ayúdanos a añadirlas",
            .campoLocationDenied: "Activa la ubicación en: Ajustes → Privacidad y Seguridad → Ubicación → Campos de Galicia",
            .campoLocationNeeded: "Necesitamos permiso para acceder a tu ubicación",
            .campoLocationError: "No pudimos obtener tu ubicación. Asegúrate de estar en un lugar con buena señal GPS",
            .campoGPSWeak: "La señal GPS es débil (%dm de precisión). Sal al exterior para mejor precisión",
            .campoTooFar: "Estás a ~%@ del campo. Acércate más (necesitas estar a %@ o menos)",
            .campoVisitSuccess: "Has visitado %@",
            .campoVisitSuccessTitle: "✅ ¡Éxito!",
            .campoVisitError: "Error al registrar visita",
            .campoUnvisitSuccess: "Visita desmarcada",
            .campoUnvisitError: "Error al desmarcar visita",

            // Logros
            .logrosTitle: "Logros y Recompensas",
            .logrosPending: "Pendientes",
            .logrosCompleted: "Completados",
            .logrosLoading: "Cargando logros...",
            .logrosAllCompleted: "¡Enhorabuena!",
            .logrosAllCompletedMessage: "Has completado todos los logros. ¡Eres un auténtico explorador de Galicia!",
            .logrosNone: "Aún no tienes logros",
            .logrosNoneMessage: "Visita campos, escribe reseñas y mantén rachas para desbloquear logros",
            .logrosProgressTitle: "Tu Progreso",
            .logrosProgressCampos: "Campos",
            .logrosProgressProvincias: "Provincias",
            .logrosProgressRacha: "Racha",
            .logrosProgressReviews: "Reseñas",
            .logrosCamposVisitados: "Campos visitados",
            .logrosRachasDiarias: "Rachas diarias",
            .logrosReseñas: "Reseñas",
            .logrosOtros: "Otros",

            // Daily Reward
            .dailyRewardTitle: "Recompensa Diaria",
            .dailyRewardClaimed: "¡Ya reclamaste hoy!",
            .dailyRewardClaim: "Reclamar +%d XP",
            .dailyRewardDay: "Día %d",
            .dailyRewardStreak: "racha",
            .dailyRewardProcessing: "Procesando...",
            .dailyRewardNotificationTitle: "Campos de Galicia",
            .dailyRewardNotificationBody: "¡Tu recompensa diaria te espera! Reclámala ahora en la sección de Logros 🎁",

            // Notifications
            .notifDisabledTitle: "Notificaciones desactivadas",
            .notifDisabledMessage: "Activa las notificaciones para recibir avisos cuando tu recompensa diaria esté lista y no perderte ningún día.",
            .notifGoToSettings: "Ir a Ajustes",
            .notifAutoCheckinTitle: "¡Campo visitado!",
            .notifAutoCheckinBody: "Has visitado %@. ¡Un campo más para tu colección! ⚽",
            .notifAutoCheckinErrorTitle: "No se pudo registrar la visita",
            .notifAutoCheckinErrorBody: "No pudimos registrar tu visita a %@. Revisa tu conexión e inténtalo de nuevo.",

            // Reviews
            .reviewAdd: "Nueva Reseña",
            .reviewEdit: "Editar Reseña",
            .reviewYourRating: "Tu valoración",
            .reviewYourOpinion: "Tu opinión",
            .reviewPlaceholder: "Cuéntanos tu experiencia en este campo...",
            .reviewGuidelines: "Sé respetuoso y describe tu experiencia de forma honesta.",
            .reviewPhotosOptional: "Fotos (opcional)",
            .reviewPhotosHelp: "Sube fotos del campo para ayudar a otros visitantes (máximo %d).",
            .reviewAnonymous: "Reseña anónima",
            .reviewAnonymousHelp: "Si activas esta opción, tu nombre no será visible en la reseña.",
            .reviewPublish: "Publicar",
            .reviewPublishing: "Publicando reseña...",
            .reviewUpdating: "Actualizando reseña...",
            .reviewPublished: "¡Reseña publicada!",
            .reviewUpdated: "¡Reseña actualizada!",
            .reviewRatingVeryBad: "😞 Muy malo",
            .reviewRatingBad: "😕 Malo",
            .reviewRatingRegular: "😐 Regular",
            .reviewRatingGood: "😊 Bueno",
            .reviewRatingExcellent: "🤩 Excelente",

            // Contribuciones
            .contribucionTitle: "Aportar información",
            .contribucionHelp: "Ayuda a completar los datos de %@",
            .contribucionAddPhotos: "Añadir fotos",
            .contribucionCantina: "¿Tiene cantina?",
            .contribucionAforo: "Aforo de la grada (número)",
            .contribucionMedidas: "Medidas del campo (ej. 105x68 metros)",
            .contribucionIluminacion: "Tipo de iluminación",
            .contribucionIluminacionNatural: "Natural",
            .contribucionIluminacionArtificial: "Artificial",
            .contribucionCesped: "Estado del césped",
            .contribucionCespedBueno: "Bueno",
            .contribucionCespedRegular: "Regular",
            .contribucionCespedMalo: "Malo",
            .contribucionAccesibilidad: "Accesibilidad",
            .contribucionAccesibilidadSi: "Sí, tiene acceso para discapacitados",
            .contribucionAccesibilidadNo: "No, no tiene acceso",
            .contribucionSuccess: "✅ Contribución enviada. ¡Gracias!",
            .contribucionError: "Error al enviar contribución",
            .contribucionSelect: "Seleccionar",

            // Toast
            .toastVisited: "✅ ¡Visitado! %@",
            .toastUnvisited: "Visita desmarcada",
            .toastXPGained: "+%d XP - %@",
            .toastLevelUp: "⬆️ ¡Nivel %d alcanzado!",
            .toastAchievement: "🏆 ¡Nuevo logro! %@",

            // Profile
            .profileLanguage: "Idioma",
            .profileLanguageTitle: "Seleccionar idioma",
            .profileLanguageMessage: "Escoge el idioma de la aplicación",

            // Empty States
            .emptyNoData: "No hay datos disponibles",

            // Loading
            .loadingCampos: "Cargando campos de Galicia...",
            .loadingCampoInfo: "Cargando información del campo...",
            .loadingLogros: "Cargando logros...",
            .loadingLocation: "Obteniendo tu ubicación...",
        ],

        // MARK: - Galego
        .galician: [
            // General
            .appName: "Campos de Galicia",
            .cancel: "Cancelar",
            .save: "Gardar",
            .ok: "OK",
            .send: "Enviar",
            .next: "Seguinte",
            .skip: "Saltar",
            .start: "Comezar",
            .loading: "Cargando...",
            .error: "Erro",
            .success: "Éxito",

            // Onboarding
            .onboardingWelcomeTitle: "Benvido a Campos de Galicia!",
            .onboardingWelcomeMessage: "Descobre os campos de fútbol de toda Galicia. Visita, explora e colecciona ubicacións reais mentres gañas XP.",
            .onboardingMissionsTitle: "Misións e XP",
            .onboardingMissionsBullet1: "Marca campos como visitados cando esteas preto do campo (500m).",
            .onboardingMissionsBullet2: "Completa misións visitando campos e mantendo rachas diarias.",
            .onboardingMissionsBullet3: "Gaña XP e sube de nivel. Explora Galicia e progresa!",
            .onboardingAutoCheckinTitle: "Auto Check-in",
            .onboardingAutoCheckinMessage: "O auto check-in rexistra a túa visita automaticamente cando esteas preto dun campo (500m) e permanezcas alí 2 minutos.",
            .onboardingAutoCheckinBullet1: "Funciona en segundo plano con moi baixo consumo de batería.",
            .onboardingAutoCheckinBullet2: "Non rastrexa a túa ubicación constantemente.",
            .onboardingAutoCheckinBullet3: "Require permanencia de 2 minutos na área.",
            .onboardingAutoCheckinBullet4: "Só se rexistra unha vez por campo.",
            .onboardingNotificationsTitle: "Notificacións",
            .onboardingNotificationsMessage: "Avisarémosche cando a túa recompensa diaria estea lista e cando visites un campo automaticamente.",
            .onboardingNotificationsButton: "Permitir Notificacións",
            .onboardingLocationTitle: "Permitir ubicación",
            .onboardingLocationMessage: "Necesitamos a túa ubicación só para verificar que visitas os campos de verdade e rexistrar os teus logros.",
            .onboardingLocationButton: "Permitir Ubicación",
            .onboardingPermissionsGranted: "Permisos outorgados",
            .onboardingPermissionsDenied: "Permisos denegados",
            .onboardingPermissionsNotDetermined: "Permiso non determinado",
            .onboardingPermissionsUnknown: "Estado descoñecido",
            .onboardingLocationServicesDisabled: "Servizos de localización desactivados",
            .onboardingOpenSettings: "Abrir Axustes",

            // Auth
            .loginTitle: "Campos de Galicia",
            .loginSubtitle: "Descobre os campos de fútbol de Galicia",
            .loginEmail: "Correo Electrónico",
            .loginPassword: "Contrasinal",
            .loginButton: "Iniciar Sesión",
            .loginLoading: "Iniciando sesión...",
            .loginForgotPassword: "Esqueciches o contrasinal?",
            .loginNoAccount: "Non tes conta?",
            .loginCreateAccount: "Crear conta",
            .loginError: "Erro ao iniciar sesión: %@",

            .registerTitle: "Crear Conta",
            .registerSubtitle: "Únete á comunidade de Campos de Galicia",
            .registerName: "Nome",
            .registerSurname: "Apelidos",
            .registerProfilePhoto: "Foto de perfil (opcional)",
            .registerSelectPhoto: "Seleccionar foto",
            .registerChangePhoto: "Cambiar foto",
            .registerButton: "Crear conta",
            .registerLoading: "Creando conta...",

            // Campo Detail
            .campoLoading: "Cargando información do campo...",
            .campoNoCoordinates: "Este campo aínda non ten coordenadas. Axúdanos a engadilas",
            .campoLocationDenied: "Activa a ubicación en: Axustes → Privacidade e Seguridade → Ubicación → Campos de Galicia",
            .campoLocationNeeded: "Necesitamos permiso para acceder á túa ubicación",
            .campoLocationError: "Non puidemos obter a túa ubicación. Asegúrate de estar nun lugar con boa señal GPS",
            .campoGPSWeak: "A señal GPS é débil (%dm de precisión). Sae ao exterior para mellor precisión",
            .campoTooFar: "Estás a ~%@ do campo. Achégate máis (necesitas estar a %@ ou menos)",
            .campoVisitSuccess: "Visitaches %@",
            .campoVisitSuccessTitle: "✅ Éxito!",
            .campoVisitError: "Erro ao rexistrar visita",
            .campoUnvisitSuccess: "Visita desmarcada",
            .campoUnvisitError: "Erro ao desmarcar visita",

            // Logros
            .logrosTitle: "Logros e Recompensas",
            .logrosPending: "Pendentes",
            .logrosCompleted: "Completados",
            .logrosLoading: "Cargando logros...",
            .logrosAllCompleted: "Parabéns!",
            .logrosAllCompletedMessage: "Completaches todos os logros. Es un auténtico explorador de Galicia!",
            .logrosNone: "Aínda non tes logros",
            .logrosNoneMessage: "Visita campos, escribe recensións e mantén rachas para desbloquear logros",
            .logrosProgressTitle: "O teu Progreso",
            .logrosProgressCampos: "Campos",
            .logrosProgressProvincias: "Provincias",
            .logrosProgressRacha: "Racha",
            .logrosProgressReviews: "Recensións",
            .logrosCamposVisitados: "Campos visitados",
            .logrosRachasDiarias: "Rachas diarias",
            .logrosReseñas: "Recensións",
            .logrosOtros: "Outros",

            // Daily Reward
            .dailyRewardTitle: "Recompensa Diaria",
            .dailyRewardClaimed: "Xa reclamaches hoxe!",
            .dailyRewardClaim: "Reclamar +%d XP",
            .dailyRewardDay: "Día %d",
            .dailyRewardStreak: "racha",
            .dailyRewardProcessing: "Procesando...",
            .dailyRewardNotificationTitle: "Campos de Galicia",
            .dailyRewardNotificationBody: "A túa recompensa diaria espérate! Recláma agora na sección de Logros 🎁",

            // Notifications
            .notifDisabledTitle: "Notificacións desactivadas",
            .notifDisabledMessage: "Activa as notificacións para recibir avisos cando a túa recompensa diaria estea lista e non perderes ningún día.",
            .notifGoToSettings: "Ir a Axustes",
            .notifAutoCheckinTitle: "Campo visitado!",
            .notifAutoCheckinBody: "Visitaches %@. Un campo máis para a túa colección! ⚽",
            .notifAutoCheckinErrorTitle: "Non se puido rexistrar a visita",
            .notifAutoCheckinErrorBody: "Non puidemos rexistrar a túa visita a %@. Revisa a túa conexión e inténtao de novo.",

            // Reviews
            .reviewAdd: "Nova Recensión",
            .reviewEdit: "Editar Recensión",
            .reviewYourRating: "A túa valoración",
            .reviewYourOpinion: "A túa opinión",
            .reviewPlaceholder: "Cóntanos a túa experiencia neste campo...",
            .reviewGuidelines: "Sé respectuoso e describe a túa experiencia de forma honesta.",
            .reviewPhotosOptional: "Fotos (opcional)",
            .reviewPhotosHelp: "Sube fotos do campo para axudar a outros visitantes (máximo %d).",
            .reviewAnonymous: "Recensión anónima",
            .reviewAnonymousHelp: "Se activas esta opción, o teu nome non será visible na recensión.",
            .reviewPublish: "Publicar",
            .reviewPublishing: "Publicando recensión...",
            .reviewUpdating: "Actualizando recensión...",
            .reviewPublished: "Recensión publicada!",
            .reviewUpdated: "Recensión actualizada!",
            .reviewRatingVeryBad: "😞 Moi malo",
            .reviewRatingBad: "😕 Malo",
            .reviewRatingRegular: "😐 Regular",
            .reviewRatingGood: "😊 Bo",
            .reviewRatingExcellent: "🤩 Excelente",

            // Contribuciones
            .contribucionTitle: "Aportar información",
            .contribucionHelp: "Axuda a completar os datos de %@",
            .contribucionAddPhotos: "Engadir fotos",
            .contribucionCantina: "Ten cantina?",
            .contribucionAforo: "Aforo da grada (número)",
            .contribucionMedidas: "Medidas do campo (ex. 105x68 metros)",
            .contribucionIluminacion: "Tipo de iluminación",
            .contribucionIluminacionNatural: "Natural",
            .contribucionIluminacionArtificial: "Artificial",
            .contribucionCesped: "Estado do céspede",
            .contribucionCespedBueno: "Bo",
            .contribucionCespedRegular: "Regular",
            .contribucionCespedMalo: "Malo",
            .contribucionAccesibilidad: "Accesibilidade",
            .contribucionAccesibilidadSi: "Si, ten acceso para discapacitados",
            .contribucionAccesibilidadNo: "Non, non ten acceso",
            .contribucionSuccess: "✅ Contribución enviada. Grazas!",
            .contribucionError: "Erro ao enviar contribución",
            .contribucionSelect: "Seleccionar",

            // Toast
            .toastVisited: "✅ Visitado! %@",
            .toastUnvisited: "Visita desmarcada",
            .toastXPGained: "+%d XP - %@",
            .toastLevelUp: "⬆️ Nivel %d acadado!",
            .toastAchievement: "🏆 Novo logro! %@",

            // Profile
            .profileLanguage: "Idioma",
            .profileLanguageTitle: "Seleccionar idioma",
            .profileLanguageMessage: "Escolle o idioma da aplicación",

            // Empty States
            .emptyNoData: "Non hai datos dispoñibles",

            // Loading
            .loadingCampos: "Cargando campos de Galicia...",
            .loadingCampoInfo: "Cargando información do campo...",
            .loadingLogros: "Cargando logros...",
            .loadingLocation: "Obtendo a túa ubicación...",
        ]
    ]
}

// MARK: - SwiftUI Extension

extension View {
    /// Aplica el idioma actual del LocalizationManager
    func withLocalization() -> some View {
        self.environmentObject(LocalizationManager.shared)
    }
}

/// Helper para acceder a traducciones fácilmente
func L(_ key: LocalizedKey, _ args: CVarArg...) -> String {
    // Leer idioma actual desde UserDefaults (thread-safe)
    let savedLang = UserDefaults.standard.string(forKey: "app_language") ?? Language.spanish.rawValue
    let currentLang = Language(rawValue: savedLang) ?? .spanish

    let format = LocalizationManager.shared.translations[currentLang]?[key] ?? key.rawValue
    if args.isEmpty {
        return format
    }
    return String(format: format, arguments: args)
}
