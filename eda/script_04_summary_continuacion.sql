WHEN AVG(cIOT) BETWEEN 0.4 AND 0.6 THEN 'DISTRIBUCIÓN_BALANCEADA'
        WHEN AVG(cIOT) < 0.8 THEN 'PREDOMINIO_1_MODERADO'
        ELSE 'PREDOMINIO_1_FUERTE'
    END
FROM productos_t2 WHERE cIDT IN (@O01, @O02)

UNION ALL

SELECT 
    @Q3_nombre, 'cIOT', COUNT(*), COUNT(cIOT), COUNT(*) - COUNT(cIOT),
    ROUND((COUNT(cIOT) * 100.0 / COUNT(*)), 2),
    MIN(cIOT), MAX(cIOT),
    COUNT(CASE WHEN cIOT = 0 THEN 1 END), COUNT(CASE WHEN cIOT = 1 THEN 1 END),
    ROUND((COUNT(CASE WHEN cIOT = 0 THEN 1 END) * 100.0 / COUNT(cIOT)), 2),
    ROUND((COUNT(CASE WHEN cIOT = 1 THEN 1 END) * 100.0 / COUNT(cIOT)), 2),
    ROUND(AVG(cIOT), 4), ROUND(STDDEV(cIOT), 4), ROUND(VARIANCE(cIOT), 4),
    
    CASE 
        WHEN COUNT(CASE WHEN cIOT = 1 THEN 1 END) > COUNT(CASE WHEN cIOT = 0 THEN 1 END) THEN 1
        WHEN COUNT(CASE WHEN cIOT = 0 THEN 1 END) > COUNT(CASE WHEN cIOT = 1 THEN 1 END) THEN 0
        ELSE 'BIMODAL'
    END,
    
    CASE 
        WHEN AVG(cIOT) < 0.1 THEN 'PREDOMINIO_0_FUERTE'
        WHEN AVG(cIOT) < 0.3 THEN 'PREDOMINIO_0_MODERADO'
        WHEN AVG(cIOT) BETWEEN 0.4 AND 0.6 THEN 'DISTRIBUCIÓN_BALANCEADA'
        WHEN AVG(cIOT) < 0.8 THEN 'PREDOMINIO_1_MODERADO'
        ELSE 'PREDOMINIO_1_FUERTE'
    END
FROM productos_t3 WHERE cIDT IN (@O01, @O02)

ORDER BY trimestre;

-- ====================================================================
-- RESUMEN COMPARATIVO CROSS-TRIMESTRAL
-- ====================================================================

SELECT 'RESUMEN COMPARATIVO - EVOLUCIÓN ESTADÍSTICA ENTRE TRIMESTRES' as resumen_ejecutivo;

-- Comparación de estadísticas clave entre trimestres
WITH estadisticas_comparativas AS (
    SELECT 
        1 as orden_trimestre,
        @Q1_nombre as trimestre,
        COUNT(*) as registros,
        ROUND(AVG(cProducto), 0) as media_producto,
        ROUND(STDDEV(cProducto), 0) as std_producto,
        ROUND(AVG(cSeleccion), 3) as media_seleccion,
        ROUND(AVG(cIOT), 3) as media_iot,
        COUNT(DISTINCT cProducto) as productos_unicos,
        COUNT(DISTINCT cCategoria) as categorias_unicas
    FROM productos_t1 WHERE cIDT IN (@O01, @O02)
    
    UNION ALL
    
    SELECT 
        2, @Q2_nombre, COUNT(*),
        ROUND(AVG(cProducto), 0), ROUND(STDDEV(cProducto), 0),
        ROUND(AVG(cSeleccion), 3), ROUND(AVG(cIOT), 3),
        COUNT(DISTINCT cProducto), COUNT(DISTINCT cCategoria)
    FROM productos_t2 WHERE cIDT IN (@O01, @O02)
    
    UNION ALL
    
    SELECT 
        3, @Q3_nombre, COUNT(*),
        ROUND(AVG(cProducto), 0), ROUND(STDDEV(cProducto), 0),
        ROUND(AVG(cSeleccion), 3), ROUND(AVG(cIOT), 3),
        COUNT(DISTINCT cProducto), COUNT(DISTINCT cCategoria)
    FROM productos_t3 WHERE cIDT IN (@O01, @O02)
)
SELECT 
    trimestre,
    registros,
    media_producto,
    std_producto,
    media_seleccion,
    media_iot,
    productos_unicos,
    categorias_unicas,
    
    -- ===== COMPARACIONES CON TRIMESTRE ANTERIOR =====
    LAG(registros) OVER(ORDER BY orden_trimestre) as registros_anterior,
    ROUND(((registros - LAG(registros) OVER(ORDER BY orden_trimestre)) * 100.0 / 
           NULLIF(LAG(registros) OVER(ORDER BY orden_trimestre), 0)), 2) as crecimiento_registros_pct,
    
    LAG(media_producto) OVER(ORDER BY orden_trimestre) as media_producto_anterior,
    ROUND((media_producto - LAG(media_producto) OVER(ORDER BY orden_trimestre)), 0) as cambio_media_producto,
    
    LAG(media_seleccion) OVER(ORDER BY orden_trimestre) as media_seleccion_anterior,
    ROUND((media_seleccion - LAG(media_seleccion) OVER(ORDER BY orden_trimestre)), 4) as cambio_media_seleccion,
    
    -- ===== ANÁLISIS DE TENDENCIAS =====
    CASE 
        WHEN LAG(media_producto) OVER(ORDER BY orden_trimestre) IS NULL THEN 'BASELINE'
        WHEN media_producto > LAG(media_producto) OVER(ORDER BY orden_trimestre) * 1.05 THEN 'TENDENCIA_CRECIENTE'
        WHEN media_producto < LAG(media_producto) OVER(ORDER BY orden_trimestre) * 0.95 THEN 'TENDENCIA_DECRECIENTE'
        ELSE 'TENDENCIA_ESTABLE'
    END as tendencia_producto,
    
    CASE 
        WHEN LAG(media_seleccion) OVER(ORDER BY orden_trimestre) IS NULL THEN 'BASELINE'
        WHEN ABS(media_seleccion - LAG(media_seleccion) OVER(ORDER BY orden_trimestre)) > 0.05 THEN 'CAMBIO_SIGNIFICATIVO'
        ELSE 'ESTABLE'
    END as tendencia_seleccion
    
FROM estadisticas_comparativas
ORDER BY orden_trimestre;

-- ====================================================================
-- ANÁLISIS DE DISTRIBUCIÓN POR RANGOS (HISTOGRAMA APROXIMADO)
-- ====================================================================

SELECT 'DISTRIBUCIÓN POR RANGOS - HISTOGRAMA APROXIMADO cPRODUCTO' as histograma;

-- Histograma de distribución para cProducto
SELECT 
    @Q1_nombre as trimestre,
    CASE 
        WHEN cProducto IS NULL THEN 'NULL'
        WHEN cProducto < 1000000 THEN 'Rango_1: <1M'
        WHEN cProducto < 5000000 THEN 'Rango_2: 1M-5M'
        WHEN cProducto < 10000000 THEN 'Rango_3: 5M-10M'
        WHEN cProducto < 50000000 THEN 'Rango_4: 10M-50M'
        ELSE 'Rango_5: >50M'
    END as rango_producto,
    COUNT(*) as frecuencia,
    ROUND((COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(PARTITION BY 1)), 2) as porcentaje,
    SUM(COUNT(*)) OVER(PARTITION BY 1 ORDER BY 
        CASE 
            WHEN cProducto IS NULL THEN 0
            WHEN cProducto < 1000000 THEN 1
            WHEN cProducto < 5000000 THEN 2
            WHEN cProducto < 10000000 THEN 3
            WHEN cProducto < 50000000 THEN 4
            ELSE 5
        END ROWS UNBOUNDED PRECEDING) as frecuencia_acumulada
FROM productos_t1 
WHERE cIDT IN (@O01, @O02)
GROUP BY rango_producto
ORDER BY 
    CASE 
        WHEN cProducto IS NULL THEN 0
        WHEN cProducto < 1000000 THEN 1
        WHEN cProducto < 5000000 THEN 2
        WHEN cProducto < 10000000 THEN 3
        WHEN cProducto < 50000000 THEN 4
        ELSE 5
    END;

-- ====================================================================
-- ANÁLISIS FINAL - DASHBOARD ESTADÍSTICO EJECUTIVO
-- ====================================================================

SELECT 'DASHBOARD ESTADÍSTICO EJECUTIVO - MÉTRICAS CLAVE CROSS-TRIMESTRAL' as dashboard_final;

-- Dashboard consolidado de métricas estadísticas clave
SELECT 
    'RESUMEN_ESTADÍSTICO_EJECUTIVO' as tipo_reporte,
    SUM(CASE WHEN trimestre = @Q1_nombre THEN registros ELSE 0 END) as total_registros_q1,
    SUM(CASE WHEN trimestre = @Q2_nombre THEN registros ELSE 0 END) as total_registros_q2,
    SUM(CASE WHEN trimestre = @Q3_nombre THEN registros ELSE 0 END) as total_registros_q3,
    SUM(registros) as gran_total_registros,
    
    -- Medias por trimestre
    ROUND(AVG(CASE WHEN trimestre = @Q1_nombre THEN media_producto END), 0) as media_producto_q1,
    ROUND(AVG(CASE WHEN trimestre = @Q2_nombre THEN media_producto END), 0) as media_producto_q2,
    ROUND(AVG(CASE WHEN trimestre = @Q3_nombre THEN media_producto END), 0) as media_producto_q3,
    
    -- Tasas de selección por trimestre
    ROUND(AVG(CASE WHEN trimestre = @Q1_nombre THEN media_seleccion END), 3) as tasa_seleccion_q1,
    ROUND(AVG(CASE WHEN trimestre = @Q2_nombre THEN media_seleccion END), 3) as tasa_seleccion_q2,
    ROUND(AVG(CASE WHEN trimestre = @Q3_nombre THEN media_seleccion END), 3) as tasa_seleccion_q3,
    
    -- Indicadores de estabilidad
    ROUND(STDDEV(media_producto), 0) as volatilidad_media_producto,
    ROUND(STDDEV(media_seleccion) * 100, 2) as volatilidad_tasa_seleccion_pct,
    
    -- Clasificación de estabilidad global
    CASE 
        WHEN STDDEV(media_producto) / AVG(media_producto) < 0.05 THEN 'SISTEMA_MUY_ESTABLE'
        WHEN STDDEV(media_producto) / AVG(media_producto) < 0.10 THEN 'SISTEMA_ESTABLE'
        WHEN STDDEV(media_producto) / AVG(media_producto) < 0.20 THEN 'SISTEMA_MODERADAMENTE_VARIABLE'
        ELSE 'SISTEMA_ALTAMENTE_VARIABLE'
    END as clasificacion_estabilidad_sistema
    
FROM (
    SELECT @Q1_nombre as trimestre, COUNT(*) as registros, AVG(cProducto) as media_producto, AVG(cSeleccion) as media_seleccion
    FROM productos_t1 WHERE cIDT IN (@O01, @O02)
    UNION ALL
    SELECT @Q2_nombre, COUNT(*), AVG(cProducto), AVG(cSeleccion) FROM productos_t2 WHERE cIDT IN (@O01, @O02)
    UNION ALL
    SELECT @Q3_nombre, COUNT(*), AVG(cProducto), AVG(cSeleccion) FROM productos_t3 WHERE cIDT IN (@O01, @O02)
) resumen_trimestral;

-- ====================================================================
-- ANÁLISIS DE PERCENTILES DETALLADOS (SOLO PARA Q1 COMO EJEMPLO)
-- ====================================================================

SELECT 'ANÁLISIS DE PERCENTILES DETALLADOS - cPRODUCTO Q1' as percentiles_detallados;

-- Análisis detallado de percentiles para cProducto en Q1
SELECT 
    @Q1_nombre as trimestre,
    'cProducto' as variable,
    'Percentiles_Detallados' as analisis,
    
    -- Percentiles específicos
    (SELECT cProducto FROM productos_t1 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL ORDER BY cProducto LIMIT 1 OFFSET (SELECT FLOOR(COUNT(cProducto) * 0.05) FROM productos_t1 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL)) as P05,
    (SELECT cProducto FROM productos_t1 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL ORDER BY cProducto LIMIT 1 OFFSET (SELECT FLOOR(COUNT(cProducto) * 0.10) FROM productos_t1 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL)) as P10,
    (SELECT cProducto FROM productos_t1 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL ORDER BY cProducto LIMIT 1 OFFSET (SELECT FLOOR(COUNT(cProducto) * 0.25) FROM productos_t1 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL)) as P25_Q1,
    (SELECT cProducto FROM productos_t1 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL ORDER BY cProducto LIMIT 1 OFFSET (SELECT FLOOR(COUNT(cProducto) * 0.50) FROM productos_t1 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL)) as P50_Mediana,
    (SELECT cProducto FROM productos_t1 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL ORDER BY cProducto LIMIT 1 OFFSET (SELECT FLOOR(COUNT(cProducto) * 0.75) FROM productos_t1 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL)) as P75_Q3,
    (SELECT cProducto FROM productos_t1 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL ORDER BY cProducto LIMIT 1 OFFSET (SELECT FLOOR(COUNT(cProducto) * 0.90) FROM productos_t1 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL)) as P90,
    (SELECT cProducto FROM productos_t1 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL ORDER BY cProducto LIMIT 1 OFFSET (SELECT FLOOR(COUNT(cProducto) * 0.95) FROM productos_t1 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL)) as P95
FROM DUAL;

-- ====================================================================
-- ANÁLISIS DE CORRELACIÓN ENTRE VARIABLES
-- ====================================================================

SELECT 'ANÁLISIS DE CORRELACIÓN ENTRE VARIABLES NUMÉRICAS' as correlaciones;

-- Correlación aproximada entre cSeleccion y cIOT
WITH correlacion_vars AS (
    SELECT 
        cSeleccion,
        cIOT,
        AVG(cSeleccion) OVER() as mean_seleccion,
        AVG(cIOT) OVER() as mean_iot
    FROM productos_t1 
    WHERE cIDT IN (@O01, @O02) 
      AND cSeleccion IS NOT NULL 
      AND cIOT IS NOT NULL
)
SELECT 
    @Q1_nombre as trimestre,
    'Correlacion_Seleccion_IOT' as analisis,
    COUNT(*) as n_pares_validos,
    
    -- Correlación de Pearson aproximada
    ROUND(
        SUM((cSeleccion - mean_seleccion) * (cIOT - mean_iot)) / 
        SQRT(SUM(POWER(cSeleccion - mean_seleccion, 2)) * SUM(POWER(cIOT - mean_iot, 2))), 
        4
    ) as correlacion_pearson_aprox,
    
    -- Tabla de contingencia
    COUNT(CASE WHEN cSeleccion = 0 AND cIOT = 0 THEN 1 END) as sel0_iot0,
    COUNT(CASE WHEN cSeleccion = 0 AND cIOT = 1 THEN 1 END) as sel0_iot1,
    COUNT(CASE WHEN cSeleccion = 1 AND cIOT = 0 THEN 1 END) as sel1_iot0,
    COUNT(CASE WHEN cSeleccion = 1 AND cIOT = 1 THEN 1 END) as sel1_iot1,
    
    -- Interpretación de correlación
    CASE 
        WHEN ABS(SUM((cSeleccion - mean_seleccion) * (cIOT - mean_iot)) / 
                 SQRT(SUM(POWER(cSeleccion - mean_seleccion, 2)) * SUM(POWER(cIOT - mean_iot, 2)))) > 0.7 THEN 'CORRELACIÓN_FUERTE'
        WHEN ABS(SUM((cSeleccion - mean_seleccion) * (cIOT - mean_iot)) / 
                 SQRT(SUM(POWER(cSeleccion - mean_seleccion, 2)) * SUM(POWER(cIOT - mean_iot, 2)))) > 0.3 THEN 'CORRELACIÓN_MODERADA'
        WHEN ABS(SUM((cSeleccion - mean_seleccion) * (cIOT - mean_iot)) / 
                 SQRT(SUM(POWER(cSeleccion - mean_seleccion, 2)) * SUM(POWER(cIOT - mean_iot, 2)))) > 0.1 THEN 'CORRELACIÓN_DÉBIL'
        ELSE 'SIN_CORRELACIÓN'
    END as interpretacion_correlacion
    
FROM correlacion_vars;

-- ====================================================================
-- FINALIZACIÓN Y ESTADÍSTICAS
-- ====================================================================

SELECT 
    'FIN DEL SUMMARY ESTADÍSTICO' as evento
    , NOW() as timestamp_fin
    , 'Análisis estadístico completado exitosamente' as status
    , 'Revisar variables con VARIABILIDAD_MUY_ALTA o distribuciones NO_NORMALES' as recomendacion
    , 'Datos listos para análisis inferencial y modelado' as siguiente_paso
FROM DUAL;