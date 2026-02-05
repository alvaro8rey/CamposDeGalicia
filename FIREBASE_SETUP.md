# 🔥 Integración de Firebase Analytics

Esta guía te ayudará a integrar Firebase Analytics en la app Campos de Galicia.

## ✅ Estado Actual

- ✅ Código preparado para Firebase Analytics
- ✅ AnalyticsManager actualizado con soporte para Firebase
- ✅ AppDelegate configurado para inicializar Firebase
- ✅ .gitignore actualizado para excluir GoogleService-Info.plist
- ⏳ Pendiente: Añadir Firebase SDK y configurar proyecto en Firebase Console

---

## 📋 Pasos para Completar la Integración

### Paso 1: Añadir Firebase SDK con Swift Package Manager

1. Abre `Campos de Galicia.xcodeproj` en Xcode
2. Ve a **File → Add Package Dependencies...**
3. En el buscador, pega: `https://github.com/firebase/firebase-ios-sdk`
4. Selecciona la versión **10.20.0** o superior
5. Marca estos paquetes:
   - ✅ **FirebaseAnalytics** (obligatorio)
   - ✅ **FirebaseCrashlytics** (opcional pero recomendado)
   - ✅ **FirebasePerformance** (opcional)
6. Click en **Add Package**

### Paso 2: Crear Proyecto en Firebase Console

1. Ve a [Firebase Console](https://console.firebase.google.com)
2. Click en **Añadir proyecto** (o selecciona uno existente)
3. Nombre del proyecto: `Campos de Galicia` (o el que prefieras)
4. Acepta los términos y click en **Continuar**
5. Habilita Google Analytics: **Sí** ✅
6. Elige una cuenta de Google Analytics (o crea una nueva)
7. Click en **Crear proyecto**

### Paso 3: Añadir App iOS al Proyecto

1. En Firebase Console, click en el ícono de **iOS**
2. Ingresa el **Bundle ID** de tu app:
   ```
   com.alvaro8rey.CamposDeGalicia
   ```
   (Puedes verificar esto en Xcode → Target → General → Bundle Identifier)

3. **Apodo de la app** (opcional): `Campos de Galicia iOS`
4. **App Store ID** (opcional): déjalo vacío por ahora
5. Click en **Registrar app**

### Paso 4: Descargar GoogleService-Info.plist

1. Firebase te mostrará un botón **Descargar GoogleService-Info.plist**
2. Descarga el archivo
3. **MUY IMPORTANTE**: Arrastra el archivo a Xcode en la carpeta raíz del proyecto "Campos de Galicia"
4. Asegúrate de marcar:
   - ✅ **Copy items if needed**
   - ✅ **Add to targets: Campos de Galicia**
5. Click en **Finish**

### Paso 5: Verificar Instalación

1. Limpia el build folder: `Cmd + Shift + K`
2. Compila el proyecto: `Cmd + B`
3. Si todo está bien, verás en la consola:
   ```
   ✅ Firebase configurado correctamente
   📊 Analytics inicializado con: localLogs, firebase
   ```

---

## 🧪 Pruebas

### Verificar que Firebase está Funcionando

1. Ejecuta la app en el simulador o dispositivo físico
2. Navega por la app (abrir campos, ver detalles, etc.)
3. Ve a Firebase Console → Analytics → Events
4. En **Debug View**, deberías ver eventos en tiempo real

**IMPORTANTE**: Para ver eventos en Debug View:

```bash
# En terminal, ejecuta:
adb shell setprop debug.firebase.analytics.app com.alvaro8rey.CamposDeGalicia

# Para dispositivos iOS reales:
# Xcode → Edit Scheme → Run → Arguments → Add:
-FIRDebugEnabled
```

### Eventos que Deberías Ver

Los siguientes eventos se trackean automáticamente:

| Evento | Cuando se dispara |
|--------|------------------|
| `app_launched` | Al abrir la app |
| `screen_viewed` | Al cambiar de pantalla |
| `campo_viewed` | Al ver detalles de un campo |
| `campo_visited` | Al visitar un campo (geofencing) |
| `login` | Al iniciar sesión |
| `register` | Al registrarse |
| `achievement_unlocked` | Al desbloquear un logro |
| `level_up` | Al subir de nivel |
| `error` | Cuando ocurre un error |

---

## 📊 Eventos Importantes para tu App

### Eventos de Usuario
```swift
AnalyticsManager.shared.trackLogin()
AnalyticsManager.shared.track(.register)
AnalyticsManager.shared.track(.logout)
AnalyticsManager.shared.track(.profileUpdate)
```

### Eventos de Campo
```swift
AnalyticsManager.shared.trackCampoView(id: campoId, name: campoName)
AnalyticsManager.shared.trackCampoVisit(id: campoId, name: campoName, autoCheckin: true)
AnalyticsManager.shared.track(.campoContributionAdded(id: campoId.uuidString))
```

### Eventos de Gamificación
```swift
AnalyticsManager.shared.trackAchievement(id: logroId, name: logroName, xp: xpValue)
AnalyticsManager.shared.trackLevelUp(newLevel: level, totalXP: xp)
```

### Eventos de Navegación
```swift
AnalyticsManager.shared.trackScreen("MapView")
AnalyticsManager.shared.track(.tabChanged(to: "Profile"))
```

### Eventos de Error
```swift
AnalyticsManager.shared.trackError(type: "network", message: errorMsg)
```

---

## 🎯 Propiedades de Usuario

Establece propiedades para segmentar usuarios:

```swift
AnalyticsManager.shared.setUserProperties([
    "user_id": userId,
    "email": userEmail,
    "level": userLevel,
    "total_campos_visited": totalVisited,
    "user_type": "active_contributor" // o "visitor"
])
```

---

## 📈 Métricas Clave en Firebase Console

### Analytics → Dashboard

- **Usuarios Activos**: Diarios, semanales, mensuales
- **Retención**: % de usuarios que vuelven después de 1, 7, 30 días
- **Engagement**: Tiempo promedio en app, sesiones por usuario
- **Eventos Principales**: Top eventos más disparados

### Analytics → Events

- **Todos los eventos**: Lista completa
- **Conversiones**: Marca eventos importantes como conversiones
- **Parámetros**: Filtra por parámetros específicos

### Analytics → User Properties

- Segmenta usuarios por nivel, ubicación, comportamiento

### Analytics → DebugView

- **Vista en tiempo real** de eventos (útil para desarrollo)

---

## 🚨 Solución de Problemas

### "Firebase not configured"

**Causa**: GoogleService-Info.plist no está añadido correctamente.

**Solución**:
1. Verifica que el archivo esté en Xcode (raíz del proyecto)
2. Verifica que esté marcado en Target Membership
3. Limpia build folder y recompila

### "No events showing in Firebase Console"

**Causas posibles**:
1. **Tiempo de propagación**: Eventos pueden tardar hasta 24 horas en aparecer
2. **Debug mode no activado**: Usa `-FIRDebugEnabled` para ver eventos en tiempo real
3. **Bundle ID incorrecto**: Verifica que coincida con Firebase Console

**Solución para ver eventos inmediatamente**:
- Usa DebugView con `-FIRDebugEnabled`
- Los eventos aparecen en ~1 minuto en DebugView

### "Crashlytics not working"

**Solución**:
1. Asegúrate de haber añadido `FirebaseCrashlytics` al Package
2. En Xcode → Build Phases → Add Run Script Phase:
   ```bash
   "${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"
   ```
3. Input Files:
   ```
   ${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${TARGET_NAME}
   $(SRCROOT)/$(BUILT_PRODUCTS_DIR)/$(INFOPLIST_PATH)
   ```

---

## 🔒 Seguridad y Privacidad

### GoogleService-Info.plist

- ✅ Ya está en `.gitignore` - **NO LO SUBAS A GIT**
- Contiene API keys de tu proyecto
- Usa diferentes archivos para desarrollo/producción

### Datos de Usuario

Firebase Analytics cumple con:
- ✅ **GDPR** (Europa)
- ✅ **CCPA** (California)
- ✅ Permite opt-out de usuarios

Para deshabilitar analytics para un usuario:
```swift
Analytics.setAnalyticsCollectionEnabled(false)
```

---

## 📚 Recursos Adicionales

- [Documentación Firebase Analytics iOS](https://firebase.google.com/docs/analytics/get-started?platform=ios)
- [Eventos Recomendados](https://firebase.google.com/docs/analytics/events?platform=ios)
- [Propiedades de Usuario](https://firebase.google.com/docs/analytics/user-properties?platform=ios)
- [Debug View](https://firebase.google.com/docs/analytics/debugview?platform=ios)

---

## ✅ Checklist de Integración

- [ ] Firebase SDK añadido via SPM
- [ ] Proyecto creado en Firebase Console
- [ ] App iOS registrada en Firebase
- [ ] GoogleService-Info.plist descargado
- [ ] GoogleService-Info.plist añadido a Xcode
- [ ] App compila sin errores
- [ ] Firebase se inicializa correctamente (ver logs)
- [ ] Eventos aparecen en DebugView
- [ ] Analytics configurado en Firebase Console

---

## 🎉 ¡Listo!

Una vez completados estos pasos, Firebase Analytics estará completamente integrado y podrás:

- Ver estadísticas de usuarios en tiempo real
- Analizar comportamiento y engagement
- Detectar errores y crashes
- Optimizar features basándote en datos reales
- Hacer A/B testing con Remote Config

**¿Tienes dudas?** Consulta la documentación oficial de Firebase o revisa los logs de la app.
