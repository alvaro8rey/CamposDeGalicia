# 🔐 Configuración de Credenciales

Este proyecto utiliza Supabase como backend. Las credenciales **NO** deben estar hardcodeadas en el código.

## ⚠️ IMPORTANTE - Seguridad

Las credenciales actuales en el código **DEBEN SER ROTADAS** antes de cualquier despliegue en producción, ya que han estado expuestas en el repositorio de git.

### Pasos para rotar credenciales:

1. Ir a tu proyecto en [Supabase Dashboard](https://app.supabase.com)
2. Settings → API → Project API keys
3. Generar nuevas API keys
4. Actualizar las credenciales usando uno de los métodos abajo

---

## 📝 Métodos de Configuración

### Opción 1: Variables de Entorno (Recomendado para producción)

```bash
# En tu terminal o en el esquema de Xcode:
export SUPABASE_URL="https://tu-proyecto.supabase.co"
export SUPABASE_KEY="tu_clave_api_publica"
```

**En Xcode:**
1. Product → Scheme → Edit Scheme
2. Run → Arguments → Environment Variables
3. Agregar:
   - `SUPABASE_URL` = `https://tu-proyecto.supabase.co`
   - `SUPABASE_KEY` = `tu_clave_api_publica`

### Opción 2: Config.plist (Recomendado para desarrollo local)

1. Crear archivo `Config.plist` en la raíz del proyecto
2. Agregar las siguientes claves:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>SUPABASE_URL</key>
    <string>https://tu-proyecto.supabase.co</string>
    <key>SUPABASE_KEY</key>
    <string>tu_clave_api_publica</string>
</dict>
</plist>
```

3. **IMPORTANTE:** Agregar `Config.plist` al `.gitignore`:

```bash
echo "Config.plist" >> .gitignore
```

### Opción 3: Valores por defecto (Solo desarrollo)

Si no configuras ninguna de las opciones anteriores, la app usará los valores por defecto **SOLO EN MODO DEBUG**.

⚠️ **Esto NO funcionará en builds de producción** y fallará con un error claro.

---

## 🔍 Verificación

La app imprimirá en la consola de dónde cargó las credenciales:

```
✅ Credenciales cargadas desde variables de entorno
```

o

```
✅ Credenciales cargadas desde Config.plist
```

o

```
⚠️ Usando credenciales por defecto (solo desarrollo)
```

---

## 📂 Estructura de Archivos

```
Campos de Galicia/
├── Config/
│   └── EnvironmentConfig.swift  ← Sistema de configuración
├── SupabaseConfig.swift          ← Cliente global de Supabase
└── Config.plist                  ← TUS CREDENCIALES (NO COMMITEAR)
```

---

## 🚫 .gitignore

Asegúrate de tener estas líneas en tu `.gitignore`:

```
# Credenciales locales
Config.plist
**/Config.plist

# Xcode
*.xcuserdata
xcuserdata/
```

---

## 🔄 CI/CD

Para pipelines de CI/CD, configura las variables de entorno en tu servicio:

- **GitHub Actions:** Repository Settings → Secrets
- **Bitrise:** Workflow → Env Vars
- **Fastlane:** Usar `dotenv` con `.env.secret`

---

## ❓ Troubleshooting

### Error: "No se encontraron credenciales de Supabase"

**Solución:** Configura las credenciales usando Opción 1 o 2 arriba.

### Error: "Credenciales de Supabase inválidas"

**Solución:** Verifica que:
- La URL comienza con `https://`
- La clave tiene más de 50 caracteres
- No hay espacios extra al inicio/final

### La app funciona en debug pero falla en release

**Solución:** En builds de release, DEBES configurar variables de entorno o Config.plist. Los valores por defecto solo funcionan en debug.

---

## 📞 Soporte

Si tienes problemas, revisa:
1. `EnvironmentConfig.swift` - Sistema de configuración
2. Console de Xcode - Mensajes de logging
3. Supabase Dashboard - Estado de las API keys
