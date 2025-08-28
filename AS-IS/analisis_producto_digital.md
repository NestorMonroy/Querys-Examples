# 💻 **AS-IS: Producto Digital - Segmentación UX y Optimización**

## 🎯 **Objetivo de Negocio**
**Optimizar la experiencia del usuario identificando diferentes segmentos de comportamiento, mejorando la retención y reduciendo el churn a través de personalización de la interfaz.**

---

## 📊 **Análisis Clave para Producto Digital**

### **1. SEGMENTACIÓN DE USUARIOS POR COMPORTAMIENTO**

#### **A. Identificación de Arquetipos de Usuario**
```sql
-- ¿Qué tipos de usuarios tenemos y cómo se comportan?
WITH metricas_usuario AS (
    SELECT 
        numero_entrada,
        COUNT(DISTINCT fecha) as dias_activos,
        COUNT(*) as total_interacciones,
        COUNT(*) / COUNT(DISTINCT fecha) as interacciones_promedio_por_dia,
        AVG(TIMESTAMPDIFF(MINUTE, MIN(hora_inicio), MAX(hora_fin))) as duracion_promedio_sesion_min,
        COUNT(DISTINCT menu) as menus_unicos_explorados,
        COUNT(DISTINCT opcion) as opciones_unicas_usadas,
        
        -- Patrones de tiempo
        STDDEV(TIMESTAMPDIFF(MINUTE, MIN(hora_inicio), MAX(hora_fin))) as variabilidad_duracion,
        COUNT(DISTINCT HOUR(hora_inicio)) as variedad_horaria,
        
        -- Éxito y engagement
        MAX(CASE WHEN menu IN ('CONFIRMACION', 'EXITO', 'COMPLETADO') THEN 1 ELSE 0 END) as tuvo_exito_alguna_vez,
        COUNT(DISTINCT CONCAT(menu, ':', opcion)) as combinaciones_unicas_usadas,
        
        -- Progresión de adopción
        DATEDIFF(MAX(fecha), MIN(fecha)) + 1 as span_dias_uso,
        COUNT(DISTINCT fecha) / (DATEDIFF(MAX(fecha), MIN(fecha)) + 1) as frecuencia_uso
    FROM llamadas_Q1 
    WHERE numero_entrada = numero_digitado
    GROUP BY numero_entrada
    HAVING COUNT(DISTINCT fecha) >= 2  -- Al menos 2 días de actividad
),
segmentacion AS (
    SELECT *,
        -- Algoritmo de segmentación basado en comportamiento
        CASE 
            -- Power Users: Alta frecuencia, alta exploración, sesiones eficientes
            WHEN frecuencia_uso > 0.7 AND 
                 menus_unicos_explorados >= 5 AND 
                 duracion_promedio_sesion_min <= 8 THEN 'POWER_USER'
            
            -- Exploradores: Baja frecuencia pero alta exploración
            WHEN menus_unicos_explorados >= 4 AND 
                 opciones_unicas_usadas >= 8 AND
                 frecuencia_uso <= 0.5 THEN 'EXPLORADOR'
            
            -- Especialistas: Usan poco pero muy específico
            WHEN menus_unicos_explorados <= 2 AND 
                 interacciones_promedio_por_dia >= 3 AND
                 variabilidad_duracion <= 2 THEN 'ESPECIALISTA'
            
            -- Struggle Users: Mucho tiempo, poca eficiencia
            WHEN duracion_promedio_sesion_min > 12 AND 
                 interacciones_promedio_por_dia > 6 AND
                 tuvo_exito_alguna_vez = 0 THEN 'STRUGGLE_USER'
            
            -- Ocasionales: Poco uso, patrones inconsistentes
            WHEN frecuencia_uso <= 0.3 AND 
                 dias_activos <= 5 THEN 'OCASIONAL'
            
            -- Abandono: Actividad inicial luego nada
            WHEN span_dias_uso > 7 AND 
                 frecuencia_uso <= 0.2 THEN 'EN_RIESGO_ABANDONO'
            
            ELSE 'REGULAR'
        END as segmento_usuario
    FROM metricas_usuario
)
SELECT 
    segmento_usuario,
    COUNT(*) as cantidad_usuarios,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) as porcentaje_base_usuarios,
    
    -- Métricas promedio por segmento
    ROUND(AVG(dias_activos), 1) as promedio_dias_activos,
    ROUND(AVG(interacciones_promedio_por_dia), 1) as promedio_interacciones_dia,
    ROUND(AVG(duracion_promedio_sesion_min), 1) as promedio_duracion_sesion,
    ROUND(AVG(menus_unicos_explorados), 1) as promedio_menus_explorados,
    ROUND(AVG(frecuencia_uso), 2) as promedio_frecuencia_uso,
    
    -- Tasa de éxito por segmento
    ROUND(SUM(tuvo_exito_alguna_vez) * 100.0 / COUNT(*), 1) as tasa_exito_pct
FROM segmentacion
GROUP BY segmento_usuario
ORDER BY cantidad_usuarios DESC;
```

#### **B. Journey Patterns por Segmento**
```sql
-- ¿Cómo navegan los diferentes segmentos?
WITH usuarios_segmentados AS (
    -- Usar la misma lógica de segmentación anterior, simplificada
    SELECT 
        numero_entrada,
        CASE 
            WHEN AVG(interacciones_por_dia) <= 3 AND COUNT(DISTINCT menu) >= 4 THEN 'EXPLORADOR'
            WHEN AVG(interacciones_por_dia) >= 5 AND COUNT(DISTINCT menu) <= 2 THEN 'ESPECIALISTA'
            WHEN AVG(duracion_sesion_min) > 10 AND COUNT(DISTINCT fecha) >= 3 THEN 'STRUGGLE_USER'
            ELSE 'REGULAR'
        END as segmento
    FROM (
        SELECT 
            numero_entrada, fecha,
            COUNT(*) as interacciones_por_dia,
            TIMESTAMPDIFF(MINUTE, MIN(hora_inicio), MAX(hora_fin)) as duracion_sesion_min,
            menu
        FROM llamadas_Q1 
        WHERE numero_entrada = numero_digitado
        GROUP BY numero_entrada, fecha, menu
    ) sesiones_diarias
    GROUP BY numero_entrada
),
journeys_por_segmento AS (
    SELECT 
        us.segmento,
        GROUP_CONCAT(
            CONCAT(l.menu, ':', l.opcion) 
            ORDER BY l.hora_inicio 
            SEPARATOR ' → '
        ) as journey_pattern,
        COUNT(*) as frecuencia_journey,
        AVG(TIMESTAMPDIFF(MINUTE, MIN(l.hora_inicio), MAX(l.hora_fin))) as duracion_promedio
    FROM usuarios_segmentados us
    JOIN llamadas_Q1 l ON us.numero_entrada = l.numero_entrada
    WHERE l.numero_entrada = l.numero_digitado
    GROUP BY us.segmento, l.numero_entrada, l.fecha
    HAVING COUNT(*) > 1  -- Solo journeys multi-paso
)
SELECT 
    segmento,
    journey_pattern,
    frecuencia_journey,
    ROUND(duracion_promedio, 1) as duracion_promedio_min,
    ROUND(frecuencia_journey * 100.0 / SUM(frecuencia_journey) OVER (PARTITION BY segmento), 1) as porcentaje_dentro_segmento
FROM journeys_por_segmento
WHERE frecuencia_journey >= 2  -- Solo patrones con múltiples ocurrencias
ORDER BY segmento, frecuencia_journey DESC;
```

### **2. ANÁLISIS DE RETENCIÓN Y CHURN**

#### **A. Cohorte de Retención**
```sql
-- ¿Cómo varía la retención por semana desde primera actividad?
WITH primera_actividad AS (
    SELECT 
        numero_entrada,
        MIN(fecha) as fecha_primera_actividad,
        WEEK(MIN(fecha)) as semana_primera_actividad
    FROM llamadas_Q1 
    WHERE numero_entrada = numero_digitado
    GROUP BY numero_entrada
),
actividad_semanal AS (
    SELECT 
        l.numero_entrada,
        WEEK(l.fecha) as semana_actividad,
        COUNT(*) as interacciones_semana
    FROM llamadas_Q1 l
    WHERE l.numero_entrada = l.numero_digitado
    GROUP BY l.numero_entrada, WEEK(l.fecha)
),
cohorte_retencion AS (
    SELECT 
        pa.semana_primera_actividad as cohorte_semana,
        COUNT(DISTINCT pa.numero_entrada) as usuarios_cohorte,
        
        -- Retención semana 1 (semana siguiente a primera actividad)
        COUNT(DISTINCT CASE WHEN asem.semana_actividad = pa.semana_primera_actividad + 1 
                            THEN pa.numero_entrada END) as retenidos_semana_1,
        
        -- Retención semana 2
        COUNT(DISTINCT CASE WHEN asem.semana_actividad = pa.semana_primera_actividad + 2 
                            THEN pa.numero_entrada END) as retenidos_semana_2,
        
        -- Retención semana 3
        COUNT(DISTINCT CASE WHEN asem.semana_actividad = pa.semana_primera_actividad + 3 
                            THEN pa.numero_entrada END) as retenidos_semana_3
    FROM primera_actividad pa
    LEFT JOIN actividad_semanal asem ON pa.numero_entrada = asem.numero_entrada
    GROUP BY pa.semana_primera_actividad
    HAVING COUNT(DISTINCT pa.numero_entrada) >= 10  -- Solo cohortes con volumen significativo
)
SELECT 
    cohorte_semana,
    usuarios_cohorte,
    
    -- Tasas de retención
    ROUND(retenidos_semana_1 * 100.0 / usuarios_cohorte, 1) as retencion_semana_1_pct,
    ROUND(retenidos_semana_2 * 100.0 / usuarios_cohorte, 1) as retencion_semana_2_pct,
    ROUND(retenidos_semana_3 * 100.0 / usuarios_cohorte, 1) as retencion_semana_3_pct,
    
    -- Churn implícito
    ROUND((usuarios_cohorte - retenidos_semana_1) * 100.0 / usuarios_cohorte, 1) as churn_semana_1_pct
FROM cohorte_retencion
ORDER BY cohorte_semana;
```

#### **B. Predicción de Churn**
```sql
-- ¿Qué usuarios tienen alta probabilidad de abandonar?
WITH comportamiento_reciente AS (
    SELECT 
        numero_entrada,
        MAX(fecha) as ultima_actividad,
        COUNT(DISTINCT fecha) as dias_activos_total,
        DATEDIFF(CURDATE(), MAX(fecha)) as dias_sin_actividad,
        
        -- Métricas de las últimas 3 sesiones
        AVG(CASE WHEN rn <= 3 THEN interacciones_sesion END) as promedio_interacciones_recientes,
        AVG(CASE WHEN rn <= 3 THEN duracion_sesion_min END) as promedio_duracion_reciente,
        SUM(CASE WHEN rn <= 3 AND tuvo_exito = 1 THEN 1 ELSE 0 END) as exitos_recientes,
        
        -- Tendencia de actividad
        COUNT(DISTINCT CASE WHEN fecha >= DATE_SUB(MAX(fecha), INTERVAL 7 DAY) 
                            THEN fecha END) as dias_activos_ultima_semana
    FROM (
        SELECT 
            numero_entrada, fecha,
            COUNT(*) as interacciones_sesion,
            TIMESTAMPDIFF(MINUTE, MIN(hora_inicio), MAX(hora_fin)) as duracion_sesion_min,
            MAX(CASE WHEN menu IN ('CONFIRMACION', 'EXITO', 'COMPLETADO') THEN 1 ELSE 0 END) as tuvo_exito,
            ROW_NUMBER() OVER (PARTITION BY numero_entrada ORDER BY fecha DESC) as rn
        FROM llamadas_Q1 
        WHERE numero_entrada = numero_digitado
        GROUP BY numero_entrada, fecha
    ) sesiones_numeradas
    GROUP BY numero_entrada
    HAVING COUNT(DISTINCT fecha) >= 3  -- Al menos 3 días de historial
),
score_churn AS (
    SELECT *,
        -- Score de churn (0-100, mayor = más probabilidad de churn)
        LEAST(100, 
            (CASE WHEN dias_sin_actividad > 7 THEN 30 ELSE dias_sin_actividad * 4 END) +
            (CASE WHEN dias_activos_ultima_semana = 0 THEN 25 ELSE 0 END) +
            (CASE WHEN promedio_duracion_reciente > 15 THEN 20 ELSE 0 END) +
            (CASE WHEN exitos_recientes = 0 THEN 20 ELSE 0 END) +
            (CASE WHEN promedio_interacciones_recientes > 8 THEN 15 ELSE 0 END)
        ) as score_riesgo_churn
    FROM comportamiento_reciente
)
SELECT 
    numero_entrada,
    dias_activos_total,
    ultima_actividad,
    dias_sin_actividad,
    dias_activos_ultima_semana,
    ROUND(promedio_interacciones_recientes, 1) as interacciones_recientes_promedio,
    ROUND(promedio_duracion_reciente, 1) as duracion_reciente_promedio,
    exitos_recientes,
    score_riesgo_churn,
    
    -- Clasificación de riesgo
    CASE 
        WHEN score_riesgo_churn >= 70 THEN 'CHURN_INMINENTE'
        WHEN score_riesgo_churn >= 50 THEN 'ALTO_RIESGO'
        WHEN score_riesgo_churn >= 30 THEN 'MEDIO_RIESGO'
        ELSE 'BAJO_RIESGO'
    END as categoria_riesgo
FROM score_churn
ORDER BY score_riesgo_churn DESC
LIMIT 100;
```

### **3. ANÁLISIS DE FUNNEL Y CONVERSIÓN**

#### **A. Funnel de Conversión por Flujo Principal**
```sql
-- ¿Dónde perdemos usuarios en el funnel principal?
WITH funnel_pasos AS (
    SELECT 
        -- Definir los pasos del funnel principal (ajustar según tu producto)
        CASE 
            WHEN menu = 'INICIO' OR menu = 'LOGIN' THEN 1
            WHEN menu = 'DASHBOARD' OR menu = 'PRINCIPAL' THEN 2
            WHEN menu = 'SELECCION' OR menu = 'CATEGORIA' THEN 3
            WHEN menu = 'PROCESO' OR menu = 'FORMULARIO' THEN 4
            WHEN menu = 'CONFIRMACION' OR menu = 'EXITO' THEN 5
            ELSE 0
        END as paso_funnel,
        numero_entrada,
        fecha,
        hora_inicio
    FROM llamadas_Q1 
    WHERE numero_entrada = numero_digitado
      AND menu IS NOT NULL
),
usuarios_por_paso AS (
    SELECT 
        paso_funnel,
        COUNT(DISTINCT numero_entrada) as usuarios_unicos_paso,
        COUNT(*) as total_interacciones_paso
    FROM funnel_pasos
    WHERE paso_funnel > 0  -- Solo pasos válidos del funnel
    GROUP BY paso_funnel
),
funnel_completo AS (
    SELECT 
        paso_funnel,
        usuarios_unicos_paso,
        LAG(usuarios_unicos_paso) OVER (ORDER BY paso_funnel) as usuarios_paso_anterior,
        usuarios_unicos_paso - LAG(usuarios_unicos_paso) OVER (ORDER BY paso_funnel) as usuarios_perdidos,
        
        -- Tasas de conversión
        ROUND(usuarios_unicos_paso * 100.0 / 
              FIRST_VALUE(usuarios_unicos_paso) OVER (ORDER BY paso_funnel), 1) as conversion_desde_inicio_pct,
        
        ROUND(usuarios_unicos_paso * 100.0 / 
              LAG(usuarios_unicos_paso) OVER (ORDER BY paso_funnel), 1) as conversion_paso_anterior_pct
    FROM usuarios_por_paso
)
SELECT 
    CASE paso_funnel
        WHEN 1 THEN 'Entrada/Login'
        WHEN 2 THEN 'Dashboard Principal'
        WHEN 3 THEN 'Selección/Categoría'
        WHEN 4 THEN 'Proceso/Formulario'
        WHEN 5 THEN 'Confirmación/Éxito'
    END as nombre_paso,
    usuarios_unicos_paso,
    usuarios_perdidos,
    conversion_desde_inicio_pct,
    conversion_paso_anterior_pct,
    
    -- Identificar cuellos de botella
    CASE 
        WHEN conversion_paso_anterior_pct < 60 THEN 'CUELLO_BOTELLA_CRITICO'
        WHEN conversion_paso_anterior_pct < 75 THEN 'REQUIERE_OPTIMIZACION'
        ELSE 'PERFORMANCE_ACEPTABLE'
    END as estado_paso
FROM funnel_completo
ORDER BY paso_funnel;
```

#### **B. A/B Test de Patrones de Navegación**
```sql
-- ¿Qué variaciones de journey tienen mejor conversión?
WITH variaciones_journey AS (
    SELECT 
        numero_entrada,
        fecha,
        GROUP_CONCAT(
            CONCAT(menu, ':', opcion) 
            ORDER BY hora_inicio 
            SEPARATOR ' → '
        ) as journey_completo,
        COUNT(*) as pasos_totales,
        MAX(CASE WHEN menu IN ('CONFIRMACION', 'EXITO', 'COMPLETADO') THEN 1 ELSE 0 END) as conversion,
        TIMESTAMPDIFF(MINUTE, MIN(hora_inicio), MAX(hora_fin)) as tiempo_total_min
    FROM llamadas_Q1 
    WHERE numero_entrada = numero_digitado
    GROUP BY numero_entrada, fecha
    HAVING COUNT(*) > 1
),
analisis_variaciones AS (
    SELECT 
        journey_completo,
        COUNT(*) as sesiones_totales,
        SUM(conversion) as conversiones,
        ROUND(SUM(conversion) * 100.0 / COUNT(*), 1) as tasa_conversion_pct,
        ROUND(AVG(pasos_totales), 1) as promedio_pasos,
        ROUND(AVG(tiempo_total_min), 1) as promedio_tiempo_min,
        ROUND(AVG(CASE WHEN conversion = 1 THEN tiempo_total_min END), 1) as tiempo_promedio_conversion
    FROM variaciones_journey
    GROUP BY journey_completo
    HAVING COUNT(*) >= 5  -- Solo journeys con volumen significativo
)
SELECT 
    journey_completo,
    sesiones_totales,
    conversiones,
    tasa_conversion_pct,
    promedio_pasos,
    promedio_tiempo_min,
    tiempo_promedio_conversion,
    
    -- Eficiencia del journey
    ROUND(tasa_conversion_pct / promedio_pasos, 1) as eficiencia_por_paso,
    
    -- Recomendación
    CASE 
        WHEN tasa_conversion_pct >= 80 AND promedio_pasos <= 4 THEN 'JOURNEY_OPTIMO'
        WHEN tasa_conversion_pct >= 60 AND promedio_tiempo_min <= 6 THEN 'JOURNEY_EFICIENTE'
        WHEN tasa_conversion_pct >= 40 THEN 'JOURNEY_MEJORABLE'
        ELSE 'JOURNEY_PROBLEMATICO'
    END as clasificacion_journey
FROM analisis_variaciones
ORDER BY tasa_conversion_pct DESC, sesiones_totales DESC;
```

### **4. PERSONALIZACIÓN Y OPTIMIZACIÓN UX**

#### **A. Recomendaciones de Features por Segmento**
```sql
-- ¿Qué features/opciones prefiere cada segmento?
WITH segmentos_usuario AS (
    -- Segmentación simplificada
    SELECT 
        numero_entrada,
        CASE 
            WHEN AVG(interacciones_dia) >= 5 AND COUNT(DISTINCT menu) <= 2 THEN 'POWER_USER'
            WHEN COUNT(DISTINCT menu) >= 4 AND AVG(interacciones_dia) <= 3 THEN 'EXPLORADOR'
            WHEN AVG(duracion_min) > 10 THEN 'STRUGGLE_USER'
            ELSE 'REGULAR'
        END as segmento
    FROM (
        SELECT 
            numero_entrada, fecha,
            COUNT(*) as interacciones_dia,
            TIMESTAMPDIFF(MINUTE, MIN(hora_inicio), MAX(hora_fin)) as duracion_min,
            menu
        FROM llamadas_Q1 
        WHERE numero_entrada = numero_digitado
        GROUP BY numero_entrada, fecha, menu
    ) sesiones
    GROUP BY numero_entrada
),
uso_features AS (
    SELECT 
        su.segmento,
        l.menu,
        l.opcion,
        COUNT(*) as frecuencia_uso,
        COUNT(DISTINCT l.numero_entrada) as usuarios_unicos,
        AVG(TIMESTAMPDIFF(SECOND, l.hora_inicio, l.hora_fin)) as tiempo_promedio_seg,
        
        -- Indicador de éxito con esta feature
        SUM(CASE WHEN EXISTS (
            SELECT 1 FROM llamadas_Q1 l2 
            WHERE l2.numero_entrada = l.numero_entrada 
              AND l2.fecha = l.fecha 
              AND l2.menu IN ('CONFIRMACION', 'EXITO', 'COMPLETADO')
              AND l2.hora_inicio > l.hora_inicio
        ) THEN 1 ELSE 0 END) as sesiones_exitosas_posterior
    FROM segmentos_usuario su
    JOIN llamadas_Q1 l ON su.numero_entrada = l.numero_entrada
    WHERE l.numero_entrada = l.numero_digitado
    GROUP BY su.segmento, l.menu, l.opcion
)
SELECT 
    segmento,
    menu,
    opcion,
    frecuencia_uso,
    usuarios_unicos,
    ROUND(tiempo_promedio_seg, 1) as tiempo_promedio_seg,
    ROUND(sesiones_exitosas_posterior * 100.0 / frecuencia_uso, 1) as tasa_exito_posterior_pct,
    
    -- Score de preferencia por segmento
    ROUND((frecuencia_uso * 1.0 / SUM(frecuencia_uso) OVER (PARTITION BY segmento)) * 100, 1) as preferencia_segmento_pct,
    
    -- Recomendación de personalización
    CASE 
        WHEN preferencia_segmento_pct >= 15 AND tasa_exito_posterior_pct >= 60 THEN 'DESTACAR_PARA_SEGMENTO'
        WHEN preferencia_segmento_pct >= 10 AND tiempo_promedio_seg <= 30 THEN 'ACCESO_RAPIDO'
        WHEN tasa_exito_posterior_pct >= 75 THEN 'PROMOVER_USO'
        WHEN preferencia_segmento_pct <= 3 THEN 'OCULTAR_PARA_SEGMENTO'
        ELSE 'MANTENER_ACTUAL'
    END as recomendacion_personalizacion
FROM uso_features
WHERE frecuencia_uso >= 10  -- Solo features con uso significativo
ORDER BY segmento, preferencia_segmento_pct DESC;
```

---

## 🎯 **Estrategias de Optimización UX por Segmento**

### **1. POWER USERS**
- **Accesos rápidos** a funciones frecuentes
- **Shortcuts de teclado** para operaciones comunes  
- **Dashboard personalizado** con métricas relevantes
- **API/Integrations** para usuarios muy técnicos

### **2. EXPLORADORES** 
- **Tooltips y tours guiados** para nuevas features
- **Breadcrumbs claros** para no perderse
- **"Undo" functionality** para experimentar sin miedo
- **Feature discovery** proactivo

### **3. STRUGGLE USERS**
- **Onboarding extendido** con práctica guiada
- **Simplificación de interfaz** (hide advanced options)
- **Help contextual** en cada paso
- **Progreso visual** para motivar completación

### **4. USUARIOS EN RIESGO DE CHURN**
- **Intervención proactiva** con ofertas de ayuda
- **Re-engagement campaigns** personalizadas
- **Simplificación extrema** de journeys críticos
- **Feedback directo** sobre frustraciones

---

## 📈 **Dashboard de Producto Digital**

### **KPIs Semanales de UX:**
```sql
-- Métricas clave para producto digital
SELECT 
    WEEK(fecha) as semana,
    
    -- Engagement
    COUNT(DISTINCT numero_entrada) as usuarios_activos_semanales,
    AVG(interacciones_por_usuario) as promedio_interacciones_usuario,
    
    -- Retención
    COUNT(DISTINCT CASE WHEN es_usuario_retenido = 1 THEN numero_entrada END) as usuarios_retenidos,
    ROUND(COUNT(DISTINCT CASE WHEN es_usuario_retenido = 1 THEN numero_entrada END) * 100.0 / 
          COUNT(DISTINCT numero_entrada), 1) as tasa_retencion_semanal,
    
    -- Conversión
    SUM(sesiones_exitosas) as conversiones_totales,
    ROUND(SUM(sesiones_exitosas) * 100.0 / COUNT(DISTINCT CONCAT(numero_entrada, fecha)), 1) as tasa_conversion_general,
    
    -- Experiencia
    AVG(duracion_promedio_sesion) as tiempo_promedio_sesion_min,
    COUNT(DISTINCT numero_entrada) - COUNT(DISTINCT CASE WHEN tuvo_exito = 1 THEN numero_entrada END) as usuarios_sin_exito
FROM (
    SELECT 
        numero_entrada, fecha, WEEK(fecha) as semana,
        COUNT(*) as interacciones_por_usuario,
        MAX(CASE WHEN menu IN ('CONFIRMACION', 'EXITO', 'COMPLETADO') THEN 1 ELSE 0 END) as sesiones_exitosas,
        MAX(CASE WHEN menu IN ('CONFIRMACION', 'EXITO', 'COMPLETADO') THEN 1 ELSE 0 END) as tuvo_exito,
        TIMESTAMPDIFF(MINUTE, MIN(hora_inicio), MAX(hora_fin)) as duracion_promedio_sesion,
        
        -- Usuario retenido si estuvo activo la semana anterior también
        MAX(CASE WHEN EXISTS (
            SELECT 1 FROM llamadas_Q1 l2 
            WHERE l2.numero_entrada = llamadas_Q1.numero_entrada 
              AND WEEK(l2.fecha) = WEEK(llamadas_Q1.fecha) - 1
        ) THEN 1 ELSE 0 END) as es_usuario_retenido
    FROM llamadas_Q1 
    WHERE numero_entrada = numero_digitado
    GROUP BY numero_entrada, fecha, WEEK(fecha)
) metricas_semanales
GROUP BY WEEK(fecha)
ORDER BY semana;
```

---

## 🚀 **Plan de Acción para Producto Digital**

### **Semana 1-2: Segmentación y Análisis**
1. **Implementar segmentación automática** de usuarios
2. **Identificar journeys de alto valor** por segmento  
3. **Mapear features críticas** para cada arquetipo

### **Semana 3-4: Experimentos A/B**
1. **Personalización básica** para Power Users (shortcuts)
2. **Onboarding mejorado** para Exploradores
3. **Simplificación de UI** para Struggle Users

### **Mes 2: Optimización Avanzada**
1. **Predicción de churn** en tiempo real
2. **Recomendaciones personalizadas** de features
3. **Intervenciones proactivas** para usuarios en riesgo

### **Métricas de Éxito:**
- ⬆️ **+25% en retención semana 1**
- ⬆️ **+15% en tasa de conversión general**  
- ⬇️ **-40% en usuarios Struggle**
- ⬆️ **+30% en engagement de Power Users**

---

**💡 Esta aproximación te permite crear experiencias personalizadas que maximizan la satisfacción y retención de cada tipo de usuario, reduciendo significativamente el churn.**