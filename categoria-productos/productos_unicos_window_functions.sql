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
     Script          : Análisis 1 - Productos Únicos con Window Functions (Elegante)
     
     Create          : AGOSTO/2025
     Engine          : MariaDB/MySQL
     
     Parámetros Variables:
     @OP, @ONa - Códigos de organización
     @Q1_inicio, @Q1_fin - Rango de fechas Q1 2025
     @Q2_inicio, @Q2_fin - Rango de fechas Q2 2025  
     @Q3_inicio, @Q3_fin - Rango de fechas Q3 2025
     
     Notas:
     - Optimizado con Window Functions en lugar de COUNT(DISTINCT)
     - Más eficiente para grandes volúmenes de datos
     - ROW_NUMBER elimina duplicados de manera controlada
     - Código más elegante y performante
     
*********************************************************************************************/

-- ====================================================================
-- CONFIGURACIÓN DE VARIABLES
-- ====================================================================

SET @OP = 123;
SET @ONa = 369;

SET @Q1_nombre = 'Q01_25';
SET @Q1_inicio = '2025-01-01';
SET @Q1_fin = '2025-03-31';

SET @Q2_nombre = 'Q02_25';
SET @Q2_inicio = '2025-04-01';
SET @Q2_fin = '2025-06-30';

SET @Q3_nombre = 'Q03_25';
SET @Q3_inicio = '2025-07-01';
SET @Q3_fin = '2025-09-30';

-- Mostrar configuración
SELECT 
    'CONFIGURACIÓN DE VARIABLES' as seccion
    , @OP
    , @ONa 
    , @Q1_nombre
    , @Q1_inicio
    , @Q1_fin
    , @Q2_nombre
    , @Q2_inicio
    , @Q2_fin
    , @Q3_nombre
    , @Q3_inicio
    , @Q3_fin;

-- ====================================================================
-- ANÁLISIS: PRODUCTOS ÚNICOS CON WINDOW FUNCTIONS
-- ====================================================================

SELECT 'EJECUTANDO ANÁLISIS: PRODUCTOS ÚNICOS - WINDOW FUNCTIONS' as proceso;

-- Técnica elegante: ROW_NUMBER en lugar de COUNT(DISTINCT)
SELECT 
    organizacion,
    trimestre,
    COUNT(*) as productos_unicos
FROM (
    SELECT 
        CASE 
            WHEN cIDR = @OP THEN 'OP'
            WHEN cIDR = @ONa THEN 'ONa'
            ELSE 'OTRO'
        END as organizacion,
        trimestre,
        producto_id,
        ROW_NUMBER() OVER (
            PARTITION BY cIDR, trimestre, producto_id 
            ORDER BY fechaTabla ASC
        ) as rn
    FROM (
        -- Q1 2025
        SELECT 
            @Q1_nombre as trimestre,
            cIDR,
            producto_id,
            fechaTabla
        FROM ventas_1
        WHERE fechaTabla >= @Q1_inicio AND fechaTabla <= @Q1_fin
        AND cIDR IN (@OP, @ONa)

        UNION ALL

        -- Q2 2025
        SELECT 
            @Q2_nombre as trimestre,
            cIDR,
            producto_id,
            fechaTabla
        FROM ventas_2
        WHERE fechaTabla >= @Q2_inicio AND fechaTabla <= @Q2_fin
        AND cIDR IN (@OP, @ONa)

        UNION ALL

        -- Q3 2025
        SELECT 
            @Q3_nombre as trimestre,
            cIDR,
            producto_id,
            fechaTabla
        FROM ventas_3
        WHERE fechaTabla >= @Q3_inicio AND fechaTabla <= @Q3_fin
        AND cIDR IN (@OP, @ONa)
    ) datos_consolidados
) productos_numerados
WHERE rn = 1  -- Solo la primera aparición de cada producto por organización/trimestre
GROUP BY organizacion, trimestre
ORDER BY 
    CASE 
        WHEN organizacion = 'OP' THEN 1
        WHEN organizacion = 'ONa' THEN 2
        ELSE 3
    END,
    CASE trimestre
        WHEN @Q1_nombre THEN 1
        WHEN @Q2_nombre THEN 2
        WHEN @Q3_nombre THEN 3
        ELSE 4
    END;

-- ====================================================================
-- ANÁLISIS COMPLEMENTARIO: MÉTRICAS AVANZADAS CON WINDOW FUNCTIONS
-- ====================================================================

SELECT 'EJECUTANDO ANÁLISIS COMPLEMENTARIO: MÉTRICAS AVANZADAS' as proceso;

-- Análisis con comparaciones automáticas usando Window Functions
SELECT 
    organizacion,
    trimestre,
    productos_unicos,
    LAG(productos_unicos) OVER (
        PARTITION BY organizacion 
        ORDER BY orden_trimestre
    ) as productos_trimestre_anterior,
    productos_unicos - LAG(productos_unicos) OVER (
        PARTITION BY organizacion 
        ORDER BY orden_trimestre
    ) as diferencia_absoluta,
    ROUND(
        (productos_unicos - LAG(productos_unicos) OVER (
            PARTITION BY organizacion 
            ORDER BY orden_trimestre
        )) * 100.0 / LAG(productos_unicos) OVER (
            PARTITION BY organizacion 
            ORDER BY orden_trimestre
        ), 2
    ) as crecimiento_porcentual,
    AVG(productos_unicos) OVER (
        PARTITION BY organizacion
    ) as promedio_organizacion,
    RANK() OVER (
        PARTITION BY trimestre 
        ORDER BY productos_unicos DESC
    ) as ranking_por_trimestre
FROM (
    SELECT 
        organizacion,
        trimestre,
        COUNT(*) as productos_unicos,
        CASE trimestre
            WHEN @Q1_nombre THEN 1
            WHEN @Q2_nombre THEN 2
            WHEN @Q3_nombre THEN 3
            ELSE 4
        END as orden_trimestre
    FROM (
        SELECT 
            CASE 
                WHEN cIDR = @OP THEN 'OP'
                WHEN cIDR = @ONa THEN 'ONa'
                ELSE 'OTRO'
            END as organizacion,
            trimestre,
            producto_id,
            ROW_NUMBER() OVER (
                PARTITION BY cIDR, trimestre, producto_id 
                ORDER BY fechaTabla ASC
            ) as rn
        FROM (
            SELECT @Q1_nombre as trimestre, cIDR, producto_id, fechaTabla
            FROM ventas_1
            WHERE fechaTabla >= @Q1_inicio AND fechaTabla <= @Q1_fin
            AND cIDR IN (@OP, @ONa)

            UNION ALL

            SELECT @Q2_nombre as trimestre, cIDR, producto_id, fechaTabla
            FROM ventas_2
            WHERE fechaTabla >= @Q2_inicio AND fechaTabla <= @Q2_fin
            AND cIDR IN (@OP, @ONa)

            UNION ALL

            SELECT @Q3_nombre as trimestre, cIDR, producto_id, fechaTabla
            FROM ventas_3
            WHERE fechaTabla >= @Q3_inicio AND fechaTabla <= @Q3_fin
            AND cIDR IN (@OP, @ONa)
        ) datos_base
    ) productos_con_rank
    WHERE rn = 1
    GROUP BY organizacion, trimestre
) metricas_base
ORDER BY 
    CASE 
        WHEN organizacion = 'OP' THEN 1
        WHEN organizacion = 'ONa' THEN 2
        ELSE 3
    END,
    orden_trimestre;

-- ====================================================================
-- ANÁLISIS EJECUTIVO: RESUMEN CON WINDOW FUNCTIONS
-- ====================================================================

SELECT 'EJECUTANDO ANÁLISIS EJECUTIVO: RESUMEN FINAL' as proceso;

-- Resumen ejecutivo con métricas calculadas usando Window Functions
SELECT 
    organizacion,
    SUM(productos_unicos) as total_productos_periodo,
    AVG(productos_unicos) as promedio_productos_trimestre,
    MIN(productos_unicos) as min_productos_trimestre,
    MAX(productos_unicos) as max_productos_trimestre,
    STDDEV(productos_unicos) as volatilidad_productos,
    CASE 
        WHEN organizacion = 'OP' THEN 
            RANK() OVER (ORDER BY AVG(productos_unicos) DESC)
        ELSE 
            RANK() OVER (ORDER BY AVG(productos_unicos) DESC)
    END as ranking_performance
FROM (
    SELECT 
        organizacion,
        trimestre,
        COUNT(*) as productos_unicos
    FROM (
        SELECT 
            CASE 
                WHEN cIDR = @OP THEN 'OP'
                WHEN cIDR = @ONa THEN 'ONa'
                ELSE 'OTRO'
            END as organizacion,
            trimestre,
            producto_id,
            ROW_NUMBER() OVER (
                PARTITION BY cIDR, trimestre, producto_id 
                ORDER BY fechaTabla ASC
            ) as rn
        FROM (
            SELECT @Q1_nombre as trimestre, cIDR, producto_id, fechaTabla
            FROM ventas_1
            WHERE fechaTabla >= @Q1_inicio AND fechaTabla <= @Q1_fin
            AND cIDR IN (@OP, @ONa)

            UNION ALL

            SELECT @Q2_nombre as trimestre, cIDR, producto_id, fechaTabla
            FROM ventas_2
            WHERE fechaTabla >= @Q2_inicio AND fechaTabla <= @Q2_fin
            AND cIDR IN (@OP, @ONa)

            UNION ALL

            SELECT @Q3_nombre as trimestre, cIDR, producto_id, fechaTabla
            FROM ventas_3
            WHERE fechaTabla >= @Q3_inicio AND fechaTabla <= @Q3_fin
            AND cIDR IN (@OP, @ONa)
        ) datos_raw
    ) productos_unique
    WHERE rn = 1
    GROUP BY organizacion, trimestre
) summary_data
GROUP BY organizacion
ORDER BY promedio_productos_trimestre DESC;

-- ====================================================================
-- FINALIZACIÓN
-- ====================================================================

SELECT '<<< ANÁLISIS PRODUCTOS ÚNICOS CON WINDOW FUNCTIONS COMPLETADO >>>' as resultado;

SELECT 
    'PROCESO COMPLETADO' as evento,
    'WINDOW_FUNCTIONS' as tecnica_utilizada,
    'OPTIMIZADO_PARA_GRANDES_VOLUMENES' as beneficio,
    NOW() as timestamp_fin
FROM DUAL;