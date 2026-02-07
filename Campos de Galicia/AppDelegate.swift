import UIKit
import BackgroundTasks
import CoreLocation

// Firebase import (comment out if not using Firebase)
#if canImport(FirebaseCore)
import FirebaseCore
#endif

/// AppDelegate para manejar eventos de background y tareas programadas
class AppDelegate: NSObject, UIApplicationDelegate {

    // Identificador de la tarea de background
    static let backgroundTaskIdentifier = "com.camposdegalicia.app.dwellcheck"

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        print("========== APP LAUNCHED ==========")
        Logger.debug("🚀 AppDelegate didFinishLaunchingWithOptions")

        // Configurar Firebase
        configureFirebase()

        // Registrar tareas de background
        registerBackgroundTasks()

        // Verificar si la app fue lanzada por un evento de ubicación
        if let locationKey = launchOptions?[.location] as? Bool, locationKey {
            Logger.debug("📍 App lanzada por evento de ubicación en background")
            // El GeofenceManager ya está configurado como delegate y manejará los eventos
        }

        // Inicializar AnalyticsManager
        _ = AnalyticsManager.shared

        // Track app launch
        AnalyticsManager.shared.track(.appLaunched)

        return true
    }

    // MARK: - Firebase Configuration

    /// Configura Firebase si está disponible
    private func configureFirebase() {
        #if canImport(FirebaseCore)
        FirebaseApp.configure()
        Logger.success("✅ Firebase configurado correctamente")
        #else
        Logger.debug("⚠️ Firebase no disponible - continuando sin analytics")
        #endif
    }

    // MARK: - Background Tasks

    /// Registra las tareas de background para verificación de dwells
    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: AppDelegate.backgroundTaskIdentifier,
            using: nil
        ) { task in
            Logger.debug("🌙 Ejecutando tarea de background: verificación de dwells")
            guard let processingTask = task as? BGProcessingTask else {
                Logger.debug("❌ Error: La tarea no es del tipo BGProcessingTask")
                task.setTaskCompleted(success: false)
                return
            }
            self.handleDwellCheckTask(task: processingTask)
        }
        Logger.debug("✅ Tarea de background registrada: \(AppDelegate.backgroundTaskIdentifier)")
    }

    /// Programa la siguiente verificación de dwells
    static func scheduleBackgroundDwellCheck() {
        let request = BGProcessingTaskRequest(identifier: backgroundTaskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutos

        do {
            try BGTaskScheduler.shared.submit(request)
            Logger.debug("📅 Programada verificación de dwells en background para dentro de 15 minutos")
        } catch {
            Logger.debug("❌ Error al programar tarea de background: \(error)")
        }
    }

    /// Maneja la tarea de verificación de dwells en background
    private func handleDwellCheckTask(task: BGProcessingTask) {
        Logger.debug("⏰ Ejecutando verificación de dwells en background")

        // Programar la siguiente ejecución
        AppDelegate.scheduleBackgroundDwellCheck()

        // Crear una tarea para verificar dwells
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1

        let operation = BlockOperation {
            Logger.debug("🔍 Verificando dwells pendientes en background...")
            // Esto será procesado por GeofenceManager cuando se active
        }

        task.expirationHandler = {
            Logger.debug("⏰ Tarea de background expirando - cancelando operación")
            queue.cancelAllOperations()
        }

        operation.completionBlock = {
            Logger.debug("✅ Verificación de dwells completada")
            task.setTaskCompleted(success: !operation.isCancelled)
        }

        queue.addOperation(operation)
    }

    // MARK: - Lifecycle

    func applicationDidEnterBackground(_ application: UIApplication) {
        Logger.debug("🌙 App entrando en background")

        // 📊 Analytics: Track app backgrounded
        let sessionDuration = Date().timeIntervalSince(application.backgroundRefreshStatus == .available ? Date() : Date())
        AnalyticsManager.shared.track(.appBackgrounded(sessionDuration: sessionDuration))
        AnalyticsManager.shared.endSession()

        // Programar tarea de verificación
        AppDelegate.scheduleBackgroundDwellCheck()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        Logger.debug("☀️ App volviendo a foreground")

        // 📊 Analytics: Track app foregrounded
        AnalyticsManager.shared.track(.appForegrounded)
        AnalyticsManager.shared.startNewSession()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        Logger.debug("✨ App activa")
    }

    // MARK: - UISceneSession Lifecycle

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        Logger.debug("🔧 Configurando escena: \(connectingSceneSession.role.rawValue)")

        // Configuración por defecto para la app principal
        let sceneConfig = UISceneConfiguration(name: "Default",
                                               sessionRole: connectingSceneSession.role)
        Logger.debug("📱 Configuración de app principal creada")
        return sceneConfig
    }
}
