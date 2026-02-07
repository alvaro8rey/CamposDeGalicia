# 🚗 CarPlay en Simulador con Personal Team

## ✅ Configuración Actual

Tu proyecto está configurado para **usar CarPlay en el simulador** sin necesitar una cuenta de pago de Apple Developer.

### ¿Qué funciona?
- ✅ CarPlay en simulador de iOS
- ✅ Mapa interactivo con campos cercanos
- ✅ Búsqueda de campos
- ✅ Navegación a campos
- ✅ Auto check-in desde CarPlay

### ⚠️ Limitaciones con Personal Team
- ❌ NO funciona en dispositivos físicos (necesitas Apple Developer Program)
- ✅ SÍ funciona perfectamente en simulador

## 🎮 Cómo Probar CarPlay en el Simulador

### Opción 1: Menú I/O (Más Fácil)

1. **Compila y ejecuta** la app en cualquier simulador de iPhone (⌘ + R)

2. **Con el simulador abierto**, ve al menú:
   ```
   I/O → External Displays → CarPlay
   ```

3. Se abrirá una **ventana nueva** que simula la pantalla de CarPlay

4. Tu app debería aparecer automáticamente en CarPlay mostrando el mapa

### Opción 2: Menú Hardware (Alternativa)

1. Ejecuta la app en el simulador

2. Ve a:
   ```
   Hardware → External Displays → CarPlay
   ```

### Opción 3: Atajo de Teclado

Con el simulador en foco:
```
⌘ + Shift + 2
```

## 🔍 Verificar que Funciona

### En la Consola de Xcode deberías ver:

```
========== CARPLAY CONECTADO ==========
🚗 CarPlay conectado
========== CARPLAY MANAGER INIT ==========
========== SETUP INTERFACE CARPLAY ==========
🚗 Configurando interfaz de CarPlay
========== TEMPLATE DE CARPLAY ESTABLECIDO CORRECTAMENTE ==========
✅ Template de CarPlay establecido correctamente
```

### En la Ventana de CarPlay deberías ver:

- Un mapa ocupando toda la pantalla
- Botones en la esquina inferior derecha:
  - Lista de campos cercanos
  - Centrar en mi ubicación
- Botón "Buscar" en la esquina superior izquierda

## 🎯 Características Disponibles

### 1. Ver Campos Cercanos
- Los primeros 10 campos más cercanos aparecen como pins en el mapa
- Toca un pin para ver detalles del campo

### 2. Lista de Campos
- Toca el botón de lista (inferior derecho) para ver todos los campos cercanos en formato lista
- Toca un campo para ver detalles y navegar

### 3. Búsqueda
- Toca "Buscar" en la esquina superior izquierda
- Busca campos por nombre o ciudad
- Los resultados se actualizan en tiempo real

### 4. Navegación
- Desde los detalles de un campo, toca "Navegar"
- Se abrirá Apple Maps con la ruta al campo

### 5. Auto Check-in
- Si llegas cerca de un campo, el check-in se hace automáticamente
- Recibirás una notificación en CarPlay

## 🐛 Solución de Problemas

### CarPlay no aparece
- Verifica que compiló sin errores
- Cierra y vuelve a abrir el simulador
- Prueba con diferentes simuladores (iPhone 14, 15, etc.)

### "No se puede conectar a CarPlay"
- Verifica que tienes los archivos:
  - `Campos de Galicia/CarPlay/CarPlaySceneDelegate.swift`
  - `Campos de Galicia/CarPlay/CarPlayManager.swift`
- Verifica que están incluidos en el target en Xcode

### Error de "entitlement"
- Si ves errores sobre entitlements al compilar:
  - Los archivos `.entitlements` NO deben tener el entitlement de CarPlay
  - Solo el `Info.plist` debe tener la configuración de escenas
  - Esto es intencional para funcionar con Personal Team

### No aparecen campos en el mapa
- Verifica que la app tiene permisos de ubicación
- En el simulador, simula una ubicación:
  ```
  Features → Location → Custom Location
  ```
  Ingresa coordenadas de Galicia, por ejemplo:
  - Latitude: 42.8782
  - Longitude: -8.5448

## 📱 Probar en Dispositivo Real (Cuando Pagues)

Cuando actualices a Apple Developer Program ($99/año):

1. **Actualiza los Entitlements**:
   - Agrega al archivo `Campos de Galicia.Debug.entitlements`:
   ```xml
   <key>com.apple.developer.carplay-navigation</key>
   <true/>
   ```

2. **Configura en el Developer Portal**:
   - Ve a developer.apple.com
   - Certificates, Identifiers & Profiles
   - Identifiers → Tu App ID
   - Habilita "CarPlay" capability

3. **Conecta tu iPhone al auto**:
   - Conecta vía USB o Bluetooth
   - La app aparecerá automáticamente en CarPlay

## 🎉 Siguiente Paso

Ahora puedes:
1. Probar todas las funciones en el simulador
2. Hacer cambios y ver cómo se ven en CarPlay
3. Prepararte para cuando tengas la cuenta de pago

¡CarPlay está listo para desarrollo! 🚀
