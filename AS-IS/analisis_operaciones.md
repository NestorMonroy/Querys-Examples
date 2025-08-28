# ⚙️ **AS-IS: Operaciones - Carga Horaria y Eficiencia por Zona**

## 🎯 **Objetivo de Negocio**
**Optimizar recursos operativos identificando patrones de carga, distribución geográfica y eficiencia del sistema para mejorar la planificación de capacidad y reducir costos operativos.**

---

## 📊 **Análisis Clave para Operaciones**

### **1. ANÁLISIS DE CARGA Y CAPACIDAD**

#### **A. Patrones de Carga Horaria por Zona**
```sql
-- ¿Cuándo y dónde necesitamos más capacidad?
WITH carga_horaria AS (
    SELECT 
        id_8T as zona,
        DATE(fecha) as dia,
        HOUR(hora_inicio) as hora,
        COUNT(*) as total_interacciones,
        COUNT(DISTINCT numero_entrada) as usuarios_unicos,
        AVG(TIMESTAMPDIFF(SECOND, hora_inicio, hora_fin)) as duracion_promedio_seg,
        
        -- Métricas de eficiencia
        COUNT(*) / COUNT(DISTINCT numero_entrada) as interacciones_promedio_por_usuario,
        
        -- Indicadores de sobrecarga
        CASE 
            WHEN COUNT(*) > (AVG(COUNT(*)) OVER (PARTITION BY id_8T) * 1.5) THEN 1 
            ELSE 0 
        END as es_hora_pico
    FROM llamadas_Q1 
    WHERE numero_entrada = numero_digitado
      AND id_8T IS NOT NULL
    GROUP BY id_8T, DATE(fecha), HOUR(hora_inicio)
),
estadisticas_zona_hora AS (
    SELECT 
        zona,
        hora,
        COUNT(*) as dias_con_datos,
        AVG(total_interacciones) as promedio_interacciones_hora,
        MAX(total_interacciones) as pico_max_interacciones,
        AVG(usuarios_unicos) as promedio_usuarios_hora,
        AVG(duracion_promedio_seg) as duracion_promedio_seg,
        SUM(es_hora_pico) as dias_fue_hora_pico,
        ROUND(SUM(es_hora_pico) * 100.0 / COUNT(*), 1) as porcentaje_dias_pico
    FROM carga_horaria
    GROUP BY zona, hora
)
SELECT 
    zona,
    hora,
    ROUND(promedio_interacciones_hora, 0) as carga_promedio,
    pico_max_interacciones as carga_maxima,
    ROUND(promedio_usuarios_hora, 0) as usuarios_promedio,
    ROUND(duracion_promedio_seg, 1) as tiempo_promedio_seg,
    porcentaje_dias_pico,
    
    -- Clasificación de carga
    CASE 
        WHEN promedio_interacciones_hora >= (AVG(promedio_interacciones_hora) OVER (PARTITION BY zona) * 1.3) THEN 'HORA_PICO'
        WHEN promedio_interacciones_hora <= (AVG(promedio_interacciones_hora) OVER (PARTITION BY zona) * 0.7) THEN 'HORA_VALLE'
        ELSE 'HORA_NORMAL'
    END as clasificacion_carga,
    
    -- Recomendación operativa
    CASE 
        WHEN porcentaje_dias_pico > 60 AND promedio_interacciones_hora > 100 THEN 'AUMENTAR_CAPACIDAD'
        WHEN porcentaje_dias_pico < 10 AND promedio_interacciones_hora < 20 THEN 'REDUCIR_CAPACIDAD'
        WHEN duracion_promedio_seg > 120 THEN 'OPTIMIZAR_PERFORMANCE'
        ELSE 'CAPACIDAD_ADECUADA'
    END as recomendacion_operativa
FROM estadisticas_zona_hora
WHERE dias_con_datos >= 5  -- Solo horas con datos suficientes
ORDER BY zona, hora;
```

#### **B. Análisis de Eficiencia del Sistema por Zona**
```sql
-- ¿Qué zonas operan más eficientemente?
WITH metricas_zona AS (
    SELECT 
        id_8T as zona,
        COUNT(*) as total_interacciones,
        COUNT(DISTINCT numero_entrada) as usuarios_unicos,
        COUNT(DISTINCT DATE(fecha)) as dias_operativos,
        
        -- Eficiencia de procesamiento
        AVG(TIMESTAMPDIFF(SECOND, hora_inicio, hora_fin)) as tiempo_promedio_interaccion_seg,
        COUNT(*) / COUNT(DISTINCT numero_entrada) as interacciones_promedio_por_usuario,
        
        -- Distribución de carga temporal
        COUNT(DISTINCT CONCAT(DATE(fecha), '-', HOUR(hora_inicio))) as horas_operativas_unicas,
        
        -- Tasa de éxito por zona
        SUM(CASE WHEN EXISTS (
            SELECT 1 FROM llamadas_Q1 l2 
            WHERE l2.numero_entrada = l1.numero_entrada 
              AND l2.fecha = l1.fecha 
              AND l2.menu IN ('CONFIRMACION', 'EXITO', 'COMPLETADO')
        ) THEN 1 ELSE 0 END) as sesiones_con_exito,
        
        -- Complejidad de operaciones
        AVG(sesiones_por_usuario.interacciones_por_sesion) as complejidad_promedio_sesion,
        COUNT(DISTINCT menu) as variedad_menus_usados,
        COUNT(DISTINCT opcion) as variedad_opciones_usadas
    FROM llamadas_Q1 l1
    JOIN (
        SELECT 
            numero_entrada, fecha, id_8T,
            COUNT(*) as interacciones_por_sesion
        FROM llamadas_Q1 
        WHERE numero_entrada = numero_digitado
        GROUP BY numero_entrada, fecha, id_8T
    ) sesiones_por_usuario ON (l1.numero_entrada = sesiones_por_usuario.numero_entrada 
                               AND l1.fecha = sesiones_por_usuario.fecha 
                               AND l1.id_8T = sesiones_por_usuario.id_8T)
    WHERE l1.numero_entrada = l1.numero_digitado
      AND l1.id_8T IS NOT NULL
    GROUP BY id_8T
),
benchmark_eficiencia AS (
    SELECT 
        zona,
        total_interacciones,
        usuarios_unicos,
        dias_operativos,
        ROUND(tiempo_promedio_interaccion_seg, 1) as tiempo_promedio_seg,
        ROUND(interacciones_promedio_por_usuario, 1) as interacciones_por_usuario,
        ROUND(complejidad_promedio_sesion, 1) as complejidad_sesion,
        ROUND(sesiones_con_exito * 100.0 / total_interacciones, 1) as tasa_exito_pct,
        
        -- Métricas de eficiencia operativa
        ROUND(total_interacciones / dias_operativos, 0) as interacciones_promedio_dia,
        ROUND(usuarios_unicos / dias_operativos, 0) as usuarios_promedio_dia,
        ROUND(total_interacciones / horas_operativas_unicas, 1) as interacciones_promedio_hora,
        
        -- Scores de rendimiento (mayor = mejor)
        ROUND(
            ((100 - LEAST(100, tiempo_promedio_interaccion_seg)) * 0.3) +
            (LEAST(100, sesiones_con_exito * 100.0 / total_interacciones) * 0.4) +
            ((100 - LEAST(100, complejidad_promedio_sesion * 10)) * 0.3)
        , 1) as score_eficiencia_operativa
    FROM metricas_zona
)
SELECT 
    zona,
    total_interacciones,
    usuarios_unicos,
    interacciones_promedio_dia,
    usuarios_promedio_dia,
    tiempo_promedio_seg,
    interacciones_por_usuario,
    tasa_exito_pct,
    score_eficiencia_operativa,
    
    -- Ranking de eficiencia
    RANK() OVER (ORDER BY score_eficiencia_operativa DESC) as ranking_eficiencia,
    
    -- Clasificación operativa
    CASE 
        WHEN score_eficiencia_operativa >= 80 THEN 'ZONA_OPTIMA'
        WHEN score_eficiencia_operativa >= 65 THEN 'ZONA_EFICIENTE'
        WHEN score_eficiencia_operativa >= 50 THEN 'ZONA_PROMEDIO'
        ELSE 'ZONA_REQUIERE_MEJORA'
    END as clasificacion_operativa,
    
    -- Recomendaciones específicas
    CASE 
        WHEN tiempo_promedio_seg > 90 AND tasa_exito_pct < 60 THEN 'OPTIMIZAR_PROCESOS'
        WHEN interacciones_por_usuario > 5 AND tasa_exito_pct > 80 THEN 'SIMPLIFICAR_FLUJOS'
        WHEN tasa_exito_pct > 85 AND tiempo_promedio_seg < 45 THEN 'MODELO_A_REPLICAR'
        WHEN usuarios_promedio_dia < 50 THEN 'EVALUAR_RECURSOS'
        ELSE 'MANTENER_OPERACION'
    END as recomendacion_especifica
FROM benchmark_eficiencia
ORDER BY score_eficiencia_operativa DESC;
```

### **2. PLANIFICACIÓN DE CAPACIDAD Y RECURSOS**

#### **A. Predicción de Demanda por Zona y Horario**
```sql
-- ¿Cómo planificar recursos por zona y horario?
WITH demanda_historica AS (
    SELECT 
        id_8T as zona,
        DAYOFWEEK(fecha) as dia_semana, -- 1=Domingo, 2=Lunes, etc.
        HOUR(hora_inicio) as hora,
        COUNT(*) as interacciones,
        COUNT(DISTINCT numero_entrada) as usuarios,
        AVG(TIMESTAMPDIFF(SECOND, hora_inicio, hora_fin)) as duracion_promedio_seg
    FROM llamadas_Q1 
    WHERE numero_entrada = numero_digitado
      AND id_8T IS NOT NULL
    GROUP BY id_8T, DAYOFWEEK(fecha), HOUR(hora_inicio)
),
patrones_demanda AS (
    SELECT 
        zona,
        dia_semana,
        hora,
        AVG(interacciones) as demanda_promedio,
        MAX(interacciones) as demanda_maxima,
        MIN(interacciones) as demanda_minima,
        STDDEV(interacciones) as variabilidad_demanda,
        AVG(duracion_promedio_seg) as tiempo_procesamiento_promedio,
        
        -- Capacidad requerida (asumiendo X segundos por interacción)
        CEIL(AVG(interacciones) * AVG(duracion_promedio_seg) / 3600) as horas_procesamiento_requeridas
    FROM demanda_historica
    GROUP BY zona, dia_semana, hora
    HAVING COUNT(*) >= 3  -- Al menos 3 observaciones
),
recomendaciones_capacidad AS (
    SELECT 
        zona,
        CASE dia_semana
            WHEN 1 THEN 'Domingo'
            WHEN 2 THEN 'Lunes'
            WHEN 3 THEN 'Martes'
            WHEN 4 THEN 'Miércoles'
            WHEN 5 THEN 'Jueves'
            WHEN 6 THEN 'Viernes'
            WHEN 7 THEN 'Sábado'
        END as dia_nombre,
        hora,
        ROUND(demanda_promedio, 0) as demanda_esperada,
        ROUND(demanda_maxima, 0) as demanda_pico,
        ROUND(variabilidad_demanda, 1) as desviacion_estandar,
        horas_procesamiento_requeridas,
        
        -- Nivel de recursos recomendado
        CASE 
            WHEN demanda_promedio >= 100 AND variabilidad_demanda > 30 THEN 'ALTO_ELASTICO'
            WHEN demanda_promedio >= 100 THEN 'ALTO_ESTABLE'
            WHEN demanda_promedio >= 50 AND variabilidad_demanda > 20 THEN 'MEDIO_ELASTICO'
            WHEN demanda_promedio >= 50 THEN 'MEDIO_ESTABLE'
            WHEN demanda_promedio >= 20 THEN 'BAJO_ESTABLE'
            ELSE 'MINIMO'
        END as nivel_recursos_recomendado,
        
        -- Estrategia operativa
        CASE 
            WHEN variabilidad_demanda > demanda_promedio * 0.5 THEN 'RECURSOS_DINAMICOS'
            WHEN horas_procesamiento_requeridas > 2 THEN 'RECURSOS_DEDICADOS'
            ELSE 'RECURSOS_COMPARTIDOS'
        END as estrategia_recursos
    FROM patrones_demanda
)
SELECT 
    zona,
    dia_nombre,
    hora,
    demanda_esperada,
    demanda_pico,
    horas_procesamiento_requeridas,
    nivel_recursos_recomendado,
    estrategia_recursos,
    
    -- Costo estimado (ajustar según tus métricas de costo)
    ROUND(horas_procesamiento_requeridas * 25, 2) as costo_estimado_hora  -- Ejemplo: $25 por hora de procesamiento
FROM recomendaciones_capacidad
ORDER BY zona, dia_semana, hora;
```

#### **B. Análisis de Distribución de Carga entre Zonas**
```sql
-- ¿Cómo está distribuida la carga entre zonas?
WITH distribucion_carga AS (
    SELECT 
        id_8T as zona,
        COUNT(*) as total_operaciones,
        COUNT(DISTINCT numero_entrada) as usuarios_unicos,
        COUNT(DISTINCT DATE(fecha)) as dias_activos,
        
        -- Métricas de intensidad
        COUNT(*) / COUNT(DISTINCT DATE(fecha)) as operaciones_promedio_dia,
        COUNT(DISTINCT numero_entrada) / COUNT(DISTINCT DATE(fecha)) as usuarios_promedio_dia,
        
        -- Horarios de operación
        MIN(HOUR(hora_inicio)) as primera_hora_operacion,
        MAX(HOUR(hora_inicio)) as ultima_hora_operacion,
        COUNT(DISTINCT HOUR(hora_inicio)) as horas_operativas_diferentes,
        
        -- Eficiencia de procesamiento
        AVG(TIMESTAMPDIFF(SECOND, hora_inicio, hora_fin)) as tiempo_promedio_operacion_seg,
        
        -- Complejidad de operaciones
        AVG(operaciones_por_sesion.ops_por_sesion) as complejidad_promedio_sesion
    FROM llamadas_Q1 l1
    JOIN (
        SELECT 
            numero_entrada, fecha, id_8T,
            COUNT(*) as ops_por_sesion
        FROM llamadas_Q1 
        WHERE numero_entrada = numero_digitado
        GROUP BY numero_entrada, fecha, id_8T
    ) operaciones_por_sesion ON (l1.numero_entrada = operaciones_por_sesion.numero_entrada 
                                 AND l1.fecha = operaciones_por_sesion.fecha 
                                 AND l1.id_8T = operaciones_por_sesion.id_8T)
    WHERE l1.numero_entrada = l1.numero_digitado
      AND l1.id_8T IS NOT NULL
    GROUP BY id_8T
),
analisis_distribucion AS (
    SELECT 
        zona,
        total_operaciones,
        usuarios_unicos,
        operaciones_promedio_dia,
        usuarios_promedio_dia,
        CONCAT(primera_hora_operacion, ':00 - ', ultima_hora_operacion, ':00') as ventana_operativa,
        horas_operativas_diferentes,
        ROUND(tiempo_promedio_operacion_seg, 1) as tiempo_promedio_seg,
        ROUND(complejidad_promedio_sesion, 1) as complejidad_sesion,
        
        -- Porcentaje de carga total
        ROUND(total_operaciones * 100.0 / SUM(total_operaciones) OVER(), 1) as porcentaje_carga_total,
        
        -- Densidad operativa (operaciones por hora operativa)
        ROUND(operaciones_promedio_dia / horas_operativas_diferentes, 1) as densidad_operaciones_hora,
        
        -- Eficiencia relativa vs promedio general
        ROUND((tiempo_promedio_operacion_seg / AVG(tiempo_promedio_operacion_seg) OVER()) * 100, 1) as eficiencia_relativa_pct
    FROM distribucion_carga
)
SELECT 
    zona,
    total_operaciones,
    usuarios_unicos,
    operaciones_promedio_dia,
    ventana_operativa,
    porcentaje_carga_total,
    densidad_operaciones_hora,
    tiempo_promedio_seg,
    eficiencia_relativa_pct,
    
    -- Clasificación de zona por carga
    CASE 
        WHEN porcentaje_carga_total >= 25 THEN 'ZONA_CRITICA'
        WHEN porcentaje_carga_total >= 15 THEN 'ZONA_ALTA_DEMANDA'
        WHEN porcentaje_carga_total >= 8 THEN 'ZONA_DEMANDA_MEDIA'
        ELSE 'ZONA_BAJA_DEMANDA'
    END as clasificacion_carga,
    
    -- Estrategia de balanceamiento
    CASE 
        WHEN porcentaje_carga_total >= 25 AND eficiencia_relativa_pct > 110 THEN 'DISTRIBUIR_CARGA'
        WHEN porcentaje_carga_total >= 20 AND densidad_operaciones_hora > 50 THEN 'AMPLIAR_VENTANA_OPERATIVA'
        WHEN porcentaje_carga_total <= 5 THEN 'CONSOLIDAR_CON_OTRA_ZONA'
        WHEN eficiencia_relativa_pct <= 80 THEN 'OPTIMIZAR_PROCESOS'
        ELSE 'MANTENER_OPERACION_ACTUAL'
    END as estrategia_balanceamiento
FROM analisis_distribucion
ORDER BY porcentaje_carga_total DESC;
```

### **3. OPTIMIZACIÓN DE PERFORMANCE Y COSTOS**

#### **A. Identificación de Cuellos de Botella Operativos**
```sql
-- ¿Dónde están los cuellos de botella que impactan la operación?
WITH metricas_operacion AS (
    SELECT 
        id_8T as zona,
        menu,
        opcion,
        COUNT(*) as frecuencia_uso,
        AVG(TIMESTAMPDIFF(SECOND, hora_inicio, hora_fin)) as tiempo_promedio_seg,
        MAX(TIMESTAMPDIFF(SECOND, hora_inicio, hora_fin)) as tiempo_maximo_seg,
        MIN(TIMESTAMPDIFF(SECOND, hora_inicio, hora_fin)) as tiempo_minimo_seg,
        STDDEV(TIMESTAMPDIFF(SECOND, hora_inicio, hora_fin)) as variabilidad_tiempo,
        
        -- Impacto en journey del usuario
        AVG(COUNT(*) OVER (PARTITION BY numero_entrada, fecha)) as interacciones_promedio_sesion,
        
        -- Horarios de mayor uso
        COUNT(CASE WHEN HOUR(hora_inicio) BETWEEN 9 AND 17 THEN 1 END) as uso_horario_pico,
        COUNT(CASE WHEN HOUR(hora_inicio) NOT BETWEEN 9 AND 17 THEN 1 END) as uso_horario_valle
    FROM llamadas_Q1 
    WHERE numero_entrada = numero_digitado
      AND id_8T IS NOT NULL
      AND menu IS NOT NULL 
      AND opcion IS NOT NULL
    GROUP BY id_8T, menu, opcion
    HAVING COUNT(*) >= 10  -- Solo operaciones con volumen significativo
),
analisis_cuellos_botella AS (
    SELECT 
        zona,
        menu,
        opcion,
        frecuencia_uso,
        tiempo_promedio_seg,
        tiempo_maximo_seg,
        ROUND(variabilidad_tiempo, 1) as desviacion_tiempo,
        
        -- Score de cuello de botella (mayor = más problemático)
        ROUND(
            (CASE WHEN tiempo_promedio_seg > 60 THEN (tiempo_promedio_seg - 60) * 0.5 ELSE 0 END) +
            (CASE WHEN variabilidad_tiempo > 30 THEN variabilidad_tiempo * 0.3 ELSE 0 END) +
            (CASE WHEN frecuencia_uso > 100 THEN LOG(frecuencia_uso) * 5 ELSE 0 END)
        , 1) as score_cuello_botella,
        
        -- Impacto estimado en operaciones
        ROUND(frecuencia_uso * (tiempo_promedio_seg - 30) / 60, 0) as minutos_impacto_diario,
        
        -- Clasificación de problema
        CASE 
            WHEN tiempo_promedio_seg > 120 AND frecuencia_uso > 50 THEN 'CRITICO'
            WHEN tiempo_promedio_seg > 90 OR (variabilidad_tiempo > 45 AND frecuencia_uso > 30) THEN 'ALTO_IMPACTO'
            WHEN tiempo_promedio_seg > 60 AND frecuencia_uso > 20 THEN 'MEDIO_IMPACTO'
            ELSE 'BAJO_IMPACTO'
        END as nivel_problema
    FROM metricas_operacion
)
SELECT 
    zona,
    menu,
    opcion,
    frecuencia_uso,
    tiempo_promedio_seg,
    tiempo_maximo_seg,
    desviacion_tiempo,
    score_cuello_botella,
    minutos_impacto_diario,
    nivel_problema,
    
    -- Prioridad de optimización
    CASE 
        WHEN nivel_problema = 'CRITICO' THEN 1
        WHEN nivel_problema = 'ALTO_IMPACTO' AND minutos_impacto_diario > 60 THEN 2
        WHEN nivel_problema = 'ALTO_IMPACTO' THEN 3
        WHEN nivel_problema = 'MEDIO_IMPACTO' AND frecuencia_uso > 100 THEN 4
        ELSE 5
    END as prioridad_optimizacion,
    
    -- Recomendación específica
    CASE 
        WHEN tiempo_promedio_seg > 120 THEN 'REDISEÑAR_PROCESO_URGENTE'
        WHEN variabilidad_tiempo > 60 THEN 'ESTANDARIZAR_PROCEDIMIENTO'
        WHEN tiempo_maximo_seg > 300 THEN 'IMPLEMENTAR_TIMEOUT'
        WHEN minutos_impacto_diario > 120 THEN 'AUTOMATIZAR_PROCESO'
        ELSE 'OPTIMIZAR_PERFORMANCE'
    END as recomendacion_accion
FROM analisis_cuellos_botella
ORDER BY prioridad_optimizacion, score_cuello_botella DESC;
```

#### **B. Análisis de Costos Operativos por Zona**
```sql
-- ¿Cuál es el costo operativo real por zona?
WITH costos_operativos AS (
    SELECT 
        id_8T as zona,
        COUNT(*) as total_operaciones,
        COUNT(DISTINCT numero_entrada) as usuarios_unicos,
        COUNT(DISTINCT DATE(fecha)) as dias_operativos,
        
        -- Tiempo total de procesamiento
        SUM(TIMESTAMPDIFF(SECOND, hora_inicio, hora_fin)) as segundos_procesamiento_total,
        AVG(TIMESTAMPDIFF(SECOND, hora_inicio, hora_fin)) as segundos_promedio_operacion,
        
        -- Distribución de complejidad
        COUNT(CASE WHEN sesion_ops.ops_por_sesion = 1 THEN 1 END) as operaciones_simples,
        COUNT(CASE WHEN sesion_ops.ops_por_sesion BETWEEN 2 AND 5 THEN 1 END) as operaciones_medias,
        COUNT(CASE WHEN sesion_ops.ops_por_sesion > 5 THEN 1 END) as operaciones_complejas,
        
        -- Eficiencia de resolución
        COUNT(CASE WHEN EXISTS (
            SELECT 1 FROM llamadas_Q1 l2 
            WHERE l2.numero_entrada = l1.numero_entrada 
              AND l2.fecha = l1.fecha 
              AND l2.menu IN ('CONFIRMACION', 'EXITO', 'COMPLETADO')
        ) THEN 1 END) as operaciones_exitosas
    FROM llamadas_Q1 l1
    JOIN (
        SELECT 
            numero_entrada, fecha, id_8T,
            COUNT(*) as ops_por_sesion
        FROM llamadas_Q1 
        WHERE numero_entrada = numero_digitado
        GROUP BY numero_entrada, fecha, id_8T
    ) sesion_ops ON (l1.numero_entrada = sesion_ops.numero_entrada 
                     AND l1.fecha = sesion_ops.fecha 
                     AND l1.id_8T = sesion_ops.id_8T)
    WHERE l1.numero_entrada = l1.numero_digitado
      AND l1.id_8T IS NOT NULL
    GROUP BY id_8T
),
calculo_costos AS (
    SELECT 
        zona,
        total_operaciones,
        usuarios_unicos,
        dias_operativos,
        ROUND(segundos_procesamiento_total / 3600, 1) as horas_procesamiento_total,
        ROUND(segundos_promedio_operacion, 1) as segundos_promedio_op,
        
        -- Distribución de complejidad
        ROUND(operaciones_simples * 100.0 / total_operaciones, 1) as pct_ops_simples,
        ROUND(operaciones_medias * 100.0 / total_operaciones, 1) as pct_ops_medias,
        ROUND(operaciones_complejas * 100.0 / total_operaciones, 1) as pct_ops_complejas,
        
        -- Eficiencia
        ROUND(operaciones_exitosas * 100.0 / total_operaciones, 1) as tasa_exito_pct,
        
        -- Costos estimados (ajustar según tus métricas reales)
        ROUND((segundos_procesamiento_total / 3600) * 30, 2) as costo_procesamiento_estimado, -- $30/hora
        ROUND(total_operaciones * 0.10, 2) as costo_transaccional_estimado, -- $0.10 por operación
        ROUND(((segundos_procesamiento_total / 3600) * 30) + (total_operaciones * 0.10), 2) as costo_total_estimado
    FROM costos_operativos
)
SELECT 
    zona,
    total_operaciones,
    horas_procesamiento_total,
    segundos_promedio_op,
    pct_ops_simples,
    pct_ops_medias,
    pct_ops_complejas,
    tasa_exito_pct,
    costo_total_estimado,
    
    -- Métricas de eficiencia de costo
    ROUND(costo_total_estimado / total_operaciones, 3) as costo_por_operacion,
    ROUND(costo_total_estimado / usuarios_unicos, 2) as costo_por_usuario,
    ROUND(total_operaciones / horas_procesamiento_total, 1) as operaciones_por_hora,
    
    -- Ranking de eficiencia de costo
    RANK() OVER (ORDER BY costo_total_estimado / total_operaciones) as ranking_eficiencia_costo,
    
    -- Oportunidades de optimización
    CASE 
        WHEN pct_ops_complejas > 30 AND tasa_exito_pct < 70 THEN 'SIMPLIFICAR_PROCESOS'
        WHEN segundos_promedio_op > 90 THEN 'OPTIMIZAR_PERFORMANCE'
        WHEN costo_total_estimado / usuarios_unicos > 5 THEN 'REDUCIR_COMPLEJIDAD'
        WHEN operaciones_por_hora < 20 THEN 'MEJORAR_THROUGHPUT'
        ELSE 'EFICIENCIA_ACEPTABLE'
    END as oportunidad_optimizacion
FROM calculo_costos
ORDER BY costo_total_estimado DESC;
```

---

## 🎯 **Dashboard Operativo en Tiempo Real**

### **KPIs Operativos Diarios:**
```sql
-- Métricas clave para operaciones
SELECT 
    DATE(fecha) as dia,
    id_8T as zona,
    
    -- Volumen y carga
    COUNT(*) as operaciones_totales,
    COUNT(DISTINCT numero_entrada) as usuarios_unicos,
    COUNT(DISTINCT HOUR(hora_inicio)) as horas_activas,
    
    -- Eficiencia operativa
    ROUND(AVG(TIMESTAMPDIFF(SECOND, hora_inicio, hora_fin)), 1) as tiempo_promedio_operacion_seg,
    MAX(TIMESTAMPDIFF(SECOND, hora_inicio, hora_fin)) as tiempo_maximo_operacion_seg,
    ROUND(COUNT(*) / COUNT(DISTINCT HOUR(hora_inicio)), 1) as operaciones_por_hora_activa,
    
    -- Performance del sistema
    COUNT(CASE WHEN TIMESTAMPDIFF(SECOND, hora_inicio, hora_fin) > 120 THEN 1 END) as operaciones_lentas,
    ROUND(COUNT(CASE WHEN TIMESTAMPDIFF(SECOND, hora_inicio, hora_fin) > 120 THEN 1 END) * 100.0 / COUNT(*), 1) as pct_operaciones_lentas,
    
    -- Distribución horaria de picos
    MAX(COUNT(*) OVER (PARTITION BY DATE(fecha), id_8T, HOUR(hora_inicio))) as pico_operaciones_hora,
    HOUR(hora_inicio) as hora_pico
FROM llamadas_Q1 
WHERE numero_entrada = numero_digitado
  AND id_8T IS NOT NULL
GROUP BY DATE(fecha), id_8T
ORDER BY dia DESC, zona;
```

---

## 🚀 **Plan de Acción Operativo**

### **Semana 1: Identificación y Priorización**
1. **Mapear cuellos de botella críticos** por zona
2. **Identificar horas pico** que requieren más capacidad  
3. **Calcular costos reales** por zona y tipo de operación

### **Semana 2-3: Optimizaciones Rápidas**
1. **Redistribuir carga** entre zonas menos utilizadas
2. **Implementar timeouts** para operaciones que se cuelgan
3. **Optimizar procesos** con mayor impacto en tiempo

### **Mes 2: Optimizaciones Estructurales**
1. **Balanceamiento dinámico** de carga por zona
2. **Escalado automático** basado en patrones históricos
3. **Consolidación de zonas** con baja utilización

### **Mes 3: Automatización y Predicción**
1. **Predicción de demanda** por zona y horario
2. **Asignación automática** de recursos
3. **Alertas proactivas** de sobrecarga

---

## 📈 **Métricas de Éxito Operativo**

### **KPIs Principales:**
- **Utilización de Capacidad**: % de uso óptimo por zona
- **Tiempo Promedio de Operación**: Segundos por transacción
- **Costo por Operación**: $ por transacción exitosa
- **Distribución de Carga**: Balanceamiento entre zonas

### **Metas Trimestrales:**
- ⬇️ **-25% en tiempo promedio de operación**
- ⬆️ **+40% en operaciones por hora**  
- ⬇️ **-30% en costo por operación**
- ⬆️ **+90% en utilización balanceada entre zonas**

---

**⚙️ Esta aproximación te permite optimizar recursos, reducir costos y mejorar la eficiencia operativa basándote en datos reales de comportamiento por zona geográfica.**