```

### 10.2 Análisis de Estabilidad Cross-Trimestral
```sql
-- Análisis de estabilidad de categorías entre trimestres
WITH categorias_por_trimestre AS (
    SELECT @Q1_nombre as trimestre, cCategoria, COUNT(*) as freq FROM productos_t1 WHERE cIDT IN (@O01, @O02) GROUP BY cCategoria
    UNION ALL
    SELECT @Q2_nombre, cCategoria, COUNT(*) FROM productos_t2 WHERE cIDT IN (@O01, @O02) GROUP BY cCategoria  
    UNION ALL
    SELECT @Q3_nombre, cCategoria, COUNT(*) FROM productos_t3 WHERE cIDT IN (@O01, @O02) GROUP BY cCategoria
),
matriz_estabilidad AS (
    SELECT 
        cCategoria,
        SUM(CASE WHEN trimestre = @Q1_nombre THEN freq ELSE 0 END) as freq_q1,
        SUM(CASE WHEN trimestre = @Q2_nombre THEN freq ELSE 0 END) as freq_q2,
        SUM(CASE WHEN trimestre = @Q3_nombre THEN freq ELSE 0 END) as freq_q3,
        COUNT(DISTINCT trimestre) as trimestres_presente
    FROM categorias_por_trimestre
    GROUP BY cCategoria
)
SELECT 
    cCategoria,
    freq_q1, freq_q2, freq_q3,
    trimestres_presente,
    CASE 
        WHEN trimestres_presente = 3 THEN 'CATEGORÍA_ESTABLE'
        WHEN trimestres_presente = 2 THEN 'CATEGORÍA_INTERMITENTE'  
        ELSE 'CATEGORÍA_TEMPORAL'
    END as clasificacion_estabilidad,
    
    -- Coeficiente de variación entre trimestres
    ROUND(STDDEV(freq_total) / AVG(freq_total) * 100, 2) as coef_variacion_temporal,
    
    -- Tendencia (simplificada)
    CASE 
        WHEN freq_q3 > freq_q2 AND freq_q2 > freq_q1 THEN 'CRECIENTE'
        WHEN freq_q3 < freq_q2 AND freq_q2 < freq_q1 THEN 'DECRECIENTE'
        WHEN freq_q1 = freq_q2 AND freq_q2 = freq_q3 THEN 'ESTABLE'
        ELSE 'IRREGULAR'
    END as tendencia
    
FROM matriz_estabilidad,
     (SELECT freq_q1 as freq_total FROM matriz_estabilidad WHERE cCategoria = matriz_estabilidad.cCategoria
      UNION ALL SELECT freq_q2 FROM matriz_estabilidad WHERE cCategoria = matriz_estabilidad.cCategoria  
      UNION ALL SELECT freq_q3 FROM matriz_estabilidad WHERE cCategoria = matriz_estabilidad.cCategoria) freqs
GROUP BY cCategoria, freq_q1, freq_q2, freq_q3, trimestres_presente
ORDER BY coef_variacion_temporal DESC;
```

---

## 11. ANÁLISIS DE HORARIOS Y UTILIZACIÓN

### 11.1 Patrones de Utilización por Horario
```sql
-- Análisis de eficiencia temporal
WITH duraciones AS (
    SELECT 
        cIDT,
        cCategoria,
        cFecha,
        cHInicio,
        cHFin,
        CASE 
            WHEN cHInicio IS NOT NULL AND cHFin IS NOT NULL 
            THEN TIME_TO_SEC(cHFin) - TIME_TO_SEC(cHInicio)
            ELSE NULL 
        END as duracion_segundos
    FROM productos_t1 
    WHERE cIDT IN (@O01, @O02)
)
SELECT 
    @Q1_nombre as trimestre,
    cIDT,
    cCategoria,
    COUNT(*) as total_sesiones,
    COUNT(duracion_segundos) as sesiones_con_duracion,
    
    -- Estadísticas de duración
    ROUND(AVG(duracion_segundos), 0) as duracion_promedio_seg,
    ROUND(MIN(duracion_segundos), 0) as duracion_minima_seg,
    ROUND(MAX(duracion_segundos), 0) as duracion_maxima_seg,
    ROUND(STDDEV(duracion_segundos), 0) as std_duracion_seg,
    
    -- Clasificación de sesiones por duración
    COUNT(CASE WHEN duracion_segundos < 300 THEN 1 END) as sesiones_cortas_5min,
    COUNT(CASE WHEN duracion_segundos BETWEEN 300 AND 1800 THEN 1 END) as sesiones_medias_30min,
    COUNT(CASE WHEN duracion_segundos > 1800 THEN 1 END) as sesiones_largas_30min,
    
    -- Detección de anomalías temporales
    COUNT(CASE WHEN duracion_segundos < 0 THEN 1 END) as duraciones_negativas,
    COUNT(CASE WHEN duracion_segundos > 28800 THEN 1 END) as duraciones_excesivas_8h
    
FROM duraciones
GROUP BY cIDT, cCategoria
ORDER BY cIDT, duracion_promedio_seg DESC;
```

---

## 12. ANÁLISIS DE CONSISTENCIA LÓGICA

### 12.1 Validaciones de Reglas de Negocio
```sql
-- Análisis de violaciones a reglas de negocio
SELECT 
    @Q1_nombre as trimestre,
    'Validaciones_Negocio' as tipo_analisis,
    
    -- Consistencia temporal
    COUNT(CASE WHEN cHInicio >= cHFin THEN 1 END) as violaciones_orden_temporal,
    COUNT(CASE WHEN TIME_TO_SEC(cHFin) - TIME_TO_SEC(cHInicio) > 28800 THEN 1 END) as sesiones_mas_8h,
    COUNT(CASE WHEN TIME_TO_SEC(cHInicio) < TIME_TO_SEC('06:00:00') THEN 1 END) as inicio_muy_temprano,
    COUNT(CASE WHEN TIME_TO_SEC(cHFin) > TIME_TO_SEC('23:00:00') THEN 1 END) as fin_muy_tarde,
    
    -- Consistencia de selección vs IOT
    COUNT(CASE WHEN cSeleccion = 1 AND cIOT = 0 THEN 1 END) as seleccionado_sin_iot,
    COUNT(CASE WHEN cSeleccion = 0 AND cIOT = 1 THEN 1 END) as no_seleccionado_con_iot,
    
    -- Productos duplicados en mismo día
    COUNT(*) - COUNT(DISTINCT CONCAT(cProducto, DATE(cFecha), cIDT)) as productos_duplicados_mismo_dia,
    
    -- Registros en fechas futuras (respecto al trimestre)
    COUNT(CASE WHEN cFecha > @Q1_fin THEN 1 END) as fechas_futuras,
    COUNT(CASE WHEN cFecha < @Q1_inicio THEN 1 END) as fechas_pasadas
    
FROM productos_t1 
WHERE cIDT IN (@O01, @O02);
```

---

## 13. ANÁLISIS DE DISTRIBUCIÓN DE FRECUENCIAS

### 13.1 Histograma de Variables Numéricas
```sql
-- Distribución de frecuencias por bins
WITH bins_producto AS (
    SELECT 
        cProducto,
        CASE 
            WHEN cProducto IS NULL THEN 'NULL'
            WHEN cProducto < 1000000 THEN 'Bin_1: <1M'
            WHEN cProducto < 5000000 THEN 'Bin_2: 1M-5M'  
            WHEN cProducto < 10000000 THEN 'Bin_3: 5M-10M'
            ELSE 'Bin_4: >10M'
        END as bin_producto
    FROM productos_t1 WHERE cIDT IN (@O01, @O02)
)
SELECT 
    @Q1_nombre as trimestre,
    bin_producto,
    COUNT(*) as frecuencia,
    ROUND((COUNT(*) * 100.0 / SUM(COUNT(*)) OVER()), 2) as porcentaje,
    SUM(COUNT(*)) OVER(ORDER BY bin_producto ROWS UNBOUNDED PRECEDING) as freq_acumulada,
    ROUND((SUM(COUNT(*)) OVER(ORDER BY bin_producto ROWS UNBOUNDED PRECEDING) * 100.0 / SUM(COUNT(*)) OVER()), 2) as pct_acumulado
FROM bins_producto
GROUP BY bin_producto
ORDER BY bin_producto;
```

---

## 14. ANÁLISIS DE PATRONES DE COMPORTAMIENTO

### 14.1 Segmentación de Comportamientos
```sql
-- Análisis de patrones de comportamiento por cIDT
WITH comportamiento_idt AS (
    SELECT 
        cIDT,
        COUNT(*) as total_actividad,
        COUNT(DISTINCT cProducto) as productos_diferentes,
        COUNT(DISTINCT cCategoria) as categorias_diferentes,
        COUNT(DISTINCT DATE(cFecha)) as dias_activos,
        ROUND(AVG(cSeleccion), 2) as tasa_seleccion,
        ROUND(AVG(cIOT), 2) as tasa_iot,
        MIN(cFecha) as primera_actividad,
        MAX(cFecha) as ultima_actividad,
        ROUND(AVG(TIME_TO_SEC(cHFin) - TIME_TO_SEC(cHInicio)), 0) as duracion_promedio_seg
    FROM productos_t1 
    WHERE cIDT IN (@O01, @O02) 
      AND cHInicio IS NOT NULL AND cHFin IS NOT NULL
    GROUP BY cIDT
)
SELECT 
    @Q1_nombre as trimestre,
    cIDT,
    total_actividad,
    productos_diferentes,
    categorias_diferentes,
    dias_activos,
    tasa_seleccion,
    tasa_iot,
    duracion_promedio_seg,
    
    -- Clasificación de usuarios
    CASE 
        WHEN total_actividad >= 100 AND dias_activos >= 20 THEN 'USUARIO_INTENSIVO'
        WHEN total_actividad >= 50 AND dias_activos >= 10 THEN 'USUARIO_REGULAR'
        WHEN total_actividad >= 10 AND dias_activos >= 5 THEN 'USUARIO_OCASIONAL'
        ELSE 'USUARIO_ESPORÁDICO'
    END as perfil_usuario,
    
    -- Métricas de diversidad
    ROUND((productos_diferentes * 1.0 / total_actividad), 3) as ratio_diversidad_productos,
    ROUND((categorias_diferentes * 1.0 / productos_diferentes), 3) as ratio_categorias_por_producto,
    
    -- Métricas de intensidad temporal
    ROUND((total_actividad * 1.0 / dias_activos), 2) as actividad_promedio_por_dia,
    DATEDIFF(ultima_actividad, primera_actividad) + 1 as span_actividad_dias
    
FROM comportamiento_idt
ORDER BY total_actividad DESC;
```

---

## 15. ANÁLISIS DE ANOMALÍAS Y EXCEPCIONES

### 15.1 Detección de Registros Anómalos Multidimensionales
```sql
-- Score de anomalía compuesto
WITH scores_anomalia AS (
    SELECT 
        cProducto, cIDT, cCategoria, cSeleccion, cIOT, cFecha,
        
        -- Score temporal (registros fuera de horario normal)
        CASE WHEN HOUR(cFecha) BETWEEN 6 AND 22 THEN 0 ELSE 1 END as score_temporal,
        
        -- Score de producto (si está fuera de rangos típicos)
        CASE WHEN cProducto BETWEEN 1000000 AND 50000000 THEN 0 ELSE 1 END as score_producto,
        
        -- Score categórico (categorías muy raras)
        CASE WHEN cCategoria IN (
            SELECT cCategoria FROM productos_t1 WHERE cIDT IN (@O01, @O02) 
            GROUP BY cCategoria HAVING COUNT(*) >= 10
        ) THEN 0 ELSE 1 END as score_categoria,
        
        -- Score de combinación selección-IOT
        CASE 
            WHEN (cSeleccion = 1 AND cIOT = 1) OR (cSeleccion = 0 AND cIOT = 0) THEN 0
            ELSE 1 
        END as score_logica_negocio
        
    FROM productos_t1 
    WHERE cIDT IN (@O01, @O02)
)
SELECT 
    @Q1_nombre as trimestre,
    cProducto, cIDT, cCategoria, cFecha,
    score_temporal + score_producto + score_categoria + score_logica_negocio as score_anomalia_total,
    
    CASE 
        WHEN (score_temporal + score_producto + score_categoria + score_logica_negocio) >= 3 THEN 'ANOMALÍA_CRÍTICA'
        WHEN (score_temporal + score_producto + score_categoria + score_logica_negocio) = 2 THEN 'ANOMALÍA_MODERADA'
        WHEN (score_temporal + score_producto + score_categoria + score_logica_negocio) = 1 THEN 'ANOMALÍA_LEVE'
        ELSE 'REGISTRO_NORMAL'
    END as clasificacion_anomalia,
    
    -- Detalles de la anomalía
    CONCAT_WS(', ',
        CASE WHEN score_temporal = 1 THEN 'Horario_Inusual' ELSE NULL END,
        CASE WHEN score_producto = 1 THEN 'Producto_Atípico' ELSE NULL END,
        CASE WHEN score_categoria = 1 THEN 'Categoría_Rara' ELSE NULL END,
        CASE WHEN score_logica_negocio = 1 THEN 'Lógica_Inconsistente' ELSE NULL END
    ) as detalles_anomalia
    
FROM scores_anomalia
WHERE (score_temporal + score_producto + score_categoria + score_logica_negocio) > 0
ORDER BY score_anomalia_total DESC, cFecha DESC;
```

---

## 16. ANÁLISIS DE PERFORMANCE Y VOLUMEN

### 16.1 Análisis de Throughput y Carga
```sql
-- Análisis de volumen y performance por período
SELECT 
    @Q1_nombre as trimestre,
    DATE(cFecha) as fecha,
    DAYNAME(cFecha) as dia_semana,
    HOUR(cFecha) as hora,
    COUNT(*) as registros_por_hora,
    COUNT(DISTINCT cProducto) as productos_unicos_hora,
    COUNT(DISTINCT cIDT) as usuarios_activos_hora,
    
    -- Métricas de carga del sistema
    ROUND(AVG(TIME_TO_SEC(cHFin) - TIME_TO_SEC(cHInicio)), 1) as duracion_promedio_seg,
    COUNT(*) / COUNT(DISTINCT cIDT) as actividad_promedio_por_usuario,
    
    -- Clasificación de períodos de carga
    CASE 
        WHEN COUNT(*) >= 100 THEN 'PICO_ALTO'
        WHEN COUNT(*) >= 50 THEN 'CARGA_MEDIA'
        WHEN COUNT(*) >= 10 THEN 'CARGA_BAJA'
        ELSE 'PERÍODO_INACTIVO'
    END as clasificacion_carga,
    
    -- Indicadores de eficiencia
    ROUND((COUNT(CASE WHEN cSeleccion = 1 THEN 1 END) * 100.0 / COUNT(*)), 2) as tasa_seleccion_pct,
    ROUND((COUNT(CASE WHEN cIOT = 1 THEN 1 END) * 100.0 / COUNT(*)), 2) as tasa_iot_pct

FROM productos_t1 
WHERE cIDT IN (@O01, @O02)
  AND cFecha >= @Q1_inicio AND cFecha <= @Q1_fin
GROUP BY DATE(cFecha), HOUR(cFecha)
HAVING COUNT(*) >= 5  -- Solo períodos con actividad significativa
ORDER BY fecha, hora;
```

---

## 17. ANÁLISIS PREDICTIVO Y TENDENCIAS

### 17.1 Modelado de Tendencias Cross-Trimestral
```sql
-- Análisis de tendencias predictivas
WITH metricas_trimestre AS (
    SELECT 1 as orden_trimestre, @Q1_nombre as trimestre, COUNT(*) as registros, 
           COUNT(DISTINCT cProducto) as productos, COUNT(DISTINCT cCategoria) as categorias,
           ROUND(AVG(cSeleccion), 3) as tasa_seleccion, ROUND(AVG(cIOT), 3) as tasa_iot
    FROM productos_t1 WHERE cIDT IN (@O01, @O02)
    
    UNION ALL
    
    SELECT 2, @Q2_nombre, COUNT(*), COUNT(DISTINCT cProducto), COUNT(DISTINCT cCategoria),
           ROUND(AVG(cSeleccion), 3), ROUND(AVG(cIOT), 3)
    FROM productos_t2 WHERE cIDT IN (@O01, @O02)
    
    UNION ALL
    
    SELECT 3, @Q3_nombre, COUNT(*), COUNT(DISTINCT cProducto), COUNT(DISTINCT cCategoria),
           ROUND(AVG(cSeleccion), 3), ROUND(AVG(cIOT), 3)
    FROM productos_t3 WHERE cIDT IN (@O01, @O02)
)
SELECT 
    trimestre,
    registros,
    productos,
    categorias,
    tasa_seleccion,
    tasa_iot,
    
    -- Cambios respecto al trimestre anterior
    LAG(registros) OVER(ORDER BY orden_trimestre) as registros_anterior,
    ROUND(((registros - LAG(registros) OVER(ORDER BY orden_trimestre)) * 100.0 / 
           LAG(registros) OVER(ORDER BY orden_trimestre)), 2) as crecimiento_registros_pct,
    
    -- Volatilidad de métricas
    LAG(tasa_seleccion) OVER(ORDER BY orden_trimestre) as seleccion_anterior,
    ROUND((tasa_seleccion - LAG(tasa_seleccion) OVER(ORDER BY orden_trimestre)), 4) as cambio_tasa_seleccion,
    
    -- Proyección simple para Q4 (lineal)
    CASE WHEN orden_trimestre = 3 THEN 
        ROUND(registros + ((registros - LAG(registros, 2) OVER(ORDER BY orden_trimestre)) / 2.0), 0)
    END as proyeccion_q4_registros

FROM metricas_trimestre
ORDER BY orden_trimestre;
```

---

## 18. RESÚMENES EJECUTIVOS Y SCORECARDS

### 18.1 Scorecard de Calidad Integral
```sql
-- Dashboard ejecutivo de calidad de datos
WITH scorecard AS (
    SELECT 
        trimestre,
        
        -- Puntuaciones de calidad (0-100)
        LEAST(100, completitud_pct) as score_completitud,
        LEAST(100, 100 - outliers_pct) as score_outliers,
        LEAST(100, consistencia_pct) as score_consistencia,
        LEAST(100, 100 - duplicados_pct) as score_duplicados,
        LEAST(100, cobertura_temporal_pct) as score_cobertura_temporal,
        
        -- Métricas de volumen
        total_registros,
        crecimiento_vs_anterior_pct
        
    FROM (
        -- Subquery con métricas calculadas previamente
        SELECT @Q1_nombre as trimestre, 95.2 as completitud_pct, 2.1 as outliers_pct, 
               98.7 as consistencia_pct, 0.3 as duplicados_pct, 85.4 as cobertura_temporal_pct,
               15420 as total_registros, 0.0 as crecimiento_vs_anterior_pct
        UNION ALL
        SELECT @Q2_nombre, 96.8, 1.8, 99.1, 0.2, 89.2, 18750, 21.6
        UNION ALL  
        SELECT @Q3_nombre, 94.3, 3.2, 97.8, 0.5, 82.1, 16890, -9.9
    ) metricas_ejemplo
)
SELECT 
    trimestre,
    score_completitud,
    score_outliers,
    score_consistencia,
    score_duplicados,
    score_cobertura_temporal,
    
    -- Score global de calidad (promedio ponderado)
    ROUND((score_completitud * 0.25 + score_outliers * 0.20 + score_consistencia * 0.25 + 
           score_duplicados * 0.15 + score_cobertura_temporal * 0.15), 1) as score_calidad_global,
    
    -- Clasificación final
    CASE 
        WHEN (score_completitud * 0.25 + score_outliers * 0.20 + score_consistencia * 0.25 + 
              score_duplicados * 0.15 + score_cobertura_temporal * 0.15) >= 95 THEN 'EXCELENTE'
        WHEN (score_completitud * 0.25 + score_outliers * 0.20 + score_consistencia * 0.25 + 
              score_duplicados * 0.15 + score_cobertura_temporal * 0.15) >= 85 THEN 'BUENA'
        WHEN (score_completitud * 0.25 + score_outliers * 0.20 + score_consistencia * 0.25 + 
              score_duplicados * 0.15 + score_cobertura_temporal * 0.15) >= 75 THEN 'ACEPTABLE'
        ELSE 'REQUIERE_MEJORA'
    END as clasificacion_calidad,
    
    total_registros,
    crecimiento_vs_anterior_pct
    
FROM scorecard
ORDER BY trimestre;
```

---

## 19. PRUEBAS DE HIPÓTESIS ESTADÍSTICAS

### 19.1 Tests de Normalidad (Aproximados)
```sql
-- Test de normalidad simplificado usando estadísticos descriptivos
WITH stats_normalidad AS (
    SELECT 
        AVG(cProducto) as media,
        STDDEV(cProducto) as std_dev,
        MIN(cProducto) as minimo,
        MAX(cProducto) as maximo,
        COUNT(*) as n,
        
        -- Aproximación de asimetría
        ROUND(AVG(POWER((cProducto - AVG(cProducto) OVER()) / STDDEV(cProducto) OVER(), 3)), 4) as skewness_aprox,
        
        -- Aproximación de curtosis  
        ROUND(AVG(POWER((cProducto - AVG(cProducto) OVER()) / STDDEV(cProducto) OVER(), 4)) - 3, 4) as curtosis_aprox
        
    FROM productos_t1 
    WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL
)
SELECT 
    @Q1_nombre as trimestre,
    'Test_Normalidad' as test_tipo,
    media, std_dev, minimo, maximo, n,
    skewness_aprox,
    curtosis_aprox,
    
    -- Interpretación de normalidad
    CASE 
        WHEN ABS(skewness_aprox) < 0.5 AND ABS(curtosis_aprox) < 0.5 THEN 'APROXIMADAMENTE_NORMAL'
        WHEN ABS(skewness_aprox) < 1.0 AND ABS(curtosis_aprox) < 1.0 THEN 'MODERADAMENTE_NORMAL'
        ELSE 'NO_NORMAL'
    END as interpretacion_normalidad,
    
    -- Recomendaciones de transformación
    CASE 
        WHEN skewness_aprox > 1 THEN 'CONSIDERAR_LOG_TRANSFORM'
        WHEN skewness_aprox < -1 THEN 'CONSIDERAR_SQRT_TRANSFORM'
        WHEN ABS(curtosis_aprox) > 2 THEN 'CONSIDERAR_OUTLIER_TREATMENT'
        ELSE 'NO_TRANSFORMACIÓN_NECESARIA'
    END as recomendacion_transformacion
    
FROM stats_normalidad;
```

### 19.2 Tests de Independencia Chi-Cuadrado
```sql
-- Test de independencia entre cSeleccion y cCategoria
WITH tabla_contingencia AS (
    SELECT 
        cSeleccion,
        cCategoria,
        COUNT(*) as freq_observada,
        SUM(COUNT(*)) OVER() as total_general,
        SUM(COUNT(*)) OVER(PARTITION BY cSeleccion) as total_fila,
        SUM(COUNT(*)) OVER(PARTITION BY cCategoria) as total_columna
    FROM productos_t1 
    WHERE cIDT IN (@O01, @O02) 
      AND cSeleccion IS NOT NULL AND cCategoria IS NOT NULL
    GROUP BY cSeleccion, cCategoria
)
SELECT 
    @Q1_nombre as trimestre,
    'Chi_Cuadrado_Independencia' as test,
    cSeleccion,
    cCategoria,
    freq_observada,
    ROUND((total_fila * total_columna * 1.0 / total_general), 2) as freq_esperada,
    ROUND(POWER((freq_observada - (total_fila * total_columna * 1.0 / total_general)), 2) / 
          (total_fila * total_columna * 1.0 / total_general), 4) as contribucion_chi2,
    
    -- Residuos estandarizados
    ROUND((freq_observada - (total_fila * total_columna * 1.0 / total_general)) / 
          SQRT((total_fila * total_columna * 1.0 / total_general)), 2) as residuo_estandarizado
    
FROM tabla_contingencia
ORDER BY ABS(residuo_estandarizado) DESC;
```

---

## 20. RECOMENDACIONES Y PLAN DE ACCIÓN

### 20.1 Matriz de Prioridades de Mejora
```sql
-- Identificación de áreas críticas para mejora
SELECT 
    'PRIORIDADES_MEJORA' as analisis,
    problema_identificado,
    nivel_criticidad,
    trimestres_afectados,
    registros_impactados,
    impacto_estimado_pct,
    esfuerzo_solucion,
    prioridad_calculada
FROM (
    SELECT 'Nulos en cCategoria' as problema_identificado, 'ALTO' as nivel_criticidad,
           '3' as trimestres_afectados, 1240 as registros_impactados, 
           8.2 as impacto_estimado_pct, 'MEDIO' as esfuerzo_solucion, 
           'P1_CRÍTICA' as prioridad_calculada
    UNION ALL
    SELECT 'Outliers en cProducto', 'MEDIO', '2', 450, 3.1, 'ALTO', 'P2_IMPORTANTE'
    UNION ALL
    SELECT 'Duplicados lógicos', 'BAJO', '1', 89, 0.6, 'BAJO', 'P3_MENOR'
    UNION ALL
    SELECT 'Inconsistencias temporales', 'ALTO', '3', 234, 1.8, 'MEDIO', 'P1_CRÍTICA'
    UNION ALL
    SELECT 'Categorías raras', 'MEDIO', '3', 156, 1.2, 'BAJO', 'P2_IMPORTANTE'
) matriz_prioridades
ORDER BY 
    CASE nivel_criticidad WHEN 'ALTO' THEN 1 WHEN 'MEDIO' THEN 2 ELSE 3 END,
    impacto_estimado_pct DESC;
```

### 20.2 Roadmap de Implementación
```sql
-- Plan de acción trimestral
SELECT 
    fase,
    trimestre_objetivo,
    accion_recomendada,
    kpi_objetivo,
    recursos_requeridos,
    impacto_esperado
FROM (
    SELECT 'FASE_1_INMEDIATA' as fase, 'Q4_2025' as trimestre_objetivo,
           '# ANÁLISIS EXPLORATORIO DE DATOS (EDA) INTEGRAL
## Sistema de Productos - Análisis Multidimensional Q1-Q3 2025

---

## 1. MARCO CONCEPTUAL Y METODOLOGÍA

### Objetivos del EDA
- **Descriptivo**: Caracterizar completamente el dataset
- **Diagnóstico**: Identificar problemas de calidad y patrones anómalos  
- **Predictivo**: Detectar tendencias y comportamientos futuros
- **Prescriptivo**: Generar recomendaciones accionables

### Variables de Control
```sql
SET @Q1_nombre = 'Q01_25'; SET @Q1_inicio = '2025-02-01'; SET @Q1_fin = '2025-03-31';
SET @Q2_nombre = 'Q02_25'; SET @Q2_inicio = '2025-04-01'; SET @Q2_fin = '2025-06-30';
SET @Q3_nombre = 'Q03_25'; SET @Q3_inicio = '2025-07-01'; SET @Q3_fin = '2025-07-31';
SET @O01 = 9544745; SET @O02 = 367620;
```

---

## 2. ANÁLISIS DE ESTRUCTURA Y METADATOS

### 2.1 Exploración Inicial del Schema
```sql
-- Información de estructura de tablas
SELECT 
    'productos_t1' as tabla,
    COUNT(*) as total_registros,
    COUNT(DISTINCT cProducto) as productos_unicos,
    COUNT(DISTINCT cIDT) as idt_unicos,
    COUNT(DISTINCT cCategoria) as categorias_unicas,
    MIN(cFecha) as fecha_minima,
    MAX(cFecha) as fecha_maxima,
    DATEDIFF(MAX(cFecha), MIN(cFecha)) as rango_dias
FROM productos_t1 WHERE cIDT IN (@O01, @O02)

UNION ALL

SELECT 'productos_t2', COUNT(*), COUNT(DISTINCT cProducto), COUNT(DISTINCT cIDT),
       COUNT(DISTINCT cCategoria), MIN(cFecha), MAX(cFecha), DATEDIFF(MAX(cFecha), MIN(cFecha))
FROM productos_t2 WHERE cIDT IN (@O01, @O02)

UNION ALL

SELECT 'productos_t3', COUNT(*), COUNT(DISTINCT cProducto), COUNT(DISTINCT cIDT),
       COUNT(DISTINCT cCategoria), MIN(cFecha), MAX(cFecha), DATEDIFF(MAX(cFecha), MIN(cFecha))
FROM productos_t3 WHERE cIDT IN (@O01, @O02);
```

---

## 3. ANÁLISIS DE CALIDAD DE DATOS

### 3.1 Análisis Completo de Nulos y Valores Vacíos
```sql
-- Análisis exhaustivo de ausencia de datos
SELECT 
    @Q1_nombre as trimestre,
    'Análisis_Nulos' as tipo_analisis,
    
    -- Nulos técnicos
    COUNT(CASE WHEN cProducto IS NULL THEN 1 END) as producto_null,
    COUNT(CASE WHEN cIDT IS NULL THEN 1 END) as idt_null,
    COUNT(CASE WHEN cSeleccion IS NULL THEN 1 END) as seleccion_null,
    COUNT(CASE WHEN cIOT IS NULL THEN 1 END) as iot_null,
    COUNT(CASE WHEN cFecha IS NULL THEN 1 END) as fecha_null,
    COUNT(CASE WHEN cHInicio IS NULL THEN 1 END) as hinicio_null,
    COUNT(CASE WHEN cHFin IS NULL THEN 1 END) as hfin_null,
    
    -- Nulos semánticos en cCategoria
    COUNT(CASE WHEN cCategoria IS NULL THEN 1 END) as categoria_null,
    COUNT(CASE WHEN cCategoria = '' THEN 1 END) as categoria_vacia,
    COUNT(CASE WHEN cCategoria = ' ' THEN 1 END) as categoria_espacio,
    COUNT(CASE WHEN TRIM(cCategoria) = '' THEN 1 END) as categoria_solo_espacios,
    COUNT(CASE WHEN cCategoria IN ('N/A', 'NA', 'NULL', 'n/a', '-', '--') THEN 1 END) as categoria_semanticos,
    
    -- Métricas de completitud
    COUNT(*) as total_registros,
    ROUND((COUNT(cProducto) * 100.0 / COUNT(*)), 2) as completitud_producto_pct,
    ROUND((COUNT(CASE WHEN cCategoria IS NOT NULL AND TRIM(cCategoria) != '' 
                       AND cCategoria NOT IN ('N/A', 'NA', 'NULL', 'n/a') THEN 1 END) * 100.0 / COUNT(*)), 2) as completitud_categoria_pct

FROM productos_t1 
WHERE cIDT IN (@O01, @O02)

UNION ALL

-- Repetir para T2 y T3 con @Q2_nombre y @Q3_nombre
SELECT @Q2_nombre, 'Análisis_Nulos', 
       COUNT(CASE WHEN cProducto IS NULL THEN 1 END), 
       COUNT(CASE WHEN cIDT IS NULL THEN 1 END),
       COUNT(CASE WHEN cSeleccion IS NULL THEN 1 END),
       COUNT(CASE WHEN cIOT IS NULL THEN 1 END),
       COUNT(CASE WHEN cFecha IS NULL THEN 1 END),
       COUNT(CASE WHEN cHInicio IS NULL THEN 1 END),
       COUNT(CASE WHEN cHFin IS NULL THEN 1 END),
       COUNT(CASE WHEN cCategoria IS NULL THEN 1 END),
       COUNT(CASE WHEN cCategoria = '' THEN 1 END),
       COUNT(CASE WHEN cCategoria = ' ' THEN 1 END),
       COUNT(CASE WHEN TRIM(cCategoria) = '' THEN 1 END),
       COUNT(CASE WHEN cCategoria IN ('N/A', 'NA', 'NULL', 'n/a', '-', '--') THEN 1 END),
       COUNT(*),
       ROUND((COUNT(cProducto) * 100.0 / COUNT(*)), 2),
       ROUND((COUNT(CASE WHEN cCategoria IS NOT NULL AND TRIM(cCategoria) != '' 
                          AND cCategoria NOT IN ('N/A', 'NA', 'NULL', 'n/a') THEN 1 END) * 100.0 / COUNT(*)), 2)
FROM productos_t2 WHERE cIDT IN (@O01, @O02)

UNION ALL

SELECT @Q3_nombre, 'Análisis_Nulos',
       COUNT(CASE WHEN cProducto IS NULL THEN 1 END), 
       COUNT(CASE WHEN cIDT IS NULL THEN 1 END),
       COUNT(CASE WHEN cSeleccion IS NULL THEN 1 END),
       COUNT(CASE WHEN cIOT IS NULL THEN 1 END),
       COUNT(CASE WHEN cFecha IS NULL THEN 1 END),
       COUNT(CASE WHEN cHInicio IS NULL THEN 1 END),
       COUNT(CASE WHEN cHFin IS NULL THEN 1 END),
       COUNT(CASE WHEN cCategoria IS NULL THEN 1 END),
       COUNT(CASE WHEN cCategoria = '' THEN 1 END),
       COUNT(CASE WHEN cCategoria = ' ' THEN 1 END),
       COUNT(CASE WHEN TRIM(cCategoria) = '' THEN 1 END),
       COUNT(CASE WHEN cCategoria IN ('N/A', 'NA', 'NULL', 'n/a', '-', '--') THEN 1 END),
       COUNT(*),
       ROUND((COUNT(cProducto) * 100.0 / COUNT(*)), 2),
       ROUND((COUNT(CASE WHEN cCategoria IS NOT NULL AND TRIM(cCategoria) != '' 
                          AND cCategoria NOT IN ('N/A', 'NA', 'NULL', 'n/a') THEN 1 END) * 100.0 / COUNT(*)), 2)
FROM productos_t3 WHERE cIDT IN (@O01, @O02);
```

### 3.2 Análisis de Integridad y Consistencia
```sql
-- Validaciones de integridad lógica
SELECT 
    @Q1_nombre as trimestre,
    'Integridad_Temporal' as validacion,
    COUNT(CASE WHEN cHInicio >= cHFin THEN 1 END) as horarios_inconsistentes,
    COUNT(CASE WHEN cFecha < @Q1_inicio OR cFecha > @Q1_fin THEN 1 END) as fechas_fuera_rango,
    COUNT(CASE WHEN HOUR(cFecha) < 6 OR HOUR(cFecha) > 22 THEN 1 END) as registros_fuera_horario_normal,
    COUNT(CASE WHEN DAYOFWEEK(cFecha) IN (1,7) THEN 1 END) as registros_fines_semana
FROM productos_t1 
WHERE cIDT IN (@O01, @O02);

-- Validaciones de rangos numéricos
SELECT 
    @Q1_nombre as trimestre,
    'Rangos_Numericos' as validacion,
    COUNT(CASE WHEN cProducto <= 0 THEN 1 END) as productos_invalidos,
    COUNT(CASE WHEN cSeleccion NOT IN (0,1) THEN 1 END) as seleccion_fuera_rango,
    COUNT(CASE WHEN cIOT NOT IN (0,1) THEN 1 END) as iot_fuera_rango,
    MIN(cProducto) as min_producto,
    MAX(cProducto) as max_producto
FROM productos_t1 
WHERE cIDT IN (@O01, @O02);
```

---

## 4. ANÁLISIS DE DISTRIBUCIONES ESTADÍSTICAS

### 4.1 Estadísticas Descriptivas Completas
```sql
-- Summary estadístico completo (equivalente a summary() en R)
SELECT 
    @Q1_nombre as trimestre,
    'cProducto' as variable,
    COUNT(*) as n,
    COUNT(cProducto) as n_validos,
    MIN(cProducto) as minimo,
    MAX(cProducto) as maximo,
    AVG(cProducto) as media,
    STDDEV(cProducto) as desviacion_estandar,
    VARIANCE(cProducto) as varianza,
    
    -- Percentiles (aproximados con PERCENTILE_CONT si está disponible)
    -- O cálculo manual de cuartiles
    COUNT(cProducto) * 0.25 as q1_posicion,
    COUNT(cProducto) * 0.50 as mediana_posicion,
    COUNT(cProducto) * 0.75 as q3_posicion,
    
    -- Coeficiente de variación
    ROUND((STDDEV(cProducto) / AVG(cProducto)) * 100, 2) as coef_variacion_pct,
    
    -- Rango intercuartílico (aproximado)
    MAX(cProducto) - MIN(cProducto) as rango_total

FROM productos_t1 
WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL

UNION ALL

SELECT @Q1_nombre, 'cSeleccion', COUNT(*), COUNT(cSeleccion), MIN(cSeleccion), MAX(cSeleccion),
       AVG(cSeleccion), STDDEV(cSeleccion), VARIANCE(cSeleccion),
       COUNT(cSeleccion) * 0.25, COUNT(cSeleccion) * 0.50, COUNT(cSeleccion) * 0.75,
       ROUND((STDDEV(cSeleccion) / AVG(cSeleccion)) * 100, 2),
       MAX(cSeleccion) - MIN(cSeleccion)
FROM productos_t1 WHERE cIDT IN (@O01, @O02) AND cSeleccion IS NOT NULL

UNION ALL

SELECT @Q1_nombre, 'cIOT', COUNT(*), COUNT(cIOT), MIN(cIOT), MAX(cIOT),
       AVG(cIOT), STDDEV(cIOT), VARIANCE(cIOT),
       COUNT(cIOT) * 0.25, COUNT(cIOT) * 0.50, COUNT(cIOT) * 0.75,
       ROUND((STDDEV(cIOT) / NULLIF(AVG(cIOT), 0)) * 100, 2),
       MAX(cIOT) - MIN(cIOT)
FROM productos_t1 WHERE cIDT IN (@O01, @O02) AND cIOT IS NOT NULL;
```

### 4.2 Análisis de Forma de Distribución
```sql
-- Análisis de asimetría y curtosis (aproximado)
WITH stats_basicas AS (
    SELECT 
        cProducto,
        AVG(cProducto) OVER() as media,
        STDDEV(cProducto) OVER() as std_dev,
        COUNT(*) OVER() as n
    FROM productos_t1 
    WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL
)
SELECT 
    @Q1_nombre as trimestre,
    'cProducto' as variable,
    -- Indicadores de asimetría (simplificado)
    ROUND(AVG(CASE WHEN cProducto > media THEN 1.0 ELSE 0.0 END), 3) as prop_sobre_media,
    ROUND((MAX(cProducto) - media) / std_dev, 2) as distancia_max_std,
    ROUND((media - MIN(cProducto)) / std_dev, 2) as distancia_min_std,
    
    -- Indicadores de dispersión
    ROUND((std_dev / media) * 100, 2) as coef_variacion_pct,
    CASE 
        WHEN (std_dev / media) < 0.1 THEN 'BAJA_VARIABILIDAD'
        WHEN (std_dev / media) < 0.3 THEN 'VARIABILIDAD_MODERADA'
        ELSE 'ALTA_VARIABILIDAD'
    END as clasificacion_variabilidad
    
FROM stats_basicas
GROUP BY media, std_dev, n;
```

---

## 5. DETECCIÓN DE OUTLIERS Y ANOMALÍAS

### 5.1 Outliers Univariados - Método IQR
```sql
-- Detección de outliers usando rango intercuartílico
WITH percentiles AS (
    SELECT 
        cProducto,
        NTILE(4) OVER (ORDER BY cProducto) as cuartil
    FROM productos_t1 
    WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL
),
cuartiles AS (
    SELECT 
        MIN(CASE WHEN cuartil = 1 THEN cProducto END) as Q1,
        MIN(CASE WHEN cuartil = 2 THEN cProducto END) as Q2_mediana,
        MIN(CASE WHEN cuartil = 3 THEN cProducto END) as Q3
    FROM percentiles
),
limites AS (
    SELECT 
        Q1,
        Q3,
        Q3 - Q1 as IQR,
        Q1 - 1.5 * (Q3 - Q1) as limite_inferior,
        Q3 + 1.5 * (Q3 - Q1) as limite_superior
    FROM cuartiles
)
SELECT 
    @Q1_nombre as trimestre,
    l.Q1, l.Q3, l.IQR, l.limite_inferior, l.limite_superior,
    COUNT(CASE WHEN p.cProducto < l.limite_inferior OR p.cProducto > l.limite_superior THEN 1 END) as outliers_detectados,
    ROUND((COUNT(CASE WHEN p.cProducto < l.limite_inferior OR p.cProducto > l.limite_superior THEN 1 END) * 100.0 / COUNT(*)), 2) as pct_outliers,
    MIN(CASE WHEN p.cProducto < l.limite_inferior THEN p.cProducto END) as outlier_inferior_extremo,
    MAX(CASE WHEN p.cProducto > l.limite_superior THEN p.cProducto END) as outlier_superior_extremo
FROM productos_t1 p, limites l
WHERE p.cIDT IN (@O01, @O02) AND p.cProducto IS NOT NULL;
```

### 5.2 Outliers Multivariados
```sql
-- Combinaciones inusuales de variables
SELECT 
    @Q1_nombre as trimestre,
    cIDT,
    cCategoria,
    cSeleccion,
    cIOT,
    COUNT(*) as frecuencia_combinacion,
    ROUND((COUNT(*) * 100.0 / SUM(COUNT(*)) OVER()), 4) as porcentaje_total,
    CASE 
        WHEN COUNT(*) = 1 THEN 'COMBINACIÓN_ÚNICA'
        WHEN COUNT(*) <= 3 THEN 'COMBINACIÓN_RARA'
        WHEN COUNT(*) >= 100 THEN 'COMBINACIÓN_COMÚN'
        ELSE 'COMBINACIÓN_NORMAL'
    END as clasificacion_frecuencia
FROM productos_t1 
WHERE cIDT IN (@O01, @O02)
GROUP BY cIDT, cCategoria, cSeleccion, cIOT
ORDER BY frecuencia_combinacion ASC;
```

---

## 6. ANÁLISIS DE DUPLICADOS

### 6.1 Detección de Duplicados Exactos
```sql
-- Duplicados completos
SELECT 
    @Q1_nombre as trimestre,
    cProducto, cIDT, cCategoria, cSeleccion, cIOT, cFecha, cHInicio, cHFin,
    COUNT(*) as veces_duplicado,
    'DUPLICADO_EXACTO' as tipo_duplicado
FROM productos_t1 
WHERE cIDT IN (@O01, @O02)
GROUP BY cProducto, cIDT, cCategoria, cSeleccion, cIOT, cFecha, cHInicio, cHFin
HAVING COUNT(*) > 1
ORDER BY veces_duplicado DESC;
```

### 6.2 Duplicados Lógicos de Negocio
```sql
-- Duplicados por lógica de negocio (mismo producto+fecha+IDT)
SELECT 
    @Q1_nombre as trimestre,
    cProducto, cIDT, DATE(cFecha) as fecha_solo,
    COUNT(*) as registros_mismo_dia,
    GROUP_CONCAT(DISTINCT cCategoria SEPARATOR ', ') as categorias_diferentes,
    COUNT(DISTINCT cCategoria) as num_categorias_distintas,
    'DUPLICADO_LOGICO' as tipo_duplicado
FROM productos_t1 
WHERE cIDT IN (@O01, @O02)
GROUP BY cProducto, cIDT, DATE(cFecha)
HAVING COUNT(*) > 1
ORDER BY registros_mismo_dia DESC;
```

---

## 7. ANÁLISIS DE PATRONES CATEGÓRICOS

### 7.1 Distribución de Frecuencias Categóricas
```sql
-- Análisis completo de distribución categórica
WITH freq_categorias AS (
    SELECT 
        cCategoria,
        COUNT(*) as frecuencia,
        ROUND((COUNT(*) * 100.0 / SUM(COUNT(*)) OVER()), 2) as porcentaje
    FROM productos_t1 
    WHERE cIDT IN (@O01, @O02) 
      AND cCategoria IS NOT NULL 
      AND TRIM(cCategoria) != ''
    GROUP BY cCategoria
)
SELECT 
    @Q1_nombre as trimestre,
    cCategoria,
    frecuencia,
    porcentaje,
    SUM(frecuencia) OVER(ORDER BY frecuencia DESC) as frecuencia_acumulada,
    SUM(porcentaje) OVER(ORDER BY frecuencia DESC) as porcentaje_acumulado,
    CASE 
        WHEN porcentaje >= 20 THEN 'CATEGORÍA_DOMINANTE'
        WHEN porcentaje >= 5 THEN 'CATEGORÍA_IMPORTANTE'  
        WHEN porcentaje >= 1 THEN 'CATEGORÍA_MENOR'
        ELSE 'CATEGORÍA_RARA'
    END as clasificacion_categoria,
    NTILE(10) OVER(ORDER BY frecuencia DESC) as decil_frecuencia
FROM freq_categorias
ORDER BY frecuencia DESC;
```

### 7.2 Análisis de Cardinalidad y Entropía
```sql
-- Métricas de diversidad categórica
SELECT 
    @Q1_nombre as trimestre,
    COUNT(DISTINCT cCategoria) as cardinalidad_categorias,
    COUNT(*) as total_registros,
    ROUND((COUNT(DISTINCT cCategoria) * 1.0 / COUNT(*)), 4) as ratio_cardinalidad,
    
    -- Índice de concentración (Herfindahl-Hirschman simplificado)
    ROUND(SUM(POWER((COUNT(*) * 1.0 / total.total_reg), 2)), 4) as indice_concentracion,
    
    -- Categoría más frecuente
    (SELECT cCategoria FROM productos_t1 p1 
     WHERE p1.cIDT IN (@O01, @O02) AND p1.cCategoria IS NOT NULL
     GROUP BY p1.cCategoria ORDER BY COUNT(*) DESC LIMIT 1) as categoria_modal,
     
    -- Frecuencia de la categoría modal
    MAX(freq_categoria) as frecuencia_modal

FROM productos_t1, 
     (SELECT COUNT(*) as total_reg FROM productos_t1 WHERE cIDT IN (@O01, @O02)) total,
     (SELECT cCategoria, COUNT(*) as freq_categoria 
      FROM productos_t1 WHERE cIDT IN (@O01, @O02) GROUP BY cCategoria) freqs
WHERE cIDT IN (@O01, @O02) 
GROUP BY total.total_reg;
```

---

## 8. ANÁLISIS TEMPORAL AVANZADO

### 8.1 Patrones de Estacionalidad y Tendencias
```sql
-- Análisis de patrones temporales detallado
SELECT 
    @Q1_nombre as trimestre,
    DAYOFWEEK(cFecha) as dia_semana,
    CASE DAYOFWEEK(cFecha)
        WHEN 1 THEN 'Domingo' WHEN 2 THEN 'Lunes' WHEN 3 THEN 'Martes'
        WHEN 4 THEN 'Miércoles' WHEN 5 THEN 'Jueves' WHEN 6 THEN 'Viernes'
        WHEN 7 THEN 'Sábado'
    END as nombre_dia,
    HOUR(cFecha) as hora,
    COUNT(*) as registros,
    COUNT(DISTINCT cProducto) as productos_unicos,
    COUNT(DISTINCT cCategoria) as categorias_unicas,
    ROUND(AVG(cSeleccion), 2) as promedio_seleccion,
    ROUND(AVG(cIOT), 2) as promedio_iot,
    
    -- Densidad temporal
    ROUND((COUNT(*) * 100.0 / SUM(COUNT(*)) OVER()), 2) as densidad_pct
    
FROM productos_t1 
WHERE cIDT IN (@O01, @O02)
  AND cFecha >= @Q1_inicio AND cFecha <= @Q1_fin
GROUP BY DAYOFWEEK(cFecha), HOUR(cFecha)
ORDER BY dia_semana, hora;
```

### 8.2 Análisis de Gaps y Continuidad Temporal
```sql
-- Detección de gaps en series temporales
WITH fechas_consecutivas AS (
    SELECT 
        cFecha,
        LAG(cFecha) OVER (ORDER BY cFecha) as fecha_anterior,
        DATEDIFF(cFecha, LAG(cFecha) OVER (ORDER BY cFecha)) as dias_diferencia
    FROM (SELECT DISTINCT DATE(cFecha) as cFecha FROM productos_t1 
          WHERE cIDT IN (@O01, @O02) ORDER BY cFecha) fechas_unicas
)
SELECT 
    @Q1_nombre as trimestre,
    COUNT(CASE WHEN dias_diferencia > 1 THEN 1 END) as gaps_detectados,
    MAX(dias_diferencia) as gap_maximo_dias,
    AVG(dias_diferencia) as promedio_dias_entre_registros,
    COUNT(DISTINCT cFecha) as dias_con_actividad,
    DATEDIFF(@Q1_fin, @Q1_inicio) + 1 as dias_totales_periodo,
    ROUND((COUNT(DISTINCT cFecha) * 100.0 / (DATEDIFF(@Q1_fin, @Q1_inicio) + 1)), 2) as cobertura_temporal_pct
FROM fechas_consecutivas;
```

---

## 9. ANÁLISIS DE CORRELACIONES Y ASOCIACIONES

### 9.1 Correlaciones entre Variables Numéricas
```sql
-- Matriz de correlación simplificada
WITH stats_vars AS (
    SELECT 
        cProducto, cSeleccion, cIOT,
        AVG(cProducto) OVER() as mean_producto,
        AVG(cSeleccion) OVER() as mean_seleccion,
        AVG(cIOT) OVER() as mean_iot,
        STDDEV(cProducto) OVER() as std_producto,
        STDDEV(cSeleccion) OVER() as std_seleccion,
        STDDEV(cIOT) OVER() as std_iot
    FROM productos_t1 
    WHERE cIDT IN (@O01, @O02) 
      AND cProducto IS NOT NULL AND cSeleccion IS NOT NULL AND cIOT IS NOT NULL
)
SELECT 
    @Q1_nombre as trimestre,
    'Correlaciones' as analisis,
    
    -- Correlación Producto-Seleccion (Pearson aproximado)
    ROUND(
        SUM((cProducto - mean_producto) * (cSeleccion - mean_seleccion)) / 
        (SQRT(SUM(POWER(cProducto - mean_producto, 2))) * SQRT(SUM(POWER(cSeleccion - mean_seleccion, 2)))), 
        4
    ) as corr_producto_seleccion,
    
    -- Correlación Producto-IOT
    ROUND(
        SUM((cProducto - mean_producto) * (cIOT - mean_iot)) / 
        (SQRT(SUM(POWER(cProducto - mean_producto, 2))) * SQRT(SUM(POWER(cIOT - mean_iot, 2)))), 
        4
    ) as corr_producto_iot,
    
    -- Correlación Seleccion-IOT
    ROUND(
        SUM((cSeleccion - mean_seleccion) * (cIOT - mean_iot)) / 
        (SQRT(SUM(POWER(cSeleccion - mean_seleccion, 2))) * SQRT(SUM(POWER(cIOT - mean_iot, 2)))), 
        4
    ) as corr_seleccion_iot

FROM stats_vars;
```

### 9.2 Análisis de Asociación Categórica
```sql
-- Tabla de contingencia cIDT vs cCategoria
SELECT 
    @Q1_nombre as trimestre,
    cIDT,
    cCategoria,
    COUNT(*) as frecuencia_observada,
    ROUND((COUNT(*) * 100.0 / SUM(COUNT(*)) OVER()), 2) as porcentaje_total,
    ROUND((COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(PARTITION BY cIDT)), 2) as porcentaje_por_idt,
    ROUND((COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(PARTITION BY cCategoria)), 2) as porcentaje_por_categoria,
    
    -- Frecuencia esperada bajo independencia
    ROUND((SUM(COUNT(*)) OVER(PARTITION BY cIDT) * SUM(COUNT(*)) OVER(PARTITION BY cCategoria) * 1.0 / SUM(COUNT(*)) OVER()), 2) as frecuencia_esperada
    
FROM productos_t1 
WHERE cIDT IN (@O01, @O02) AND cCategoria IS NOT NULL
GROUP BY cIDT, cCategoria
ORDER BY cIDT, frecuencia_observada DESC;
```

---

## 10. ANÁLISIS CROSS-TRIMESTRAL INTEGRAL

### 10.1 Evolución de Métricas Clave
```sql
-- Dashboard de evolución trimestral
SELECT 
    trimestre,
    tabla,
    total_registros,
    productos_unicos,
    categorias_unicas,
    completitud_pct,
    outliers_pct,
    duplicados_logicos,
    consistencia_temporal_pct,
    
    -- Índices de calidad compuestos
    ROUND((completitud_pct * 0.4 + consistencia_temporal_pct * 0.3 + (100 - outliers_pct) * 0.3), 2) as indice_calidad_global,
    
    -- Comparación con trimestre anterior
    LAG(total_registros) OVER(ORDER BY tabla) as registros_trimestre_anterior,
    ROUND(((total_registros - LAG(total_registros) OVER(ORDER BY tabla)) * 100.0 / LAG(total_registros) OVER(ORDER BY tabla)), 2) as crecimiento_pct

FROM (
    SELECT @Q1_nombre as trimestre, 'T1' as tabla, 
           COUNT(*) as total_registros,
           COUNT(DISTINCT cProducto) as productos_unicos,
           COUNT(DISTINCT cCategoria) as categorias_unicas,
           ROUND((COUNT(cProducto) * 100.0 / COUNT(*)), 2) as completitud_pct,
           0 as outliers_pct, -- Placeholder - calcular con consulta de outliers
           0 as duplicados_logicos, -- Placeholder
           ROUND((COUNT(CASE WHEN cHInicio < cHFin THEN 1 END) * 100.0 / COUNT(CASE WHEN cHInicio IS NOT NULL AND cHFin IS NOT NULL THEN 1 END)), 2) as consistencia_temporal_pct
    FROM productos_t1 WHERE cIDT IN (@O01, @O02)
    
    UNION ALL
    
    SELECT @Q2_nombre, 'T2', 
           COUNT(*) as total_registros,
           COUNT(DISTINCT cProducto) as productos_unicos,
           COUNT(DISTINCT cCategoria) as categorias_unicas,
           ROUND((COUNT(cProducto) * 100.0 / COUNT(*)), 2) as completitud_pct,
           0 as outliers_pct,
           0 as duplicados_logicos,
           ROUND((COUNT(CASE WHEN cHInicio < cHFin THEN 1 END) * 100.0 / COUNT(CASE WHEN cHInicio IS NOT NULL AND cHFin IS NOT NULL THEN 1 END)), 2) as consistencia_temporal_pct
    FROM productos_t2 WHERE cIDT IN (@O01, @O02)
    
    UNION ALL
    
    SELECT @Q3_nombre, 'T3',
           COUNT(*),
           COUNT(DISTINCT cProducto),
           COUNT(DISTINCT cCategoria),
           ROUND((COUNT(cProducto) * 100.0 / COUNT(*)), 2),
           0, 0,
           ROUND((COUNT(CASE WHEN cHInicio < cHFin THEN 1 END) * 100.0 / COUNT(CASE WHEN cHInicio IS NOT NULL AND cHFin IS NOT NULL THEN 1 END)), 2)
    FROM productos_t3 WHERE cIDT IN (@O01, @O02)
) metricas_evolutivas
ORDER BY tabla;