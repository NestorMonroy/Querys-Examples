-- ====================================================================
-- INFORMACIÓN DEL ENTORNO
-- ====================================================================

SELECT 'EJECUTADO EN:' as info;

SELECT 
    DATABASE() as 'Base de Datos'
    , USER() as 'Usuario'
    , @@version as 'Versión MySQL/MariaDB'
FROM DUAL;

SELECT NOW() as 'FECHA DE INICIO';

/*********************************************************************************************
     Script          : ANÁLISIS_INTEGRAL_NULOS_CROSS_TRIMESTRAL
     
     Create          : AGOSTO/2025
     Engine          : MariaDB/MySQL
     
     Descripción     : Análisis completo de valores nulos, vacíos y semánticos
                      across las 3 tablas trimestrales con agrupación por cIDT y cCategoria
     
     Parámetros Variables:
     - @Q1_nombre, @Q2_nombre, @Q3_nombre: Nombres de trimestres
     - @O01, @O02: IDs específicos para análisis
     
     Tablas Target   : productos_t1, productos_t2, productos_t3
     
     Hipótesis       : H0: No hay diferencias significativas en distribución de nulos entre trimestres
                      H1: Los patrones de nulos evolucionan entre T1, T2, T3
                      H2: Ciertos cIDT tienen patrones consistentes de nulos
     
     Notas          : Detecta nulos técnicos (NULL), semánticos ('', ' ', 'N/A') y patrones temporales

*********************************************************************************************/

-- ====================================================================
-- CONFIGURACIÓN DE VARIABLES POR TRIMESTRE
-- ====================================================================

-- ====================================================================
-- MÉTODO 1: FECHAS FIJAS (Configuración manual)
-- ====================================================================

-- Definir variables para rangos de fechas de cada trimestre
SET @Q1_nombre = 'Q01_25';
SET @Q1_inicio = '2025-02-01';
SET @Q1_fin = '2025-03-31';

SET @Q2_nombre = 'Q02_25';
SET @Q2_inicio = '2025-04-01';
SET @Q2_fin = '2025-06-30';

SET @Q3_nombre = 'Q03_25';
SET @Q3_inicio = '2025-07-01';
SET @Q3_fin = '2025-07-31';

-- Variables de IDT específicos para análisis
SET @O01 = 9544745;
SET @O02 = 367620;

-- Mostrar configuración final seleccionada
SELECT 
    'CONFIGURACIÓN DE VARIABLES' as seccion
    , @Q1_nombre as Q1_nombre
    , @Q1_inicio as Q1_inicio
    , @Q1_fin as Q1_fin
    , @Q2_nombre as Q2_nombre
    , @Q2_inicio as Q2_inicio
    , @Q2_fin as Q2_fin
    , @Q3_nombre as Q3_nombre
    , @Q3_inicio as Q3_inicio
    , @Q3_fin as Q3_fin
    , @O01 as IDT_01
    , @O02 as IDT_02;

-- Mostrar estadísticas iniciales para monitoreo
SELECT 
    'INICIO DEL PROCESO' as evento
    , NOW() as timestamp
    , CONNECTION_ID() as connection_id
FROM DUAL;

-- ====================================================================
-- CONTEO DE DATOS EXISTENTES
-- ====================================================================

-- Contar registros por trimestre ANTES del análisis de nulos
SELECT 'ANTES - REGISTROS POR TRIMESTRE EN TABLAS FUENTE' as reporte;

SELECT 
    @Q1_nombre as trimestre,
    @Q1_inicio as fecha_inicio,
    @Q1_fin as fecha_fin,
    COUNT(*) as registros_existentes,
    COUNT(DISTINCT cIDT) as idt_unicos,
    COUNT(DISTINCT cCategoria) as categorias_unicas
FROM productos_t1
WHERE cIDT IN (@O01, @O02)

UNION ALL

SELECT 
    @Q2_nombre as trimestre,
    @Q2_inicio as fecha_inicio,
    @Q2_fin as fecha_fin,
    COUNT(*) as registros_existentes,
    COUNT(DISTINCT cIDT) as idt_unicos,
    COUNT(DISTINCT cCategoria) as categorias_unicas
FROM productos_t2
WHERE cIDT IN (@O01, @O02)

UNION ALL

SELECT 
    @Q3_nombre as trimestre,
    @Q3_inicio as fecha_inicio,
    @Q3_fin as fecha_fin,
    COUNT(*) as registros_existentes,
    COUNT(DISTINCT cIDT) as idt_unicos,
    COUNT(DISTINCT cCategoria) as categorias_unicas
FROM productos_t3
WHERE cIDT IN (@O01, @O02);

-- ====================================================================
-- ANÁLISIS PRINCIPAL - DETECCIÓN INTEGRAL DE NULOS
-- ====================================================================

SELECT 'ANÁLISIS INTEGRAL DE NULOS - AGRUPADO POR TRIMESTRE, cIDT Y cCATEGORIA' as proceso;

-- Análisis completo de nulos técnicos, semánticos y patrones
SELECT 
    @Q1_nombre as trimestre,
    cIDT,
    COALESCE(cCategoria, '[NULL_CATEGORIA]') as categoria_analizada,
    COUNT(*) as total_registros,
    
    -- ===== ANÁLISIS DE NULOS TÉCNICOS =====
    COUNT(CASE WHEN cProducto IS NULL THEN 1 END) as producto_null,
    COUNT(CASE WHEN cIDT IS NULL THEN 1 END) as idt_null,
    COUNT(CASE WHEN cSeleccion IS NULL THEN 1 END) as seleccion_null,
    COUNT(CASE WHEN cIOT IS NULL THEN 1 END) as iot_null,
    COUNT(CASE WHEN cFecha IS NULL THEN 1 END) as fecha_null,
    COUNT(CASE WHEN cHInicio IS NULL THEN 1 END) as hinicio_null,
    COUNT(CASE WHEN cHFin IS NULL THEN 1 END) as hfin_null,
    
    -- ===== ANÁLISIS DE NULOS SEMÁNTICOS EN cCATEGORIA =====
    COUNT(CASE WHEN cCategoria IS NULL THEN 1 END) as categoria_null,
    COUNT(CASE WHEN cCategoria = '' THEN 1 END) as categoria_cadena_vacia,
    COUNT(CASE WHEN cCategoria = ' ' THEN 1 END) as categoria_solo_espacio,
    COUNT(CASE WHEN TRIM(cCategoria) = '' AND cCategoria != '' THEN 1 END) as categoria_espacios_multiples,
    COUNT(CASE WHEN cCategoria IN ('N/A', 'NA', 'NULL', 'n/a', '-', '--', 'null') THEN 1 END) as categoria_nulos_semanticos,
    
    -- ===== MÉTRICAS DE COMPLETITUD =====
    ROUND((COUNT(cProducto) * 100.0 / COUNT(*)), 2) as completitud_producto_pct,
    ROUND((COUNT(CASE WHEN cCategoria IS NOT NULL AND TRIM(cCategoria) != '' 
                       AND cCategoria NOT IN ('N/A', 'NA', 'NULL', 'n/a', '-', '--', 'null') THEN 1 END) * 100.0 / COUNT(*)), 2) as completitud_categoria_pct,
    ROUND((COUNT(cSeleccion) * 100.0 / COUNT(*)), 2) as completitud_seleccion_pct,
    ROUND((COUNT(cIOT) * 100.0 / COUNT(*)), 2) as completitud_iot_pct,
    
    -- ===== ÍNDICES DE CALIDAD COMPUESTOS =====
    ROUND(((COUNT(cProducto) + COUNT(CASE WHEN cCategoria IS NOT NULL AND TRIM(cCategoria) != '' THEN 1 END) + 
            COUNT(cSeleccion) + COUNT(cIOT)) * 100.0 / (COUNT(*) * 4)), 2) as indice_completitud_global_pct,
    
    -- ===== CLASIFICACIÓN DE CALIDAD =====
    CASE 
        WHEN ((COUNT(cProducto) + COUNT(CASE WHEN cCategoria IS NOT NULL AND TRIM(cCategoria) != '' THEN 1 END) + 
               COUNT(cSeleccion) + COUNT(cIOT)) * 100.0 / (COUNT(*) * 4)) >= 95 THEN 'EXCELENTE'
        WHEN ((COUNT(cProducto) + COUNT(CASE WHEN cCategoria IS NOT NULL AND TRIM(cCategoria) != '' THEN 1 END) + 
               COUNT(cSeleccion) + COUNT(cIOT)) * 100.0 / (COUNT(*) * 4)) >= 85 THEN 'BUENA'
        WHEN ((COUNT(cProducto) + COUNT(CASE WHEN cCategoria IS NOT NULL AND TRIM(cCategoria) != '' THEN 1 END) + 
               COUNT(cSeleccion) + COUNT(cIOT)) * 100.0 / (COUNT(*) * 4)) >= 75 THEN 'ACEPTABLE'
        ELSE 'REQUIERE_MEJORA'
    END as clasificacion_calidad_datos
    
FROM productos_t1 
WHERE cIDT IN (@O01, @O02)
GROUP BY cIDT, cCategoria

UNION ALL

SELECT 
    @Q2_nombre as trimestre,
    cIDT,
    COALESCE(cCategoria, '[NULL_CATEGORIA]') as categoria_analizada,
    COUNT(*) as total_registros,
    
    -- Nulos técnicos
    COUNT(CASE WHEN cProducto IS NULL THEN 1 END),
    COUNT(CASE WHEN cIDT IS NULL THEN 1 END),
    COUNT(CASE WHEN cSeleccion IS NULL THEN 1 END),
    COUNT(CASE WHEN cIOT IS NULL THEN 1 END),
    COUNT(CASE WHEN cFecha IS NULL THEN 1 END),
    COUNT(CASE WHEN cHInicio IS NULL THEN 1 END),
    COUNT(CASE WHEN cHFin IS NULL THEN 1 END),
    
    -- Nulos semánticos en cCategoria
    COUNT(CASE WHEN cCategoria IS NULL THEN 1 END),
    COUNT(CASE WHEN cCategoria = '' THEN 1 END),
    COUNT(CASE WHEN cCategoria = ' ' THEN 1 END),
    COUNT(CASE WHEN TRIM(cCategoria) = '' AND cCategoria != '' THEN 1 END),
    COUNT(CASE WHEN cCategoria IN ('N/A', 'NA', 'NULL', 'n/a', '-', '--', 'null') THEN 1 END),
    
    -- Métricas de completitud
    ROUND((COUNT(cProducto) * 100.0 / COUNT(*)), 2),
    ROUND((COUNT(CASE WHEN cCategoria IS NOT NULL AND TRIM(cCategoria) != '' 
                       AND cCategoria NOT IN ('N/A', 'NA', 'NULL', 'n/a', '-', '--', 'null') THEN 1 END) * 100.0 / COUNT(*)), 2),
    ROUND((COUNT(cSeleccion) * 100.0 / COUNT(*)), 2),
    ROUND((COUNT(cIOT) * 100.0 / COUNT(*)), 2),
    
    -- Índice global
    ROUND(((COUNT(cProducto) + COUNT(CASE WHEN cCategoria IS NOT NULL AND TRIM(cCategoria) != '' THEN 1 END) + 
            COUNT(cSeleccion) + COUNT(cIOT)) * 100.0 / (COUNT(*) * 4)), 2),
    
    -- Clasificación
    CASE 
        WHEN ((COUNT(cProducto) + COUNT(CASE WHEN cCategoria IS NOT NULL AND TRIM(cCategoria) != '' THEN 1 END) + 
               COUNT(cSeleccion) + COUNT(cIOT)) * 100.0 / (COUNT(*) * 4)) >= 95 THEN 'EXCELENTE'
        WHEN ((COUNT(cProducto) + COUNT(CASE WHEN cCategoria IS NOT NULL AND TRIM(cCategoria) != '' THEN 1 END) + 
               COUNT(cSeleccion) + COUNT(cIOT)) * 100.0 / (COUNT(*) * 4)) >= 85 THEN 'BUENA'
        WHEN ((COUNT(cProducto) + COUNT(CASE WHEN cCategoria IS NOT NULL AND TRIM(cCategoria) != '' THEN 1 END) + 
               COUNT(cSeleccion) + COUNT(cIOT)) * 100.0 / (COUNT(*) * 4)) >= 75 THEN 'ACEPTABLE'
        ELSE 'REQUIERE_MEJORA'
    END
    
FROM productos_t2 
WHERE cIDT IN (@O01, @O02)
GROUP BY cIDT, cCategoria

UNION ALL

SELECT 
    @Q3_nombre as trimestre,
    cIDT,
    COALESCE(cCategoria, '[NULL_CATEGORIA]') as categoria_analizada,
    COUNT(*) as total_registros,
    
    -- Nulos técnicos
    COUNT(CASE WHEN cProducto IS NULL THEN 1 END),
    COUNT(CASE WHEN cIDT IS NULL THEN 1 END),
    COUNT(CASE WHEN cSeleccion IS NULL THEN 1 END),
    COUNT(CASE WHEN cIOT IS NULL THEN 1 END),
    COUNT(CASE WHEN cFecha IS NULL THEN 1 END),
    COUNT(CASE WHEN cHInicio IS NULL THEN 1 END),
    COUNT(CASE WHEN cHFin IS NULL THEN 1 END),
    
    -- Nulos semánticos en cCategoria
    COUNT(CASE WHEN cCategoria IS NULL THEN 1 END),
    COUNT(CASE WHEN cCategoria = '' THEN 1 END),
    COUNT(CASE WHEN cCategoria = ' ' THEN 1 END),
    COUNT(CASE WHEN TRIM(cCategoria) = '' AND cCategoria != '' THEN 1 END),
    COUNT(CASE WHEN cCategoria IN ('N/A', 'NA', 'NULL', 'n/a', '-', '--', 'null') THEN 1 END),
    
    -- Métricas de completitud
    ROUND((COUNT(cProducto) * 100.0 / COUNT(*)), 2),
    ROUND((COUNT(CASE WHEN cCategoria IS NOT NULL AND TRIM(cCategoria) != '' 
                       AND cCategoria NOT IN ('N/A', 'NA', 'NULL', 'n/a', '-', '--', 'null') THEN 1 END) * 100.0 / COUNT(*)), 2),
    ROUND((COUNT(cSeleccion) * 100.0 / COUNT(*)), 2),
    ROUND((COUNT(cIOT) * 100.0 / COUNT(*)), 2),
    
    -- Índice global
    ROUND(((COUNT(cProducto) + COUNT(CASE WHEN cCategoria IS NOT NULL AND TRIM(cCategoria) != '' THEN 1 END) + 
            COUNT(cSeleccion) + COUNT(cIOT)) * 100.0 / (COUNT(*) * 4)), 2),
    
    -- Clasificación
    CASE 
        WHEN ((COUNT(cProducto) + COUNT(CASE WHEN cCategoria IS NOT NULL AND TRIM(cCategoria) != '' THEN 1 END) + 
               COUNT(cSeleccion) + COUNT(cIOT)) * 100.0 / (COUNT(*) * 4)) >= 95 THEN 'EXCELENTE'
        WHEN ((COUNT(cProducto) + COUNT(CASE WHEN cCategoria IS NOT NULL AND TRIM(cCategoria) != '' THEN 1 END) + 
               COUNT(cSeleccion) + COUNT(cIOT)) * 100.0 / (COUNT(*) * 4)) >= 85 THEN 'BUENA'
        WHEN ((COUNT(cProducto) + COUNT(CASE WHEN cCategoria IS NOT NULL AND TRIM(cCategoria) != '' THEN 1 END) + 
               COUNT(cSeleccion) + COUNT(cIOT)) * 100.0 / (COUNT(*) * 4)) >= 75 THEN 'ACEPTABLE'
        ELSE 'REQUIERE_MEJORA'
    END
    
FROM productos_t3 
WHERE cIDT IN (@O01, @O02)
GROUP BY cIDT, cCategoria

ORDER BY cIDT, categoria_analizada, trimestre;

-- ====================================================================
-- ANÁLISIS COMPLEMENTARIO - RESUMEN EJECUTIVO DE NULOS
-- ====================================================================

SELECT 'RESUMEN EJECUTIVO - CONSOLIDADO DE NULOS POR TRIMESTRE' as reporte_final;

-- Resumen consolidado por trimestre
SELECT 
    trimestre,
    SUM(total_registros) as registros_totales,
    SUM(total_registros) - SUM(producto_validos) as total_nulos_producto,
    SUM(total_registros) - SUM(categoria_validos) as total_nulos_categoria,
    ROUND(AVG(completitud_producto_pct), 2) as completitud_promedio_producto,
    ROUND(AVG(completitud_categoria_pct), 2) as completitud_promedio_categoria,
    COUNT(DISTINCT cIDT) as idt_analizados,
    COUNT(DISTINCT categoria_analizada) as categorias_analizadas,
    
    -- Índice de calidad trimestral
    ROUND(((SUM(producto_validos) + SUM(categoria_validos)) * 100.0 / (SUM(total_registros) * 2)), 2) as indice_calidad_trimestral
    
FROM (
    SELECT 
        @Q1_nombre as trimestre,
        cIDT,
        cCategoria as categoria_analizada,
        COUNT(*) as total_registros,
        COUNT(cProducto) as producto_validos,
        COUNT(CASE WHEN cCategoria IS NOT NULL AND TRIM(cCategoria) != '' 
                   AND cCategoria NOT IN ('N/A', 'NA', 'NULL', 'n/a', '-', '--', 'null') THEN 1 END) as categoria_validos,
        ROUND((COUNT(cProducto) * 100.0 / COUNT(*)), 2) as completitud_producto_pct,
        ROUND((COUNT(CASE WHEN cCategoria IS NOT NULL AND TRIM(cCategoria) != '' 
                           AND cCategoria NOT IN ('N/A', 'NA', 'NULL', 'n/a', '-', '--', 'null') THEN 1 END) * 100.0 / COUNT(*)), 2) as completitud_categoria_pct
    FROM productos_t1 WHERE cIDT IN (@O01, @O02) GROUP BY cIDT, cCategoria
    
    UNION ALL
    
    SELECT 
        @Q2_nombre, cIDT, cCategoria, COUNT(*), COUNT(cProducto),
        COUNT(CASE WHEN cCategoria IS NOT NULL AND TRIM(cCategoria) != '' 
                   AND cCategoria NOT IN ('N/A', 'NA', 'NULL', 'n/a', '-', '--', 'null') THEN 1 END),
        ROUND((COUNT(cProducto) * 100.0 / COUNT(*)), 2),
        ROUND((COUNT(CASE WHEN cCategoria IS NOT NULL AND TRIM(cCategoria) != '' 
                           AND cCategoria NOT IN ('N/A', 'NA', 'NULL', 'n/a', '-', '--', 'null') THEN 1 END) * 100.0 / COUNT(*)), 2)
    FROM productos_t2 WHERE cIDT IN (@O01, @O02) GROUP BY cIDT, cCategoria
    
    UNION ALL
    
    SELECT 
        @Q3_nombre, cIDT, cCategoria, COUNT(*), COUNT(cProducto),
        COUNT(CASE WHEN cCategoria IS NOT NULL AND TRIM(cCategoria) != '' 
                   AND cCategoria NOT IN ('N/A', 'NA', 'NULL', 'n/a', '-', '--', 'null') THEN 1 END),
        ROUND((COUNT(cProducto) * 100.0 / COUNT(*)), 2),
        ROUND((COUNT(CASE WHEN cCategoria IS NOT NULL AND TRIM(cCategoria) != '' 
                           AND cCategoria NOT IN ('N/A', 'NA', 'NULL', 'n/a', '-', '--', 'null') THEN 1 END) * 100.0 / COUNT(*)), 2)
    FROM productos_t3 WHERE cIDT IN (@O01, @O02) GROUP BY cIDT, cCategoria
    
) analisis_consolidado
GROUP BY trimestre
ORDER BY trimestre;

-- ====================================================================
-- FINALIZACIÓN Y ESTADÍSTICAS
-- ====================================================================

SELECT 
    'FIN DEL ANÁLISIS DE NULOS' as evento
    , NOW() as timestamp_fin
    , 'Script completado exitosamente' as status
FROM DUAL;