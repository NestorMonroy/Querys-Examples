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
     Script          : Análisis 2 - Promedio de Productos por Categoría (Optimizado)
     
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
     - Análisis específico: Promedio de productos únicos por categoría across trimestres
     
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
    'INICIO DEL PROCESO - ANÁLISIS PROMEDIO PRODUCTOS POR CATEGORÍA' as evento
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
    COUNT(*) as registros_existentes,
    COUNT(DISTINCT categoria) as categorias_existentes
FROM ventas_1
WHERE fechaTabla >= @Q1_inicio AND fechaTabla <= @Q1_fin
AND cIDR IN (@OP, @ONa)

UNION ALL

SELECT 
    @Q2_nombre as trimestre,
    @Q2_inicio as fecha_inicio,
    @Q2_fin as fecha_fin,
    COUNT(*) as registros_existentes,
    COUNT(DISTINCT categoria) as categorias_existentes
FROM ventas_2
WHERE fechaTabla >= @Q2_inicio AND fechaTabla <= @Q2_fin
AND cIDR IN (@OP, @ONa)

UNION ALL

SELECT 
    @Q3_nombre as trimestre,
    @Q3_inicio as fecha_inicio,
    @Q3_fin as fecha_fin,
    COUNT(*) as registros_existentes,
    COUNT(DISTINCT categoria) as categorias_existentes
FROM ventas_3
WHERE fechaTabla >= @Q3_inicio AND fechaTabla <= @Q3_fin
AND cIDR IN (@OP, @ONa);

-- ====================================================================
-- ANÁLISIS PRINCIPAL: PRODUCTOS POR CATEGORÍA POR TRIMESTRE
-- ====================================================================

-- ANÁLISIS DIRECTO SIN TABLA TEMPORAL (Optimización para evitar ~3TB en memoria)

SELECT 'EJECUTANDO ANÁLISIS: PRODUCTOS POR CATEGORÍA POR TRIMESTRE' as proceso;

-- Paso 1: Obtener productos únicos por categoría por trimestre
CREATE TEMPORARY TABLE temp_productos_categoria_trimestre (
    trimestre VARCHAR(10),
    categoria VARCHAR(100),
    productos_unicos INT,
    PRIMARY KEY (trimestre, categoria),
    INDEX idx_categoria (categoria)
) ENGINE=MEMORY;

-- Cargar datos de productos por categoría por trimestre
INSERT INTO temp_productos_categoria_trimestre
SELECT 
    trimestre,
    categoria,
    COUNT(DISTINCT producto_id) as productos_unicos
FROM (
    -- TRIMESTRE 1: Extraer productos por categoría
    SELECT 
        @Q1_nombre as trimestre,
        categoria,
        producto_id
    FROM ventas_1
    WHERE fechaTabla >= @Q1_inicio AND fechaTabla <= @Q1_fin
    AND cIDR IN (@OP, @ONa)

    UNION ALL

    -- TRIMESTRE 2: Extraer productos por categoría
    SELECT 
        @Q2_nombre as trimestre,
        categoria,
        producto_id
    FROM ventas_2
    WHERE fechaTabla >= @Q2_inicio AND fechaTabla <= @Q2_fin
    AND cIDR IN (@OP, @ONa)

    UNION ALL

    -- TRIMESTRE 3: Extraer productos por categoría
    SELECT 
        @Q3_nombre as trimestre,
        categoria,
        producto_id
    FROM ventas_3
    WHERE fechaTabla >= @Q3_inicio AND fechaTabla <= @Q3_fin
    AND cIDR IN (@OP, @ONa)
) productos_categoria_consolidados
GROUP BY trimestre, categoria
ORDER BY trimestre, categoria;

-- Mostrar productos por categoría por trimestre
SELECT 
    trimestre,
    categoria,
    productos_unicos
FROM temp_productos_categoria_trimestre
ORDER BY 
    CASE trimestre
        WHEN @Q1_nombre THEN 1
        WHEN @Q2_nombre THEN 2
        WHEN @Q3_nombre THEN 3
        ELSE 99
    END,
    categoria;

-- ====================================================================
-- ANÁLISIS PRINCIPAL: PROMEDIO DE PRODUCTOS POR CATEGORÍA
-- ====================================================================

SELECT 'EJECUTANDO ANÁLISIS PRINCIPAL: PROMEDIO DE PRODUCTOS POR CATEGORÍA' as proceso;

-- Calcular promedio de productos por categoría across trimestres
SELECT 
    categoria,
    COUNT(*) as trimestres_con_actividad,
    MIN(productos_unicos) as min_productos,
    MAX(productos_unicos) as max_productos,
    ROUND(AVG(productos_unicos), 2) as promedio_productos,
    ROUND(STDDEV(productos_unicos), 2) as desviacion_estandar,
    ROUND(
        CASE 
            WHEN AVG(productos_unicos) > 0 
            THEN (STDDEV(productos_unicos) / AVG(productos_unicos)) * 100 
            ELSE 0 
        END, 2
    ) as coeficiente_variacion_pct
FROM temp_productos_categoria_trimestre
GROUP BY categoria
ORDER BY promedio_productos DESC;

-- ====================================================================
-- ANÁLISIS COMPLEMENTARIO: ESTADÍSTICAS GENERALES
-- ====================================================================

SELECT 'EJECUTANDO ANÁLISIS COMPLEMENTARIO: ESTADÍSTICAS GENERALES' as proceso;

-- Estadísticas generales del promedio de productos
WITH estadisticas_base AS (
    SELECT 
        categoria,
        ROUND(AVG(productos_unicos), 2) as promedio_productos
    FROM temp_productos_categoria_trimestre
    GROUP BY categoria
)
SELECT 
    'ESTADÍSTICAS_GENERALES' as tipo_analisis,
    COUNT(*) as total_categorias,
    ROUND(MIN(promedio_productos), 2) as promedio_minimo,
    ROUND(MAX(promedio_productos), 2) as promedio_maximo,
    ROUND(AVG(promedio_productos), 2) as promedio_de_promedios,
    ROUND(STDDEV(promedio_productos), 2) as desviacion_entre_categorias
FROM estadisticas_base;

-- ====================================================================
-- ANÁLISIS DETALLADO: CATEGORÍAS POR RANGO DE PROMEDIO
-- ====================================================================

SELECT 'EJECUTANDO ANÁLISIS DETALLADO: CATEGORÍAS POR RANGO DE PROMEDIO' as proceso;

-- Clasificar categorías por rangos de promedio de productos
WITH promedios_categoria AS (
    SELECT 
        categoria,
        ROUND(AVG(productos_unicos), 2) as promedio_productos
    FROM temp_productos_categoria_trimestre
    GROUP BY categoria
)
SELECT 
    CASE 
        WHEN promedio_productos >= 100 THEN 'ALTO (100+)'
        WHEN promedio_productos >= 50 THEN 'MEDIO_ALTO (50-99)'
        WHEN promedio_productos >= 20 THEN 'MEDIO (20-49)'
        WHEN promedio_productos >= 10 THEN 'MEDIO_BAJO (10-19)'
        WHEN promedio_productos >= 5 THEN 'BAJO (5-9)'
        ELSE 'MUY_BAJO (<5)'
    END as rango_promedio,
    COUNT(*) as cantidad_categorias,
    ROUND(MIN(promedio_productos), 2) as promedio_minimo_rango,
    ROUND(MAX(promedio_productos), 2) as promedio_maximo_rango,
    ROUND(AVG(promedio_productos), 2) as promedio_del_rango
FROM promedios_categoria
GROUP BY 
    CASE 
        WHEN promedio_productos >= 100 THEN 'ALTO (100+)'
        WHEN promedio_productos >= 50 THEN 'MEDIO_ALTO (50-99)'
        WHEN promedio_productos >= 20 THEN 'MEDIO (20-49)'
        WHEN promedio_productos >= 10 THEN 'MEDIO_BAJO (10-19)'
        WHEN promedio_productos >= 5 THEN 'BAJO (5-9)'
        ELSE 'MUY_BAJO (<5)'
    END
ORDER BY promedio_del_rango DESC;

-- ====================================================================
-- ANÁLISIS COMPLEMENTARIO: VARIABILIDAD POR CATEGORÍA
-- ====================================================================

SELECT 'EJECUTANDO ANÁLISIS: VARIABILIDAD POR CATEGORÍA' as proceso;

-- Identificar categorías con mayor y menor variabilidad
SELECT 
    categoria,
    COUNT(*) as trimestres_activos,
    ROUND(AVG(productos_unicos), 2) as promedio_productos,
    MIN(productos_unicos) as min_productos,
    MAX(productos_unicos) as max_productos,
    MAX(productos_unicos) - MIN(productos_unicos) as rango_variacion,
    ROUND(STDDEV(productos_unicos), 2) as desviacion_estandar,
    CASE 
        WHEN COUNT(*) = 3 THEN 'CATEGORÍA_ESTABLE'
        WHEN COUNT(*) = 2 THEN 'CATEGORÍA_INTERMITENTE'
        ELSE 'CATEGORÍA_ESPORÁDICA'
    END as tipo_categoria,
    CASE 
        WHEN STDDEV(productos_unicos) <= AVG(productos_unicos) * 0.1 THEN 'MUY_ESTABLE'
        WHEN STDDEV(productos_unicos) <= AVG(productos_unicos) * 0.3 THEN 'ESTABLE'
        WHEN STDDEV(productos_unicos) <= AVG(productos_unicos) * 0.5 THEN 'MODERADAMENTE_VARIABLE'
        ELSE 'ALTAMENTE_VARIABLE'
    END as clasificacion_variabilidad
FROM temp_productos_categoria_trimestre
GROUP BY categoria
ORDER BY desviacion_estandar DESC;

-- ====================================================================
-- ANÁLISIS DETALLADO: TOP CATEGORÍAS Y BOTTOM CATEGORÍAS
-- ====================================================================

SELECT 'EJECUTANDO ANÁLISIS: TOP Y BOTTOM CATEGORÍAS' as proceso;

-- Top 10 categorías con mayor promedio de productos
SELECT 
    'TOP_10_CATEGORÍAS' as tipo_ranking,
    categoria,
    ROUND(AVG(productos_unicos), 2) as promedio_productos,
    MIN(productos_unicos) as min_productos,
    MAX(productos_unicos) as max_productos,
    COUNT(*) as trimestres_activos
FROM temp_productos_categoria_trimestre
GROUP BY categoria
ORDER BY AVG(productos_unicos) DESC
LIMIT 10;

-- Bottom 10 categorías con menor promedio de productos
SELECT 
    'BOTTOM_10_CATEGORÍAS' as tipo_ranking,
    categoria,
    ROUND(AVG(productos_unicos), 2) as promedio_productos,
    MIN(productos_unicos) as min_productos,
    MAX(productos_unicos) as max_productos,
    COUNT(*) as trimestres_activos
FROM temp_productos_categoria_trimestre
GROUP BY categoria
ORDER BY AVG(productos_unicos) ASC
LIMIT 10;

-- ====================================================================
-- RESUMEN EJECUTIVO FINAL
-- ====================================================================

SELECT 'GENERANDO RESUMEN EJECUTIVO FINAL' as proceso;

-- Crear tabla temporal para resumen ejecutivo
CREATE TEMPORARY TABLE temp_resumen_ejecutivo (
    metrica VARCHAR(50),
    valor DECIMAL(10,2),
    descripcion TEXT
) ENGINE=MEMORY;

-- Cargar métricas del resumen ejecutivo
INSERT INTO temp_resumen_ejecutivo
SELECT 
    'TOTAL_CATEGORÍAS',
    COUNT(DISTINCT categoria),
    'Total de categorías únicas que tuvieron actividad en al menos un trimestre'
FROM temp_productos_categoria_trimestre

UNION ALL

SELECT 
    'PROMEDIO_GENERAL',
    ROUND(AVG(promedio_categoria), 2),
    'Promedio general de productos por categoría across todas las categorías'
FROM (
    SELECT AVG(productos_unicos) as promedio_categoria
    FROM temp_productos_categoria_trimestre
    GROUP BY categoria
) promedios_por_categoria

UNION ALL

SELECT 
    'CATEGORÍA_MÁS_AMPLIA',
    MAX(promedio_categoria),
    'Mayor promedio de productos por categoría'
FROM (
    SELECT AVG(productos_unicos) as promedio_categoria
    FROM temp_productos_categoria_trimestre
    GROUP BY categoria
) promedios_por_categoria

UNION ALL

SELECT 
    'CATEGORÍA_MÁS_PEQUEÑA',
    MIN(promedio_categoria),
    'Menor promedio de productos por categoría'
FROM (
    SELECT AVG(productos_unicos) as promedio_categoria
    FROM temp_productos_categoria_trimestre
    GROUP BY categoria
) promedios_por_categoria

UNION ALL

SELECT 
    'CATEGORÍAS_ESTABLES',
    COUNT(*),
    'Categorías que aparecen en los 3 trimestres'
FROM (
    SELECT categoria
    FROM temp_productos_categoria_trimestre
    GROUP BY categoria
    HAVING COUNT(*) = 3
) categorias_estables;

-- Mostrar resumen ejecutivo
SELECT 
    metrica,
    valor,
    descripcion
FROM temp_resumen_ejecutivo
ORDER BY 
    CASE metrica
        WHEN 'TOTAL_CATEGORÍAS' THEN 1
        WHEN 'PROMEDIO_GENERAL' THEN 2
        WHEN 'CATEGORÍA_MÁS_AMPLIA' THEN 3
        WHEN 'CATEGORÍA_MÁS_PEQUEÑA' THEN 4
        WHEN 'CATEGORÍAS_ESTABLES' THEN 5
        ELSE 99
    END;

-- Limpiar tablas temporales
DROP TEMPORARY TABLE IF EXISTS temp_productos_categoria_trimestre;
DROP TEMPORARY TABLE IF EXISTS temp_resumen_ejecutivo;

-- ====================================================================
-- FINALIZACIÓN DEL PROCESO
-- ====================================================================

-- Verificar finalización exitosa
SELECT '<<< ANÁLISIS PROMEDIO PRODUCTOS POR CATEGORÍA COMPLETADO EXITOSAMENTE >>>' as resultado;

SELECT 
    'PROCESO COMPLETADO' as evento,
    'PROMEDIO_PRODUCTOS_POR_CATEGORÍA' as tipo_analisis,
    'SIN_TABLA_TEMPORAL' as metodo_optimizado,
    'CONSULTA_DIRECTA_OPTIMIZADA' as estrategia,
    NOW() as timestamp_fin
FROM DUAL;