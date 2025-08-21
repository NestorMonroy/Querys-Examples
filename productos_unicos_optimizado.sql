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
     Script          : Análisis 1 - Productos Únicos por Trimestre (Optimizado)
     
     Create          : AGOSTO/2025
     Engine          : MariaDB/MySQL
     
     Parámetros Variables:
     @OP, @ONa, @ONa02 - Códigos de organización
     @Q1_inicio, @Q1_fin - Rango de fechas Q1 2025
     @Q2_inicio, @Q2_fin - Rango de fechas Q2 2025  
     @Q3_inicio, @Q3_fin - Rango de fechas Q3 2025
     
     Notas:
     - Optimizado SIN tabla temporal para evitar problemas de memoria con ~3TB
     - Consulta directa sobre ventas_1, ventas_2, ventas_3
     - Las fechas deben estar en formato ISO (YYYY-MM-DD) para compatibilidad
     - Análisis específico: Productos únicos = productos DISTINTOS que tuvieron actividad
     
*********************************************************************************************/

-- ====================================================================
-- CONFIGURACIÓN DE VARIABLES DE FECHA POR TRIMESTRE
-- ====================================================================

-- ====================================================================
-- MÉTODO 1: FECHAS FIJAS (Configuración manual)
-- ====================================================================

-- Definir variables para rangos de fechas de cada trimestre

SET @OP = 123;
SET @ONa = 369;
SET @ONa02 = 1902001;

SET @Q1_nombre = 'Q01_25';
SET @Q1_inicio = '2025-01-01';
SET @Q1_fin = '2025-03-31';

SET @Q2_nombre = 'Q02_25';
SET @Q2_inicio = '2025-04-01';
SET @Q2_fin = '2025-06-30';

SET @Q3_nombre = 'Q03_25';
SET @Q3_inicio = '2025-07-01';
SET @Q3_fin = '2025-09-30';

-- Mostrar configuración final seleccionada
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
	
-- Mostrar estadísticas iniciales para monitoreo
SELECT 
    'INICIO DEL PROCESO - ANÁLISIS PRODUCTOS ÚNICOS' as evento
    , NOW() as timestamp
    , CONNECTION_ID() as connection_id
FROM DUAL;

-- ====================================================================
-- CONTEO DE DATOS EXISTENTES
-- ====================================================================

-- Contar registros por trimestre ANTES del proceso 
SELECT 'ANTES - REGISTROS POR TRIMESTRE EN TABLA FUENTE' as reporte;

SELECT 
    @Q1_nombre as trimestre,
    @Q1_inicio as fecha_inicio,
    @Q1_fin as fecha_fin,
    COUNT(*) as registros_existentes
FROM ventas_1
WHERE fechaTabla >= @Q1_inicio AND fechaTabla <= @Q1_fin
AND cIDR IN (@OP, @ONa)

UNION ALL

SELECT 
    @Q2_nombre as trimestre,
    @Q2_inicio as fecha_inicio,
    @Q2_fin as fecha_fin,
    COUNT(*) as registros_existentes
FROM ventas_2
WHERE fechaTabla >= @Q2_inicio AND fechaTabla <= @Q2_fin
AND cIDR IN (@OP, @ONa)

UNION ALL

SELECT 
    @Q3_nombre as trimestre,
    @Q3_inicio as fecha_inicio,
    @Q3_fin as fecha_fin,
    COUNT(*) as registros_existentes
FROM ventas_3
WHERE fechaTabla >= @Q3_inicio AND fechaTabla <= @Q3_fin
AND cIDR IN (@OP, @ONa);

-- ====================================================================
-- ANÁLISIS PRINCIPAL: PRODUCTOS ÚNICOS POR TRIMESTRE
-- ====================================================================

-- ANÁLISIS DIRECTO SIN TABLA TEMPORAL (Optimización para evitar ~3TB en memoria)

SELECT 'EJECUTANDO ANÁLISIS: PRODUCTOS ÚNICOS POR TRIMESTRE' as proceso;

SELECT 
    trimestre,
    COUNT(DISTINCT producto_id) as productos_unicos,
    COUNT(*) as total_transacciones,
    ROUND(COUNT(DISTINCT producto_id) * 100.0 / COUNT(*), 4) as ratio_diversidad_productos
FROM (
    -- TRIMESTRE 1: Extraer productos
    SELECT 
        @Q1_nombre as trimestre,
        producto_id
    FROM ventas_1
    WHERE fechaTabla >= @Q1_inicio AND fechaTabla <= @Q1_fin
    AND cIDR IN (@OP, @ONa)

    UNION ALL

    -- TRIMESTRE 2: Extraer productos
    SELECT 
        @Q2_nombre as trimestre,
        producto_id
    FROM ventas_2
    WHERE fechaTabla >= @Q2_inicio AND fechaTabla <= @Q2_fin
    AND cIDR IN (@OP, @ONa)

    UNION ALL

    -- TRIMESTRE 3: Extraer productos
    SELECT 
        @Q3_nombre as trimestre,
        producto_id
    FROM ventas_3
    WHERE fechaTabla >= @Q3_inicio AND fechaTabla <= @Q3_fin
    AND cIDR IN (@OP, @ONa)
) productos_consolidados
GROUP BY trimestre
ORDER BY 
    CASE trimestre
        WHEN @Q1_nombre THEN 1
        WHEN @Q2_nombre THEN 2
        WHEN @Q3_nombre THEN 3
        ELSE 99
    END;

-- ====================================================================
-- ANÁLISIS COMPLEMENTARIO: VARIACIÓN ENTRE TRIMESTRES
-- ====================================================================

SELECT 'EJECUTANDO ANÁLISIS COMPLEMENTARIO: VARIACIONES TRIMESTRE A TRIMESTRE' as proceso;

-- Crear vista temporal para cálculos de variación
CREATE TEMPORARY TABLE temp_productos_unicos_base (
    trimestre VARCHAR(10),
    productos_unicos INT,
    orden_trimestre INT,
    PRIMARY KEY (trimestre)
) ENGINE=MEMORY;

-- Cargar datos base de productos únicos
INSERT INTO temp_productos_unicos_base
SELECT 
    trimestre,
    COUNT(DISTINCT producto_id) as productos_unicos,
    CASE trimestre
        WHEN @Q1_nombre THEN 1
        WHEN @Q2_nombre THEN 2
        WHEN @Q3_nombre THEN 3
        ELSE 99
    END as orden_trimestre
FROM (
    SELECT @Q1_nombre as trimestre, producto_id FROM ventas_1
    WHERE fechaTabla >= @Q1_inicio AND fechaTabla <= @Q1_fin
    AND cIDR IN (@OP, @ONa)

    UNION ALL

    SELECT @Q2_nombre as trimestre, producto_id FROM ventas_2
    WHERE fechaTabla >= @Q2_inicio AND fechaTabla <= @Q2_fin
    AND cIDR IN (@OP, @ONa)

    UNION ALL

    SELECT @Q3_nombre as trimestre, producto_id FROM ventas_3
    WHERE fechaTabla >= @Q3_inicio AND fechaTabla <= @Q3_fin
    AND cIDR IN (@OP, @ONa)
) consolidado
GROUP BY trimestre;

-- Mostrar análisis de variaciones
SELECT 
    a.trimestre,
    a.productos_unicos,
    b.productos_unicos as productos_trimestre_anterior,
    CASE 
        WHEN b.productos_unicos IS NOT NULL 
        THEN a.productos_unicos - b.productos_unicos
        ELSE NULL
    END as diferencia_absoluta,
    CASE 
        WHEN b.productos_unicos IS NOT NULL AND b.productos_unicos > 0
        THEN ROUND((a.productos_unicos - b.productos_unicos) * 100.0 / b.productos_unicos, 2)
        ELSE NULL
    END as variacion_porcentual,
    CASE 
        WHEN b.productos_unicos IS NULL THEN 'TRIMESTRE_BASE'
        WHEN a.productos_unicos > b.productos_unicos THEN 'CRECIMIENTO'
        WHEN a.productos_unicos = b.productos_unicos THEN 'ESTABLE'
        ELSE 'DECRECIMIENTO'
    END as tendencia
FROM temp_productos_unicos_base a
LEFT JOIN temp_productos_unicos_base b ON b.orden_trimestre = a.orden_trimestre - 1
ORDER BY a.orden_trimestre;

-- ====================================================================
-- ANÁLISIS DETALLADO: PRODUCTOS NUEVOS Y DESCONTINUADOS
-- ====================================================================

SELECT 'EJECUTANDO ANÁLISIS DETALLADO: PRODUCTOS NUEVOS Y DESCONTINUADOS' as proceso;

-- Crear tablas temporales para análisis de productos por trimestre
CREATE TEMPORARY TABLE temp_productos_q1 (
    producto_id VARCHAR(100),
    PRIMARY KEY (producto_id)
) ENGINE=MEMORY;

CREATE TEMPORARY TABLE temp_productos_q2 (
    producto_id VARCHAR(100),
    PRIMARY KEY (producto_id)
) ENGINE=MEMORY;

CREATE TEMPORARY TABLE temp_productos_q3 (
    producto_id VARCHAR(100),
    PRIMARY KEY (producto_id)
) ENGINE=MEMORY;

-- Cargar productos únicos por trimestre
INSERT INTO temp_productos_q1
SELECT DISTINCT producto_id 
FROM ventas_1
WHERE fechaTabla >= @Q1_inicio AND fechaTabla <= @Q1_fin
AND cIDR IN (@OP, @ONa);

INSERT INTO temp_productos_q2
SELECT DISTINCT producto_id 
FROM ventas_2
WHERE fechaTabla >= @Q2_inicio AND fechaTabla <= @Q2_fin
AND cIDR IN (@OP, @ONa);

INSERT INTO temp_productos_q3
SELECT DISTINCT producto_id 
FROM ventas_3
WHERE fechaTabla >= @Q3_inicio AND fechaTabla <= @Q3_fin
AND cIDR IN (@OP, @ONa);

-- Análisis de productos nuevos y descontinuados
SELECT 
    'PRODUCTOS_NUEVOS_Q2' as categoria,
    COUNT(*) as cantidad,
    'Productos que aparecen en Q2 pero no estaban en Q1' as descripcion
FROM temp_productos_q2 q2
LEFT JOIN temp_productos_q1 q1 ON q2.producto_id = q1.producto_id
WHERE q1.producto_id IS NULL

UNION ALL

SELECT 
    'PRODUCTOS_NUEVOS_Q3' as categoria,
    COUNT(*) as cantidad,
    'Productos que aparecen en Q3 pero no estaban en Q1 ni Q2' as descripcion
FROM temp_productos_q3 q3
LEFT JOIN temp_productos_q1 q1 ON q3.producto_id = q1.producto_id
LEFT JOIN temp_productos_q2 q2 ON q3.producto_id = q2.producto_id
WHERE q1.producto_id IS NULL AND q2.producto_id IS NULL

UNION ALL

SELECT 
    'PRODUCTOS_DESCONTINUADOS_Q2' as categoria,
    COUNT(*) as cantidad,
    'Productos que estaban en Q1 pero no aparecen en Q2' as descripcion
FROM temp_productos_q1 q1
LEFT JOIN temp_productos_q2 q2 ON q1.producto_id = q2.producto_id
WHERE q2.producto_id IS NULL

UNION ALL

SELECT 
    'PRODUCTOS_DESCONTINUADOS_Q3' as categoria,
    COUNT(*) as cantidad,
    'Productos que estaban en Q2 pero no aparecen en Q3' as descripcion
FROM temp_productos_q2 q2
LEFT JOIN temp_productos_q3 q3 ON q2.producto_id = q3.producto_id
WHERE q3.producto_id IS NULL

UNION ALL

SELECT 
    'PRODUCTOS_CONSISTENTES' as categoria,
    COUNT(*) as cantidad,
    'Productos que aparecen en los 3 trimestres' as descripcion
FROM temp_productos_q1 q1
INNER JOIN temp_productos_q2 q2 ON q1.producto_id = q2.producto_id
INNER JOIN temp_productos_q3 q3 ON q1.producto_id = q3.producto_id;

-- ====================================================================
-- RESUMEN EJECUTIVO FINAL
-- ====================================================================

SELECT 'GENERANDO RESUMEN EJECUTIVO FINAL' as proceso;

-- Calcular métricas consolidadas
SELECT 
    'RESUMEN_EJECUTIVO' as tipo_reporte,
    (SELECT productos_unicos FROM temp_productos_unicos_base WHERE trimestre = @Q1_nombre) as productos_Q1,
    (SELECT productos_unicos FROM temp_productos_unicos_base WHERE trimestre = @Q2_nombre) as productos_Q2,
    (SELECT productos_unicos FROM temp_productos_unicos_base WHERE trimestre = @Q3_nombre) as productos_Q3,
    (
        SELECT COUNT(DISTINCT producto_id) 
        FROM (
            SELECT producto_id FROM temp_productos_q1
            UNION
            SELECT producto_id FROM temp_productos_q2
            UNION
            SELECT producto_id FROM temp_productos_q3
        ) todos_productos
    ) as productos_unicos_totales_2025,
    ROUND(
        (
            (SELECT productos_unicos FROM temp_productos_unicos_base WHERE trimestre = @Q3_nombre) -
            (SELECT productos_unicos FROM temp_productos_unicos_base WHERE trimestre = @Q1_nombre)
        ) * 100.0 / (SELECT productos_unicos FROM temp_productos_unicos_base WHERE trimestre = @Q1_nombre), 2
    ) as crecimiento_Q1_a_Q3_pct;

-- Limpiar tablas temporales
DROP TEMPORARY TABLE IF EXISTS temp_productos_unicos_base;
DROP TEMPORARY TABLE IF EXISTS temp_productos_q1;
DROP TEMPORARY TABLE IF EXISTS temp_productos_q2;
DROP TEMPORARY TABLE IF EXISTS temp_productos_q3;

-- ====================================================================
-- FINALIZACIÓN DEL PROCESO
-- ====================================================================

-- Verificar finalización exitosa
SELECT '<<< ANÁLISIS PRODUCTOS ÚNICOS COMPLETADO EXITOSAMENTE >>>' as resultado;

SELECT 
    'PROCESO COMPLETADO' as evento,
    'PRODUCTOS_ÚNICOS_POR_TRIMESTRE' as tipo_analisis,
    'SIN_TABLA_TEMPORAL' as metodo_optimizado,
    'CONSULTA_DIRECTA_OPTIMIZADA' as estrategia,
    NOW() as timestamp_fin
FROM DUAL;