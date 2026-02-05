# 📊 Guía de Firebase Analytics - Campos de Galicia

## 🎯 Acceso a Firebase Analytics

### 1. Acceder a Firebase Console
1. Ve a https://console.firebase.google.com/
2. Selecciona tu proyecto **"CamposDeGalicia"**
3. En el menú lateral, haz clic en **"Analytics"**

### 2. Modo Debug (DESARROLLO)
Para ver eventos en tiempo real mientras desarrollas:

#### Opción A: Desde Xcode
```bash
# En el esquema de tu app en Xcode, añade este argumento:
-FIRDebugEnabled
```

#### Opción B: Desde Terminal
```bash
# Después de instalar la app en tu dispositivo/simulador:
adb shell setprop debug.firebase.analytics.app com.tuapp.bundleid

# Para iOS con dispositivo físico:
# Los eventos ya se están enviando con debug_mode habilitado en el código
```

Con el modo debug habilitado, verás eventos **INSTANTÁNEAMENTE** en Firebase Console > DebugView

---

## 📈 Paneles de Firebase Analytics

### 1. 🔍 DebugView (Desarrollo)
**Ubicación:** Analytics > DebugView

**¿Qué verás?**
- Eventos en tiempo real (segundos)
- Parámetros completos de cada evento
- Ideal para verificar que los eventos se están enviando correctamente

**Cómo usarlo:**
1. Ejecuta tu app en modo debug
2. Ve a DebugView en Firebase Console
3. Interactúa con la app
4. Verás los eventos aparecer inmediatamente

---

### 2. 🎯 Dashboard (Vista General)
**Ubicación:** Analytics > Dashboard

**¿Qué verás?**
- Usuarios activos (última hora, día, semana, mes)
- Nuevos usuarios
- Eventos principales
- Retención de usuarios
- Ingresos (si aplica)

**Métricas clave:**
- **Usuarios activos diarios (DAU)**: Cuántos usuarios únicos usan la app cada día
- **Tasa de retención**: % de usuarios que vuelven a usar la app
- **Sesiones promedio**: Cuántas veces abren la app tus usuarios

**Tiempo de actualización:** 24-48 horas

---

### 3. 🎪 Events (Eventos)
**Ubicación:** Analytics > Events

**¿Qué verás?**
Lista de TODOS los eventos que se están registrando en tu app, con:
- Nombre del evento
- Conteo total
- Usuarios únicos que lo activaron
- Valor por usuario

#### Eventos que verás en tu app:

##### 📱 **Eventos de Aplicación**
- `app_open` - Usuario abre la app
- `app_foregrounded` - App vuelve al primer plano
- `app_backgrounded` - App va a segundo plano
- `first_open` - Primera vez que el usuario abre la app

##### 👤 **Eventos de Usuario**
- `login` - Usuario inicia sesión
- `logout` - Usuario cierra sesión
- `register` - Nuevo registro
- `profile_update` - Actualización de perfil

##### 🏕️ **Eventos de Campos** (LO MÁS IMPORTANTE)
- `campo_viewed` - Usuario ve detalles de un campo
  - Parámetros: `campo_id`, `campo_name`
- `campo_visited` - Usuario visita un campo (check-in)
  - Parámetros: `campo_id`, `campo_name`, `method` (manual/auto)
- `campo_favorite_toggled` - Usuario marca/desmarca favorito
- `campo_shared` - Usuario comparte un campo
- `campo_contribution_added` - Usuario añade una contribución

##### 🔍 **Eventos de Búsqueda y Filtros**
- `search` - Usuario realiza una búsqueda
  - Parámetros: `search_term`, `results_count`
- `filter_applied` - Usuario aplica un filtro
  - Parámetros: `filter_type`, `filter_value`
- `sort_changed` - Usuario cambia el orden de la lista

##### 🏆 **Eventos de Logros**
- `achievement_unlocked` - Desbloqueo de logro
  - Parámetros: `achievement_id`, `achievement_name`, `xp`
- `level_up` - Subida de nivel
  - Parámetros: `new_level`, `total_xp`
- `daily_reward_claimed` - Recompensa diaria reclamada

##### 🧭 **Eventos de Navegación**
- `screen_view` - Vista de pantalla
  - Parámetros: `screen_name` (home, map, nearby, profile)
- `tab_changed` - Cambio de pestaña
  - Parámetros: `tab_name`
- `button_click` - Click en botón
  - Parámetros: `button_name`, `screen_name`

##### 🗺️ **Eventos de Mapa**
- `map_interaction` - Interacción con el mapa
  - Parámetros: `action` (zoom, pan, marker_tap)

##### ⚙️ **Eventos de Configuración**
- `theme_changed` - Cambio de tema
  - Parámetros: `theme`
- `language_changed` - Cambio de idioma
  - Parámetros: `language`
- `setting_changed` - Cambio de configuración
- `notifications_toggled` - Activación/desactivación de notificaciones

---

### 4. ⏱️ Realtime (Tiempo Real)
**Ubicación:** Analytics > Realtime

**¿Qué verás?**
- Usuarios activos AHORA MISMO
- Eventos disparándose en los últimos 30 minutos
- Pantallas que están viendo
- Ubicación geográfica de usuarios

**Tiempo de actualización:** 1-5 minutos

---

### 5. 📊 Audiences (Audiencias)
**Ubicación:** Analytics > Audiences

**¿Qué puedes hacer?**
Crear segmentos de usuarios basados en:
- Usuarios que han visitado más de 10 campos
- Usuarios que no han visitado campos en 7 días
- Usuarios que usan la búsqueda frecuentemente
- Usuarios que tienen logros desbloqueados

**Ejemplo práctico:**
```
Audiencia: "Usuarios Activos"
Condiciones:
- Ha visitado al menos 5 campos
- Ha usado la app en los últimos 7 días
- Ha desbloqueado al menos 1 logro
```

---

### 6. 🔄 Conversions (Conversiones)
**Ubicación:** Analytics > Conversions

**¿Qué verás?**
Eventos marcados como "conversiones" (objetivos clave):

**Sugerencias de conversiones para tu app:**
- `campo_visited` - Objetivo principal: que visiten campos
- `achievement_unlocked` - Engagement: usuarios activos
- `campo_contribution_added` - Contribución: usuarios que aportan contenido
- `login` - Retención: usuarios que vuelven

Para marcar un evento como conversión:
1. Ve a Analytics > Events
2. Encuentra el evento
3. Haz clic en "Mark as conversion"

---

## 🎯 Casos de Uso Prácticos

### Caso 1: ¿Cuántos usuarios visitaron campos esta semana?
1. Ve a **Analytics > Events**
2. Busca el evento `campo_visited`
3. Verás el conteo total y usuarios únicos
4. Puedes filtrar por fechas en la parte superior

### Caso 2: ¿Qué campos son los más populares?
1. Ve a **Analytics > Events**
2. Click en el evento `campo_viewed`
3. Ve a la pestaña "Parameters"
4. Ordena por `campo_name` o `campo_id`
5. Verás qué campos se ven más

### Caso 3: ¿Qué están buscando los usuarios?
1. Ve a **Analytics > Events**
2. Click en el evento `search`
3. Ve a "Parameters"
4. Mira los valores de `search_term`
5. Identifica patrones en las búsquedas

### Caso 4: ¿Cuántos usuarios usan el check-in automático vs manual?
1. Ve a **Analytics > Events**
2. Click en `campo_visited`
3. Ve a "Parameters"
4. Filtra por `method` = "auto" vs "manual"

### Caso 5: ¿Qué pantallas son las más visitadas?
1. Ve a **Analytics > Events**
2. Click en `screen_view`
3. Ve a "Parameters"
4. Mira `screen_name` más frecuentes

### Caso 6: ¿Cuántos usuarios están activos ahora mismo?
1. Ve a **Analytics > Realtime**
2. Verás usuarios activos en tiempo real
3. Puedes ver qué están haciendo exactamente

---

## 🎨 Gráficos y Reportes Personalizados

### Crear un reporte personalizado:
1. Ve a **Analytics > Custom Analysis**
2. Haz click en "Create New Analysis"
3. Elige el tipo de análisis:
   - **Funnel Analysis**: Ver el camino del usuario (Ej: abrir app → buscar campo → ver campo → visitar campo)
   - **Path Analysis**: Ver cómo navegan los usuarios
   - **Segment Overlap**: Comparar segmentos de usuarios
   - **Cohort Analysis**: Retención de usuarios por cohorte

**Ejemplo de Funnel:**
```
Nombre: "Conversión a Visita"
Pasos:
1. app_open
2. search
3. campo_viewed
4. campo_visited

Esto te mostrará:
- 100% abren la app
- 60% buscan campos
- 40% ven detalles
- 15% visitan físicamente
```

---

## 📱 BigQuery (Análisis Avanzado)

Si necesitas análisis más profundos:

1. Ve a **Project Settings > Integrations**
2. Habilita **BigQuery**
3. Todos tus eventos se exportarán a BigQuery automáticamente
4. Podrás hacer queries SQL complejas

**Ejemplo de query:**
```sql
SELECT
  event_name,
  COUNT(*) as event_count,
  COUNT(DISTINCT user_pseudo_id) as unique_users
FROM `your-project.analytics_XXXXX.events_*`
WHERE event_name = 'campo_visited'
  AND _TABLE_SUFFIX BETWEEN '20240101' AND '20241231'
GROUP BY event_name
ORDER BY event_count DESC
```

---

## 🚨 Troubleshooting

### "No veo eventos en DebugView"
1. ✅ Verifica que tienes `-FIRDebugEnabled` en los argumentos de Xcode
2. ✅ Asegúrate de que estás en el dispositivo/simulador correcto
3. ✅ Espera hasta 30 segundos (puede haber delay)
4. ✅ Verifica que Firebase está inicializado (checa los logs)

### "Los eventos tardan mucho en aparecer"
- **DebugView**: Debe ser instantáneo (segundos)
- **Realtime**: 1-5 minutos
- **Dashboard/Events**: 24-48 horas

### "No veo parámetros de eventos"
1. Ve a Analytics > Events
2. Click en el evento específico
3. Ve a la pestaña "Parameters"
4. Si no ves parámetros, espera 24-48 horas (procesamiento inicial)

---

## 🎓 Mejores Prácticas

### 1. Usa DebugView durante desarrollo
- Verifica que todos los eventos se disparen correctamente
- Comprueba que los parámetros sean correctos
- Detecta errores antes de producción

### 2. Marca conversiones clave
- `campo_visited` - Tu objetivo principal
- `achievement_unlocked` - Engagement
- `campo_contribution_added` - Contribución de usuarios

### 3. Crea audiencias útiles
- Usuarios activos (han usado la app en 7 días)
- Usuarios inactivos (no han usado en 30 días)
- Power users (más de 20 campos visitados)

### 4. Revisa reportes regularmente
- **Diario**: Realtime para ver actividad actual
- **Semanal**: Events y Dashboard para tendencias
- **Mensual**: Audiences y Conversions para optimización

### 5. Analiza el embudo de conversión
1. Usuarios que abren la app
2. Usuarios que buscan/filtran
3. Usuarios que ven campos
4. Usuarios que visitan campos físicamente

---

## 📊 KPIs Recomendados

Para tu app "Campos de Galicia", estos son los KPIs más importantes:

### Engagement
- **DAU (Daily Active Users)**: Usuarios únicos por día
- **MAU (Monthly Active Users)**: Usuarios únicos por mes
- **DAU/MAU Ratio**: Indica qué tan "pegajosa" es tu app (ideal >20%)

### Conversión
- **Campos visitados por usuario**: Promedio de check-ins
- **Tasa de conversión búsqueda → visita**: % de búsquedas que terminan en visita
- **Tiempo promedio en la app**: Engagement por sesión

### Retención
- **Day 1 Retention**: % usuarios que vuelven al día siguiente
- **Day 7 Retention**: % usuarios que vuelven a los 7 días
- **Day 30 Retention**: % usuarios que vuelven a los 30 días

### Contenido
- **Campos más populares**: Top 10 campos por vistas
- **Búsquedas populares**: Términos más buscados
- **Contribuciones por usuario**: Usuarios que aportan contenido

---

## 🎯 Próximos Pasos

1. **Habilita DebugView** y verifica que los eventos se envíen correctamente
2. **Espera 24-48 horas** para que se procesen los primeros datos históricos
3. **Marca conversiones clave**: `campo_visited`, `achievement_unlocked`
4. **Crea tu primera audiencia**: "Usuarios Activos"
5. **Configura un funnel analysis**: App Open → Campo Viewed → Campo Visited
6. **Revisa semanalmente** tus métricas clave

---

## 📚 Recursos Adicionales

- [Documentación oficial de Firebase Analytics](https://firebase.google.com/docs/analytics)
- [Guía de eventos recomendados](https://support.google.com/analytics/answer/9267735)
- [BigQuery para Firebase](https://firebase.google.com/docs/projects/bigquery-export)

---

**¡Listo! Ahora puedes ver todas las estadísticas de tu app en Firebase Analytics.**

¿Necesitas ayuda con algo específico? Abre un issue en el repositorio.
