# 🔍 Solicitar búsqueda con texto en CarPlay (CPSearchTemplate)

## ⚠️ IMPORTANTE

Apple **NO permite** usar `CPSearchTemplate` sin autorización previa. Para usarlo en tu app necesitas:

1. ✅ Tener la app publicada en el App Store
2. ✅ Solicitar el entitlement `com.apple.developer.carplay-search`
3. ✅ Esperar aprobación de Apple (puede tardar semanas)

---

## 📋 Proceso de solicitud

### 1️⃣ **Preparar tu app**

Antes de solicitar, asegúrate de que:

- [ ] Tu app está **publicada en el App Store**
- [ ] CarPlay está funcionando correctamente (sin crashes)
- [ ] Tienes una razón clara de por qué necesitas búsqueda con texto
- [ ] Tu app tiene suficientes usuarios activos

---

### 2️⃣ **Solicitar el entitlement**

#### **Opción A: Apple Developer Program**

1. Ve a [Apple Developer Program](https://developer.apple.com/contact/request/carplay/)
2. Selecciona **"Request CarPlay Entitlements"**
3. Rellena el formulario:
   - **App Name**: Campos de Galicia
   - **Bundle ID**: `com.alvaro8rey.CamposDeGalicia`
   - **Entitlement**: `com.apple.developer.carplay-search`
   - **Justificación**: Ver ejemplo abajo

#### **Opción B: Email directo**

Envía un email a: **carplay@apple.com**

**Asunto:**
```
CarPlay Search Entitlement Request - Campos de Galicia (com.alvaro8rey.CamposDeGalicia)
```

**Cuerpo del email:**
```
Hello Apple CarPlay Team,

I am requesting the com.apple.developer.carplay-search entitlement for my app "Campos de Galicia".

App Details:
- App Name: Campos de Galicia
- Bundle ID: com.alvaro8rey.CamposDeGalicia
- App Store Link: [TU ENLACE DEL APP STORE]
- Developer Account: [TU CUENTA DE DEVELOPER]

Use Case:
"Campos de Galicia" is a sports field directory app for Galicia, Spain, with over 120 registered fields. The app helps users find and navigate to football fields across 4 provinces.

Why we need CPSearchTemplate:
1. Users need to quickly search for specific fields while driving (e.g., "Riazor", "Balaídos")
2. Currently, users must browse through paginated lists (8 items per page), which requires multiple taps
3. Text search is essential for finding a specific field among 120+ entries safely while driving
4. Our current implementation uses CPListTemplate with pagination, but it's not efficient for quick lookups

Safety Considerations:
- Search will use voice dictation (Siri integration)
- Results will be filtered server-side to minimize distractions
- Maximum 8 results will be shown per search
- Full field details require stopping (navigation starts only when parked)

Current CarPlay Implementation:
- Main screen: Nearest fields based on location
- "All" button: Paginated list of all fields (8 per page)
- Navigation: Tap field → Details → Navigate (opens Apple Maps)

We believe text search will significantly improve the user experience while maintaining safety standards.

Thank you for your consideration.

Best regards,
[TU NOMBRE]
[TU EMAIL]
[TU EMPRESA/NOMBRE DE DEVELOPER]
```

---

### 3️⃣ **Esperar respuesta**

- ⏱️ Apple puede tardar **2-6 semanas** en responder
- 📧 Recibirás un email de confirmación o rechazo
- ✅ Si es aprobado, el entitlement se añadirá a tu cuenta

---

### 4️⃣ **Implementar CPSearchTemplate (después de la aprobación)**

Una vez aprobado, actualiza tu `Info.plist` y `entitlements`:

#### **Info.plist**
```xml
<key>UIApplicationSceneManifest</key>
<dict>
    <key>UIApplicationSupportsCarPlay</key>
    <true/>
    <key>UIApplicationSceneManifest</key>
    <dict>
        <key>CarPlaySceneTemplates</key>
        <array>
            <string>CPListTemplate</string>
            <string>CPSearchTemplate</string>  <!-- ✅ AÑADE ESTO -->
        </array>
    </dict>
</dict>
```

#### **Entitlements file**
```xml
<key>com.apple.developer.carplay-search</key>
<true/>
```

#### **Código Swift**
```swift
// MARK: - Búsqueda con texto (requiere entitlement)

private func showSearchTemplate() {
    let searchTemplate = CPSearchTemplate()
    searchTemplate.delegate = self

    interfaceController.pushTemplate(searchTemplate, animated: true)
    Logger.debug("✅ CPSearchTemplate mostrado")
}

// MARK: - CPSearchTemplateDelegate

extension CarPlayManager: CPSearchTemplateDelegate {
    func searchTemplate(_ searchTemplate: CPSearchTemplate,
                       updatedSearchText searchText: String,
                       completionHandler: @escaping ([CPListItem]) -> Void) {

        Logger.debug("🔍 Búsqueda: \(searchText)")

        let filtered = allCampos
            .filter { $0.nombre.lowercased().contains(searchText.lowercased()) }
            .sorted { $0.nombre < $1.nombre }
            .prefix(8)  // Máximo 8 resultados

        let items = filtered.map { campo -> CPListItem in
            let item = CPListItem(
                text: campo.nombre,
                detailText: "\(campo.localidad), \(campo.provincia)"
            )
            item.handler = { [weak self] (_, completion) in
                self?.showCampoDetails(campo)
                completion()
            }
            return item
        }

        completionHandler(items)
        Logger.debug("✅ \(items.count) resultados para '\(searchText)'")
    }

    func searchTemplate(_ searchTemplate: CPSearchTemplate,
                       selectedResult item: CPListItem,
                       completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
```

---

## 📊 Probabilidad de aprobación

| ✅ A favor | ❌ En contra |
|-----------|-------------|
| App publicada | App nueva sin usuarios |
| Caso de uso claro | Poca justificación |
| Más de 120 campos | Pocos datos |
| Navegación GPS | Solo información |
| Enfoque en seguridad | Sin mencionar seguridad |

---

## 🎯 Consejos para la solicitud

1. **Justifica la necesidad**: Explica por qué la búsqueda es esencial
2. **Menciona seguridad**: Integración con Siri, resultados limitados
3. **Muestra datos**: "120+ campos", "4 provincias"
4. **Sé profesional**: Email claro y conciso
5. **Ten paciencia**: Apple revisa manualmente cada solicitud

---

## 🔄 Alternativas (mientras esperas aprobación)

1. **✅ Lista alfabética con índice A-Z** (actualmente implementado)
2. **✅ Agrupación por provincia** (puede causar crashes si hay muchos items)
3. **✅ Campos cercanos basados en ubicación** (ya implementado)
4. **✅ Paginación** (ya implementado)

---

## 📚 Referencias

- [CarPlay Programming Guide](https://developer.apple.com/carplay/documentation/CarPlay-App-Programming-Guide.pdf)
- [CPSearchTemplate Documentation](https://developer.apple.com/documentation/carplay/cpsearchtemplate)
- [Requesting Entitlements](https://developer.apple.com/contact/request/carplay/)

---

## ✅ Resumen

1. **NO puedes** usar `CPSearchTemplate` sin aprobación de Apple
2. **Debes solicitar** el entitlement `com.apple.developer.carplay-search`
3. **Espera 2-6 semanas** para la respuesta
4. **Mientras tanto**, usa la implementación actual (lista completa con paginación)
5. **Una vez aprobado**, añade el código de búsqueda

---

**Creado por Claude Code**
Fecha: 27 de febrero de 2026
Session: https://claude.ai/code/session_01E6nDCGtKPqkHDburytmE9n
