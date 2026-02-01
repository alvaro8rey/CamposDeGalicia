# Configuración de Notificaciones en Background

## Cambios Implementados

Se ha implementado un sistema robusto de auto check-in que funciona **incluso con la app cerrada o en segundo plano**.

### Problemas Resueltos

1. **Timers no funcionaban en background**: Los `Timer.scheduledTimer` se pausan cuando iOS suspende la app
2. **Pérdida de estado**: Los datos no persistían cuando la app se cerraba
3. **Eventos no procesados**: Los eventos de geofencing no se procesaban correctamente en background

### Soluciones Implementadas

1. **Sistema de timestamps persistentes**
   - Los timestamps de entrada a regiones se guardan en `UserDefaults`
   - Se verifican en cada evento de ubicación (entrada, salida, cambio de estado)
   - Sobreviven al cierre completo de la app

2. **Background Tasks**
   - Uso de `UIBackgroundTaskIdentifier` para procesamiento extendido
   - Configuración de `BGTaskScheduler` para verificaciones periódicas
   - La app se despierta automáticamente cuando el usuario entra/sale de una región

3. **Carga de datos persistidos**
   - En cada evento de geofencing (`didEnterRegion`, `didExitRegion`, `didDetermineState`), se cargan los datos guardados
   - Permite procesar dwells que comenzaron antes de que la app se cerrara

4. **Verificación continua**
   - `checkPendingDwells()` se llama en TODOS los eventos de ubicación
   - Verifica si han transcurrido los 120 segundos necesarios
   - Procesa automáticamente los check-ins completados

## Configuración Necesaria en Xcode

### 1. Agregar AppDelegate.swift al Target

El archivo `AppDelegate.swift` fue creado pero necesita ser agregado al target de compilación:

1. Abre el proyecto en Xcode
2. Haz clic derecho en la carpeta "Campos de Galicia" en el navegador de archivos
3. Selecciona "Add Files to 'Campos de Galicia'..."
4. Navega a `Campos de Galicia/AppDelegate.swift`
5. Asegúrate de que "Copy items if needed" esté DESMARCADO
6. Marca el target "Campos de Galicia"
7. Haz clic en "Add"

**ALTERNATIVA (si el archivo ya aparece):**
1. Selecciona `AppDelegate.swift` en el navegador
2. En el panel derecho, en "Target Membership", asegúrate de que "Campos de Galicia" esté marcado

### 2. Verificar Background Modes

Ya están configurados en `Info.plist`, pero verifica en Xcode:

1. Selecciona el proyecto en el navegador
2. Ve a la pestaña "Signing & Capabilities"
3. Asegúrate de que "Background Modes" esté habilitado con:
   - ✅ Location updates
   - ✅ Background fetch
   - ✅ Remote notifications
   - ✅ Background processing

Si no aparece "Background Modes", haz clic en "+ Capability" y agrégalo.

### 3. Registrar Background Task Identifier

1. Selecciona el proyecto en el navegador
2. Ve a la pestaña "Info"
3. Busca "Permitted background task scheduler identifiers"
4. Si no existe, haz clic en el "+" al lado de "Information Property List"
5. Agrega: `Permitted background task scheduler identifiers` (tipo: Array)
6. Dentro del array, agrega un item (tipo: String) con el valor:
   ```
   com.camposdegalicia.app.dwellcheck
   ```

**NOTA**: Si compilas y ves un warning sobre "Background task identifier not registered", sigue estos pasos.

### 4. Permisos de Ubicación

El usuario DEBE otorgar permiso de ubicación "Always" (Siempre) para que funcione en background:

- La app solicitará automáticamente el permiso cuando active el auto check-in
- En Settings > Configuración > Auto Check-in aparece un warning si el permiso no es "Always"
- El usuario puede cambiarlo en: Settings > Privacy > Location Services > Campos de Galicia

## Cómo Funciona

### Flujo en Foreground
1. Usuario entra en región → `didEnterRegion` llamado
2. Se guarda timestamp de entrada en `UserDefaults`
3. Timer opcional se crea (solo para feedback visual)
4. Después de 120s, se verifica y procesa el check-in

### Flujo en Background
1. Usuario entra en región → iOS despierta la app
2. `didEnterRegion` llamado automáticamente
3. Se cargan datos de `UserDefaults`
4. Se guarda timestamp de entrada
5. Se inicia background task (30 segundos de procesamiento garantizado)
6. Usuario permanece 120s → En el siguiente evento de ubicación o cuando se verifica el estado de la región, `checkPendingDwells()` detecta que pasaron los 120s
7. Se procesa el check-in y se envía la notificación
8. Background task se finaliza

### Flujo con App Cerrada
1. Usuario entra en región → iOS despierta la app completamente
2. `application(_:didFinishLaunchingWithOptions:)` llamado con `.location`
3. `GeofenceManager` se inicializa y carga datos persistidos
4. `didEnterRegion` procesa el evento
5. Mismo proceso que en background

## Testing

### Prueba en Simulador (Limitado)
El simulador NO puede probar geofencing real. Para testing básico:
1. Usa "Debug > Location > Custom Location"
2. Cambia coordenadas manualmente
3. Los eventos NO se dispararán correctamente

### Prueba en Dispositivo Real (Recomendado)
1. Compila en un iPhone real
2. Activa auto check-in en Settings
3. Otorga permiso "Always"
4. Cierra la app completamente (desliza hacia arriba)
5. Camina hacia un campo de fútbol
6. Al entrar en el radio de 200m, iOS despertará la app
7. Después de 120s dentro, recibirás la notificación

### Debugging en Background
1. En Xcode, ve a Debug > Simulate Background Fetch
2. O usa: `e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.camposdegalicia.app.dwellcheck"]`
3. Revisa los logs para ver si se ejecuta correctamente

## Logs Importantes

Busca estos mensajes en la consola:

- `🚶 didEnterRegion llamado - iOS despertó la app por evento de geofencing`
- `📂 Cargados X timestamps de dwells persistidos`
- `⏱️ Empezando dwell de 120s para [campo]`
- `✅ Dwell completado en background para [campo]`
- `🔔 Notificación enviada`
- `🌙 Background task iniciado`

## Optimizaciones

- **Bajo consumo de batería**:
  - Solo usa Significant Location Changes (cambios > 500m)
  - No usa GPS continuo
  - Precisión de 10m (no "Best")
  - Background tasks se finalizan rápidamente

- **Eficiencia de red**:
  - Solo 20 regiones monitorizadas a la vez
  - Priorizadas por cercanía
  - Re-priorizan cada 6 horas o al moverte significativamente

- **Memoria**:
  - Datos persistidos son mínimos (solo UUIDs y timestamps)
  - No se mantienen objetos pesados en memoria

## Troubleshooting

### Las notificaciones no llegan en background

1. **Verifica permisos**: Settings > Campos de Galicia > Location > Always
2. **Verifica Background Modes**: En Xcode, Signing & Capabilities
3. **Revisa los logs**: Busca mensajes de error en consola
4. **Reinicia la app**: A veces iOS necesita reiniciar para aplicar cambios

### Los dwells no se procesan

1. **Verifica que hay campos cargados**: Revisa logs "configurando geovallas para X campos"
2. **Verifica que las regiones están monitorizadas**: Logs "Total de regiones monitorizadas"
3. **Asegúrate de estar dentro del radio**: 200 metros del campo
4. **Espera los 120 segundos completos**: No salgas antes de tiempo

### La app consume mucha batería

- Esto NO debería pasar con la configuración actual
- Si pasa, revisa que `allowsBackgroundLocationUpdates = true` pero que NO hay actualizaciones continuas
- Verifica que solo se usa `Significant Location Changes`

## Próximos Pasos Recomendados

1. **Testing exhaustivo** en dispositivo real
2. **Monitorear logs** durante varios días de uso
3. **Ajustar parámetros** si es necesario (dwell time, radio, etc.)
4. **Feedback de usuarios** sobre funcionamiento en background
