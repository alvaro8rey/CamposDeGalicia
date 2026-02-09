# Diagnóstico de CarPlay

## Estado de los Archivos

✅ **CarPlaySceneDelegate.swift** - Existe y está correctamente implementado
✅ **CarPlayManager.swift** - Existe y está correctamente implementado
✅ **Info.plist** - Tiene la configuración correcta de escenas de CarPlay
✅ **Entitlements** - Tiene el entitlement `com.apple.developer.carplay-navigation`

## Configuración Actual

### Info.plist (`Campos-de-Galicia-Info.plist`)
```xml
<key>CPTemplateApplicationSceneSessionRoleApplication</key>
<array>
    <dict>
        <key>UISceneClassName</key>
        <string>CPTemplateApplicationScene</string>
        <key>UISceneConfigurationName</key>
        <string>CarPlay</string>
        <key>UISceneDelegateClassName</key>
        <string>$(PRODUCT_MODULE_NAME).CarPlaySceneDelegate</string>
    </dict>
</array>
```

### AppDelegate.swift
El AppDelegate está correctamente configurado para manejar escenas de CarPlay:
```swift
if connectingSceneSession.role == .carTemplateApplication {
    let sceneConfig = UISceneConfiguration(name: "CarPlay",
                                           sessionRole: connectingSceneSession.role)
    sceneConfig.delegateClass = CarPlaySceneDelegate.self
    return sceneConfig
}
```

## Problema Identificado

El proyecto usa **PBXFileSystemSynchronizedRootGroup** (Xcode 15+), que sincroniza automáticamente archivos. Sin embargo, puede necesitar una limpieza y recompilación.

## Solución - Pasos a Seguir en Xcode

### 1. Limpiar el Proyecto
```
Cmd + Shift + K (Clean Build Folder)
Cmd + Shift + Option + K (Clean All Build Folders)
```

### 2. Verificar que los Archivos Estén en el Target
1. En Xcode, selecciona `CarPlaySceneDelegate.swift`
2. En el Inspector de Archivos (panel derecho), verifica que la casilla del target "Campos de Galicia" esté marcada
3. Haz lo mismo con `CarPlayManager.swift`

### 3. Verificar Configuración del Proyecto
1. Selecciona el proyecto en el navegador
2. Ve a la pestaña "Build Settings"
3. Busca "INFOPLIST_FILE" y verifica que apunte a: `Campos-de-Galicia-Info.plist`
4. Busca "CODE_SIGN_ENTITLEMENTS" y verifica que apunte a: `Campos de Galicia/Campos de Galicia.entitlements`

### 4. Verificar Esquema de Compilación
1. Ve a Product > Scheme > Edit Scheme
2. En la sección "Run", pestaña "Info"
3. Verifica que "Build Configuration" esté en "Debug" (para que funcione Logger)

### 5. Recompilar
```
Cmd + B (Build)
```

## Para Probar CarPlay en el Simulador

### Método 1: Menú del Simulador
1. Ejecuta la app en el simulador (Cmd + R)
2. En el simulador, ve a menú: **I/O > External Displays > CarPlay**
3. Deberías ver aparecer una ventana de CarPlay

### Método 2: Hardware del Simulador
1. Con el simulador abierto
2. Ve a: **Hardware > External Displays > CarPlay**

## Verificar Logs

Una vez que ejecutes la app en el simulador con CarPlay activado, deberías ver estos logs en la consola:

```
🔧 Configurando escena: CPTemplateApplicationSceneSessionRoleApplication
🚗 Configuración de CarPlay creada
🚗 CarPlay conectado
🚗 Configurando interfaz de CarPlay
✅ Template de CarPlay establecido correctamente
```

Si ves estos logs, CarPlay está funcionando correctamente.

## Si Aún No Funciona

1. **Verifica que estás ejecutando en Debug mode** (no Release)
2. **Cierra completamente Xcode** y vuelve a abrirlo
3. **Borra Derived Data**:
   - Ve a Xcode > Settings > Locations
   - Haz clic en la flecha junto a "Derived Data"
   - Borra la carpeta de tu proyecto
4. **Reinicia el simulador**

## Logs de Depuración

Si sigues sin ver logs, agrega estos comandos temporales en `AppDelegate.swift` línea 18:

```swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    print("========== APP LAUNCHED ==========")
    Logger.debug("🚀 AppDelegate didFinishLaunchingWithOptions")
    // ... resto del código
```

Y en `CarPlaySceneDelegate.swift` línea 18:

```swift
func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                               didConnect interfaceController: CPInterfaceController) {
    print("========== CARPLAY CONNECTED ==========")
    Logger.debug("🚗 CarPlay conectado")
    // ... resto del código
```

Los `print()` siempre se mostrarán, incluso si Logger falla.
