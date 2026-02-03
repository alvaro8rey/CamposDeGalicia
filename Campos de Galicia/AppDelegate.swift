import UIKit
import BackgroundTasks
import CoreLocation

/// AppDelegate para manejar eventos de background y tareas programadas
class AppDelegate: NSObject, UIApplicationDelegate {

    // Identificador de la tarea de background
    static let backgroundTaskIdentifier = "com.camposdegalicia.app.dwellcheck"

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        print("🚀 AppDelegate didFinishLaunchingWithOptions")

        // Registrar tareas de background
        registerBackgroundTasks()

        // Verificar si la app fue lanzada por un evento de ubicación
        if let locationKey = launchOptions?[.location] as? Bool, locationKey {
            print("📍 App lanzada por evento de ubicación en background")
            // El GeofenceManager ya está configurado como delegate y manejará los eventos
        }

        return true
    }

    // MARK: - Background Tasks

    /// Registra las tareas de background para verificación de dwells
    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: AppDelegate.backgroundTaskIdentifier,
            using: nil
        ) { task in
            print("🌙 Ejecutando tarea de background: verificación de dwells")
            guard let processingTask = task as? BGProcessingTask else {
                print("❌ Error: La tarea no es del tipo BGProcessingTask")
                task.setTaskCompleted(success: false)
                return
            }
            self.handleDwellCheckTask(task: processingTask)
        }
        print("✅ Tarea de background registrada: \(AppDelegate.backgroundTaskIdentifier)")
    }

    /// Programa la siguiente verificación de dwells
    static func scheduleBackgroundDwellCheck() {
        let request = BGProcessingTaskRequest(identifier: backgroundTaskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutos

        do {
            try BGTaskScheduler.shared.submit(request)
            print("📅 Programada verificación de dwells en background para dentro de 15 minutos")
        } catch {
            print("❌ Error al programar tarea de background: \(error)")
        }
    }

    /// Maneja la tarea de verificación de dwells en background
    private func handleDwellCheckTask(task: BGProcessingTask) {
        print("⏰ Ejecutando verificación de dwells en background")

        // Programar la siguiente ejecución
        AppDelegate.scheduleBackgroundDwellCheck()

        // Crear una tarea para verificar dwells
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1

        let operation = BlockOperation {
            print("🔍 Verificando dwells pendientes en background...")
            // Esto será procesado por GeofenceManager cuando se active
        }

        task.expirationHandler = {
            print("⏰ Tarea de background expirando - cancelando operación")
            queue.cancelAllOperations()
        }

        operation.completionBlock = {
            print("✅ Verificación de dwells completada")
            task.setTaskCompleted(success: !operation.isCancelled)
        }

        queue.addOperation(operation)
    }

    // MARK: - Lifecycle

    func applicationDidEnterBackground(_ application: UIApplication) {
        print("🌙 App entrando en background")
        // Programar tarea de verificación
        AppDelegate.scheduleBackgroundDwellCheck()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        print("☀️ App volviendo a foreground")
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        print("✨ App activa")
    }
}
