# CarPlay - Instrucciones para Producción

## Estado Actual ✅

Tu app ya tiene **TODA la implementación de CarPlay lista**:

- ✅ `CarPlaySceneDelegate.swift` - Maneja la conexión de CarPlay
- ✅ `CarPlayManager.swift` - Lógica completa de la interfaz
- ✅ `Info.plist` - Configuración de escenas de CarPlay
- ✅ `AppDelegate.swift` - Detección y configuración de escenas

## Funcionalidades Implementadas

1. **Mapa interactivo** con campos de fútbol cercanos
2. **Lista de campos cercanos** (hasta 10 campos en un radio de 50km)
3. **Búsqueda de campos** por nombre o localidad
4. **Navegación** a cualquier campo usando Apple Maps
5. **Botones de acción** para centrar ubicación y ver listas
6. **Integración con ubicación** del usuario

## Para Probar en el Simulador AHORA

### 1. Compilar y Ejecutar
```bash
# En Xcode:
Cmd + B  # Build
Cmd + R  # Run
```

### 2. Abrir Ventana de CarPlay
Con el simulador ejecutándose:
- Ve a: **I/O → External Displays → CarPlay**
- O: **Hardware → External Displays → CarPlay**

### 3. Verificar Logs
En la consola de Xcode deberías ver:
```
========================================
🚗🚗🚗 CARPLAY CONECTADO! 🚗🚗🚗
========================================
✅ Interface controller asignado
✅ Window asignada
📱 Inicializando CarPlayManager...
🎨 Configurando interfaz de CarPlay...
========================================
✅ CARPLAY CONFIGURADO COMPLETAMENTE
========================================
```

## Cuando Tengas la Cuenta de Desarrollador

### Paso 1: Solicitar el Entitlement de CarPlay

1. Inicia sesión en [Apple Developer Portal](https://developer.apple.com)
2. Ve a: **Certificates, Identifiers & Profiles**
3. Selecciona tu **App ID** (`com.camposdegalicia.app`)
4. En la sección de **Capabilities**, busca y habilita:
   - ✅ **CarPlay Navigation** (para apps de navegación con mapas)
5. Guarda los cambios
6. Apple puede tardar **1-2 días** en aprobar el entitlement

### Paso 2: Actualizar el Perfil de Provisioning

Una vez aprobado el entitlement:

1. En Apple Developer Portal, ve a **Profiles**
2. Edita tu perfil de desarrollo/distribución
3. Regenera el perfil (incluirá automáticamente el nuevo entitlement)
4. Descarga e instala el nuevo perfil

### Paso 3: Agregar el Entitlement al Proyecto

1. En Xcode, abre tu proyecto
2. Ve a: **Target → Signing & Capabilities**
3. Haz clic en **+ Capability**
4. Busca y agrega: **CarPlay**
5. Se creará/actualizará automáticamente el archivo `.entitlements` con:
   ```xml
   <key>com.apple.developer.carplay-navigation</key>
   <true/>
   ```

### Paso 4: ¡Listo para Producción!

Una vez agregado el entitlement:

- ✅ Tu app funcionará en dispositivos iOS reales conectados a CarPlay
- ✅ Podrás distribuir la app en TestFlight con soporte de CarPlay
- ✅ Podrás publicar en la App Store con funcionalidad de CarPlay

## Notas Importantes

### Para el Simulador (SIN entitlement - AHORA)
- ✅ Funciona perfectamente en el simulador de Xcode
- ✅ Puedes diseñar y probar toda la interfaz
- ✅ Puedes verificar la lógica y el flujo de navegación
- ❌ No funciona en dispositivos físicos sin el entitlement

### Para Dispositivos Reales (CON entitlement)
- ✅ Requiere cuenta de desarrollador paga ($99/año)
- ✅ Requiere solicitar y obtener aprobación del entitlement
- ✅ Funciona en autos con CarPlay o adaptadores CarPlay
- ✅ Necesario para publicar en la App Store

## Solución de Problemas

### Si no aparece la ventana de CarPlay en el simulador:

1. **Limpia el build:**
   ```
   Cmd + Shift + K (Clean Build Folder)
   ```

2. **Verifica que los archivos estén en el target:**
   - Selecciona `CarPlaySceneDelegate.swift` en Xcode
   - En el panel derecho, verifica que esté marcado el target "Campos de Galicia"
   - Haz lo mismo con `CarPlayManager.swift`

3. **Reinicia Xcode y el simulador**

4. **Verifica la configuración del build:**
   - En Build Settings, busca `INFOPLIST_FILE`
   - Debe apuntar a: `Campos-de-Galicia-Info.plist`

### Si hay errores de compilación:

1. Verifica que tienes la importación de CarPlay:
   ```swift
   import CarPlay
   ```

2. Asegúrate de que el deployment target sea iOS 14.0 o superior

## Checklist Final

Antes de solicitar el entitlement, asegúrate de:

- [ ] La app funciona correctamente en el simulador de CarPlay
- [ ] Has probado todas las funcionalidades (búsqueda, navegación, lista)
- [ ] Los logs muestran que CarPlay se conecta correctamente
- [ ] La interfaz se ve bien y es usable
- [ ] Has probado con diferentes campos y ubicaciones
- [ ] La navegación a campos funciona correctamente

## Recursos Adicionales

- [CarPlay Documentation](https://developer.apple.com/carplay/)
- [CarPlay Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/carplay)
- [CarPlay Entitlements](https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_developer_carplay-navigation)

---

**¡Todo está listo! Ahora puedes diseñar y perfeccionar tu interfaz de CarPlay en el simulador. Cuando tengas tu cuenta de desarrollador, solo sigue los pasos arriba y estará lista para producción.**
