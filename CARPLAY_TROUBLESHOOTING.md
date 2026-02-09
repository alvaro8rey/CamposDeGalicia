# Solución: CarPlay no aparece en Add Capabilities

## Problema
CarPlay no aparece en la lista de capabilities en Xcode cuando intentas agregarlo.

## 🚨 SOLUCIÓN RÁPIDA para Cuenta Free

**Si tienes una cuenta free y no puedes compilar**, el entitlement de CarPlay ya ha sido **deshabilitado temporalmente**.

### ¿Qué hacer ahora?

1. **Abre el proyecto en Xcode**
2. **Selecciona tu Personal Team en Signing & Capabilities**
3. **Compila normalmente** - debería funcionar sin errores
4. **Cuando tengas Apple Developer Program**, lee `CARPLAY_ENABLE_WHEN_READY.md` para habilitar CarPlay

**La app funcionará perfectamente sin CarPlay** hasta que actualices tu cuenta.

---

## Causas Comunes y Soluciones

### 1. ✅ Verificar que tienes Apple Developer Program

**El problema más común:**
- CarPlay NO está disponible para cuentas personales/free
- NECESITAS una cuenta de pago del Apple Developer Program ($99/año)

**Verificar:**
1. Ve a Xcode → Settings → Accounts
2. Verifica que tu cuenta muestre "Apple Developer Program"
3. Si dice "Personal Team" o "Free", no tendrás acceso a CarPlay

**Solución:**
- Inscríbete en el Apple Developer Program en https://developer.apple.com/programs/

---

### 2. 🔐 Habilitar CarPlay en el Portal de Desarrollador

Incluso con una cuenta de pago, debes habilitar CarPlay manualmente:

#### Paso a Paso:

1. **Ve al portal de desarrollador:**
   - Abre https://developer.apple.com/account
   - Inicia sesión con tu cuenta

2. **Ve a Certificates, Identifiers & Profiles:**
   - Click en "Certificates, Identifiers & Profiles"
   - Click en "Identifiers"

3. **Selecciona tu App ID:**
   - Busca el Bundle ID de tu app (ej: `com.tucompania.camposdegalicia`)
   - Click en él para editarlo

4. **Habilita CarPlay:**
   - Busca en la lista de capabilities "CarPlay"
   - Marca la casilla junto a "CarPlay"
   - Selecciona el tipo: **"App integrates CarPlay audio or communication features"** o **"App integrates CarPlay navigation"** (este último para tu app)

5. **Guarda los cambios:**
   - Click en "Save"
   - Confirma los cambios

6. **Vuelve a Xcode:**
   - Cierra y reabre Xcode
   - Ve a tu proyecto → Signing & Capabilities
   - Ahora debería aparecer CarPlay en "+ Capability"

---

### 3. 🔄 Sincronizar Xcode con el Portal

A veces Xcode no se sincroniza automáticamente:

**Método 1: Descargar perfiles manualmente**
```
Xcode → Settings → Accounts → [Tu cuenta] → Download Manual Profiles
```

**Método 2: Limpiar y regenerar perfiles**
1. Ve a Xcode → Settings → Accounts
2. Selecciona tu cuenta
3. Click en "Download Manual Profiles"
4. En tu proyecto, ve a Signing & Capabilities
5. Desmarca "Automatically manage signing"
6. Vuelve a marcar "Automatically manage signing"

---

### 4. 📝 Añadir CarPlay Manualmente (Si sigue sin aparecer)

Si CarPlay sigue sin aparecer en la UI, puedes agregarlo manualmente:

#### Opción A: Editar el archivo .entitlements directamente

Ya lo tienes configurado en:
```
Campos de Galicia/Campos de Galicia.entitlements
```

Contenido actual:
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

#### Opción B: Editar el archivo del proyecto (.xcodeproj)

Xcode debería detectar el entitlement automáticamente si:
1. El archivo .entitlements está en el proyecto
2. El Build Setting "CODE_SIGN_ENTITLEMENTS" apunta a él
3. El Bundle ID coincide con el del portal

---

### 5. 🎯 Verificar Configuración del Proyecto

#### Comprobar Build Settings:

1. Abre tu proyecto en Xcode
2. Selecciona el target "Campos de Galicia"
3. Ve a "Build Settings"
4. Busca "Code Signing Entitlements"
5. Debe mostrar: `Campos de Galicia/Campos de Galicia.entitlements`

#### Comprobar que el archivo está incluido:

1. En el navegador de archivos, selecciona `Campos de Galicia.entitlements`
2. En el inspector de archivos (panel derecho), verifica:
   - Target Membership: debe estar marcado tu target principal

---

### 6. 🔧 Solución de Problemas Adicionales

#### Problema: "Signing certificate not found"
- Genera o descarga un certificado de desarrollo/distribución desde el portal
- Xcode → Settings → Accounts → Manage Certificates

#### Problema: "Provisioning profile doesn't include the CarPlay entitlement"
- Elimina el provisioning profile:
  ```bash
  rm -rf ~/Library/MobileDevice/Provisioning\ Profiles/*
  ```
- Descarga nuevos perfiles desde Xcode → Settings → Accounts

#### Problema: Xcode muestra error al compilar
- Asegúrate de que el entitlement en el portal coincide con el del archivo .entitlements
- Para navegación debe ser: `com.apple.developer.carplay-navigation`

---

## ✅ Verificación Final

Para verificar que CarPlay está correctamente configurado:

### En Xcode:
1. Abre tu proyecto
2. Selecciona el target
3. Ve a "Signing & Capabilities"
4. Deberías ver una sección "CarPlay" (puede mostrar un warning en desarrollo, es normal)

### En el Build:
1. Compila el proyecto
2. No debe haber errores de entitlements
3. El archivo `Campos de Galicia.app/embedded.mobileprovision` debe incluir CarPlay

### Para probar:
- Usa el simulador de iOS (I/O → External Displays → CarPlay)
- O conecta un dispositivo con soporte CarPlay real

---

## 📞 Si Nada Funciona

Si después de todos estos pasos CarPlay aún no aparece:

1. **Verifica tu membresía:**
   - https://developer.apple.com/account/#!/membership/
   - Debe decir "Active" y "Apple Developer Program"

2. **Contacta a Apple Developer Support:**
   - Si tienes una cuenta de pago, tienes soporte incluido
   - Explica que CarPlay no aparece en capabilities

3. **Alternativa temporal:**
   - Sigue usando el archivo .entitlements como está
   - La configuración manual funciona perfectamente
   - No necesitas que aparezca en la UI de Xcode si el entitlement está en el archivo

---

## 🎉 Tu Configuración Actual

**Buenas noticias:** Tu proyecto YA TIENE CarPlay configurado correctamente:

- ✅ Archivo .entitlements con `com.apple.developer.carplay-navigation`
- ✅ Info.plist con configuración de escenas
- ✅ CarPlaySceneDelegate implementado
- ✅ CarPlayManager con funcionalidad completa

**Si la app compila y funciona sin errores, no necesitas que aparezca en "Add Capabilities".** El entitlement ya está agregado manualmente y eso es suficiente.

---

## 🚀 Siguiente Paso

Una vez configurado CarPlay:
1. Lee `CARPLAY_SETUP.md` para instrucciones de uso
2. Prueba en el simulador con Cmd+Shift+2 (I/O → External Displays → CarPlay)
3. Verifica que la app funciona correctamente en modo CarPlay
