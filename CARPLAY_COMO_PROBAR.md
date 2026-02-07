# Cómo Probar CarPlay en el Simulador

## ✅ Estado Actual de la Configuración

La app YA está completamente configurada para CarPlay:

- ✅ Entitlements configurados (`com.apple.developer.carplay-navigation`)
- ✅ Info.plist con escena de CarPlay
- ✅ AppDelegate maneja conexión de CarPlay
- ✅ CarPlaySceneDelegate implementado
- ✅ CarPlayManager con interfaz completa

## 🧪 Pasos para Probar en Simulador

### 1. Limpiar y Recompilar

**IMPORTANTE**: Después de agregar entitlements, DEBES limpiar y recompilar:

```bash
# En Xcode:
1. Product → Clean Build Folder (Cmd+Shift+K)
2. Product → Build (Cmd+B)
```

### 2. Ejecutar la App

1. Selecciona un simulador de iPhone (iOS 14+)
2. Ejecuta la app (Cmd+R)
3. Espera a que la app se lance completamente

### 3. Abrir CarPlay

Hay DOS formas de abrir CarPlay en el simulador:

**Opción A - Menú I/O:**
```
I/O → External Displays → CarPlay
```

**Opción B - Atajo de Teclado:**
```
Shift + Cmd + C
```

### 4. Verificar que Funciona

Deberías ver en la **consola de Xcode**:

```
========================================
🔧 CONFIGURANDO ESCENA
Role: CPTemplateApplicationSceneSessionRoleApplication
========================================

========================================
🚗🚗🚗 CARPLAY DETECTADO! 🚗🚗🚗
========================================

========================================
🚗🚗🚗 CARPLAY CONECTADO! 🚗🚗🚗
========================================

========== CARPLAY MANAGER INIT ==========
========== SETUP INTERFACE CARPLAY ==========
========== TEMPLATE DE CARPLAY ESTABLECIDO CORRECTAMENTE ==========
```

Y en la **ventana de CarPlay** deberías ver:
- Un mapa
- Botones en la parte inferior derecha (lista y ubicación)
- Botón "Buscar" en la barra superior

## 🐛 Si NO Funciona

### Problema 1: La ventana de CarPlay se abre pero está vacía

**Síntomas:**
- La ventana de CarPlay aparece pero está en blanco
- No ves logs de "CARPLAY CONECTADO" en la consola

**Solución:**
1. Cierra el simulador completamente (Cmd+Q)
2. En Xcode: Product → Clean Build Folder (Cmd+Shift+K)
3. Elimina la app del simulador:
   - Abre el simulador
   - Mantén presionado el icono de la app
   - Elimínala
4. Recompila (Cmd+B)
5. Ejecuta de nuevo (Cmd+R)
6. Abre CarPlay (Shift+Cmd+C)

### Problema 2: No aparece ninguna ventana de CarPlay

**Síntomas:**
- Al seleccionar I/O → CarPlay no pasa nada

**Solución:**
1. Verifica que estés usando un simulador compatible (iOS 14+)
2. Reinicia el simulador
3. Intenta con un modelo diferente de simulador

### Problema 3: Error de "No apps with CarPlay support"

**Síntomas:**
- Mensaje en el simulador que dice que no hay apps con soporte CarPlay

**Solución:**
1. Los entitlements NO se aplicaron correctamente
2. Verifica que estos archivos existan y contengan el entitlement:
   - `Campos de Galicia/Campos de Galicia.Debug.entitlements`
   - `Campos de Galicia/Campos de Galicia.Release.entitlements`
3. Ambos deben tener:
```xml
<key>com.apple.developer.carplay-navigation</key>
<true/>
```

## 📱 Funcionalidad Disponible

Una vez que CarPlay esté funcionando, podrás:

1. **Ver mapa** con campos de fútbol cercanos
2. **Botón de lista** (icono de lista): Muestra los 10 campos más cercanos
3. **Botón de ubicación** (icono de ubicación): Centra el mapa en tu ubicación
4. **Búsqueda**: Busca campos por nombre o localidad
5. **Navegación**: Toca un campo para iniciar navegación en Apple Maps

## 🔍 Logs de Diagnóstico

Los logs están diseñados para ser MUY visibles. Busca en la consola de Xcode:

- `========== CARPLAY` - Eventos importantes de CarPlay
- `🚗` - Logs relacionados con CarPlay
- `📍` - Logs de ubicación
- `❌` - Errores

## ⚠️ Limitaciones del Simulador

- El mapa puede no mostrarse correctamente (es una limitación del simulador)
- La ubicación puede ser fija (puedes cambiarla en: Debug → Location)
- Algunas interacciones táctiles pueden comportarse diferente que en CarPlay real
- Para probar en un auto real, necesitarás Apple Developer Program ($99/año)

## 📞 Necesitas Ayuda?

Si después de seguir estos pasos aún no funciona:

1. Verifica la consola de Xcode para mensajes de error
2. Comparte los logs que aparecen (o la ausencia de ellos)
3. Indica exactamente en qué paso estás teniendo problemas
