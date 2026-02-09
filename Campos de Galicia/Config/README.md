# Configuración de Credenciales

## ⚠️ IMPORTANTE: Seguridad de Credenciales

Este proyecto utiliza Supabase como backend. Las credenciales **NO** deben incluirse en el control de versiones.

## Configuración Local

### Paso 1: Copiar el archivo de ejemplo

```bash
cp "Campos de Galicia/Config/Config.plist.example" "Campos de Galicia/Config/Config.plist"
```

### Paso 2: Configurar tus credenciales

Edita el archivo `Config.plist` y reemplaza los valores placeholder:

```xml
<key>SUPABASE_URL</key>
<string>https://tu-proyecto.supabase.co</string>
<key>SUPABASE_KEY</key>
<string>tu-clave-anon-publica-aqui</string>
```

### Paso 3: Obtener tus credenciales de Supabase

1. Ve a tu proyecto en [Supabase Dashboard](https://app.supabase.com)
2. Navega a **Settings** → **API**
3. Copia:
   - **Project URL** → `SUPABASE_URL`
   - **anon public** key → `SUPABASE_KEY`

## Verificación

El archivo `Config.plist` está incluido en `.gitignore` y **no será commiteado** al repositorio.

## Fallback Automático

Si `Config.plist` no existe, la aplicación usará valores fallback definidos en `EnvironmentConfig.swift`:
- URL de desarrollo: `https://placeholder.supabase.co`
- Mostrará advertencia en logs

## Para Producción

Para builds de producción, considera usar:
- Variables de entorno en CI/CD
- Configuración desde Xcode Build Settings
- Gestión de secretos con servicios como AWS Secrets Manager o similares
