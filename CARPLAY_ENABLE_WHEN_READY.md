# Habilitar CarPlay cuando tengas Apple Developer Program

## Estado Actual
CarPlay está **DESHABILITADO temporalmente** porque estás usando una cuenta free de Apple Developer.

## ¿Qué significa esto?
- ✅ La app compila y funciona perfectamente sin CarPlay
- ✅ Todo el código de CarPlay está implementado y listo
- ❌ CarPlay NO funcionará hasta que tengas una cuenta de pago ($99/año)

## Cuando Tengas Apple Developer Program

### Paso 1: Descomenta el Entitlement

Edita el archivo: `Campos de Galicia/Campos de Galicia.entitlements`

**Cambia de:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<!-- CarPlay entitlement comentado temporalmente para cuenta free -->
	<!-- Descomentar cuando tengas Apple Developer Program -->
	<!--
	<key>com.apple.developer.carplay-navigation</key>
	<true/>
	-->
</dict>
</plist>
```

**A:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.carplay-navigation</key>
	<true/>
</dict>
</plist>
```

### Paso 2: Configura en el Portal de Desarrollador

1. Ve a https://developer.apple.com/account
2. Certificates, Identifiers & Profiles → Identifiers
3. Selecciona tu Bundle ID
4. Marca "CarPlay"
5. Selecciona tipo: **"App integrates CarPlay navigation"**
6. Guarda cambios

### Paso 3: En Xcode

1. Xcode → Settings → Accounts → Download Manual Profiles
2. En tu proyecto → Signing & Capabilities
3. Verifica que aparezca "CarPlay"
4. Compila y prueba

### Paso 4: Prueba CarPlay

En el simulador:
- I/O → External Displays → CarPlay
- O usa: Cmd + Shift + 2

En dispositivo real:
- Conecta tu iPhone a un sistema CarPlay
- La app debería aparecer automáticamente

## Archivos de CarPlay Ya Implementados

Todo el código está listo:
- ✅ `CarPlay/CarPlaySceneDelegate.swift` - Gestor de sesión
- ✅ `CarPlay/CarPlayManager.swift` - Lógica completa
- ✅ `Campos-de-Galicia-Info.plist` - Configuración de escenas
- ✅ `Campos de Galicia.entitlements` - Solo necesita descomentarse

## Funcionalidades Implementadas

Cuando habilites CarPlay tendrás:
- 🗺️ Mapa interactivo con campos cercanos
- 📍 Lista de campos ordenados por distancia
- 🔍 Búsqueda por nombre y localidad
- 🧭 Navegación integrada con Apple Maps
- 📊 Analytics de uso

## Documentación

- `CARPLAY_SETUP.md` - Guía completa de uso
- `CARPLAY_TROUBLESHOOTING.md` - Solución de problemas

---

**¡Todo está listo para cuando decidas actualizar tu cuenta de desarrollador!** 🚀
