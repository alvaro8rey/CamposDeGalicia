# Guía para Probar Navegación en Simulador

## 📍 Archivos GPX Creados

He creado dos archivos GPX en la raíz del proyecto:

1. **GaliciaRoute.gpx** - Simula un recorrido en movimiento desde Santiago de Compostela
2. **GaliciaStatic.gpx** - Ubicación estática en Santiago de Compostela

## 🔧 Cómo Agregar los Archivos GPX a Xcode

### Paso 1: Agregar al Proyecto
1. Abre Xcode
2. Arrastra los archivos `GaliciaRoute.gpx` y `GaliciaStatic.gpx` desde Finder al navegador de proyectos de Xcode
3. Cuando aparezca el diálogo:
   - ✅ Marca "Copy items if needed"
   - ✅ Marca "Add to targets: Campos de Galicia"
   - Haz clic en "Finish"

### Paso 2: Usar los Archivos GPX

#### Opción A: Durante la Ejecución (Recomendado para testing)
1. Ejecuta la app en el simulador (⌘R)
2. En Xcode, ve al menú: **Debug → Simulate Location**
3. Verás tus archivos GPX al final de la lista:
   - **GaliciaRoute** - Para simular movimiento
   - **GaliciaStatic** - Para ubicación fija

#### Opción B: Configurar en el Esquema (Ubicación Inicial)
1. En Xcode, ve a **Product → Scheme → Edit Scheme...** (⌘<)
2. Selecciona **Run** en la barra lateral
3. Ve a la pestaña **Options**
4. En "Core Location", cambia:
   - **Default Location** → Selecciona **GaliciaStatic**
5. Haz clic en "Close"

Ahora cada vez que ejecutes la app, comenzará en Santiago de Compostela.

## 🧪 Cómo Probar la Navegación

### Test 1: Navegación Básica
1. Ejecuta la app en el simulador
2. Usa **GaliciaStatic** como ubicación inicial
3. En el mapa, busca un campo cercano a Santiago
4. Pulsa "Cómo llegar" → "Ir"
5. Cambia a **GaliciaRoute** desde Debug → Simulate Location
6. **Observa**:
   - Las indicaciones deben actualizarse cada 15 segundos
   - La distancia debe disminuir
   - El paso actual debe cambiar automáticamente

### Test 2: Recalculación de Ruta
1. Inicia navegación hacia un campo
2. Espera a que comiencen las indicaciones
3. En Xcode, ve a **Debug → Simulate Location → Custom Location**
4. Ingresa coordenadas que estén fuera de la ruta (ej: 42.90, -8.50)
5. **Observa**:
   - Después de 5 segundos, debe recalcular la ruta
   - Verás en consola: "✅ Ruta recalculada"
   - El paso debe volver a 0

### Test 3: Avance de Pasos
1. Inicia navegación
2. Usa **GaliciaRoute** para movimiento continuo
3. **Observa**:
   - Los pasos deben avanzar automáticamente
   - La distancia debe actualizarse en tiempo real
   - El indicador muestra "X/Y pasos"

## 📊 Mensajes de Consola a Observar

- `✅ Ruta calculada - Distancia: X km, Pasos: Y` - Primera vez que se calcula la ruta
- `✅ Ruta recalculada - Distancia: X km, Pasos: Y` - Cuando te desvías y se recalcula
- `⚠️ No se pudo obtener la ubicación del usuario` - GPS no disponible
- `❌ Error calculando ruta: ...` - Error en la API de mapas

## 🎯 Coordenadas Útiles en Galicia

Si quieres crear ubicaciones personalizadas:

- **Santiago de Compostela**: 42.8782, -8.5448
- **A Coruña**: 43.3623, -8.4115
- **Vigo**: 42.2406, -8.7207
- **Lugo**: 43.0097, -7.5567
- **Ourense**: 42.3360, -7.8640
- **Pontevedra**: 42.4334, -8.6443
- **Ferrol**: 43.4833, -8.2333

## 💡 Consejos

1. **Velocidad de simulación**: GaliciaRoute avanza cada 15 segundos por punto. Es lento pero preciso para testing.

2. **Crear tu propia ruta**: Puedes editar `GaliciaRoute.gpx` y agregar más puntos `<trkpt>` con tus coordenadas.

3. **Debugging**: Usa `print()` en `didUpdate userLocation` para ver cada actualización de ubicación.

4. **Resetear ubicación**: Debug → Simulate Location → None, luego selecciona tu GPX de nuevo.

## 🚨 Solución de Problemas

### El simulador no muestra mi ubicación
- Verifica permisos: Settings → Privacy → Location Services → Campos de Galicia → Always

### La ruta no se calcula
- Asegúrate de estar usando **GaliciaStatic** o coordenadas en Galicia
- Verifica la consola por errores de red

### Las indicaciones no se actualizan
- Asegúrate de haber iniciado navegación (botón "Ir")
- Verifica que `externalIsNavigating` sea `true`
- Revisa la consola para mensajes de recalculación

## 📝 Modificar la Ruta GPX

Para crear tus propias rutas:

```xml
<trkpt lat="42.XXXX" lon="-8.YYYY">
  <ele>ALTITUD</ele>
  <time>2024-01-01T10:XX:XXZ</time>
</trkpt>
```

- `lat`: Latitud (42.X para Galicia)
- `lon`: Longitud (-7.X a -9.X para Galicia)
- `ele`: Altitud en metros (opcional)
- `time`: Incrementa 15 segundos por punto para movimiento natural
